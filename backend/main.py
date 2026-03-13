from datetime import date, datetime, timedelta
from typing import List, Optional, Any, Union
from contextlib import asynccontextmanager
from fastapi import FastAPI, HTTPException, Query, BackgroundTasks, WebSocket, WebSocketDisconnect
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field
import pymysql
import pymysql.cursors
import random
import re
import smtplib
from email.mime.text import MIMEText
import secrets
import hashlib
import time
import asyncio
import os
import sys
import pytz
import httpx
import math
import json
import redis.asyncio as aioredis
from queue import Queue, Empty, Full
from threading import Lock

# ─────────────── TIMEZONE CONFIG ───────────────────────────────────
IST = pytz.timezone('Asia/Kolkata')
def get_now_ist():
    return datetime.now(IST).replace(tzinfo=None)

def get_today_ist():
    return get_now_ist().date()

# ─────────────── DELHI OTD REAL-TIME CONFIG ──────────────────────────────────
DELHI_OTD_KEY = "uUi6of5x89BEGVwXfoVa5oj7T2QkB2Fy"
DELHI_VP_URL  = f"https://otd.delhi.gov.in/api/realtime/VehiclePositions.pb?key={DELHI_OTD_KEY}"
_rt_cache: dict = {}          # trip_id → {lat, lon, spd, vid, bearing}
_rt_by_route: dict = {}       # route_id → list of live bus data dicts
_rt_cache_ts: float = 0.0     # last fetch epoch

# Add current dir to path for local imports
sys.path.append(os.path.dirname(os.path.abspath(__file__)))

# ─────────────────────────────── REDIS ──────────────────────────────────────
REDIS_URL = os.environ.get("REDIS_URL", "redis://localhost:6379")
_redis: aioredis.Redis | None = None

async def get_redis() -> aioredis.Redis | None:
    global _redis
    if _redis is None:
        try:
            _redis = aioredis.from_url(REDIS_URL, decode_responses=True, socket_connect_timeout=2)
            await _redis.ping()
            print("✅ Redis connected")
        except Exception as e:
            print(f"⚠️  Redis unavailable ({e}), running without cache")
            _redis = None
    return _redis

async def redis_get(key: str) -> str | None:
    r = await get_redis()
    if r:
        try:
            return await r.get(key)
        except Exception:
            return None
    return None

async def redis_set(key: str, value: str, ttl: int = 10):
    r = await get_redis()
    if r:
        try:
            await r.set(key, value, ex=ttl)
        except Exception:
            pass

async def redis_publish(channel: str, message: str):
    r = await get_redis()
    if r:
        try:
            await r.publish(channel, message)
        except Exception:
            pass

# ───────────────────────── WEBSOCKET MANAGER ────────────────────────────────
class ConnectionManager:
    """Manages all active WebSocket connections and broadcasts messages."""
    def __init__(self):
        self._clients: list[WebSocket] = []
        self._lock = asyncio.Lock()

    async def connect(self, ws: WebSocket):
        await ws.accept()
        async with self._lock:
            self._clients.append(ws)
        print(f"WS connected. Total clients: {len(self._clients)}")

    async def disconnect(self, ws: WebSocket):
        async with self._lock:
            self._clients = [c for c in self._clients if c is not ws]
        print(f"WS disconnected. Total clients: {len(self._clients)}")

    async def broadcast(self, data: str):
        """Send JSON string to all connected clients, remove dead ones."""
        if not self._clients:
            return
        dead = []
        async with self._lock:
            clients = list(self._clients)
        for ws in clients:
            try:
                await ws.send_text(data)
            except Exception:
                dead.append(ws)
        for ws in dead:
            await self.disconnect(ws)

    @property
    def client_count(self) -> int:
        return len(self._clients)

ws_manager = ConnectionManager()

# ─────────────────────── GPS BROADCAST LOOP (background) ────────────────────
GPS_BROADCAST_INTERVAL = 3  # seconds

async def _gps_broadcast_loop():
    """
    Runs forever in the background:
    1. Fetches all transit routes (cached for 1h)
    2. Fetches live GPS for all routes in batches
    3. Caches payload in Redis & broadcasts via WebSocket
    """
    print("🚌 GPS broadcast loop started (Dynamic mode)")
    all_routes = []
    last_route_fetch = datetime.min.replace(tzinfo=pytz.UTC)

    while True:
        try:
            if ws_manager.client_count > 0:
                # DELHI SIMULATION: Fetch active trips and interpolate positions
                all_vehicles = await get_simulated_vehicles()

                if all_vehicles:
                    # Offload DB operations to a thread to avoid blocking the event loop
                    def save_gps_to_db(vehicles, ts):
                        conn = get_conn()
                        try:
                            bulk_data = []
                            for v in vehicles:
                                try:
                                    v_spd = float(v.get("spd", 0)) * 1.60934
                                except:
                                    v_spd = 0.0
                                    
                                bulk_data.append((
                                    v.get("vid"), v.get("tatripid"), ts, v.get("lat"), v.get("lon"),
                                    v_spd, v.get("hdg"), f"Route {v.get('rt')}", v.get("rt"), v.get("dir")
                                ))

                            if bulk_data:
                                with conn.cursor() as cur:
                                    sql = """
                                    INSERT INTO gps_points (ext_vehicle_id, ext_trip_id, ts, lat, lng, speed, heading, route_name, route_id_str, direction)
                                    VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
                                    ON DUPLICATE KEY UPDATE 
                                        ext_trip_id=VALUES(ext_trip_id), ts=VALUES(ts), lat=VALUES(lat), lng=VALUES(lng),
                                        speed=VALUES(speed), heading=VALUES(heading), route_name=VALUES(route_name),
                                        route_id_str=VALUES(route_id_str), direction=VALUES(direction)
                                    """
                                    cur.executemany(sql, bulk_data)
                            conn.commit()
                        finally:
                            release_conn(conn)

                    now = get_now_ist()
                    await asyncio.to_thread(save_gps_to_db, all_vehicles, now)

                    payload = json.dumps({"type": "gps_update", "vehicles": all_vehicles, "ts": now.isoformat()})
                    await redis_set("gps:live", payload, ttl=10)
                    await ws_manager.broadcast(payload)
        except Exception as e:
            print(f"GPS broadcast error: {e}")
        await asyncio.sleep(GPS_BROADCAST_INTERVAL)

# ───────────────────────────── APP LIFESPAN ─────────────────────────────────
@asynccontextmanager
async def lifespan(app: FastAPI):
    """Start background tasks on app startup, clean up on shutdown."""
    # Connect to Redis
    await get_redis()
    # Start GPS broadcast loop
    loop_task = asyncio.create_task(_gps_broadcast_loop())
    # Start the Schedule simulation background task
    sync_task = asyncio.create_task(schedule_to_gps_sync())
    print("✅ App started with WebSocket GPS broadcast and DB sync")
    yield
    # Shutdown
    loop_task.cancel()
    sync_task.cancel()
    try:
        await asyncio.gather(loop_task, sync_task, return_exceptions=True)
    except Exception:
        pass
    if _redis:
        await _redis.aclose()
    print("App shutdown complete")


def calculate_speed(lat1, lon1, ts1, lat2, lon2, ts2):
    """Calculate speed in km/h between two points."""
    try:
        if isinstance(ts1, str): ts1 = datetime.fromisoformat(ts1.replace('Z', ''))
        if isinstance(ts2, str): ts2 = datetime.fromisoformat(ts2.replace('Z', ''))
        
        R = 6371.0  # Earth radius in kilometers
        phi1, phi2 = math.radians(lat1), math.radians(lat2)
        dphi = math.radians(lat2 - lat1)
        dlambda = math.radians(lon2 - lon1)
        a = math.sin(dphi / 2)**2 + math.cos(phi1) * math.cos(phi2) * math.sin(dlambda / 2)**2
        c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a))
        dist = R * c
        
        hours = abs((ts2 - ts1).total_seconds()) / 3600.0
        return round(dist / hours, 2) if hours > 0 else 0.0
    except:
        return 0.0


# --- GMAIL SMTP CONFIGURATION ---
SMTP_EMAIL = "whereismybusss@gmail.com"
SMTP_PASSWORD = "gyvdlaqatzejlgvb"

app = FastAPI(title="College Bus Backend", lifespan=lifespan)

# Allow iOS app to connect (needed for WebSocket upgrades from the app)
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

DB_HOST = "127.0.0.1"
DB_USER = "root"
DB_PASS = ""
DB_NAME = "college_bus"
DB_PORT = 3307




DB_CONFIG = dict(host=DB_HOST, user=DB_USER, password=DB_PASS,
                 database=DB_NAME, port=DB_PORT, autocommit=True,
                 cursorclass=pymysql.cursors.DictCursor)

# ──────────────────────── DB CONNECTION POOLING ──────────────────────────────
class SimplePool:
    def __init__(self, size=5):
        self._pool = Queue(maxsize=size)
        self._lock = Lock()
        self._size = size
        for _ in range(size):
            try:
                self._pool.put(self._create_conn())
            except:
                pass

    def _create_conn(self):
        return pymysql.connect(**DB_CONFIG)

    def get(self):
        try:
            conn = self._pool.get(timeout=2)
            try:
                conn.ping(reconnect=True)
            except:
                conn = self._create_conn()
            return conn
        except Empty:
            return self._create_conn()

    def put(self, conn):
        try:
            self._pool.put(conn, block=False)
        except Full:
            try:
                conn.close()
            except:
                pass

db_pool = SimplePool(size=20)

def get_conn(retries: int = 3, delay: float = 0.5):
    """Return a pooled DB connection."""
    return db_pool.get()

def release_conn(conn):
    db_pool.put(conn)


# ---------- UTILS ----------
def serialize_rows(rows):
    """Convert any datetime / timedelta / date / Decimal values in DB rows to strings
    so FastAPI can JSON-serialize them without raising a 500 error.
    Handles nested lists and dicts recursively."""
    from datetime import datetime, date, timedelta
    from decimal import Decimal

    def clean_val(v, k=None):
        if v is None:
            return None
        if isinstance(v, datetime):
            val = v.isoformat()
            if v.tzinfo is None: val += "Z"
            return val
        if isinstance(v, date):
            return v.isoformat()
        if isinstance(v, timedelta):
            # If it's a duration (minutes), return int if key matches. 
            if k and k in ['duration_minutes', 'duration']:
                return int(v.total_seconds() // 60)
            total_seconds = int(v.total_seconds())
            hours, remainder = divmod(total_seconds, 3600)
            minutes, seconds = divmod(remainder, 60)
            return f"{hours:02d}:{minutes:02d}:{seconds:02d}"
        if isinstance(v, Decimal):
            return float(v)
        if isinstance(v, list):
            return [clean_val(item) for item in v]
        if isinstance(v, dict):
            return {dk: clean_val(dv, dk) for dk, dv in v.items()}
        return v

    result = []
    for row in rows:
        clean = {}
        for k, v in row.items():
            clean[k] = clean_val(v, k)
        result.append(clean)
    return result

def send_email_otp(recipient: str, otp: str):
    """Utility to securely send an OTP via Gmail SMTP with fallback and timeout."""
    if SMTP_EMAIL == "PASTE_YOUR_GMAIL_ADDRESS_HERE" or not SMTP_PASSWORD:
        print(f"DEBUG: SMTP credentials not set. Printing OTP to terminal: {otp} for {recipient}")
        return
        
    try:
        with open("/tmp/otp_debug.log", "a") as f:
            f.write(f"[{get_now_ist()}] Attempting to send OTP to {recipient}\n")
            
        html_content = f"""
        <html>
        <body style="font-family: Arial, sans-serif; color: #333;">
            <div style="max-width: 600px; margin: 0 auto; padding: 20px; border: 1px solid #eee; border-radius: 10px;">
                <h1 style="color: #007AFF; text-align: center;">WhereIsMyBus</h1>
                <p>Hello,</p>
                <p>Your <strong>WhereIsMyBus</strong> verification code is:</p>
                <div style="background-color: #f4f4f4; padding: 15px; text-align: center; border-radius: 5px;">
                    <span style="font-size: 24px; font-weight: bold; letter-spacing: 5px;">{otp}</span>
                </div>
                <p>This code will expire in 5 minutes. If you did not request this code, please ignore this email.</p>
                <hr style="border: none; border-top: 1px solid #eee; margin: 20px 0;">
                <p style="font-size: 11px; color: #999; text-align: center;">
                    This is an automated message, please do not reply to this email.
                </p>
                <p style="font-size: 12px; color: #888; text-align: center;">© 2026 WhereIsMyBus Team. All rights reserved.</p>
            </div>
        </body>
        </html>
        """
        msg = MIMEText(html_content, 'html')
        msg['Subject'] = 'WhereIsMyBus - Verification Code'
        msg['From'] = f"WhereIsMyBus (No Reply) <{SMTP_EMAIL}>"
        msg['To'] = recipient
        msg['Reply-To'] = "no-reply@whereismybus.com"

        # Try Port 587 (Standard)
        try:
            print(f"DEBUG: Attempting Gmail SMTP (587) for {recipient}...")
            server = smtplib.SMTP('smtp.gmail.com', 587, timeout=15)
            server.starttls()
            server.login(SMTP_EMAIL, SMTP_PASSWORD)
            server.send_message(msg)
            server.quit()
        except Exception as e587:
            print(f"DEBUG: SMTP 587 failed ({e587}), trying Port 465 (SSL)...")
            # Try Port 465 (SSL Fallback)
            server = smtplib.SMTP_SSL('smtp.gmail.com', 465, timeout=15)
            server.login(SMTP_EMAIL, SMTP_PASSWORD)
            server.send_message(msg)
            server.quit()

        with open("/tmp/otp_debug.log", "a") as f:
            f.write(f"[{get_now_ist()}] Successfully sent OTP to {recipient}\n")
        print(f"DEBUG: Successfully sent Email OTP to {recipient}")
    except Exception as e:
        # FAIL-SAFE: If SMTP is blocked by the network, print OTP to terminal so admin can still log in
        print(f"\n🚀 [OTP FALLBACK] Verification code for {recipient}: {otp}")
        print(f"⚠️ SMTP delivery failed ({e}). Use the code above to log in.\n")
        
        with open("/tmp/otp_debug.log", "a") as f:
            f.write(f"[{get_now_ist()}] SMTP Email Finally Failed for {recipient}: {e}. PRINTED TO TERMINAL.\n")

# ---------- SECURITY ----------
def hash_password(password: str) -> str:
    """Securely hash a password using PBKDF2-SHA256. 
    Maintained at 100,000 iterations for robust security."""
    salt = secrets.token_hex(16)
    key = hashlib.pbkdf2_hmac(
        'sha256', 
        password.encode('utf-8'), 
        salt.encode('utf-8'), 
        100000 
    )
    return f"{salt}${key.hex()}"

def verify_password(password: str, hashed: str) -> bool:
    """Verify password. Tries 100k iterations first (Standard), then falls back for legacy setup."""
    if not hashed: return False
    if "$" not in hashed: return password == hashed
    
    try:
        salt, key_hex = hashed.split("$")
        # Try 100,000 iterations (Current Standard)
        new_key_100k = hashlib.pbkdf2_hmac('sha256', password.encode('utf-8'), salt.encode('utf-8'), 100000)
        res_100k = new_key_100k.hex()
        if res_100k == key_hex:
            return True
        
        # Fallback to 50,000 (Optimized Migration attempt)
        new_key_50k = hashlib.pbkdf2_hmac('sha256', password.encode('utf-8'), salt.encode('utf-8'), 50000)
        res_50k = new_key_50k.hex()
        if res_50k == key_hex:
            return True
        
        # Fallback to 100,000 (Legacy)
        new_key_100k = hashlib.pbkdf2_hmac('sha256', password.encode('utf-8'), salt.encode('utf-8'), 100000)
        res_100k = new_key_100k.hex()
        
        # Check for 2000 (Some older setups)
        new_key_2k = hashlib.pbkdf2_hmac('sha256', password.encode('utf-8'), salt.encode('utf-8'), 2000)
        res_2k = new_key_2k.hex()

        return res_100k == key_hex or res_2k == key_hex
    except Exception:
        return False


# ---------- MODELS ----------
class GPSIn(BaseModel):
    trip_id: int
    bus_id: int
    lat: float = Field(..., ge=-90, le=90)
    lng: float = Field(..., ge=-180, le=180)
    ts: datetime | None = None
    speed: float | None = None
    heading: float | None = None

class RegisterIn(BaseModel):
    reg_no: str
    password: str
    first_name: str
    last_name: str
    year: int
    mobile_no: str
    email: str | None = None
    role: str = "student"
    college_name: str
    department: str
    degree: str | None = "N/A"
    location: str
    stop: str

class OTPIn(BaseModel):
    target: str # Can be mobile_no or email
    code: str | None = None
    is_admin: bool = False
    is_registration: bool = False

class LoginIn(BaseModel):
    reg_no_or_email: str
    password: str


# ---------- HEALTH ----------
@app.get("/")
def root():
    return {"ok": True, "msg": "server running"}

# ---------- DATABASE MIGRATION ----------
@app.get("/init_db")
def init_db():
    conn = get_conn()
    try:
        with conn.cursor() as cur:
            # Ensure stop_times table exists with correct types
            cur.execute("""
                CREATE TABLE IF NOT EXISTS trip_stop_times (
                    id INT AUTO_INCREMENT PRIMARY KEY,
                    trip_id INT NOT NULL,
                    stop_id INT NOT NULL,
                    stop_order INT NOT NULL,
                    sched_arrival TIME,
                    sched_departure TIME,
                    actual_arrival TIME,
                    actual_departure TIME,
                    status VARCHAR(50) DEFAULT 'scheduled'
                )
            """)
            
            # Ensure gps_points has external ID columns
            try:
                cur.execute("ALTER TABLE gps_points ADD COLUMN IF NOT EXISTS ext_vehicle_id VARCHAR(128)")
                cur.execute("ALTER TABLE gps_points ADD COLUMN IF NOT EXISTS ext_trip_id VARCHAR(128)")
                cur.execute("CREATE INDEX IF NOT EXISTS idx_gps_ext_v ON gps_points(ext_vehicle_id, ts)")
                cur.execute("CREATE INDEX IF NOT EXISTS idx_gps_ext_t ON gps_points(ext_trip_id, ts)")
                conn.commit()
            except Exception as e:
                print(f"Schema update warning (gps_points): {e}")

        return {"ok": True, "msg": "Database schema ensured"}
    finally:
        release_conn(conn)




# ---------- AUTHENTICATION ----------
@app.post("/register")
def register_student(data: RegisterIn):
    conn = get_conn()
    try:
        with conn.cursor() as cur:
            cur.execute("SELECT id FROM users WHERE reg_no = %s", (data.reg_no,))
            if cur.fetchone():
                raise HTTPException(status_code=400, detail="Registration number already registered.")

            if data.email:
                cur.execute("SELECT id FROM users WHERE email = %s", (data.email,))
                if cur.fetchone():
                    raise HTTPException(status_code=400, detail="Email address already registered.")
            
            hashed_pw = hash_password(data.password)
            
            sql = """
            INSERT INTO users (reg_no, password, first_name, last_name, year, mobile_no, email,
                             college_name, department, degree, location, bus_stop, role)
            VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
            """
            cur.execute(sql, (data.reg_no, hashed_pw, data.first_name, data.last_name, 
                             data.year, data.mobile_no, data.email, data.college_name, data.department, 
                             data.degree, data.location, data.stop, data.role))
            conn.commit()
            return {"ok": True, "msg": "Registration successful"}
    finally:
        release_conn(conn)

@app.post("/login")
async def login(data: LoginIn):
    """Refactored to use a single query and async hashing for speed."""
    def fetch_user_for_login(ident):
        conn = get_conn()
        try:
            with conn.cursor() as cur:
                cur.execute("""
                    SELECT * FROM users 
                    WHERE email = %s OR reg_no = %s 
                    LIMIT 1
                """, (ident, ident))
                return cur.fetchone()
        finally:
            release_conn(conn)

    user = await asyncio.to_thread(fetch_user_for_login, data.reg_no_or_email)
    
    if not user:
        raise HTTPException(status_code=401, detail="Invalid credentials.")

    # CPU-bound hashing moved to thread
    is_valid = await asyncio.to_thread(verify_password, data.password, user['password'])
    if not is_valid:
        raise HTTPException(status_code=401, detail="Invalid credentials.")
    
    # Auto-upgrade hash to 100k iterations if plain or old 50k
    should_update = "$" not in user['password']
    if not should_update:
        salt = user['password'].split("$")[0]
        check_100k = hashlib.pbkdf2_hmac('sha256', data.password.encode('utf-8'), salt.encode('utf-8'), 100000).hex()
        if check_100k != user['password'].split("$")[1]:
            should_update = True

    if should_update:
        print(f"DEBUG: Upgrading hash Iterations for {data.reg_no_or_email}")
        def update_user_pw(uid, pw):
            conn = get_conn()
            try:
                hashed_pw = hash_password(pw)
                with conn.cursor() as cur:
                    cur.execute("UPDATE users SET password = %s WHERE id = %s", (hashed_pw, uid))
                conn.commit()
            finally:
                release_conn(conn)
        await asyncio.to_thread(update_user_pw, user['id'], data.password)
    
    if user['role'] == 'admin':
        return {"ok": True, "requires_otp": True, "target": user['email']}
        
    return {"ok": True, "user": serialize_rows([user])[0]}

@app.post("/send_otp")
def send_otp(data: OTPIn, background_tasks: BackgroundTasks):
    with open("/tmp/otp_hits.log", "a") as f:
        f.write(f"[{get_now_ist()}] send_otp hit with target: {data.target}\n")
    conn = get_conn()
    try:
        with conn.cursor() as cur:
            # 1. Cleanup expired OTPs
            cur.execute("DELETE FROM otp_codes WHERE expires_at < %s", (get_now_ist(),))
            
            target_email = data.target
            
            # 2. Resolve Register Number to Email if needed
            if "@" not in data.target:
                cur.execute("SELECT email FROM users WHERE reg_no = %s", (data.target,))
                row = cur.fetchone()
                if not row or not row['email']:
                    raise HTTPException(status_code=404, detail="No account found with that Register Number.")
                target_email = row['email']
            else:
                # Validate Email Address format
                email_regex = r"^[a-zA-Z0-9_.+-]+@[a-zA-Z0-9-]+\.[a-zA-Z0-9-.]+$"
                if not re.match(email_regex, data.target):
                    raise HTTPException(status_code=400, detail="Invalid email address format.")
            
            # 3. Check intentions
            if data.is_registration:
                # Registration flow: email MUST NOT exist
                cur.execute("SELECT id FROM users WHERE email = %s", (target_email,))
                if cur.fetchone():
                    raise HTTPException(status_code=400, detail="Email address already registered. Please login or reset your password.")
            elif not data.is_admin:
                # Password reset flow: email MUST exist and user MUST NOT be admin
                cur.execute("SELECT role FROM users WHERE email = %s", (target_email,))
                user = cur.fetchone()
                if not user:
                    raise HTTPException(status_code=404, detail="No account found with that email address.")
                if user['role'] == 'admin':
                    raise HTTPException(status_code=403, detail="Admin accounts cannot reset password via this flow. Please contact system support.")

            # 4. Generate and Save OTP
            otp = str(random.randint(1000, 9999))
            expiry = get_now_ist() + timedelta(minutes=5)
            
            cur.execute("""
                INSERT INTO otp_codes (target, code, expires_at) 
                VALUES (%s, %s, %s) 
                ON DUPLICATE KEY UPDATE code=%s, expires_at=%s
            """, (target_email, otp, expiry, otp, expiry))
            conn.commit()
            
            # 5. Send the email (in background)
            background_tasks.add_task(send_email_otp, target_email, otp)
                
            return {"ok": True, "msg": "OTP sent successfully", "target": target_email}
    finally:
        release_conn(conn)

@app.post("/verify_otp")
def verify_otp(data: OTPIn):
    conn = get_conn()
    try:
        with conn.cursor() as cur:
            cur.execute("SELECT code, expires_at FROM otp_codes WHERE target = %s", (data.target,))
            row = cur.fetchone()
            if not row:
                raise HTTPException(status_code=400, detail="No OTP sent for this target.")
            
            if row['expires_at'] < get_now_ist():
                raise HTTPException(status_code=400, detail="OTP expired.")
            
            if row['code'] == data.code:
                cur.execute("DELETE FROM otp_codes WHERE target = %s", (data.target,))
                
                # If admin login OTP verify: fetch the final Admin user to return.
                user_res = None
                if data.is_admin:
                    cur.execute("SELECT * FROM users WHERE email = %s AND role = 'admin'", (data.target,))
                    user = cur.fetchone()
                    if user:
                        user_res = serialize_rows([user])[0]
                
                conn.commit()
                return {"ok": True, "msg": "OTP verified", "user": user_res}
            else:
                raise HTTPException(status_code=400, detail="Invalid OTP code.")
    finally:
        release_conn(conn)

class ResetPasswordIn(BaseModel):
    email: str
    new_password: str

@app.post("/reset_password")
def reset_password(data: ResetPasswordIn):
    conn = get_conn()
    try:
        with conn.cursor() as cur:
            # Check user with this email exists
            cur.execute("SELECT id FROM users WHERE email = %s", (data.email,))
            user = cur.fetchone()
            if not user:
                raise HTTPException(status_code=404, detail="No account found with that email address.")
            
            hashed_pw = hash_password(data.new_password)
            cur.execute("UPDATE users SET password = %s WHERE email = %s", (hashed_pw, data.email))
            conn.commit()
            return {"ok": True, "msg": "Password reset successfully."}
    finally:
        release_conn(conn)

# ---------- ADMIN MANAGEMENT ----------
@app.get("/seed_admin")
def seed_admin():
    """
    Seeds the admin user accounts into the users table.
    Call this once to set up admin credentials. Safe to call multiple times.
    """
    admins = [
        {
            "reg_no": "ADMIN001",
            "email": "admin@saveetha.ac.in",
            "password": "Admin@123",
            "first_name": "Admin",
            "last_name": "Manager",
            "role": "admin",
            "college_name": "Saveetha Engineering College",
            "department": "Administration",
        },
        {
            "reg_no": "ADMIN002",
            "email": "transport@saveetha.ac.in",
            "password": "Transport@123",
            "first_name": "Transport",
            "last_name": "Officer",
            "role": "admin",
            "college_name": "Saveetha Engineering College",
            "department": "Transport",
        },
        {
            "reg_no": "ADMIN003",
            "email": "whereismybusss@gmail.com",
            "password": "Admin@123",
            "first_name": "System",
            "last_name": "Admin",
            "role": "admin",
            "college_name": "Saveetha Engineering College",
            "department": "IT Support",
        }
    ]

    conn = get_conn()
    seeded = []
    skipped = []
    try:
        with conn.cursor() as cur:
            for admin in admins:
                cur.execute("SELECT id FROM users WHERE reg_no = %s OR email = %s",
                            (admin["reg_no"], admin["email"]))
                if cur.fetchone():
                    skipped.append(admin["email"])
                    continue

                hashed = hash_password(admin["password"])
                cur.execute(
                    """INSERT INTO users
                       (reg_no, password, first_name, last_name, year, mobile_no, email,
                        role, college_name, department, degree, location, bus_stop)
                       VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)""",
                    (admin["reg_no"], hashed, admin["first_name"], admin["last_name"],
                     1, "0000000000", admin["email"], admin["role"],
                     admin["college_name"], admin["department"], "N/A", "Chennai", "N/A")
                )
                seeded.append(admin["email"])

        conn.commit()
        return {
            "ok": True,
            "seeded": seeded,
            "skipped_already_exist": skipped,
            "credentials": [
                {"email": "admin@saveetha.ac.in", "password": "Admin@123"},
                {"email": "transport@saveetha.ac.in", "password": "Transport@123"}
            ]
        }
    except Exception as e:
        import traceback
        print(traceback.format_exc())
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        release_conn(conn)


@app.get("/students")
def get_students():
    """
    Returns all registered student accounts.
    This endpoint is intended for admin use only (role enforcement on client side).
    """
    conn = get_conn()
    try:
        with conn.cursor() as cur:
            cur.execute(
                """SELECT id, reg_no, first_name, last_name, year, mobile_no,
                          email, college_name, department, degree, location, bus_stop
                   FROM users
                   WHERE role = 'student'
                   ORDER BY first_name ASC"""
            )
            rows = cur.fetchall()
            return {"ok": True, "students": serialize_rows(rows)}
    finally:
        release_conn(conn)

class SupportIn(BaseModel):
    user_email: str | None = None
    subject: str
    message: str
    category: str | None = "Report" # "Report", "Contact", "Account"

class DriverReportIn(BaseModel):
    user_email: str
    bus_number: str
    driver_info: str
    description: str

@app.post("/report")
def submit_report(data: SupportIn):
    """
    Accepts a bug report or issue from the user and sends it to the admin email.
    """
    subject = f"Bus App Report: {data.subject}"
    body = f"Category: {data.category}\nFrom: {data.user_email or 'Anonymous'}\n\nMessage:\n{data.message}"
    
    try:
        _send_admin_notification(subject, body)
        return {"ok": True, "msg": "Report sent successfully."}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/contact")
def contact_support(data: SupportIn):
    """
    General contact form endpoint.
    """
    subject = f"Bus App Contact: {data.subject}"
    body = f"From: {data.user_email or 'Anonymous'}\n\nMessage:\n{data.message}"
    
    try:
        _send_admin_notification(subject, body)
        return {"ok": True, "msg": "Message sent successfully."}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/report_driver")
def report_driver(data: DriverReportIn):
    """
    Form for reporting driver behavior.
    """
    subject = f"Bus App Driver Report: Bus {data.bus_number}"
    body = (f"From: {data.user_email}\n"
            f"Bus Number: {data.bus_number}\n"
            f"Driver Info: {data.driver_info}\n\n"
            f"Incident Description:\n{data.description}")
    
    try:
        _send_admin_notification(subject, body)
        return {"ok": True, "msg": "Driver report sent successfully."}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

def _send_admin_notification(subject: str, body: str):
    """Helper to send email to the configured admin account (SMTP_EMAIL)."""
    if not SMTP_EMAIL or not SMTP_PASSWORD:
        print(f"DEBUG: SMTP not configured. Admin Notification: {subject}\n{body}")
        return

    msg = MIMEText(body)
    msg['Subject'] = subject
    msg['From'] = SMTP_EMAIL
    msg['To'] = SMTP_EMAIL # Send to self/admin

    server = smtplib.SMTP('smtp.gmail.com', 587)
    server.starttls()
    server.login(SMTP_EMAIL, SMTP_PASSWORD)
    server.send_message(msg)
    server.quit()

@app.get("/secure_existing_passwords")
def secure_existing():
    """
    One-time migration to hash any plain-text passwords in the database.
    Checks if the stored password looks like a hash; if not, hashes it.
    """
    conn = get_conn()
    try:
        count = 0
        with conn.cursor() as cur:
            cur.execute("SELECT id, password FROM users")
            users = cur.fetchall()
            for u in users:
                pw = u['password']
                # If password doesn't contain $, assume it's plain text
                if "$" not in pw:
                    hashed = hash_password(pw)
                    cur.execute("UPDATE users SET password = %s WHERE id = %s", (hashed, u['id']))
                    count += 1
            conn.commit()
            return {"ok": True, "msg": f"Secured {count} existing accounts."}
    finally:
        release_conn(conn)


@app.get("/buses")
async def list_buses(service_date: str | None = None, route: str | None = None):
    # DELHI SIMULATION: Return simulated vehicles for fleet view
    simulated = await get_simulated_vehicles()
    
    if route:
        simulated = [v for v in simulated if v.get("rt") == route]
        
    all_buses = []
    now = get_now_ist()
    
    for v in simulated:
        all_buses.append({
            "trip_id": int(v["vid"]) if v["vid"].isdigit() else random.randint(1000, 9999),
            "ext_trip_id": v["tatripid"],
            "bus_id": int(v["vid"]) if v["vid"].isdigit() else None,
            "bus_no": v["vid"],
            "label": f"{v['rt']} to {v['des']}",
            "route_id": v["rt"],
            "route_name": f"Route {v['rt']}",
            "ext_route_id": v["rt"],
            "first_departure": now.isoformat(),
            "last_arrival": (now + timedelta(minutes=30)).isoformat(),
            "status": "Running",
            "speed": float(v.get("spd", 0)),
            "heading": float(v.get("hdg", 0)),
            "latitude": v["lat"],
            "longitude": v["lon"]
        })
    
    return {"ok": True, "data": all_buses}


# ---------- STOPS (for From/To dropdown) ----------
@app.get("/stops")
def list_stops():
    conn = get_conn()
    try:
        with conn.cursor() as cur:
            cur.execute("SELECT id, name, lat, lng FROM stops WHERE is_active=1 ORDER BY name;")
            rows = cur.fetchall()
        return {"ok": True, "data": serialize_rows(rows)}
    finally:
        release_conn(conn)



@app.get("/api/routes/{rt}/directions")
async def get_directions(rt: str):
    """Returns directions for a route in Transit format: [{"dir": "Northbound"}, ...]"""
    # For Delhi, we'll return generic directions or attempt to find them in DB
    return {"ok": True, "directions": [{"dir": "Up"}, {"dir": "Down"}]}

@app.get("/api/stops")
async def get_stops_by_route(rt: str, dir: str):
    """Returns stops for a route in Transit format: [{"stpid": "...", "stpnm": "...", "lat": ..., "lon": ...}, ...]"""
    conn = get_conn()
    try:
        with conn.cursor() as cur:
            # Optimized: Find one representative trip for today and get its stops
            sql = """
            SELECT s.ext_stop_id AS stpid, s.name AS stpnm, s.lat, s.lng AS lon
            FROM stops s
            JOIN trip_stop_times tst ON tst.stop_id = s.id
            WHERE tst.trip_id = (
                SELECT t.id FROM trips t
                JOIN routes r ON r.id = t.route_id
                WHERE r.ext_route_id = %s AND t.service_date = CURDATE()
                LIMIT 1
            )
            ORDER BY tst.stop_order;
            """
            cur.execute(sql, (rt,))
            rows = cur.fetchall()
            return serialize_rows(rows)
    finally:
        release_conn(conn)

@app.get("/api/track")
async def track_route(route_id: str, from_stop_id: str, to_stop_id: str, dir: str):
    # DELHI MODE: Returns simulated vehicles on this route
    simulated = await get_simulated_vehicles()
    filtered = [v for v in simulated if v.get("rt") == route_id]
    
    predictions = []
    now = get_now_ist()
    
    for v in filtered:
        predictions.append({
            "trip_id": int(v["vid"]) if v["vid"].isdigit() else random.randint(1000, 9999),
            "ext_trip_id": v["tatripid"],
            "bus_id": int(v["vid"]) if v["vid"].isdigit() else None,
            "bus_no": v["vid"],
            "label": f"{v['rt']} to {v['des']}",
            "route_id": v["rt"],
            "route_name": f"Route {v['rt']}",
            "ext_route_id": v["rt"],
            "from_departure": now.isoformat(),
            "duration_minutes": 5, # Simulated
            "status": "Running",
            "latitude": v["lat"],
            "longitude": v["lon"]
        })
    return {"ok": True, "data": predictions}


@app.get("/api/search/realtime")
async def search_realtime(rt: str, stpid: str):
    # DELHI MODE: Return simulated predictions for this route/stop
    simulated = await get_simulated_vehicles()
    filtered = [v for v in simulated if v.get("rt") == rt]
    
    predictions = []
    now = get_now_ist()
    
    for v in filtered:
        predictions.append({
            "trip_id": int(v["vid"]) if v["vid"].isdigit() else random.randint(1000, 9999),
            "ext_trip_id": v["tatripid"],
            "bus_id": int(v["vid"]) if v["vid"].isdigit() else None,
            "bus_no": v["vid"],
            "label": f"{rt} to {v['des']}",
            "route_id": rt,
            "route_name": f"Route {rt}",
            "ext_route_id": rt,
            "from_departure": now.isoformat(),
            "duration_minutes": 5,
            "status": "Running"
        })
    return {"ok": True, "data": predictions}

@app.get("/api/trip/full_details")
async def get_trip_full_details(rt: str, dir: str, vid: str):
    # DELHI MODE: Returns simulated/DB details
    conn = get_conn()
    try:
        # a) Get stops from DB
        with conn.cursor() as cur:
            sql = """
            SELECT DISTINCT s.id as stpid, s.name as stpnm, s.lat, s.lng
            FROM stops s
            JOIN trip_stop_times tst ON tst.stop_id = s.id
            JOIN trips t ON t.id = tst.trip_id
            JOIN routes r ON r.id = t.route_id
            WHERE r.ext_route_id = %s
            ORDER BY tst.stop_order
            """
            cur.execute(sql, (rt,))
            all_stops = cur.fetchall()
            
        # b) Get simulated position
        simulated = await get_simulated_vehicles()
        this_bus = next((v for v in simulated if v["vid"] == vid), None)
        
        live_location = None
        if this_bus:
            live_location = {
                "latitude": this_bus["lat"],
                "longitude": this_bus["lon"],
                "heading": this_bus["hdg"],
                "speed_mph": 25
            }
            
        # c) Build timeline (simple mock status for now)
        timeline = []
        for idx, s in enumerate(all_stops):
            timeline.append({
                "stop_id": s["stpid"],
                "stop_name": s["stpnm"],
                "lat": s["lat"],
                "lng": s["lng"],
                "status": "Running",
                "eta": "Scheduled",
                "is_major": (idx == 0 or idx == len(all_stops)-1)
            })

        return {
            "ok": True,
            "vid": vid,
            "route": rt,
            "direction": dir,
            "bus_live_location": live_location,
            "timeline": timeline,
            "polyline": []
        }
    finally:
        release_conn(conn)

# ---------- SEARCH (AUTOCOMPLETE & SUGGESTIONS) ----------
@app.get("/api/search/suggestions")
def search_suggestions(q: str = Query(..., min_length=2)):
    """
    Returns stop suggestions matching the query string (minimum 2 characters).
    """
    conn = get_conn()
    try:
        with conn.cursor() as cur:
            # Search for stops where the name matches the query. Limit to 20 for UI perf.
            search_pattern = f"%{q}%"
            cur.execute(
                "SELECT id, name, lat, lng FROM stops WHERE name LIKE %s ORDER BY name ASC LIMIT 20",
                (search_pattern,)
            )
            stops = cur.fetchall()
            return {"ok": True, "suggestions": serialize_rows(stops)}
    except Exception as e:
        print(f"Error fetching suggestions for '{q}': {e}")
        return {"ok": False, "error": str(e), "suggestions": []}
    finally:
        release_conn(conn)


# ---------- ROUTES SEARCH (by stop name strings, no IDs needed) ----------
@app.get("/api/routes/search")
async def routes_search(
    from_stop: str = Query(..., min_length=2),
    to_stop: str = Query(..., min_length=2),
    service_date: str | None = None
):
    """
    Search for buses/trips by stop name text (not IDs).
    Returns trips with: bus number, route, departure time at from_stop,
    arrival at to_stop, duration, next_stop_name, eta_to_from_stop_mins.
    Falls back to most recent date if no trips found for today.
    """
    sdate = service_date or str(get_today_ist())
    conn = get_conn()
    try:
        with conn.cursor() as cur:
            cur.execute("SELECT id, name FROM stops WHERE name LIKE %s ORDER BY name LIMIT 5", (f"%{from_stop}%",))
            from_stops = cur.fetchall()
            cur.execute("SELECT id, name FROM stops WHERE name LIKE %s ORDER BY name LIMIT 5", (f"%{to_stop}%",))
            to_stops = cur.fetchall()

            if not from_stops or not to_stops:
                return {"ok": True, "data": [], "debug": {"found_from": len(from_stops), "found_to": len(to_stops)}}

            from_ids = [r['id'] for r in from_stops]
            to_ids   = [r['id'] for r in to_stops]
            from_ph  = ",".join(["%s"] * len(from_ids))
            to_ph    = ",".join(["%s"] * len(to_ids))

            def run_search(d):
                sql = f"""
                SELECT
                  t.id AS trip_id, t.ext_trip_id, t.bus_id, b.bus_no,
                  r.id AS route_id, r.name AS route_name, r.ext_route_id,
                  fs.stop_id AS from_stop_id, fs_s.name AS from_stop_name,
                  ts.stop_id AS to_stop_id, ts_s.name AS to_stop_name,
                  CONCAT(%s,'T',DATE_FORMAT(fs.sched_departure,'%%H:%%i:%%s')) AS from_departure,
                  CONCAT(%s,'T',DATE_FORMAT(ts.sched_arrival,'%%H:%%i:%%s')) AS to_arrival,
                  GREATEST(1, TIMESTAMPDIFF(MINUTE, fs.sched_departure, ts.sched_arrival)) AS duration_minutes,
                  t.status,
                  (SELECT s2.name FROM trip_stop_times tst2 JOIN stops s2 ON s2.id=tst2.stop_id
                   WHERE tst2.trip_id=t.id AND tst2.actual_departure IS NULL
                   ORDER BY tst2.stop_order ASC LIMIT 1) AS next_stop_name,
                  (SELECT s3.name FROM trip_stop_times tst3 JOIN stops s3 ON s3.id=tst3.stop_id
                   WHERE tst3.trip_id=t.id AND tst3.actual_departure IS NOT NULL
                   ORDER BY tst3.stop_order DESC LIMIT 1) AS current_stop_name
                FROM trips t
                JOIN routes r ON r.id=t.route_id
                LEFT JOIN buses b ON b.id=t.bus_id
                JOIN trip_stop_times fs ON fs.trip_id=t.id AND fs.stop_id IN ({from_ph})
                JOIN trip_stop_times ts ON ts.trip_id=t.id AND ts.stop_id IN ({to_ph})
                JOIN stops fs_s ON fs_s.id=fs.stop_id
                JOIN stops ts_s ON ts_s.id=ts.stop_id
                WHERE fs.stop_order < ts.stop_order AND t.service_date=%s
                ORDER BY fs.sched_departure LIMIT 200
                """
                cur.execute(sql, [d, d] + from_ids + to_ids + [d])
                return cur.fetchall()

            rows = run_search(sdate)
            if not rows:
                cur.execute("SELECT MAX(service_date) as last_date FROM trips")
                lr = cur.fetchone()
                if lr and lr['last_date']:
                    rows = run_search(str(lr['last_date']))
            
            # --- LIVE FALLBACK ---
            # If still no rows, or just to enrich, look for live vehicles on this route
            if not rows and from_stop and to_stop:
                print(f"[Live Fallback] Searching for live vehicles matching {from_stop} or {to_stop}")
                # Try to guess route number from context or just fetch common ones
                # Fresh simulation if cache empty
                vehicles = await get_simulated_vehicles()
                
                # If the user typed a route number (e.g. "22"), we can filter specifically
                query_route = None
                for part in from_stop.split() + to_stop.split():
                    if part.isdigit(): query_route = part; break
                
                for v in vehicles:
                    v_rt = v.get("rt")
                    if query_route and v_rt != query_route: continue
                    
                    # Synthesize a row
                    rows.append({
                        "trip_id": 0,
                        "ext_trip_id": v.get("tatripid") or v.get("vid"),
                        "bus_id": 0,
                        "bus_no": v.get("vid"),
                        "route_id": 0,
                        "route_name": f"Route {v_rt}",
                        "ext_route_id": v_rt,
                        "from_stop_id": from_ids[0] if from_ids else 0,
                        "from_stop_name": from_stops[0]['name'] if from_stops else from_stop,
                        "to_stop_id": to_ids[0] if to_ids else 0,
                        "to_stop_name": to_stops[0]['name'] if to_stops else to_stop,
                        "from_departure": get_now_ist().isoformat(),
                        "to_arrival": (get_now_ist() + timedelta(minutes=20)).isoformat(),
                        "duration_minutes": 20,
                        "status": v.get("p_status") or "Live",
                        "next_stop_name": "Scanning...",
                        "current_stop_name": "En route"
                    })

        return {"ok": True, "from_stop": from_stop, "to_stop": to_stop, "data": serialize_rows(rows)}
    except Exception as e:
        import traceback; print(f"routes_search error: {e}\n{traceback.format_exc()}")
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        release_conn(conn)




@app.get("/search")
async def search_trips(from_stop_id: int, to_stop_id: int, service_date: str | None = None):
    """
    Returns scheduled trips that go from_stop -> to_stop on a given date (default today).
    """
    sdate = service_date or str(get_today_ist())

    sql = """
    SELECT
      t.id AS trip_id,
      t.ext_trip_id,
      t.bus_id,
      b.bus_no,
      r.id AS route_id,
      r.name AS route_name,
      r.ext_route_id,
      CONCAT(%s, 'T', DATE_FORMAT(fs.sched_departure, '%%H:%%i:%%s')) AS from_departure,
      CONCAT(%s, 'T', DATE_FORMAT(ts.sched_arrival, '%%H:%%i:%%s')) AS to_arrival,
      GREATEST(1, TIMESTAMPDIFF(MINUTE, fs.sched_departure, ts.sched_arrival)) AS duration_minutes,
      t.status,
      (SELECT s2.name FROM trip_stop_times tst2 JOIN stops s2 ON s2.id=tst2.stop_id
       WHERE tst2.trip_id=t.id AND tst2.actual_departure IS NULL
       ORDER BY tst2.stop_order ASC LIMIT 1) AS next_stop_name,
      (SELECT s3.name FROM trip_stop_times tst3 JOIN stops s3 ON s3.id=tst3.stop_id
       WHERE tst3.trip_id=t.id AND tst3.actual_departure IS NOT NULL
       ORDER BY tst3.stop_order DESC LIMIT 1) AS current_stop_name
    FROM trips t
    JOIN routes r ON r.id = t.route_id
    LEFT JOIN buses b ON b.id = t.bus_id
    JOIN trip_stop_times fs ON fs.trip_id = t.id AND fs.stop_id = %s
    JOIN trip_stop_times ts ON ts.trip_id = t.id AND ts.stop_id = %s
    WHERE fs.stop_order < ts.stop_order AND t.service_date = %s
    ORDER BY fs.sched_departure
    LIMIT 10000;
    """

    def fetch_search_trips_db(sdate_param, from_stop_id_param, to_stop_id_param, sql_query):
        conn = get_conn()
        try:
            with conn.cursor() as cur:
                print(f"SEARCH: from={from_stop_id_param} to={to_stop_id_param} date={sdate_param}")
                cur.execute(sql_query, (sdate_param, sdate_param, from_stop_id_param, to_stop_id_param, sdate_param))
                return cur.fetchall()
        finally:
            release_conn(conn)

    rows = await asyncio.to_thread(fetch_search_trips_db, sdate, from_stop_id, to_stop_id, sql)
            
    # Fallback
    if not rows:
        print(f"[Fallback Search] No trips for {sdate}, finding most recent...")
        def get_max_service_date():
            conn = get_conn()
            try:
                with conn.cursor() as cur:
                    cur.execute("SELECT MAX(service_date) as last_date FROM trips")
                    return cur.fetchone()
            finally:
                release_conn(conn)
        
        last_row = await asyncio.to_thread(get_max_service_date)
        if last_row and last_row['last_date']:
            fallback_date = str(last_row['last_date'])
            rows = await asyncio.to_thread(fetch_search_trips_db, fallback_date, from_stop_id, to_stop_id, sql)
    
    # Diagnostic: check if stops even exist
    if not rows:
        def check_stops_exist():
            conn = get_conn()
            try:
                with conn.cursor() as cur:
                    cur.execute("SELECT id, name FROM stops WHERE id IN (%s, %s)", (from_stop_id, to_stop_id))
                    return cur.fetchall()
            finally:
                release_conn(conn)
        found_stops = await asyncio.to_thread(check_stops_exist)
        print(f"[Debug Search] Found {len(found_stops)}/2 stops in DB: {found_stops}")

    # --- LIVE FALLBACK ---
    if not rows:
        print(f"[Live Fallback /search] No DB trips, checking simulated vehicles...")
        vehicles = await get_simulated_vehicles()
        rows = []   # ensure it's a mutable list
        
        for v in vehicles:
            v_rt = v.get("rt")
            rows.append({
                "trip_id": 0,
                "ext_trip_id": v.get("tatripid") or v.get("vid"),
                "bus_id": 0,
                "bus_no": v.get("vid"),
                "route_id": 0,
                "route_name": f"Route {v_rt} (Simulated)",
                "ext_route_id": v_rt,
                "from_departure": datetime.now().isoformat(),
                "to_arrival": (datetime.now() + timedelta(minutes=25)).isoformat(),
                "duration_minutes": 25,
                "status": "Simulated"
            })

    print(f"SEARCH RESULT: {len(rows)} rows found")
    return {"ok": True, "data": serialize_rows(rows)}


@app.get("/routes")
@app.get("/api/routes")
async def list_routes(q: str = "", limit: int = 100, offset: int = 0):
    """Returns Delhi DTC routes with pagination and optional name/id search."""
    conn = get_conn()
    try:
        with conn.cursor() as cur:
            if q:
                search = f"%{q}%"
                cur.execute(
                    "SELECT id, name, ext_route_id FROM routes WHERE name LIKE %s OR ext_route_id LIKE %s ORDER BY ext_route_id LIMIT %s OFFSET %s",
                    (search, search, limit, offset)
                )
            else:
                cur.execute(
                    "SELECT id, name, ext_route_id FROM routes ORDER BY ext_route_id LIMIT %s OFFSET %s",
                    (limit, offset)
                )
            rows = cur.fetchall()
            cur.execute("SELECT COUNT(*) as total FROM routes")
            total = cur.fetchone()['total']
            return {"ok": True, "data": serialize_rows(rows), "total": total, "limit": limit, "offset": offset}
    finally:
        release_conn(conn)


# ---------- TIMELINE (Selecting a bus/trip) ----------
@app.get("/trips/{trip_id}/timeline")
async def trip_timeline(trip_id: str):
    """
    Returns ordered stop timeline for a trip, with live predictions.
    Supports both internal integer IDs and external string IDs.
    """
    try:
        def fetch_timeline_db(t_id, col):
            conn = get_conn()
            try:
                with conn.cursor() as cur:
                    cur.execute(f"SELECT id, ext_trip_id FROM trips WHERE {col}=%s", (t_id,))
                    meta = cur.fetchone()
                    if not meta: return None, None
                    
                    sql = f"""
                    SELECT tst.stop_order, s.id AS stop_id, s.ext_stop_id, s.name AS stop_name, s.lat, s.lng,
                           tst.sched_arrival, tst.sched_departure, tst.actual_arrival, tst.actual_departure
                    FROM trip_stop_times tst
                    JOIN stops s ON s.id = tst.stop_id
                    JOIN trips t ON t.id = tst.trip_id
                    WHERE t.{col} = %s ORDER BY tst.stop_order;
                    """
                    cur.execute(sql, (t_id,))
                    rows = cur.fetchall()
                    return meta, rows
            finally:
                release_conn(conn)

        id_col = "id" if trip_id.isdigit() else "ext_trip_id"
        val = int(trip_id) if trip_id.isdigit() else trip_id
        
        trip_meta, raw_rows = await asyncio.to_thread(fetch_timeline_db, val, id_col)
        
        if not trip_meta:
            # DELHI SIMULATION: Fallback to finding a simulated vehicle if trip not in DB
            simulated = await get_simulated_vehicles()
            this_bus = next((v for v in simulated if v["vid"] == str(trip_id) or v["tatripid"] == str(trip_id)), None)
            if this_bus:
                # Mock a timeline from the route
                rt = this_bus["rt"]
                conn = get_conn()
                try:
                    with conn.cursor() as cur:
                        sql = """
                        SELECT DISTINCT s.id AS stop_id, s.ext_stop_id, s.name AS stop_name, s.lat, s.lng,
                               tst.stop_order, tst.sched_arrival
                        FROM stops s
                        JOIN trip_stop_times tst ON tst.stop_id = s.id
                        JOIN trips t ON t.id = tst.trip_id
                        JOIN routes r ON r.id = t.route_id
                        WHERE r.ext_route_id = %s ORDER BY tst.stop_order LIMIT 10;
                        """
                        cur.execute(sql, (rt,))
                        raw_rows = cur.fetchall()
                        trip_meta = {"ext_trip_id": trip_id}
                finally:
                    release_conn(conn)

        if not trip_meta:
            raise HTTPException(status_code=404, detail=f"Trip {trip_id} not found")

        result = []
        for row in serialize_rows(raw_rows or []):
            row["is_reached"] = False
            row["realtime_eta"] = None
            row["delay_mins"] = 0
            result.append(row)

        return {"ok": True, "trip_id": trip_id, "data": result}
    except HTTPException: raise
    except Exception as e:
        import traceback
        traceback.print_exc()
        return {"ok": False, "error": str(e)}


# ---------- GPS INGEST (later from phone or hardware) ----------
@app.post("/gps")
def gps_ingest(p: GPSIn):
    ts = p.ts or get_now_ist()

    conn = get_conn()
    try:
        with conn.cursor() as cur:
            cur.execute(
                """
                INSERT INTO gps_points (trip_id, bus_id, ts, lat, lng, speed, heading)
                VALUES (%s, %s, %s, %s, %s, %s, %s)
                """,
                (p.trip_id, p.bus_id, ts, p.lat, p.lng, p.speed, p.heading),
            )
        return {"ok": True, "saved": True, "ts": ts.isoformat()}
    finally:
        release_conn(conn)





@app.get("/api/routes/{route_id}/stops")
def get_route_stops(route_id: int):
    """Returns up to 50 stops for a specific route."""
    conn = get_conn()
    try:
        with conn.cursor() as cur:
            cur.execute("""
                SELECT s.id AS stop_id, s.name AS stop_name, s.lat, s.lng, tst.stop_order, tst.sched_arrival
                FROM trip_stop_times tst
                JOIN stops s ON s.id = tst.stop_id
                JOIN trips t ON t.id = tst.trip_id
                WHERE t.route_id = %s AND t.service_date = CURDATE()
                ORDER BY tst.stop_order
                LIMIT 50
            """, (route_id,))
            rows = cur.fetchall()
        return {"ok": True, "data": serialize_rows(rows)}
    finally:
        release_conn(conn)


@app.get("/api/routes/{route_id}/schedule")
def get_route_schedule(route_id: int, date_str: str | None = None):
    """Returns trips for a specific route on a given date (default today)."""
    sdate = date_str or str(get_today_ist())
    sql = """
    SELECT id AS trip_id, ext_trip_id, start_time, end_time, status
    FROM trips
    WHERE route_id = %s AND service_date = %s
    ORDER BY start_time
    """
    conn = get_conn()
    try:
        with conn.cursor() as cur:
            cur.execute(sql, (route_id, sdate))
            rows = cur.fetchall()
        return {"ok": True, "data": serialize_rows(rows)}
    finally:
        release_conn(conn)


@app.get("/api/trips/{ext_trip_id}/timeline")
async def get_ext_trip_timeline(ext_trip_id: str):
    """
    Returns ordered stops for a trip merged with real-time ETAs and GPS points.
    Falls back to the most recent service_date if today has no data.
    """
    # 1. Get scheduled stops — prefer today, fall back to most recent service_date
    sql_stops_today = """
    SELECT tst.stop_order, s.id AS stop_id, s.ext_stop_id, s.name AS stop_name, s.lat, s.lng, 
           tst.sched_arrival, tst.sched_departure
    FROM trip_stop_times tst
    JOIN stops s ON s.id = tst.stop_id
    JOIN trips t ON t.id = tst.trip_id
    WHERE t.ext_trip_id = %s AND t.service_date = CURDATE()
    ORDER BY tst.stop_order
    """

    sql_stops_fallback = """
    SELECT tst.stop_order, s.id AS stop_id, s.ext_stop_id, s.name AS stop_name, s.lat, s.lng, 
           tst.sched_arrival, tst.sched_departure
    FROM trip_stop_times tst
    JOIN stops s ON s.id = tst.stop_id
    JOIN trips t ON t.id = tst.trip_id
    WHERE t.ext_trip_id = %s
      AND t.service_date = (
          SELECT MAX(service_date) FROM trips WHERE ext_trip_id = %s
      )
    ORDER BY tst.stop_order
    """
    
    # 2. Get real-time ETAs
    sql_etas = "SELECT ext_stop_id, eta_ts, delay_sec FROM trip_stop_eta WHERE ext_trip_id = %s"
    
    # 3. Get GPS points for this trip
    sql_gps = "SELECT lat, lng, speed, heading, ts FROM gps_points WHERE ext_trip_id = %s ORDER BY ts ASC LIMIT 500"

    ist_tz = pytz.timezone('Asia/Kolkata')
    target_date_str = datetime.now(ist_tz).strftime('%Y-%m-%d')
    conn = get_conn()
    try:
        with conn.cursor() as cur:
            # First try today's schedule
            cur.execute(sql_stops_today.replace("CURDATE()", "%s"), (ext_trip_id, target_date_str))
            stops = cur.fetchall()
            
            # Fallback: if no stops for today, use most recent date this trip ran
            if not stops:
                print(f"[Timeline Fallback] No stops today for ext_trip_id={ext_trip_id}, using most recent service_date")
                cur.execute(sql_stops_fallback, (ext_trip_id, ext_trip_id))
                stops = cur.fetchall()
            
            cur.execute(sql_etas, (ext_trip_id,))
            etas = {row['ext_stop_id']: row for row in cur.fetchall()}
            
            cur.execute(sql_gps, (ext_trip_id,))
            gps = cur.fetchall()
            
            # Merge ETAs into stops
            for s in stops:
                ext_sid = s['ext_stop_id']
                if ext_sid in etas:
                    s['realtime_eta'] = etas[ext_sid]['eta_ts']
                    s['delay_sec'] = etas[ext_sid]['delay_sec']
                else:
                    s['realtime_eta'] = None
                    s['delay_sec'] = 0

        return {
            "ok": True, 
            "ext_trip_id": ext_trip_id, 
            "stops": serialize_rows(stops),
            "gps_points": serialize_rows(gps)
        }
    finally:
        release_conn(conn)



@app.get("/api/gps/latest")
@app.get("/gps/live")
@app.get("/api/gps/live")
async def gps_live_cached():
    """
    Returns the latest GPS vehicle positions.
    Reads from Redis cache (updated every 3s by the background loop).
    Falls back to simulation if cache is empty.
    """
    cached = await redis_get("gps:live")
    if cached:
        payload = json.loads(cached)
        return {"ok": True, "source": "cache", "data": payload.get("vehicles", [])}

    # Cache miss — get simulated
    vehicles = await get_simulated_vehicles()
    if vehicles:
        payload_str = json.dumps({"type": "gps_update", "vehicles": vehicles, "ts": get_now_ist().isoformat()})
        await redis_set("gps:live", payload_str, ttl=10)
        return {"ok": True, "source": "simulated", "data": vehicles}

    return {"ok": True, "source": "empty", "data": []}


async def schedule_to_gps_sync():
    """Background task to simulate movements based on schedule."""
    print("🚌 Schedule simulation (Delhi Mode) started")
    while True:
        try:
            # Live simulation is handled by get_simulated_vehicles called in _gps_broadcast_loop.
            # This task can be used for secondary sync or just to keep the loop alive.
            pass
        except Exception as e:
            print(f"[SIM SYNC] Error: {e}")
        await asyncio.sleep(60)

async def get_simulated_vehicles():
    """Returns list of real-time or simulated vehicles. Prioritizes real-time OTD feed."""
    try:
        def fetch_active_trips(target_date=None):
            conn = get_conn()
            try:
                now = datetime.now(pytz.timezone('Asia/Kolkata'))
                now_str = now.strftime("%H:%M:%S")
                curr_date = target_date or now.date().isoformat()
                sql = """
                SELECT tst.trip_id, tst.stop_id, tst.sched_arrival, tst.stop_order, 
                       s.lat, s.lng, r.ext_route_id, t.ext_trip_id, t.bus_id
                FROM trip_stop_times tst
                JOIN stops s ON s.id = tst.stop_id
                JOIN trips t ON t.id = tst.trip_id
                JOIN routes r ON r.id = t.route_id
                WHERE t.service_date = %s
                  AND t.start_time <= %s AND t.end_time >= %s
                ORDER BY tst.trip_id, tst.stop_order
                """
                with conn.cursor() as cur:
                    cur.execute(sql, (curr_date, now_str, now_str))
                    return cur.fetchall()
            finally: release_conn(conn)

        # ── 1. Fetch live GTFS-RT (throttled 15s) ─────────────────────────
        global _rt_cache, _rt_cache_ts, _rt_by_route
        if GTFS_RT_AVAILABLE and (time.time() - _rt_cache_ts > 15):
            try:
                async with httpx.AsyncClient(timeout=8) as client:
                    resp = await client.get(DELHI_VP_URL)
                if resp.status_code == 200:
                    from google.transit import gtfs_realtime_pb2
                    feed = gtfs_realtime_pb2.FeedMessage()
                    feed.ParseFromString(resp.content)
                    new_cache = {}
                    new_by_route = {}
                    for entity in feed.entity:
                        if entity.HasField('vehicle'):
                            vp = entity.vehicle
                            tid = vp.trip.trip_id
                            rid = vp.trip.route_id
                            if tid and vp.position.latitude:
                                data = {
                                    "lat": vp.position.latitude, "lon": vp.position.longitude,
                                    "spd": round(vp.position.speed * 3.6, 1) if vp.position.speed else 0.0,
                                    "bearing": vp.position.bearing, "vid": vp.vehicle.id or tid, "rt": rid
                                }
                                new_cache[tid] = data
                                if rid not in new_by_route: new_by_route[rid] = []
                                new_by_route[rid].append(data)
                    _rt_cache = new_cache
                    _rt_by_route = new_by_route
                    _rt_cache_ts = time.time()
                    print(f"[GTFS-RT] {len(_rt_cache)} live vehicles active.")
            except Exception as e:
                print(f"[GTFS-RT] Refresh error: {e}")

        # 2. Process Results ───────────────────────────────────────────
        results = []
        live_vids = set()
        
        # Try to fetch current schedule trips to match RT data
        rows = await asyncio.to_thread(fetch_active_trips)
        if rows:
            trips_data = {}
            for r in rows:
                if r['trip_id'] not in trips_data: trips_data[r['trip_id']] = []
                trips_data[r['trip_id']].append(r)

            for tid, stops in trips_data.items():
                ext_tid = stops[0].get('ext_trip_id')
                ext_rt  = stops[0].get('ext_route_id')
                rt_data = _rt_cache.get(ext_tid)
                
                # Fallback match by route if trip match fails
                if not rt_data and ext_rt in _rt_by_route and _rt_by_route[ext_rt]:
                    rt_data = _rt_by_route[ext_rt].pop(0)

                if rt_data:
                    live_vids.add(rt_data['vid'])
                    results.append({
                        "vid": rt_data['vid'], "tatripid": ext_tid, "lat": rt_data['lat'], "lon": rt_data['lon'],
                        "hdg": rt_data['bearing'], "spd": f"{rt_data['spd']:.1f}", "rt": rt_data['rt'],
                        "des": "Live", "dir": "Live", "source": "realtime"
                    })
                elif len(_rt_cache) < 10: 
                    # Only simulate if RT feed is absolutely dead (prevent 'mock' perception)
                    # (Skipping simulation for now as requested: "dont use dummy/mock data")
                    pass

        # 3. Include ALL Unmatched RT Vehicles (The "Make it work" fix) ──
        for tid, v in _rt_cache.items():
            if v['vid'] not in live_vids:
                results.append({
                    "vid": v['vid'], "tatripid": tid, "lat": v['lat'], "lon": v['lon'],
                    "hdg": v['bearing'], "spd": f"{v['spd']:.1f}", "rt": v['rt'] or "DTC",
                    "des": "Realtime", "dir": "Live", "source": "realtime"
                })

        return results
    except Exception as e:
        print(f"get_simulated_vehicles error: {e}")
        return []


@app.get("/health")
def api_health():
    """Returns system health showing data counts for Delhi integration."""
    conn = get_conn()
    try:
        ist_tz = pytz.timezone('Asia/Kolkata')
        ist_now = datetime.now(ist_tz)
        today_str = ist_now.strftime('%Y-%m-%d')
        five_min_ago = (ist_now - timedelta(minutes=5)).strftime('%Y-%m-%d %H:%M:%S')

        with conn.cursor() as cur:
            cur.execute("SELECT COUNT(*) as count FROM trips WHERE service_date = %s", (today_str,))
            today_trips = cur.fetchone()['count']
            
            cur.execute("SELECT MAX(ts) as last_ts FROM gps_points")
            last_gps = cur.fetchone()['last_ts']
            
            cur.execute("SELECT COUNT(DISTINCT ext_vehicle_id) as active FROM gps_points WHERE ts > %s", (five_min_ago,))
            active_vehicles = cur.fetchone()['active']
            
        return {
            "ok": True,
            "today_trips_count": today_trips,
            "gps_points_last_timestamp": serialize_rows([{"ts": last_gps}])[0]['ts'] if last_gps else None,
            "active_vehicles_count": active_vehicles
        }
    finally:
        release_conn(conn)


# Moved to list_routes


# Removed duplicate /api/gps/latest

# Removed duplicate legacy /gps/latest


# ---------- RECENT SEARCHES ----------
class SearchIn(BaseModel):
    from_stop_id: int | None = None
    to_stop_id: int | None = None
    from_name: str | None = None
    to_name: str | None = None
    role: str = "student"
    user_id: int | None = None


@app.post("/recent_searches")
async def save_recent_search(s: SearchIn):
    """
    Saves a recent from-to search for a user or role.
    Handles both stop IDs (preferred) and names (fallback).
    """
    conn = get_conn()
    try:
        with conn.cursor() as cur:
            # 1. Resolve stop_ids from names if missing
            fid = s.from_stop_id
            tid = s.to_stop_id
            
            if fid is None and s.from_name:
                cur.execute("SELECT id FROM stops WHERE name = %s LIMIT 1", (s.from_name,))
                if r := cur.fetchone(): fid = r['id']
                
            if tid is None and s.to_name:
                cur.execute("SELECT id FROM stops WHERE name = %s LIMIT 1", (s.to_name,))
                if r := cur.fetchone(): tid = r['id']

            # If we still don't have IDs and don't have names, we can't save much.
            if fid is None and s.from_name is None: return {"ok": False, "error": "Insufficient data"}

            now = get_now_ist()
            
            # Simple deduplication and limit (keep last 10)
            if s.user_id:
                cur.execute(
                    "DELETE FROM recent_searches WHERE (from_stop_id = %s OR from_name = %s) AND (to_stop_id = %s OR to_name = %s) AND user_id = %s",
                    (fid, s.from_name, tid, s.to_name, s.user_id)
                )
                cur.execute(
                    "INSERT INTO recent_searches (from_stop_id, to_stop_id, from_name, to_name, role, ts, user_id) VALUES (%s, %s, %s, %s, %s, %s, %s)",
                    (fid, tid, s.from_name, s.to_name, s.role, now, s.user_id)
                )
            else:
                cur.execute(
                    "DELETE FROM recent_searches WHERE (from_stop_id = %s OR from_name = %s) AND (to_stop_id = %s OR to_name = %s) AND role = %s AND user_id IS NULL",
                    (fid, s.from_name, tid, s.to_name, s.role)
                )
                cur.execute(
                    "INSERT INTO recent_searches (from_stop_id, to_stop_id, from_name, to_name, role, ts) VALUES (%s, %s, %s, %s, %s, %s)",
                    (fid, tid, s.from_name, s.to_name, s.role, now)
                )
            
            conn.commit()
            return {"ok": True, "saved": True}
    except Exception as e:
        print(f"save_recent_search error: {e}")
        return {"ok": False, "error": str(e)}
    finally:
        release_conn(conn)


@app.get("/gps/history")
def get_gps_history(trip_id: int):
    """Returns all GPS points for a trip to show historical path."""
    conn = get_conn()
    try:
        with conn.cursor() as cur:
            cur.execute(
                "SELECT lat, lng, speed, heading, ts FROM gps_points WHERE trip_id=%s ORDER BY ts ASC",
                (trip_id,),
            )
            rows = cur.fetchall()
        return {"ok": True, "trip_id": trip_id, "data": serialize_rows(rows)}
    finally:
        release_conn(conn)


@app.get("/recent_searches")
def list_recent_searches(role: str = "student", limit: int = 5, user_id: int | None = None):
    conn = get_conn()
    try:
        with conn.cursor() as cur:
            if user_id:
                sql = """
                SELECT rs.id, rs.from_stop_id, rs.to_stop_id, s1.name AS from_name, s2.name AS to_name, rs.ts
                FROM recent_searches rs
                JOIN stops s1 ON s1.id = rs.from_stop_id
                JOIN stops s2 ON s2.id = rs.to_stop_id
                WHERE rs.user_id = %s
                ORDER BY rs.ts DESC LIMIT %s;
                """
                cur.execute(sql, (user_id, limit))
            else:
                sql = """
                SELECT rs.id, rs.from_stop_id, rs.to_stop_id, s1.name AS from_name, s2.name AS to_name, rs.ts
                FROM recent_searches rs
                JOIN stops s1 ON s1.id = rs.from_stop_id
                JOIN stops s2 ON s2.id = rs.to_stop_id
                WHERE rs.role = %s AND rs.user_id IS NULL
                ORDER BY rs.ts DESC LIMIT %s;
                """
                cur.execute(sql, (role, limit))
            rows = cur.fetchall()
        return {"ok": True, "data": serialize_rows(rows)}
    finally:
        release_conn(conn)

# ---------- FLEET HISTORY ----------
@app.get("/fleet/history")
def get_fleet_history(date: str):
    """
    Returns all scheduled trips for a specific date,
    including the full recorded GPS path for each trip.
    """
    try:
        return _get_fleet_history_impl(date)
    except Exception as e:
        import traceback
        trace = traceback.format_exc()
        print(f"FLEET HISTORY ERROR: {e}\n{trace}")
        raise HTTPException(status_code=500, detail=str(e))

def _get_fleet_history_impl(date: str):
    conn = get_conn()
    try:
        with conn.cursor() as cur:
            # 1. Fetch trip_ids that actually have GPS data for this date
            # This avoids passing 89,000 IDs in a 'WHERE IN' clause
            cur.execute("""
                SELECT DISTINCT trip_id FROM gps_points 
                WHERE ts >= %s AND ts < %s + INTERVAL 1 DAY
            """, (date, date))
            trips_with_gps = {row['trip_id'] for row in cur.fetchall()}

            # 2. Fetch all trips (schedules) for the date
            trips_sql = """
            SELECT
                t.id AS trip_id,
                b.id AS bus_id,
                COALESCE(b.bus_no, r.name) AS bus_number,
                r.name AS route_name,
                t.status,
                (SELECT MIN(sched_departure) FROM trip_stop_times WHERE trip_id = t.id) as start_time,
                (SELECT MAX(sched_arrival) FROM trip_stop_times WHERE trip_id = t.id) as end_time
            FROM trips t
            LEFT JOIN buses b ON b.id = t.bus_id
            JOIN routes r ON r.id = t.route_id
            WHERE t.service_date = %s
            """
            cur.execute(trips_sql, (date,))
            all_trips = cur.fetchall()
            
            # For performance and stability, we prioritize trips with GPS
            # and limit the total number of trips returned.
            trips = [t for t in all_trips if t['trip_id'] in trips_with_gps]
            
            # If we have space, add some non-GPS trips too, up to 1000 total
            if len(trips) < 1000:
                for t in all_trips:
                    if t['trip_id'] not in trips_with_gps:
                        trips.append(t)
                        if len(trips) >= 1000: break
            
            # Format time strings and start_city
            for trip in trips:
                if trip.get('start_time'):
                    trip['start_time'] = str(trip['start_time'])
                if trip.get('end_time'):
                    trip['end_time'] = str(trip['end_time'])
                
                r_name = trip.get('route_name') or ""
                parts = r_name.split(' ')
                if len(parts) > 1:
                    trip['start_city'] = parts[1] if parts[0].isalnum() else parts[0]
                else:
                    trip['start_city'] = r_name or "Unknown"

            gps_by_trip = {}
            stops_by_trip = {}

            # 3. Only fetch GPS for trips in the "trips_with_gps" set
            target_ids = [t['trip_id'] for t in trips if t['trip_id'] in trips_with_gps]
            
            if target_ids:
                # Still use batches if target_ids is large (e.g. > 1000)
                # But here 515 is fine for one query.
                placeholders = ', '.join(['%s'] * len(target_ids))
                
                # Fetch GPS - Pruning every 10th point to keep JSON small
                # (10.9M points / 515 trips = 20k points per trip. Pruning to 2k is safer)
                gps_sql = f"""
                SELECT trip_id, lat, lng, speed, heading, ts
                FROM (
                    SELECT *, ROW_NUMBER() OVER (PARTITION BY trip_id ORDER BY ts ASC) as rn
                    FROM gps_points
                    WHERE trip_id IN ({placeholders})
                ) t
                WHERE MOD(t.rn, 50) = 1 
                """
                cur.execute(gps_sql, tuple(target_ids))
                gps_rows = cur.fetchall()

                for row in gps_rows:
                    tid = row['trip_id']
                    if tid not in gps_by_trip:
                        gps_by_trip[tid] = []
                    gps_by_trip[tid].append({
                        'lat': row['lat'],
                        'lng': row['lng'],
                        'speed': row['speed'],
                        'heading': row['heading'],
                        'ts': str(row['ts']) if row['ts'] else None
                    })

                # Stop Schedule History for target trips
                stops_sql = f"""
                SELECT tst.trip_id, s.name as stop_name, s.lat, s.lng, tst.actual_arrival, tst.stop_order
                FROM trip_stop_times tst
                JOIN stops s ON s.id = tst.stop_id
                WHERE tst.trip_id IN ({placeholders})
                ORDER BY tst.trip_id, tst.stop_order ASC
                """
                cur.execute(stops_sql, tuple(target_ids))
                stop_rows = cur.fetchall()
                
                for row in stop_rows:
                    tid = row['trip_id']
                    if tid not in stops_by_trip:
                        stops_by_trip[tid] = []
                    stops_by_trip[tid].append({
                        'stop_name': row['stop_name'],
                        'lat': row['lat'],
                        'lng': row['lng'],
                        'reached_time': str(row['actual_arrival']) if row['actual_arrival'] else None
                    })
                
                # Combine everything
                for trip in trips:
                    tid = trip['trip_id']
                    trip['actual_polyline'] = gps_by_trip.get(tid, [])
                    trip['stops'] = stops_by_trip.get(tid, [])
            else:
                # No trips with GPS, ensure keys exist
                for trip in trips:
                    trip['actual_polyline'] = []
                    trip['stops'] = []

        return {"ok": True, "date": date, "data": serialize_rows(trips)}
    finally:
        release_conn(conn)


# ---------- ADMIN HISTORY ENDPOINTS ----------

@app.get("/api/admin/history/dates")
def admin_history_dates():
    """
    Returns a list of distinct dates that have recorded GPS tracking data.
    Only past dates are returned (no future dates). Used to populate the Admin calendar.
    """
    conn = get_conn()
    try:
        with conn.cursor() as cur:
            cur.execute("""
                SELECT DISTINCT DATE(ts) as date
                FROM gps_points
                WHERE ts <= NOW()
                ORDER BY date DESC
                LIMIT 365
            """)
            rows = cur.fetchall()
            dates = [str(row['date']) for row in rows]
            return {"ok": True, "dates": dates}
    except Exception as e:
        print(f"Admin history dates error: {e}")
        return {"ok": False, "dates": [], "error": str(e)}
    finally:
        release_conn(conn)


@app.get("/api/admin/history/timeline")
def admin_history_timeline(date: str, trip_id: int):
    """
    Returns the historical stop timeline for a specific trip on a specific date.
    Shows actual arrival/departure times at each stop.
    """
    conn = get_conn()
    try:
        with conn.cursor() as cur:
            cur.execute("""
                SELECT 
                    s.id as stop_id,
                    s.name as stop_name,
                    s.lat,
                    s.lng,
                    tst.stop_order,
                    tst.sched_arrival,
                    tst.sched_departure,
                    tst.actual_arrival,
                    tst.actual_departure,
                    tst.status
                FROM trip_stop_times tst
                JOIN stops s ON s.id = tst.stop_id
                WHERE tst.trip_id = %s
                ORDER BY tst.stop_order ASC
            """, (trip_id,))
            rows = cur.fetchall()

            # Enrich with delay info
            result = []
            for row in serialize_rows(rows):
                sched = row.get('sched_arrival') or row.get('sched_departure')
                actual = row.get('actual_arrival') or row.get('actual_departure')
                delay_mins = None
                try:
                    if sched and actual:
                        fmt = "%H:%M:%S"
                        s_dt = datetime.strptime(str(sched)[-8:], fmt).replace(tzinfo=IST)
                        a_dt = datetime.strptime(str(actual)[-8:], fmt).replace(tzinfo=IST)
                        diff = (a_dt - s_dt).total_seconds() / 60
                        delay_mins = int(diff) if diff > 1 else None
                except Exception:
                    pass
                row['delay_mins'] = delay_mins
                result.append(row)

            return {"ok": True, "trip_id": trip_id, "date": date, "timeline": result}
    except Exception as e:
        print(f"Admin history timeline error: {e}")
        return {"ok": False, "timeline": [], "error": str(e)}
    finally:
        release_conn(conn)


@app.get("/api/admin/history/map")
def admin_history_map(date: str, trip_id: int = None, route_name: str = None):
    """
    Returns GPS breadcrumbs for one or all routes on a specific date.
    Used to draw historical polylines on the fleet view.
    If trip_id is supplied, returns only that trip's path.
    If route_name is supplied, returns all trips for that route.
    Otherwise returns all trips with GPS data for the day.
    """
    conn = get_conn()
    try:
        with conn.cursor() as cur:
            if trip_id:
                cur.execute("""
                    SELECT gp.lat, gp.lng, gp.speed, gp.heading, gp.ts, gp.trip_id,
                           COALESCE(b.bus_no, r.name) as bus_number, r.name as route_name
                    FROM gps_points gp
                    JOIN trips t ON t.id = gp.trip_id
                    JOIN routes r ON r.id = t.route_id
                    LEFT JOIN buses b ON b.id = t.bus_id
                    WHERE gp.trip_id = %s AND DATE(gp.ts) = %s
                    ORDER BY gp.ts ASC
                """, (trip_id, date))
            elif route_name:
                cur.execute("""
                    SELECT gp.lat, gp.lng, gp.speed, gp.heading, gp.ts, gp.trip_id,
                           COALESCE(b.bus_no, r.name) as bus_number, r.name as route_name
                    FROM gps_points gp
                    JOIN trips t ON t.id = gp.trip_id
                    JOIN routes r ON r.id = t.route_id
                    LEFT JOIN buses b ON b.id = t.bus_id
                    WHERE r.name = %s AND DATE(gp.ts) = %s
                    ORDER BY gp.trip_id, gp.ts ASC
                    LIMIT 5000
                """, (route_name, date))
            else:
                cur.execute("""
                    SELECT gp.lat, gp.lng, gp.speed, gp.heading, gp.ts, 
                           COALESCE(gp.trip_id, 0) as trip_id,
                           COALESCE(b.bus_no, gp.ext_vehicle_id) as bus_number, 
                           COALESCE(r.name, gp.route_name) as route_name,
                           gp.ext_vehicle_id
                    FROM gps_points gp
                    LEFT JOIN trips t ON t.id = gp.trip_id
                    LEFT JOIN routes r ON r.id = t.route_id
                    LEFT JOIN buses b ON b.id = t.bus_id
                    WHERE DATE(gp.ts) = %s
                    ORDER BY COALESCE(r.name, gp.route_name), COALESCE(gp.trip_id, gp.ext_vehicle_id), gp.ts ASC
                    LIMIT 10000
                """, (date,))

            rows = cur.fetchall()

            # Group by trip_id for easy rendering in iOS
            by_trip: dict = {}
            for row in rows:
                # Use a combination of trip_id and ext_vehicle_id for grouping 
                # if trip_id is 0/null
                group_key = row['trip_id'] if row['trip_id'] != 0 else row['ext_vehicle_id']
                
                if group_key not in by_trip:
                    by_trip[group_key] = {
                        "trip_id": row['trip_id'],
                        "bus_number": row['bus_number'],
                        "route_name": row['route_name'],
                        "ext_vehicle_id": row.get('ext_vehicle_id'),
                        "points": []
                    }
                by_trip[group_key]["points"].append({
                    "lat": float(row['lat']),
                    "lng": float(row['lng']),
                    "speed": float(row['speed'] or 0),
                    "heading": float(row['heading'] or 0),
                    "ts": serialize_val(row['ts'])
                })

            return {"ok": True, "date": date, "trips": list(by_trip.values())}
    except Exception as e:
        print(f"Admin history map error: {e}")
        return {"ok": False, "trips": [], "error": str(e)}
    finally:
        release_conn(conn)


# ─────────────────────── WEBSOCKET GPS ENDPOINT ─────────────────────────────
@app.websocket("/ws/gps")
async def websocket_gps(websocket: WebSocket):
    """
    WebSocket endpoint. Clients connect here to receive real-time GPS pushes.
    The server broadcasts vehicle positions every GPS_BROADCAST_INTERVAL seconds.
    The client can also send {"type": "ping"} to keep the connection alive.
    """
    await ws_manager.connect(websocket)
    try:
        # Send the latest cached GPS immediately on connect (fast first paint)
        cached = await redis_get("gps:live")
        if cached:
            await websocket.send_text(cached)
        # Keep connection alive while waiting for pushes
        while True:
            try:
                msg = await asyncio.wait_for(websocket.receive_text(), timeout=30)
                # Handle client ping/pong
                try:
                    data = json.loads(msg)
                    if data.get("type") == "ping":
                        await websocket.send_text(json.dumps({"type": "pong"}))
                except Exception:
                    pass
            except asyncio.TimeoutError:
                # Send keep-alive ping to prevent proxy disconnects
                await websocket.send_text(json.dumps({"type": "ping"}))
    except WebSocketDisconnect:
        pass
    except Exception as e:
        print(f"WebSocket error: {e}")
    finally:
        await ws_manager.disconnect(websocket)


# ─────────────────────── CACHED GPS REST ENDPOINT ───────────────────────────
# Integrated into unified GPS endpoint above


# ─────────────────────── WS STATUS (debug) ───────────────────────────────────
@app.get("/api/ws/status")
async def ws_status():
    """Returns the number of connected WebSocket clients and Redis ping status."""
    redis_ok = False
    try:
        r = await get_redis()
        if r:
            await r.ping()
            redis_ok = True
    except Exception:
        pass
    return {
        "connected_clients": ws_manager.client_count,
        "redis_connected": redis_ok,
        "broadcast_interval_secs": GPS_BROADCAST_INTERVAL
    }

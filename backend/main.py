from datetime import date, datetime, timedelta
from typing import List, Optional, Any, Union
from contextlib import asynccontextmanager
from fastapi import FastAPI, Request, HTTPException, Query, BackgroundTasks, WebSocket, WebSocketDisconnect
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

# (Delhi OTD / GTFS-RT integration removed — using only real device GPS)

# Add current dir to path for local imports
sys.path.append(os.path.dirname(os.path.abspath(__file__)))
import voice_agent

# ─────────────────────────────── REDIS ──────────────────────────────────────
REDIS_URL = os.environ.get("REDIS_URL", "redis://127.0.0.1:6379")
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
class SegmentedConnectionManager:
    """Manages role-based WebSocket connections (admin vs student)."""
    def __init__(self):
        # Dict mapping role -> list of WebSockets
        self._clients: dict[str, list[WebSocket]] = {"admin": [], "student": [], "driver": []}
        self._lock = asyncio.Lock()

    async def connect(self, ws: WebSocket, role: str = "student"):
        await ws.accept()
        if role not in self._clients:
            role = "student"
        async with self._lock:
            self._clients[role].append(ws)
        print(f"WS connected ({role}). Total clients: {self.client_count}")

    async def disconnect(self, ws: WebSocket):
        async with self._lock:
            for role in self._clients:
                if ws in self._clients[role]:
                    self._clients[role].remove(ws)
                    break
        print(f"WS disconnected. Total clients: {self.client_count}")

    async def broadcast_segmented(self, payload: str, role_filter: str | None = None):
        """Sends data to specific roles or all if role_filter is None."""
        if self.client_count == 0:
            return
        
        dead = []
        async with self._lock:
            to_notify = []
            if role_filter:
                to_notify = list(self._clients.get(role_filter, []))
            else:
                for r in self._clients:
                    to_notify.extend(self._clients[r])
        
        for ws in to_notify:
            try:
                await ws.send_text(payload)
            except Exception:
                dead.append(ws)
        
        for ws in dead:
            await self.disconnect(ws)

    @property
    def client_count(self) -> int:
        return sum(len(c) for c in self._clients.values())

ws_manager = SegmentedConnectionManager()

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
                # 1. Fetch Real GPS updates from Redis cache instead of simulation
                r = await get_redis()
                all_vehicles = []
                if r:
                    keys = await r.keys("gps:latest:*")
                    seen = set()
                    for k in keys:
                        v_str = await r.get(k)
                        if v_str:
                            try:
                                v = json.loads(v_str)
                                vid = v.get("vid")
                                if vid and vid not in seen:
                                    seen.add(vid)
                                    all_vehicles.append(v)
                            except: pass

                if all_vehicles:
                    # Fix types for frontend (String lat/lon/spd/hdg)
                    for v in all_vehicles:
                        v["lat"] = str(v.get("lat", "0.0"))
                        v["lon"] = str(v.get("lon", "0.0"))
                        v["spd"] = str(v.get("spd", "0"))
                        v["hdg"] = str(v.get("hdg", "0"))
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
                    # Broadcast to everyone (admin/student/driver) for main live map
                    await ws_manager.broadcast_segmented(payload)
                    
                    # Also update individual trip caches for /api/gps/latest
                    for v in all_vehicles:
                        if v.get("vid"):
                            await redis_set(f"gps:latest:{v['vid']}", json.dumps(v), ttl=60)
                        if v.get("tatripid"):
                            await redis_set(f"gps:latest:{v['tatripid']}", json.dumps(v), ttl=60)
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
        if hours <= 0: return 0.0
        res = dist / hours
        return float(round(res, 2))
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
    """Ensures all necessary tables and columns exist in the database."""
    conn = get_conn()
    try:
        with conn.cursor() as cur:
            cur.execute("""
                CREATE TABLE IF NOT EXISTS stops (
                    id INT AUTO_INCREMENT PRIMARY KEY,
                    ext_stop_id VARCHAR(128),
                    name VARCHAR(255) NOT NULL,
                    lat DECIMAL(10, 8),
                    lng DECIMAL(11, 8),
                    stop_code VARCHAR(50),
                    is_active TINYINT(1) DEFAULT 1,
                    UNIQUE KEY (name)
                )
            """)
            cur.execute("""
                CREATE TABLE IF NOT EXISTS buses (
                    id INT AUTO_INCREMENT PRIMARY KEY,
                    bus_no VARCHAR(50) NOT NULL UNIQUE,
                    driver_name VARCHAR(255),
                    phone_no VARCHAR(20),
                    model VARCHAR(100),
                    capacity INT,
                    label VARCHAR(255),
                    is_active TINYINT(1) DEFAULT 1
                )
            """)
            cur.execute("""
                CREATE TABLE IF NOT EXISTS routes (
                    id INT AUTO_INCREMENT PRIMARY KEY,
                    ext_route_id VARCHAR(128),
                    name VARCHAR(255) NOT NULL,
                    description TEXT,
                    color VARCHAR(20),
                    is_active TINYINT(1) DEFAULT 1,
                    UNIQUE KEY (name)
                )
            """)
            cur.execute("""
                CREATE TABLE IF NOT EXISTS trips (
                    id INT AUTO_INCREMENT PRIMARY KEY,
                    bus_id INT,
                    route_id INT,
                    service_date DATE,
                    status ENUM('scheduled', 'active', 'completed', 'cancelled') DEFAULT 'scheduled',
                    ext_trip_id VARCHAR(128),
                    FOREIGN KEY (bus_id) REFERENCES buses(id),
                    FOREIGN KEY (route_id) REFERENCES routes(id)
                )
            """)

            # 2. Schedule Tables
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
                    status VARCHAR(50) DEFAULT 'scheduled',
                    FOREIGN KEY (trip_id) REFERENCES trips(id),
                    FOREIGN KEY (stop_id) REFERENCES stops(id)
                )
            """)

            # 3. Geometry (Routing)
            cur.execute("""
                CREATE TABLE IF NOT EXISTS route_paths (
                    id INT AUTO_INCREMENT PRIMARY KEY,
                    route_id INT NOT NULL,
                    point_order INT NOT NULL,
                    lat DECIMAL(10, 8) NOT NULL,
                    lng DECIMAL(11, 8) NOT NULL,
                    FOREIGN KEY (route_id) REFERENCES routes(id)
                )
            """)

            # 4. Auth & User State
            cur.execute("""
                CREATE TABLE IF NOT EXISTS users (
                    id INT AUTO_INCREMENT PRIMARY KEY,
                    reg_no VARCHAR(100) UNIQUE,
                    first_name VARCHAR(255),
                    last_name VARCHAR(255),
                    password VARCHAR(255),
                    year INT,
                    mobile_no VARCHAR(20),
                    email VARCHAR(255) UNIQUE,
                    college_name VARCHAR(255),
                    department VARCHAR(255),
                    degree VARCHAR(255) DEFAULT 'N/A',
                    location VARCHAR(255),
                    bus_stop VARCHAR(255),
                    role ENUM('student', 'admin', 'driver') DEFAULT 'student',
                    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
                )
            """)
            cur.execute("""
                CREATE TABLE IF NOT EXISTS otp_codes (
                    target VARCHAR(255) PRIMARY KEY,
                    code VARCHAR(10) NOT NULL,
                    expires_at DATETIME NOT NULL
                )
            """)
            cur.execute("""
                CREATE TABLE IF NOT EXISTS recent_searches (
                    id INT AUTO_INCREMENT PRIMARY KEY,
                    user_id INT,
                    from_stop_id INT,
                    to_stop_id INT,
                    from_name VARCHAR(255),
                    to_name VARCHAR(255),
                    role VARCHAR(50),
                    ts TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                    FOREIGN KEY (user_id) REFERENCES users(id)
                )
            """)


            # 5. GPS & Logs
            cur.execute("""
                CREATE TABLE IF NOT EXISTS gps_points (
                    id BIGINT AUTO_INCREMENT PRIMARY KEY,
                    trip_id INT,
                    ext_vehicle_id VARCHAR(128),
                    ext_trip_id VARCHAR(128),
                    route_id_str VARCHAR(128),
                    route_name VARCHAR(255),
                    direction VARCHAR(50),
                    ts DATETIME NOT NULL,
                    lat DECIMAL(10, 8) NOT NULL,
                    lng DECIMAL(11, 8) NOT NULL,
                    speed FLOAT,
                    heading FLOAT,
                    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                    INDEX (ts),
                    INDEX (ext_vehicle_id, ts),
                    INDEX (trip_id, ts)
                )
            """)

            # 6. Migrations (Columns if table existed)
            try:
                cur.execute("ALTER TABLE gps_points ADD COLUMN IF NOT EXISTS ext_vehicle_id VARCHAR(128)")
                cur.execute("ALTER TABLE gps_points ADD COLUMN IF NOT EXISTS route_id_str VARCHAR(128)")
                cur.execute("ALTER TABLE gps_points ADD COLUMN IF NOT EXISTS direction VARCHAR(50)")
            except: pass

            conn.commit()
            return {"ok": True, "msg": "Full database schema ensured"}
    except Exception as e:
        print(f"init_db error: {e}")
        return {"ok": False, "error": str(e)}
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
                # Password reset flow: email MUST exist
                cur.execute("SELECT role FROM users WHERE email = %s", (target_email,))
                user = cur.fetchone()
                if not user:
                    raise HTTPException(status_code=404, detail="No account found with that email address.")
                
                # USER RULE: Reset password is not eligible for user, he needs to contact transport admin
                if user['role'] == 'student' or user['role'] == 'user':
                    raise HTTPException(status_code=403, detail="Password reset is not available for users. Please contact the Transport Admin.")
                
                # Admin MUST be allowed to reset (OTP flow)


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
            # Check user role and ensure only admins can reset (as per requirement)
            cur.execute("SELECT role FROM users WHERE email = %s", (data.email,))
            user = cur.fetchone()
            if not user:
                raise HTTPException(status_code=404, detail="No account found.")
            
            if user['role'] == 'student' or user['role'] == 'user':
                raise HTTPException(status_code=403, detail="Users cannot reset password in-app. Contact Transport Admin.")
            
            hashed_pw = hash_password(data.new_password)
            cur.execute("UPDATE users SET password = %s WHERE email = %s", (hashed_pw, data.email))
            conn.commit()
            return {"ok": True, "msg": "Admin password reset successfully."}

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

@app.get("/api/stops/nearby")
async def get_stops_nearby(lat: float, lon: float, limit: int = 5, directions: bool = False):
    """Returns stops sorted by distance from the given lat/lon."""
    conn = get_conn()
    try:
        with conn.cursor() as cur:
            # Simple Haversine in SQL
            sql = """
                SELECT id, name, lat, lng,
                (6371 * acos(cos(radians(%s)) * cos(radians(lat)) * cos(radians(lng) - radians(%s)) + sin(radians(%s)) * sin(radians(lat)))) AS distance_km
                FROM stops
                ORDER BY distance_km
                LIMIT %s
            """
            cur.execute(sql, (lat, lon, lat, limit))
            rows = cur.fetchall()
            serialized = serialize_rows(rows)
            
            if directions and serialized:
                nearest = serialized[0]
                # Calculate walking directions from user to nearest stop
                try:
                    dist, dur, poly = await get_route_details(lat, lon, nearest['lat'], nearest['lng'], profile='foot')
                    nearest['directions'] = {
                        "distance_km": dist,
                        "duration_minutes": int(dur),
                        "polyline": poly
                    }
                except Exception as e:
                    print(f"Walking directions error: {e}")
                    
            return {"ok": True, "data": serialized}
    finally:
        release_conn(conn)

@app.get("/api/routes")
async def get_routes_list(q: str = "", limit: int = 100, offset: int = 0):
    """Returns a list of all bus routes."""
    conn = get_conn()
    try:
        with conn.cursor() as cur:
            sql = "SELECT id, name, ext_route_id FROM routes"
            params: List[Any] = []
            if q:
                sql += " WHERE name LIKE %s"
                params.append(f"%{q}%")
            sql += " LIMIT %s OFFSET %s"
            params.extend([limit, offset])
            
            cur.execute(sql, params)
            routes = cur.fetchall()
            
            cur.execute("SELECT COUNT(*) as total FROM routes")
            total = cur.fetchone()['total']
            
            return {"ok": True, "data": serialize_rows(routes), "total": total}
    finally:
        release_conn(conn)

@app.get("/api/routes/{route_id}/stops")
async def get_route_stops_v3(route_id: int):
    """Returns the ordered stops for a specific route."""
    conn = get_conn()
    try:
        with conn.cursor() as cur:
            sql = """
                SELECT DISTINCT s.id as stop_id, s.name, s.lat, s.lng, tst.stop_order
                FROM stops s
                JOIN trip_stop_times tst ON tst.stop_id = s.id
                JOIN trips t ON t.id = tst.trip_id
                WHERE t.route_id = %s
                ORDER BY tst.stop_order ASC
            """
            cur.execute(sql, (route_id,))
            rows = cur.fetchall()
            return {"ok": True, "data": serialize_rows(rows)}
    finally:
        release_conn(conn)

@app.get("/buses")
async def get_today_buses_alias(service_date: str | None = None, route: str | None = None, stop_id: str | None = None):
    """Alias for getting active trips for a specific day, with optional stop filtering."""
    sdate = service_date or str(date.today())
    conn = get_conn()
    try:
        with conn.cursor() as cur:
            def run_query(d):
                if stop_id:
                    # Filtering by stop (for Nearby Stops feature)
                    sql = """
                        SELECT 
                            t.id as trip_id, t.bus_id, b.bus_no, r.name as route_name, 
                            r.id as route_id, r.ext_route_id, t.ext_trip_id, t.status,
                            tst.sched_departure as first_departure,
                            r.name as label
                        FROM trips t
                        JOIN routes r ON r.id = t.route_id
                        LEFT JOIN buses b ON b.id = t.bus_id
                        JOIN trip_stop_times tst ON tst.trip_id = t.id
                        WHERE t.service_date = %s AND tst.stop_id = %s
                    """
                    p = [d, stop_id]
                else:
                    # Generic list
                    sql = """
                        SELECT 
                            t.id as trip_id, t.bus_id, b.bus_no, r.name as route_name, 
                            r.id as route_id, r.ext_route_id, t.ext_trip_id, t.status,
                            t.start_time as first_departure,
                            r.name as label
                        FROM trips t
                        JOIN routes r ON r.id = t.route_id
                        LEFT JOIN buses b ON b.id = t.bus_id
                        WHERE t.service_date = %s
                    """
                    p = [d]

                if route:
                    sql += " AND (r.name LIKE %s OR r.ext_route_id = %s)"
                    p.extend([f"%{route}%", route])
                
                cur.execute(sql, p)
                return cur.fetchall()

            rows = run_query(sdate)
            # FALLBACK to latest available date if today is empty
            if not rows and not service_date:
                cur.execute("SELECT MAX(service_date) as last_date FROM trips")
                res = cur.fetchone()
                if res and res['last_date']:
                    rows = run_query(str(res['last_date']))

            return {"ok": True, "data": serialize_rows(rows)}
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
            "route_id": int(v["rt"]) if str(v["rt"]).isdigit() else 0,
            "route_name": f"Route {v['rt']}",
            "ext_route_id": v["rt"],
            "from_departure": now.isoformat(),
            "duration_minutes": 5, # Simulated
            "status": "Running",
            "lat": v["lat"],
            "lon": v["lon"]
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
            "route_id": int(rt) if str(rt).isdigit() else 0,
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
        # a) Get stops from DB with scheduled times
        with conn.cursor() as cur:
            sql = """
            SELECT s.id as stpid, s.name as stpnm, s.lat, s.lng, 
                   tst.sched_arrival, tst.stop_order
            FROM stops s
            JOIN trip_stop_times tst ON tst.stop_id = s.id
            JOIN trips t ON t.id = tst.trip_id
            JOIN routes r ON r.id = t.route_id
            WHERE r.ext_route_id = %s OR r.id = %s OR r.name = %s
            ORDER BY tst.stop_order
            """
            rt_id = int(rt) if rt.isdigit() else 0
            cur.execute(sql, (rt, rt_id, rt))
            all_stops = cur.fetchall()
            
            # Get actual route ID to lookup path
            cur.execute("SELECT id FROM routes WHERE ext_route_id = %s OR id = %s OR name = %s", (rt, rt_id, rt))
            row = cur.fetchone()
            actual_route_id = row['id'] if row else rt_id

            # c) Get road-snapped polyline from route_paths
            cur.execute("SELECT lat, lng FROM route_paths WHERE route_id = %s ORDER BY point_order", (actual_route_id,))
            db_path = cur.fetchall()
            
        # b) Get simulated position
        simulated = await get_simulated_vehicles()
        this_bus = next((v for v in simulated if v["vid"] == vid), None)
        
        live_location = None
        if this_bus:
            live_location = {
                "lat": this_bus["lat"],
                "lon": this_bus["lon"],
                "heading": this_bus["hdg"],
                "speed_mph": 25
            }
            
        # d) Build timeline and polyline coordinates
        timeline = []
        polyline_coords = [{"lat": float(p["lat"]), "lng": float(p["lng"])} for p in db_path] if db_path else []
        first_arrival_mins = None
        current_cumulative_dist = 0.0
        last_stop_loc = None

        for idx, s in enumerate(all_stops):
            # Calculate distance
            curr_loc = (float(s["lat"]), float(s["lng"]))
            if last_stop_loc:
                dist = calculate_distance(last_stop_loc[0], last_stop_loc[1], curr_loc[0], curr_loc[1])
                current_cumulative_dist += dist
            last_stop_loc = curr_loc

            # Calculate Duration from Schedule
            duration_mins = 0
            if s.get("sched_arrival"):
                val = s["sched_arrival"]
                # pymysql returns TIME as timedelta
                this_mins = 0
                if isinstance(val, timedelta):
                    this_mins = int(val.total_seconds() // 60)
                else:
                    try:
                        h, m, sec = map(int, str(val).split(':'))
                        this_mins = h * 60 + m
                    except: pass
                
                if first_arrival_mins is None:
                    first_arrival_mins = this_mins
                else:
                    duration_mins = this_mins - first_arrival_mins

            # ETA calculation (relative to now)
            eta = "Scheduled"
            if live_location:
                try:
                    d_to_stop = calculate_distance(float(live_location["lat"]), float(live_location["lon"]), s["lat"], s["lng"])
                    eta_mins = int(d_to_stop * 3) # 20km/h
                    eta_date = get_now_ist() + timedelta(minutes=eta_mins)
                    eta = eta_date.strftime("%H:%M")
                except:
                    pass

            timeline.append({
                "stop_id": str(s["stpid"]),
                "stop_name": s["stpnm"],
                "lat": str(s["lat"]),
                "lng": str(s["lng"]),
                "status": "Upcoming",
                "eta": eta,
                "is_major": (idx == 0 or idx == len(all_stops)-1),
                "distance_km": round(float(current_cumulative_dist), 2),
                "duration_mins": max(0, duration_mins)
            })
            if not db_path:
                polyline_coords.append({"lat": s["lat"], "lng": s["lng"]})

        return {
            "ok": True,
            "vid": str(vid),
            "route": str(rt),
            "direction": dir,
            "live_location": {
                "lat": float(live_location["lat"]),
                "lon": float(live_location["lon"]),
                "heading": int(live_location["heading"] or 0),
                "speed_mph": int(live_location["speed_mph"] or 25)
            } if live_location else None,
            "polyline": polyline_coords,
            "timeline": timeline
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
                "SELECT id, name, lat, lng FROM stops WHERE name LIKE %s AND is_active = 1 ORDER BY name ASC LIMIT 20",
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
            cur.execute("SELECT id, name, lat, lng FROM stops WHERE name LIKE %s ORDER BY name LIMIT 5", (f"%{from_stop}%",))
            from_stops = cur.fetchall()
            cur.execute("SELECT id, name, lat, lng FROM stops WHERE name LIKE %s ORDER BY name LIMIT 5", (f"%{to_stop}%",))
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
                  fs_s.lat AS from_lat, fs_s.lng AS from_lon,
                  ts_s.lat AS to_lat, ts_s.lng AS to_lon,
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
                        "from_lat": from_stops[0]['lat'] if from_stops else 0.0,
                        "from_lon": from_stops[0]['lng'] if from_stops else 0.0,
                        "to_lat": to_stops[0]['lat'] if to_stops else 0.0,
                        "to_lon": to_stops[0]['lng'] if to_stops else 0.0,
                        "from_departure": get_now_ist().isoformat(),
                        "to_arrival": (get_now_ist() + timedelta(minutes=20)).isoformat(),
                        "duration_minutes": 20,
                        "status": v.get("p_status") or "Live",
                        "next_stop_name": "Scanning...",
                        "current_stop_name": "En route"
                    })

            async def enrich_row(r):
                if 'from_lat' in r and r.get('from_lat') and 'to_lat' in r and r.get('to_lat'):
                    dist, duration, polyline = await get_route_details(r['from_lat'], r['from_lon'], r['to_lat'], r['to_lon'])
                    r['distance_km'] = round(dist, 2)
                    # Only override duration if it's missing or zero from schedule
                    if not r.get('duration_minutes') or r['duration_minutes'] <= 0:
                        r['duration_minutes'] = int(duration)
                    if polyline:
                        r['polyline_coords'] = polyline
                return r

            if rows:
                tasks = [enrich_row(r) for r in rows[:5]]
                enriched = await asyncio.gather(*tasks)
                for i, e in enumerate(enriched):
                    rows[i] = e

        return {"ok": True, "from_stop": from_stop, "to_stop": to_stop, "data": serialize_rows(rows)}
    except Exception as e:
        import traceback; print(f"routes_search error: {e}\n{traceback.format_exc()}")
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        release_conn(conn)


# ---------- TRIP TIMELINE (Dynamic) ----------
@app.get("/api/trip/timeline")
async def get_trip_timeline(trip_id: int, from_stop_id: str | None = None, to_stop_id: str | None = None):
    """
    Returns the real-time stop timeline for a trip.
    Calculates ETAs based on the bus's current location relative to stops.
    If from_stop_id and to_stop_id are provided, marks the segment.
    """
    conn = get_conn()
    try:
        with conn.cursor() as cur:
            # 1. Fetch trip and its stops
            cur.execute("""
                SELECT 
                    tst.stop_id, s.name as stop_name, s.lat, s.lng, 
                    tst.stop_order, tst.sched_arrival, tst.sched_departure,
                    tst.actual_arrival, tst.actual_departure, tst.status,
                    t.bus_id, b.bus_no
                FROM trip_stop_times tst
                JOIN stops s ON s.id = tst.stop_id
                JOIN trips t ON t.id = tst.trip_id
                LEFT JOIN buses b ON b.id = t.bus_id
                WHERE tst.trip_id = %s
                ORDER BY tst.stop_order ASC
            """, (trip_id,))
            stops = cur.fetchall()
            
            if not stops:
                raise HTTPException(status_code=404, detail="Trip not found")

            # 2. Identify the search segment if IDs provided
            from_order = -1
            to_order = 999999
            if from_stop_id:
                # Find stop_order for from_stop_id
                for s in stops:
                    if str(s['stop_id']) == from_stop_id:
                        from_order = s['stop_order']
                        break
            if to_stop_id:
                # Find stop_order for to_stop_id
                for s in stops:
                    if str(s['stop_id']) == to_stop_id:
                        to_order = s['stop_order']
                        break

            # 3. Get the bus's current live GPS position
            sql = """
                SELECT lat, lng, ts, speed, heading 
                FROM gps_points 
                WHERE trip_id = %s 
                ORDER BY ts DESC LIMIT 1
            """
            cur.execute(sql, (trip_id,))
            live = cur.fetchone()

            # 4. Process the timeline
            result = []
            future_stops = []
            
            for s in serialize_rows(stops):
                status = s['status']
                if s['actual_departure']:
                    status = "departed"
                elif s['actual_arrival']:
                    status = "arrived"
                s['live_status'] = status
                s['eta'] = None
                
                # Mark if in segment
                s['is_in_segment'] = (s['stop_order'] >= from_order and s['stop_order'] <= to_order)
                
                if live and not s['actual_arrival']:
                    future_stops.append(s)
                result.append(s)

            # 5. Calculate segment totals (duration/distance)
            segment_duration = 0
            segment_distance = 0
            segment_stops = [s for s in result if s.get('is_in_segment')]
            if len(segment_stops) >= 2:
                # Duration
                try:
                    s_first = segment_stops[0]
                    s_last = segment_stops[-1]
                    t1 = s_first.get('sched_departure') or s_first.get('sched_arrival')
                    t2 = s_last.get('sched_arrival')
                    
                    def to_mins(val):
                        if isinstance(val, timedelta): return int(val.total_seconds() // 60)
                        h, m, s = map(int, str(val).split(':'))
                        return h * 60 + m
                    
                    if t1 and t2:
                        segment_duration = max(0, to_mins(t2) - to_mins(t1))
                except: pass

                # Distance
                try:
                    last_coords = None
                    for ss in segment_stops:
                        curr_coords = (float(ss['lat']), float(ss['lng']))
                        if last_coords:
                            segment_distance += calculate_distance(last_coords[0], last_coords[1], curr_coords[0], curr_coords[1])
                        last_coords = curr_coords
                except: pass

            # Concurrent OSRM ETA calculations
            if live and future_stops:
                async def fetch_eta(s_stop):
                    try:
                        _, duration, _ = await get_route_details(live['lat'], live['lng'], s_stop['lat'], s_stop['lng'])
                        if duration > 0:
                            s_stop['eta'] = (get_now_ist() + timedelta(minutes=int(duration))).isoformat()
                    except Exception as e:
                        print(f"Timeline ETA calculation error: {e}")

                await asyncio.gather(*(fetch_eta(s) for s in future_stops))

            return {
                "ok": True,
                "trip_id": trip_id,
                "bus_no": stops[0]['bus_no'],
                "segment_duration": segment_duration,
                "segment_distance": round(segment_distance, 2),
                "live_location": serialize_rows([live])[0] if live else None,
                "timeline": result
            }
    finally:
        release_conn(conn)

# ───────────────────────── TRACCAR & DIRECT GPS UPDATES ──────────────────────

@app.get("/api/gps/logger")
@app.get("/api/gps/traccar")
async def traccar_push(
    background_tasks: BackgroundTasks,
    id: str, lat: float, lon: float,
    spd: float = 0, hdg: float = 0,
    timestamp: str | None = None
):
    """
    Endpoint for Traccar Client app. 
    Format: /api/gps/traccar?id=DEVICE_ID&lat=LAT&lon=LON&spd=SPEED&hdg=BEARING
    """
    now = get_now_ist()
    try:
        # Use numeric ID if possible, fall back to the raw string (e.g. "Bus1")
        try: vid_str = str(int(id))
        except: vid_str = id  # raw string like "Bus1"

        vehicle = {
            "vid": vid_str,
            "tatripid": vid_str,

            "ext_vehicle_id": id, 
            "ext_trip_id": id, 
            "lat": str(lat), 
            "lon": str(lon),
            "hdg": str(hdg), 
            "spd": f"{spd:.1f}", 
            "rt": "TRC",
            "des": "Traccar Live", 
            "dir": "Live", 
            "source": "traccar",
            "ts": now.isoformat()
        }
        
        # Update cache and broadcast
        payload = json.dumps({"type": "gps_update", "vehicles": [vehicle], "ts": now.isoformat()})
        await redis_set("gps:live", payload, ttl=10)
        await redis_set(f"gps:latest:{id}", json.dumps(vehicle), ttl=21600)  # 6 hours for testing
        await ws_manager.broadcast_segmented(payload)
        
        # Async save to DB
        def save_traccar_to_db():
            conn = get_conn()
            try:
                with conn.cursor() as cur:
                    # Lookup active trip_id for today matching ext_trip_id or bus_no
                    trip_id = None
                    try:
                        # 1. Try Lookup by ext_trip_id
                        cur.execute("SELECT id FROM trips WHERE ext_trip_id = %s AND service_date = %s ORDER BY id DESC LIMIT 1", (id, now.date()))
                        res = cur.fetchone()
                        if res:
                            trip_id = res['id']
                        else:
                            # 2. Try Lookup by bus_no (Device ID might match bus number)
                            cur.execute("SELECT t.id FROM trips t JOIN buses b ON b.id = t.bus_id WHERE b.bus_no = %s AND t.service_date = %s ORDER BY t.id DESC LIMIT 1", (id, now.date()))
                            res = cur.fetchone()
                            if res: trip_id = res['id']
                    except Exception as e:
                        print(f"Traccar trip lookup error: {e}")

                    sql = """
                    INSERT INTO gps_points (ext_vehicle_id, ext_trip_id, ts, lat, lng, speed, heading, route_name, trip_id)
                    VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s)
                    """
                    cur.execute(sql, (id, id, now, lat, lon, spd, hdg, "Traccar Route", trip_id))
                    conn.commit()
            except Exception as e:
                print(f"DB Save Error (Traccar): {e}")
            finally: release_conn(conn)

        background_tasks.add_task(save_traccar_to_db)
        return {"status": "ok"}
    except Exception as e:
        print(f"Traccar Push Error: {e}")
        return {"status": "error", "msg": str(e)}

@app.post("/api/gps/owntracks")
async def owntracks_push(request: Request, background_tasks: BackgroundTasks, id: str | None = None):
    """
    Endpoint for OwnTracks HTTP mode.
    Reads raw body to prevents 422 Unprocessable Entity framing drops.
    """
    try:
        data = {}
        content_type = request.headers.get("Content-Type", "")
        
        if "application/json" in content_type:
            data = await request.json()
        elif "application/x-www-form-urlencoded" in content_type:
            form = await request.form()
            data = dict(form)
        else:
            try: data = await request.json()
            except: pass

        print(f"OwnTracks Received: {data}")

        if data.get("_type") != "location":
            return {"status": "ignored", "type": data.get("_type")}
        
        # Use id from query param first, then tid from JSON
        device_id = id or data.get("tid", "Unknown")
        lat = data.get("lat")
        lon = data.get("lon")
        spd = data.get("vel", 0)
        hdg = data.get("cog", 0)

        if lat is None or lon is None:
            return {"status": "missing_coords"}

        # Redirect to same logic as traccar_push
        await traccar_push(background_tasks=background_tasks, id=device_id, lat=lat, lon=lon, spd=spd, hdg=hdg)
        return {"status": "ok"}
    except Exception as e:
        print(f"OwnTracks Push Error: {e}")
        return {"status": "error", "msg": str(e)}

@app.post("/gps")
async def post_gps_update(data: GPSIn):
    """Direct GPS update from the iOS app."""
    now = get_now_ist()
    vid = str(data.bus_id)
    tid = str(data.trip_id)
    
    vehicle = {
        "vid": vid, 
        "tatripid": tid,
        "lat": str(data.lat), 
        "lon": str(data.lng),
        "hdg": str(data.heading or 0), 
        "spd": f"{data.speed or 0:.1f}", 
        "rt": "APP",
        "des": "App Live", 
        "dir": "Live", 
        "source": "app",
        "ts": now.isoformat()
    }
    
    payload = json.dumps({"type": "gps_update", "vehicles": [vehicle], "ts": now.isoformat()})
    await redis_set("gps:live", payload, ttl=10)
    await redis_set(f"gps:latest:{vid}", json.dumps(vehicle), ttl=60)
    await redis_set(f"gps:latest:{tid}", json.dumps(vehicle), ttl=60)
    await ws_manager.broadcast_segmented(payload)
    
    def save_app_gps_to_db():
        conn = get_conn()
        try:
            with conn.cursor() as cur:
                sql = """
                INSERT INTO gps_points (trip_id, lat, lng, speed, heading, ts)
                VALUES (%s, %s, %s, %s, %s, %s)
                """
                cur.execute(sql, (data.trip_id, data.lat, data.lng, data.speed, data.heading, now))
                conn.commit()
        finally: release_conn(conn)
    
    asyncio.create_task(asyncio.to_thread(save_app_gps_to_db))
    return {"ok": True}

@app.get("/search")
@app.get("/api/search")
async def api_search_redirect(rt: str, stpid: str):
    """Redirect for compatibility with some frontend versions."""
    return await search_realtime(rt, stpid)

async def get_route_details(lat1, lon1, lat2, lon2, profile="driving"):
    """
    Returns (distance_km, duration_minutes, polyline) between two coordinates.
    Uses Google Maps if GOOGLE_MAPS_API_KEY is available, otherwise OSRM as fallback.
    """
    import os
    GOOGLE_MAPS_API_KEY = os.environ.get("GOOGLE_MAPS_API_KEY")

    if GOOGLE_MAPS_API_KEY:
        try:
            url = f"https://maps.googleapis.com/maps/api/directions/json?origin={lat1},{lon1}&destination={lat2},{lon2}&key={GOOGLE_MAPS_API_KEY}"
            async with httpx.AsyncClient() as client:
                resp = await client.get(url, timeout=5.0)
                if resp.status_code == 200:
                    data = resp.json()
                    if data.get("status") == "OK":
                        route = data["routes"][0]
                        leg = route["legs"][0]
                        distance = leg["distance"]["value"] / 1000.0
                        duration = leg["duration"]["value"] / 60.0
                        # Encoded polyline is returned, it's easier to use OSRM geometry or let frontend do snapping
                        return distance, duration, []
        except Exception as e:
            print(f"Google Maps Directions Error: {e}")

    # OSRM Fallback
    try:
        # Use provided profile (driving, walking, foot)
        url = f"http://router.project-osrm.org/route/v1/{profile}/{lon1},{lat1};{lon2},{lat2}?overview=full&geometries=geojson"
        async with httpx.AsyncClient() as client:
            resp = await client.get(url, timeout=5.0)
            if resp.status_code == 200:
                data = resp.json()
                if data.get("code") == "Ok":
                    route = data["routes"][0]
                    distance = route["distance"] / 1000.0
                    duration = route["duration"] / 60.0
                    geometry = route["geometry"].get("coordinates", [])
                    polyline = [{"lat": c[1], "lon": c[0]} for c in geometry]
                    return distance, duration, polyline
    except Exception as e:
        print(f"OSRM Routing Error: {e}")

    # Fallback to Haversine
    dist = calculate_distance(lat1, lon1, lat2, lon2)
    return dist, dist * 3, [] # Approx 3 mins per km

def calculate_distance(lat1, lon1, lat2, lon2):
    """Haversine distance in km."""
    R = 6371.0
    dlat = math.radians(lat2 - lat1)
    dlon = math.radians(lon2 - lon1)
    a = math.sin(dlat/2)**2 + math.cos(math.radians(lat1)) * math.cos(math.radians(lat2)) * math.sin(dlon/2)**2
    c = 2 * math.atan2(math.sqrt(a), math.sqrt(1-a))
    return R * c


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

    # Cache miss — Fetch real live vehicles from Redis cache instead of simulation
    r = await get_redis()
    all_vehicles = []
    if r:
        try:
            keys = await r.keys("gps:latest:*")
            seen = set()
            for k in keys:
                v_str = await r.get(k)
                if v_str:
                    v = json.loads(v_str)
                    # Use vid, or fall back to the Redis key suffix as identifier
                    vid = v.get("vid") or k.split(":")[-1]
                    if vid and vid not in seen:
                        seen.add(vid)
                        all_vehicles.append(v)
        except Exception as e:
            print(f"Redis fetch error in gps_live_cached: {e}")

    if all_vehicles:
        return {"ok": True, "source": "realtime", "data": all_vehicles}

    return {"ok": True, "source": "empty", "data": []}


async def schedule_to_gps_sync():
    """Background task to simulate movements based on schedule for trips without live GPS."""
    print("🚌 Background simulation sync task started")
    while True:
        try:
            now = get_now_ist()
            today = now.date()
            conn = get_conn()
            try:
                with conn.cursor() as cur:
                    # Fetch all active trips for today
                    cur.execute("""
                        SELECT t.id, t.bus_id, b.bus_no, r.name as route_name, r.id as route_id
                        FROM trips t
                        JOIN buses b ON b.id = t.bus_id
                        JOIN routes r ON r.id = t.route_id
                        WHERE t.service_date = %s AND t.status = 'scheduled'
                    """, (today,))
                    trips = cur.fetchall()
                    
                    for trip in trips:
                        tid = trip['id']
                        vid = trip['bus_no'] or str(trip['bus_id'])
                        
                        # Check if we have real GPS in Redis in last 30s
                        real_gps = await redis_get(f"gps:latest:{vid}")
                        if real_gps:
                            # Skip simulation if real GPS is active
                            continue
                            
                        # Simulate: Find where the bus SHOULD be right now
                        cur.execute("""
                            SELECT s.lat, s.lng, tst.sched_arrival, tst.stop_order
                            FROM trip_stop_times tst
                            JOIN stops s ON s.id = tst.stop_id
                            WHERE tst.trip_id = %s
                            ORDER BY tst.stop_order ASC
                        """, (tid,))
                        stops = cur.fetchall()
                        
                        if not stops: continue
                        
                        # Find current segment
                        # (This is a simplified linear interpolation for the monolith restoration)
                        target_stop = None
                        prev_stop = stops[0]
                        for s in stops:
                            # Convert sched_arrival (time object) to datetime for comparison
                            sched_dt = datetime.combine(today, (datetime.min + s['sched_arrival']).time())
                            if sched_dt > now:
                                target_stop = s
                                break
                            prev_stop = s
                        
                        if target_stop:
                            # Simple "at stop" simulation or segment lead
                            lat, lon = prev_stop['lat'], prev_stop['lng']
                            
                            vehicle = {
                                "vid": vid, "tatripid": str(tid),
                                "lat": str(lat), "lon": str(lon),
                                "hdg": "0", "spd": "0", "rt": trip['route_name'],
                                "des": "Scheduled", "dir": "Inbound", "source": "sim",
                                "ts": now.isoformat()
                            }
                            await redis_set(f"gps:latest:{vid}", json.dumps(vehicle), ttl=10)
            finally:
                release_conn(conn)
        except Exception as e:
            print(f"[SIM SYNC] Error: {e}")
        await asyncio.sleep(10)

async def get_simulated_vehicles():
    """Returns vehicles from Redis GPS cache only (real device GPS via GPSLogger)."""
    try:
        r = await get_redis()
        results = []
        if r:
            keys = await r.keys("gps:latest:*")
            seen = set()
            for k in keys:
                v_str = await r.get(k)
                if v_str:
                    try:
                        v = json.loads(v_str)
                        vid = v.get("vid")
                        if vid and vid not in seen:
                            seen.add(vid)
                            results.append(v)
                    except:
                        pass
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


# ---------- RECENT SEARCHES ----------
class SearchIn(BaseModel):
    from_stop_id: Union[int, str, None] = None
    to_stop_id: Union[int, str, None] = None
    from_name: str | None = None
    to_name: str | None = None
    role: str = "student"
    user_id: Union[int, str, None] = None


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


# ────────────────── ADMIN MANAGEMENT ENDPOINTS ────────────────────────────
class BusIn(BaseModel):
    bus_no: str
    driver_name: str | None = None
    phone_no: str | None = None
    label: str | None = None
    capacity: int = 40

@app.get("/api/admin/buses")
def admin_get_buses():
    conn = get_conn()
    try:
        with conn.cursor() as cur:
            cur.execute("SELECT * FROM buses ORDER BY id DESC")
            return {"ok": True, "data": serialize_rows(cur.fetchall())}
    finally: release_conn(conn)

@app.post("/api/admin/buses")
def admin_add_bus(b: BusIn):
    conn = get_conn()
    try:
        with conn.cursor() as cur:
            sql = "INSERT INTO buses (bus_no, driver_name, phone_no, label, capacity) VALUES (%s, %s, %s, %s, %s)"
            cur.execute(sql, (b.bus_no, b.driver_name, b.phone_no, b.label, b.capacity))
            conn.commit()
            return {"ok": True, "id": cur.lastrowid}
    finally: release_conn(conn)

@app.delete("/api/admin/buses/{bus_id}")
def admin_delete_bus(bus_id: int):
    conn = get_conn()
    try:
        with conn.cursor() as cur:
            cur.execute("DELETE FROM buses WHERE id = %s", (bus_id,))
            conn.commit()
            return {"ok": True}
    finally: release_conn(conn)

@app.get("/api/admin/routes")
def admin_get_routes():
    conn = get_conn()
    try:
        with conn.cursor() as cur:
            cur.execute("SELECT * FROM routes ORDER BY id DESC")
            return {"ok": True, "data": serialize_rows(cur.fetchall())}
    finally: release_conn(conn)

@app.get("/api/admin/drivers")
def admin_get_drivers():
    conn = get_conn()
    try:
        with conn.cursor() as cur:
            cur.execute("SELECT id, name, email, mobile_no, role FROM users WHERE role = 'driver'")
            return {"ok": True, "data": serialize_rows(cur.fetchall())}
    finally: release_conn(conn)

@app.get("/api/admin/stats")
def admin_stats():
    """Summary stats for Admin Dashboard."""
    conn = get_conn()
    try:
        with conn.cursor() as cur:
            cur.execute("SELECT COUNT(*) AS c FROM users WHERE role='student'")
            students = cur.fetchone()['c']
            cur.execute("SELECT COUNT(*) AS c FROM buses")
            buses = cur.fetchone()['c']
            cur.execute("SELECT COUNT(*) AS c FROM trips WHERE service_date = CURDATE()")
            trips = cur.fetchone()['c']
            cur.execute("SELECT COUNT(*) AS c FROM gps_points WHERE ts > NOW() - INTERVAL 10 MINUTE")
            live = cur.fetchone()['c']
            return {"ok": True, "students": students, "buses": buses, "today_trips": trips, "active_gps": live}
    finally: release_conn(conn)

@app.websocket("/ws/gps")
async def websocket_gps(websocket: WebSocket, role: str = "student"):
    """
    WebSocket endpoint. Clients connect here to receive real-time GPS pushes.
    The server broadcasts vehicle positions every GPS_BROADCAST_INTERVAL seconds.
    The client can also send {"type": "ping"} to keep the connection alive.
    """
    await ws_manager.connect(websocket, role=role)
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

def serialize_val(v):
    if v is None: return None
    if isinstance(v, (datetime, date)): return v.isoformat()
    return v

# ─────────────────────── VOICE ASSISTANT LLM ───────────────────────────────
class VoiceTranscriptRequest(BaseModel):
    transcript: str
# ────────────────── FUEL & MAINTENANCE LOGS ──────────────────────────────
class FuelLog(BaseModel):
    bus_id: int
    fuel_liters: float
    cost: float
    odometer: float

@app.post("/api/admin/fuel")
def add_fuel_log(log: FuelLog):
    conn = get_conn()
    try:
        with conn.cursor() as cur:
            sql = "INSERT INTO fuel_logs (bus_id, fuel_liters, cost, odometer, ts) VALUES (%s, %s, %s, %s, NOW())"
            cur.execute(sql, (log.bus_id, log.fuel_liters, log.cost, log.odometer))
            conn.commit()
            return {"ok": True}
    finally: release_conn(conn)

class MaintLog(BaseModel):
    bus_id: int
    description: str
    cost: float
    parts_replaced: str | None = None

@app.post("/api/admin/maintenance")
def add_maintenance_log(log: MaintLog):
    conn = get_conn()
    try:
        with conn.cursor() as cur:
            sql = "INSERT INTO maintenance_logs (bus_id, description, cost, parts_replaced, ts) VALUES (%s, %s, %s, %s, NOW())"
            cur.execute(sql, (log.bus_id, log.description, log.cost, log.parts_replaced))
            conn.commit()
            return {"ok": True}
    finally: release_conn(conn)

@app.get("/api/system/config")
def get_system_config():
    """Returns global app configuration for frontend."""
    return {
        "app_name": "WhereIsMyBus",
        "version": "2.4.0",
        "support_email": "support@whereismybus.com",
        "features": {
            "realtime_tracking": True,
            "voice_assistant": True,
            "admin_dashboard": True,
            "fuel_tracking": True
        }
    }


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)

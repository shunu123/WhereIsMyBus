# 🚌 WhereIsMyBus

A next-generation college bus tracking system designed for high performance and real-time visualization.

## 🚀 Key Features

### ⚡ Performance Optimizations
- **Quadtree Spatial Index**: Efficiently manages thousands of map markers by partitioning space, ensuring smooth interaction regardless of fleet size.
- **Marker Clustering**: Automatically groups nearby buses into clusters at lower zoom levels, reducing visual clutter and CPU usage.
- **Lazy Loading (Pagination)**: The bus list is loaded in batches of 5 with on-scroll fetching, ensuring instantaneous UI responsiveness.

### 📍 Real-Time Tracking
- **Live Telemetry**: Real-time GPS updates delivered via WebSocket.
- **Visual Routes**: Dynamic map visualization of bus routes and active stops.
- **Chennai-Specific Testing**: Pre-seeded with realistic data for Chennai transit routes.

## 📂 Project Structure

```text
WhereIsMyBus/
├── frontend/             # iOS Application (Swift/SwiftUI)
│   ├── WhereIsMyBus.xcodeproj
│   ├── ViewModels/       # Business logic and state management
│   ├── Services/         # Networking and tracking algorithms
│   └── ...
├── backend/              # Python API (FastAPI)
│   ├── main.py           # Core backend logic
│   ├── requirements.txt  # Python dependencies
│   └── database/         # SQL Schema and Data Seeding
│       ├── college_bus.sql
│       ├── routes.sql
│       └── chennai_dummy_data.sql
└── README.md
```

## 🛠️ Setup Instructions

### Backend
1. Ensure Python 3.x is installed.
2. Navigate to `backend/`: `cd backend`
3. Install dependencies: `pip install -r requirements.txt`
4. Setup your MySQL/MariaDB database and import the SQL files from `backend/database/`.
5. Update `DB_CONFIG` in `main.py` with your credentials.
6. Run the server: `python main.py`

### Frontend (iOS)
1. Open `frontend/WhereIsMyBus.xcodeproj` in Xcode.
2. Ensure you are targeting a device or simulator with iOS 16.0+.
3. Update `APIConfig.swift` to point to your backend server URL.
4. Build and Run (⌘R).

## 📄 License
This project is for educational and testing purposes for college transit systems.

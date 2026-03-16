import { useRef, useEffect, useState } from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import { getStops, searchTrips, getRouteStops } from '../services/api';
import { Moon, Sun, Type } from 'lucide-react';

// New Components
import MapContainer from '../components/MapContainer';
import SearchInput from '../components/Sidebar/SearchInput';
import BusList from '../components/Sidebar/BusList';
import LiveTrackingView from '../components/Sidebar/LiveTrackingView';
import AnimatedLoader from '../components/AnimatedLoader';

// V3 Specific Components
import FloatingSearchBar from '../components/Sidebar/FloatingSearchBar';
import CategoryChips from '../components/CategoryChips';
import MapControlsUI from '../components/MapControlsUI';
import UserProfile from '../components/UserProfile'; // Import Profile

// Haversine Distance Formula (km)
const calculateDistance = (lat1, lon1, lat2, lon2) => {
    const R = 6371; // Earth radius in km
    const dLat = (lat2 - lat1) * Math.PI / 180;
    const dLon = (lon2 - lon1) * Math.PI / 180;
    const a = Math.sin(dLat / 2) * Math.sin(dLat / 2) +
        Math.cos(lat1 * Math.PI / 180) * Math.cos(lat2 * Math.PI / 180) *
        Math.sin(dLon / 2) * Math.sin(dLon / 2);
    const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
    return R * c;
};

const Dashboard = () => {
    const [stops, setStops] = useState([]);
    const [search, setSearch] = useState({ from: '', to: '', fromTitle: '', toTitle: '' });
    const [suggestions, setSuggestions] = useState({ from: [], to: [] });
    const [buses, setBuses] = useState([]);
    const [selectedBus, setSelectedBus] = useState(null);
    const [routeStops, setRouteStops] = useState([]);
    const [loading, setLoading] = useState(false);
    const [wsData, setWsData] = useState({});
    const [tripStats, setTripStats] = useState({ distance: 0, duration: 0 });
    const [theme, setTheme] = useState('light');
    const [fontSize, setFontSize] = useState(16);
    
    // UI State: 'SEARCH', 'RESULTS', 'TRACKING'
    const [viewState, setViewState] = useState('SEARCH');
    const [isSidebarOpen, setIsSidebarOpen] = useState(false);
    const [activeCategory, setActiveCategory] = useState(null);
    const [searchText, setSearchText] = useState('');

    const mapRef = useRef(null);

    // Initial Fetch
    useEffect(() => {
        const fetchStops = async () => {
            try {
                const res = await getStops();
                if (res) setStops(res);
            } catch (err) {
                console.error("Error fetching stops:", err);
            }
        };
        fetchStops();

        // WebSocket Simulation/Connection
        const ws = new WebSocket('ws://127.0.0.1:8000/ws/gps');
        ws.onmessage = (event) => {
            try {
                const data = JSON.parse(event.data);
                if (Array.isArray(data)) {
                    const updates = {};
                    data.forEach(v => {
                        updates[v.vid] = { lat: v.lat, lon: v.lon, spd: v.spd, hdg: v.hdg };
                    });
                    setWsData(updates);
                } else {
                    console.warn("WS received non-array data:", data);
                }
            } catch (e) {
                console.error("WS error parsing data", e);
            }
        };
        return () => ws.close();
    }, []);

    // Theme and Accessibility Sync
    useEffect(() => {
        if (theme === 'light') document.documentElement.classList.add('light');
        else document.documentElement.classList.remove('light');
        return () => document.documentElement.classList.remove('light');
    }, [theme]);

    useEffect(() => {
        document.documentElement.style.setProperty('--base-font-size', `${fontSize}px`);
    }, [fontSize]);

    const handleSearchInput = (type, val) => {
        if (type === 'fromFocus' || type === 'toFocus') return; 
        
        setSearch(prev => ({ ...prev, [type]: val }));
        if (val.length > 1) {
            const filtered = stops.filter(s => s.name.toLowerCase().includes(val.toLowerCase())).slice(0, 5);
            setSuggestions(prev => ({ ...prev, [type]: filtered }));
        } else {
            setSuggestions(prev => ({ ...prev, [type]: [] }));
        }
    };

    const selectSuggestion = (type, stop) => {
        setSearch(prev => ({ ...prev, [type]: stop.id, [`${type}Title`]: stop.name }));
        setSuggestions(prev => ({ ...prev, [type]: [] }));
    };

    const handleSearch = async () => {
        if (!searchText && (!search.from || !search.to)) return;
        setLoading(true);
        setViewState('RESULTS');
        setIsSidebarOpen(true); // Open drawer on search
        try {
            const res = await searchTrips(search.from || stops[0]?.id, search.to || stops[5]?.id);
            if (res) {
                const fromStop = stops.find(s => s.id === parseInt(search.from));
                const toStop = stops.find(s => s.id === parseInt(search.to));
                
                if (fromStop && toStop) {
                    const dist = calculateDistance(fromStop.lat, fromStop.lng, toStop.lat, toStop.lng);
                    setTripStats({ distance: dist.toFixed(2), duration: res[0]?.duration_minutes || 45 });
                }
                setBuses(res);
            }
        } catch (err) {
            console.error("Search error:", err);
        } finally {
            setLoading(false);
        }
    };

    const handleBusClick = async (bus) => {
        setSelectedBus(bus);
        setViewState('TRACKING');
        try {
            const stopsRes = await getRouteStops(bus.ext_route_id, 'Up');
            if (stopsRes) {
                setRouteStops(stopsRes);
                if (mapRef.current) {
                    const coords = stopsRes.map(s => [s.lon, s.lat]).filter(c => c[0] && c[1]);
                    if (coords.length > 0) mapRef.current.fitBounds(coords, { padding: 80 });
                }
            }
        } catch (err) {
            console.error("Error fetching route stops:", err);
        }
    };

    return (
        <div className="gm-layout">
            {/* TOP RIGHT PROFILE */}
            <div className="absolute top-3 right-3 z-9999">
                <UserProfile />
            </div>

            {/* V3 SEARCH CONTAINER */}
            <div className="gm-v3-search-container">
                <FloatingSearchBar 
                    onMenuClick={() => setIsSidebarOpen(!isSidebarOpen)}
                    value={searchText}
                    onChange={setSearchText}
                    onSearch={handleSearch}
                />
                <CategoryChips 
                    activeCategory={activeCategory}
                    onCategoryChange={setActiveCategory}
                />
            </div>

            {/* V3 MAP CONTROLS */}
            <MapControlsUI 
                onZoomIn={() => mapRef.current?.zoomIn()}
                onZoomOut={() => mapRef.current?.zoomOut()}
                onLocate={() => mapRef.current?.locate()}
                onLayers={() => console.log('Layers clicked')}
            />

            {/* FULL SCREEN MAP */}
            <MapContainer 
                ref={mapRef}
                theme={theme}
                buses={buses}
                routeStops={routeStops}
                selectedBus={selectedBus}
                wsData={wsData}
                onMarkerClick={handleBusClick}
                selectedStops={[
                    (stops || []).find(s => s.id == search.from),
                    (stops || []).find(s => s.id == search.to)
                ]}
            />

            {/* DRAWER SIDEBAR */}
            <div className={`gm-sidebar ${isSidebarOpen ? 'open' : ''}`}>
                <div className="p-4 flex items-center justify-between border-b border-[var(--border)]">
                    <h3 className="font-bold text-lg text-[var(--text-1)]">College Bus Routes</h3>
                    <button 
                        onClick={() => setIsSidebarOpen(false)}
                        className="p-2 hover:bg-[var(--surface-hover)] rounded-full text-[var(--text-3)]"
                    >
                        ✕
                    </button>
                </div>

                <div className="gm-sidebar-content h-[calc(100%-130px)] overflow-y-auto p-4">
                    <AnimatePresence mode="wait">
                        {viewState !== 'TRACKING' ? (
                            <motion.div 
                                key="plan-journey"
                                className="flex flex-col gap-4 h-full"
                            >
                                <SearchInput 
                                    search={search}
                                    suggestions={suggestions}
                                    onInputChange={handleSearchInput}
                                    onSelectSuggestion={selectSuggestion}
                                    onSearch={handleSearch}
                                    loading={loading}
                                />
                                
                                <div className="mt-2 flex-1">
                                    {buses.length > 0 ? (
                                        <BusList 
                                            buses={buses}
                                            onBusClick={handleBusClick}
                                            tripStats={tripStats}
                                            onBack={() => setBuses([])} // Reset buses to go back
                                        />
                                    ) : (
                                        <div className="space-y-4">
                                            <h4 className="text-xs font-bold text-[var(--text-3)] uppercase tracking-wider">Recent Searches</h4>
                                            <div className="flex flex-col gap-2">
                                                {['Campus Gate → Hostel', 'Admin Block → Mess Hall'].map((s, i) => (
                                                    <div key={i} className="p-3 bg-[var(--surface-hover)] rounded-xl text-sm text-[var(--text-2)] hover:bg-[var(--surface-bright)] cursor-pointer transition-colors flex items-center gap-2">
                                                        <div className="w-1.5 h-1.5 rounded-full bg-blue-500"></div>
                                                        <span>{s}</span>
                                                    </div>
                                                ))}
                                            </div>

                                            <h4 className="text-xs font-bold text-[var(--text-3)] uppercase tracking-wider mt-6">Nearby Stops</h4>
                                            <div className="flex flex-col gap-2">
                                                {(stops || []).slice(0, 3).map((s) => (
                                                    <div key={s.id} className="p-3 bg-[var(--surface-hover)] rounded-xl text-sm text-[var(--text-2)] hover:bg-[var(--surface-bright)] cursor-pointer transition-colors flex items-center justify-between">
                                                        <span>{s.name}</span>
                                                        <span className="text-xs text-[var(--text-4)]">200m</span>
                                                    </div>
                                                ))}
                                            </div>
                                        </div>
                                    )}
                                </div>
                            </motion.div>
                        ) : (
                            <motion.div 
                                key="tracking"
                                initial={{ opacity: 0 }}
                                animate={{ opacity: 1 }}
                                exit={{ opacity: 0 }}
                                className="h-full"
                            >
                                <LiveTrackingView 
                                    selectedBus={selectedBus}
                                    routeStops={routeStops}
                                    wsData={wsData}
                                    tripStats={tripStats}
                                    onBack={() => setViewState('SEARCH')} // Back to search list
                                />
                            </motion.div>
                        )}
                    </AnimatePresence>
                </div>

                {/* Bottom Tools */}
                <div className="p-4 bg-[var(--bg-subtle)] border-t border-[var(--border)] flex items-center justify-between">
                    <div className="flex items-center gap-3">
                        <button 
                            className="w-8 h-8 rounded-full bg-[var(--surface)] border border-[var(--border)] flex items-center justify-center text-[var(--text-3)] hover:text-white transition-colors"
                            onClick={() => setTheme(t => t === 'light' ? 'dark' : 'light')}
                        >
                            {theme === 'light' ? <Moon size={14} /> : <Sun size={14} />}
                        </button>
                    </div>
                    <span className="text-[10px] font-bold text-[var(--text-4)] uppercase tracking-widest">v3.0 Premium</span>
                </div>
            </div>
        </div>
    );
};

export default Dashboard;

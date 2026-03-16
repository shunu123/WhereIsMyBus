import React, { forwardRef } from 'react';
import { Map, MapMarker, MarkerContent, MarkerPopup, MapControls, MapRoute } from '@/components/ui/map';
import { Navigation } from 'lucide-react';

const MapContainer = forwardRef(({ 
  theme, 
  buses, 
  routeStops, 
  selectedBus, 
  wsData,
  onMarkerClick,
  selectedStops = [] // Add prop for [fromStop, toStop]
}, ref) => {
  
  const getLivePos = (bus) => {
    const live = wsData[bus.bus_no];
    if (live && live.lat && live.lon) return [live.lon, live.lat];
    if (bus.latitude && bus.longitude) return [bus.longitude, bus.latitude];
    return [77.2090, 28.6139]; // Default fallback
  };

  const getHeading = (bus) => {
    const live = wsData[bus.bus_no];
    return live?.hdg || 0;
  };

  // Calculate bus progress along routeStops
  const getProgressStops = () => {
    if (!selectedBus || !routeStops.length) return [];
    
    const pos = getLivePos(selectedBus);
    let nearestIdx = 0;
    let minDist = Infinity;

    // Find the nearest stop to the current bus position
    routeStops.forEach((stop, idx) => {
        const d = Math.sqrt(Math.pow(stop.lon - pos[0], 2) + Math.pow(stop.lat - pos[1], 2));
        if (d < minDist) {
            minDist = d;
            nearestIdx = idx;
        }
    });

    // In a real app, you'd also check if the bus has "passed" the stop.
    // For this UI, we'll show progress up to the nearest stop.
    return routeStops.slice(0, nearestIdx + 1);
  };

  const currentProgressCoords = getProgressStops().map(s => [s.lon, s.lat]);

  return (
    <div className="gm-map-container">
      <Map
        ref={ref}
        viewport={{
          center: [80.2707, 13.0827], // Default to Chennai area
          zoom: 12
        }}
        theme={theme}
      >

        {/* Planned Route (Grey/Static) */}
        {routeStops.length > 0 && (
          <MapRoute
            coordinates={routeStops.map(s => [s.lon, s.lat])}
            color="#4b5563"
            width={6}
            opacity={0.3}
          />
        )}

        {/* Progress Route (Active/Colored) */}
        {selectedBus && currentProgressCoords.length > 0 && (
          <MapRoute
            coordinates={currentProgressCoords}
            color="#6366f1"
            width={6}
            opacity={0.8}
          />
        )}

        {/* Bus Markers */}
        {buses.map((bus, index) => {
          const pos = getLivePos(bus);
          const heading = getHeading(bus);
          const isSelected = selectedBus?.trip_id === bus.trip_id;

          return (
            <MapMarker
              key={`bus-marker-${bus.trip_id}-${index}`}
              longitude={pos[0]}
              latitude={pos[1]}
              onClick={() => onMarkerClick(bus)}
            >
              <MarkerContent>
                <div 
                  className={`transition-all duration-500 flex items-center justify-center ${isSelected ? 'scale-125' : 'scale-100'}`}
                  style={{ transform: `rotate(${heading}deg)` }}
                >
                  <div className={`w-8 h-8 rounded-full flex items-center justify-center shadow-2xl border-2 ${isSelected ? 'bg-[var(--accent)] border-white' : 'bg-white border-[var(--accent)]'}`}>
                    <Navigation 
                      size={16} 
                      className={isSelected ? 'text-white' : 'text-[var(--accent)]'} 
                      fill="currentColor"
                    />
                  </div>
                </div>
              </MarkerContent>
              <MarkerPopup>
                <div className="p-2 min-w-[120px]">
                  <h4 className="font-black text-sm text-[var(--accent)] mb-1">Bus #{bus.bus_no}</h4>
                  <p className="text-[10px] font-bold text-gray-500 uppercase">{bus.route_name}</p>
                </div>
              </MarkerPopup>
            </MapMarker>
          );
        })}

        {/* Stop Markers */}
        {routeStops.map((stop, idx) => (
          <MapMarker
            key={`stop-marker-${stop.stpid}-${idx}`}
            longitude={stop.lon}
            latitude={stop.lat}
          >
            <MarkerContent>
              <div className="w-3 h-3 rounded-full bg-white border-2 border-gray-400 shadow-sm" />
            </MarkerContent>
            <MarkerPopup>
              <span className="text-xs font-bold">{stop.stpnm}</span>
            </MarkerPopup>
          </MapMarker>
        ))}

        {/* Selected Search Stops (From/To) */}
        {selectedStops.map((stop, sidx) => stop && (
          <MapMarker
            key={`selected-stop-${stop.id}-${sidx}`}
            longitude={stop.lon}
            latitude={stop.lat}
          >
            <MarkerContent>
              <div className={`w-4 h-4 rounded-full flex items-center justify-center ${sidx === 0 ? 'bg-green-500' : 'bg-red-500'} border-2 border-white shadow-lg text-white font-bold text-[8px]`}>
                 {sidx === 0 ? 'S' : 'D'}
              </div>
            </MarkerContent>
            <MarkerPopup>
              <span className="text-xs font-black">{sidx === 0 ? 'From' : 'To'}: {stop.name}</span>
            </MarkerPopup>
          </MapMarker>
        ))}
      </Map>
    </div>
  );
});

export default MapContainer;

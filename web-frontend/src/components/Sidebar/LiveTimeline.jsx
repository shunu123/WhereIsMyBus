import React from 'react';
import { MapPin, Clock } from 'lucide-react';

const LiveTimeline = ({ routeStops, selectedBus, tripDuration }) => {
  // Rough estimation of progress based on mock logic or actual data
  const currentStopIndex = 1; // This would typically come from bus props or backend
  
  return (
    <div className="gm-timeline ml-1">
      {routeStops.map((stop, idx) => {
        const isCompleted = idx < currentStopIndex;
        const isActive = idx === currentStopIndex;
        const minutesPerStop = tripDuration / (routeStops.length || 1);
        const eta = Math.round((idx - currentStopIndex) * minutesPerStop);

        return (
          <div 
            key={`${stop.stpid}-${idx}`} 
            className={`gm-timeline-item ${isCompleted ? 'completed' : ''} ${isActive ? 'active' : ''}`}
          >
            <div className="gm-timeline-dot"></div>
            
            <div className="flex-1 -mt-1">
              <div className="flex items-center justify-between mb-0.5">
                <h4 className={`text-sm font-bold transition-all ${isActive ? 'text-white scale-105 origin-left' : isCompleted ? 'text-[var(--text-3)]' : 'text-[var(--text-2)]'}`}>
                  {stop.stpnm}
                </h4>
                {!isCompleted && !isActive && (
                  <span className="text-[10px] font-black text-[var(--text-4)]">+{eta}m</span>
                )}
                {isActive && (
                  <span className="text-[10px] font-black text-[#4ade80] animate-pulse">ARRIVING</span>
                )}
              </div>
              
              <div className="flex items-center gap-2">
                {isActive ? (
                  <p className="text-[10px] font-bold text-[var(--accent)] uppercase tracking-wider">Current Stop</p>
                ) : isCompleted ? (
                  <p className="text-[10px] font-bold text-[var(--text-4)] uppercase tracking-wider">Passed</p>
                ) : (
                  <p className="text-[10px] font-bold text-[var(--text-4)] uppercase tracking-wider">Upcoming</p>
                )}
              </div>
            </div>
          </div>
        );
      })}
    </div>
  );
};

export default LiveTimeline;

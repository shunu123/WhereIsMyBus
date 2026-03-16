import React from 'react';
import { Bus, Clock, MapPin, ChevronRight } from 'lucide-react';

const BusCard = ({ bus, onClick }) => {
  const eta = bus.eta || Math.floor(Math.random() * 15) + 1;
  const isDelayed = Math.random() > 0.8;

  return (
    <div 
      className="gm-bus-card group"
      onClick={onClick}
    >
      <div className="flex items-start justify-between mb-4">
        <div className="flex items-center gap-3">
          <div className="w-10 h-10 bg-[var(--accent)] rounded-lg flex items-center justify-center text-white shadow-lg shadow-indigo-500/20">
            <Bus size={20} />
          </div>
          <div>
            <h4 className="font-bold text-[var(--text-1)] text-base">Bus #{bus.bus_no}</h4>
            <span className="text-xs font-medium text-[var(--text-3)]">{bus.route_name}</span>
          </div>
        </div>
        <div className="text-right">
          <span className="text-xl font-black text-[#4ade80]">{eta}m</span>
          <p className="text-[10px] font-bold text-[var(--text-4)] uppercase tracking-tighter">ETA</p>
        </div>
      </div>

      <div className="space-y-3 mb-4">
        <div className="flex items-center gap-3 text-sm">
          <div className="w-2 h-2 rounded-full bg-[var(--text-4)]" />
          <span className="text-[var(--text-2)] font-medium truncate">
            {bus.current_stop_name || 'In Transit'}
          </span>
        </div>
        <div className="flex items-center gap-3 text-sm">
          <MapPin size={14} className="text-[var(--accent)]" />
          <span className="text-[var(--text-1)] font-bold truncate">
            {bus.next_stop_name || 'Terminal'}
          </span>
        </div>
      </div>

      <div className="flex items-center justify-between pt-3 border-t border-[var(--border)]">
        <div className="flex gap-2">
          {isDelayed && (
            <span className="px-2 py-0.5 bg-red-500/10 text-red-500 text-[10px] font-bold rounded-md uppercase">
              Delayed
            </span>
          )}
          <span className="px-2 py-0.5 bg-[var(--surface-bright)] text-[var(--text-3)] text-[10px] font-bold rounded-md uppercase">
            A/C Bus
          </span>
        </div>
        <ChevronRight size={16} className="text-[var(--text-4)] group-hover:text-[var(--accent)] transition-colors" />
      </div>
    </div>
  );
};

export default BusCard;

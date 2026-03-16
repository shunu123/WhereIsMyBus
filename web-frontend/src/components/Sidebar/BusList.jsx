import React from 'react';
import { ArrowLeft, Bus } from 'lucide-react';
import BusCard from './BusCard';

const BusList = ({ buses, onBusClick, onBack, loading, tripStats }) => {
  return (
    <div className="flex flex-col h-full">
      <div className="flex items-center gap-4 mb-6">
        <button 
          onClick={onBack}
          className="p-2 hover:bg-[var(--surface-hover)] rounded-full transition-all text-[var(--text-2)]"
        >
          <ArrowLeft size={20} />
        </button>
        <div>
          <h2 className="text-xl font-bold text-[var(--text-1)]">Suggested Routes</h2>
          {tripStats.distance > 0 && (
            <p className="text-xs font-bold text-[var(--accent)] uppercase tracking-wider mt-0.5">
              {tripStats.distance} KM • ~{tripStats.duration} MINS
            </p>
          )}
        </div>
      </div>

      <div className="flex-1 overflow-y-auto pr-1">
        {buses.length > 0 ? (
          buses.map((bus, idx) => (
            <BusCard 
              key={`${bus.trip_id}-${bus.bus_no}-${idx}`} 
              bus={bus} 
              onClick={() => onBusClick(bus)} 
            />
          ))
        ) : (
          <div className="text-center py-12">
            <div className="w-16 h-16 bg-[var(--surface)] rounded-full flex items-center justify-center mx-auto mb-4">
              <Bus size={24} className="text-[var(--text-4)]" />
            </div>
            <p className="text-[var(--text-3)] text-sm">No buses found for this route.</p>
          </div>
        )}
      </div>
    </div>
  );
};

export default BusList;

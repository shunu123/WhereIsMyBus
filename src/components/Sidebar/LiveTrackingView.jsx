import React, { useEffect } from 'react';
import { ArrowLeft, Clock, Info, Navigation2 } from 'lucide-react';
import LiveTimeline from './LiveTimeline';

const LiveTrackingView = ({ selectedBus, routeStops, onBack, tripStats, wsData }) => {
  const liveStats = wsData[selectedBus?.bus_no] || {};
  
  return (
    <div className="flex flex-col h-full bg-[var(--surface-bright)] rounded-3xl overflow-hidden border border-[var(--border)] shadow-2xl">
      <div className="bg-gradient-to-br from-[var(--bg-subtle)] to-[var(--surface-hover)] p-6 border-b border-[var(--border)] relative overflow-hidden">
        {/* Abstract Background Decoration */}
        <div className="absolute top-[-20%] right-[-10%] w-32 h-32 bg-[var(--accent)] opacity-[0.03] blur-3xl rounded-full"></div>
        
        <div className="flex items-center gap-4 relative z-10">
          <button 
            onClick={onBack}
            className="p-2.5 bg-white/5 hover:bg-white/10 rounded-xl transition-all text-white border border-white/5"
          >
            <ArrowLeft size={18} />
          </button>
          <div>
            <div className="flex items-center gap-2">
              <span className="px-2 py-0.5 bg-[var(--accent)] text-white text-[10px] font-black rounded uppercase tracking-widest">Live</span>
              <h2 className="text-xl font-black text-white">#{selectedBus?.bus_no}</h2>
            </div>
            <p className="text-xs font-bold text-[var(--text-3)] uppercase tracking-wide truncate max-w-[200px]">
              {selectedBus?.route_name}
            </p>
          </div>
        </div>

        <div className="grid grid-cols-2 gap-3 mt-6 relative z-10">
          <div className="bg-white/5 border border-white/5 rounded-2xl p-3">
            <p className="text-[10px] font-black text-[var(--text-4)] uppercase tracking-widest mb-1">Speed</p>
            <div className="flex items-end gap-1">
              <span className="text-xl font-black text-white leading-none">{liveStats.spd || selectedBus?.speed || 0}</span>
              <span className="text-[10px] font-bold text-[var(--text-3)] pb-0.5">KM/H</span>
            </div>
          </div>
          <div className="bg-white/5 border border-white/5 rounded-2xl p-3">
            <p className="text-[10px] font-black text-[var(--text-4)] uppercase tracking-widest mb-1">Status</p>
            <div className="flex items-center gap-1.5">
              <div className="w-1.5 h-1.5 rounded-full bg-[#4ade80] animate-pulse"></div>
              <span className="text-sm font-bold text-white">Active</span>
            </div>
          </div>
        </div>
      </div>

      <div className="flex-1 overflow-y-auto p-6 scrollbar-hide">
        <div className="mb-6 flex items-center justify-between text-xs font-bold uppercase tracking-widest text-[var(--text-4)]">
          <span>Route Progress</span>
          <span>{tripStats.duration} Min Trip</span>
        </div>
        
        <LiveTimeline 
            routeStops={routeStops} 
            selectedBus={selectedBus}
            tripDuration={tripStats.duration}
        />
      </div>

      <div className="p-4 bg-[var(--bg-subtle)] border-t border-[var(--border)]">
        <button className="w-full py-3.5 bg-[var(--surface-bright)] hover:bg-[var(--surface-hover)] text-white text-xs font-black rounded-xl border border-[var(--border)] transition-all flex items-center justify-center gap-2 tracking-widest uppercase">
          <Info size={14} className="text-[var(--accent)]" />
          <span>Report Issue</span>
        </button>
      </div>
    </div>
  );
};

export default LiveTrackingView;

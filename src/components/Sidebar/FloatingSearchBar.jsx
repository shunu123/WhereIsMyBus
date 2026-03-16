import React from 'react';
import { Menu, Search, Mic, Map } from 'lucide-react';

const FloatingSearchBar = ({ onMenuClick, value, onChange, onSearch }) => {
  return (
    <div className="gm-v3-search-bar">
      <button 
        onClick={onMenuClick}
        className="p-1 hover:bg-[var(--surface-hover)] rounded-full transition-colors text-[var(--text-2)]"
      >
        <Menu size={20} />
      </button>
      
      <input 
        type="text" 
        className="gm-v3-search-input"
        placeholder="Search routes or stops..."
        value={value}
        onChange={(e) => onChange(e.target.value)}
        onKeyDown={(e) => e.key === 'Enter' && onSearch()}
      />
      
      <div className="flex items-center gap-2 border-l border-[var(--border)] pl-4 ml-2">
        <button className="p-1.5 text-[var(--accent)] hover:bg-[var(--surface-hover)] rounded-full transition-colors">
          <Search size={20} onClick={onSearch} />
        </button>
        <div className="w-[1px] h-4 bg-[var(--border)] mx-1" />
        <button className="p-1.5 text-[var(--text-3)] hover:bg-[var(--surface-hover)] rounded-full transition-colors">
          <Map size={20} />
        </button>
      </div>
    </div>
  );
};

export default FloatingSearchBar;

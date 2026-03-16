import React from 'react';
import { Search, MapPin, Navigation } from 'lucide-react';

const SearchInput = ({ 
  search, 
  suggestions, 
  onInputChange, 
  onSelectSuggestion, 
  onSearch, 
  loading 
}) => {
  return (
    <div className="flex flex-col gap-4">
      <div className="panel-header mb-2">
        <h2 className="text-2xl font-black text-[var(--text-1)] tracking-tight">Plan Journey</h2>
        <p className="text-sm text-[var(--text-3)] font-medium">Find the best bus route for your trip.</p>
      </div>

      <div className="gm-search-box space-y-4">
        {/* Source Input */}
        <div className="relative">
          <div className="absolute left-3 top-3.5 text-[var(--accent)]">
            <MapPin size={18} />
          </div>
          <input
            type="text"
            className="w-full pl-10 pr-4 py-3 bg-[var(--bg-subtle)] border border-[var(--border)] rounded-xl text-sm focus:border-[var(--accent)] transition-all outline-none"
            placeholder="Starting from..."
            value={search.fromTitle || search.from}
            onChange={(e) => onInputChange('from', e.target.value)}
            onFocus={() => onInputChange('fromFocus', true)}
          />
          {suggestions.from.length > 0 && (
            <div className="absolute left-0 right-0 top-full mt-2 bg-[var(--surface-bright)] border border-[var(--border)] rounded-xl shadow-2xl z-[110] overflow-hidden">
              {suggestions.from.map(s => (
                <div 
                  key={s.id} 
                  className="px-4 py-3 hover:bg-[var(--surface-hover)] cursor-pointer text-sm border-b border-[var(--border)] last:border-0 flex items-center gap-3"
                  onClick={() => onSelectSuggestion('from', s)}
                >
                  <MapPin size={14} className="text-[var(--text-4)]" />
                  <span>{s.name}</span>
                </div>
              ))}
            </div>
          )}
        </div>

        {/* Connector Line */}
        <div className="ml-5 h-4 border-l-2 border-dashed border-[var(--border)]"></div>

        {/* Destination Input */}
        <div className="relative">
          <div className="absolute left-3 top-3.5 text-[var(--accent)]">
            <Navigation size={18} />
          </div>
          <input
            type="text"
            className="w-full pl-10 pr-4 py-3 bg-[var(--bg-subtle)] border border-[var(--border)] rounded-xl text-sm focus:border-[var(--accent)] transition-all outline-none"
            placeholder="Going to..."
            value={search.toTitle || search.to}
            onChange={(e) => onInputChange('to', e.target.value)}
            onFocus={() => onInputChange('toFocus', true)}
          />
          {suggestions.to.length > 0 && (
            <div className="absolute left-0 right-0 top-full mt-2 bg-[var(--surface-bright)] border border-[var(--border)] rounded-xl shadow-2xl z-[110] overflow-hidden">
              {suggestions.to.map(s => (
                <div 
                  key={s.id} 
                  className="px-4 py-3 hover:bg-[var(--surface-hover)] cursor-pointer text-sm border-b border-[var(--border)] last:border-0 flex items-center gap-3"
                  onClick={() => onSelectSuggestion('to', s)}
                >
                  <MapPin size={14} className="text-[var(--text-4)]" />
                  <span>{s.name}</span>
                </div>
              ))}
            </div>
          )}
        </div>
      </div>

      <button 
        className="w-full py-4 bg-[var(--text-1)] text-[var(--bg)] font-bold rounded-2xl hover:opacity-90 transition-all flex items-center justify-center gap-2 shadow-lg"
        onClick={onSearch}
        disabled={loading || !search.from || !search.to}
      >
        {loading ? (
          <div className="w-5 h-5 border-2 border-[var(--bg)] border-t-transparent rounded-full animate-spin"></div>
        ) : (
          <>
            <Search size={18} />
            <span>Search Available Buses</span>
          </>
        )}
      </button>
    </div>
  );
};

export default SearchInput;

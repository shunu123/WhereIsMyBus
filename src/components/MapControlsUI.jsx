import React from 'react';
import { Plus, Minus, Crosshair, Layers } from 'lucide-react';

const MapControlsUI = ({ onZoomIn, onZoomOut, onLocate, onLayers }) => {
  return (
    <div className="gm-v3-controls-container">
      <div className="gm-v3-control-group">
        <button onClick={onZoomIn} className="gm-v3-control-btn" title="Zoom In">
          <Plus size={20} />
        </button>
        <button onClick={onZoomOut} className="gm-v3-control-btn" title="Zoom Out">
          <Minus size={20} />
        </button>
      </div>

      <div className="gm-v3-control-group">
        <button onClick={onLocate} className="gm-v3-control-btn" title="My Location">
          <Crosshair size={20} />
        </button>
      </div>

      <div className="gm-v3-control-group">
        <button onClick={onLayers} className="gm-v3-control-btn" title="Layers">
          <Layers size={20} />
        </button>
      </div>
    </div>
  );
};

export default MapControlsUI;

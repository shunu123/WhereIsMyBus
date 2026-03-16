import React from 'react';
import RealisticGlobe from './RealisticGlobe';

const MapBackground = () => {
    return (
        <div className="map-bg" style={{ position: 'absolute', inset: 0, zIndex: 0, overflow: 'hidden' }}>
            <RealisticGlobe />
        </div>
    );
};

export default MapBackground;

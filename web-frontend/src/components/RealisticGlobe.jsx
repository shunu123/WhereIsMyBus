import React, { useEffect, useRef, useState } from 'react';
import Globe from 'react-globe.gl';

// High-res realistic earth textures
const EARTH_TEXTURE = '//unpkg.com/three-globe/example/img/earth-blue-marble.jpg';
const NIGHT_TEXTURE = '//unpkg.com/three-globe/example/img/earth-night.jpg';
const BUMP_MAP = '//unpkg.com/three-globe/example/img/earth-topology.png';

const RealisticGlobe = () => {
    const globeRef = useRef();
    const [containerWidth, setContainerWidth] = useState(window.innerWidth);
    const [containerHeight, setContainerHeight] = useState(window.innerHeight);

    // Update window size
    useEffect(() => {
        const handleResize = () => {
            setContainerWidth(window.innerWidth);
            setContainerHeight(window.innerHeight);
        };
        window.addEventListener('resize', handleResize);
        return () => window.removeEventListener('resize', handleResize);
    }, []);

    useEffect(() => {
        // Wait for the globe to initialize before accessing controls
        const initGlobe = () => {
            if (!globeRef.current) return;

            try {
                const controls = globeRef.current.controls();
                if (controls) {
                    controls.autoRotate = true;
                    controls.autoRotateSpeed = 0.5;
                    controls.enableZoom = false;
                    controls.enablePan = false;
                }

                // Position camera over India
                globeRef.current.pointOfView({ lat: 20, lng: 80, altitude: 1.5 });
            } catch (e) {
                console.error("Error configuring globe controls", e);
            }
        };

        // Small timeout ensures the ThreeJS canvas is mounted
        setTimeout(initGlobe, 100);
    }, []);

    return (
        <div style={{ position: 'absolute', inset: 0, zIndex: 0, overflow: 'hidden', background: '#020202' }}>

            {/* 
                We use the night texture as the base because it has the glowing city lights built-in.
                This is the safest, most stable way to get the "Apple Maps night side" look 
                without writing custom WebGL shaders that crash the browser.
            */}
            <Globe
                ref={globeRef}
                width={containerWidth}
                height={containerHeight}
                globeImageUrl={NIGHT_TEXTURE}
                bumpImageUrl={BUMP_MAP}
                showAtmosphere={true}
                atmosphereColor="#5882ff"
                atmosphereAltitude={0.15}
                backgroundColor="rgba(0,0,0,0)"
            />

            {/* Premium Vignette Overlay */}
            <div
                style={{
                    position: 'absolute',
                    inset: 0,
                    pointerEvents: 'none',
                    background: 'radial-gradient(circle at center, transparent 30%, #000 110%)',
                    zIndex: 1,
                }}
            />
        </div>
    );
};

export default RealisticGlobe;

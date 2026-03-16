import { useEffect, useRef } from 'react';

/**
 * Custom hook: observes elements with .reveal, .reveal-left, .reveal-right, .reveal-scale
 * and adds .visible class when they enter the viewport (CampusGo-style scroll-triggered animations).
 */
const useScrollReveal = () => {
    const observerRef = useRef(null);

    useEffect(() => {
        observerRef.current = new IntersectionObserver(
            (entries) => {
                entries.forEach((entry) => {
                    if (entry.isIntersecting) {
                        entry.target.classList.add('visible');
                    }
                });
            },
            {
                threshold: 0.12,
                rootMargin: '0px 0px -40px 0px',
            }
        );

        // Observe all reveal elements on the page
        const targets = document.querySelectorAll(
            '.reveal, .reveal-left, .reveal-right, .reveal-scale'
        );
        targets.forEach((el) => observerRef.current.observe(el));

        return () => {
            if (observerRef.current) {
                observerRef.current.disconnect();
            }
        };
    }, []);
};

export default useScrollReveal;

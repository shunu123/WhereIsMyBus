import React, { useState, useEffect, useRef } from 'react';
import { motion, useScroll, useTransform } from 'framer-motion';
import MapBackground from '../components/MapBackground';

/* Animated counter */
const Counter = ({ target, suffix = '' }) => {
    const [count, setCount] = useState(0);
    const ref = useRef(null);
    const started = useRef(false);

    useEffect(() => {
        const obs = new IntersectionObserver(
            ([e]) => {
                if (e.isIntersecting && !started.current) {
                    started.current = true;
                    const end = parseFloat(target);
                    const dur = 2000;
                    const startT = performance.now();
                    const tick = (now) => {
                        const p = Math.min((now - startT) / dur, 1);
                        const eased = 1 - Math.pow(1 - p, 3);
                        setCount(String(target).includes('.') ? (eased * end).toFixed(1) : Math.floor(eased * end));
                        if (p < 1) requestAnimationFrame(tick);
                    };
                    requestAnimationFrame(tick);
                }
            },
            { threshold: 0.5 }
        );
        if (ref.current) obs.observe(ref.current);
        return () => obs.disconnect();
    }, [target]);

    return <span ref={ref}>{count}{suffix}</span>;
};

const stats = [
    { value: '500', suffix: '+', label: 'Students Active' },
    { value: '99', suffix: '%', label: 'Server Uptime' },
    { value: '24', suffix: '/7', label: 'Live Support' },
    { value: '4.9', suffix: '', label: 'User Rating' },
];

const Home = () => {
    return (
        <>
            {/* ── Hero over map ── */}
            <div className="map-page">
                <MapBackground />
                <div className="map-overlay" />
                <div className="map-content">
                    <div style={s.heroGrid}>
                        <motion.div
                            style={s.heroLeft}
                            initial={{ opacity: 0, x: -25 }}
                            animate={{ opacity: 1, x: 0 }}
                            transition={{ duration: 0.6, ease: [0.25, 0.46, 0.45, 0.94] }}
                        >
                            <div style={s.badge}>College Transit Platform</div>
                            <h1 style={s.title}>
                                <span style={s.titleGradient}>WhereIs</span>MyBus
                            </h1>
                            <p style={s.desc}>
                                A modern college transportation tracking platform built this to simplify
                                the daily student commute. Monitor your assigned bus in real time,
                                view structured arrival schedules, and plan every journey with confidence.
                                Safety is built in — from verified authentication to integrated SOS emergency
                                support — making every trip dependable and transparent.
                            </p>
                            <div style={s.actions}>
                                <a href="/register" className="btn-primary btn-primary--white" style={{ width: 'auto', padding: '0.75rem 2rem' }}>
                                    Get Started
                                </a>
                                <a href="/about" style={s.ghost}>Learn more →</a>
                            </div>
                        </motion.div>

                        <motion.div
                            style={s.heroRight}
                            initial={{ opacity: 0, x: 25 }}
                            animate={{ opacity: 1, x: 0 }}
                            transition={{ duration: 0.6, delay: 0.12 }}
                        >
                            <motion.div
                                style={s.spot}
                                animate={{ y: [0, -5, 0] }}
                                transition={{ duration: 5, repeat: Infinity, ease: 'easeInOut' }}
                            >
                                <div style={s.spotGlow} />
                                <div style={s.spotGlow2} />
                                <span style={s.spotLabel}>Feature Spotlight</span>
                                <h2 style={s.spotTitle}>Eagle Eye Monitoring</h2>
                                <p style={s.spotDesc}>
                                    Monitor the entire fleet approaching campus simultaneously.
                                    A bird's-eye perspective for smarter departure decisions
                                    and real-time route selection.
                                </p>
                                <div style={s.spotMeta}>
                                    <span style={s.dot} />
                                    Live monitoring during scheduled hours
                                </div>
                            </motion.div>
                        </motion.div>
                    </div>
                </div>
            </div>

            {/* ── Stats ── */}
            <div style={s.statsWrap}>
                <hr className="glow-line" />
                <div style={s.statsGrid}>
                    {stats.map((st, i) => (
                        <motion.div
                            key={i}
                            style={s.statItem}
                            initial={{ opacity: 0, y: 15 }}
                            whileInView={{ opacity: 1, y: 0 }}
                            viewport={{ once: true, margin: '-30px' }}
                            transition={{ duration: 0.45, delay: i * 0.08 }}
                        >
                            <div style={s.statVal}><Counter target={st.value} suffix={st.suffix} /></div>
                            <div style={s.statLbl}>{st.label}</div>
                        </motion.div>
                    ))}
                </div>
                <hr className="glow-line" />
            </div>
        </>
    );
};

const s = {
    heroGrid: {
        maxWidth: '1200px', width: '100%',
        display: 'flex', alignItems: 'center', gap: '4rem', flexWrap: 'wrap',
    },
    heroLeft: { flex: 1.15, minWidth: '340px' },
    badge: {
        display: 'inline-block', padding: '0.3rem 0.85rem',
        borderRadius: '20px', fontSize: '0.68rem', fontWeight: 700,
        letterSpacing: '1.5px', textTransform: 'uppercase',
        color: '#d4a843', border: '1px solid rgba(212,168,67,0.2)',
        background: 'rgba(212,168,67,0.06)', marginBottom: '1.25rem',
    },
    title: {
        fontSize: '3.75rem', fontWeight: 900, lineHeight: 1.04,
        letterSpacing: '-2.5px', marginBottom: '1.25rem', color: '#ededed',
    },
    titleGradient: {
        background: 'linear-gradient(135deg, #ededed 20%, rgba(255,255,255,0.5) 100%)',
        WebkitBackgroundClip: 'text', WebkitTextFillColor: 'transparent',
    },
    desc: {
        fontSize: '0.97rem', color: 'rgba(255,255,255,0.5)',
        lineHeight: 1.75, marginBottom: '2.25rem', maxWidth: '90%',
    },
    actions: { display: 'flex', alignItems: 'center', gap: '1.5rem' },
    ghost: {
        color: 'rgba(255,255,255,0.35)', fontSize: '0.88rem', fontWeight: 500,
    },
    heroRight: { flex: 1, minWidth: '340px' },
    spot: {
        position: 'relative', overflow: 'hidden',
        background: 'rgba(255,255,255,0.03)',
        backdropFilter: 'blur(20px)', WebkitBackdropFilter: 'blur(20px)',
        border: '1px solid rgba(255,255,255,0.07)', borderRadius: '20px', padding: '2.5rem',
        boxShadow: '0 24px 48px -16px rgba(0,0,0,0.4), inset 0 1px 0 rgba(255,255,255,0.05)',
    },
    spotGlow: {
        position: 'absolute', top: '-60px', right: '-60px',
        width: '160px', height: '160px', borderRadius: '50%',
        background: 'radial-gradient(circle, rgba(99,102,241,0.2), transparent 70%)',
        pointerEvents: 'none',
    },
    spotGlow2: {
        position: 'absolute', bottom: '-40px', left: '-40px',
        width: '120px', height: '120px', borderRadius: '50%',
        background: 'radial-gradient(circle, rgba(34,211,238,0.08), transparent 70%)',
        pointerEvents: 'none',
    },
    spotLabel: {
        display: 'block', fontSize: '0.65rem', fontWeight: 700, textTransform: 'uppercase',
        letterSpacing: '2px', color: '#d4a843', marginBottom: '0.6rem',
    },
    spotTitle: {
        fontSize: '1.3rem', fontWeight: 800, color: '#ededed',
        marginBottom: '0.75rem', letterSpacing: '-0.5px',
    },
    spotDesc: {
        fontSize: '0.88rem', color: 'rgba(255,255,255,0.45)',
        lineHeight: 1.7, marginBottom: '1.25rem',
    },
    spotMeta: {
        display: 'flex', alignItems: 'center', gap: '0.45rem',
        fontSize: '0.75rem', color: 'rgba(255,255,255,0.25)',
    },
    dot: {
        width: '5px', height: '5px', borderRadius: '50%',
        background: '#22c55e', boxShadow: '0 0 8px rgba(34,197,94,0.6)',
    },
    statsWrap: { padding: '0 2rem', position: 'relative' },
    statsGrid: {
        maxWidth: '900px', margin: '0 auto',
        display: 'grid', gridTemplateColumns: 'repeat(4, 1fr)',
        gap: '2rem', padding: '3.5rem 0',
    },
    statItem: { textAlign: 'center' },
    statVal: {
        fontSize: '2.5rem', fontWeight: 900, letterSpacing: '-1.5px',
        marginBottom: '0.15rem',
        background: 'linear-gradient(180deg, #ededed 30%, rgba(255,255,255,0.5) 100%)',
        WebkitBackgroundClip: 'text', WebkitTextFillColor: 'transparent',
    },
    statLbl: { fontSize: '0.78rem', color: 'rgba(255,255,255,0.3)', fontWeight: 500 },
};

export default Home;

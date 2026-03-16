import React from 'react';
import { motion } from 'framer-motion';

const features = [
    { num: '01', title: 'Secure Login', desc: 'Students log in using verified registration credentials for protected and reliable access to the platform.' },
    { num: '02', title: 'Live Map Tracking', desc: 'Real-time bus location monitoring through an interactive map with accurate positional data updated every 3 seconds.' },
    { num: '03', title: 'ETA Timeline', desc: 'Structured stop-by-stop arrival timeline providing estimated times for each point along the route.' },
    { num: '04', title: 'Stop Reminder Alarm', desc: 'Activate a personal reminder before your selected stop. The system notifies you 5 minutes before arrival.' },
    { num: '05', title: 'Voice Assistant', desc: 'Voice-enabled access to essential transportation information including schedules, routes, and live ETA updates.' },
    { num: '06', title: 'Eagle Eye View', desc: 'Bird\'s-eye overview of all active buses approaching campus simultaneously for fleet-wide monitoring.' },
    { num: '07', title: 'SOS Emergency', desc: 'Integrated emergency alert that sends your live location to campus security and registered emergency contacts.' },
];

const About = () => (
    <div style={{ minHeight: 'calc(100vh - 64px)', position: 'relative' }}>
        {/* Header */}
        <div style={{ padding: '5rem 2rem 2.5rem', textAlign: 'center' }}>
            <motion.div
                initial={{ opacity: 0, y: 12 }}
                animate={{ opacity: 1, y: 0 }}
                transition={{ duration: 0.45 }}
                style={{ maxWidth: '700px', margin: '0 auto' }}
            >
                <div className="section-label">About</div>
                <h1 className="section-heading">About WhereIsMyBus</h1>
                <p className="section-subtitle" style={{ textAlign: 'center', margin: '0 auto' }}>
                    Smart and secure college bus tracking system
                </p>
            </motion.div>
        </div>

        {/* Description */}
        <div style={{ padding: '0 2rem 3.5rem', display: 'flex', justifyContent: 'center' }}>
            <motion.div
                initial={{ opacity: 0, scale: 0.97 }}
                whileInView={{ opacity: 1, scale: 1 }}
                viewport={{ once: true }}
                transition={{ duration: 0.45 }}
                style={{
                    background: 'rgba(255,255,255,0.025)',
                    border: '1px solid rgba(255,255,255,0.06)',
                    borderRadius: '16px', padding: '2.25rem',
                    maxWidth: '850px', width: '100%', textAlign: 'center',
                }}
            >
                <p style={{ fontSize: '0.98rem', color: 'rgba(255,255,255,0.5)', lineHeight: 1.8 }}>
                    WhereIsMyBus is a modern college transportation tracking system designed to
                    improve student safety, commute transparency, and punctuality. The platform
                    provides structured schedule visibility, real-time location monitoring, and
                    reliable commute management tools tailored for institutional environments.
                    Every feature has been designed with the student experience in mind.
                </p>
            </motion.div>
        </div>

        <hr className="glow-line" />

        {/* Feature cards with gradient borders */}
        <div style={{ padding: '4.5rem 2rem 5rem' }}>
            <div style={{ maxWidth: '1200px', margin: '0 auto' }}>
                <motion.div
                    initial={{ opacity: 0, y: 10 }}
                    whileInView={{ opacity: 1, y: 0 }}
                    viewport={{ once: true }}
                    transition={{ duration: 0.4 }}
                    style={{ textAlign: 'center', marginBottom: '3rem' }}
                >
                    <div className="section-label">Capabilities</div>
                    <h2 className="section-heading" style={{ fontSize: '2.2rem' }}>Platform Features</h2>
                </motion.div>

                <div style={{
                    display: 'grid',
                    gridTemplateColumns: 'repeat(auto-fit, minmax(300px, 1fr))',
                    gap: '1.25rem',
                }}>
                    {features.map((f, i) => (
                        <motion.div
                            key={i}
                            className="glow-card"
                            initial={{ opacity: 0, y: 18 }}
                            whileInView={{ opacity: 1, y: 0 }}
                            viewport={{ once: true, margin: '-20px' }}
                            transition={{ duration: 0.4, delay: i * 0.05 }}
                        >
                            <div className="glow-card__inner">
                                <div className="glow-card__number">{f.num}</div>
                                <h3 className="glow-card__title">{f.title}</h3>
                                <p className="glow-card__desc">{f.desc}</p>
                            </div>
                        </motion.div>
                    ))}
                </div>
            </div>
        </div>
    </div>
);

export default About;

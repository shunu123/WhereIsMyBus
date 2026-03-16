import React, { useState, useRef, useEffect } from 'react';
import { motion } from 'framer-motion';

const faqs = [
    { q: 'How to track a bus?', a: 'Navigate to the Live Map section from the dashboard. Select your assigned bus number or search by route to see its real-time location with estimated arrival times at each stop.' },
    { q: 'How to activate the stop reminder alarm?', a: 'Within the ETA Timeline view, select your destination stop and tap the alarm icon. You\'ll be notified approximately 5 minutes before arrival. This is a personal reminder — it does not stop the bus.' },
    { q: 'How to use Eagle Eye view?', a: 'Eagle Eye mode is accessible through the map layers control. It provides a campus-wide overhead view of all active buses simultaneously.' },
    { q: 'How does the SOS feature work?', a: 'The SOS function sends an immediate alert containing your live location to campus security and your registered emergency contacts.' },
];

const safety = [
    { title: 'Safe Driving Practices', text: 'All buses adhere to institutional speed limits. Drivers undergo regular safety training and vehicle inspections before every scheduled departure.' },
    { title: 'Student Boarding Safety', text: 'Students must wait at designated stops and board only when the vehicle is at a complete halt. Running alongside moving buses is strictly prohibited.' },
    { title: 'Road Awareness', text: 'Remain attentive while waiting at stops. Avoid headphones at high volume near roadways and always use designated pedestrian crossings.' },
    { title: 'Emergency Response', text: 'In case of an emergency during transit, use the SOS feature immediately. Campus security is available 24/7.' },
];

const FAQItem = ({ question, answer, isOpen, onClick }) => {
    const ref = useRef(null);
    const [h, setH] = useState(0);
    useEffect(() => { setH(isOpen && ref.current ? ref.current.scrollHeight : 0); }, [isOpen]);

    return (
        <div className="faq-item">
            <button className="faq-btn" onClick={onClick}>
                <span>{question}</span>
                <span className={`faq-chevron ${isOpen ? 'faq-chevron--open' : ''}`}>▾</span>
            </button>
            <div className="faq-answer" style={{ height: `${h}px` }}>
                <div ref={ref} className="faq-answer__inner">{answer}</div>
            </div>
        </div>
    );
};

const Help = () => {
    const [active, setActive] = useState(null);

    return (
        <div style={{ minHeight: 'calc(100vh - 64px)', position: 'relative' }}>
            <div style={{ padding: '5rem 2rem 2.5rem', textAlign: 'center' }}>
                <motion.div
                    initial={{ opacity: 0, y: 12 }}
                    animate={{ opacity: 1, y: 0 }}
                    transition={{ duration: 0.45 }}
                    style={{ maxWidth: '700px', margin: '0 auto' }}
                >
                    <div className="section-label">Support</div>
                    <h1 className="section-heading">Help & Support</h1>
                    <p className="section-subtitle" style={{ textAlign: 'center', margin: '0 auto' }}>
                        Safety guidelines, frequently asked questions, and contact information
                    </p>
                </motion.div>
            </div>

            <hr className="glow-line" />

            <div style={{ padding: '3rem 2rem 5rem' }}>
                <div style={{ maxWidth: '1200px', margin: '0 auto', display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '3rem' }}>
                    {/* Left */}
                    <motion.div
                        initial={{ opacity: 0, x: -20 }}
                        whileInView={{ opacity: 1, x: 0 }}
                        viewport={{ once: true }}
                        transition={{ duration: 0.5 }}
                    >
                        <h2 style={styles.colTitle}>Driver Precautions & Road Safety</h2>
                        <div style={{ display: 'flex', flexDirection: 'column', gap: '0.85rem' }}>
                            {safety.map((p, i) => (
                                <motion.div
                                    key={i}
                                    className="glow-card"
                                    initial={{ opacity: 0, y: 10 }}
                                    whileInView={{ opacity: 1, y: 0 }}
                                    viewport={{ once: true }}
                                    transition={{ duration: 0.35, delay: i * 0.06 }}
                                >
                                    <div className="glow-card__inner" style={{ padding: '1.15rem', display: 'flex', gap: '0.85rem' }}>
                                        <span style={{ fontSize: '0.75rem', fontWeight: 700, color: '#818cf8', minWidth: '20px', paddingTop: '2px' }}>
                                            {String(i + 1).padStart(2, '0')}
                                        </span>
                                        <div>
                                            <h4 style={{ fontSize: '0.9rem', fontWeight: 700, color: '#ededed', marginBottom: '0.25rem' }}>{p.title}</h4>
                                            <p style={{ fontSize: '0.82rem', color: 'rgba(255,255,255,0.35)', lineHeight: 1.6 }}>{p.text}</p>
                                        </div>
                                    </div>
                                </motion.div>
                            ))}
                        </div>
                    </motion.div>

                    {/* Right */}
                    <motion.div
                        initial={{ opacity: 0, x: 20 }}
                        whileInView={{ opacity: 1, x: 0 }}
                        viewport={{ once: true }}
                        transition={{ duration: 0.5, delay: 0.08 }}
                    >
                        <h2 style={styles.colTitle}>Frequently Asked Questions</h2>
                        <div style={{ display: 'flex', flexDirection: 'column', gap: '0.6rem', marginBottom: '2.25rem' }}>
                            {faqs.map((faq, i) => (
                                <FAQItem
                                    key={i} question={faq.q} answer={faq.a}
                                    isOpen={active === i} onClick={() => setActive(active === i ? null : i)}
                                />
                            ))}
                        </div>

                        <h3 style={{ fontSize: '0.95rem', fontWeight: 700, color: '#ededed', marginBottom: '0.85rem' }}>Helpline</h3>
                        <div style={{ display: 'flex', flexDirection: 'column', gap: '0.6rem' }}>
                            <div className="contact-item">
                                <div>
                                    <div className="contact-item__label">Email</div>
                                    <div className="contact-item__value">support@whereismybus.com</div>
                                </div>
                            </div>
                            <div className="contact-item">
                                <div>
                                    <div className="contact-item__label">Mobile</div>
                                    <div className="contact-item__value">+91-XXXXXXXXXX</div>
                                </div>
                            </div>
                        </div>
                    </motion.div>
                </div>
            </div>
        </div>
    );
};

const styles = {
    colTitle: {
        fontSize: '1.05rem', fontWeight: 700, color: '#ededed',
        marginBottom: '1.25rem', paddingBottom: '0.65rem',
        borderBottom: '1px solid rgba(255,255,255,0.06)',
    },
};

export default Help;

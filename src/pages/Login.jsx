import React, { useState } from 'react';
import MapBackground from '../components/MapBackground';
import { Link, useNavigate } from 'react-router-dom';
import { motion } from 'framer-motion';
import { useAuth } from '../context/AuthContext';
import { loginUser } from '../services/api';

const Login = () => {
    const [regNoOrEmail, setRegNoOrEmail] = useState('');
    const [password, setPassword] = useState('');
    const [error, setError] = useState('');
    const [isLoading, setIsLoading] = useState(false);
    const { login } = useAuth();
    const navigate = useNavigate();

    const handleLogin = async (e) => {
        e.preventDefault();
        setError('');
        setIsLoading(true);

        try {
            const data = await loginUser(regNoOrEmail, password);
            login(data);
            navigate('/dashboard'); // Navigate to student dashboard after successful login
        } catch (err) {
            setError(typeof err === 'string' ? err : 'Invalid credentials.');
        } finally {
            setIsLoading(false);
        }
    };

    return (
        <div className="map-page">
            <MapBackground />
            <div className="map-overlay" />
            <div className="map-content">
                <motion.div
                    className="glass-card"
                    style={s.card}
                    initial={{ opacity: 0, y: 15, scale: 0.98 }}
                    animate={{ opacity: 1, y: 0, scale: 1 }}
                    transition={{ duration: 0.45, ease: [0.25, 0.46, 0.45, 0.94] }}
                >
                    <div style={s.header}>
                        <h2 style={s.title}>Sign In</h2>
                        <p style={s.sub}>Access your student transit dashboard</p>
                    </div>
                    {error && <div style={s.errorBadge}>{error}</div>}
                    <form style={s.form} onSubmit={handleLogin}>
                        <div style={s.group}>
                            <label className="form-label">Registration Number</label>
                            <input
                                type="text"
                                className="form-input"
                                placeholder="e.g. 21BCE0000"
                                value={regNoOrEmail}
                                onChange={(e) => setRegNoOrEmail(e.target.value)}
                                required
                            />
                        </div>
                        <div style={s.group}>
                            <label className="form-label">Password</label>
                            <input
                                type="password"
                                className="form-input"
                                placeholder="Enter your password"
                                value={password}
                                onChange={(e) => setPassword(e.target.value)}
                                required
                            />
                        </div>
                        <div style={{ textAlign: 'right', marginTop: '-0.3rem' }}>
                            <a href="#" style={{ color: 'rgba(255,255,255,0.3)', fontSize: '0.8rem', fontWeight: 500 }}>Forgot password?</a>
                        </div>
                        <button className="btn-primary btn-primary--accent" type="submit" disabled={isLoading}>
                            {isLoading ? 'Signing In...' : 'Sign In'}
                        </button>
                    </form>
                    <div style={s.footer}>
                        Don't have an account? <Link to="/register" style={{ color: '#818cf8', fontWeight: 600 }}>Register</Link>
                    </div>
                </motion.div>
            </div>
        </div>
    );
};

const s = {
    card: { width: '100%', maxWidth: '400px', padding: '2.75rem 2.25rem' },
    header: { textAlign: 'center', marginBottom: '2rem' },
    title: { fontSize: '1.65rem', fontWeight: 800, color: '#ededed', letterSpacing: '-0.5px', marginBottom: '0.25rem' },
    sub: { color: 'rgba(255,255,255,0.35)', fontSize: '0.85rem' },
    form: { display: 'flex', flexDirection: 'column', gap: '1.1rem' },
    group: { display: 'flex', flexDirection: 'column', gap: '0.35rem' },
    footer: { marginTop: '1.75rem', textAlign: 'center', fontSize: '0.85rem', color: 'rgba(255,255,255,0.3)' },
    errorBadge: {
        backgroundColor: 'rgba(239, 68, 68, 0.1)',
        color: '#ef4444',
        padding: '0.75rem',
        borderRadius: '0.5rem',
        fontSize: '0.85rem',
        textAlign: 'center',
        marginBottom: '1rem',
        border: '1px solid rgba(239, 68, 68, 0.2)'
    }
};

export default Login;

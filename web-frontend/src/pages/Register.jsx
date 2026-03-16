import React, { useState, useEffect } from 'react';
import { Link, useNavigate } from 'react-router-dom';
import { motion, AnimatePresence } from 'framer-motion';
import { sendOtp, verifyOtp, registerStudent } from '../services/api';

const Register = () => {
    const navigate = useNavigate();
    const [formData, setFormData] = useState({
        first_name: '',
        last_name: '',
        reg_no: '',
        year: '',
        degree: '',
        college_name: '',
        department: '',
        email: '',
        mobile_no: '',
        location: '',
        stop: '',
        password: '',
        confirmPassword: '',
        otp: ''
    });

    const [status, setStatus] = useState({
        loading: false,
        error: '',
        success: '',
        otpSent: false,
        otpSending: false
    });

    const [pwStrength, setPwStrength] = useState({ isStrong: false, message: '' });
    const [passwordsMatch, setPasswordsMatch] = useState(false);

    const validatePassword = (pw) => {
        if (!pw) return { isStrong: false, message: '' };
        const hasUpper = /[A-Z]/.test(pw);
        const hasLower = /[a-z]/.test(pw);
        const hasNumber = /[0-9]/.test(pw);
        const hasSpecial = /[!@#$%^&*(),.?":{}|<>]/.test(pw);
        if (pw.length < 8) return { isStrong: false, message: 'Min 8 characters required' };
        if (!hasUpper || !hasLower || !hasNumber || !hasSpecial) {
            return { isStrong: false, message: 'Need Upper, Lower, Number & Special Char' };
        }
        return { isStrong: true, message: 'Strong password!' };
    };

    useEffect(() => {
        setPwStrength(validatePassword(formData.password));
    }, [formData.password]);

    useEffect(() => {
        setPasswordsMatch(formData.password !== '' && formData.password === formData.confirmPassword);
    }, [formData.password, formData.confirmPassword]);

    const handleChange = (e) => {
        const { name, value } = e.target;
        setFormData(prev => ({ ...prev, [name]: value }));
    };

    const handleSendOtp = async () => {
        if (!formData.email) {
            setStatus(prev => ({ ...prev, error: 'Please enter your email first.' }));
            return;
        }

        setStatus(prev => ({ ...prev, otpSending: true, error: '', success: '' }));
        try {
            await sendOtp(formData.email);
            setStatus(prev => ({ ...prev, otpSent: true, success: 'OTP sent to your email!' }));
        } catch (err) {
            setStatus(prev => ({ ...prev, error: err }));
        } finally {
            setStatus(prev => ({ ...prev, otpSending: false }));
        }
    };

    const handleSubmit = async (e) => {
        e.preventDefault();
        setStatus(prev => ({ ...prev, loading: true, error: '', success: '' }));

        if (formData.password !== formData.confirmPassword) {
            setStatus(prev => ({ ...prev, error: 'Passwords do not match.', loading: false }));
            return;
        }

        if (!status.otpSent) {
            setStatus(prev => ({ ...prev, error: 'Please send and verify OTP first.', loading: false }));
            return;
        }

        if (!pwStrength.isStrong) {
            setStatus(prev => ({ ...prev, error: 'Please use a stronger password.', loading: false }));
            return;
        }

        if (!passwordsMatch) {
            setStatus(prev => ({ ...prev, error: 'Passwords do not match.', loading: false }));
            return;
        }

        try {
            // 1. Verify OTP first
            await verifyOtp(formData.email, formData.otp);

            // 2. Register student
            const registrationPayload = {
                reg_no: formData.reg_no,
                password: formData.password,
                first_name: formData.first_name,
                last_name: formData.last_name,
                year: parseInt(formData.year) || 1,
                mobile_no: formData.mobile_no,
                email: formData.email,
                college_name: formData.college_name,
                department: formData.department,
                degree: formData.degree || "N/A",
                location: formData.location,
                stop: formData.stop,
                role: "student"
            };

            await registerStudent(registrationPayload);
            setStatus(prev => ({ ...prev, success: 'Registration successful! Redirecting to login...' }));
            setTimeout(() => navigate('/login'), 2000);
        } catch (err) {
            setStatus(prev => ({ ...prev, error: err }));
        } finally {
            setStatus(prev => ({ ...prev, loading: false }));
        }
    };

    return (
        <div style={{ minHeight: 'calc(100vh - 64px)', position: 'relative' }}>
            <div style={{ padding: '4rem 2rem 1.5rem', textAlign: 'center' }}>
                <motion.div
                    initial={{ opacity: 0, y: 12 }}
                    animate={{ opacity: 1, y: 0 }}
                    transition={{ duration: 0.45 }}
                    style={{ maxWidth: '600px', margin: '0 auto' }}
                >
                    <div className="section-label">Join Us</div>
                    <h1 className="section-heading" style={{ fontSize: '2.1rem' }}>Student Registration</h1>
                    <p className="section-subtitle" style={{ textAlign: 'center', margin: '0 auto' }}>
                        Create your WhereIsMyBus account to start tracking your commute
                    </p>
                </motion.div>
            </div>

            <div style={{ display: 'flex', justifyContent: 'center', padding: '0 2rem 4rem' }}>
                <motion.div
                    className="glow-card"
                    initial={{ opacity: 0, y: 15, scale: 0.98 }}
                    animate={{ opacity: 1, y: 0, scale: 1 }}
                    transition={{ duration: 0.45, delay: 0.08 }}
                    style={{ width: '100%', maxWidth: '820px' }}
                >
                    <div className="glow-card__inner" style={{ padding: '2.5rem' }}>
                        {status.error && <div style={s.errorBadge}>{status.error}</div>}
                        {status.success && <div style={s.successBadge}>{status.success}</div>}

                        <form style={s.form} onSubmit={handleSubmit}>
                            <div style={s.secLabel}>Personal Details</div>
                            <div style={s.grid}>
                                <div style={s.g}><label className="form-label">First Name <span style={{ color: '#ef4444' }}>*</span></label>
                                    <input type="text" name="first_name" value={formData.first_name} onChange={handleChange} className="form-input" required />
                                </div>
                                <div style={s.g}><label className="form-label">Last Name <span style={{ color: '#ef4444' }}>*</span></label>
                                    <input type="text" name="last_name" value={formData.last_name} onChange={handleChange} className="form-input" required />
                                </div>
                            </div>

                            <div style={s.secLabel}>Academic Details</div>
                            <div style={s.grid}>
                                <div style={s.g}><label className="form-label">Registration Number <span style={{ color: '#ef4444' }}>*</span></label>
                                    <input type="text" name="reg_no" value={formData.reg_no} onChange={handleChange} className="form-input" required />
                                </div>
                                <div style={s.g}><label className="form-label">Year <span style={{ color: '#ef4444' }}>*</span></label>
                                    <select name="year" value={formData.year} onChange={handleChange} className="form-input" required>
                                        <option value="">Select Year</option>
                                        <option value="1">1st Year</option>
                                        <option value="2">2nd Year</option>
                                        <option value="3">3rd Year</option>
                                        <option value="4">4th Year</option>
                                    </select>
                                </div>
                                <div style={s.g}><label className="form-label">Degree <span style={{ color: '#ef4444' }}>*</span></label>
                                    <input type="text" name="degree" value={formData.degree} onChange={handleChange} className="form-input" placeholder="e.g. B.Tech" required />
                                </div>
                                <div style={s.g}><label className="form-label">College <span style={{ color: '#ef4444' }}>*</span></label>
                                    <input type="text" name="college_name" value={formData.college_name} onChange={handleChange} className="form-input" required />
                                </div>
                                <div style={{ ...s.g, gridColumn: '1 / -1' }}><label className="form-label">Department <span style={{ color: '#ef4444' }}>*</span></label>
                                    <input type="text" name="department" value={formData.department} onChange={handleChange} className="form-input" required />
                                </div>
                            </div>

                            <div style={s.secLabel}>Contact Information</div>
                            <div style={s.grid}>
                                <div style={s.g}>
                                    <label className="form-label">Email <span style={{ color: '#ef4444' }}>*</span></label>
                                    <div style={{ display: 'flex', gap: '0.5rem' }}>
                                        <input type="email" name="email" value={formData.email} onChange={handleChange} className="form-input" style={{ flex: 1 }} required />
                                        <button
                                            type="button"
                                            onClick={handleSendOtp}
                                            disabled={status.otpSending}
                                            style={s.otpBtn}
                                        >
                                            {status.otpSending ? '...' : status.otpSent ? 'Resend' : 'Send OTP'}
                                        </button>
                                    </div>
                                </div>

                                <AnimatePresence>
                                    {status.otpSent && (
                                        <motion.div
                                            initial={{ opacity: 0, height: 0 }}
                                            animate={{ opacity: 1, height: 'auto' }}
                                            exit={{ opacity: 0, height: 0 }}
                                            style={s.g}
                                        >
                                            <label className="form-label">Email Verification <span style={{ color: '#ef4444' }}>*</span></label>
                                            <input type="text" name="otp" value={formData.otp} onChange={handleChange} className="form-input" placeholder="Enter OTP" required />
                                        </motion.div>
                                    )}
                                </AnimatePresence>

                                <div style={s.g}><label className="form-label">Mobile Number <span style={{ color: '#ef4444' }}>*</span></label>
                                    <input type="text" name="mobile_no" value={formData.mobile_no} onChange={handleChange} className="form-input" placeholder="e.g. 9876543210" required />
                                </div>
                                <div style={s.g}><label className="form-label">Location <span style={{ color: '#ef4444' }}>*</span></label>
                                    <input type="text" name="location" value={formData.location} onChange={handleChange} className="form-input" required />
                                </div>
                                <div style={{ ...s.g, gridColumn: '1 / -1' }}><label className="form-label">Pickup Stop <span style={{ color: '#ef4444' }}>*</span></label>
                                    <input type="text" name="stop" value={formData.stop} onChange={handleChange} className="form-input" required />
                                </div>
                            </div>

                            <div style={s.secLabel}>Security</div>
                            <div style={s.grid}>
                                <div style={s.g}>
                                    <label className="form-label">Password <span style={{ color: '#ef4444' }}>*</span></label>
                                    <input type="password" name="password" value={formData.password} onChange={handleChange} className="form-input" required />
                                    {formData.password && (
                                        <div style={{ fontSize: '0.75rem', marginTop: '0.2rem', color: pwStrength.isStrong ? '#22c55e' : '#f59e0b' }}>
                                            {pwStrength.message}
                                        </div>
                                    )}
                                </div>
                                <div style={s.g}>
                                    <label className="form-label" style={{ display: 'flex', alignItems: 'center', gap: '0.5rem' }}>
                                        Confirm Password <span style={{ color: '#ef4444' }}>*</span>
                                        {passwordsMatch && <span style={{ color: '#22c55e' }}>✔</span>}
                                    </label>
                                    <input type="password" name="confirmPassword" value={formData.confirmPassword} onChange={handleChange} className="form-input" required />
                                </div>
                            </div>

                            <button className="btn-primary btn-primary--accent" type="submit" disabled={status.loading} style={{ marginTop: '0.75rem' }}>
                                {status.loading ? 'Creating Account...' : 'Create Account'}
                            </button>
                        </form>

                        <div style={{ marginTop: '1.75rem', textAlign: 'center', fontSize: '0.85rem', color: 'rgba(255,255,255,0.3)' }}>
                            Already registered? <Link to="/login" style={{ color: '#818cf8', fontWeight: 600 }}>Sign in</Link>
                        </div>
                    </div>
                </motion.div>
            </div>
        </div>
    );
};

const s = {
    form: { display: 'flex', flexDirection: 'column', gap: '1.75rem' },
    secLabel: {
        fontSize: '0.65rem', fontWeight: 700, textTransform: 'uppercase',
        letterSpacing: '2px',
        background: 'linear-gradient(135deg, #818cf8, #22d3ee)',
        WebkitBackgroundClip: 'text', WebkitTextFillColor: 'transparent',
        paddingBottom: '0.45rem', borderBottom: '1px solid rgba(255,255,255,0.05)',
    },
    grid: {
        display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(280px, 1fr))',
        gap: '1.1rem', marginTop: '-0.4rem',
    },
    g: { display: 'flex', flexDirection: 'column', gap: '0.35rem' },
    errorBadge: {
        backgroundColor: 'rgba(239, 68, 68, 0.1)',
        color: '#ef4444',
        padding: '0.75rem',
        borderRadius: '0.5rem',
        fontSize: '0.85rem',
        textAlign: 'center',
        marginBottom: '1.5rem',
        border: '1px solid rgba(239, 68, 68, 0.2)'
    },
    successBadge: {
        backgroundColor: 'rgba(34, 197, 94, 0.1)',
        color: '#22c55e',
        padding: '0.75rem',
        borderRadius: '0.5rem',
        fontSize: '0.85rem',
        textAlign: 'center',
        marginBottom: '1.5rem',
        border: '1px solid rgba(34, 197, 94, 0.2)'
    },
    otpBtn: {
        padding: '0 1rem',
        background: 'rgba(129, 140, 248, 0.1)',
        color: '#818cf8',
        border: '1px solid rgba(129, 140, 248, 0.2)',
        borderRadius: '8px',
        fontSize: '0.8rem',
        fontWeight: 600,
        cursor: 'pointer',
        transition: 'all 0.2s ease'
    }
};

export default Register;

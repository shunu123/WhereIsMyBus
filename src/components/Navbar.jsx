import React, { useEffect, useState } from 'react';
import { Link, useLocation } from 'react-router-dom';

const Navbar = () => {
    const { pathname } = useLocation();
    const [scrolled, setScrolled] = useState(false);

    useEffect(() => {
        const handleScroll = () => {
            setScrolled(window.scrollY > 20);
        };
        window.addEventListener('scroll', handleScroll, { passive: true });
        return () => window.removeEventListener('scroll', handleScroll);
    }, []);

    const navItems = [
        { to: '/', label: 'Home' },
        { to: '/about', label: 'About' },
        { to: '/help', label: 'Help & Support' },
    ];

    return (
        <nav className={`navbar ${scrolled ? 'navbar--scrolled' : ''}`}>
            <div className="navbar-inner">
                <Link to="/" className="navbar-logo">
                    WhereIs<span>My</span>Bus
                </Link>
                <div className="navbar-links">
                    {navItems.map(item => (
                        <Link
                            key={item.to}
                            to={item.to}
                            className={`navbar-link ${pathname === item.to ? 'active' : ''}`}
                        >
                            {item.label}
                        </Link>
                    ))}
                    <div className="navbar-divider" />
                    <Link to="/login" className="navbar-btn navbar-btn--ghost">Login</Link>
                    <Link to="/register" className="navbar-btn navbar-btn--solid">Register</Link>
                </div>
            </div>
        </nav>
    );
};

export default Navbar;

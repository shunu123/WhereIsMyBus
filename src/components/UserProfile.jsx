import React, { useState, useRef, useEffect } from 'react';
import { User, Settings, FileText, LogOut, ChevronDown } from 'lucide-react';
import { useAuth } from '../context/AuthContext';
import { motion, AnimatePresence } from 'framer-motion';

const UserProfile = () => {
    const { user, logout } = useAuth();
    const [isOpen, setIsOpen] = useState(false);
    const menuRef = useRef(null);

    // Close on click outside
    useEffect(() => {
        const handleClickOutside = (event) => {
            if (menuRef.current && !menuRef.current.contains(event.target)) {
                setIsOpen(false);
            }
        };
        document.addEventListener('mousedown', handleClickOutside);
        return () => document.removeEventListener('mousedown', handleClickOutside);
    }, []);

    if (!user) return null;

    return (
        <div className="relative" ref={menuRef}>
            {/* Trigger Button */}
            <button 
                onClick={() => setIsOpen(!isOpen)}
                className="flex items-center gap-2 px-3 py-1.5 bg-[var(--surface-bright)] border border-[var(--border)] rounded-full hover:bg-[var(--surface-hover)] transition-all shadow-md"
            >
                <div className="w-6 h-6 rounded-full bg-[var(--accent)] flex items-center justify-center text-white text-xs font-bold">
                    {user.name ? user.name[0].toUpperCase() : 'U'}
                </div>
                <span className="text-sm font-medium text-[var(--text-1)]">{user.name || 'User'}</span>
                <ChevronDown size={14} className={`text-[var(--text-3)] transition-transform ${isOpen ? 'rotate-180' : ''}`} />
            </button>

            {/* Dropdown Menu */}
            <AnimatePresence>
                {isOpen && (
                    <motion.div
                        initial={{ opacity: 0, y: 10, scale: 0.95 }}
                        animate={{ opacity: 1, y: 0, scale: 1 }}
                        exit={{ opacity: 0, y: 5, scale: 0.95 }}
                        transition={{ duration: 0.15, ease: 'easeOut' }}
                        className="absolute right-0 mt-2 w-56 bg-[var(--surface-bright)] border border-[var(--border)] rounded-2xl shadow-2xl z-[10000] overflow-hidden"
                    >
                        {/* User Details */}
                        <div className="p-4 border-b border-[var(--border)] bg-[var(--surface)]">
                            <p className="text-xs font-bold text-[var(--text-4)] uppercase tracking-wider">Signed in as</p>
                            <p className="text-sm font-black text-[var(--text-1)] mt-0.5">{user.name}</p>
                            <p className="text-xs text-[var(--text-3)] truncate">{user.email || user.reg_no}</p>
                        </div>

                        {/* Actions */}
                        <div className="p-2">
                            <button className="w-full flex items-center gap-3 px-3 py-2 text-sm text-[var(--text-2)] hover:bg-[var(--surface-hover)] rounded-xl transition-colors">
                                <User size={16} className="text-[var(--text-3)]" />
                                <span>Profile Details</span>
                            </button>
                            <button className="w-full flex items-center gap-3 px-3 py-2 text-sm text-[var(--text-2)] hover:bg-[var(--surface-hover)] rounded-xl transition-colors">
                                <Settings size={16} className="text-[var(--text-3)]" />
                                <span>Settings</span>
                            </button>
                            <button className="w-full flex items-center gap-3 px-3 py-2 text-sm text-[var(--text-2)] hover:bg-[var(--surface-hover)] rounded-xl transition-colors">
                                <FileText size={16} className="text-[var(--text-3)]" />
                                <span>Reports</span>
                            </button>
                        </div>

                        {/* Logout */}
                        <div className="p-2 border-t border-[var(--border)]">
                            <button 
                                onClick={logout}
                                className="w-full flex items-center gap-3 px-3 py-2 text-sm text-red-500 hover:bg-red-500/10 rounded-xl transition-colors font-medium"
                            >
                                <LogOut size={16} />
                                <span>Log out</span>
                            </button>
                        </div>
                    </motion.div>
                )}
            </AnimatePresence>
        </div>
    );
};

export default UserProfile;

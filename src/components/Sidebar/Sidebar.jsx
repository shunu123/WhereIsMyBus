import React from 'react';
import { motion, AnimatePresence } from 'framer-motion';

const Sidebar = ({ children, isVisible = true }) => {
  return (
    <AnimatePresence>
      {isVisible && (
        <motion.aside
          className="gm-sidebar"
          initial={{ x: -450, opacity: 0 }}
          animate={{ x: 0, opacity: 1 }}
          exit={{ x: -450, opacity: 0 }}
          transition={{ type: 'spring', damping: 25, stiffness: 200 }}
        >
          {children}
        </motion.aside>
      )}
    </AnimatePresence>
  );
};

export default Sidebar;

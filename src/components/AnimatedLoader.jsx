import React from 'react';
import Lottie from 'lottie-react';
import { motion } from 'framer-motion';

// Import the JSON directly if it exists, otherwise we'll handle the absence gracefully
import busAnimationData from '../../public/bus-loading.json';

const AnimatedLoader = ({ text = "Searching for buses..." }) => {
    // Check if the loaded data is an actual Lottie JSON or the XML error we got
    const isValidLottie = busAnimationData && busAnimationData.v;

    return (
        <div className="flex flex-col items-center justify-center p-8 h-64 w-full">
            <motion.div
                initial={{ opacity: 0, scale: 0.9 }}
                animate={{ opacity: 1, scale: 1 }}
                transition={{ duration: 0.3 }}
                className="flex flex-col items-center"
            >
                {isValidLottie ? (
                    <div className="w-48 h-48 mb-4">
                        <Lottie 
                            animationData={busAnimationData} 
                            loop={true} 
                            autoplay={true} 
                        />
                    </div>
                ) : (
                    // Fallback spinner if the specific Lottie file isn't available
                    <div className="relative w-24 h-24 mb-6">
                        <div className="absolute inset-0 border-4 border-[var(--border)] rounded-full"></div>
                        <div className="absolute inset-0 border-4 border-[var(--accent)] rounded-full border-t-transparent animate-spin"></div>
                        <div className="absolute inset-2 bg-[var(--surface-hover)] rounded-full flex items-center justify-center">
                            <span className="text-[var(--accent)] text-xs font-bold">BUS</span>
                        </div>
                    </div>
                )}
                
                <h3 className="text-lg font-semibold text-[var(--text-1)] mb-2">{text}</h3>
                <p className="text-sm text-[var(--text-3)] text-center max-w-xs">
                    Please wait while we locate the best routes for your journey.
                </p>
            </motion.div>
        </div>
    );
};

export default AnimatedLoader;

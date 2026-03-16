import axios from 'axios';

const API_URL = 'http://127.0.0.1:8000';

const api = axios.create({
    baseURL: API_URL,
    headers: {
        'Content-Type': 'application/json',
    },
});

export const loginUser = async (reg_no_or_email, password) => {
    try {
        const response = await api.post('/login', {
            reg_no_or_email,
            password,
        });
        return response.data;
    } catch (error) {
        throw error.response?.data?.detail || 'Login failed. Please check your credentials.';
    }
};

export const sendOtp = async (target, isRegistration = true) => {
    try {
        const response = await api.post('/send_otp', {
            target,
            is_registration: isRegistration
        });
        return response.data;
    } catch (error) {
        throw error.response?.data?.detail || 'Failed to send OTP.';
    }
};

export const verifyOtp = async (target, code, isRegistration = true) => {
    try {
        const response = await api.post('/verify_otp', {
            target,
            code,
            is_registration: isRegistration
        });
        return response.data;
    } catch (error) {
        throw error.response?.data?.detail || 'OTP verification failed.';
    }
};

export const registerStudent = async (studentData) => {
    try {
        const response = await api.post('/register', studentData);
        return response.data;
    } catch (error) {
        throw error.response?.data?.detail || 'Registration failed.';
    }
};

export const getStops = async () => {
    try {
        const response = await api.get('/stops');
        return response.data;
    } catch (error) {
        throw error.response?.data?.detail || 'Failed to fetch stops.';
    }
};

export const searchTrips = async (fromStopId, toStopId) => {
    try {
        const response = await api.get('/search', {
            params: { from_stop_id: fromStopId, to_stop_id: toStopId }
        });
        return response.data;
    } catch (error) {
        throw error.response?.data?.detail || 'Failed to search trips.';
    }
};

export const getRouteStops = async (routeId, direction) => {
    try {
        const response = await api.get('/api/stops', {
            params: { rt: routeId, dir: direction }
        });
        return response.data;
    } catch (error) {
        throw error.response?.data?.detail || 'Failed to fetch route stops.';
    }
};

export default api;

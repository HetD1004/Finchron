"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.AuthController = void 0;
const bcryptjs_1 = __importDefault(require("bcryptjs"));
const jsonwebtoken_1 = __importDefault(require("jsonwebtoken"));
const uuid_1 = require("uuid");
const validator_1 = __importDefault(require("validator"));
const Database_1 = require("../database/Database");
const logger_1 = require("../utils/logger");
class AuthController {
    constructor() {
        this.db = new Database_1.Database();
    }
    // Register new user
    async register(req, res) {
        try {
            const { email, name, password } = req.body;
            // Validation
            if (!email || !name || !password) {
                res.status(400).json({
                    error: {
                        message: 'Email, name, and password are required',
                        status: 400,
                    },
                });
                return;
            }
            if (!validator_1.default.isEmail(email)) {
                res.status(400).json({
                    error: {
                        message: 'Invalid email format',
                        status: 400,
                    },
                });
                return;
            }
            if (password.length < 6) {
                res.status(400).json({
                    error: {
                        message: 'Password must be at least 6 characters long',
                        status: 400,
                    },
                });
                return;
            }
            // Check if user already exists
            const existingUser = await this.db.getUserByEmail(email);
            if (existingUser) {
                res.status(409).json({
                    error: {
                        message: 'User with this email already exists',
                        status: 409,
                    },
                });
                return;
            }
            // Hash password
            const saltRounds = parseInt(process.env.BCRYPT_ROUNDS || '12', 10);
            const passwordHash = await bcryptjs_1.default.hash(password, saltRounds);
            // Create user
            const userId = (0, uuid_1.v4)();
            const user = await this.db.createUser({
                id: userId,
                email: email.toLowerCase(),
                name: name.trim(),
                password_hash: passwordHash,
            });
            // Generate JWT token
            const token = this.generateToken({
                id: user.id,
                email: user.email,
                name: user.name,
            });
            logger_1.logger.info(`User registered successfully: ${user.email}`);
            res.status(201).json({
                message: 'User registered successfully',
                user: {
                    id: user.id,
                    email: user.email,
                    name: user.name,
                    created_at: user.created_at,
                },
                token,
            });
        }
        catch (error) {
            logger_1.logger.error('Registration error:', error);
            res.status(500).json({
                error: {
                    message: 'Internal server error during registration',
                    status: 500,
                },
            });
        }
    }
    // Login user
    async login(req, res) {
        try {
            const { email, password } = req.body;
            // Validation
            if (!email || !password) {
                res.status(400).json({
                    error: {
                        message: 'Email and password are required',
                        status: 400,
                    },
                });
                return;
            }
            // Find user
            const user = await this.db.getUserByEmail(email.toLowerCase());
            if (!user) {
                res.status(401).json({
                    error: {
                        message: 'Invalid email or password',
                        status: 401,
                    },
                });
                return;
            }
            // Check password
            const isValidPassword = await bcryptjs_1.default.compare(password, user.password_hash);
            if (!isValidPassword) {
                res.status(401).json({
                    error: {
                        message: 'Invalid email or password',
                        status: 401,
                    },
                });
                return;
            }
            // Generate JWT token
            const token = this.generateToken({
                id: user.id,
                email: user.email,
                name: user.name,
            });
            logger_1.logger.info(`User logged in successfully: ${user.email}`);
            res.json({
                message: 'Login successful',
                user: {
                    id: user.id,
                    email: user.email,
                    name: user.name,
                    profile_picture_url: user.profile_picture_url,
                },
                token,
            });
        }
        catch (error) {
            logger_1.logger.error('Login error:', error);
            res.status(500).json({
                error: {
                    message: 'Internal server error during login',
                    status: 500,
                },
            });
        }
    }
    // Google OAuth login (placeholder)
    async googleLogin(req, res) {
        try {
            const { googleToken, email, name, googleId } = req.body;
            if (!googleToken || !email || !name || !googleId) {
                res.status(400).json({
                    error: {
                        message: 'Google token, email, name, and Google ID are required',
                        status: 400,
                    },
                });
                return;
            }
            // Check if user exists by Google ID
            let user = await this.db.getUserByGoogleId(googleId);
            if (!user) {
                // Check if user exists by email
                user = await this.db.getUserByEmail(email.toLowerCase());
                if (user) {
                    // Update existing user with Google ID
                    user = await this.db.updateUser(user.id, { google_id: googleId });
                }
                else {
                    // Create new user
                    const userId = (0, uuid_1.v4)();
                    user = await this.db.createUser({
                        id: userId,
                        email: email.toLowerCase(),
                        name: name.trim(),
                        password_hash: '', // No password for Google users
                        google_id: googleId,
                    });
                }
            }
            // Generate JWT token
            const token = this.generateToken({
                id: user.id,
                email: user.email,
                name: user.name,
            });
            logger_1.logger.info(`User logged in with Google: ${user.email}`);
            res.json({
                message: 'Google login successful',
                user: {
                    id: user.id,
                    email: user.email,
                    name: user.name,
                    profile_picture_url: user.profile_picture_url,
                },
                token,
            });
        }
        catch (error) {
            logger_1.logger.error('Google login error:', error);
            res.status(500).json({
                error: {
                    message: 'Internal server error during Google login',
                    status: 500,
                },
            });
        }
    }
    // Refresh token
    async refreshToken(req, res) {
        try {
            const { token } = req.body;
            if (!token) {
                res.status(400).json({
                    error: {
                        message: 'Token is required',
                        status: 400,
                    },
                });
                return;
            }
            // Verify token
            const secret = process.env.JWT_SECRET;
            if (!secret) {
                throw new Error('JWT_SECRET not configured');
            }
            const decoded = jsonwebtoken_1.default.verify(token, secret);
            // Generate new token
            const newToken = this.generateToken({
                id: decoded.id,
                email: decoded.email,
                name: decoded.name,
            });
            res.json({
                message: 'Token refreshed successfully',
                token: newToken,
            });
        }
        catch (error) {
            logger_1.logger.error('Token refresh error:', error);
            res.status(401).json({
                error: {
                    message: 'Invalid or expired token',
                    status: 401,
                },
            });
        }
    }
    // Logout (placeholder - in a real app, you might want to blacklist tokens)
    async logout(req, res) {
        res.json({
            message: 'Logout successful',
        });
    }
    // Generate JWT token
    generateToken(payload) {
        const secret = process.env.JWT_SECRET;
        if (!secret) {
            throw new Error('JWT_SECRET not configured');
        }
        return jsonwebtoken_1.default.sign(payload, secret, { expiresIn: '7d' });
    }
}
exports.AuthController = AuthController;
//# sourceMappingURL=AuthController.js.map
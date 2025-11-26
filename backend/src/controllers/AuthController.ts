import { Request, Response } from 'express';
import bcrypt from 'bcryptjs';
import jwt, { SignOptions } from 'jsonwebtoken';
import { v4 as uuidv4 } from 'uuid';
import validator from 'validator';
import { Database } from '../database/Database';
import { logger } from '../utils/logger';

export class AuthController {
  private db: Database;

  constructor(database: Database) {
    this.db = database;
  }

  // Register new user
  async register(req: Request, res: Response): Promise<void> {
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

      if (!validator.isEmail(email)) {
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
      const passwordHash = await bcrypt.hash(password, saltRounds);

      // Create user
      const userId = uuidv4();
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

      logger.info(`User registered successfully: ${user.email}`);

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
    } catch (error) {
      logger.error('Registration error:', error);
      res.status(500).json({
        error: {
          message: 'Internal server error during registration',
          status: 500,
        },
      });
    }
  }

  // Login user
  async login(req: Request, res: Response): Promise<void> {
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
      const isValidPassword = await bcrypt.compare(password, user.password_hash);
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

      logger.info(`User logged in successfully: ${user.email}`);

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
    } catch (error) {
      logger.error('Login error:', error);
      res.status(500).json({
        error: {
          message: 'Internal server error during login',
          status: 500,
        },
      });
    }
  }

  // Google OAuth login
  async googleLogin(req: Request, res: Response): Promise<void> {
    try {
      const { idToken } = req.body;

      logger.info(`Google login request received. Token present: ${!!idToken}`);
      
      if (!idToken) {
        res.status(400).json({
          error: {
            message: 'Google ID token is required',
            status: 400,
          },
        });
        return;
      }

      // Log the first few characters of the token for debugging
      logger.info(`ID Token length: ${idToken.length}, starts with: ${idToken.substring(0, 50)}...`);

      // Verify this is a JWT-formatted token
      const tokenParts = idToken.split('.');
      if (tokenParts.length !== 3) {
        logger.error(`Invalid JWT format. Parts: ${tokenParts.length}`);
        res.status(400).json({
          error: {
            message: 'Invalid Google ID token format',
            status: 400,
          },
        });
        return;
      }

      // TODO: Verify the ID token with Google
      // For now, we'll decode the JWT payload (not secure for production)
      try {
        // Decode JWT payload (base64 decode the middle part)
        const payload = JSON.parse(
          Buffer.from(tokenParts[1], 'base64').toString()
        );

        logger.info(`Decoded payload: ${JSON.stringify(payload, null, 2)}`);

        const email = payload.email;
        const name = payload.name;
        const googleId = payload.sub;

        if (!email || !name || !googleId) {
          logger.error(`Missing required fields in payload. Email: ${!!email}, Name: ${!!name}, GoogleId: ${!!googleId}`);
          res.status(400).json({
            error: {
              message: 'Invalid Google ID token - missing required fields',
              status: 400,
            },
          });
          return;
        }

        // Check if user exists by Google ID
        logger.info(`Looking up user by Google ID: ${googleId}`);
        let user;
        try {
          user = await this.db.getUserByGoogleId(googleId);
          logger.info(`User found by Google ID: ${!!user}`);
        } catch (dbError) {
          logger.error(`Database error during getUserByGoogleId:`, dbError);
          throw dbError;
        }
        
        if (!user) {
          // Check if user exists by email
          logger.info(`Looking up user by email: ${email.toLowerCase()}`);
          user = await this.db.getUserByEmail(email.toLowerCase());
          logger.info(`User found by email: ${!!user}`);
          
          if (user) {
            // Update existing user with Google ID
            logger.info(`Updating existing user with Google ID`);
            user = await this.db.updateUser(user.id, { google_id: googleId });
            logger.info(`User updated successfully`);
          } else {
            // Create new user
            const userId = uuidv4();
            logger.info(`Creating new user with ID: ${userId}`);
            user = await this.db.createUser({
              id: userId,
              email: email.toLowerCase(),
              name: name.trim(),
              password_hash: '', // No password for Google users
              google_id: googleId,
            });
            logger.info(`User created successfully: ${user.email}`);
          }
        }

        // Generate JWT token
        const token = this.generateToken({
          id: user.id,
          email: user.email,
          name: user.name,
        });

        logger.info(`User logged in with Google: ${user.email}`);

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
      } catch (decodeError) {
        logger.error('Failed to decode Google ID token:', decodeError);
        res.status(400).json({
          error: {
            message: 'Invalid Google ID token format',
            status: 400,
          },
        });
      }
    } catch (error) {
      logger.error('Google login error:', error);
      res.status(500).json({
        error: {
          message: 'Internal server error during Google login',
          status: 500,
        },
      });
    }
  }

  // Refresh token
  async refreshToken(req: Request, res: Response): Promise<void> {
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

      const decoded = jwt.verify(token, secret) as any;
      
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
    } catch (error) {
      logger.error('Token refresh error:', error);
      res.status(401).json({
        error: {
          message: 'Invalid or expired token',
          status: 401,
        },
      });
    }
  }

  // Logout (placeholder - in a real app, you might want to blacklist tokens)
  async logout(req: Request, res: Response): Promise<void> {
    res.json({
      message: 'Logout successful',
    });
  }

  // Generate JWT token
  private generateToken(payload: { id: string; email: string; name: string }): string {
    const secret = process.env.JWT_SECRET;
    if (!secret) {
      throw new Error('JWT_SECRET not configured');
    }
    
    return jwt.sign(payload, secret, { expiresIn: '7d' });
  }
}

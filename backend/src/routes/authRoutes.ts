import { Router } from 'express';
import { AuthController } from '../controllers/AuthController';
import { Database } from '../database/Database';

function createAuthRoutes(database: Database): Router {
  const router = Router();
  const authController = new AuthController(database);

  // Register new user
  router.post('/register', (req, res) => authController.register(req, res));

  // Login user
  router.post('/login', (req, res) => authController.login(req, res));

  // Google OAuth login
  router.post('/google', (req, res) => authController.googleLogin(req, res));

  // Refresh JWT token
  router.post('/refresh', (req, res) => authController.refreshToken(req, res));

  // Logout user
  router.post('/logout', (req, res) => authController.logout(req, res));

  return router;
}

export default createAuthRoutes;

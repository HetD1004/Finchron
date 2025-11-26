"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
const express_1 = require("express");
const AuthController_1 = require("../controllers/AuthController");
const router = (0, express_1.Router)();
const authController = new AuthController_1.AuthController();
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
exports.default = router;
//# sourceMappingURL=authRoutes.js.map
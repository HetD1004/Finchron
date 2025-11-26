"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
const express_1 = require("express");
const router = (0, express_1.Router)();
// Placeholder for user routes
router.get('/profile', (req, res) => {
    res.json({ message: 'User profile endpoint - coming soon' });
});
router.put('/profile', (req, res) => {
    res.json({ message: 'Update profile endpoint - coming soon' });
});
router.delete('/account', (req, res) => {
    res.json({ message: 'Delete account endpoint - coming soon' });
});
exports.default = router;
//# sourceMappingURL=userRoutes.js.map
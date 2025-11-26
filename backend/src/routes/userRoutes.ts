import { Router } from 'express';

const router = Router();

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

export default router;

/**
 * Projects API Routes
 */

import express from 'express';
import { requireAuth } from '../middleware/auth.js';

const router = express.Router();

// Get all projects (already implemented in video.js)
// This is a stub for additional project-specific routes

router.get('/', requireAuth, async (req, res) => {
  res.json({ message: 'Projects endpoint - see /api/videos/projects' });
});

export default router;

/**
 * Authentication Routes
 * Google and Apple OAuth login/logout
 */

import express from 'express';
import passport from 'passport';

const router = express.Router();

// Google OAuth login
router.get('/google',
  passport.authenticate('google', {
    scope: ['profile', 'email'],
    prompt: 'select_account'
  })
);

// Google OAuth callback
router.get('/google/callback',
  passport.authenticate('google', { failureRedirect: '/login?error=google' }),
  (req, res) => {
    // Successful authentication, redirect to frontend
    const frontendURL = process.env.FRONTEND_URL || 'http://localhost:5173';
    res.redirect(`${frontendURL}/dashboard?login=success`);
  }
);

// Apple Sign In login
router.post('/apple',
  passport.authenticate('apple', {
    scope: ['name', 'email']
  })
);

// Apple Sign In callback
router.post('/apple/callback',
  passport.authenticate('apple', { failureRedirect: '/login?error=apple' }),
  (req, res) => {
    const frontendURL = process.env.FRONTEND_URL || 'http://localhost:5173';
    res.redirect(`${frontendURL}/dashboard?login=success`);
  }
);

// Logout
router.post('/logout', (req, res) => {
  req.logout((err) => {
    if (err) {
      return res.status(500).json({ error: 'Logout failed' });
    }
    res.json({ message: 'Logged out successfully' });
  });
});

// Get current user
router.get('/me', (req, res) => {
  if (!req.isAuthenticated()) {
    return res.status(401).json({ error: 'Not authenticated' });
  }

  res.json({
    user: {
      id: req.user.id,
      email: req.user.email,
      name: req.user.name,
      avatar: req.user.avatar,
      provider: req.user.provider,
      createdAt: req.user.createdAt
    }
  });
});

// Check authentication status
router.get('/status', (req, res) => {
  res.json({
    authenticated: req.isAuthenticated(),
    user: req.isAuthenticated() ? {
      id: req.user.id,
      email: req.user.email,
      name: req.user.name
    } : null
  });
});

export default router;

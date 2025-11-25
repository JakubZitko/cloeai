/**
 * Authentication Routes
 * Google and Apple OAuth login/logout
 */

import express from 'express';
import passport from 'passport';
import User from '../models/User.js';

const router = express.Router();

// ============================================
// DEV LOGIN - Only works in development mode
// ============================================
router.get('/dev-login', async (req, res) => {
  if (process.env.NODE_ENV === 'production') {
    return res.status(404).json({ error: 'Not found' });
  }

  try {
    // Find or create demo user
    let [user] = await User.findOrCreate({
      where: { email: 'demo@cloe.ai' },
      defaults: {
        name: 'Demo User',
        email: 'demo@cloe.ai',
        googleId: 'demo-google-id-12345',
        provider: 'google',
        subscription: 'pro',
        creditsRemaining: 100
      }
    });

    // Log them in
    req.login(user, (err) => {
      if (err) {
        return res.status(500).json({ error: 'Login failed' });
      }

      const frontendURL = process.env.FRONTEND_URL || 'http://localhost:5173';
      res.redirect(`${frontendURL}/dashboard?login=success`);
    });
  } catch (error) {
    console.error('Dev login error:', error);
    res.status(500).json({ error: 'Login failed' });
  }
});

// Get API token for desktop app (dev mode)
router.get('/dev-token', async (req, res) => {
  if (process.env.NODE_ENV === 'production') {
    return res.status(404).json({ error: 'Not found' });
  }

  if (!req.isAuthenticated()) {
    return res.status(401).json({ error: 'Not authenticated' });
  }

  // In a real app, this would generate a proper JWT token
  // For demo purposes, we use the session ID
  res.json({
    token: req.sessionID,
    message: 'Use this token in the macOS app Settings > Cloud to connect'
  });
});

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

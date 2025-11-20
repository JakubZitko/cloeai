/**
 * Authentication Middleware
 */

export function requireAuth(req, res, next) {
  if (!req.isAuthenticated()) {
    return res.status(401).json({
      error: 'Authentication required',
      message: 'Please log in to access this resource'
    });
  }
  next();
}

export function requireAdmin(req, res, next) {
  if (!req.isAuthenticated()) {
    return res.status(401).json({ error: 'Authentication required' });
  }

  if (req.user.role !== 'admin') {
    return res.status(403).json({ error: 'Admin access required' });
  }

  next();
}

export function checkCredits(requiredCredits = 1) {
  return async (req, res, next) => {
    if (!req.isAuthenticated()) {
      return res.status(401).json({ error: 'Authentication required' });
    }

    if (req.user.creditsRemaining < requiredCredits) {
      return res.status(403).json({
        error: 'Insufficient credits',
        creditsRemaining: req.user.creditsRemaining,
        creditsRequired: requiredCredits
      });
    }

    next();
  };
}

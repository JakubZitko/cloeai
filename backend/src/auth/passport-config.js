/**
 * Passport OAuth Configuration
 * Google and Apple Sign In strategies
 */

import passport from 'passport';
import { Strategy as GoogleStrategy } from 'passport-google-oauth20';
import { Strategy as AppleStrategy } from 'passport-apple';
import User from '../models/User.js';

// Serialize user for session
passport.serializeUser((user, done) => {
  done(null, user.id);
});

// Deserialize user from session
passport.deserializeUser(async (id, done) => {
  try {
    const user = await User.findByPk(id);
    done(null, user);
  } catch (error) {
    done(error, null);
  }
});

// Google OAuth Strategy
passport.use(new GoogleStrategy({
  clientID: process.env.GOOGLE_CLIENT_ID,
  clientSecret: process.env.GOOGLE_CLIENT_SECRET,
  callbackURL: `${process.env.BACKEND_URL}/auth/google/callback`,
  scope: ['profile', 'email']
}, async (accessToken, refreshToken, profile, done) => {
  try {
    console.log('🔐 Google OAuth callback:', profile.id);

    // Find or create user
    let user = await User.findOne({
      where: { googleId: profile.id }
    });

    if (!user) {
      // Create new user
      user = await User.create({
        googleId: profile.id,
        email: profile.emails[0].value,
        name: profile.displayName,
        avatar: profile.photos[0]?.value,
        provider: 'google'
      });

      console.log('✅ New user created:', user.email);
    } else {
      // Update existing user
      await user.update({
        name: profile.displayName,
        avatar: profile.photos[0]?.value,
        lastLogin: new Date()
      });

      console.log('✅ User logged in:', user.email);
    }

    return done(null, user);

  } catch (error) {
    console.error('❌ Google OAuth error:', error);
    return done(error, null);
  }
}));

// Apple Sign In Strategy
passport.use(new AppleStrategy({
  clientID: process.env.APPLE_CLIENT_ID,
  teamID: process.env.APPLE_TEAM_ID,
  callbackURL: `${process.env.BACKEND_URL}/auth/apple/callback`,
  keyID: process.env.APPLE_KEY_ID,
  privateKeyLocation: process.env.APPLE_PRIVATE_KEY_PATH || './AuthKey_Apple.p8',
  passReqToCallback: false
}, async (accessToken, refreshToken, idToken, profile, done) => {
  try {
    console.log('🍎 Apple Sign In callback:', profile.id);

    // Find or create user
    let user = await User.findOne({
      where: { appleId: profile.id }
    });

    if (!user) {
      // Extract email from idToken
      const email = profile.email || `${profile.id}@privaterelay.appleid.com`;

      // Create new user
      user = await User.create({
        appleId: profile.id,
        email: email,
        name: profile.name?.firstName
          ? `${profile.name.firstName} ${profile.name.lastName || ''}`
          : 'Apple User',
        provider: 'apple'
      });

      console.log('✅ New Apple user created:', user.email);
    } else {
      // Update last login
      await user.update({
        lastLogin: new Date()
      });

      console.log('✅ Apple user logged in:', user.email);
    }

    return done(null, user);

  } catch (error) {
    console.error('❌ Apple Sign In error:', error);
    return done(error, null);
  }
}));

console.log('✅ Passport strategies configured');

export default passport;

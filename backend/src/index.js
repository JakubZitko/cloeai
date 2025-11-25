/**
 * Cloe Video Backend API
 * Main server entry point
 */

import express from 'express';
import session from 'express-session';
import passport from 'passport';
import cors from 'cors';
import dotenv from 'dotenv';
import { fileURLToPath } from 'url';
import { dirname, join } from 'path';
import { createServer } from 'http';
import { WebSocketServer } from 'ws';

// Import routes
import authRoutes from './auth/routes.js';
import videoRoutes from './api/video.js';
import projectRoutes from './api/projects.js';
import userRoutes from './api/user.js';
import cloeRoutes from './api/cloe.js';

// Import config
import './auth/passport-config.js';
import { connectDatabase } from './config/database.js';
import { initRedis } from './config/redis.js';

dotenv.config();

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

const app = express();
const server = createServer(app);
const PORT = process.env.PORT || 3000;

// WebSocket server for real-time updates
const wss = new WebSocketServer({ server, path: '/ws' });

// Store connected clients by project ID
const projectClients = new Map();

wss.on('connection', (ws, req) => {
  console.log('[WS] Client connected');

  ws.on('message', (message) => {
    try {
      const data = JSON.parse(message);

      if (data.type === 'subscribe' && data.projectId) {
        // Subscribe to project updates
        if (!projectClients.has(data.projectId)) {
          projectClients.set(data.projectId, new Set());
        }
        projectClients.get(data.projectId).add(ws);
        ws.projectId = data.projectId;
        console.log(`[WS] Client subscribed to project ${data.projectId}`);

        // Send acknowledgment
        ws.send(JSON.stringify({ type: 'subscribed', projectId: data.projectId }));
      }
    } catch (e) {
      console.error('[WS] Message parse error:', e);
    }
  });

  ws.on('close', () => {
    // Remove from project subscribers
    if (ws.projectId && projectClients.has(ws.projectId)) {
      projectClients.get(ws.projectId).delete(ws);
      if (projectClients.get(ws.projectId).size === 0) {
        projectClients.delete(ws.projectId);
      }
    }
    console.log('[WS] Client disconnected');
  });

  ws.on('error', (error) => {
    console.error('[WS] Error:', error);
  });
});

// Export function to broadcast project updates
export function broadcastProjectUpdate(projectId, data) {
  if (projectClients.has(projectId)) {
    const message = JSON.stringify({ type: 'project_update', projectId, data });
    projectClients.get(projectId).forEach((client) => {
      if (client.readyState === 1) { // WebSocket.OPEN
        client.send(message);
      }
    });
  }
}

// Middleware
app.use(cors({
  origin: process.env.FRONTEND_URL || 'http://localhost:5173',
  credentials: true
}));

app.use(express.json());
app.use(express.urlencoded({ extended: true }));

// Session configuration
app.use(session({
  secret: process.env.SESSION_SECRET || 'cloe-video-secret-change-in-production',
  resave: false,
  saveUninitialized: false,
  cookie: {
    secure: process.env.NODE_ENV === 'production',
    httpOnly: true,
    maxAge: 24 * 60 * 60 * 1000 // 24 hours
  }
}));

// Passport initialization
app.use(passport.initialize());
app.use(passport.session());

// Routes
app.use('/auth', authRoutes);
app.use('/api/videos', videoRoutes);
app.use('/api/projects', projectRoutes);
app.use('/api/user', userRoutes);
app.use('/api/cloe', cloeRoutes);

// Health check
app.get('/health', (req, res) => {
  res.json({
    status: 'healthy',
    timestamp: new Date().toISOString(),
    uptime: process.uptime()
  });
});

// Error handling middleware
app.use((err, req, res, next) => {
  console.error('Error:', err);
  res.status(err.status || 500).json({
    error: {
      message: err.message || 'Internal server error',
      ...(process.env.NODE_ENV === 'development' && { stack: err.stack })
    }
  });
});

// Initialize services and start server
async function startServer() {
  try {
    // Connect to database
    await connectDatabase();
    console.log('[OK] Database connected');

    // Connect to Redis
    await initRedis();
    console.log('[OK] Redis connected');

    // Start server (use http server for WebSocket support)
    server.listen(PORT, () => {
      console.log(`[SERVER] Cloe Video Backend running on port ${PORT}`);
      console.log(`   Environment: ${process.env.NODE_ENV || 'development'}`);
      console.log(`   Frontend URL: ${process.env.FRONTEND_URL || 'http://localhost:5173'}`);
      console.log(`   WebSocket: ws://localhost:${PORT}/ws`);
    });

  } catch (error) {
    console.error('[ERROR] Failed to start server:', error);
    process.exit(1);
  }
}

startServer();

export default app;

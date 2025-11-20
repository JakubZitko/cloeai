/**
 * Video API Routes
 * Upload, analyze, and process videos
 */

import express from 'express';
import multer from 'multer';
import { v4 as uuidv4 } from 'uuid';
import path from 'path';
import fs from 'fs/promises';
import Project from '../models/Project.js';
import { requireAuth } from '../middleware/auth.js';
import { addVideoAnalysisJob } from '../services/job-queue.js';

const router = express.Router();

// Configure multer for video upload
const storage = multer.diskStorage({
  destination: async (req, file, cb) => {
    const uploadDir = path.join(process.cwd(), 'uploads', 'videos');
    await fs.mkdir(uploadDir, { recursive: true });
    cb(null, uploadDir);
  },
  filename: (req, file, cb) => {
    const uniqueName = `${uuidv4()}${path.extname(file.originalname)}`;
    cb(null, uniqueName);
  }
});

const upload = multer({
  storage,
  limits: {
    fileSize: 500 * 1024 * 1024 // 500MB max
  },
  fileFilter: (req, file, cb) => {
    // Accept video files only
    const allowedTypes = /mp4|mov|avi|mkv|webm/;
    const extname = allowedTypes.test(path.extname(file.originalname).toLowerCase());
    const mimetype = allowedTypes.test(file.mimetype);

    if (extname && mimetype) {
      cb(null, true);
    } else {
      cb(new Error('Only video files are allowed'));
    }
  }
});

// Upload video
router.post('/upload', requireAuth, upload.single('video'), async (req, res) => {
  try {
    const { name, description, requirements } = req.body;

    if (!req.file) {
      return res.status(400).json({ error: 'No video file uploaded' });
    }

    console.log('📹 Video uploaded:', req.file.filename);

    // Create project
    const project = await Project.create({
      userId: req.user.id,
      name: name || `Video Project ${Date.now()}`,
      description: description || '',
      status: 'analyzing',
      originalVideoPath: req.file.path,
      progress: 10
    });

    // Add to analysis queue
    await addVideoAnalysisJob({
      projectId: project.id,
      videoPath: req.file.path,
      requirements: requirements ? JSON.parse(requirements) : {}
    });

    console.log('✅ Project created:', project.id);

    res.json({
      success: true,
      project: {
        id: project.id,
        name: project.name,
        status: project.status,
        progress: project.progress
      }
    });

  } catch (error) {
    console.error('❌ Upload error:', error);
    res.status(500).json({ error: error.message });
  }
});

// Get project status
router.get('/project/:id', requireAuth, async (req, res) => {
  try {
    const project = await Project.findOne({
      where: {
        id: req.params.id,
        userId: req.user.id
      }
    });

    if (!project) {
      return res.status(404).json({ error: 'Project not found' });
    }

    res.json({
      project: {
        id: project.id,
        name: project.name,
        status: project.status,
        progress: project.progress,
        analysis: project.analysis,
        references: project.references,
        outputVideoPath: project.outputVideoPath,
        errorMessage: project.errorMessage,
        createdAt: project.createdAt,
        updatedAt: project.updatedAt
      }
    });

  } catch (error) {
    console.error('❌ Get project error:', error);
    res.status(500).json({ error: error.message });
  }
});

// Get all user projects
router.get('/projects', requireAuth, async (req, res) => {
  try {
    const projects = await Project.findAll({
      where: { userId: req.user.id },
      order: [['createdAt', 'DESC']],
      limit: 50
    });

    res.json({
      projects: projects.map(p => ({
        id: p.id,
        name: p.name,
        status: p.status,
        progress: p.progress,
        createdAt: p.createdAt
      }))
    });

  } catch (error) {
    console.error('❌ Get projects error:', error);
    res.status(500).json({ error: error.message });
  }
});

// Delete project
router.delete('/project/:id', requireAuth, async (req, res) => {
  try {
    const project = await Project.findOne({
      where: {
        id: req.params.id,
        userId: req.user.id
      }
    });

    if (!project) {
      return res.status(404).json({ error: 'Project not found' });
    }

    // Delete video files
    if (project.originalVideoPath) {
      try {
        await fs.unlink(project.originalVideoPath);
      } catch (e) {
        console.warn('Could not delete original video:', e.message);
      }
    }

    if (project.outputVideoPath) {
      try {
        await fs.unlink(project.outputVideoPath);
      } catch (e) {
        console.warn('Could not delete output video:', e.message);
      }
    }

    await project.destroy();

    res.json({ success: true });

  } catch (error) {
    console.error('❌ Delete project error:', error);
    res.status(500).json({ error: error.message });
  }
});

export default router;

/**
 * Video Analysis Worker (Simplified - No Rendering)
 * Processes video analysis and reference finding only
 */

import { spawn } from 'child_process';
import { fileURLToPath } from 'url';
import { dirname, join } from 'path';
import fs from 'fs/promises';
import Project from '../models/Project.js';
import { videoAnalysisQueue } from '../services/job-queue.js';
import { connectDatabase } from '../config/database.js';
import dotenv from 'dotenv';

dotenv.config();

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);
const rootDir = join(__dirname, '../..');

console.log('🔧 Video Analysis Worker starting...');

// Connect to database
await connectDatabase();

// Process video analysis jobs
videoAnalysisQueue.process(async (job) => {
  const { projectId, videoPath, requirements } = job.data;

  console.log(`\n📊 Processing analysis job: ${job.id}`);
  console.log(`   Project: ${projectId}`);
  console.log(`   Video: ${videoPath}`);

  try {
    // Update project status
    const project = await Project.findByPk(projectId);

    if (!project) {
      throw new Error(`Project not found: ${projectId}`);
    }

    await project.update({
      status: 'analyzing',
      progress: 20
    });

    job.progress(20);

    // Run Python video analyzer
    console.log('🐍 Running video analysis...');

    const analysisOutput = join(rootDir, `uploads/analysis/${projectId}_analysis.json`);
    await fs.mkdir(join(rootDir, 'uploads/analysis'), { recursive: true });

    const analysisResult = await runPythonScript(
      join(rootDir, '../video-analyzer/analyzer.py'),
      [videoPath, analysisOutput],
      (data) => {
        console.log(`   ${data}`);
      }
    );

    job.progress(50);

    // Load analysis results
    const analysisData = JSON.parse(await fs.readFile(analysisOutput, 'utf8'));

    await project.update({
      analysis: analysisData,
      progress: 60
    });

    console.log('✅ Video analysis complete');

    // Find reference videos
    console.log('🔎 Finding reference videos...');

    const referencesOutput = join(rootDir, `uploads/analysis/${projectId}_references.json`);

    await runPythonScript(
      join(rootDir, '../video-analyzer/reference_finder.py'),
      [analysisOutput, referencesOutput],
      (data) => {
        console.log(`   ${data}`);
      }
    );

    job.progress(80);

    // Load reference results
    const referencesData = JSON.parse(await fs.readFile(referencesOutput, 'utf8'));

    await project.update({
      references: referencesData,
      progress: 90
    });

    console.log('✅ Reference videos found');

    // Mark as completed - no rendering needed!
    await project.update({
      status: 'completed',
      progress: 100
    });

    job.progress(100);
    console.log('🎉 Project analysis complete!');

    return {
      success: true,
      analysis: analysisData,
      references: referencesData
    };

  } catch (error) {
    console.error(`❌ Analysis job failed: ${error.message}`);

    // Update project with error
    const project = await Project.findByPk(projectId);
    if (project) {
      await project.update({
        status: 'failed',
        errorMessage: error.message
      });
    }

    throw error;
  }
});

// Helper: Run Python script
function runPythonScript(scriptPath, args, onData) {
  return new Promise((resolve, reject) => {
    const python = spawn('python3', [scriptPath, ...args]);

    let output = '';
    let errorOutput = '';

    python.stdout.on('data', (data) => {
      const text = data.toString();
      output += text;
      if (onData) onData(text.trim());
    });

    python.stderr.on('data', (data) => {
      errorOutput += data.toString();
    });

    python.on('close', (code) => {
      if (code === 0) {
        resolve(output);
      } else {
        reject(new Error(`Python script failed: ${errorOutput}`));
      }
    });

    python.on('error', (error) => {
      reject(error);
    });
  });
}

console.log('✅ Video Analysis Worker ready');
console.log('   Listening for jobs...');
console.log('   No rendering - just analysis & reference finding');

// Handle graceful shutdown
process.on('SIGTERM', async () => {
  console.log('\n👋 Shutting down worker...');
  await videoAnalysisQueue.close();
  process.exit(0);
});

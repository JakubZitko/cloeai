/**
 * Render Worker
 * Processes video analysis and rendering jobs
 */

import { spawn } from 'child_process';
import { fileURLToPath } from 'url';
import { dirname, join } from 'path';
import fs from 'fs/promises';
import Project from '../models/User.js';
import { videoAnalysisQueue, videoRenderQueue } from '../services/job-queue.js';
import { connectDatabase } from '../config/database.js';
import dotenv from 'dotenv';

dotenv.config();

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);
const rootDir = join(__dirname, '../..');

console.log('🔧 Render Worker starting...');

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

    // Queue render job
    await videoRenderQueue.add({
      projectId,
      analysisPath: analysisOutput,
      referencesPath: referencesOutput
    });

    await project.update({
      status: 'processing',
      progress: 100
    });

    job.progress(100);

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

// Process video render jobs
videoRenderQueue.process(async (job) => {
  const { projectId, analysisPath, referencesPath } = job.data;

  console.log(`\n🎬 Processing render job: ${job.id}`);
  console.log(`   Project: ${projectId}`);

  try {
    const project = await Project.findByPk(projectId);

    if (!project) {
      throw new Error(`Project not found: ${projectId}`);
    }

    await project.update({
      status: 'rendering',
      progress: 10
    });

    job.progress(10);

    // Generate After Effects config
    console.log('📋 Generating After Effects config...');

    const aeConfig = await generateAEConfig(project, analysisPath, referencesPath);
    const aeConfigPath = join(rootDir, `uploads/ae/${projectId}_config.json`);

    await fs.mkdir(join(rootDir, 'uploads/ae'), { recursive: true });
    await fs.writeFile(aeConfigPath, JSON.stringify(aeConfig, null, 2));

    job.progress(30);

    // Run After Effects automation
    console.log('🎨 Running After Effects...');

    const aeProjectPath = join(rootDir, `uploads/ae/${projectId}.aep`);
    const outputVideoPath = join(rootDir, `uploads/output/${projectId}.mp4`);

    await fs.mkdir(join(rootDir, 'uploads/output'), { recursive: true });

    // Execute After Effects (if available)
    // NOTE: This requires After Effects to be installed and aerender in PATH
    if (process.platform === 'darwin') { // macOS
      await runAfterEffects(aeConfigPath, aeProjectPath, outputVideoPath);
    } else {
      console.warn('⚠️  After Effects rendering not available on this platform');
      // For development, just copy the original video
      await fs.copyFile(project.originalVideoPath, outputVideoPath);
    }

    job.progress(90);

    await project.update({
      status: 'completed',
      progress: 100,
      aeProjectPath,
      outputVideoPath
    });

    console.log('✅ Render complete');

    job.progress(100);

    return {
      success: true,
      outputPath: outputVideoPath
    };

  } catch (error) {
    console.error(`❌ Render job failed: ${error.message}`);

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

// Helper: Generate After Effects config
async function generateAEConfig(project, analysisPath, referencesPath) {
  const analysis = JSON.parse(await fs.readFile(analysisPath, 'utf8'));
  const references = JSON.parse(await fs.readFile(referencesPath, 'utf8'));

  return {
    projectName: project.name,
    duration: analysis.video_metadata?.duration || 60,
    width: 1920,
    height: 1080,
    frameRate: 30,
    originalVideoPath: project.originalVideoPath,
    colorPalette: analysis.visual_style?.color_palette || ['#000000', '#FFFFFF'],
    animations: analysis.animations_needed?.map((anim, i) => ({
      type: anim.type.toLowerCase().replace(/ /g, '_'),
      startTime: i * 5,
      duration: parseFloat(anim.duration) || 3,
      ...anim
    })) || [],
    textOverlays: [],
    outputDir: join(rootDir, 'uploads/ae'),
    outputProjectPath: join(rootDir, `uploads/ae/${project.id}.aep`),
    outputVideoPath: join(rootDir, `uploads/output/${project.id}.mp4`),
    autoRender: false // We'll render separately
  };
}

// Helper: Run After Effects
async function runAfterEffects(configPath, projectPath, outputPath) {
  // This is a simplified version - full implementation would use aerender
  console.log('ℹ️  After Effects automation skipped (requires AE installation)');
  console.log(`   Config: ${configPath}`);
  console.log(`   Project: ${projectPath}`);
  console.log(`   Output: ${outputPath}`);

  // In production, you would run:
  // /Applications/Adobe After Effects 2024/aerender -project ${projectPath} -output ${outputPath}
}

console.log('✅ Render Worker ready');
console.log('   Listening for jobs...');

// Handle graceful shutdown
process.on('SIGTERM', async () => {
  console.log('\n👋 Shutting down worker...');
  await videoAnalysisQueue.close();
  await videoRenderQueue.close();
  process.exit(0);
});

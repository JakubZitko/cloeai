/**
 * Job Queue Service
 * Bull queue for video processing
 */

import Queue from 'bull';
import dotenv from 'dotenv';

dotenv.config();

// Create queues
export const videoAnalysisQueue = new Queue('video-analysis', {
  redis: {
    host: process.env.REDIS_HOST || 'localhost',
    port: process.env.REDIS_PORT || 6379
  },
  defaultJobOptions: {
    attempts: 3,
    backoff: {
      type: 'exponential',
      delay: 2000
    },
    removeOnComplete: 100,
    removeOnFail: false
  }
});

export const videoRenderQueue = new Queue('video-render', {
  redis: {
    host: process.env.REDIS_HOST || 'localhost',
    port: process.env.REDIS_PORT || 6379
  },
  defaultJobOptions: {
    attempts: 2,
    backoff: {
      type: 'exponential',
      delay: 5000
    },
    removeOnComplete: 50,
    removeOnFail: false
  }
});

// Add job to analysis queue
export async function addVideoAnalysisJob(data) {
  const job = await videoAnalysisQueue.add(data, {
    priority: data.priority || 5
  });

  console.log(`📊 Video analysis job added: ${job.id}`);

  return job;
}

// Add job to render queue
export async function addVideoRenderJob(data) {
  const job = await videoRenderQueue.add(data, {
    priority: data.priority || 5,
    timeout: 30 * 60 * 1000 // 30 minutes timeout
  });

  console.log(`🎬 Video render job added: ${job.id}`);

  return job;
}

// Get job status
export async function getJobStatus(jobId, queueName = 'video-analysis') {
  const queue = queueName === 'video-analysis' ? videoAnalysisQueue : videoRenderQueue;
  const job = await queue.getJob(jobId);

  if (!job) {
    return null;
  }

  return {
    id: job.id,
    data: job.data,
    progress: job.progress(),
    state: await job.getState(),
    failedReason: job.failedReason,
    finishedOn: job.finishedOn,
    processedOn: job.processedOn
  };
}

// Queue event listeners
videoAnalysisQueue.on('completed', (job, result) => {
  console.log(`✅ Analysis job ${job.id} completed`);
});

videoAnalysisQueue.on('failed', (job, err) => {
  console.error(`❌ Analysis job ${job.id} failed:`, err.message);
});

videoRenderQueue.on('completed', (job, result) => {
  console.log(`✅ Render job ${job.id} completed`);
});

videoRenderQueue.on('failed', (job, err) => {
  console.error(`❌ Render job ${job.id} failed:`, err.message);
});

console.log('✅ Job queues initialized');

export default { videoAnalysisQueue, videoRenderQueue };

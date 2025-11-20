/**
 * Job Queue Service
 * Bull queue for video analysis (no rendering)
 */

import Queue from 'bull';
import dotenv from 'dotenv';

dotenv.config();

// Create analysis queue
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

// Add job to analysis queue
export async function addVideoAnalysisJob(data) {
  const job = await videoAnalysisQueue.add(data, {
    priority: data.priority || 5
  });

  console.log(`📊 Video analysis job added: ${job.id}`);

  return job;
}

// Get job status
export async function getJobStatus(jobId) {
  const job = await videoAnalysisQueue.getJob(jobId);

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

console.log('✅ Video analysis queue initialized');

export default { videoAnalysisQueue };

/**
 * Demo Data Seeder
 * Seeds the database with sample data for testing the dashboard
 *
 * Run: node src/scripts/seed-demo-data.js
 */

import { sequelize, connectDatabase } from '../config/database.js';
import User from '../models/User.js';

async function seedDemoData() {
  console.log('[SEED] Starting demo data seeder...\n');

  try {
    // Connect to database
    await connectDatabase();

    // Create or find demo user
    let [user, created] = await User.findOrCreate({
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

    if (created) {
      console.log('[SEED] Created demo user: demo@cloe.ai');
    } else {
      console.log('[SEED] Found existing demo user: demo@cloe.ai');
    }

    const userId = user.id;

    // Clear existing demo data
    await sequelize.query('DELETE FROM cloe_actions WHERE user_id = ?', { replacements: [userId] });
    await sequelize.query('DELETE FROM cloe_contacts WHERE user_id = ?', { replacements: [userId] });
    await sequelize.query('DELETE FROM cloe_workflows WHERE user_id = ?', { replacements: [userId] });
    console.log('[SEED] Cleared existing demo data');

    // Seed Actions (Activity Log)
    const actions = generateDemoActions(userId);
    for (const action of actions) {
      await sequelize.query(
        `INSERT INTO cloe_actions (user_id, type, app, target, value, timestamp) VALUES (?, ?, ?, ?, ?, ?)`,
        { replacements: [action.user_id, action.type, action.app, action.target, action.value, action.timestamp] }
      );
    }
    console.log(`[SEED] Added ${actions.length} demo actions`);

    // Seed Contacts
    const contacts = generateDemoContacts(userId);
    for (const contact of contacts) {
      await sequelize.query(
        `INSERT INTO cloe_contacts (user_id, name, email, phone, relationship, aliases, locations, last_contact)
         VALUES (?, ?, ?, ?, ?, ?, ?, ?)`,
        { replacements: [
          contact.user_id, contact.name, contact.email, contact.phone, contact.relationship,
          JSON.stringify(contact.aliases), JSON.stringify(contact.locations), contact.last_contact
        ]}
      );
    }
    console.log(`[SEED] Added ${contacts.length} demo contacts`);

    // Seed Workflows
    const workflows = generateDemoWorkflows(userId);
    for (const workflow of workflows) {
      await sequelize.query(
        `INSERT INTO cloe_workflows (user_id, name, steps, trigger_patterns, frequency, last_used)
         VALUES (?, ?, ?, ?, ?, ?)`,
        { replacements: [
          workflow.user_id, workflow.name, JSON.stringify(workflow.steps),
          JSON.stringify(workflow.trigger_patterns), workflow.frequency, workflow.last_used
        ]}
      );
    }
    console.log(`[SEED] Added ${workflows.length} demo workflows`);

    // Seed Settings
    const settings = {
      learningEnabled: true,
      nightModeEnabled: true,
      nightModeStart: '22:00',
      nightModeEnd: '06:00',
      syncEnabled: true,
      notifications: {
        taskComplete: true,
        learnedPattern: true,
        nightModeReport: true
      },
      privacy: {
        trackBrowsing: true,
        trackEmail: true,
        trackMessages: true,
        trackFiles: true
      }
    };

    await sequelize.query(
      `INSERT INTO cloe_settings (user_id, settings) VALUES (?, ?)
       ON CONFLICT (user_id) DO UPDATE SET settings = ?`,
      { replacements: [userId, JSON.stringify(settings), JSON.stringify(settings)] }
    );
    console.log('[SEED] Added demo settings');

    console.log('\n[SEED] Demo data seeding complete!');
    console.log('\n--- Demo Login Info ---');
    console.log('Since Google OAuth requires setup, use this workaround for testing:');
    console.log('1. Start the backend: npm run dev');
    console.log('2. The demo user email is: demo@cloe.ai');
    console.log('3. You can manually create a session or use the API directly');
    console.log('------------------------\n');

  } catch (error) {
    console.error('[SEED] Error:', error);
  } finally {
    await sequelize.close();
    process.exit(0);
  }
}

function generateDemoActions(userId) {
  const now = new Date();
  const actions = [];

  const templates = [
    { type: 'openApp', app: 'Safari', target: null },
    { type: 'openApp', app: 'VS Code', target: null },
    { type: 'openApp', app: 'Slack', target: null },
    { type: 'openApp', app: 'Mail', target: null },
    { type: 'openApp', app: 'Finder', target: null },
    { type: 'switchApp', app: 'Safari', target: 'GitHub - Pull Request #42' },
    { type: 'switchApp', app: 'VS Code', target: 'index.js - MyProject' },
    { type: 'switchApp', app: 'Slack', target: 'engineering' },
    { type: 'openFile', app: 'VS Code', target: '/Users/demo/Projects/app/src/index.js' },
    { type: 'openFile', app: 'Finder', target: '/Users/demo/Documents/Report.pdf' },
    { type: 'saveFile', app: 'VS Code', target: '/Users/demo/Projects/app/src/api.js' },
    { type: 'sendEmail', app: 'Mail', target: 'john@example.com' },
    { type: 'sendEmail', app: 'Mail', target: 'sarah@company.com' },
    { type: 'openURL', app: 'Safari', target: 'https://github.com/notifications' },
    { type: 'openURL', app: 'Safari', target: 'https://docs.google.com/document/d/abc' },
    { type: 'copyText', app: 'VS Code', target: null, value: 'const api = new API();' },
    { type: 'search', app: 'Safari', target: null, value: 'react useEffect cleanup' },
    { type: 'search', app: 'Spotlight', target: null, value: 'quarterly report' },
  ];

  // Generate 50 actions over the past 3 days
  for (let i = 0; i < 50; i++) {
    const template = templates[Math.floor(Math.random() * templates.length)];
    const hoursAgo = Math.floor(Math.random() * 72); // Random time in last 3 days
    const timestamp = new Date(now.getTime() - hoursAgo * 60 * 60 * 1000);

    actions.push({
      user_id: userId,
      type: template.type,
      app: template.app,
      target: template.target,
      value: template.value || null,
      timestamp: timestamp.toISOString()
    });
  }

  // Sort by timestamp descending
  actions.sort((a, b) => new Date(b.timestamp) - new Date(a.timestamp));

  return actions;
}

function generateDemoContacts(userId) {
  return [
    {
      user_id: userId,
      name: 'John Smith',
      email: 'john.smith@example.com',
      phone: '+1 555-0101',
      relationship: 'colleague',
      aliases: ['John', 'JS'],
      locations: [{ app: 'Mail' }, { app: 'Slack' }],
      last_contact: new Date(Date.now() - 2 * 60 * 60 * 1000).toISOString()
    },
    {
      user_id: userId,
      name: 'Sarah Johnson',
      email: 'sarah.j@company.com',
      phone: '+1 555-0102',
      relationship: 'manager',
      aliases: ['Sarah', 'Boss'],
      locations: [{ app: 'Mail' }, { app: 'Zoom' }],
      last_contact: new Date(Date.now() - 24 * 60 * 60 * 1000).toISOString()
    },
    {
      user_id: userId,
      name: 'Mike Chen',
      email: 'mike.chen@startup.io',
      phone: null,
      relationship: 'client',
      aliases: ['Mike', 'Michael'],
      locations: [{ app: 'Mail' }],
      last_contact: new Date(Date.now() - 48 * 60 * 60 * 1000).toISOString()
    },
    {
      user_id: userId,
      name: 'Emily Davis',
      email: 'emily@design.co',
      phone: '+1 555-0103',
      relationship: 'designer',
      aliases: ['Em', 'Emily D'],
      locations: [{ app: 'Slack' }, { app: 'Figma' }],
      last_contact: new Date(Date.now() - 5 * 60 * 60 * 1000).toISOString()
    },
    {
      user_id: userId,
      name: 'David Wilson',
      email: 'dwilson@legal.com',
      phone: '+1 555-0104',
      relationship: 'lawyer',
      aliases: ['Dave', 'Attorney'],
      locations: [{ app: 'Mail' }],
      last_contact: new Date(Date.now() - 168 * 60 * 60 * 1000).toISOString()
    }
  ];
}

function generateDemoWorkflows(userId) {
  return [
    {
      user_id: userId,
      name: 'Morning Routine',
      steps: [
        { app: 'Mail', action: 'Check inbox', details: 'Review new emails' },
        { app: 'Slack', action: 'Check messages', details: 'Read team updates' },
        { app: 'Calendar', action: 'Review schedule', details: 'Check today\'s meetings' },
        { app: 'Safari', action: 'Open GitHub', details: 'Check notifications' }
      ],
      trigger_patterns: ['start my day', 'morning routine', 'begin work'],
      frequency: 45,
      last_used: new Date(Date.now() - 8 * 60 * 60 * 1000).toISOString()
    },
    {
      user_id: userId,
      name: 'Code Review',
      steps: [
        { app: 'Safari', action: 'Open GitHub PR', details: null },
        { app: 'VS Code', action: 'Open project', details: 'Clone or open local repo' },
        { app: 'Terminal', action: 'Run tests', details: 'npm test' }
      ],
      trigger_patterns: ['review code', 'check PR', 'code review'],
      frequency: 23,
      last_used: new Date(Date.now() - 2 * 60 * 60 * 1000).toISOString()
    },
    {
      user_id: userId,
      name: 'Weekly Report',
      steps: [
        { app: 'Notion', action: 'Open weekly template', details: null },
        { app: 'Calendar', action: 'Review past week', details: 'Check completed meetings' },
        { app: 'Slack', action: 'Gather updates', details: 'Check team channel' },
        { app: 'Mail', action: 'Send report', details: 'To: manager' }
      ],
      trigger_patterns: ['weekly report', 'write report', 'send update'],
      frequency: 12,
      last_used: new Date(Date.now() - 72 * 60 * 60 * 1000).toISOString()
    },
    {
      user_id: userId,
      name: 'Deploy to Production',
      steps: [
        { app: 'VS Code', action: 'Final code check', details: null },
        { app: 'Terminal', action: 'Run tests', details: 'npm test && npm run build' },
        { app: 'Terminal', action: 'Deploy', details: 'npm run deploy' },
        { app: 'Safari', action: 'Verify deployment', details: 'Check production site' }
      ],
      trigger_patterns: ['deploy', 'push to production', 'release'],
      frequency: 8,
      last_used: new Date(Date.now() - 24 * 60 * 60 * 1000).toISOString()
    }
  ];
}

// Run the seeder
seedDemoData();

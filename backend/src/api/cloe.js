/**
 * Cloe API Routes
 * Handles dashboard data for the Cloe AI assistant
 */

import express from 'express';
import { isAuthenticated } from '../middleware/auth.js';
import { getRedis } from '../config/redis.js';
import { query } from '../config/database.js';

const router = express.Router();

// All routes require authentication
router.use(isAuthenticated);

/**
 * GET /api/cloe/stats
 * Get dashboard statistics
 */
router.get('/stats', async (req, res) => {
  try {
    const userId = req.user.id;

    // Get stats from database
    const actionsResult = await query(
      'SELECT COUNT(*) as count FROM cloe_actions WHERE user_id = $1',
      [userId]
    ).catch(() => ({ rows: [{ count: 0 }] }));

    const contactsResult = await query(
      'SELECT COUNT(*) as count FROM cloe_contacts WHERE user_id = $1',
      [userId]
    ).catch(() => ({ rows: [{ count: 0 }] }));

    const workflowsResult = await query(
      'SELECT COUNT(*) as count FROM cloe_workflows WHERE user_id = $1',
      [userId]
    ).catch(() => ({ rows: [{ count: 0 }] }));

    const appsResult = await query(
      'SELECT COUNT(DISTINCT app) as count FROM cloe_actions WHERE user_id = $1',
      [userId]
    ).catch(() => ({ rows: [{ count: 0 }] }));

    // Check if desktop app is connected via Redis
    const redis = getRedis();
    let connected = false;
    if (redis) {
      const lastPing = await redis.get(`cloe:user:${userId}:lastPing`);
      if (lastPing) {
        const pingTime = parseInt(lastPing);
        connected = (Date.now() - pingTime) < 60000; // Connected if ping within 1 minute
      }
    }

    res.json({
      stats: {
        actions: parseInt(actionsResult.rows[0].count),
        contacts: parseInt(contactsResult.rows[0].count),
        workflows: parseInt(workflowsResult.rows[0].count),
        apps: parseInt(appsResult.rows[0].count)
      },
      connected
    });
  } catch (error) {
    console.error('Failed to get stats:', error);
    res.status(500).json({ error: 'Failed to load statistics' });
  }
});

/**
 * GET /api/cloe/activity
 * Get activity log
 */
router.get('/activity', async (req, res) => {
  try {
    const userId = req.user.id;
    const { limit = 50, page = 1, type } = req.query;
    const offset = (page - 1) * limit;

    let queryText = `
      SELECT id, type, app, target, value, timestamp
      FROM cloe_actions
      WHERE user_id = $1
    `;
    const params = [userId];

    if (type) {
      queryText += ' AND type = $2';
      params.push(type);
    }

    queryText += ' ORDER BY timestamp DESC LIMIT $' + (params.length + 1) + ' OFFSET $' + (params.length + 2);
    params.push(parseInt(limit), parseInt(offset));

    const result = await query(queryText, params).catch(() => ({ rows: [] }));

    // Check if there are more results
    const countQuery = type
      ? 'SELECT COUNT(*) as count FROM cloe_actions WHERE user_id = $1 AND type = $2'
      : 'SELECT COUNT(*) as count FROM cloe_actions WHERE user_id = $1';
    const countResult = await query(countQuery, type ? [userId, type] : [userId]).catch(() => ({ rows: [{ count: 0 }] }));
    const total = parseInt(countResult.rows[0].count);

    res.json({
      activity: result.rows,
      hasMore: offset + result.rows.length < total,
      total
    });
  } catch (error) {
    console.error('Failed to get activity:', error);
    res.status(500).json({ error: 'Failed to load activity' });
  }
});

/**
 * POST /api/cloe/activity
 * Record new activity (called from desktop app)
 */
router.post('/activity', async (req, res) => {
  try {
    const userId = req.user.id;
    const { type, app, target, value } = req.body;

    const result = await query(
      `INSERT INTO cloe_actions (user_id, type, app, target, value, timestamp)
       VALUES ($1, $2, $3, $4, $5, NOW())
       RETURNING id`,
      [userId, type, app, target, value]
    );

    res.json({ id: result.rows[0].id });
  } catch (error) {
    console.error('Failed to record activity:', error);
    res.status(500).json({ error: 'Failed to record activity' });
  }
});

/**
 * GET /api/cloe/contacts
 * Get all contacts
 */
router.get('/contacts', async (req, res) => {
  try {
    const userId = req.user.id;

    const result = await query(
      `SELECT id, name, aliases, email, phone, locations, relationship, last_contact as "lastContact"
       FROM cloe_contacts
       WHERE user_id = $1
       ORDER BY last_contact DESC NULLS LAST`,
      [userId]
    ).catch(() => ({ rows: [] }));

    res.json({ contacts: result.rows });
  } catch (error) {
    console.error('Failed to get contacts:', error);
    res.status(500).json({ error: 'Failed to load contacts' });
  }
});

/**
 * POST /api/cloe/contacts
 * Create a new contact
 */
router.post('/contacts', async (req, res) => {
  try {
    const userId = req.user.id;
    const { name, email, phone, relationship, aliases, locations } = req.body;

    const result = await query(
      `INSERT INTO cloe_contacts (user_id, name, email, phone, relationship, aliases, locations, last_contact)
       VALUES ($1, $2, $3, $4, $5, $6, $7, NOW())
       RETURNING *`,
      [userId, name, email, phone, relationship, JSON.stringify(aliases || []), JSON.stringify(locations || [])]
    );

    res.json({ contact: result.rows[0] });
  } catch (error) {
    console.error('Failed to create contact:', error);
    res.status(500).json({ error: 'Failed to create contact' });
  }
});

/**
 * PUT /api/cloe/contacts/:id
 * Update a contact
 */
router.put('/contacts/:id', async (req, res) => {
  try {
    const userId = req.user.id;
    const { id } = req.params;
    const { name, email, phone, relationship, aliases } = req.body;

    const result = await query(
      `UPDATE cloe_contacts
       SET name = COALESCE($3, name),
           email = COALESCE($4, email),
           phone = COALESCE($5, phone),
           relationship = COALESCE($6, relationship),
           aliases = COALESCE($7, aliases)
       WHERE id = $1 AND user_id = $2
       RETURNING *`,
      [id, userId, name, email, phone, relationship, aliases ? JSON.stringify(aliases) : null]
    );

    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Contact not found' });
    }

    res.json({ contact: result.rows[0] });
  } catch (error) {
    console.error('Failed to update contact:', error);
    res.status(500).json({ error: 'Failed to update contact' });
  }
});

/**
 * DELETE /api/cloe/contacts/:id
 * Delete a contact
 */
router.delete('/contacts/:id', async (req, res) => {
  try {
    const userId = req.user.id;
    const { id } = req.params;

    await query(
      'DELETE FROM cloe_contacts WHERE id = $1 AND user_id = $2',
      [id, userId]
    );

    res.json({ success: true });
  } catch (error) {
    console.error('Failed to delete contact:', error);
    res.status(500).json({ error: 'Failed to delete contact' });
  }
});

/**
 * GET /api/cloe/workflows
 * Get all workflows
 */
router.get('/workflows', async (req, res) => {
  try {
    const userId = req.user.id;

    const result = await query(
      `SELECT id, name, steps, trigger_patterns as "triggerPatterns", frequency, last_used as "lastUsed"
       FROM cloe_workflows
       WHERE user_id = $1
       ORDER BY last_used DESC NULLS LAST`,
      [userId]
    ).catch(() => ({ rows: [] }));

    res.json({ workflows: result.rows });
  } catch (error) {
    console.error('Failed to get workflows:', error);
    res.status(500).json({ error: 'Failed to load workflows' });
  }
});

/**
 * POST /api/cloe/workflows
 * Create a new workflow
 */
router.post('/workflows', async (req, res) => {
  try {
    const userId = req.user.id;
    const { name, steps, triggerPatterns } = req.body;

    const result = await query(
      `INSERT INTO cloe_workflows (user_id, name, steps, trigger_patterns, frequency, last_used)
       VALUES ($1, $2, $3, $4, 0, NOW())
       RETURNING id, name, steps, trigger_patterns as "triggerPatterns", frequency, last_used as "lastUsed"`,
      [userId, name, JSON.stringify(steps), JSON.stringify(triggerPatterns || [])]
    );

    res.json({ workflow: result.rows[0] });
  } catch (error) {
    console.error('Failed to create workflow:', error);
    res.status(500).json({ error: 'Failed to create workflow' });
  }
});

/**
 * DELETE /api/cloe/workflows/:id
 * Delete a workflow
 */
router.delete('/workflows/:id', async (req, res) => {
  try {
    const userId = req.user.id;
    const { id } = req.params;

    await query(
      'DELETE FROM cloe_workflows WHERE id = $1 AND user_id = $2',
      [id, userId]
    );

    res.json({ success: true });
  } catch (error) {
    console.error('Failed to delete workflow:', error);
    res.status(500).json({ error: 'Failed to delete workflow' });
  }
});

/**
 * GET /api/cloe/settings
 * Get user settings
 */
router.get('/settings', async (req, res) => {
  try {
    const userId = req.user.id;

    const result = await query(
      'SELECT settings FROM cloe_settings WHERE user_id = $1',
      [userId]
    ).catch(() => ({ rows: [] }));

    // Return default settings if none exist
    const defaultSettings = {
      learningEnabled: true,
      nightModeEnabled: false,
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

    res.json({
      settings: result.rows[0]?.settings || defaultSettings
    });
  } catch (error) {
    console.error('Failed to get settings:', error);
    res.status(500).json({ error: 'Failed to load settings' });
  }
});

/**
 * PUT /api/cloe/settings
 * Update user settings
 */
router.put('/settings', async (req, res) => {
  try {
    const userId = req.user.id;
    const settings = req.body;

    await query(
      `INSERT INTO cloe_settings (user_id, settings)
       VALUES ($1, $2)
       ON CONFLICT (user_id) DO UPDATE SET settings = $2`,
      [userId, JSON.stringify(settings)]
    );

    res.json({ success: true });
  } catch (error) {
    console.error('Failed to save settings:', error);
    res.status(500).json({ error: 'Failed to save settings' });
  }
});

/**
 * POST /api/cloe/ping
 * Desktop app ping to indicate it's connected
 */
router.post('/ping', async (req, res) => {
  try {
    const userId = req.user.id;
    const redis = getRedis();

    if (redis) {
      await redis.set(`cloe:user:${userId}:lastPing`, Date.now().toString(), 'EX', 120);
    }

    res.json({ success: true });
  } catch (error) {
    console.error('Ping failed:', error);
    res.status(500).json({ error: 'Ping failed' });
  }
});

/**
 * POST /api/cloe/sync
 * Sync data from desktop app
 */
router.post('/sync', async (req, res) => {
  try {
    const userId = req.user.id;
    const { actions, contacts, workflows } = req.body;

    // Sync actions
    if (actions?.length > 0) {
      for (const action of actions) {
        await query(
          `INSERT INTO cloe_actions (user_id, type, app, target, value, timestamp)
           VALUES ($1, $2, $3, $4, $5, $6)
           ON CONFLICT DO NOTHING`,
          [userId, action.type, action.app, action.target, action.value, action.timestamp]
        ).catch(() => {});
      }
    }

    // Sync contacts
    if (contacts?.length > 0) {
      for (const contact of contacts) {
        await query(
          `INSERT INTO cloe_contacts (user_id, name, email, phone, relationship, aliases, locations, last_contact)
           VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
           ON CONFLICT (user_id, name) DO UPDATE SET
             email = COALESCE(EXCLUDED.email, cloe_contacts.email),
             phone = COALESCE(EXCLUDED.phone, cloe_contacts.phone),
             last_contact = EXCLUDED.last_contact`,
          [userId, contact.name, contact.email, contact.phone, contact.relationship,
           JSON.stringify(contact.aliases || []), JSON.stringify(contact.locations || []), contact.lastContact]
        ).catch(() => {});
      }
    }

    // Sync workflows
    if (workflows?.length > 0) {
      for (const workflow of workflows) {
        await query(
          `INSERT INTO cloe_workflows (user_id, name, steps, trigger_patterns, frequency, last_used)
           VALUES ($1, $2, $3, $4, $5, $6)
           ON CONFLICT (user_id, name) DO UPDATE SET
             steps = EXCLUDED.steps,
             trigger_patterns = EXCLUDED.trigger_patterns,
             frequency = EXCLUDED.frequency,
             last_used = EXCLUDED.last_used`,
          [userId, workflow.name, JSON.stringify(workflow.steps),
           JSON.stringify(workflow.triggerPatterns || []), workflow.frequency, workflow.lastUsed]
        ).catch(() => {});
      }
    }

    res.json({ success: true });
  } catch (error) {
    console.error('Sync failed:', error);
    res.status(500).json({ error: 'Sync failed' });
  }
});

export default router;

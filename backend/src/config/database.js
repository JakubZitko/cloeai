/**
 * Database Configuration
 * PostgreSQL + Sequelize
 */

import { Sequelize } from 'sequelize';
import dotenv from 'dotenv';

dotenv.config();

export const sequelize = new Sequelize(
  process.env.DATABASE_URL || {
    database: process.env.DB_NAME || 'cloe_video',
    username: process.env.DB_USER || 'postgres',
    password: process.env.DB_PASSWORD || 'postgres',
    host: process.env.DB_HOST || 'localhost',
    port: process.env.DB_PORT || 5432,
    dialect: 'postgres',
    logging: process.env.NODE_ENV === 'development' ? console.log : false,
    pool: {
      max: 10,
      min: 0,
      acquire: 30000,
      idle: 10000
    }
  }
);

export async function connectDatabase() {
  try {
    await sequelize.authenticate();
    console.log('[OK] Database connection established');

    // Sync models in development
    if (process.env.NODE_ENV === 'development') {
      await sequelize.sync({ alter: true });
      console.log('[OK] Database models synchronized');
    }

    // Run Cloe migrations
    await runCloeMigrations();

    return sequelize;
  } catch (error) {
    console.error('[ERROR] Unable to connect to database:', error);
    throw error;
  }
}

// Run raw SQL migrations for Cloe tables
async function runCloeMigrations() {
  try {
    // Create cloe_actions table
    await sequelize.query(`
      CREATE TABLE IF NOT EXISTS cloe_actions (
        id SERIAL PRIMARY KEY,
        user_id INTEGER NOT NULL,
        type VARCHAR(50) NOT NULL,
        app VARCHAR(255) NOT NULL,
        target TEXT,
        value TEXT,
        timestamp TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
        created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
      )
    `);

    // Create cloe_contacts table
    await sequelize.query(`
      CREATE TABLE IF NOT EXISTS cloe_contacts (
        id SERIAL PRIMARY KEY,
        user_id INTEGER NOT NULL,
        name VARCHAR(255) NOT NULL,
        email VARCHAR(255),
        phone VARCHAR(50),
        relationship VARCHAR(100),
        aliases JSONB DEFAULT '[]',
        locations JSONB DEFAULT '[]',
        last_contact TIMESTAMP WITH TIME ZONE,
        created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
        UNIQUE(user_id, name)
      )
    `);

    // Create cloe_workflows table
    await sequelize.query(`
      CREATE TABLE IF NOT EXISTS cloe_workflows (
        id SERIAL PRIMARY KEY,
        user_id INTEGER NOT NULL,
        name VARCHAR(255) NOT NULL,
        steps JSONB NOT NULL DEFAULT '[]',
        trigger_patterns JSONB DEFAULT '[]',
        frequency INTEGER DEFAULT 0,
        last_used TIMESTAMP WITH TIME ZONE,
        created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
        UNIQUE(user_id, name)
      )
    `);

    // Create cloe_settings table
    await sequelize.query(`
      CREATE TABLE IF NOT EXISTS cloe_settings (
        id SERIAL PRIMARY KEY,
        user_id INTEGER NOT NULL UNIQUE,
        settings JSONB NOT NULL DEFAULT '{}',
        updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
      )
    `);

    console.log('[OK] Cloe tables created/verified');
  } catch (error) {
    console.error('[WARN] Cloe migration error (may be expected):', error.message);
  }
}

// Raw query helper function
export async function query(text, params) {
  // Convert $1, $2 placeholders to ? for Sequelize
  let convertedText = text;
  let paramIndex = 1;
  while (convertedText.includes('$' + paramIndex)) {
    convertedText = convertedText.replace('$' + paramIndex, '?');
    paramIndex++;
  }

  // Determine query type
  const trimmed = convertedText.trim().toUpperCase();
  let queryType;
  if (trimmed.startsWith('SELECT') || trimmed.startsWith('WITH')) {
    queryType = sequelize.QueryTypes.SELECT;
  } else if (trimmed.startsWith('INSERT')) {
    queryType = sequelize.QueryTypes.INSERT;
  } else if (trimmed.startsWith('UPDATE')) {
    queryType = sequelize.QueryTypes.UPDATE;
  } else if (trimmed.startsWith('DELETE')) {
    queryType = sequelize.QueryTypes.DELETE;
  } else {
    queryType = sequelize.QueryTypes.RAW;
  }

  try {
    const [results, metadata] = await sequelize.query(convertedText, {
      replacements: params,
      type: queryType
    });

    // Handle different result formats
    if (queryType === sequelize.QueryTypes.SELECT) {
      return { rows: Array.isArray(results) ? results : [] };
    } else if (queryType === sequelize.QueryTypes.INSERT) {
      // For INSERT RETURNING, results contains the returned rows
      return { rows: Array.isArray(results) ? results : [results].filter(Boolean) };
    } else {
      return { rows: [], rowCount: metadata };
    }
  } catch (error) {
    console.error('[DB] Query error:', error.message);
    throw error;
  }
}

export default sequelize;

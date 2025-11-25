-- Cloe AI Dashboard Tables
-- Migration 002

-- Actions table - stores user activity log
CREATE TABLE IF NOT EXISTS cloe_actions (
    id SERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    type VARCHAR(50) NOT NULL,
    app VARCHAR(255) NOT NULL,
    target TEXT,
    value TEXT,
    timestamp TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_cloe_actions_user_id ON cloe_actions(user_id);
CREATE INDEX IF NOT EXISTS idx_cloe_actions_timestamp ON cloe_actions(timestamp);
CREATE INDEX IF NOT EXISTS idx_cloe_actions_type ON cloe_actions(type);

-- Contacts table - stores learned contacts
CREATE TABLE IF NOT EXISTS cloe_contacts (
    id SERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    name VARCHAR(255) NOT NULL,
    email VARCHAR(255),
    phone VARCHAR(50),
    relationship VARCHAR(100),
    aliases JSONB DEFAULT '[]',
    locations JSONB DEFAULT '[]',
    last_contact TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(user_id, name)
);

CREATE INDEX IF NOT EXISTS idx_cloe_contacts_user_id ON cloe_contacts(user_id);

-- Workflows table - stores learned and created workflows
CREATE TABLE IF NOT EXISTS cloe_workflows (
    id SERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    name VARCHAR(255) NOT NULL,
    steps JSONB NOT NULL DEFAULT '[]',
    trigger_patterns JSONB DEFAULT '[]',
    frequency INTEGER DEFAULT 0,
    last_used TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(user_id, name)
);

CREATE INDEX IF NOT EXISTS idx_cloe_workflows_user_id ON cloe_workflows(user_id);

-- Settings table - stores user preferences
CREATE TABLE IF NOT EXISTS cloe_settings (
    id SERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE UNIQUE,
    settings JSONB NOT NULL DEFAULT '{}',
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_cloe_settings_user_id ON cloe_settings(user_id);

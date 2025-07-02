-- Migration Script for Existing Database
-- This script adds the new a1zap tables to the existing database
-- Run this in a transaction to ensure atomicity

BEGIN;

-- ============================================
-- 1. Create new tables
-- ============================================

-- Create enum for app permissions
CREATE TYPE app_user_permission AS ENUM ('read', 'write', 'admin');

-- Create subscription plans table
CREATE TABLE subscription_plans (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  description TEXT,
  price_monthly DECIMAL(10, 2),
  price_yearly DECIMAL(10, 2),
  currency TEXT DEFAULT 'USD',
  max_personal_agents INTEGER NOT NULL,
  max_work_agents INTEGER NOT NULL,
  max_messages_per_month INTEGER,
  max_storage_gb INTEGER,
  features JSONB DEFAULT '[]',
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMP NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMP NOT NULL DEFAULT NOW()
);

-- Insert default subscription plans
INSERT INTO subscription_plans (id, name, max_personal_agents, max_work_agents, price_monthly, max_messages_per_month) VALUES
('free', 'Free', 1, 1, 0, 1000),
('pro', 'Pro', 5, 5, 29.99, 10000),
('enterprise', 'Enterprise', -1, -1, 99.99, -1); -- -1 means unlimited

-- Create user subscriptions table
CREATE TABLE user_subscriptions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id TEXT UNIQUE NOT NULL,
  plan_id TEXT NOT NULL DEFAULT 'free' REFERENCES subscription_plans(id),
  status TEXT NOT NULL DEFAULT 'active',
  max_personal_agents INTEGER DEFAULT 1,
  max_work_agents INTEGER DEFAULT 1,
  max_total_agents INTEGER DEFAULT 2,
  stripe_customer_id TEXT,
  stripe_subscription_id TEXT,
  current_period_start TIMESTAMP,
  current_period_end TIMESTAMP,
  created_at TIMESTAMP NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMP NOT NULL DEFAULT NOW(),
  cancelled_at TIMESTAMP,
  CONSTRAINT valid_plan CHECK (plan_id IN ('free', 'pro', 'enterprise')),
  CONSTRAINT valid_status CHECK (status IN ('active', 'cancelled', 'past_due', 'trialing'))
);

-- Create a1_agents table
CREATE TABLE a1_agents (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  owner_id TEXT NOT NULL,
  app_id TEXT UNIQUE, -- Will be updated to UUID after apps table migration
  name TEXT NOT NULL,
  handle TEXT UNIQUE NOT NULL,
  description TEXT,
  avatar_url TEXT,
  email TEXT,
  phone_number TEXT,
  whatsapp_number TEXT,
  base_website TEXT,
  custom_website TEXT,
  onboarding_data JSONB,
  settings JSONB DEFAULT '{}',
  status TEXT DEFAULT 'active',
  agent_type TEXT NOT NULL,
  created_at TIMESTAMP NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMP NOT NULL DEFAULT NOW(),
  CONSTRAINT valid_agent_type CHECK (agent_type IN ('personal', 'work')),
  CONSTRAINT valid_status CHECK (status IN ('active', 'paused', 'archived')),
  CONSTRAINT valid_handle CHECK (handle ~ '^[a-zA-Z0-9_]+$')
);

-- Create indexes for a1_agents
CREATE INDEX idx_a1_agents_owner_id ON a1_agents(owner_id);
CREATE INDEX idx_a1_agents_handle ON a1_agents(handle);
CREATE INDEX idx_a1_agents_status ON a1_agents(status);

-- Create agent usage table
CREATE TABLE agent_usage (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  agent_id UUID NOT NULL REFERENCES a1_agents(id) ON DELETE CASCADE,
  date DATE NOT NULL,
  message_count INTEGER DEFAULT 0,
  api_calls INTEGER DEFAULT 0,
  storage_bytes BIGINT DEFAULT 0,
  compute_seconds INTEGER DEFAULT 0,
  estimated_cost DECIMAL(10, 4) DEFAULT 0,
  created_at TIMESTAMP NOT NULL DEFAULT NOW(),
  CONSTRAINT unique_agent_date UNIQUE (agent_id, date)
);

-- Create index for agent usage
CREATE INDEX idx_agent_usage_agent_id_date ON agent_usage(agent_id, date);

-- Create billing events table
CREATE TABLE billing_events (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id TEXT NOT NULL,
  event_type TEXT NOT NULL,
  amount DECIMAL(10, 2),
  currency TEXT DEFAULT 'USD',
  description TEXT,
  subscription_id UUID REFERENCES user_subscriptions(id),
  invoice_id TEXT,
  metadata JSONB DEFAULT '{}',
  created_at TIMESTAMP NOT NULL DEFAULT NOW()
);

-- Create indexes for billing events
CREATE INDEX idx_billing_events_user_id ON billing_events(user_id);
CREATE INDEX idx_billing_events_type ON billing_events(event_type);

-- Create agent conversations table
CREATE TABLE agent_conversations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  agent_id UUID NOT NULL REFERENCES a1_agents(id) ON DELETE CASCADE,
  external_user_id TEXT,
  channel TEXT NOT NULL,
  thread_id TEXT,
  status TEXT DEFAULT 'active',
  started_at TIMESTAMP NOT NULL DEFAULT NOW(),
  last_message_at TIMESTAMP NOT NULL DEFAULT NOW(),
  ended_at TIMESTAMP,
  metadata JSONB DEFAULT '{}',
  CONSTRAINT valid_status CHECK (status IN ('active', 'archived'))
);

-- Create indexes for agent conversations
CREATE INDEX idx_agent_conversations_agent_id ON agent_conversations(agent_id);
CREATE INDEX idx_agent_conversations_external_user ON agent_conversations(external_user_id);

-- Create agent integrations table
CREATE TABLE agent_integrations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  agent_id UUID NOT NULL REFERENCES a1_agents(id) ON DELETE CASCADE,
  provider TEXT NOT NULL,
  status TEXT DEFAULT 'active',
  config JSONB NOT NULL DEFAULT '{}',
  created_at TIMESTAMP NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMP NOT NULL DEFAULT NOW(),
  last_sync_at TIMESTAMP,
  CONSTRAINT unique_agent_provider UNIQUE (agent_id, provider)
);

-- ============================================
-- 2. Migrate existing tables
-- ============================================

-- First, we need to check if the newer schema tables exist
-- If they do, we'll migrate them. If not, we'll work with the legacy tables.

DO $$
BEGIN
    -- Check if the newer schema exists (with UUID ids)
    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'apps' 
        AND column_name = 'id' 
        AND data_type = 'uuid'
    ) THEN
        -- Newer schema exists, add agent_id column
        ALTER TABLE apps ADD COLUMN IF NOT EXISTS agent_id UUID UNIQUE REFERENCES a1_agents(id);
        
        -- Add columns to messages table if it exists
        IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'messages') THEN
            ALTER TABLE messages 
                ADD COLUMN IF NOT EXISTS agent_id UUID REFERENCES a1_agents(id),
                ADD COLUMN IF NOT EXISTS conversation_id UUID REFERENCES agent_conversations(id);
        END IF;
    ELSE
        -- Legacy schema with text IDs exists
        -- Create a temporary mapping table for migration
        CREATE TEMP TABLE app_id_mapping (
            old_id TEXT PRIMARY KEY,
            new_id UUID DEFAULT gen_random_uuid()
        );
        
        -- Insert mappings for all existing apps
        INSERT INTO app_id_mapping (old_id)
        SELECT id FROM apps;
        
        -- Create new apps table with proper schema
        CREATE TABLE apps_new (
            id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
            name TEXT NOT NULL DEFAULT 'Unnamed App',
            description TEXT NOT NULL DEFAULT 'No description',
            git_repo TEXT NOT NULL,
            created_at TIMESTAMP NOT NULL DEFAULT NOW(),
            base_id TEXT NOT NULL DEFAULT 'nextjs-dkjfgdf',
            preview_domain TEXT UNIQUE,
            agent_id UUID UNIQUE
        );
        
        -- Migrate data from old apps table
        INSERT INTO apps_new (id, name, description, git_repo, created_at, preview_domain)
        SELECT 
            m.new_id,
            COALESCE(a.name, 'Unnamed App'),
            COALESCE(a.description, 'No description'),
            COALESCE(a.github_url, ''),
            COALESCE(a.created_at, NOW()),
            a.preview_url
        FROM apps a
        JOIN app_id_mapping m ON a.id = m.old_id;
        
        -- Create app_users table
        CREATE TABLE app_users (
            user_id TEXT NOT NULL,
            app_id UUID NOT NULL REFERENCES apps_new(id) ON DELETE CASCADE,
            created_at TIMESTAMP NOT NULL DEFAULT NOW(),
            permissions app_user_permission,
            freestyle_identity TEXT NOT NULL DEFAULT '',
            freestyle_access_token TEXT NOT NULL DEFAULT '',
            freestyle_access_token_id TEXT NOT NULL DEFAULT ''
        );
        
        -- Create messages table if using chat_messages
        IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'chat_messages') THEN
            CREATE TABLE messages (
                id TEXT PRIMARY KEY,
                created_at TIMESTAMP NOT NULL DEFAULT NOW(),
                app_id UUID NOT NULL REFERENCES apps_new(id),
                message JSONB NOT NULL,
                agent_id UUID REFERENCES a1_agents(id),
                conversation_id UUID REFERENCES agent_conversations(id)
            );
            
            -- Migrate chat messages
            INSERT INTO messages (id, created_at, app_id, message)
            SELECT 
                cm.id,
                cm.created_at,
                m.new_id,
                jsonb_build_object(
                    'role', cm.role,
                    'content', cm.content
                )
            FROM chat_messages cm
            JOIN app_id_mapping m ON cm.app_id = m.old_id;
        END IF;
        
        -- Create app_deployments table
        CREATE TABLE app_deployments (
            app_id UUID NOT NULL REFERENCES apps_new(id) ON DELETE CASCADE,
            created_at TIMESTAMP NOT NULL DEFAULT NOW(),
            deployment_id TEXT NOT NULL,
            commit TEXT NOT NULL
        );
        
        -- Drop old tables and rename new ones
        DROP TABLE IF EXISTS files CASCADE;
        DROP TABLE IF EXISTS chat_messages CASCADE;
        DROP TABLE apps CASCADE;
        ALTER TABLE apps_new RENAME TO apps;
        
        -- Update a1_agents app_id to UUID
        ALTER TABLE a1_agents DROP COLUMN app_id;
        ALTER TABLE a1_agents ADD COLUMN app_id UUID UNIQUE REFERENCES apps(id) ON DELETE CASCADE;
    END IF;
END $$;

-- ============================================
-- 3. Create triggers for updated_at
-- ============================================

CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

CREATE TRIGGER update_a1_agents_updated_at BEFORE UPDATE ON a1_agents
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_subscription_plans_updated_at BEFORE UPDATE ON subscription_plans
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_user_subscriptions_updated_at BEFORE UPDATE ON user_subscriptions
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_agent_integrations_updated_at BEFORE UPDATE ON agent_integrations
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- ============================================
-- 4. Create initial subscriptions for existing users
-- ============================================

-- If app_users table exists, create free subscriptions for all existing users
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'app_users') THEN
        INSERT INTO user_subscriptions (user_id, plan_id)
        SELECT DISTINCT user_id, 'free'
        FROM app_users
        ON CONFLICT (user_id) DO NOTHING;
    END IF;
END $$;

COMMIT;

-- ============================================
-- Post-migration notes:
-- ============================================
-- 1. Update your application code to use the new schema
-- 2. Test all functionality thoroughly
-- 3. Consider adding data encryption for sensitive fields
-- 4. Set up regular backups before running in production 
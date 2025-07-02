-- Fresh Database Creation Script for A1Zap
-- This script creates the complete database schema from scratch
-- Run this on a new PostgreSQL database

-- ============================================
-- 1. Create extensions
-- ============================================

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ============================================
-- 2. Create enums
-- ============================================

CREATE TYPE app_user_permission AS ENUM ('read', 'write', 'admin');

-- ============================================
-- 3. Create core tables
-- ============================================

-- Subscription plans table (no dependencies)
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

-- User subscriptions table
CREATE TABLE user_subscriptions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id TEXT UNIQUE NOT NULL, -- Stack Auth user ID
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

-- Apps table (server instances)
CREATE TABLE apps (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL DEFAULT 'Unnamed App',
  description TEXT NOT NULL DEFAULT 'No description',
  git_repo TEXT NOT NULL,
  created_at TIMESTAMP NOT NULL DEFAULT NOW(),
  base_id TEXT NOT NULL DEFAULT 'nextjs-dkjfgdf',
  preview_domain TEXT UNIQUE,
  agent_id UUID UNIQUE -- Will be set after a1_agents is created
);

-- A1 Agents table
CREATE TABLE a1_agents (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  owner_id TEXT NOT NULL, -- Stack Auth user ID
  app_id UUID UNIQUE NOT NULL REFERENCES apps(id) ON DELETE CASCADE,
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

-- Add foreign key constraint back to apps
ALTER TABLE apps ADD CONSTRAINT apps_agent_id_fkey 
  FOREIGN KEY (agent_id) REFERENCES a1_agents(id) ON DELETE SET NULL;

-- App users table (for sharing apps)
CREATE TABLE app_users (
  user_id TEXT NOT NULL, -- Stack Auth user ID
  app_id UUID NOT NULL REFERENCES apps(id) ON DELETE CASCADE,
  created_at TIMESTAMP NOT NULL DEFAULT NOW(),
  permissions app_user_permission,
  freestyle_identity TEXT NOT NULL,
  freestyle_access_token TEXT NOT NULL,
  freestyle_access_token_id TEXT NOT NULL,
  PRIMARY KEY (user_id, app_id)
);

-- Agent conversations table
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

-- Messages table
CREATE TABLE messages (
  id TEXT PRIMARY KEY,
  created_at TIMESTAMP NOT NULL DEFAULT NOW(),
  app_id UUID NOT NULL REFERENCES apps(id) ON DELETE CASCADE,
  message JSONB NOT NULL,
  agent_id UUID REFERENCES a1_agents(id),
  conversation_id UUID REFERENCES agent_conversations(id)
);

-- App deployments table
CREATE TABLE app_deployments (
  app_id UUID NOT NULL REFERENCES apps(id) ON DELETE CASCADE,
  created_at TIMESTAMP NOT NULL DEFAULT NOW(),
  deployment_id TEXT NOT NULL,
  commit TEXT NOT NULL,
  PRIMARY KEY (app_id, deployment_id)
);

-- Agent usage table
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

-- Billing events table
CREATE TABLE billing_events (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id TEXT NOT NULL, -- Stack Auth user ID
  event_type TEXT NOT NULL,
  amount DECIMAL(10, 2),
  currency TEXT DEFAULT 'USD',
  description TEXT,
  subscription_id UUID REFERENCES user_subscriptions(id),
  invoice_id TEXT,
  metadata JSONB DEFAULT '{}',
  created_at TIMESTAMP NOT NULL DEFAULT NOW()
);

-- Agent integrations table
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
-- 4. Create indexes
-- ============================================

-- A1 Agents indexes
CREATE INDEX idx_a1_agents_owner_id ON a1_agents(owner_id);
CREATE INDEX idx_a1_agents_handle ON a1_agents(handle);
CREATE INDEX idx_a1_agents_status ON a1_agents(status);

-- App users indexes
CREATE INDEX idx_app_users_user_id ON app_users(user_id);
CREATE INDEX idx_app_users_app_id ON app_users(app_id);

-- Agent conversations indexes
CREATE INDEX idx_agent_conversations_agent_id ON agent_conversations(agent_id);
CREATE INDEX idx_agent_conversations_external_user ON agent_conversations(external_user_id);

-- Messages indexes
CREATE INDEX idx_messages_app_id ON messages(app_id);
CREATE INDEX idx_messages_agent_id ON messages(agent_id);
CREATE INDEX idx_messages_conversation_id ON messages(conversation_id);
CREATE INDEX idx_messages_created_at ON messages(created_at DESC);

-- Agent usage indexes
CREATE INDEX idx_agent_usage_agent_id_date ON agent_usage(agent_id, date);

-- Billing events indexes
CREATE INDEX idx_billing_events_user_id ON billing_events(user_id);
CREATE INDEX idx_billing_events_type ON billing_events(event_type);
CREATE INDEX idx_billing_events_created_at ON billing_events(created_at DESC);

-- User subscriptions indexes
CREATE INDEX idx_user_subscriptions_user_id ON user_subscriptions(user_id);
CREATE INDEX idx_user_subscriptions_status ON user_subscriptions(status);

-- ============================================
-- 5. Create triggers
-- ============================================

-- Function to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Apply updated_at triggers
CREATE TRIGGER update_a1_agents_updated_at 
  BEFORE UPDATE ON a1_agents
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_subscription_plans_updated_at 
  BEFORE UPDATE ON subscription_plans
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_user_subscriptions_updated_at 
  BEFORE UPDATE ON user_subscriptions
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_agent_integrations_updated_at 
  BEFORE UPDATE ON agent_integrations
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- ============================================
-- 6. Insert default data
-- ============================================

-- Insert default subscription plans
INSERT INTO subscription_plans (id, name, description, max_personal_agents, max_work_agents, price_monthly, price_yearly, max_messages_per_month, max_storage_gb) VALUES
('free', 'Free', 'Perfect for trying out A1Zap', 1, 1, 0, 0, 1000, 1),
('pro', 'Pro', 'For professionals and small teams', 5, 5, 29.99, 299.99, 10000, 10),
('enterprise', 'Enterprise', 'Unlimited agents and custom limits', -1, -1, 99.99, 999.99, -1, -1);

-- ============================================
-- 7. Create views for common queries
-- ============================================

-- View for user's agents with app info
CREATE VIEW user_agents_view AS
SELECT 
  a.id,
  a.owner_id,
  a.name,
  a.handle,
  a.description,
  a.status,
  a.agent_type,
  a.created_at,
  app.id as app_id,
  app.git_repo,
  app.preview_domain,
  COALESCE(
    (SELECT SUM(message_count) 
     FROM agent_usage 
     WHERE agent_id = a.id 
     AND date >= date_trunc('month', CURRENT_DATE)
    ), 0
  ) as monthly_message_count
FROM a1_agents a
JOIN apps app ON a.app_id = app.id;

-- View for billing summary
CREATE VIEW user_billing_summary AS
SELECT 
  us.user_id,
  us.plan_id,
  sp.name as plan_name,
  us.status as subscription_status,
  us.current_period_end,
  sp.price_monthly,
  sp.max_personal_agents,
  sp.max_work_agents,
  (SELECT COUNT(*) FROM a1_agents WHERE owner_id = us.user_id AND agent_type = 'personal') as current_personal_agents,
  (SELECT COUNT(*) FROM a1_agents WHERE owner_id = us.user_id AND agent_type = 'work') as current_work_agents
FROM user_subscriptions us
JOIN subscription_plans sp ON us.plan_id = sp.id;

-- ============================================
-- 8. Row Level Security (Optional but recommended)
-- ============================================

-- Enable RLS on sensitive tables
ALTER TABLE a1_agents ENABLE ROW LEVEL SECURITY;
ALTER TABLE agent_usage ENABLE ROW LEVEL SECURITY;
ALTER TABLE agent_conversations ENABLE ROW LEVEL SECURITY;
ALTER TABLE agent_integrations ENABLE ROW LEVEL SECURITY;

-- Create policies (example for a1_agents)
-- Note: These would need to be adjusted based on your auth implementation
CREATE POLICY "Users can view their own agents" ON a1_agents
  FOR SELECT USING (owner_id = current_setting('app.current_user_id', true));

CREATE POLICY "Users can insert their own agents" ON a1_agents
  FOR INSERT WITH CHECK (owner_id = current_setting('app.current_user_id', true));

CREATE POLICY "Users can update their own agents" ON a1_agents
  FOR UPDATE USING (owner_id = current_setting('app.current_user_id', true));

CREATE POLICY "Users can delete their own agents" ON a1_agents
  FOR DELETE USING (owner_id = current_setting('app.current_user_id', true));

-- ============================================
-- 9. Performance optimizations
-- ============================================

-- Partial index for active agents
CREATE INDEX idx_a1_agents_active ON a1_agents(owner_id) WHERE status = 'active';

-- Partial index for active conversations
CREATE INDEX idx_agent_conversations_active ON agent_conversations(agent_id) WHERE status = 'active';

-- BRIN index for time-series data
CREATE INDEX idx_agent_usage_created_at_brin ON agent_usage USING brin(created_at);
CREATE INDEX idx_messages_created_at_brin ON messages USING brin(created_at);

-- ============================================
-- Database setup complete!
-- ============================================ 
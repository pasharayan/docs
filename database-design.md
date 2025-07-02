# A1Zap Database Design

## Overview
This document outlines the complete database schema for A1Zap, an AI agent platform where users can create and manage AI agents (a1agents) built on the a1framework pattern.

## Core Entities

### 1. Users (via Stack Auth)
- Managed by Stack Auth
- Connected to our database via `userId` references
- Each user can have multiple a1agents (limited by subscription)

### 2. A1Agents
The core entity representing an AI agent instance.

### 3. Apps
Server instances that run the a1agents (1:1 relationship with a1agents).

### 4. Billing & Subscriptions
Manages user subscriptions and billing information.

### 5. Usage Tracking
Tracks usage metrics for billing and analytics.

## Database Schema

### `a1_agents` Table
Stores the core configuration and settings for each AI agent.

```sql
CREATE TABLE a1_agents (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  owner_id TEXT NOT NULL, -- Stack Auth user ID
  app_id UUID UNIQUE NOT NULL REFERENCES apps(id) ON DELETE CASCADE,
  
  -- Basic Information
  name TEXT NOT NULL,
  handle TEXT UNIQUE NOT NULL, -- @handle for the agent
  description TEXT,
  avatar_url TEXT,
  
  -- Contact Information
  email TEXT,
  phone_number TEXT,
  whatsapp_number TEXT,
  
  -- Websites
  base_website TEXT, -- Primary website
  custom_website TEXT, -- Custom domain
  
  -- Configuration
  onboarding_data JSONB, -- Stores initial onboarding questions/answers
  settings JSONB DEFAULT '{}', -- Additional agent settings
  
  -- Status
  status TEXT DEFAULT 'active', -- active, paused, archived
  agent_type TEXT NOT NULL, -- personal, work
  
  -- Timestamps
  created_at TIMESTAMP NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMP NOT NULL DEFAULT NOW(),
  
  -- Constraints
  CONSTRAINT valid_agent_type CHECK (agent_type IN ('personal', 'work')),
  CONSTRAINT valid_status CHECK (status IN ('active', 'paused', 'archived')),
  CONSTRAINT valid_handle CHECK (handle ~ '^[a-zA-Z0-9_]+$')
);

-- Indexes
CREATE INDEX idx_a1_agents_owner_id ON a1_agents(owner_id);
CREATE INDEX idx_a1_agents_handle ON a1_agents(handle);
CREATE INDEX idx_a1_agents_status ON a1_agents(status);
```

### `user_subscriptions` Table
Manages user subscription tiers and limits.

```sql
CREATE TABLE user_subscriptions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id TEXT UNIQUE NOT NULL, -- Stack Auth user ID
  
  -- Subscription Details
  plan_id TEXT NOT NULL DEFAULT 'free', -- free, pro, enterprise
  status TEXT NOT NULL DEFAULT 'active', -- active, cancelled, past_due
  
  -- Limits
  max_personal_agents INTEGER DEFAULT 1,
  max_work_agents INTEGER DEFAULT 1,
  max_total_agents INTEGER DEFAULT 2,
  
  -- Billing
  stripe_customer_id TEXT,
  stripe_subscription_id TEXT,
  current_period_start TIMESTAMP,
  current_period_end TIMESTAMP,
  
  -- Timestamps
  created_at TIMESTAMP NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMP NOT NULL DEFAULT NOW(),
  cancelled_at TIMESTAMP,
  
  -- Constraints
  CONSTRAINT valid_plan CHECK (plan_id IN ('free', 'pro', 'enterprise')),
  CONSTRAINT valid_status CHECK (status IN ('active', 'cancelled', 'past_due', 'trialing'))
);
```

### `subscription_plans` Table
Defines available subscription tiers.

```sql
CREATE TABLE subscription_plans (
  id TEXT PRIMARY KEY, -- free, pro, enterprise
  name TEXT NOT NULL,
  description TEXT,
  
  -- Pricing
  price_monthly DECIMAL(10, 2),
  price_yearly DECIMAL(10, 2),
  currency TEXT DEFAULT 'USD',
  
  -- Limits
  max_personal_agents INTEGER NOT NULL,
  max_work_agents INTEGER NOT NULL,
  max_messages_per_month INTEGER,
  max_storage_gb INTEGER,
  
  -- Features
  features JSONB DEFAULT '[]',
  
  -- Status
  is_active BOOLEAN DEFAULT true,
  
  created_at TIMESTAMP NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMP NOT NULL DEFAULT NOW()
);

-- Insert default plans
INSERT INTO subscription_plans (id, name, max_personal_agents, max_work_agents, price_monthly) VALUES
('free', 'Free', 1, 1, 0),
('pro', 'Pro', 5, 5, 29.99),
('enterprise', 'Enterprise', -1, -1, 99.99); -- -1 means unlimited
```

### `agent_usage` Table
Tracks usage metrics for each agent.

```sql
CREATE TABLE agent_usage (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  agent_id UUID NOT NULL REFERENCES a1_agents(id) ON DELETE CASCADE,
  
  -- Usage Metrics
  date DATE NOT NULL,
  message_count INTEGER DEFAULT 0,
  api_calls INTEGER DEFAULT 0,
  storage_bytes BIGINT DEFAULT 0,
  compute_seconds INTEGER DEFAULT 0,
  
  -- Cost Tracking
  estimated_cost DECIMAL(10, 4) DEFAULT 0,
  
  -- Timestamps
  created_at TIMESTAMP NOT NULL DEFAULT NOW(),
  
  -- Constraints
  CONSTRAINT unique_agent_date UNIQUE (agent_id, date)
);

-- Indexes
CREATE INDEX idx_agent_usage_agent_id_date ON agent_usage(agent_id, date);
```

### `billing_events` Table
Tracks all billing-related events.

```sql
CREATE TABLE billing_events (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id TEXT NOT NULL,
  
  -- Event Details
  event_type TEXT NOT NULL, -- subscription_created, payment_succeeded, payment_failed, etc.
  amount DECIMAL(10, 2),
  currency TEXT DEFAULT 'USD',
  description TEXT,
  
  -- References
  subscription_id UUID REFERENCES user_subscriptions(id),
  invoice_id TEXT, -- Stripe invoice ID
  
  -- Metadata
  metadata JSONB DEFAULT '{}',
  
  -- Timestamps
  created_at TIMESTAMP NOT NULL DEFAULT NOW()
);

-- Indexes
CREATE INDEX idx_billing_events_user_id ON billing_events(user_id);
CREATE INDEX idx_billing_events_type ON billing_events(event_type);
```

### `agent_conversations` Table
Stores conversation history for each agent.

```sql
CREATE TABLE agent_conversations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  agent_id UUID NOT NULL REFERENCES a1_agents(id) ON DELETE CASCADE,
  
  -- Conversation Details
  external_user_id TEXT, -- ID of the person talking to the agent
  channel TEXT NOT NULL, -- web, whatsapp, email, etc.
  thread_id TEXT, -- For threading conversations
  
  -- Status
  status TEXT DEFAULT 'active', -- active, archived
  
  -- Timestamps
  started_at TIMESTAMP NOT NULL DEFAULT NOW(),
  last_message_at TIMESTAMP NOT NULL DEFAULT NOW(),
  ended_at TIMESTAMP,
  
  -- Metadata
  metadata JSONB DEFAULT '{}'
);

-- Indexes
CREATE INDEX idx_agent_conversations_agent_id ON agent_conversations(agent_id);
CREATE INDEX idx_agent_conversations_external_user ON agent_conversations(external_user_id);
```

### `agent_integrations` Table
Manages third-party integrations for agents.

```sql
CREATE TABLE agent_integrations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  agent_id UUID NOT NULL REFERENCES a1_agents(id) ON DELETE CASCADE,
  
  -- Integration Details
  provider TEXT NOT NULL, -- whatsapp, slack, discord, etc.
  status TEXT DEFAULT 'active',
  
  -- Configuration
  config JSONB NOT NULL DEFAULT '{}', -- Encrypted sensitive data
  
  -- Timestamps
  created_at TIMESTAMP NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMP NOT NULL DEFAULT NOW(),
  last_sync_at TIMESTAMP,
  
  -- Constraints
  CONSTRAINT unique_agent_provider UNIQUE (agent_id, provider)
);
```

### Updates to Existing Tables

#### `apps` Table (existing)
Add a reference to track which app belongs to which agent:
```sql
ALTER TABLE apps ADD COLUMN agent_id UUID UNIQUE REFERENCES a1_agents(id);
```

#### `messages` Table (existing)
Add fields to track which agent and conversation:
```sql
ALTER TABLE messages 
  ADD COLUMN agent_id UUID REFERENCES a1_agents(id),
  ADD COLUMN conversation_id UUID REFERENCES agent_conversations(id);
```

## Key Relationships

1. **User → A1Agents**: One-to-many (limited by subscription)
2. **A1Agent ↔ App**: One-to-one (bidirectional unique constraint)
3. **User → Subscription**: One-to-one
4. **A1Agent → Usage**: One-to-many
5. **A1Agent → Conversations**: One-to-many
6. **A1Agent → Integrations**: One-to-many

## Business Rules

1. **Agent Limits**:
   - Free users: 1 personal + 1 work agent
   - Pro users: 5 personal + 5 work agents
   - Enterprise: Unlimited agents

2. **Handle Requirements**:
   - Must be unique across all agents
   - Only alphanumeric and underscore characters
   - Used for public agent URLs (e.g., `a1zap.com/@agent_handle`)

3. **Billing**:
   - Usage tracked daily per agent
   - Billing calculated monthly based on usage
   - Overage charges for exceeding plan limits

4. **Agent Lifecycle**:
   - Creating an agent automatically creates an associated app
   - Deleting an agent cascades to delete the app and all related data
   - Agents can be paused to stop billing but preserve data

## Migration Strategy

1. Create new tables in order of dependencies
2. Update existing tables with new columns
3. Migrate any existing data to new structure
4. Add foreign key constraints
5. Create indexes for performance

## Security Considerations

1. **Data Encryption**:
   - Sensitive integration configs should be encrypted
   - Phone numbers and emails should be encrypted at rest

2. **Access Control**:
   - Users can only access their own agents
   - Admin users can access all agents for support

3. **Rate Limiting**:
   - Track API usage per agent
   - Implement rate limits based on subscription tier

## Future Considerations

1. **Team Collaboration**:
   - Add team/organization support
   - Share agents between team members

2. **Agent Templates**:
   - Pre-configured agent templates
   - Marketplace for sharing agent configurations

3. **Analytics**:
   - Detailed analytics per agent
   - Performance metrics and insights

4. **Audit Trail**:
   - Track all changes to agents
   - Compliance and debugging support 
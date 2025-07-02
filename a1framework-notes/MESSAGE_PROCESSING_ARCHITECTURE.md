# Message Processing Architecture Guide

## Overview

This document provides a comprehensive guide to understanding how the A1Base messaging system processes incoming messages, performs triage, and routes them through various workflows. This architecture can be adapted for implementing a multi-agent system where different agents handle different types of requests.

!!NOTE: For this implementation in a1zap, we are happy to use any llm provider like claude, grok, and openai.!!

## Table of Contents

1. [Architecture Overview](#architecture-overview)
2. [Message Flow](#message-flow)
3. [Core Components](#core-components)
4. [Triage System](#triage-system)
5. [Workflow Implementation](#workflow-implementation)
6. [Multi-Agent Considerations](#multi-agent-considerations)
7. [Implementation Examples](#implementation-examples)

## Architecture Overview

The A1Base messaging system follows a pipeline architecture:

1. **Webhook Reception**: Messages arrive via webhooks from various channels (WhatsApp, SMS, RCS, iMessage)
2. **Message Processing**: Messages are normalized, stored, and prepared for processing
3. **Triage**: AI-powered classification determines the intent and appropriate workflow
4. **Workflow Execution**: Specialized handlers process different types of requests
5. **Response Generation**: AI generates contextual responses
6. **Message Delivery**: Responses are sent back through the appropriate channel

## Message Flow

### 1. Webhook Entry Point

All messages enter through a unified webhook endpoint:

```typescript
// app/api/a1base/messaging/route.ts
export interface WebhookPayload {
  thread_id: string;
  message_id: string;
  thread_type: 'group' | 'individual' | 'broadcast';
  sender_number: string;
  sender_name: string;
  timestamp: string;
  service: string; // 'whatsapp', 'sms', 'rcs', 'imessage'
  message_type: string; // 'text', 'image', 'video', etc.
  is_from_agent: boolean;
  agent_mentioned?: boolean;
  message_content: {
    text?: string;
    data?: string; // base64 for media
    // ... other content types
  };
}
```

### 2. Message Persistence

Messages are stored in both database and memory for redundancy:

```typescript
// lib/supabase/adapter.ts - processWebhookPayload method
async processWebhookPayload(payload: WebhookPayload) {
  // 1. Get or create user
  const userId = await this.getUserFromWebhook(
    payload.sender_number,
    payload.sender_name,
    payload.service
  );

  // 2. Get or create chat/thread
  const chatId = await this.getChatFromWebhook(
    payload.thread_id,
    payload.thread_type,
    payload.service
  );

  // 3. Add user as participant
  await this.addParticipantToChat(chatId, userId);

  // 4. Store the message
  await this.storeMessage(
    chatId,
    userId,
    payload.message_id,
    payload.message_content,
    payload.message_type,
    payload.service
  );
}
```

### 3. Message Processing Pipeline

The main processing happens in `handleWhatsAppIncoming`:

```typescript
// lib/ai-triage/handle-whatsapp-incoming.ts
export async function handleWhatsAppIncoming(webhookData: WebhookPayload) {
  // 1. Skip agent's own messages
  if (sender_number === process.env.A1BASE_AGENT_NUMBER) {
    // Store but don't process
    return;
  }

  // 2. Check group chat mention requirements
  if (thread_type === 'group' && respondOnlyWhenMentioned && !agent_mentioned) {
    // Store but skip processing
    return;
  }

  // 3. Process multimedia messages
  if (message_type !== 'text') {
    processedContent = processIncomingMediaMessage(message_content, message_type);
  }

  // 4. Persist message
  const { chatId, isNewChatInDb } = await persistIncomingMessage(webhookData, adapter);

  // 5. Check for onboarding needs
  const shouldTriggerOnboarding = await checkIfOnboardingNeeded(thread_id, adapter, threadMessages);

  // 6. Handle onboarding or standard triage
  if (shouldTriggerOnboarding) {
    await manageIndividualOnboardingProcess(threadMessages, webhookData, adapter, chatId);
  } else {
    const triageResult = await triageMessage({
      thread_id,
      message_id,
      content: processedContent,
      // ... other params
    });
  }

  // 7. Send response
  await sendResponseMessage(triageResponseText, thread_type, recipient, service, chatId, adapter);
}
```

## Core Components

### 1. Triage System

The triage system uses OpenAI to classify incoming messages and determine the appropriate workflow:

```typescript
// lib/services/openai.ts
export async function triageMessageIntent(
  threadMessages: ThreadMessage[],
  projects: any[] = []
): Promise<TriageResult> {
  // AI analyzes conversation context and returns:
  return {
    responseType: "simpleResponse" | "projectFlow" | "emailReportFlow" | "onboardingFlow",
    // Additional context-specific fields
    projectAction?: "create" | "update" | "complete" | "reference",
    projectName?: string,
    // ... other fields
  };
}
```

### 2. Workflow Router

Based on triage results, messages are routed to appropriate workflows:

```typescript
// lib/ai-triage/triage-logic.ts
switch (triage.responseType) {
  case "onboardingFlow":
    // Handle new user onboarding
    break;
    
  case "projectFlow":
    // Handle project management requests
    break;
    
  case "emailReportFlow":
    // Handle email report requests
    break;
    
  case "simpleResponse":
  default:
    // Generate standard conversational response
    break;
}
```

### 3. Response Generation

Each workflow generates responses using AI with specific prompts:

```typescript
// lib/workflows/basic_workflow.ts
export async function DefaultReplyToMessage(
  threadMessages: ThreadMessage[],
  thread_type: "individual" | "group",
  // ... other params
): Promise<string> {
  // Generate AI response with context
  const aiResponse = await generateAgentResponse(
    threadMessages,
    basicWorkflowsPrompt.simple_response.user,
    thread_type,
    participants,
    projects,
    service
  );
  
  // Send response through appropriate channel
  await _sendWhatsAppMessage(thread_type, recipientId, aiResponse);
  
  return aiResponse;
}
```

## Triage System

### Intent Classification

The triage system uses a sophisticated prompt to classify intents:

```typescript
const triagePrompt = `
Based on the conversation, analyze the user's intent and respond with JSON:
- "responseType": one of ["simpleResponse", "projectFlow", "emailReportFlow", "onboardingFlow"]
- Additional fields based on intent.

Rules:
- "projectFlow": Used for ALL project-related actions
- "emailReportFlow": Used for email report requests
- "onboardingFlow": Related to user onboarding
- "simpleResponse": Default for all other messages

For "projectFlow" responses, include:
- "projectAction": one of ["create", "update", "complete", "reference"]
- "projectName": Name of the project
- "projectDescription": Description (for create)
`;
```

### Context Awareness

The triage system considers:
- Conversation history
- Existing projects
- User preferences
- Previous interactions
- Current context

## Workflow Implementation

### 1. Simple Response Workflow

Handles general conversational messages:

```typescript
// Uses OpenAI to generate contextual responses
// Considers conversation history and user context
// Applies personality and tone settings from agent profile
```

### 2. Project Management Workflow

Handles CRUD operations for projects:

```typescript
case "projectFlow":
  const projectAction = triage.projectAction;
  
  switch(projectAction) {
    case "create":
      await adapter.createProject(projectName, projectDescription, chatId);
      break;
    case "update":
      await adapter.updateProject(projectId, updates);
      break;
    case "complete":
      await adapter.updateProject(projectId, { is_live: false });
      break;
  }
```

### 3. Onboarding Workflow

Handles new user onboarding:

```typescript
// Loads onboarding configuration
const onboardingFlow = await loadOnboardingFlow();

// Generates conversational onboarding messages
const onboardingMessage = await generateOnboardingMessage(
  systemPrompt,
  threadMessages,
  userMessage,
  service
);
```

## Multi-Agent Considerations

### 1. Agent Selection

For a multi-agent system, extend the triage to include agent selection:

```typescript
interface MultiAgentTriageResult {
  responseType: string;
  selectedAgent: string; // 'sales', 'support', 'technical', etc.
  confidence: number;
  handoffRequired: boolean;
  context: any;
}
```

### 2. Agent Profiles

Each agent should have a distinct profile:

```typescript
interface AgentProfile {
  id: string;
  name: string;
  specialties: string[];
  systemPrompt: string;
  capabilities: string[];
  escalationAgent?: string;
}
```

### 3. Context Handoff

When transferring between agents:

```typescript
interface AgentHandoff {
  fromAgent: string;
  toAgent: string;
  reason: string;
  context: {
    conversation: ThreadMessage[];
    userInfo: any;
    currentIntent: string;
    metadata: any;
  };
}
```

### 4. Agent Routing Logic

```typescript
async function routeToAgent(
  triageResult: MultiAgentTriageResult,
  threadMessages: ThreadMessage[]
): Promise<AgentResponse> {
  const agent = await getAgent(triageResult.selectedAgent);
  
  // Check if agent can handle request
  if (!agent.canHandle(triageResult.context)) {
    // Escalate to supervisor or fallback agent
    return await escalateToAgent(agent.escalationAgent, triageResult);
  }
  
  // Process with selected agent
  return await agent.processRequest(threadMessages, triageResult.context);
}
```

## Implementation Examples

### 1. Adding a New Workflow

To add a new workflow (e.g., appointment scheduling):

```typescript
// 1. Update triage intent types
export async function triageMessageIntent() {
  // Add "appointmentFlow" to responseType options
}

// 2. Add workflow handler
export async function handleAppointmentFlow(
  messages: ThreadMessage[],
  appointmentAction: string
) {
  switch(appointmentAction) {
    case "schedule":
      // Schedule appointment logic
      break;
    case "reschedule":
      // Reschedule logic
      break;
    case "cancel":
      // Cancellation logic
      break;
  }
}

// 3. Update triage router
switch (triage.responseType) {
  case "appointmentFlow":
    await handleAppointmentFlow(messages, triage.appointmentAction);
    break;
}
```

### 2. Implementing Agent Specialization

```typescript
// Define agent specialties
const AGENT_SPECIALTIES = {
  sales: {
    keywords: ['pricing', 'buy', 'purchase', 'cost', 'plan'],
    intents: ['product_inquiry', 'pricing_request', 'demo_request'],
    systemPrompt: 'You are a helpful sales agent...'
  },
  support: {
    keywords: ['help', 'issue', 'problem', 'not working', 'error'],
    intents: ['technical_support', 'bug_report', 'troubleshooting'],
    systemPrompt: 'You are a technical support agent...'
  }
};

// Agent selection logic
function selectAgent(message: string, intent: string): string {
  // Score each agent based on keyword matches and intent alignment
  const scores = {};
  
  for (const [agent, config] of Object.entries(AGENT_SPECIALTIES)) {
    let score = 0;
    
    // Check keyword matches
    config.keywords.forEach(keyword => {
      if (message.toLowerCase().includes(keyword)) score += 10;
    });
    
    // Check intent alignment
    if (config.intents.includes(intent)) score += 20;
    
    scores[agent] = score;
  }
  
  // Return highest scoring agent
  return Object.entries(scores)
    .sort(([,a], [,b]) => b - a)[0][0];
}
```

### 3. Implementing Context Preservation

```typescript
// Store agent context between interactions
interface AgentContext {
  currentAgent: string;
  conversationState: any;
  userPreferences: any;
  taskProgress: any;
}

async function preserveAgentContext(
  chatId: string,
  context: AgentContext
): Promise<void> {
  await adapter.upsertChatThreadMemoryValue(
    chatId,
    'agent_context',
    JSON.stringify(context)
  );
}

async function retrieveAgentContext(
  chatId: string
): Promise<AgentContext | null> {
  const stored = await adapter.getChatThreadMemoryValue(
    chatId,
    'agent_context'
  );
  
  return stored ? JSON.parse(stored) : null;
}
```

## Best Practices

### 1. Error Handling

Always implement robust error handling:

```typescript
try {
  const triageResult = await triageMessage(params);
  // Process result
} catch (error) {
  console.error('[Triage] Error:', error);
  // Fallback to default response
  return {
    type: "default",
    success: false,
    message: "I'm having trouble processing your request. Please try again."
  };
}
```

### 2. Performance Optimization

- Use parallel processing where possible
- Cache frequently accessed data
- Implement message batching for high volume
- Use connection pooling for database

### 3. Monitoring and Logging

- Log all triage decisions
- Track response times
- Monitor error rates
- Implement alerting for failures

### 4. Testing

- Unit test each workflow
- Integration test the full pipeline
- Load test with realistic message volumes
- Test edge cases and error scenarios

## Conclusion

This architecture provides a flexible foundation for building multi-agent messaging systems. The key components - webhook handling, message persistence, AI-powered triage, and modular workflows - can be extended and customized to support various use cases and agent configurations.

The system's strength lies in its:
- **Modularity**: Easy to add new workflows and agents
- **Scalability**: Can handle multiple channels and high message volumes
- **Intelligence**: AI-powered intent classification and response generation
- **Flexibility**: Supports various message types and interaction patterns

When implementing a multi-agent system, focus on:
1. Clear agent boundaries and specializations
2. Smooth context handoffs between agents
3. Consistent user experience across agents
4. Robust error handling and fallback mechanisms 



The files in a1framework that implement this. Feel free to ask for the contents of these files when implementing this in a1zap.

PI Files (Routes/Endpoints)
Primary Message Ingestion:
app/api/a1base/messaging/route.ts
Main webhook endpoint for all messaging channels (WhatsApp, SMS, RCS, iMessage)
Receives WebhookPayload and routes to appropriate handlers
Channel-Specific Routes:
app/api/a1base/sms/route.ts
Dedicated SMS webhook handler
Processes SMS-specific payloads
app/api/a1base/sms/status/route.ts
Handles SMS delivery status updates
app/api/a1base/email/route.ts
Email webhook handler for incoming emails
Web UI Integration:
app/api/chat/route.ts
Web UI chat endpoint
Handles messages from the web interface
app/api/chat/socket-message/route.ts
Real-time message handling for web UI
Library Files
Core Message Processing:
lib/ai-triage/handle-whatsapp-incoming.ts
Main message processing pipeline
Handles message persistence, onboarding checks, and triage routing
lib/ai-triage/triage-logic.ts
Message triage router
Routes messages to appropriate workflows based on intent
lib/ai-triage/types.ts
Type definitions for triage system
AI/OpenAI Integration:
lib/services/openai.ts
AI intent classification (triageMessageIntent)
Response generation functions
Database/Persistence:
lib/supabase/adapter.ts
Database operations including processWebhookPayload
User, chat, and message management
lib/supabase/config.ts
Database configuration and initialization
lib/data/message-storage.ts
Message storage operations
In-memory and database storage functions
Workflows:
lib/workflows/basic_workflow.ts
DefaultReplyToMessage - main response generation
Message sending logic
lib/workflows/onboarding-workflow.ts
StartOnboarding - handles new user onboarding
lib/workflows/email_workflow.ts
Email-related workflows
lib/workflows/group-onboarding-workflow.ts
Group chat onboarding logic
Messaging/Communication:
lib/messaging/multimedia-handler.ts
Handles multimedia message processing
Webhook Processing:
lib/webhooks/sms-processor.ts
SMS webhook processing and transformation
Configuration:
lib/agent/system-prompt.ts
Agent personality and system prompt configuration
lib/agent-profile/agent-profile-settings.ts
Agent profile settings management
lib/settings/message-settings.ts
Message processing settings
Memory/Context:
lib/agent-memory/memory-processor.ts
Processes messages for memory updates
Flow Summary
The typical flow uses these files in sequence:
Webhook Reception: app/api/a1base/messaging/route.ts
Message Processing: lib/ai-triage/handle-whatsapp-incoming.ts
Persistence: lib/supabase/adapter.ts (processWebhookPayload)
Triage: lib/services/openai.ts (triageMessageIntent)
Routing: lib/ai-triage/triage-logic.ts
Workflow Execution: lib/workflows/basic_workflow.ts or other workflow files
Response Generation: lib/services/openai.ts (generateAgentResponse)
Message Delivery: Back through lib/workflows/basic_workflow.ts
This modular structure allows for easy extension and modification of individual components without affecting the entire system.
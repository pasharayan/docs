# A1Base Email Integration

This document describes how A1Zap-maker integrates with A1Base to provide email functionality for AI agents.

## Overview

A1Base provides email infrastructure that allows AI agents to:
- Have their own email addresses (@a1send.com or @a101.bot)
- Send emails independently
- Receive emails via webhooks
- Maintain email conversations

## Setup

### Environment Variables

Add these to your `.env` file:

```env
A1BASE_API_KEY=your_api_key
A1BASE_API_SECRET=your_api_secret
A1BASE_ACCOUNT_ID=your_account_id
```

### Webhook Configuration

Configure A1Base to send incoming emails to:
```
https://your-domain.com/api/webhooks/a1base-email
```

## Usage

### 1. Email Service (`src/lib/a1base-email.ts`)

Core service for interacting with A1Base API:

```typescript
import { a1BaseEmail } from "@/lib/a1base-email";

// Create email for agent
const result = await a1BaseEmail.createAgentEmail("AgentName", "a1send.com");

// Send email
await a1BaseEmail.sendEmail({
  sender_address: "agent@a1send.com",
  recipient_address: "user@example.com",
  subject: "Hello",
  body: "Message content"
});
```

### 2. Server Actions (`src/app/actions/email-actions.ts`)

Server-side functions for email operations:

```typescript
import { createAgentEmailAddress, sendAgentEmail } from "@/app/actions/email-actions";

// Create email for existing agent
const result = await createAgentEmailAddress(agentId, "a1send.com");

// Send email from agent
await sendAgentEmail(agentId, recipientEmail, subject, body);
```

### 3. React Hook (`src/hooks/use-agent-email.ts`)

Client-side hook for email operations:

```typescript
const { createEmail, sendEmail, isLoading, error } = useAgentEmail();

// Create email
const result = await createEmail(agentId);

// Send email
await sendEmail(agentId, recipientEmail, subject, body);
```

### 4. Email Manager Component (`src/components/agent-email-manager.tsx`)

Ready-to-use UI component:

```tsx
<AgentEmailManager 
  agentId={agent.id}
  agentName={agent.name}
  currentEmail={agent.email}
  userEmail={user.email}
/>
```

## Automatic Email Creation

When creating a new agent via the onboarding flow, an email address is automatically created if:
- The agent doesn't have an email yet
- The email domain is @a1friend.com (placeholder)

The system will:
1. Generate a valid email address based on the agent name
2. Create the email via A1Base API
3. Send a welcome email to the user
4. Store the email in the agent record

## Email Validation Rules

A1Base email addresses must:
- Be 5-30 characters long
- Only contain letters, numbers, '.', '_', '-'
- Have no consecutive dots, spaces, or commas

## Receiving Emails

Incoming emails are:
1. Received via webhook at `/api/webhooks/a1base-email`
2. Matched to agents by email address
3. Stored as messages in the database
4. Associated with a conversation

## Testing

Use the test page at `/test-email` to:
- Create email addresses
- Validate email formats
- Send test emails
- View email suggestions

## Error Handling

The integration includes:
- Graceful fallbacks if email creation fails
- Error messages in UI components
- Logging for debugging
- Non-blocking operations (email failures don't break agent creation)

## Security Considerations

- API credentials are stored in environment variables
- Webhook endpoint validates incoming requests
- Email content is sanitized before storage
- Access control via agent ownership

## Future Enhancements

Potential improvements:
- Custom domain support
- Email templates
- Automated responses
- Email threading
- Attachment handling
- Email analytics 
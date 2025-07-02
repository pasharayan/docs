# Stack Auth Integration Guide

## Overview
This document explains how Stack Auth is integrated into a1zap and how it connects to our internal user system. Stack Auth handles authentication while our database maintains user-related data and relationships.

## Architecture Overview

```
┌─────────────────┐     ┌──────────────────┐     ┌─────────────────┐
│   Stack Auth    │────▶│    a1zap App     │────▶│   PostgreSQL    │
│   (Auth Layer)  │     │  (Business Logic) │     │   (Data Layer)  │
└─────────────────┘     └──────────────────┘     └─────────────────┘
```

## How Stack Auth Works

### 1. Authentication Provider
Stack Auth is a third-party authentication service that:
- Manages user registration and login
- Handles password resets and email verification
- Provides OAuth integrations (Google, GitHub, etc.)
- Stores basic user profile data
- Issues JWT tokens for session management

### 2. User Identification
When a user authenticates via Stack Auth:
- Stack Auth assigns a unique `user.id` (string)
- This ID becomes our primary user identifier
- We use this ID to link all user data in our database

## Integration Points

### 1. Stack Auth Configuration (`src/auth/stack-auth.ts`)

```typescript
import { StackServerApp } from "@stackframe/stack";

export const stackServerApp = new StackServerApp({
  tokenStore: "nextjs-cookie",  // Stores auth tokens in cookies
});

export async function getUser() {
  const user = await stackServerApp.getUser();
  
  if (!user) {
    throw new Error("User not found");
  }
  
  // Ensure user has a Freestyle identity for Git operations
  if (!user?.serverMetadata?.freestyleIdentity) {
    const gitIdentity = await freestyle.createGitIdentity();
    
    await user.update({
      serverMetadata: {
        freestyleIdentity: gitIdentity.id,
      },
    });
  }
  
  return {
    userId: user.id,  // Stack Auth user ID
    freestyleIdentity: user.serverMetadata.freestyleIdentity,
  };
}
```

### 2. Environment Variables Required

```env
NEXT_PUBLIC_STACK_PROJECT_ID=<your-project-id>
NEXT_PUBLIC_STACK_PUBLISHABLE_CLIENT_KEY=<your-publishable-client-key>
STACK_SECRET_SERVER_KEY=<your-secret-server-key>
```

## Database Relationships

### User References in Our Database

Stack Auth users are referenced throughout our database using their Stack Auth ID:

1. **`app_users` table**
   ```sql
   userId: text("user_id").notNull()  -- Stack Auth user ID
   ```

2. **`a1_agents` table**
   ```sql
   owner_id: TEXT NOT NULL  -- Stack Auth user ID
   ```

3. **`user_subscriptions` table**
   ```sql
   user_id: TEXT UNIQUE NOT NULL  -- Stack Auth user ID
   ```

4. **`billing_events` table**
   ```sql
   user_id: TEXT NOT NULL  -- Stack Auth user ID
   ```

### Data Flow Example

When a user creates a new AI agent:

```typescript
// 1. Get authenticated user from Stack Auth
const user = await getUser();
// Returns: { userId: "stack_auth_id_123", freestyleIdentity: "git_id_456" }

// 2. Create agent in our database
const agent = await db.insert(a1_agents).values({
  owner_id: user.userId,  // Link to Stack Auth user
  name: "My AI Agent",
  // ... other fields
});

// 3. Create subscription record (if first time)
await db.insert(user_subscriptions).values({
  user_id: user.userId,  // Same Stack Auth ID
  plan_id: "free",
  // ... other fields
});
```

## Authentication Flow

### 1. User Registration/Login
```
User → Stack Auth Sign-in Page → Stack Auth Backend → JWT Token → a1zap App
```

### 2. Authenticated Requests
```
User Request → Next.js Middleware → Verify Stack Auth Token → Load User → Process Request
```

### 3. Protected Routes
All authenticated routes use Stack Auth's built-in protection:

```typescript
// In components
const user = useUser({ or: "redirect" });  // Redirects to login if not authenticated

// In server actions
const user = await getUser();  // Throws error if not authenticated
```

## Key Integration Files

1. **`src/auth/stack-auth.ts`**
   - Stack Auth configuration
   - User retrieval helper
   - Freestyle identity management

2. **`src/app/handler/[...stack]/page.tsx`**
   - Stack Auth UI handler
   - Manages login/signup/password reset pages

3. **`src/app/layout.tsx`**
   - Wraps app with StackProvider
   - Enables Stack Auth throughout the app

4. **Server Actions** (e.g., `src/actions/create-app.ts`)
   - All use `getUser()` to get authenticated user
   - Link created resources to Stack Auth user ID

## User Metadata

Stack Auth allows storing custom metadata on users:

### Server Metadata (Private)
- Only accessible server-side
- Used for storing `freestyleIdentity`
- Can store any JSON data

### Client Metadata (Public)
- Accessible in the browser
- Not currently used in a1zap

Example of updating metadata:
```typescript
await user.update({
  serverMetadata: {
    freestyleIdentity: gitIdentity.id,
    customField: "value"
  }
});
```

## Security Considerations

1. **Token Storage**
   - Auth tokens stored in httpOnly cookies
   - Prevents XSS attacks
   - Automatically sent with requests

2. **User Isolation**
   - All queries filter by Stack Auth user ID
   - Users can only access their own data
   - Example:
     ```typescript
     const userApps = await db
       .select()
       .from(appUsers)
       .where(eq(appUsers.userId, user.userId));
     ```

3. **Permission Checks**
   - Every action verifies user ownership
   - Additional permission levels (read/write/admin) for shared resources

## Benefits of This Architecture

1. **Separation of Concerns**
   - Stack Auth handles authentication complexity
   - a1zap focuses on business logic
   - Clear boundary between auth and app data

2. **Scalability**
   - No need to manage password hashing
   - Built-in OAuth providers
   - Professional auth UI components

3. **Security**
   - Battle-tested authentication
   - Regular security updates from Stack Auth
   - Reduced attack surface

4. **Developer Experience**
   - Simple API for checking authentication
   - Built-in React hooks
   - TypeScript support

## Common Patterns

### Checking Authentication Status
```typescript
// In React components
const user = useUser();
if (user) {
  // User is logged in
}

// In server components/actions
try {
  const user = await getUser();
  // User is authenticated
} catch {
  // User is not authenticated
}
```

### Creating User-Owned Resources
```typescript
const user = await getUser();
await db.insert(tableName).values({
  ...data,
  owner_id: user.userId,  // Always link to Stack Auth ID
});
```

### Querying User Data
```typescript
const user = await getUser();
const userData = await db
  .select()
  .from(tableName)
  .where(eq(tableName.owner_id, user.userId));
```

## Migration Considerations

If migrating from another auth system:
1. Create Stack Auth accounts for existing users
2. Map old user IDs to Stack Auth IDs
3. Update all foreign key references
4. Migrate any custom user data to Stack Auth metadata

## Troubleshooting

### Common Issues

1. **"User not found" errors**
   - Ensure user is logged in
   - Check Stack Auth configuration
   - Verify environment variables

2. **Permission denied**
   - Verify user owns the resource
   - Check permission levels in app_users table

3. **Lost Freestyle identity**
   - Automatically recreated on next access
   - Old Git permissions may need manual cleanup 
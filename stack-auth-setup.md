# Stack Auth Setup Guide for a1zap

## Prerequisites

1. Stack Auth account and project created at https://app.stack-auth.com
2. Google Cloud Console project for OAuth

## Environment Variables

Add these to your `.env.local` file:

```env
NEXT_PUBLIC_STACK_PROJECT_ID=<your-project-id>
NEXT_PUBLIC_STACK_PUBLISHABLE_CLIENT_KEY=<your-publishable-client-key>
STACK_SECRET_SERVER_KEY=<your-secret-server-key>
```

## Stack Auth Dashboard Configuration

### 1. Enable OAuth Providers

1. Go to your Stack Auth dashboard
2. Navigate to **Authentication** → **OAuth Providers**
3. Enable **Google** provider
4. Add your Google OAuth credentials:
   - Client ID (from Google Cloud Console)
   - Client Secret (from Google Cloud Console)

### 2. Configure Redirect URLs

1. In Stack Auth dashboard, go to **Settings** → **URLs**
2. Add the following redirect URLs:
   - `http://localhost:3001/handler/oauth-callback` (for local development)
   - `https://your-production-domain.com/handler/oauth-callback` (for production)
   - Any preview/staging URLs you need

### 3. Configure Domains

1. Go to **Configuration** → **Domains**
2. Enable **"Allow all localhost callbacks for development"**
3. Add your production domain(s)

## Google Cloud Console Configuration

### 1. Create OAuth 2.0 Credentials

1. Go to [Google Cloud Console](https://console.cloud.google.com)
2. Navigate to **APIs & Services** → **Credentials**
3. Click **Create Credentials** → **OAuth client ID**
4. Choose **Web application**

### 2. Configure OAuth Client

Add the following to your OAuth client:

**Authorized JavaScript origins:**
- `http://localhost:3001`
- `https://your-production-domain.com`

**Authorized redirect URIs:**
- `http://localhost:3001/handler/oauth-callback`
- `https://your-production-domain.com/handler/oauth-callback`

### 3. Copy Credentials

Copy the **Client ID** and **Client Secret** to use in Stack Auth dashboard.

## Common Issues

### 1. OAuth Callback 404 Error

If you get a 404 on `/handler/oauth-callback`, ensure:
- The `[...stack]` catch-all route exists at `src/app/handler/[...stack]/page.tsx`
- Stack Auth is properly initialized in your app

### 2. ServerMetadata Null Error

This happens when a new user signs up. The fix is already implemented in `src/auth/stack-auth.ts` which:
1. Checks if `serverMetadata` exists
2. Creates a Freestyle identity if it doesn't
3. Refetches the user to get the updated metadata

### 3. Redirect Loop

If you experience redirect loops:
- Check that your redirect URLs match exactly in both Stack Auth and Google Console
- Ensure cookies are not being blocked
- Verify environment variables are set correctly

## Testing OAuth Flow

1. Start your development server: `npm run dev`
2. Navigate to `http://localhost:3001`
3. Click through the onboarding flow
4. When redirected to sign in, choose "Sign in with Google"
5. Complete Google authentication
6. You should be redirected back to your app

## Production Deployment

Before deploying to production:

1. Update all redirect URLs to use your production domain
2. Set environment variables in your hosting provider (Vercel, etc.)
3. Ensure your production domain is added to both Stack Auth and Google Console
4. Test the OAuth flow in production 
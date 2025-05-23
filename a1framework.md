# A1Framework Documentation

## Overview
A1Framework is a professional, production-ready framework for building AI-powered chat agents using [A1Base](https://a1base.com) and [Next.js](https://nextjs.org/). It enables seamless multi-channel communication through WhatsApp, Email, Slack, Teams, and SMS, with a focus on WhatsApp integration. Powered by OpenAI's GPT-4, A1Framework provides a robust foundation for creating intelligent, responsive, and customizable conversational agents.

## Key Features
- **Effortless Multi-Channel Integration:** Connect with users across WhatsApp, Email, Slack, Teams, and SMS from one platform.
- **Advanced AI Capabilities:** Leverage OpenAI's GPT-4 for smart, context-aware conversations.
- **Persistent Conversations:** Maintain chat history for seamless user experiences.
- **Developer-Friendly Design:** Built with Next.js 14 and TypeScript for modern, scalable development.
- **Secure & Customizable:** Protect sensitive data and tailor your agent to your needs.

## Getting Started
### Prerequisites
- Node.js version 18.x or later
- [A1Base Account](https://dashboard.a1base.com) with API credentials
- [OpenAI API Key](https://platform.openai.com) for AI capabilities
- WhatsApp Business Number: Configured via A1Base

### Installation
1. **Clone the Repository**
   ```bash
   git clone https://github.com/a1baseai/a1framework
   cd a1framework
   ```
2. **Install dependencies**
   ```bash
   npm install
   ```
3. **Configure environment**
   Copy `.env.example` to `.env.local` and update with your credentials:
   ```env
   A1BASE_API_KEY=your_api_key
   A1BASE_API_SECRET=your_api_secret
   A1BASE_ACCOUNT_ID=your_account_id
   A1BASE_AGENT_NUMBER=your_agent_number
   A1BASE_AGENT_NAME=your_agent_name
   A1BASE_AGENT_EMAIL=email@a1send.com
   OPENAI_API_KEY=your_openai_key
   CRON_SECRET=your_generated_secret
   ```
4. **Register A1Base credentials**
   - Register at [A1Base Dashboard](https://dashboard.a1base.com)
   - Access Settings > API Keys for credentials
   - Locate Account ID in Dashboard overview
   - Configure WhatsApp business number
5. **Launch development server**
   ```bash
   npm run dev
   ```
   Your agent will be available at `http://localhost:3000`.

## Webhook Configuration
1. **Expose Local Server**
   ```bash
   ngrok http 3000
   ```
2. **Configure A1Base Webhook**
   - Navigate to Settings > Webhooks in A1Base Dashboard
   - Set Webhook URL: `https://your-ngrok-url/api/whatsapp/incoming`
   - Save configuration
3. **Verify Setup**
   - Send test message to WhatsApp business number
   - Confirm AI response
   - Review console logs for debugging

## Customization
- **Agent Personality:** Modify `lib/agent-profile/agent-profile-settings.json`
- **Safety Settings:** Update `lib/safety-config/safety-settings.json`
- **AI Response Logic:** Customize `lib/services/openai.ts`
- **Message Handling:** Adjust `lib/ai-triage/triage-logic.ts`
- **Workflows:** Enhance `lib/workflows/basic_workflow.ts`
- **Interface:** Modify `app/page.tsx`

## Support
- **A1Base Integration:** [Documentation](https://docs.a1base.com/llms-full.txt)
- **Template Issues:** [GitHub Issues](https://github.com/a1baseai/a1framework/issues)
- **General Inquiries:** [A1Base Support](https://a1base.com/support)

---
Made with ❤️ by the A1Base Community

# Getting Started: Sending Your First SMS with a1base

This guide will help you send your first SMS using the a1base API. Code samples are provided for both Python and TypeScript. 🚀

---

## Prerequisites
- Your a1base account ID
- API key and API secret
- Sender and recipient phone numbers
- Python 3 or Node.js (for TypeScript)

---

## 1. Endpoint Information
- **URL:** `POST /v1/messages/sms/{accountId}/send`
- **Headers:**
    - `x-api-key`: Your API key
    - `x-api-secret`: Your API secret
- **Body:**
    - `content`: Message body text
    - `from`: Sender phone number
    - `to`: Recipient phone number
    - `service`: `sms`

---

## 2. Python Example
```python
import requests

account_id = "YOUR_ACCOUNT_ID"
url = f"https://api.a1base.com/v1/messages/sms/{account_id}/send"
headers = {
    "x-api-key": "YOUR_API_KEY",
    "x-api-secret": "YOUR_API_SECRET",
    "Content-Type": "application/json"
}
data = {
    "content": "Hello from a1base! 🚀",
    "from": "SENDER_PHONE_NUMBER",
    "to": "RECIPIENT_PHONE_NUMBER",
    "service": "sms"
}

response = requests.post(url, json=data, headers=headers)
print(response.json())
```

---

## 3. TypeScript Example
```typescript
import axios from 'axios';

const accountId = 'YOUR_ACCOUNT_ID';
const url = `https://api.a1base.com/v1/messages/sms/${accountId}/send`;
const headers = {
  'x-api-key': 'YOUR_API_KEY',
  'x-api-secret': 'YOUR_API_SECRET',
  'Content-Type': 'application/json',
};
const data = {
  content: 'Hello from a1base! 🚀',
  from: 'SENDER_PHONE_NUMBER',
  to: 'RECIPIENT_PHONE_NUMBER',
  service: 'sms',
};

axios.post(url, data, { headers })
  .then(response => console.log(response.data))
  .catch(error => console.error(error));
```

---

## 4. Response Example
```json
{
  "to": "61433174782",
  "from": "61421868490",
  "body": "Hello from a1base! 🚀",
  "status": "queued"
}
```

---

You're all set to send your first SMS with a1base! 🎉📱
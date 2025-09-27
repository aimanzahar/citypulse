# CityPulse Dashboard Chatbot

This dashboard includes an AI-powered chatbot that uses OpenRouter's API to provide assistance with dashboard features and city reporting questions.

## Features

- **AI Assistant**: Powered by x-ai/grok-4-fast:free model via OpenRouter
- **Interactive Chat**: Real-time conversation with typing indicators
- **Quick Actions**: Pre-defined questions for common help topics
- **Mobile Responsive**: Works on desktop and mobile devices
- **Context Aware**: Understands CityPulse dashboard functionality
- **Secure API Key Management**: No hardcoded API keys in frontend code

## Setup

### 1. **Environment Variables**
Create a `.env` file in the dashboard directory:
```env
OPENROUTER_API_KEY=your_api_key_here
OPENROUTER_BASE_URL=https://openrouter.ai/api/v1
OPENROUTER_MODEL=x-ai/grok-4-fast:free
```

### 2. **Get API Key**
Sign up at [OpenRouter](https://openrouter.ai/) to get your free API key.

### 3. **Install Dependencies**
```bash
cd dashboard
npm install
```

### 4. **Setup API Key (Development)**
```bash
npm run setup
```
This script safely injects your API key from the `.env` file into the frontend code.

### 5. **Start Development Server**
```bash
npm run dev
```
Or manually:
```bash
npm run setup && python -m http.server 3000
```

## Usage

- Click the floating chat button (💬) in the bottom-right corner to open the chatbot
- Type your questions or use the quick action buttons for common queries
- The chatbot can help with:
  - Dashboard navigation and features
  - Understanding report statuses and categories
  - General questions about city reporting
  - Troubleshooting dashboard issues

## Quick Actions Available

- **Dashboard Help**: How to use dashboard filters
- **Report Status**: What different report statuses mean
- **Categories**: Types of city issues that can be reported
- **Navigation**: How to navigate to specific locations on the map

## Security Features

### 🔒 **No Hardcoded API Keys**
- API keys are never hardcoded in the frontend JavaScript
- Keys are loaded from environment variables at runtime
- Build-time replacement ensures keys aren't exposed in source code

### 🛡️ **Development vs Production**
- **Development**: Uses environment variables with build-time replacement
- **Production**: Should use a secure backend endpoint to serve configuration

### 🔧 **Backend Configuration Server (Optional)**
For enhanced security, you can run the included Python server:
```bash
pip install flask flask-cors python-dotenv
python server.py
```
This serves configuration from `http://localhost:3001/api/chatbot-config`

## Technical Details

- Built with React and modern JavaScript
- Uses OpenRouter API for AI responses
- Styled to match the CityPulse dashboard theme
- Includes error handling and loading states
- Mobile-responsive design
- Secure API key management

## Project Structure

```
dashboard/
├── .env                    # Environment variables (create this)
├── Chatbot.js             # Main chatbot component
├── app.js                 # Dashboard application
├── index.html             # Main HTML file
├── styles.css             # Styling
├── server.py              # Optional backend config server
├── replace-env-vars.js    # Development API key injection
├── package.json           # Node.js dependencies
└── requirements.txt       # Python dependencies
```

## Troubleshooting

If the chatbot isn't working:

1. **Check API Key**: Ensure your OpenRouter API key is valid and has credits
2. **Environment Setup**: Make sure `.env` file exists with correct variables
3. **Run Setup**: Execute `npm run setup` to inject the API key
4. **Check Console**: Look for error messages in browser developer tools
5. **Network Check**: Verify internet connection for API calls

### Common Issues

- **"API key not configured"**: Run `npm run setup` to inject the key
- **CORS errors**: Make sure the server is running from the correct directory
- **404 errors**: Check that all files are in the dashboard directory

## Security Best Practices

1. **Never commit API keys** to version control
2. **Use environment variables** for all sensitive configuration
3. **Consider backend services** for production deployments
4. **Rotate API keys** regularly
5. **Monitor API usage** on OpenRouter dashboard

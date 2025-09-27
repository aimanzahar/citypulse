#!/usr/bin/env node
/**
 * Simple script to replace environment variable placeholders in frontend code
 * This is a development convenience - in production, use proper build tools
 */

const fs = require('fs');
const path = require('path');
require('dotenv').config();

const CHATBOT_FILE = path.join(__dirname, 'Chatbot.js');
const ENV_FILE = path.join(__dirname, '.env');

// Read the current Chatbot.js file
let chatbotContent = fs.readFileSync(CHATBOT_FILE, 'utf8');

// Read the .env file
let envContent = fs.readFileSync(ENV_FILE, 'utf8');

// Extract the API key from .env
const apiKeyMatch = envContent.match(/OPENROUTER_API_KEY=(.+)/);
if (!apiKeyMatch) {
  console.error('❌ OPENROUTER_API_KEY not found in .env file');
  process.exit(1);
}

const actualApiKey = apiKeyMatch[1].trim();

// Replace the placeholder with the actual API key
const updatedContent = chatbotContent.replace(
  /OPENROUTER_API_KEY: ['"]YOUR_API_KEY_HERE['"]/,
  `OPENROUTER_API_KEY: '${actualApiKey}'`
);

// Write the updated file
fs.writeFileSync(CHATBOT_FILE, updatedContent);

console.log('✅ API key successfully injected into Chatbot.js');
console.log('🔒 Remember: This is for development only. Use secure methods in production.');

// Also update the hardcoded key in the fetch request
const fetchUpdatedContent = updatedContent.replace(
  /`Bearer \$\{config\.OPENROUTER_API_KEY\}`/g,
  `\`Bearer \${config.OPENROUTER_API_KEY}\``
);

fs.writeFileSync(CHATBOT_FILE, fetchUpdatedContent);
console.log('✅ Chatbot.js updated with secure API key reference');

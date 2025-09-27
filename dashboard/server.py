#!/usr/bin/env python3
"""
Simple configuration server for CityPulse Dashboard Chatbot
Serves API keys securely without exposing them in frontend code
"""

import os
import json
from flask import Flask, jsonify
from flask_cors import CORS
from dotenv import load_dotenv

# Load environment variables
load_dotenv()

app = Flask(__name__)
CORS(app)  # Enable CORS for all routes

@app.route('/api/chatbot-config', methods=['GET'])
def get_chatbot_config():
    """Serve chatbot configuration securely"""
    try:
        config = {
            'OPENROUTER_API_KEY': os.getenv('OPENROUTER_API_KEY'),
            'OPENROUTER_BASE_URL': os.getenv('OPENROUTER_BASE_URL', 'https://openrouter.ai/api/v1'),
            'OPENROUTER_MODEL': os.getenv('OPENROUTER_MODEL', 'x-ai/grok-4-fast:free')
        }

        # Validate that API key is present
        if not config['OPENROUTER_API_KEY']:
            return jsonify({'error': 'API key not configured'}), 500

        return jsonify(config)

    except Exception as e:
        return jsonify({'error': f'Failed to load configuration: {str(e)}'}), 500

@app.route('/api/config', methods=['GET'])
def get_config():
    """Legacy config endpoint"""
    return get_chatbot_config()

if __name__ == '__main__':
    print("Starting CityPulse Dashboard Configuration Server...")
    print("Server will run on http://localhost:3001")
    print("Make sure your .env file contains OPENROUTER_API_KEY")
    app.run(host='localhost', port=3001, debug=True)

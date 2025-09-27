#!/usr/bin/env python3
"""
Simple configuration server for CityPulse Dashboard Chatbot
Serves API keys securely without exposing them in frontend code
"""

import os
import json
import requests
from flask import Flask, jsonify, request
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

@app.route('/api/ticket-analytics', methods=['GET'])
def get_ticket_analytics():
    """Fetch real ticket analytics data from backend"""
    try:
        backend_url = os.getenv('BACKEND_URL', 'http://localhost:8000')
        response = requests.get(f'{backend_url}/api/analytics')

        if response.status_code == 200:
            return jsonify(response.json())
        else:
            return jsonify({'error': f'Backend error: {response.status_code}'}), 500

    except Exception as e:
        return jsonify({'error': f'Failed to fetch analytics: {str(e)}'}), 500

@app.route('/api/tickets', methods=['GET'])
def get_tickets():
    """Fetch real ticket data from backend with optional filtering"""
    try:
        # Get query parameters
        user_id = None  # Not needed for general queries
        category = None
        severity = None
        status = None

        backend_url = os.getenv('BACKEND_URL', 'http://localhost:8000')
        params = {}

        if category:
            params['category'] = category
        if severity:
            params['severity'] = severity
        if status:
            params['status'] = status

        response = requests.get(f'{backend_url}/api/tickets', params=params)

        if response.status_code == 200:
            return jsonify(response.json())
        else:
            return jsonify({'error': f'Backend error: {response.status_code}'}), 500

    except Exception as e:
        return jsonify({'error': f'Failed to fetch tickets: {str(e)}'}), 500

@app.route('/api/ticket-stats', methods=['GET'])
def get_ticket_stats():
    """Get formatted ticket statistics for chatbot"""
    try:
        # Fetch analytics data
        analytics_response = requests.get('http://localhost:3001/api/ticket-analytics')
        if analytics_response.status_code != 200:
            return jsonify({'error': 'Failed to fetch analytics data'}), 500

        analytics_data = analytics_response.json()

        # Format the data for the chatbot
        total_tickets = analytics_data.get('total_tickets', 0)
        severity_counts = analytics_data.get('severity_counts', {})
        status_counts = analytics_data.get('status_counts', {})
        category_counts = analytics_data.get('category_counts', {})

        # Convert severity keys back to readable format if needed
        severity_map = {
            'LOW': 'low',
            'MEDIUM': 'medium',
            'HIGH': 'high'
        }

        status_map = {
            'SUBMITTED': 'submitted',
            'IN_PROGRESS': 'in_progress',
            'FIXED': 'fixed'
        }

        readable_severity = {severity_map.get(k, k.lower()): v for k, v in severity_counts.items()}
        readable_status = {status_map.get(k, k.lower()): v for k, v in status_counts.items()}

        return jsonify({
            'total_tickets': total_tickets,
            'severity_breakdown': readable_severity,
            'status_breakdown': readable_status,
            'category_breakdown': category_counts,
            'high_severity_count': readable_severity.get('high', 0),
            'active_tickets_count': readable_status.get('submitted', 0) + readable_status.get('in_progress', 0)
        })

    except Exception as e:
        return jsonify({'error': f'Failed to get ticket stats: {str(e)}'}), 500

@app.route('/api/reverse-geocode', methods=['GET'])
def reverse_geocode():
    """Convert lat/lng coordinates to readable address"""
    try:
        lat = request.args.get('lat', type=float)
        lng = request.args.get('lng', type=float)

        if lat is None or lng is None:
            return jsonify({'error': 'lat and lng parameters are required'}), 400

        # Use Nominatim API (OpenStreetMap) for reverse geocoding
        url = f'https://nominatim.openstreetmap.org/reverse?format=json&lat={lat}&lon={lng}&zoom=14&addressdetails=1'

        headers = {
            'User-Agent': 'CityPulse-Dashboard/1.0 (citypulse@dashboard.app)',
            'Accept': 'application/json'
        }

        response = requests.get(url, headers=headers, timeout=5)

        if response.status_code == 200:
            data = response.json()

            # Extract relevant location information
            address = data.get('address', {})

            location_info = {
                'lat': lat,
                'lng': lng,
                'formatted_address': data.get('display_name', ''),
                'city': address.get('city') or address.get('town') or address.get('village'),
                'suburb': address.get('suburb') or address.get('neighbourhood'),
                'state': address.get('state'),
                'country': address.get('country'),
                'road': address.get('road') or address.get('pedestrian') or address.get('path')
            }

            # Clean up empty values
            location_info = {k: v for k, v in location_info.items() if v}

            # Ensure we have at least some basic location info
            if not location_info.get('city') and not location_info.get('formatted_address'):
                location_info['formatted_address'] = f'Location at {lat}, {lng}'
                location_info['city'] = 'Unknown Location'

            # If we have coordinates but no city, try to provide a more meaningful fallback
            if not location_info.get('city') or location_info.get('city') == 'Unknown Location':
                # For Malaysian coordinates (lat 1-7, lng 99-105), provide regional fallback
                if 1 <= lat <= 7 and 99 <= lng <= 105:
                    location_info['city'] = 'Malaysia'
                    location_info['state'] = 'Kuala Lumpur Area'
                    location_info['country'] = 'Malaysia'
                else:
                    location_info['city'] = 'Unknown Location'

            return jsonify(location_info)
        else:
            return jsonify({'error': f'Reverse geocoding failed: {response.status_code}'}), 500

    except Exception as e:
        return jsonify({'error': f'Failed to reverse geocode: {str(e)}'}), 500

@app.route('/api/ticket-locations', methods=['GET'])
def get_ticket_locations():
    """Get tickets with location information and city names"""
    try:
        # Get high severity tickets first (as mentioned in the user's example)
        severity = request.args.get('severity', 'high')

        backend_url = os.getenv('BACKEND_URL', 'http://localhost:8000')

        # Convert severity to proper format expected by backend
        severity_map = {
            'high': 'High',
            'medium': 'Medium',
            'low': 'Low'
        }
        backend_severity = severity_map.get(severity.lower(), severity)

        params = {'severity': backend_severity}

        response = requests.get(f'{backend_url}/api/tickets', params=params, timeout=5)

        if response.status_code != 200:
            return jsonify({'error': f'Failed to fetch tickets: {response.status_code}'}), 500

        tickets = response.json()

        # Add location information to each ticket
        tickets_with_locations = []
        for ticket in tickets:
            if ticket.get('latitude') and ticket.get('longitude'):
                try:
                    # Get reverse geocoding for this ticket
                    geo_response = requests.get(
                        'http://localhost:3001/api/reverse-geocode',
                        params={'lat': ticket['latitude'], 'lng': ticket['longitude']},
                        timeout=3
                    )

                    location_info = {}
                    if geo_response.status_code == 200:
                        location_info = geo_response.json()
                    else:
                        # Fallback location info if geocoding fails
                        location_info = {
                            'lat': ticket['latitude'],
                            'lng': ticket['longitude'],
                            'formatted_address': f'Location at {ticket["latitude"]}, {ticket["longitude"]}',
                            'city': 'Unknown'
                        }

                    ticket_with_location = {
                        **ticket,
                        'location_info': location_info
                    }
                    tickets_with_locations.append(ticket_with_location)

                except Exception as geo_error:
                    print(f"Error getting location for ticket {ticket.get('id')}: {geo_error}")
                    # Add ticket with basic location info even if geocoding fails
                    ticket_with_location = {
                        **ticket,
                        'location_info': {
                            'lat': ticket['latitude'],
                            'lng': ticket['longitude'],
                            'formatted_address': f'Location at {ticket["latitude"]}, {ticket["longitude"]}',
                            'city': 'Unknown'
                        }
                    }
                    tickets_with_locations.append(ticket_with_location)

        return jsonify({
            'tickets': tickets_with_locations,
            'count': len(tickets_with_locations),
            'severity_filter': severity
        })

    except Exception as e:
        return jsonify({'error': f'Failed to get ticket locations: {str(e)}'}), 500

if __name__ == '__main__':
    print("Starting CityPulse Dashboard Configuration Server...")
    print("Server will run on http://localhost:3001")
    print("Make sure your .env file contains OPENROUTER_API_KEY")
    print("Backend URL can be configured with BACKEND_URL environment variable")
    app.run(host='localhost', port=3001, debug=True)

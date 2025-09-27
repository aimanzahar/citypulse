#!/usr/bin/env python3
"""
Test script for chatbot data fetching functionality
"""

import requests
import json

def test_backend_connection():
    """Test if backend is accessible"""
    try:
        print("Testing backend connection...")
        response = requests.get('http://localhost:8000/api/analytics', timeout=5)
        if response.status_code == 200:
            data = response.json()
            print("✅ Backend connected successfully!")
            print(f"Total tickets: {data.get('total_tickets', 'N/A')}")
            print(f"Severity counts: {data.get('severity_counts', {})}")
            return True
        else:
            print(f"❌ Backend error: {response.status_code}")
            return False
    except Exception as e:
        print(f"❌ Backend connection failed: {e}")
        return False

def test_dashboard_server():
    """Test if dashboard server endpoints work"""
    try:
        print("\nTesting dashboard server endpoints...")

        # Test ticket analytics endpoint
        response = requests.get('http://localhost:3001/api/ticket-analytics', timeout=5)
        if response.status_code == 200:
            data = response.json()
            print("✅ Ticket analytics endpoint working!")
            print(f"Total tickets: {data.get('total_tickets', 'N/A')}")
        else:
            print(f"❌ Ticket analytics error: {response.status_code}")
            return False

        # Test ticket stats endpoint
        response = requests.get('http://localhost:3001/api/ticket-stats', timeout=5)
        if response.status_code == 200:
            data = response.json()
            print("✅ Ticket stats endpoint working!")
            print(f"Total tickets: {data.get('total_tickets', 'N/A')}")
            print(f"High severity count: {data.get('high_severity_count', 'N/A')}")
            print(f"Active tickets: {data.get('active_tickets_count', 'N/A')}")
            return True
        else:
            print(f"❌ Ticket stats error: {response.status_code}")
            return False

    except Exception as e:
        print(f"❌ Dashboard server test failed: {e}")
        return False

def test_real_data():
    """Test that we get real data, not hallucinated numbers"""
    try:
        print("\nTesting real data accuracy...")

        # Get real stats
        response = requests.get('http://localhost:3001/api/ticket-stats', timeout=5)
        if response.status_code != 200:
            print("❌ Failed to get real stats")
            return False

        real_stats = response.json()
        total_tickets = real_stats.get('total_tickets', 0)
        high_severity = real_stats.get('high_severity_count', 0)

        print("✅ Real data fetched:"        print(f"   Total tickets: {total_tickets}")
        print(f"   High severity tickets: {high_severity}")

        # Compare with expected values from demo data
        expected_total = 16
        expected_high = 4

        if total_tickets == expected_total and high_severity == expected_high:
            print("✅ Data matches expected values!")
            print(f"   Expected: {expected_total} total, {expected_high} high severity")
            return True
        else:
            print("⚠️  Data doesn't match expected values")
            print(f"   Expected: {expected_total} total, {expected_high} high severity")
            print(f"   Got: {total_tickets} total, {high_severity} high severity")
            return False

    except Exception as e:
        print(f"❌ Real data test failed: {e}")
        return False

if __name__ == '__main__':
    print("🧪 Testing CityPulse Chatbot Data Integration")
    print("=" * 50)

    # Test backend connection
    backend_ok = test_backend_connection()

    # Test dashboard server
    server_ok = test_dashboard_server()

    # Test real data accuracy
    data_ok = test_real_data()

    print("\n" + "=" * 50)
    if backend_ok and server_ok and data_ok:
        print("✅ All tests passed! Chatbot should now use real data.")
    else:
        print("❌ Some tests failed. Check server logs for details.")

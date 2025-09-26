import requests
import json
import uuid
from pathlib import Path

BASE_URL = "http://127.0.0.1:8000/api"  # API root

# ----------------------
# Helper function to log responses nicely
# ----------------------
def log_response(step_name, response):
    print(f"\n=== {step_name} ===")
    print("Status Code:", response.status_code)
    try:
        print("Response JSON:", json.dumps(response.json(), indent=2))
    except Exception:
        print("Response Text:", response.text)

# ----------------------
# 1. Create a new user
# ----------------------
def create_user(name, email):
    url = f"{BASE_URL}/users"
    payload = {"name": name, "email": email}
    response = requests.post(url, json=payload)
    log_response("CREATE USER", response)
    if response.status_code == 200:
        user_data = response.json()
        return user_data.get("id"), user_data.get("name")
    return None, None

# ----------------------
# 2. Submit a new report/ticket
# ----------------------
def submit_report(user_id, image_path):
    url = f"{BASE_URL}/report"
    if not Path(image_path).exists():
        print(f"Image file not found: {image_path}")
        return None

    data = {
        "user_id": user_id,
        "latitude": 3.12345,
        "longitude": 101.54321,
        "description": "Automated test report"
    }
    with open(image_path, "rb") as img_file:
        files = {"image": img_file}
        response = requests.post(url, data=data, files=files)
    log_response("SUBMIT REPORT", response)
    if response.status_code == 201:
        return response.json().get("ticket_id")
    return None

# ----------------------
# 3. Fetch all tickets
# ----------------------
def get_all_tickets():
    url = f"{BASE_URL}/tickets"
    response = requests.get(url)
    log_response("GET ALL TICKETS", response)

# ----------------------
# 4. Fetch a single ticket
# ----------------------
def get_ticket(ticket_id):
    url = f"{BASE_URL}/tickets/{ticket_id}"
    response = requests.get(url)
    log_response(f"GET TICKET {ticket_id}", response)

# ----------------------
# 5. Update ticket status
# ----------------------
def update_ticket(ticket_id, new_status):
    url = f"{BASE_URL}/tickets/{ticket_id}"
    payload = {"new_status": new_status}  # <-- use new_status to match backend
    response = requests.patch(url, json=payload)
    log_response(f"UPDATE TICKET {ticket_id} TO {new_status}", response)



# ----------------------
# 6. Fetch analytics
# ----------------------
def get_analytics():
    url = f"{BASE_URL}/analytics"
    response = requests.get(url)
    log_response("GET ANALYTICS", response)

# ----------------------
# Main test flow
# ----------------------
if __name__ == "__main__":
    print("=== STARTING BACKEND TEST SCRIPT ===")

    # # Step 1: Create user
    # user_name = "Test User"
    # user_email = f"testuser1@gmail.com"
    # user_id, returned_name = create_user(user_name, user_email)
    # if user_id:
    #     print(f"Created user: {returned_name} with ID: {user_id}")
    # else:
    #     print("Failed to create user, aborting script.")
    #     exit(1)
    
    user_id = "5fc2ac8b-6d77-4567-918e-39e31f749c79"  # Use existing user ID for testing

    # Step 2: Submit a ticket
    image_file = r"D:\CTF_Hackathon\gensprintai2025\images\potholes.jpeg"  # Update this path
    ticket_id = submit_report(user_id, image_file)
    if ticket_id:
        print(f"Created ticket with ID: {ticket_id}")

        # # Step 3: Fetch all tickets
        # get_all_tickets()

        # Step 4: Fetch single ticket
        get_ticket(ticket_id)

        # Step 5: Update ticket status to 'In Progress' then 'Fixed'
        update_ticket(ticket_id, "In Progress")
        get_ticket(ticket_id)
        update_ticket(ticket_id, "Fixed")

        # Step 6: Fetch analytics
        get_analytics()
    else:
        print("Ticket creation failed, skipping ticket tests.")

    print("\n=== BACKEND TEST SCRIPT COMPLETED ===")

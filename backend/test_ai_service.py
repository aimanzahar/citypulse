import os
from app.services.global_ai import get_ai_service

# Initialize AI service
ai_service = get_ai_service()

if ai_service is None:
    print("AI Service failed to initialize.")
    exit(1)

# ----------------------
# Test classification
# ----------------------
test_image = "D:\CTF_Hackathon\gensprintai2025\images\dtreet_light_1.jpg"

if not os.path.exists(test_image):
    print(f"Test image not found at {test_image}")
    exit(1)

try:
    category = ai_service.classify_category(test_image)
    print(f"Classification result: {category}")
except Exception as e:
    print(f"Classification failed: {e}")

# ----------------------
# Test detection / severity
# ----------------------
try:
    severity, output_path = ai_service.detect_pothole_severity(test_image, "tests/output.jpg")
    print(f"Detection result: Severity={severity}, Output saved to {output_path}")
except Exception as e:
    print(f"Detection failed: {e}")

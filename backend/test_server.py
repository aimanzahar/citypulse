#!/usr/bin/env python3

import sys
import os

# Add the current directory to Python path
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

try:
    print("Testing imports...")
    from app.database import Base, engine
    print("✓ Database imports successful")

    from app.models.ticket_model import User, Ticket, TicketStatus, SeverityLevel
    print("✓ Model imports successful")

    from app.services.ticket_service import TicketService
    print("✓ Service imports successful")

    from app.services.global_ai import init_ai_service
    print("✓ AI service imports successful")

    print("\nTesting database connection...")
    Base.metadata.create_all(bind=engine)
    print("✓ Database initialized successfully")

    print("\nTesting AI service initialization...")
    ai_service = init_ai_service()
    print("✓ AI service initialized successfully")

    print("\n✅ All tests passed! The backend should work correctly.")

except Exception as e:
    print(f"❌ Error: {e}")
    import traceback
    traceback.print_exc()
    sys.exit(1)
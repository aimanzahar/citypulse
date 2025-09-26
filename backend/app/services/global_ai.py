import os
from app.services.ai_service import AIModelManager, AIService
import logging
import random
from typing import Tuple

logger = logging.getLogger(__name__)
logger.setLevel(logging.DEBUG)

# ----------------------
# Lazy-initialized AI service
# ----------------------
_ai_service: AIService = None

def init_ai_service() -> AIService:
    """Initializes the AI service if not already initialized."""
    global _ai_service
    if _ai_service is None:
        logger.debug("Initializing AI service...")
        try:
            model_manager = AIModelManager()
            _ai_service = AIService(model_manager)
            logger.info("AI service ready.")
        except Exception as e:
            logger.warning(f"Failed to initialize AI service: {e}. Using mock service.")
            # Create a mock AI service for now
            _ai_service = MockAIService()
    return _ai_service

def get_ai_service() -> AIService:
    """Returns the initialized AI service."""
    return init_ai_service()

# Mock AI service for testing when models can't be loaded
class MockAIService:
    def classify_category(self, image_path: str) -> str:
        categories = ["pothole", "streetlight", "garbage", "signage", "drainage", "other"]
        return random.choice(categories)

    def detect_pothole_severity(self, image_path: str) -> Tuple[str, str]:
        severities = ["High", "Medium", "Low"]
        severity = random.choice(severities)
        return severity, image_path  # Return same path as annotated path

from typing import Optional
from fastapi import APIRouter, UploadFile, File, Form, Depends, HTTPException, Request
from fastapi.responses import JSONResponse
from sqlalchemy.orm import Session
from app.database import get_db
from app.services.ticket_service import TicketService, SeverityLevel
from app.models.ticket_model import User
from app.services.global_ai import get_ai_service
from app.utils import make_image_url, normalize_image_path_for_url
from pathlib import Path
import logging, uuid

router = APIRouter()
logger = logging.getLogger(__name__)
logger.setLevel(logging.DEBUG)

UPLOAD_DIR = Path("static") / "uploads"
UPLOAD_DIR.mkdir(parents=True, exist_ok=True)

@router.post("/report")
async def report_issue(
    user_id: Optional[str] = Form(None),
    user_name: Optional[str] = Form(None),
    latitude: float = Form(...),
    longitude: float = Form(...),
    address: Optional[str] = Form(None),
    description: str = Form(""),
    image: UploadFile = File(...),
    request: Request = None,
    db: Session = Depends(get_db)
):
    logger.debug("Received report request")
    ticket_service = TicketService(db)

    # Validate or create user
    user = None
    if user_id:
        user = ticket_service.get_user(user_id)
    if not user:
        # Create a guest user automatically
        guest_email = f"guest-{uuid.uuid4()}@example.local"
        guest_name = user_name or f"Guest-{str(uuid.uuid4())[:8]}"
        try:
            user = ticket_service.create_user(name=guest_name, email=guest_email)
            logger.info(f"Created guest user: {user}")
        except Exception as e:
            logger.exception("Failed to create guest user")
            raise HTTPException(status_code=500, detail="Failed to ensure user")

    logger.debug(f"Using user: {user.name} ({user.email})")

    # Validate file type
    allowed_extensions = {'.jpg', '.jpeg', '.png', '.gif', '.bmp', '.webp'}
    allowed_content_types = {
        'image/jpeg', 'image/png', 'image/gif', 'image/bmp', 'image/webp',
        'application/octet-stream'  # Some cameras/mobile devices use this
    }

    file_ext = Path(image.filename).suffix.lower()
    if file_ext not in allowed_extensions:
        logger.error(f"Invalid file extension: {file_ext}")
        raise HTTPException(status_code=400, detail="Only image files are allowed")

    if image.content_type not in allowed_content_types:
        logger.error(f"Invalid content type: {image.content_type}")
        raise HTTPException(status_code=400, detail="Invalid file type")

    # Save uploaded image
    filename = f"{uuid.uuid4()}{file_ext}"
    file_path_obj = UPLOAD_DIR / filename
    try:
        content = await image.read()
        file_path_obj.write_bytes(content)
        logger.debug(f"Saved image to {file_path_obj} ({len(content)} bytes)")
    except Exception as e:
        logger.exception("Failed to save uploaded image")
        raise HTTPException(status_code=500, detail="Failed to save uploaded image")

    # Get initialized AI service
    ai_service = get_ai_service()
    logger.debug("AI service ready")

    # Run AI predictions
    try:
        category = ai_service.classify_category(str(file_path_obj))
        logger.debug(f"Classification: {category}")

        if category.lower() == "pothole":
            severity_str, annotated_path = ai_service.detect_pothole_severity(str(file_path_obj))
            logger.debug(f"Detection: severity={severity_str}, path={annotated_path}")
            severity = {
                "High": SeverityLevel.HIGH,
                "Medium": SeverityLevel.MEDIUM,
                "Low": SeverityLevel.LOW,
                "Unknown": SeverityLevel.NA
            }.get(severity_str, SeverityLevel.NA)
        else:
            severity = SeverityLevel.NA
            logger.debug("No detection needed")
    except Exception as e:
        logger.exception("AI prediction failed")
        category = "Unknown"
        severity = SeverityLevel.NA

    # Create ticket (store relative posix path)
    image_path_db = file_path_obj.as_posix()
    ticket = ticket_service.create_ticket(
        user_id=user.id,
        image_path=image_path_db,
        category=category,
        severity=severity,
        latitude=latitude,
        longitude=longitude,
        description=description,
        address=address
    )
    logger.info(f"Ticket created: {ticket.id} for user {user.id}")

    # Normalize stored path and build absolute URL
    rel_path = normalize_image_path_for_url(ticket.image_path)
    image_url = make_image_url(rel_path, request)
    
    response = {
        "ticket_id": ticket.id,
        "id": ticket.id,
        "user_id": user.id,
        "user_name": user.name,
        "user_email": user.email,
        "category": ticket.category,
        "severity": ticket.severity.value,
        "status": ticket.status.value,
        "description": ticket.description,
        "image_path": rel_path,
        "image_url": image_url,
        "address": ticket.address
    }

    logger.debug(f"Response: {response}")
    return JSONResponse(status_code=201, content=response)

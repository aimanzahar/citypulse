from fastapi import APIRouter, UploadFile, File, Form, Depends, HTTPException
from fastapi.responses import JSONResponse
from sqlalchemy.orm import Session
from app.database import get_db
from app.services.ticket_service import TicketService, SeverityLevel
from app.models.ticket_model import User
from app.services.global_ai import get_ai_service
import os, uuid, logging

router = APIRouter()
logger = logging.getLogger(__name__)
logger.setLevel(logging.DEBUG)

UPLOAD_DIR = "app/static/uploads"
os.makedirs(UPLOAD_DIR, exist_ok=True)

@router.post("/report")
async def report_issue(
    user_id: str = Form(...),
    latitude: float = Form(...),
    longitude: float = Form(...),
    description: str = Form(""),
    image: UploadFile = File(...),
    db: Session = Depends(get_db)
):
    logger.debug("Received report request")
    ticket_service = TicketService(db)

    # Validate user
    user = db.query(User).filter(User.id == user_id).first()
    if not user:
        logger.error(f"User with id {user_id} not found")
        raise HTTPException(status_code=404, detail=f"User with id {user_id} not found")
    logger.debug(f"User found: {user.name} ({user.email})")

    # Save uploaded image
    file_ext = os.path.splitext(image.filename)[1]
    filename = f"{uuid.uuid4()}{file_ext}"
    file_path = os.path.join(UPLOAD_DIR, filename)
    try:
        content = await image.read()
        with open(file_path, "wb") as f:
            f.write(content)
        logger.debug(f"Saved image to {file_path} ({len(content)} bytes)")
    except Exception as e:
        logger.exception("Failed to save uploaded image")
        raise HTTPException(status_code=500, detail="Failed to save uploaded image")

    # Get initialized AI service
    ai_service = get_ai_service()
    logger.debug("AI service ready")

    # Run AI predictions
    try:
        category = ai_service.classify_category(file_path)
        logger.debug(f"Classification: {category}")

        if category.lower() == "pothole":
            severity_str, annotated_path = ai_service.detect_pothole_severity(file_path)
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

    # Create ticket
    ticket = ticket_service.create_ticket(
        user_id=user.id,
        image_path=file_path,
        category=category,
        severity=severity,
        latitude=latitude,
        longitude=longitude,
        description=description
    )
    logger.info(f"Ticket created: {ticket.id} for user {user.id}")

    response = {
        "ticket_id": ticket.id,
        "user_id": user.id,
        "user_name": user.name,
        "user_email": user.email,
        "category": ticket.category,
        "severity": ticket.severity.value,
        "status": ticket.status.value,
        "description": ticket.description,
        "image_path": ticket.image_path
    }

    logger.debug(f"Response: {response}")
    return JSONResponse(status_code=201, content=response)

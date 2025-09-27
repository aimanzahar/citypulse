from typing import Optional
from fastapi import APIRouter, UploadFile, File, Form, Depends, HTTPException, Request
from fastapi.responses import JSONResponse
from sqlalchemy.orm import Session
from pathlib import Path
import logging, uuid

from app.database import get_db
from app.services.ticket_service import TicketService, SeverityLevel
from app.models.ticket_model import User
from app.services.global_ai import get_ai_service
from app.utils import make_image_url, normalize_image_path_for_url

router = APIRouter()
logger = logging.getLogger(__name__)
logger.setLevel(logging.DEBUG)

UPLOAD_DIR = Path("static") / "uploads"
UPLOAD_DIR.mkdir(parents=True, exist_ok=True)

# ----------------------
# API 1: Analyze image (no DB write)
# ----------------------
@router.post("/analyze")
async def analyze_image(
    image: UploadFile = File(...),
    request: Request = None
):
    logger.debug("Received analyze request")

    # Validate file extension and type
    allowed_extensions = {'.jpg', '.jpeg', '.png', '.gif', '.bmp', '.webp'}
    allowed_content_types = {
        'image/jpeg', 'image/png', 'image/gif', 'image/bmp', 'image/webp',
        'application/octet-stream'
    }

    file_ext = Path(image.filename).suffix.lower()
    if file_ext not in allowed_extensions:
        raise HTTPException(status_code=400, detail="Only image files are allowed")
    if image.content_type not in allowed_content_types:
        raise HTTPException(status_code=400, detail="Invalid file type")

    # Save file
    filename = f"{uuid.uuid4()}{file_ext}"
    file_path_obj = UPLOAD_DIR / filename
    try:
        content = await image.read()
        file_path_obj.write_bytes(content)
        logger.debug(f"Saved image for analysis: {file_path_obj}")
    except Exception:
        logger.exception("Failed to save image for analysis")
        raise HTTPException(status_code=500, detail="Failed to save uploaded image")

    # Run AI
    ai_service = get_ai_service()
    try:
        category = ai_service.classify_category(str(file_path_obj))
        logger.debug(f"Classification result: {category}")

        severity = SeverityLevel.NA
        annotated_path = None
        if category.lower() == "pothole":
            severity_str, annotated_path = ai_service.detect_pothole_severity(str(file_path_obj))
            severity = {
                "High": SeverityLevel.HIGH,
                "Medium": SeverityLevel.MEDIUM,
                "Low": SeverityLevel.LOW,
                "Unknown": SeverityLevel.NA
            }.get(severity_str, SeverityLevel.NA)
            logger.debug(f"Severity detection: {severity_str}")
    except Exception:
        logger.exception("AI analysis failed")
        category = "Unknown"
        severity = SeverityLevel.NA

    rel_path = normalize_image_path_for_url(file_path_obj.as_posix())
    image_url = make_image_url(rel_path, request)

    response = {
        "temp_id": str(uuid.uuid4()),
        "filename": filename,
        "image_path": rel_path,
        "image_url": image_url,
        "category": category,
        "severity": severity.value
    }
    logger.debug(f"Analyze response: {response}")
    return JSONResponse(status_code=200, content=response)


# ----------------------
# API 2: Submit report (with analyzed file + DB write)
# ----------------------
@router.post("/report")
async def report_issue(
    user_id: Optional[str] = Form(None),
    user_name: Optional[str] = Form(None),
    latitude: float = Form(...),
    longitude: float = Form(...),
    address: Optional[str] = Form(None),
    description: str = Form(""),
    analyzed_file: str = Form(...),  # filename returned from /analyze
    category: str = Form(...),
    severity: str = Form(...),
    db: Session = Depends(get_db),
    request: Request = None
):
    logger.debug("Received report submission request")
    ticket_service = TicketService(db)

    # Ensure user
    user = None
    if user_id:
        user = ticket_service.get_user(user_id)
    if not user:
        guest_email = f"guest-{uuid.uuid4()}@example.local"
        guest_name = user_name or f"Guest-{str(uuid.uuid4())[:8]}"
        try:
            user = ticket_service.create_user(name=guest_name, email=guest_email)
            logger.info(f"Created guest user: {user}")
        except Exception:
            logger.exception("Failed to create guest user")
            raise HTTPException(status_code=500, detail="Failed to ensure user")

    # Verify analyzed file exists
    file_path_obj = UPLOAD_DIR / analyzed_file
    if not file_path_obj.exists():
        logger.error(f"Analyzed file not found: {analyzed_file}")
        raise HTTPException(status_code=400, detail="Analyzed file not found")

    # Save ticket
    severity_enum = SeverityLevel.__members__.get(severity.upper(), SeverityLevel.NA)
    try:
        ticket = ticket_service.create_ticket(
            user_id=user.id,
            image_path=file_path_obj.as_posix(),
            category=category,
            severity=severity_enum,
            latitude=latitude,
            longitude=longitude,
            description=description,
            address=address
        )
        logger.info(f"Ticket created: {ticket.id} for user {user.id}")
    except Exception:
        logger.exception("Failed to create ticket")
        raise HTTPException(status_code=500, detail="Failed to create ticket")

    rel_path = normalize_image_path_for_url(ticket.image_path)
    image_url = make_image_url(rel_path, request)

    response = {
        "ticket_id": ticket.id,
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
    logger.debug(f"Report response: {response}")
    return JSONResponse(status_code=201, content=response)

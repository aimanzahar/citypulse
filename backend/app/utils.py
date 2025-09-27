from typing import Optional
from pathlib import Path
import logging

logger = logging.getLogger(__name__)
logging.basicConfig(level=logging.INFO)

# Path where uploaded images are stored (relative to project root)
UPLOADS_DIR = Path("static") / "uploads"
# Resolved absolute path for safety checks
try:
    UPLOADS_DIR_RESOLVED = UPLOADS_DIR.resolve()
except Exception:
    UPLOADS_DIR_RESOLVED = UPLOADS_DIR

def normalize_image_path_for_url(image_path: Optional[str]) -> Optional[str]:
    """
    Normalize stored image_path to a web-accessible relative path under the /static/ mount.
    Examples:
        r"static\\uploads\\uuid.jpg" -> "static/uploads/uuid.jpg"
        "C:\\project\\static\\uploads\\uuid.jpg" -> "static/uploads/uuid.jpg"
        "uploads/uuid.jpg" -> "static/uploads/uuid.jpg"
    """
    if not image_path:
        return None

    p = str(image_path).replace("\\", "/")
    # strip leading './' and leading slashes
    while p.startswith("./"):
        p = p[2:]
    p = p.lstrip("/")

    # prefer existing 'static/' segment if present
    if "static/" in p:
        p = p[p.find("static/"):]
    elif p.startswith("uploads/"):
        p = f"static/{p}"
    else:
        # fallback to treating as filename only
        p = f"static/uploads/{Path(p).name}"

    # collapse accidental duplicates
    p = p.replace("static/static", "static").replace("uploads/uploads", "uploads")
    return p

def make_image_url(image_path: Optional[str], request) -> Optional[str]:
    """
    Build an absolute URL for the given stored image_path using the FastAPI request.
    Returns None if image_path is falsy.
    """
    rel = normalize_image_path_for_url(image_path)
    if not rel:
        return None
    base = str(request.base_url).rstrip("/")
    return f"{base}/{rel.lstrip('/')}"

def ticket_to_dict(ticket, request=None) -> dict:
    """
    Serialize a Ticket ORM object to the normalized schema expected by clients.

    Schema:
      id, category, severity, status, description,
      user_id, user_name, user_email,
      created_at (ISO8601), latitude, longitude, address,
      image_url (absolute), image_path (relative POSIX under static/)
    """
    created = None
    try:
        if getattr(ticket, "created_at", None):
            created = ticket.created_at.isoformat()
    except Exception:
        created = None

    # Normalize stored image path to a safe relative POSIX path under 'static/'
    normalized_path = normalize_image_path_for_url(getattr(ticket, "image_path", None))

    image_url = None
    if request is not None:
        try:
            image_url = make_image_url(normalized_path, request)
        except Exception:
            logger.exception("Failed to build image_url")
            image_url = None

    return {
        "id": ticket.id,
        "category": ticket.category,
        "severity": ticket.severity.value if getattr(ticket, "severity", None) else None,
        "status": ticket.status.value if getattr(ticket, "status", None) else None,
        "description": ticket.description,
        "user_id": ticket.user_id,
        "user_name": ticket.user.name if getattr(ticket, "user", None) else None,
        "user_email": ticket.user.email if getattr(ticket, "user", None) else None,
        "created_at": created,
        "latitude": ticket.latitude,
        "longitude": ticket.longitude,
        "address": ticket.address,
        "image_url": image_url,
        "image_path": normalized_path
    }
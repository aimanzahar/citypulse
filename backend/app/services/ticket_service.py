# app/services/ticket_service.py
import uuid
from typing import List, Optional
from pathlib import Path
from sqlalchemy.orm import Session
from sqlalchemy.exc import NoResultFound
from app.models.ticket_model import User, Ticket, TicketAudit, TicketStatus, SeverityLevel
from app.utils import normalize_image_path_for_url, UPLOADS_DIR_RESOLVED
import logging

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# ----------------------
# Ticket Service
# ----------------------
class TicketService:
    def __init__(self, db: Session):
        self.db = db

    # ------------------
    # User Operations
    # ------------------
    def create_user(self, name: str, email: str) -> User:
        user = User(name=name, email=email)
        self.db.add(user)
        self.db.commit()
        self.db.refresh(user)
        logger.info(f"Created user {user}")
        return user  # <-- return User object

    def get_user(self, user_id: str) -> Optional[User]:
        return self.db.query(User).filter(User.id == user_id).first()

    # ------------------
    # Ticket Operations
    # ------------------
    def create_ticket(
        self,
        user_id: str,
        image_path: str,
        category: str,
        severity: SeverityLevel,
        latitude: float,
        longitude: float,
        description: str = "",
        address: Optional[str] = None,
    ) -> Ticket:
        """
        Create a Ticket record.

        image_path should be a relative POSIX path (e.g. 'static/uploads/uuid.jpg').
        report.route uses Path.as_posix() to ensure forward slashes on save.
        """
        # Normalize stored path to POSIX
        image_path_posix = Path(str(image_path)).as_posix() if image_path else None

        ticket = Ticket(
            id=str(uuid.uuid4()),
            user_id=user_id,
            image_path=image_path_posix,
            category=category,
            severity=severity,
            latitude=latitude,
            longitude=longitude,
            description=description,
            address=address,
        )
        self.db.add(ticket)
        self.db.commit()
        self.db.refresh(ticket)
        logger.info(f"Created ticket {ticket}")
        return ticket

    def update_ticket_status(self, ticket_id: str, new_status: TicketStatus) -> Ticket:
        ticket = self.db.query(Ticket).filter(Ticket.id == ticket_id).first()
        if not ticket:
            raise NoResultFound(f"Ticket with id {ticket_id} not found")

        # Log audit
        audit = TicketAudit(
            ticket_id=ticket.id,
            old_status=ticket.status,
            new_status=new_status,
        )
        self.db.add(audit)

        # Update status
        ticket.status = new_status
        self.db.commit()
        self.db.refresh(ticket)
        logger.info(f"Updated ticket {ticket.id} status to {new_status}")
        return ticket

    def get_ticket(self, ticket_id: str) -> Optional[Ticket]:
        return self.db.query(Ticket).filter(Ticket.id == ticket_id).first()

    def list_tickets(
        self,
        user_id: Optional[str] = None,
        category: Optional[str] = None,
        severity: Optional[SeverityLevel] = None,
        status: Optional[TicketStatus] = None
    ) -> List[Ticket]:
        """
        Return tickets. By default returns all tickets unless optional filters are provided.
        """
        query = self.db.query(Ticket)
        if user_id:
            query = query.filter(Ticket.user_id == user_id)
        if category:
            query = query.filter(Ticket.category == category)
        if severity:
            query = query.filter(Ticket.severity == severity)
        if status:
            query = query.filter(Ticket.status == status)
        return query.order_by(Ticket.created_at.desc()).all()

    def delete_ticket(self, ticket_id: str) -> bool:
        """
        Delete a ticket and its associated image file if it exists.

        Safety:
        - Normalize stored image_path to a relative POSIX path under the static/ mount using
          normalize_image_path_for_url().
        - Resolve the resulting path and only delete if the resolved path is under the configured
          uploads directory (UPLOADS_DIR_RESOLVED) to prevent path traversal.
        """
        ticket = self.db.query(Ticket).filter(Ticket.id == ticket_id).first()
        if not ticket:
            raise NoResultFound(f"Ticket with id {ticket_id} not found")

        # Attempt to delete the image file if present
        try:
            rel = normalize_image_path_for_url(ticket.image_path)
            if rel:
                file_path = Path(rel)
                # Resolve to absolute path safely (works if file missing too)
                try:
                    absolute = file_path.resolve()
                except Exception:
                    absolute = (Path.cwd() / file_path).resolve()

                # Ensure the file is inside the uploads directory
                try:
                    absolute.relative_to(UPLOADS_DIR_RESOLVED)
                    inside_uploads = True
                except Exception:
                    inside_uploads = False

                if inside_uploads and absolute.exists():
                    try:
                        absolute.unlink()
                        logger.info(f"Deleted image file: {absolute}")
                    except Exception as e:
                        logger.warning(f"Failed to delete image file {absolute}: {e}")
                else:
                    logger.debug(f"Image file not deleted (missing or outside uploads): {absolute}")
        except Exception as e:
            logger.exception(f"Error while attempting to remove image for ticket {ticket_id}: {e}")

        # Delete ticket record
        try:
            self.db.delete(ticket)
            self.db.commit()
            logger.info(f"Deleted ticket {ticket_id}")
            return True
        except Exception as e:
            logger.exception(f"Failed to delete ticket {ticket_id} from DB: {e}")
            self.db.rollback()
            raise
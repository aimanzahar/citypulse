# app/services/ticket_service.py
import uuid
from typing import List, Optional
from sqlalchemy.orm import Session
from sqlalchemy.exc import NoResultFound
from app.models.ticket_model import User, Ticket, TicketAudit, TicketStatus, SeverityLevel
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
    ) -> Ticket:
        ticket = Ticket(
            id=str(uuid.uuid4()),
            user_id=user_id,
            image_path=image_path,
            category=category,
            severity=severity,
            latitude=latitude,
            longitude=longitude,
            description=description,
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

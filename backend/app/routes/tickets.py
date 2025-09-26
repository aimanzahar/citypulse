# app/routes/tickets.py
from typing import Optional, List
import logging
from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session
from app.database import get_db
from app.services.ticket_service import TicketService, TicketStatus, SeverityLevel
from pydantic import BaseModel

router = APIRouter()
logger = logging.getLogger(__name__)
logging.basicConfig(level=logging.INFO)

class TicketStatusUpdate(BaseModel):
    new_status: TicketStatus

# ----------------------
# GET /tickets
# ----------------------
@router.get("/tickets", response_model=List[dict])
def list_tickets(
    user_id: Optional[str] = Query(None, description="Filter by user ID"),
    category: Optional[str] = Query(None, description="Filter by category"),
    severity: Optional[SeverityLevel] = Query(None, description="Filter by severity"),
    status: Optional[TicketStatus] = Query(None, description="Filter by status"),
    db: Session = Depends(get_db)
):
    service = TicketService(db)
    tickets = service.list_tickets(user_id=user_id, category=category, severity=severity, status=status)
    return [
        {
            "ticket_id": t.id,
            "user_id": t.user_id,
            "category": t.category,
            "severity": t.severity.value,
            "status": t.status.value,
            "description": t.description,
            "latitude": t.latitude,
            "longitude": t.longitude,
            "image_path": t.image_path,
            "created_at": t.created_at,
            "updated_at": t.updated_at
        } for t in tickets
    ]

# ----------------------
# GET /tickets/{ticket_id}
# ----------------------
@router.get("/tickets/{ticket_id}", response_model=dict)
def get_ticket(ticket_id: str, db: Session = Depends(get_db)):
    service = TicketService(db)
    ticket = service.get_ticket(ticket_id)
    if not ticket:
        raise HTTPException(status_code=404, detail=f"Ticket {ticket_id} not found")
    return {
        "ticket_id": ticket.id,
        "user_id": ticket.user_id,
        "category": ticket.category,
        "severity": ticket.severity.value,
        "status": ticket.status.value,
        "description": ticket.description,
        "latitude": ticket.latitude,
        "longitude": ticket.longitude,
        "image_path": ticket.image_path,
        "created_at": ticket.created_at,
        "updated_at": ticket.updated_at
    }

# ----------------------
# PATCH /tickets/{ticket_id} - Update status
# ----------------------
@router.patch("/tickets/{ticket_id}", response_model=dict)
def update_ticket_status(
    ticket_id: str,
    status_update: TicketStatusUpdate,  # JSON body with new_status
    db: Session = Depends(get_db)
):
    service = TicketService(db)
    try:
        ticket = service.update_ticket_status(ticket_id, status_update.new_status)
    except Exception as e:
        logger.error(f"Failed to update ticket status: {e}")
        raise HTTPException(status_code=400, detail=str(e))
    return {
        "ticket_id": ticket.id,
        "user_id": ticket.user_id,
        "category": ticket.category,
        "severity": ticket.severity.value,
        "status": ticket.status.value,
        "description": ticket.description,
        "latitude": ticket.latitude,
        "longitude": ticket.longitude,
        "image_path": ticket.image_path,
        "created_at": ticket.created_at,
        "updated_at": ticket.updated_at
    }

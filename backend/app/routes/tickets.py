# app/routes/tickets.py
from typing import Optional, List
import logging
from fastapi import APIRouter, Depends, HTTPException, Query, Request
from sqlalchemy.orm import Session
from app.database import get_db
from app.services.ticket_service import TicketService, TicketStatus, SeverityLevel
from pydantic import BaseModel
from app.utils import ticket_to_dict

router = APIRouter()
logger = logging.getLogger(__name__)
logging.basicConfig(level=logging.INFO)

class TicketStatusUpdate(BaseModel):
    status: TicketStatus

# ----------------------
# GET /tickets
# ----------------------
@router.get("/tickets", response_model=List[dict])
def list_tickets(
    request: Request,
    user_id: Optional[str] = Query(None, description="Filter by user ID"),
    category: Optional[str] = Query(None, description="Filter by category"),
    severity: Optional[SeverityLevel] = Query(None, description="Filter by severity"),
    status: Optional[TicketStatus] = Query(None, description="Filter by status"),
    db: Session = Depends(get_db)
):
    """
    Return all tickets by default. Optional query params may filter results.
    Each item is serialized using ticket_to_dict(...) which guarantees:
      - image_url is an absolute forward-slash URL
      - created_at is ISO-8601 string
      - consistent schema for dashboard & mobile clients
    """
    service = TicketService(db)
    tickets = service.list_tickets(user_id=user_id, category=category, severity=severity, status=status)
    return [ticket_to_dict(t, request) for t in tickets]

# ----------------------
# GET /tickets/{ticket_id}
# ----------------------
@router.get("/tickets/{ticket_id}", response_model=dict)
def get_ticket(ticket_id: str, request: Request, db: Session = Depends(get_db)):
    service = TicketService(db)
    ticket = service.get_ticket(ticket_id)
    if not ticket:
        raise HTTPException(status_code=404, detail=f"Ticket {ticket_id} not found")
    return ticket_to_dict(ticket, request)

# ----------------------
# PATCH /tickets/{ticket_id}/status - Update status
# ----------------------
@router.patch("/tickets/{ticket_id}/status", response_model=dict)
def update_ticket_status(
    ticket_id: str,
    status_update: TicketStatusUpdate,  # JSON body with status
    request: Request,
    db: Session = Depends(get_db)
):
    service = TicketService(db)
    try:
        ticket = service.update_ticket_status(ticket_id, status_update.status)
    except Exception as e:
        logger.error(f"Failed to update ticket status: {e}")
        raise HTTPException(status_code=400, detail=str(e))
    return ticket_to_dict(ticket, request)

# ----------------------
# DELETE /tickets/{ticket_id} - Delete ticket + image
# ----------------------
@router.delete("/tickets/{ticket_id}", response_model=dict)
def delete_ticket(ticket_id: str, db: Session = Depends(get_db)):
    service = TicketService(db)
    try:
        service.delete_ticket(ticket_id)
    except Exception as e:
        logger.error(f"Failed to delete ticket {ticket_id}: {e}")
        raise HTTPException(status_code=400, detail=str(e))
    return {"deleted": True, "id": ticket_id}

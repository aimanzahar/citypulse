# app/routes/analytics.py
from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from sqlalchemy import func
from app.database import get_db
from app.models.ticket_model import Ticket, SeverityLevel, TicketStatus
from typing import Dict, Any

router = APIRouter()

# ----------------------
# GET /analytics
# ----------------------
@router.get("/analytics", response_model=Dict[str, Any])
def analytics(db: Session = Depends(get_db), cluster_size: float = 0.01):
    """
    Returns summary statistics for tickets:
    - Total tickets
    - Counts by category
    - Counts by severity
    - Counts by status
    - Optional: location clustering (hotspots) using grid-based approach
    """
    # Total tickets
    total_tickets = db.query(func.count(Ticket.id)).scalar()

    # Counts by category
    category_counts = dict(
        db.query(Ticket.category, func.count(Ticket.id))
          .group_by(Ticket.category)
          .all()
    )

    # Counts by severity
    severity_counts = dict(
        db.query(Ticket.severity, func.count(Ticket.id))
          .group_by(Ticket.severity)
          .all()
    )

    # Counts by status
    status_counts = dict(
        db.query(Ticket.status, func.count(Ticket.id))
          .group_by(Ticket.status)
          .all()
    )

    # ----------------------
    # Location Clustering
    # ----------------------
    # Simple grid-based clustering: round lat/lon to nearest cluster_size
    tickets = db.query(Ticket.latitude, Ticket.longitude).all()
    location_clusters: Dict[str, int] = {}
    for lat, lon in tickets:
        key = f"{round(lat/cluster_size)*cluster_size:.4f},{round(lon/cluster_size)*cluster_size:.4f}"
        location_clusters[key] = location_clusters.get(key, 0) + 1

    return {
        "total_tickets": total_tickets,
        "category_counts": category_counts,
        "severity_counts": {k.value: v for k, v in severity_counts.items()},
        "status_counts": {k.value: v for k, v in status_counts.items()},
        "location_clusters": location_clusters  # format: "lat,lon": count
    }

# app/routes/users.py
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from app.database import get_db
from app.services.ticket_service import TicketService
from app.models.ticket_model import User
from app.schemas.user_schema import UserCreate  # import schema

router = APIRouter()

@router.post("/users")
def create_user(user: UserCreate, db: Session = Depends(get_db)):
    service = TicketService(db)
    existing_user = db.query(User).filter(User.email == user.email).first()
    if existing_user:
        raise HTTPException(status_code=400, detail="User with this email already exists")
    new_user = service.create_user(user.name, user.email)
    return {"id": new_user.id, "name": new_user.name, "email": new_user.email}

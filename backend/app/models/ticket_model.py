import uuid
from sqlalchemy import Column, String, Float, Enum, DateTime, ForeignKey, Index
from sqlalchemy.orm import relationship
from sqlalchemy.sql import func
from app.database import Base
import enum

# ----------------------
# Enums
# ----------------------
class TicketStatus(str, enum.Enum):
    NEW = "New"
    IN_PROGRESS = "In Progress"
    FIXED = "Fixed"

class SeverityLevel(str, enum.Enum):
    LOW = "Low"
    MEDIUM = "Medium"
    HIGH = "High"
    NA = "N/A"

# ----------------------
# User Model
# ----------------------
class User(Base):
    __tablename__ = "users"

    id = Column(String, primary_key=True, default=lambda: str(uuid.uuid4()), index=True)
    name = Column(String, nullable=False)
    email = Column(String, unique=True, nullable=False)

    tickets = relationship("Ticket", back_populates="user", cascade="all, delete-orphan")

    def __repr__(self):
        return f"<User(id={self.id}, name={self.name}, email={self.email})>"

# ----------------------
# Ticket Model
# ----------------------
class Ticket(Base):
    __tablename__ = "tickets"

    id = Column(String, primary_key=True, default=lambda: str(uuid.uuid4()), index=True)
    user_id = Column(String, ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    image_path = Column(String, nullable=False)
    category = Column(String, nullable=False)
    severity = Column(Enum(SeverityLevel), nullable=False, default=SeverityLevel.NA)
    description = Column(String, default="")
    address = Column(String, nullable=True)
    status = Column(Enum(TicketStatus), nullable=False, default=TicketStatus.NEW)
    latitude = Column(Float, nullable=False)
    longitude = Column(Float, nullable=False)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now())

    user = relationship("User", back_populates="tickets")

    __table_args__ = (
        Index("idx_category_status", "category", "status"),
    )

    def __repr__(self):
        return f"<Ticket(id={self.id}, category={self.category}, severity={self.severity}, status={self.status}, user_id={self.user_id})>"

# ----------------------
# Ticket Audit Model
# ----------------------
class TicketAudit(Base):
    __tablename__ = "ticket_audit"

    id = Column(String, primary_key=True, default=lambda: str(uuid.uuid4()))
    ticket_id = Column(String, ForeignKey("tickets.id", ondelete="CASCADE"))
    old_status = Column(Enum(TicketStatus))
    new_status = Column(Enum(TicketStatus))
    updated_at = Column(DateTime(timezone=True), server_default=func.now())

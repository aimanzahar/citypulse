import os
import logging
from contextlib import asynccontextmanager
from fastapi import FastAPI
from fastapi.staticfiles import StaticFiles
from app.database import Base, engine
from app.routes import report, tickets, analytics, users
from app.services.global_ai import init_ai_service

logging.basicConfig(level=logging.DEBUG)
logger = logging.getLogger(__name__)

# ----------------------
# Lifespan context for startup/shutdown
# ----------------------
@asynccontextmanager
async def lifespan(app: FastAPI):
    logger.info("Starting FixMate Backend...")
    init_ai_service()  # ✅ Models load once here
    logger.info("AI models loaded successfully.")
    yield
    logger.info("FixMate Backend shutting down...")

# ----------------------
# Initialize FastAPI
# ----------------------
app = FastAPI(
    title="FixMate Backend API",
    description="Backend for FixMate Hackathon Prototype",
    version="1.0.0",
    lifespan=lifespan
)

# ----------------------
# Initialize DB
# ----------------------
Base.metadata.create_all(bind=engine)
logger.info("Database initialized.")

# ----------------------
# Static files
# ----------------------
UPLOAD_DIR = "static/uploads"
os.makedirs(UPLOAD_DIR, exist_ok=True)
app.mount("/static", StaticFiles(directory="static"), name="static")

# ----------------------
# Include routers
# ----------------------
try:
    app.include_router(report.router, prefix="/api", tags=["Report"])
    app.include_router(tickets.router, prefix="/api", tags=["Tickets"])
    app.include_router(analytics.router, prefix="/api", tags=["Analytics"])
    app.include_router(users.router, prefix="/api", tags=["Users"])
    print("✅ All routers included successfully")
except Exception as e:
    print(f"❌ Error including routers: {e}")
    import traceback
    traceback.print_exc()

@app.get("/")
def root():
    return {"message": "Welcome to FixMate Backend API! Visit /docs for API documentation."}

print("✅ FastAPI server setup complete")

# Start the server when running this script directly
if __name__ == "__main__":
    import uvicorn
    print("🚀 Starting server on http://127.0.0.1:8000")
    print("📚 API documentation available at http://127.0.0.1:8000/docs")
    uvicorn.run(app, host="127.0.0.1", port=8000)

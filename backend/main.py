import os
import logging
from contextlib import asynccontextmanager
from fastapi import FastAPI
from fastapi.staticfiles import StaticFiles
from fastapi.middleware.cors import CORSMiddleware
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
# CORS - allow dashboard & emulator origins
# ----------------------
DEFAULT_ORIGINS = "http://localhost:3000,http://127.0.0.1:3000,http://10.0.2.2:3000,http://192.168.100.59:3000"
origins_env = os.environ.get("FIXMATE_CORS_ORIGINS", DEFAULT_ORIGINS)
allowed_origins = [o.strip() for o in origins_env.split(",") if o.strip()]
# Ensure common development origins are always allowed (localhost, emulator, LAN)
for origin in ("http://localhost:3000", "http://127.0.0.1:3000", "http://10.0.2.2:3000", "http://192.168.100.59:3000"):
    if origin not in allowed_origins:
        allowed_origins.append(origin)

app.add_middleware(
    CORSMiddleware,
    allow_origins=allowed_origins,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

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
    print("🚀 Starting server on http://0.0.0.0:8000")
    print("📚 API documentation available at http://127.0.0.1:8000/docs")
    print("🔗 Also accessible from mobile/emulator at http://192.168.100.59:8000")
    uvicorn.run(app, host="0.0.0.0", port=8000)

# 🏗️ CityPulse - Smart Citizen-Driven Urban Maintenance Platform

CityPulse is a comprehensive citizen reporting application that combines **Flutter frontend** with **Python FastAPI backend** and **AI-powered image classification**. Users can capture urban issues (potholes, broken streetlights, trash, etc.), get automatic AI classification, and track their reports through a complete management system.

## 🎯 System Architecture

### Frontend (Flutter)
- **Location**: Root directory
- **Technology**: Flutter (Dart) with Material Design
- **Purpose**: Cross-platform mobile and web interface for citizens
- **Features**: Camera integration, GPS location, map visualization, bilingual support (EN/BM)

### Backend (Python FastAPI)
- **Location**: `backend/` directory
- **Technology**: Python FastAPI with SQLAlchemy + SQLite
- **Purpose**: RESTful API server with AI-powered image classification
- **Features**: YOLO-based object detection, severity classification, ticket management

### Data Flow
```
User takes photo → Flutter App → FastAPI Backend → AI Analysis → Database
      ↓                    ↓              ↓            ↓             ↓
   Reports List ←────── API Calls ←─── HTTP/REST ──→ YOLO Model ─→ SQLite
```

## 🚀 Quick Start Guide

### Prerequisites
- **Flutter SDK** 3.8.1+ ([Install Guide](https://docs.flutter.dev/get-started/install))
- **Python** 3.11+ ([Install Guide](https://python.org/downloads/))
- **Git** for version control

### 1. Clone and Setup
```bash
git clone <your-repo-url>
cd fixmate-frontend
```

### 2. Install Flutter Dependencies
```bash
flutter pub get
```

### 3. Setup Backend
```bash
cd backend
pip install -r requirements.txt
```

### 4. Start Backend Server (Terminal 1)
```bash
cd backend
python main.py
```
✅ Backend will run on: `http://127.0.0.1:8000`

### 5. Start Flutter App (Terminal 2)
```bash
# Navigate back to project root
cd ..

# Start Flutter app (choose your target)
flutter run                    # Mobile (Android/iOS)
# OR
flutter run -d chrome          # Web (Chrome)
# OR
flutter run -d web-server      # Web Server
```

## 🔧 Alternative Startup Methods

### Method A: Backend Only
```bash
cd backend
python main.py
```

### Method B: Using Uvicorn (Alternative)
```bash
cd backend
uvicorn main:app --host 127.0.0.1 --port 8000 --reload
```

### Method C: Flutter Web (Web Version)
```bash
flutter run -d chrome  # or firefox, edge
```

### Method D: Development Mode (Hot Reload)
```bash
# Terminal 1 - Backend with auto-reload
cd backend
uvicorn main:app --reload

# Terminal 2 - Flutter with hot reload
flutter run
```

### Method E: Dashboard Access (Web Interface)
```bash
# Terminal 1 - Start Backend Server
cd backend
python main.py
# OR (if port conflicts occur):
uvicorn main:app --host 127.0.0.1 --port 8000 --reload

# Terminal 2 - Start Dashboard Server
cd dashboard
python -m http.server 3000

# Open browser and navigate to:
# http://localhost:3000
```

**Dashboard Features:**
- 🗺️ Interactive map with report visualization
- 🔍 Advanced filtering by category, severity, status, and date
- 📊 Real-time statistics and analytics
- 🌡️ Heatmap toggle for density visualization
- 🔄 Status management (submitted → in_progress → fixed)
- 📱 Responsive design for desktop and mobile
- 🌍 Bilingual support (English/Bahasa Malaysia)

**Troubleshooting Dashboard:**
- **Port 8000 in use?** Try: `uvicorn main:app --host 127.0.0.1 --port 8080 --reload` (then update dashboard to use port 8080)
- **Port 3000 in use?** Try: `python -m http.server 3001`
- **Backend connection fails?** Dashboard will automatically use demo data
- **CORS issues?** Ensure backend allows requests from `http://localhost:3000`

## 📱 API Endpoints

The Flutter app communicates with these backend endpoints:

| Endpoint | Method | Purpose |
|----------|--------|---------|
| `/api/tickets` | GET | Fetch all reports |
| `/api/report` | POST | Submit new report with image |
| `/api/tickets/{id}` | GET | Get specific report |
| `/api/tickets/{id}` | PATCH | Update report status |
| `/api/analytics` | GET | Get dashboard analytics |
| `/api/users` | POST | Create user account |

### API Documentation
View interactive API documentation at: `http://127.0.0.1:8000/docs`

---

## 🎮 Features Overview

### Flutter Frontend Features
- ✅ **Report Flow**: Camera/gallery photo capture with GPS location
- ✅ **AI Classification**: Automatic issue type and severity detection
- ✅ **Map View**: Interactive OpenStreetMap with clustering and filtering
- ✅ **Report Management**: View, edit, and track report status
- ✅ **Bilingual Support**: English and Bahasa Malaysia
- ✅ **Settings**: Language toggle and data management

### Backend AI Features
- ✅ **YOLO Object Detection**: Detects urban issues from images
- ✅ **Severity Classification**: ML model assesses issue severity
- ✅ **SQLite Database**: Local data storage with full CRUD operations
- ✅ **RESTful API**: Complete API for mobile app integration
- ✅ **File Upload**: Image storage and processing

## 📁 Project Structure

### Frontend (Flutter)
```
lib/
├── app.dart                    # Main app widget and routing
├── main.dart                   # App entry point
├── models/
│   ├── report.dart            # Report data model
│   └── enums.dart             # Category, severity, status enums
├── screens/
│   ├── report_flow/           # Photo capture flow
│   ├── map/                   # Map visualization screen
│   ├── my_reports/            # User reports management
│   └── settings/              # App settings
├── services/
│   ├── api_service.dart       # Backend API communication
│   ├── storage.dart           # Local data storage
│   ├── location_service.dart  # GPS location services
│   └── mock_ai.dart           # AI classification logic
├── theme/
│   └── themes.dart            # App theming
├── widgets/                   # Reusable UI components
└── l10n/                      # Internationalization
```

### Backend (Python)
```
backend/
├── main.py                    # FastAPI server entry point
├── requirements.txt           # Python dependencies
├── app/
│   ├── database.py           # SQLite database setup
│   ├── models/               # Database models
│   ├── routes/               # API route handlers
│   ├── services/             # Business logic and AI services
│   ├── schemas/              # Pydantic data models
│   └── static/uploads/       # Image storage
└── test/                     # Test files and utilities
```

## 🛠️ Technology Stack

### Frontend Technology Stack
- **Flutter**: 3.8.1+ with Material Design
- **Key Packages**:
  - `flutter_map` + `flutter_map_marker_cluster` (Interactive maps)
  - `geolocator` (GPS location services)
  - `image_picker` (Camera integration)
  - `http` (API communication)
  - `provider` (State management)
  - `shared_preferences` (Local storage)

### Backend Technology Stack
- **FastAPI**: 0.117.1+ (Modern Python web framework)
- **SQLAlchemy**: 2.0.43+ (ORM for database operations)
- **PyTorch**: 2.8.0+ (Machine learning framework)
- **Ultralytics YOLO**: 8.3.203+ (Object detection)
- **SQLite**: Local database for data persistence

### AI Models
- **Object Detection**: YOLOv12n for issue identification
- **Severity Classification**: Custom PyTorch model
- **Model Storage**: `backend/app/models/` directory

## 🛠️ Troubleshooting

### Backend Issues

**Port 8000 already in use:**
```bash
# Windows
netstat -ano | findstr :8000
taskkill /F /IM python.exe

# Alternative: Kill specific process
Get-Process -Name python | Stop-Process -Force
```

**Missing dependencies:**
```bash
cd backend
pip install -r requirements.txt
pip install python-multipart pydantic[email]
```

**Backend not starting:**
```bash
# Test if modules can be imported
cd backend
python -c "import main; print('Import successful')"
```

### Frontend Issues

**Flutter dependencies:**
```bash
flutter clean
flutter pub get
```

**Device connection issues:**
```bash
flutter devices  # List connected devices
flutter doctor   # Check Flutter installation
```

**Web-specific issues:**
```bash
flutter config --enable-web
```

### Common Issues

**"Connection refused" errors:**
- Ensure backend server is running on port 8000
- Check firewall settings
- Verify API base URL in `lib/services/api_service.dart`
- For dashboard: Check browser console for CORS errors

**Camera/Geolocation not working:**
- Grant permissions in device settings
- Use HTTPS for web deployment
- Check browser permissions

**Slow AI processing:**
- First startup downloads ML models (may take time)
- Consider using CPU-only builds for faster startup
- Check available memory

## 🧪 Testing & Development

### Backend Testing
```bash
cd backend
python -m pytest test/  # Run all tests
python test/check_torch.py  # Verify PyTorch setup
```

### Flutter Testing
```bash
flutter test              # Run unit tests
flutter test --coverage   # With coverage report
```

### Database Management
```bash
cd backend
python -c "from app.database import engine; print('Database file:', engine.url.database)"
# Database file: backend/app/db/fixmate.db
```

## 📊 Performance Considerations

### Backend Performance
- **First Startup**: ML models download (~200MB) - may take several minutes
- **Memory Usage**: PyTorch models require significant RAM
- **CPU vs GPU**: CPU-only builds available for compatibility
- **Database**: SQLite suitable for small-scale deployments

### Frontend Performance
- **Image Processing**: Images compressed before upload
- **Map Rendering**: Clustering optimizes marker display
- **Caching**: Local storage for offline functionality

## 🚀 Production Deployment

### Backend Deployment
```bash
cd backend
# Production server
uvicorn main:app --host 0.0.0.0 --port 8000 --workers 4

# Or with Gunicorn
gunicorn main:app -w 4 -k uvicorn.workers.UvicornWorker
```

### Flutter Deployment
```bash
# Build for production
flutter build apk --release      # Android
flutter build ios --release      # iOS
flutter build web --release      # Web

# Build for specific targets
flutter build appbundle          # Android App Bundle
flutter build ipa               # iOS Archive
```

## 📚 Key Files Reference

### Essential Flutter Files
- `lib/main.dart` - App entry point
- `lib/app.dart` - Main app widget and navigation
- `lib/services/api_service.dart` - Backend communication
- `lib/models/report.dart` - Data models
- `pubspec.yaml` - Flutter dependencies

### Essential Backend Files
- `backend/main.py` - FastAPI server
- `backend/app/database.py` - Database configuration
- `backend/app/routes/tickets.py` - Ticket API endpoints
- `backend/app/services/ai_service.py` - AI classification logic
- `backend/requirements.txt` - Python dependencies

## 🎯 Future Enhancements

### Planned Features
- [ ] Real-time notifications for status updates
- [ ] Advanced filtering and search capabilities
- [ ] User authentication and profiles
- [ ] Admin dashboard for report management
- [ ] Push notifications for mobile
- [ ] Offline mode with sync capabilities
- [ ] Multi-language support expansion
- [ ] Analytics and reporting dashboard

### Technical Improvements
- [ ] Database optimization for large datasets
- [ ] Caching layer implementation
- [ ] API rate limiting
- [ ] Image compression optimization
- [ ] Background processing for AI tasks
- [ ] Monitoring and logging enhancement

## 📄 License & Acknowledgments

### License
- Placeholder: Add appropriate license for your project

### Acknowledgments
- **OpenStreetMap** - Map data and tile services
- **Leaflet** - Interactive mapping library
- **Flutter Community** - Dart packages and plugins
- **Ultralytics** - YOLO implementation
- **PyTorch** - Machine learning framework
- **FastAPI** - Modern Python web framework

### References
1. [Flutter Documentation](https://docs.flutter.dev/)
2. [FastAPI Documentation](https://fastapi.tiangolo.com/)
3. [YOLOv12 Implementation](https://github.com/ultralytics/ultralytics)
4. [PyTorch Models](https://pytorch.org/)

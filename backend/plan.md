Perfect 👍 Before I drop a full codebase, let’s agree on the **flow + plan** so you (and your team) know exactly how things connect. This will also make sure the code I give matches your hackathon goals.

---

# ⚡ Backend Flow (CityPulse Local Prototype)

### 1. Citizen Upload Flow

1. **Citizen uses frontend** (simple React, Streamlit, or Swagger UI for now).
2. Submits:

   * Photo (issue picture).
   * GPS location (lat/lng) (either auto from frontend or manually typed for demo).
   * Optional notes.
3. Backend endpoint: `POST /report`

   * Saves photo → `./app/static/uploads/`
   * Runs **AI classification** (via YOLOv8 model from Hugging Face).
   * Runs **severity logic** (based on bounding box size / confidence).
   * Generates **ticket record** in DB.
   * Returns JSON: `{id, category, severity, status, description}`

---

### 2. AI Model Flow

* First time backend runs:

  * Check if `models/` folder exists. If not, create it.
  * Use **`hf_hub_download`** to fetch YOLOv8n weights into `./models/`.
  * Load the model from that path with `ultralytics.YOLO`.
* Every report:

  * Pass image to model → detect objects.
  * Map objects to CityPulse categories (`pothole`, `streetlight`, `trash`, `signage`).
  * Apply **severity scoring** (e.g. bounding box area = High if > certain %).
* If model fails (no internet, missing weights):

  * Use fallback heuristic (OpenCV contour/brightness detection).

---

### 3. Ticket Lifecycle Flow

* Ticket schema:

  ```
  id, image_path, category, severity, location, description, status, timestamps
  ```
* Default status = `"New"`.
* Admin dashboard endpoints:

  * `GET /tickets` → list all tickets.
  * `GET /tickets/{id}` → fetch ticket details.
  * `PATCH /tickets/{id}` → update status (`In Progress`, `Fixed`).
* Citizens can query:

  * `GET /status/{id}` → see ticket’s status.

---

### 4. Dashboard & Analytics Flow

* Admin UI (or Swagger demo) calls:

  * `/tickets` → display list or map markers.
  * `/analytics` → simple stats:

    * Total tickets.
    * Counts by category & severity.
    * (Optional) Location clustering for hotspots.

---

# 🛠️ Development Plan

### Step 1 – Environment & Repo

* Conda or venv, install dependencies (FastAPI, SQLAlchemy, ultralytics, huggingface\_hub).
* Initialize Git repo with `.gitignore`, `requirements.txt`.

### Step 2 – Database & Models

* SQLite with SQLAlchemy ORM.
* `Ticket` model with enum fields for severity + status.

### Step 3 – AI Service

* `ai_service.py` handles:

  * Ensure `models/` exists.
  * Download YOLOv8 from Hugging Face into `./models/`.
  * Load model.
  * `detect_issue(image_path)` returns `{category, severity, confidence}`.

### Step 4 – Ticket Service

* Saves image locally.
* Calls `ai_service.detect_issue()`.
* Creates DB record.

### Step 5 – API Routes

* `/report` → citizen upload.
* `/tickets` → list all tickets.
* `/tickets/{id}` → fetch ticket.
* `/tickets/{id}` PATCH → update status.
* `/analytics` → summary stats.

### Step 6 – Demo Prep

* Populate DB with some sample tickets.
* Upload a few pothole/streetlight images → verify classification.
* Test via Swagger UI at [http://127.0.0.1:8000/docs](http://127.0.0.1:8000/docs).

---

✅ With this flow, you’ll have a **complete hackathon backend** that:

* Works offline after first model download.
* Saves everything locally (SQLite + images).
* Provides APIs ready for a frontend dashboard.

---

👉 Do you want me to now **rewrite the backend code** with this Hugging Face + `models/` folder integration (full project files), so you can just copy-paste into your repo and run?

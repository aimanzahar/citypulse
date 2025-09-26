Perfect 👍 thanks for clarifying — let’s keep it **venv only**. I’ll adjust the README so your teammates can just follow **one clean workflow** with `python -m venv`.

---

# 🛠️ FixMate Backend – Hackathon Prototype

Smart citizen-driven urban maintenance platform powered by **Computer Vision + Generative AI**.
This backend runs fully **locally** (no cloud required).

---

## 🚀 Features

* Citizen submits an image of an issue (pothole, streetlight, trash, signage).
* AI auto-classifies the issue + assigns severity.
* Ticket saved in local SQLite DB.
* API endpoints for citizens (report/status) and admins (tickets/analytics).
* Supports both **CPU-only** (safe) and **GPU-accelerated** (NVIDIA CUDA).

---

## 📦 Requirements

* Python **3.11+** (works on 3.8–3.12)
* `venv` for virtual environment
* (Optional) NVIDIA GPU with CUDA 11.8 or 12.1 drivers

---

## ⚙️ Setup Instructions

### 1. Clone repository

```bash
git clone https://github.com/yourteam/fixmate-backend.git
cd fixmate-backend
```

### 2. Create & activate virtual environment

```bash
python -m venv venv
```

**Windows (PowerShell):**

```bash
venv\Scripts\activate
```

**Linux/macOS:**

```bash
source venv/bin/activate
```

---

### 3. Install dependencies

#### Option A – CPU only (safe for all laptops)

```bash
pip install -r requirements.txt
pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cpu
```

#### Option B – GPU (if you have NVIDIA + CUDA)

Check your driver version:

```bash
nvidia-smi
```

* If CUDA 12.1:

```bash
pip install -r requirements.txt
pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu121
```

* If CUDA 11.8:

```bash
pip install -r requirements.txt
pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu118
```

---

## 🧪 Verify Setup

Run the PyTorch check script:

```bash
python Backend/test/check_torch.py
```

Expected output:

* CPU build:

  ```
  🔥 PyTorch version: 2.8.0+cpu
  🖥️ CUDA available: False
  ```
* GPU build:

  ```
  🔥 PyTorch version: 2.8.0
  🖥️ CUDA available: True
   -> GPU name: NVIDIA GeForce RTX 3060
  ```

---

## ▶️ Run Backend Server

```bash
uvicorn app.main:app --reload
```

Open Swagger API docs at:
👉 [http://127.0.0.1:8000/docs](http://127.0.0.1:8000/docs)

---

## 📷 Test ML Detection

Run detection test on a sample image:

```bash
python Backend/test/test_detect.py --image ./test_images/pothole.jpg
```

Outputs:

* If YOLO model works → JSON with detections.
* If fallback → Heuristic result (pothole-like / dark-image).

---

## 📂 Project Structure

```
fixmate-backend/
│── README.md
│── requirements.txt
│── models/                # YOLO weights (downloaded here)
│── data/                  # SQLite DB + sample images
│── app/
│    ├── main.py           # FastAPI entrypoint
│    ├── models.py         # SQLAlchemy models
│    ├── schemas.py        # Pydantic schemas
│    ├── database.py       # DB connection (SQLite)
│    ├── routes/           # API routes
│    └── services/         # AI + ticket logic
│── Backend/test/
│    ├── check_torch.py    # Verify torch GPU/CPU
│    └── test_detect.py    # Run YOLO/heuristic on image
```

---

## 👥 Team Notes

* First run may take time (downloads YOLO weights into `./models/`).
* Keep everything local (SQLite + images) for hackathon.
* If no GPU available, always use CPU build.

---

# References
1) https://pyimagesearch.com/2025/07/21/training-yolov12-for-detecting-pothole-severity-using-a-custom-dataset/?utm_source=chatgpt.com
2) https://universe.roboflow.com/aegis/pothole-detection-i00zy/dataset/2#

👉 Do you want me to now also generate the **`requirements.txt`** file that matches this README so you don’t have to guess the dependencies?




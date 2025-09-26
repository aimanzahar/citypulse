import os
import zipfile
import shutil
import random
from pathlib import Path
import requests

# ---------- CONFIG ----------
BASE_DIR = Path("dataset")
DOWNLOAD_DIR = Path("downloads")
CLASS_NAME = "streetlight"
TRAIN_SPLIT = 0.8  # 80% train, 20% val

os.makedirs(BASE_DIR / "train" / CLASS_NAME, exist_ok=True)
os.makedirs(BASE_DIR / "val" / CLASS_NAME, exist_ok=True)
os.makedirs(DOWNLOAD_DIR, exist_ok=True)

def download_from_github(url: str, out_path: Path):
    print(f"⬇️ Trying download: {url}")
    resp = requests.get(url, stream=True)
    if resp.status_code != 200:
        print(f"❌ Download failed: status code {resp.status_code}")
        return False
    with open(out_path, "wb") as f:
        for chunk in resp.iter_content(8192):
            f.write(chunk)
    print(f"✅ Downloaded to {out_path}")
    return True

def unzip_and_split(zip_path: Path, class_name: str):
    extract_path = Path("tmp_extract")
    with zipfile.ZipFile(zip_path, 'r') as zip_ref:
        zip_ref.extractall(extract_path)

    all_images = list(extract_path.rglob("*.jpg")) + list(extract_path.rglob("*.png")) + list(extract_path.rglob("*.jpeg"))
    if not all_images:
        print("⚠️ No images in extracted folder.")
        return

    random.shuffle(all_images)
    split_idx = int(len(all_images) * TRAIN_SPLIT)
    train = all_images[:split_idx]
    val = all_images[split_idx:]

    for img in train:
        shutil.move(str(img), BASE_DIR / "train" / class_name / img.name)
    for img in val:
        shutil.move(str(img), BASE_DIR / "val" / class_name / img.name)

    shutil.rmtree(extract_path)
    print(f"✅ {class_name} split: {len(train)} train / {len(val)} val")

if __name__ == "__main__":
    # Try the GitHub repo from the paper
    streetlight_url = "https://github.com/Team16Project/Street-Light-Dataset/archive/refs/heads/main.zip"
    zip_path = DOWNLOAD_DIR / "streetlight_dataset.zip"

    ok = download_from_github(streetlight_url, zip_path)
    if ok:
        unzip_and_split(zip_path, CLASS_NAME)
    else:
        print("⚠️ Could not download streetlight dataset. You may need to find alternative source.")

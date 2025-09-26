import os
import zipfile
import shutil
import random
import json
from pathlib import Path

# ---------- CONFIG ----------
BASE_DIR = Path("dataset")
DOWNLOAD_DIR = Path("downloads")
CLASSES = ["pothole", "streetlight", "garbage", "signage"]
TRAIN_SPLIT = 0.8  # 80% train, 20% val

os.makedirs(BASE_DIR, exist_ok=True)
os.makedirs(DOWNLOAD_DIR, exist_ok=True)

# Create folder structure
for split in ["train", "val"]:
    for cls in CLASSES:
        os.makedirs(BASE_DIR / split / cls, exist_ok=True)

# ---------- AUTHENTICATION ----------
def setup_kaggle_api():
    """Load kaggle.json and set environment variables"""
    kaggle_path = Path("kaggle.json")  # put kaggle.json in the same folder as this script
    if not kaggle_path.exists():
        raise FileNotFoundError("❌ kaggle.json not found! Download it from https://www.kaggle.com/settings")
    
    with open(kaggle_path, "r") as f:
        creds = json.load(f)
    
    os.environ["KAGGLE_USERNAME"] = creds["username"]
    os.environ["KAGGLE_KEY"] = creds["key"]
    print("✅ Kaggle API credentials loaded.")

# ---------- HELPERS ----------
def unzip_and_move(zip_path, class_name):
    """Unzip dataset and put images into dataset/train/ & val/ folders"""
    extract_path = Path("tmp_extract")
    with zipfile.ZipFile(zip_path, 'r') as zip_ref:
        zip_ref.extractall(extract_path)

    # Collect images
    all_images = list(extract_path.rglob("*.jpg")) + list(extract_path.rglob("*.png")) + list(extract_path.rglob("*.jpeg"))
    random.shuffle(all_images)

    # Train/Val split
    split_idx = int(len(all_images) * TRAIN_SPLIT)
    train_files = all_images[:split_idx]
    val_files = all_images[split_idx:]

    for img in train_files:
        target = BASE_DIR / "train" / class_name / img.name
        shutil.move(str(img), target)

    for img in val_files:
        target = BASE_DIR / "val" / class_name / img.name
        shutil.move(str(img), target)

    shutil.rmtree(extract_path)

def kaggle_download(dataset_slug, out_zip):
    """Download Kaggle dataset into downloads/ folder"""
    os.system(f'kaggle datasets download -d {dataset_slug} -p {DOWNLOAD_DIR} -o')
    return DOWNLOAD_DIR / out_zip

# ---------- MAIN ----------
if __name__ == "__main__":
    setup_kaggle_api()

    # Pothole dataset
    pothole_zip = kaggle_download("andrewmvd/pothole-detection", "pothole-detection.zip")
    unzip_and_move(pothole_zip, "pothole")

    # Garbage dataset
    garbage_zip = kaggle_download("dataclusterlabs/domestic-trash-garbage-dataset", "domestic-trash-garbage-dataset.zip")
    unzip_and_move(garbage_zip, "garbage")

    # TrashNet (alternative garbage dataset)
    trashnet_zip = kaggle_download("techsash/waste-classification-data", "waste-classification-data.zip")
    unzip_and_move(trashnet_zip, "garbage")

    # Signage dataset
    signage_zip = kaggle_download("ahemateja19bec1025/traffic-sign-dataset-classification", "traffic-sign-dataset-classification.zip")
    unzip_and_move(signage_zip, "signage")  # Combine all sign classes into one

    #Drainage dataset (⚠️ still missing)
    print("⚠️ No Kaggle dataset found for drainage. Please add manually to dataset/train/drainage & val/drainage.")
    # Streetlight dataset (⚠️ still missing)
    print("⚠️ No Kaggle dataset found for streetlights. Please add manually to dataset/train/streetlight & val/streetlight.")

    print("✅ All datasets downloaded, cleaned, and organized into 'dataset/'")

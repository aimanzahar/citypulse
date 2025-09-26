import os
import shutil
import random
from pathlib import Path

# ---------- CONFIG ----------
SRC_DIR = Path("dataset_downloads")  # where new images are
DST_DIR = Path("dataset")            # your main dataset folder
TRAIN_SPLIT = 0.8                    # 80% train, 20% val

# Classes to process
NEW_CLASSES = ["broken streetlight", "drainage"]

for cls in NEW_CLASSES:
    src_class_dir = SRC_DIR / cls
    if not src_class_dir.exists():
        print(f"⚠️ Source folder not found: {src_class_dir}")
        continue

    # Prepare destination folders
    train_dest = DST_DIR / "train" / cls
    val_dest = DST_DIR / "val" / cls
    train_dest.mkdir(parents=True, exist_ok=True)
    val_dest.mkdir(parents=True, exist_ok=True)

    # List all images
    images = list(src_class_dir.glob("*.*"))  # jpg, png, jpeg
    random.shuffle(images)

    # Split
    split_idx = int(len(images) * TRAIN_SPLIT)
    train_imgs = images[:split_idx]
    val_imgs = images[split_idx:]

    # Move images
    for img in train_imgs:
        shutil.move(str(img), train_dest / img.name)
    for img in val_imgs:
        shutil.move(str(img), val_dest / img.name)

    print(f"✅ Class '{cls}' added: {len(train_imgs)} train, {len(val_imgs)} val")

print("All new classes are organized and ready for training!")

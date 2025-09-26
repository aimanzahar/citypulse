# from bing_image_downloader import downloader

# downloader.download(
#     "broken streetlight", 
#     limit=100, 
#     output_dir='dataset_downloads', 
#     adult_filter_off=True, 
#     force_replace=False, 
#     timeout=60
# )

from bing_image_downloader import downloader
from pathlib import Path

# ---------- CONFIG ----------
CLASS_NAME = "drainage"
LIMIT = 200  # number of images to download
OUTPUT_DIR = Path("dataset_downloads")  # folder to store downloaded images

# Ensure the output directory exists
OUTPUT_DIR.mkdir(parents=True, exist_ok=True)

# ---------- DOWNLOAD IMAGES ----------
downloader.download(
    CLASS_NAME,
    limit=LIMIT,
    output_dir=str(OUTPUT_DIR),
    adult_filter_off=True,   # keep it safe
    force_replace=False,     # don't overwrite if already downloaded
    timeout=60               # seconds per request
)

print(f"✅ Downloaded {LIMIT} images for class '{CLASS_NAME}' in '{OUTPUT_DIR}'")

import torch
from torchvision import transforms, models
from PIL import Image
import os

# ---------- CONFIG ----------
DEVICE = torch.device("cuda" if torch.cuda.is_available() else "cpu")
NUM_CLASSES = 6
CLASS_NAMES = ["broken_streetlight","drainage","garbage", "pothole","signage", "streetlight"]
MODEL_PATH = "best_model.pth"
TEST_IMAGES_DIR = "images"  # folder containing test images

# ---------- MODEL ----------
model = models.resnet18(weights=models.ResNet18_Weights.IMAGENET1K_V1)
model.fc = torch.nn.Linear(model.fc.in_features, NUM_CLASSES)
model.load_state_dict(torch.load(MODEL_PATH, map_location=DEVICE))
model = model.to(DEVICE)
model.eval()

# ---------- IMAGE PREPROCESS ----------
preprocess = transforms.Compose([
    transforms.Resize((224, 224)),
    transforms.ToTensor(),
])

# ---------- INFERENCE ----------
for image_name in os.listdir(TEST_IMAGES_DIR):
    image_path = os.path.join(TEST_IMAGES_DIR, image_name)
    if not image_path.lower().endswith(('.png', '.jpg', '.jpeg')):
        continue

    image = Image.open(image_path).convert("RGB")
    input_tensor = preprocess(image).unsqueeze(0).to(DEVICE)  # add batch dimension

    with torch.no_grad():
        outputs = model(input_tensor)
        _, predicted = torch.max(outputs, 1)
        predicted_class = CLASS_NAMES[predicted.item()]

    print(f"{image_name} --> Predicted class: {predicted_class}")
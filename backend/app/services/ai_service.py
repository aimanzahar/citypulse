import os
import logging
from typing import Tuple
import torch
from torchvision import transforms, models
from PIL import Image
import cv2
from ultralytics import YOLO
import json

logger = logging.getLogger(__name__)
logger.setLevel(logging.INFO)

# ----------------------
# AI Model Manager
# ----------------------
class AIModelManager:
    """Loads and keeps classification and detection models in memory."""
    def __init__(self, device: str = None):
        self.device = torch.device(device or ("cuda" if torch.cuda.is_available() else "cpu"))

        # Compute relative paths
        BASE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
        self.class_model_path = os.path.join(BASE_DIR, "models", "classification", "best_model.pth")
        self.class_mapping_path = os.path.join(BASE_DIR, "models", "classification", "class_mapping.json")
        self.detection_model_path = os.path.join(BASE_DIR, "models", "detection", "best_severity_check.pt")


        # Initialize models
        self.class_model = None
        self.class_names = None
        self._load_classification_model()
        self.detection_model = None
        self._load_detection_model()

        # Preprocess for classification
        self.preprocess = transforms.Compose([
            transforms.Resize((224, 224)),
            transforms.ToTensor()
        ])

    def _load_classification_model(self):
        logger.info("Loading classification model...")
        with open(self.class_mapping_path, "r") as f:
            class_mapping = json.load(f)
        self.class_names = [class_mapping[str(i)] for i in range(len(class_mapping))]

        self.class_model = models.resnet18(weights=None)
        self.class_model.fc = torch.nn.Linear(self.class_model.fc.in_features, len(self.class_names))
        state_dict = torch.load(self.class_model_path, map_location=self.device)
        self.class_model.load_state_dict(state_dict)
        self.class_model.to(self.device)
        self.class_model.eval()
        logger.info("Classification model loaded successfully.")

    def _load_detection_model(self):
        logger.info("Loading YOLO detection model...")
        self.detection_model = YOLO(self.detection_model_path)
        logger.info("YOLO detection model loaded successfully.")


# ----------------------
# AI Service
# ----------------------
class AIService:
    """Handles classification and detection using preloaded models."""
    def __init__(self, model_manager: AIModelManager):
        self.models = model_manager

    # ----------------------
    # Classification
    # ----------------------
    def classify_category(self, image_path: str) -> str:
        image = Image.open(image_path).convert("RGB")
        input_tensor = self.models.preprocess(image).unsqueeze(0).to(self.models.device)
        with torch.no_grad():
            outputs = self.models.class_model(input_tensor)
            _, predicted = torch.max(outputs, 1)
            category = self.models.class_names[predicted.item()]
        logger.info(f"Image '{image_path}' classified as '{category}'.")
        return category

    # ----------------------
    # Detection / Severity
    # ----------------------
    @staticmethod
    def classify_severity(box: Tuple[int, int, int, int], image_height: int) -> str:
        x1, y1, x2, y2 = box
        area = (x2 - x1) * (y2 - y1)
        if area > 50000 or y2 > image_height * 0.75:
            return "High"
        elif area > 20000 or y2 > image_height * 0.5:
            return "Medium"
        else:
            return "Low"

    @staticmethod
    def draw_boxes_and_severity(image, results) -> None:
        for r in results:
            for box in r.boxes.xyxy:
                x1, y1, x2, y2 = map(int, box.cpu().numpy())
                conf = float(r.boxes.conf[0]) if hasattr(r.boxes, "conf") else 0.0
                severity = AIService.classify_severity((x1, y1, x2, y2), image.shape[0])
                color = (0, 255, 0) if severity == "Low" else (0, 255, 255) if severity == "Medium" else (0, 0, 255)
                cv2.rectangle(image, (x1, y1), (x2, y2), color, 2)
                cv2.putText(image, f"{severity} ({conf:.2f})", (x1, y1 - 10),
                            cv2.FONT_HERSHEY_SIMPLEX, 0.6, color, 2)

    def detect_pothole_severity(self, image_path: str, output_path: str = None) -> Tuple[str, str]:
        image = cv2.imread(image_path)
        results = self.models.detection_model(image)
        self.draw_boxes_and_severity(image, results)

        # Determine highest severity
        severities = []
        for r in results:
            for box in r.boxes.xyxy:
                severities.append(self.classify_severity(map(int, box.cpu().numpy()), image.shape[0]))

        if severities:
            if "High" in severities:
                severity = "High"
            elif "Medium" in severities:
                severity = "Medium"
            else:
                severity = "Low"
        else:
            severity = "Unknown"

        # Save annotated image
        if output_path:
            os.makedirs(os.path.dirname(output_path), exist_ok=True)
            cv2.imwrite(output_path, image)
        else:
            output_path = image_path

        logger.info(f"Pothole severity: {severity}, output image saved to '{output_path}'.")
        return severity, output_path

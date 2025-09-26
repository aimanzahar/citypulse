import cv2
from ultralytics import YOLO

# Load your trained YOLOv12 model
model = YOLO("checkpoints/pothole_detector/weights/best.pt")  # Path to your trained weights

# Define severity thresholds (you can adjust these based on your dataset)
def classify_severity(box, image_height):
    x1, y1, x2, y2 = box
    area = (x2 - x1) * (y2 - y1)
    if area > 50000 or y2 > image_height * 0.75:
        return "High"
    elif area > 20000 or y2 > image_height * 0.5:
        return "Medium"
    else:
        return "Low"

# Draw bounding boxes with severity
def draw_boxes_and_severity(image, results):
    for r in results:  # iterate over Results objects
        for box in r.boxes.xyxy:  # xyxy format
            x1, y1, x2, y2 = map(int, box.cpu().numpy())
            conf = float(r.boxes.conf[0]) if hasattr(r.boxes, "conf") else 0.0
            severity = classify_severity((x1, y1, x2, y2), image.shape[0])
            color = (0, 255, 0) if severity == "Low" else (0, 255, 255) if severity == "Medium" else (0, 0, 255)
            cv2.rectangle(image, (x1, y1), (x2, y2), color, 2)
            cv2.putText(image, f"{severity} ({conf:.2f})", (x1, y1 - 10),
                        cv2.FONT_HERSHEY_SIMPLEX, 0.6, color, 2)
    return image

# Detect potholes in an image
def detect_potholes(image_path, output_path="output.jpg"):
    image = cv2.imread(image_path)
    results = model(image)  # Run inference
    image = draw_boxes_and_severity(image, results)
    cv2.imwrite(output_path, image)
    print(f"Output saved to {output_path}")

# Example usage
if __name__ == "__main__":
    detect_potholes(r"images\pothole_1.jpg")

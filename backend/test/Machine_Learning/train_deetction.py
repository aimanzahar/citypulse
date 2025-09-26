from ultralytics import YOLO

def train():
    model = YOLO("yolov12n.pt")  # pretrained YOLOv8 small
    model.train(
        data="D:/CTF_Hackathon/gensprintai2025/pothole-detection-yolov12.v2i.yolov12/data.yaml",
        epochs=10,
        imgsz=512,
        batch=8,
        device=0,
        project="checkpoints",
        name="pothole_detector",
        exist_ok=True
    )

if __name__ == "__main__":
    train()

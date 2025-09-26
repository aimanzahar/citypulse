import os
import torch
from torch import nn, optim
from torch.utils.data import DataLoader
from torchvision import datasets, transforms, models
from torch.cuda.amp import GradScaler, autocast
from torch.utils.tensorboard import SummaryWriter
import time
import psutil

# ---------- CONFIG ----------
DATA_DIR = "dataset"  # dataset folder
BATCH_SIZE = 16
NUM_EPOCHS = 5
LR = 1e-4
DEVICE = torch.device("cuda" if torch.cuda.is_available() else "cpu")
NUM_CLASSES = 6  # pothole, streetlight, garbage
NUM_WORKERS = 10  # Windows-safe

# ---------- DATA ----------
train_transforms = transforms.Compose([
    transforms.Resize((224, 224)),
    transforms.RandomHorizontalFlip(),
    transforms.RandomRotation(15),
    transforms.ColorJitter(brightness=0.2, contrast=0.2, saturation=0.2),
    transforms.ToTensor(),
])

val_transforms = transforms.Compose([
    transforms.Resize((224, 224)),
    transforms.ToTensor(),
])

train_dataset = datasets.ImageFolder(os.path.join(DATA_DIR, "train"), transform=train_transforms)
val_dataset = datasets.ImageFolder(os.path.join(DATA_DIR, "val"), transform=val_transforms)

train_loader = DataLoader(train_dataset, batch_size=BATCH_SIZE, shuffle=True, num_workers=NUM_WORKERS)
val_loader = DataLoader(val_dataset, batch_size=BATCH_SIZE, shuffle=False, num_workers=NUM_WORKERS)

# ---------- MODEL ----------
model = models.resnet18(weights=models.ResNet18_Weights.IMAGENET1K_V1)
model.fc = nn.Linear(model.fc.in_features, NUM_CLASSES)
model = model.to(DEVICE)

criterion = nn.CrossEntropyLoss()
optimizer = optim.Adam(model.parameters(), lr=LR)
scaler = GradScaler()  # Mixed precision

# ---------- TENSORBOARD ----------
writer = SummaryWriter(log_dir="runs/streetlight_classification")

# ---------- DEBUG FUNCTIONS ----------
def print_gpu_memory():
    if DEVICE.type == "cuda":
        print(f"GPU Memory Allocated: {torch.cuda.memory_allocated()/1024**2:.2f} MB")
        print(f"GPU Memory Cached:    {torch.cuda.memory_reserved()/1024**2:.2f} MB")

def print_cpu_memory():
    mem = psutil.virtual_memory()
    print(f"CPU Memory Usage: {mem.percent}% ({mem.used/1024**2:.2f}MB / {mem.total/1024**2:.2f}MB)")

# ---------- TRAINING FUNCTION ----------
def train_model(num_epochs):
    best_acc = 0.0
    for epoch in range(num_epochs):
        start_time = time.time()
        model.train()
        running_loss = 0.0

        for i, (inputs, labels) in enumerate(train_loader):
            inputs, labels = inputs.to(DEVICE), labels.to(DEVICE)
            optimizer.zero_grad()

            with autocast():
                outputs = model(inputs)
                loss = criterion(outputs, labels)

            scaler.scale(loss).backward()

            # Debug gradients for first batch
            if i == 0 and epoch == 0:
                for name, param in model.named_parameters():
                    if param.grad is not None:
                        print(f"Grad {name}: mean={param.grad.mean():.6f}, std={param.grad.std():.6f}")

            scaler.step(optimizer)
            scaler.update()
            running_loss += loss.item()

            if i % 10 == 0:
                print(f"[Epoch {epoch+1}][Batch {i}/{len(train_loader)}] Loss: {loss.item():.4f}")
                print_gpu_memory()
                print_cpu_memory()

        avg_loss = running_loss / len(train_loader)

        # ---------- VALIDATION ----------
        model.eval()
        correct, total = 0, 0
        with torch.no_grad():
            for inputs, labels in val_loader:
                inputs, labels = inputs.to(DEVICE), labels.to(DEVICE)
                outputs = model(inputs)
                _, preds = torch.max(outputs, 1)
                correct += (preds == labels).sum().item()
                total += labels.size(0)
        val_acc = correct / total

        print(f"Epoch [{epoch+1}/{num_epochs}] completed in {time.time()-start_time:.2f}s")
        print(f"Train Loss: {avg_loss:.4f}, Val Accuracy: {val_acc:.4f}\n")

        # TensorBoard logging
        writer.add_scalar("Loss/train", avg_loss, epoch)
        writer.add_scalar("Accuracy/val", val_acc, epoch)

        # Save best model
        if val_acc > best_acc:
            best_acc = val_acc
            torch.save(model.state_dict(), "best_model.pth")
            print("✅ Saved best model.")

    print(f"Training finished. Best Val Accuracy: {best_acc:.4f}")

if __name__ == "__main__":
    train_model(NUM_EPOCHS)

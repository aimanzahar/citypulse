import torch

print("🔥 PyTorch version:", torch.__version__)

# Always True if torch installed
print("✅ Torch is available:", torch.backends.mkl.is_available() or torch.backends.openmp.is_available())

# Check CUDA / GPU
print("🖥️ CUDA available:", torch.cuda.is_available())
if torch.cuda.is_available():
    print("   -> CUDA device count:", torch.cuda.device_count())
    print("   -> Current device:", torch.cuda.current_device())
    print("   -> GPU name:", torch.cuda.get_device_name(torch.cuda.current_device()))
else:
    print("   -> Running on CPU only")

# Check MPS (for Apple Silicon M1/M2 Macs)
if torch.backends.mps.is_available():
    print("🍎 MPS (Apple GPU) available")

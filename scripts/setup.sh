#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BACKEND_DIR="$SCRIPT_DIR/../backend"

echo "=== VoiceType-Lite Setup ==="

# 1. Create Python venv
echo "Creating Python virtual environment..."
cd "$BACKEND_DIR"
python3 -m venv .venv
source .venv/bin/activate

# 2. Install dependencies
echo "Installing Python dependencies..."
pip install --upgrade pip
pip install -r requirements.txt

# 3. Pre-download model
echo "Pre-downloading SenseVoiceSmall model..."
python3 -c "
from funasr import AutoModel
print('Downloading model...')
AutoModel(model='iic/SenseVoiceSmall', trust_remote_code=True, device='cpu')
print('Model downloaded successfully.')
"

echo ""
echo "=== Setup complete ==="
echo "To start the backend:  cd backend && ./start.sh"
echo "To build the Swift app: cd app && xcodegen generate && open VoiceType-Lite.xcodeproj"

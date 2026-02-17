#!/bin/bash
set -e

DIR="$(cd "$(dirname "$0")" && pwd)"
BACKEND_DIR="$DIR/backend"
APP_PATH="$HOME/Library/Developer/Xcode/DerivedData/VoiceType-Lite-*/Build/Products/Debug/VoiceType-Lite.app"

# Start backend
echo "Starting backend..."
cd "$BACKEND_DIR"
source .venv/bin/activate
python -m uvicorn server:app --host 127.0.0.1 --port 8766 --workers 1 &
BACKEND_PID=$!

# Wait for backend to be ready
echo "Waiting for model to load..."
until curl -s http://127.0.0.1:8766/health | grep -q '"ready"'; do
    sleep 2
done
echo "Backend ready."

# Launch Swift app
APP=$(ls -d $APP_PATH 2>/dev/null | head -1)
if [ -n "$APP" ]; then
    echo "Launching VoiceType-Lite app..."
    open "$APP"
else
    echo "Swift app not found. Build it first in Xcode, then it will auto-launch next time."
fi

# Keep running, Ctrl+C to stop all
echo "Running. Press Ctrl+C to stop."
trap "kill $BACKEND_PID 2>/dev/null; exit" INT TERM
wait $BACKEND_PID

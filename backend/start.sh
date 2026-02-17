#!/bin/bash
cd "$(dirname "$0")"
source .venv/bin/activate 2>/dev/null
python -m uvicorn server:app --host 127.0.0.1 --port 8766 --workers 1

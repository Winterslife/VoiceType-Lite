import asyncio
import io
import logging
import re

import numpy as np
import soundfile as sf
from fastapi import FastAPI, File, UploadFile
from fastapi.responses import JSONResponse
from funasr import AutoModel
from funasr.utils.postprocess_utils import rich_transcription_postprocess


def _deduplicate(text: str) -> str:
    """Remove repeated sentence blocks from ASR output."""
    segments = re.split(r"(?<=[。？！])", text)
    segments = [s for s in segments if s]
    if len(segments) <= 1:
        # Fallback for text without sentence-ending punctuation
        n = len(text)
        if n >= 2 and n % 2 == 0 and text[: n // 2] == text[n // 2 :]:
            return text[: n // 2]
        return text
    # Find and remove consecutive repeated blocks of sentences
    result: list[str] = []
    i = 0
    while i < len(segments):
        max_block = (len(segments) - i) // 2
        found = False
        for block_len in range(max_block, 0, -1):
            block = segments[i : i + block_len]
            j = i + block_len
            while j + block_len <= len(segments) and segments[j : j + block_len] == block:
                j += block_len
            if j > i + block_len:
                result.extend(block)
                i = j
                found = True
                break
        if not found:
            result.append(segments[i])
            i += 1
    return "".join(result)


logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("voicetype-lite")

app = FastAPI(title="VoiceType-Lite ASR Backend")

model = None


@app.on_event("startup")
async def load_model():
    global model
    logger.info("Loading SenseVoiceSmall on CPU")
    model = AutoModel(
        model="iic/SenseVoiceSmall",
        trust_remote_code=True,
        device="cpu",
    )
    logger.info("SenseVoiceSmall loaded successfully")


@app.get("/health")
async def health():
    if model is None:
        return JSONResponse({"status": "loading"}, status_code=503)
    return {"status": "ready"}


@app.post("/transcribe")
async def transcribe(file: UploadFile = File(...)):
    if model is None:
        return JSONResponse({"error": "Model not loaded"}, status_code=503)

    contents = await file.read()
    try:
        audio_data, sr = sf.read(io.BytesIO(contents), dtype="float32")
    except Exception as e:
        return JSONResponse({"error": f"Invalid audio file: {e}"}, status_code=400)

    # Convert stereo to mono if needed
    if audio_data.ndim > 1:
        audio_data = audio_data.mean(axis=1)

    loop = asyncio.get_event_loop()
    result = await loop.run_in_executor(
        None, lambda: model.generate(input=audio_data, input_len=len(audio_data), language="zh", use_itn=True)
    )

    # SenseVoiceSmall returns a list of dicts with 'text' key
    if isinstance(result, list) and len(result) > 0:
        item = result[0]
        if isinstance(item, dict):
            text = item.get("text", "")
        elif hasattr(item, "text"):
            text = item.text
        else:
            text = str(item)
    elif isinstance(result, str):
        text = result
    else:
        text = str(result)

    text = rich_transcription_postprocess(text)

    text = _deduplicate(text)

    return {"text": text, "language": "zh"}

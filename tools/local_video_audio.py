"""Decode mono 16 kHz float audio using the installed PyAV API."""
from pathlib import Path

import av
import numpy as np


def decode_audio(path: str | Path) -> np.ndarray:
    resampler = av.AudioResampler(format="fltp", layout="mono", rate=16000)
    chunks = []
    with av.open(str(path)) as container:
        for frame in container.decode(audio=0):
            for converted in resampler.resample(frame):
                chunks.append(converted.to_ndarray().reshape(-1))
        for converted in resampler.resample(None):
            chunks.append(converted.to_ndarray().reshape(-1))
    if not chunks:
        raise ValueError("No decoded audio samples.")
    return np.concatenate(chunks).astype(np.float32, copy=False)

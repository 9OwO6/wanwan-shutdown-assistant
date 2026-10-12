"""Run an owned CPU-only TTS child only for this generation job."""
import json
import os
import subprocess
import time
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
TTS = Path(r"E:\LocalAI\alltalk_tts")
PYTHON = TTS / "alltalk_environment" / "env" / "python.exe"
SERVER = "http://127.0.0.1:7851/api/ready"

def ready():
    try:
        with urllib.request.urlopen(SERVER, timeout=2) as response:
            body = response.read().decode("utf-8").strip()
            return body in ('Ready', '"Ready"')
    except (OSError, ValueError):
        return False

child = None
try:
    if not ready():
        env = os.environ.copy()
        env["CUDA_VISIBLE_DEVICES"] = "-1"
        env["PYTHONUNBUFFERED"] = "1"
        log = (ROOT / "output" / "voice-auditions" / "bank-server.log").open("w")
        child = subprocess.Popen([str(PYTHON), "tts_server.py"], cwd=TTS, env=env,
                                 stdout=log, stderr=subprocess.STDOUT,
                                 creationflags=subprocess.CREATE_NO_WINDOW)
        print(f"Owned CPU TTS child: {child.pid}", flush=True)
        deadline = time.monotonic() + 90
        while not ready():
            if child.poll() is not None:
                raise RuntimeError("TTS child exited; see bank-server.log")
            if time.monotonic() > deadline:
                raise TimeoutError("TTS initialization exceeded 90 seconds")
            time.sleep(1)
    print("TTS ready; building local voice packs", flush=True)
    subprocess.run([os.sys.executable, str(ROOT / "tools" / "build_voice_bank.py")], check=True)
finally:
    if child is not None:
        child.terminate()
        try:
            child.wait(timeout=10)
        except subprocess.TimeoutExpired:
            child.kill()
            child.wait()
        log.close()
        print("Owned CPU TTS child stopped", flush=True)

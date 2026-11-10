#!/usr/bin/env python3
"""Legacy entry point: emit audio only; image regeneration now requires review."""
from pathlib import Path
import runpy
runpy.run_path(str(Path(__file__).with_name('generate_audio.py')))
print('Art workflow: docs/art-workflow.md. Use Godot tools/import_art.gd for reviewed PNG slicing.')

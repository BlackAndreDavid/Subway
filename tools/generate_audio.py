#!/usr/bin/env python3
"""Recreate the original synthesized WAV cues. Raster art uses reviewed image sources."""
from pathlib import Path
import math,wave,struct
root=Path(__file__).resolve().parents[1]/'assets'
for name,freq in [('shot',510),('pickup',880),('hit',170),('door',330)]:
 with wave.open(str(root/(name+'.wav')),'wb') as w:
  w.setparams((1,2,22050,0,'NONE','not compressed'))
  w.writeframes(b''.join(struct.pack('<h',int(4500*math.sin(2*math.pi*freq*t/22050)*(1-t/2205))) for t in range(2205)))
print('Generated 4 WAV cues; PNG sources are never overwritten.')

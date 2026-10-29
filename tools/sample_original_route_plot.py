"""Sample a visibly calibrated original-app sensor curve; never a precision export.

Only supports the recorded 2560x1392 maximized layout. Calibration must be
checked against each screenshot before use. No app automation or hidden state.
"""
import argparse
import csv
import hashlib
import json
from pathlib import Path

import numpy as np
from PIL import Image

parser = argparse.ArgumentParser()
parser.add_argument('screenshot', type=Path)
parser.add_argument('output', type=Path)
args = parser.parse_args()
rgb = np.asarray(Image.open(args.screenshot).convert('RGB')).astype(int)
assert rgb.shape == (1392, 2560, 3), 'Recalibrate changed screenshot dimensions'
# Observed plot borders/ticks: (-6000,2000)=(538,625), (0,0)=(1594,977).
left, right, top, bottom = 538, 1594, 625, 977
sx, sy = (right-left)/6000, (bottom-top)/2000
red = (rgb[:,:,0] > 160)
# Retain anti-aliased light red; reject green/blue curves and magenta arrows.
red &= (rgb[:,:,0]-rgb[:,:,1] > 50) & (rgb[:,:,0]-rgb[:,:,2] > 50)

def sample(x):
    col = round(left + (x+6000)*sx)
    yy, _ = np.where(red[top+1:bottom, col-1:col+2])
    if not len(yy):
        return None
    yy = yy+top+1
    # Reject marker stacks, multiple branches, legend lines and broad patches.
    if np.ptp(yy) > 8:
        return None
    row = float(np.median(yy))
    return {'xMM': x, 'yMM': (bottom-row)/sy, 'pixelColumn': col,
            'pixelRow': row, 'redPixelCount': len(yy)}

# Avoid start/finish markers and upper-right legend. Stations do not coincide
# with supplied target centers. The remaining trace is a sampled visual guide.
stations = [sample(x) for x in [-5000,-4000,-3000,-2000,-1000]]
assert all(stations), 'A requested station is ambiguous; inspect manually'
trace = [r for x in range(-5300,-699,25) if (r := sample(x)) is not None]
args.output.parent.mkdir(parents=True, exist_ok=True)
report = {'source': str(args.screenshot),
          'sourceSHA256': hashlib.sha256(args.screenshot.read_bytes()).hexdigest(),
          'pixelCalibration': {'left':left,'right':right,'top':top,'bottom':bottom,
                               'xMM':[-6000,0],'yMM':[0,2000]},
          'readingUncertaintyPixels': 2,
          'approximateReadingUncertaintyMM': {'x':2/sx,'y':2/sy},
          'stations':stations, 'traceSampleCount':len(trace),
          'scope':'Approximate screen sensor-trajectory reading. Curves are separately designed; differences are route-choice differences, not numerical error against a common route. Not a cam coordinate export or hit-tolerance certification.'}
args.output.with_suffix('.json').write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf-8')
for suffix, rows in [('stations',stations),('trace',trace)]:
    with args.output.with_name(args.output.stem+'_'+suffix+'.csv').open('w',newline='',encoding='utf-8') as f:
        writer=csv.writer(f); writer.writerow(['xMM','yMM'])
        writer.writerows((r['xMM'],r['yMM']) for r in rows)
print(json.dumps(report,ensure_ascii=False))

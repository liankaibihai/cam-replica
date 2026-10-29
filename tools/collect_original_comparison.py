"""Archive sanitized visible original-app evidence and independent replica data."""
import hashlib
import json
import re
from pathlib import Path

root=Path(__file__).resolve().parents[1]
local=root/'local/original_comparison_20261029'
out=root/'outputs/original_comparison_20261029'
def read(path):
    return json.loads(path.read_text(encoding='utf-8-sig'))
def fingerprint(path):
    return {'path':path.relative_to(root).as_posix(),
            'sha256':hashlib.sha256(path.read_bytes()).hexdigest()}

replica=read(out/'replica_candidates.json')
visual=read(out/'visual_station_comparison.json')
inputs=read(local/'inputs_sanitized.json')
allowed={'file_format','export_type','line_num','car_type','dh','i_total','c','r','d','f',
         'xmin','xmax','ymin','ymax','driving_x','driving_y','driven_x','driven_y',
         'sensor_x','sensor_y','vc_x','vc_y','train_times','control_points_num',
         'segments_num','bezier_index','gradient_force','study_rate','smooth_rate',
         'disturb_gap','disturb_index','version','pathway_points','control_points',
         'optimal_gradient'} | {f'index{i}' for i in range(1,13)}
for case in inputs.values():
    assert set(case)<=allowed, 'Unexpected input field; do not archive identifiers'
labels={'iterations':'迭代次数','durationReadout':'训练时长','gradientForce':'梯度力',
        'score':'综合分数','driveLengthMM':'主动轮路线长度','maxLeftDeg':'前轮最大左转角度',
        'maxRightDeg':'前轮最大右转角度','maxPressureDeg':'凸轮最大压力角'}
cases=[]
for kind in ['rack','flat']:
    readings=read(local/f'{kind}_readouts.json')
    text=readings[-1]['text']
    metrics={key:float(re.search(re.escape(label)+r'：([-\d.]+)',text).group(1))
             for key,label in labels.items()}
    assert metrics['iterations']==300
    counterpart=next(x for x in replica['cases'] if x['mechanism']==kind)
    counterpart['originalResultAvailableAtReplicaCalculation']=counterpart.pop('originalResultAvailable')
    cases.append({'mechanism':kind,'originalInput':inputs[kind],
                  'originalUIFinal':metrics,'originalVisibleReadouts':readings,
                  'originalScreenshot':fingerprint(local/f'{kind}_final.png'),
                  'originalInitialMAT':fingerprint(root/f'local/reference_app/codex_compare_{kind}_300_20261029.mat'),
                  'originalFinalMAT':fingerprint(local/f'{kind}_after_300.mat'),
                  'replica':counterpart,
                  'pixelCalibration':read(out/f'{kind}_pixels.json'),
                  'visualStations':next(x for x in visual['cases'] if x['mechanism']==kind)})
report={'date':'2026-10-29','originalVersion':'3.1.2','replicaRelease':'R2025b',
        'cases':cases,'originalPhysicalInputInvariantFields':20,
        'userOriginalProjectRestoredFields':48,
        'logs':[fingerprint(root/'local'/name) for name in [
            'matlab_b6ae970c6457434cba68d7ae4ccba165.log',
            'matlab_dadf0426840741929f0ad736dd55583d.log',
            'matlab_da906eb45a4a4a4da4ac458985e6cf24.log']],
        'scope':'Same targets and physical parameters, fixed transmission ratio20, different route basis/initial route/objective. Original300 iterations completed; replica local stopping reported. Screenshots calibrate visible sensor trajectory only; about2pixels uncertainty per coordinate. No pointwise cam-output equivalence, original hit-error certification, identical pressure-statistic scope or vehicle validation. UI duration unit not labelled. No export authorization bypass.'}
target=root/'data/original_comparison_20261029.json'
target.write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print(f'Wrote {target.relative_to(root)} ({target.stat().st_size} bytes)')

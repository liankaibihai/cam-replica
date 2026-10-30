"""Condense completed MATLAB artifacts; never manufacture missing run results."""
from pathlib import Path
import hashlib
import json
import statistics
import math
import re

root = Path(__file__).resolve().parents[1]
folder = root / 'outputs/path_comparison_20261031'
full = json.loads((folder / 'final_report.json').read_text(encoding='utf-8'))
assert len(full['runs']) == 20
methods = ['cubic', 'bezier5', 'bspline3', 'bspline5']
titles = ['三次插值样条', '独立融合贝塞尔（五次）', '标准三次B样条', '标准五次B样条']

def numeric(value):
    return value if isinstance(value, (int, float)) and math.isfinite(value) else math.inf

def finite(value):
    return value if math.isfinite(value) else None

def metric(r, key):
    m = r['finalMetrics']
    return numeric(m.get(key)) if isinstance(m, dict) else math.inf

def display(value, digits=3):
    return f'{value:.{digits}f}' if value is not None and math.isfinite(value) else '无效'

def condensed(r):
    result = {k: r[k] for k in ['label','seed','method','iterations','requestedIterations','reason',
        'modelAttempts','solverFunctionCount','solverSeconds','effectiveDOF','stable','discreteFeasible',
        'verifiedFeasible','last50ViolationImprovement','convergenceDelta','numericalChecks','pressureAudit']}
    result['fit'] = r['fit']
    result['initialMetrics'] = r['initial']['metrics']
    result['finalMetrics'] = r['final']['metrics']
    result['maxScaledViolation'] = r['final']['maxScaledViolation']
    result['maximumCenterOutsideMM'] = r['final']['maxTrajectoryOutsideMM']
    result['finalValid'] = r['final']['valid']
    result['controlBounds'] = r['final']['controlBounds']
    result['requestedRatio'] = r['final']['requestedRatio']
    result['effectiveRatio'] = r['final']['effectiveRatio']
    return result

runs = [condensed(r) for r in full['runs']]
continuation = []
for method in methods:
    file = folder / 'continuation_2x' / f'seed1_{method}.json'
    assert file.is_file(), f'Missing continuation: {file}'
    r = condensed(json.loads(file.read_text(encoding='utf-8')))
    # The original batch retained primary position-fit statistics but recomputed
    # sensor/steering differences on the continuation start. Preserve raw MAT/JSON
    # and explicitly separate these fields in the delivered evidence.
    fit = r.pop('fit')
    r['primaryRepresentationFit'] = fit.get('primaryRepresentationFit', {k: v for k, v in fit.items()
        if k not in ['sensorMaxDifferenceMM','steeringMaxDifferenceDeg']})
    r['continuationStartVersusOriginalGeometry'] = {k: fit[k]
        for k in ['sensorMaxDifferenceMM','steeringMaxDifferenceDeg']}
    continuation.append(r)

files = ['route.m','camProfile.m','routeSpline.m','bezierRoute.m','independentBezierBasis.m',
    'bsplineBasis.m','bsplineRoute.m','toBSpline.m','routeGeometry.m','optimizationVariables.m',
    'controlBounds.m','fminconModel.m','optimizeFmincon.m','verifyConstrained.m',
    'autoTuneAssessment.m','autoTuneNumericalChecks.m','validateProject.m','evaluate.m']
paths = [root / '+camdesign' / x for x in files]
paths += [root / 'check_path_method_comparison.m', root / 'report_path_method_comparison.m', Path(__file__).resolve()]
hashes = {p.relative_to(root).as_posix(): hashlib.sha256(p.read_bytes()).hexdigest() for p in paths}
groups = []
for name in methods:
    rows = [r for r in runs if r['method'] == name]
    assert len(rows) == 5 and all(r['effectiveDOF'] == 66 for r in rows)
    groups.append(dict(method=name, runs=5, feasible=sum(r['verifiedFeasible'] for r in rows),
        stable=sum(r['stable'] for r in rows), iterations=sum(r['iterations'] for r in rows),
        modelAttempts=sum(r['modelAttempts'] for r in rows),
        pressureMedianDeg=finite(statistics.median(numeric(r['pressureAudit']['maxPressureDeg']) for r in rows)),
        hitMedianMM=finite(statistics.median(metric(r,'maxHitError') for r in rows)),
        returnMedianDeg=finite(statistics.median(metric(r,'actualReturnDeg') for r in rows)),
        routeMedianMM=finite(statistics.median(metric(r,'routeLength') for r in rows)),
        intersectionMinMax=[finite(min(metric(r,'intersectionCount') for r in rows)),finite(max(metric(r,'intersectionCount') for r in rows))]))
report = dict(date='2026-10-31', release='R2025b', baselineGit='7c6d4e0e58ceac958210a849ead87107f8cdad67',
    scope='Independent representation comparison on the solar preliminary flat-car model. Not original-software or physical vehicle equivalence.',
    protocol=full['protocol'], referenceInput=full['referenceInput'], groups=groups, representatives=full['representatives'],
    selectionPolicy=full['selectionPolicy'], timingCaution=full['timingCaution'],
    runs=runs, continuationProtocol=json.loads((folder / 'continuation_2x/protocol.json').read_text(encoding='utf-8')),
    continuation=continuation, sourceSha256=hashes,
    sourceHashScope='Delivered source files. Numerical core frozen throughout formal runs; report/recovery fixes made during execution did not change numerical objectives, constraints or candidates.',
    coreContracts=json.loads((root / 'outputs/bspline_20261031/contracts/verification.json').read_text(encoding='utf-8'))['checks'],
    uiContracts=json.loads((root / 'outputs/bspline_20261031/ui_map_bounds/verification.json').read_text(encoding='utf-8'))['checks'],
    regression=dict(passed=12,total=12,log='local/matlab_1fb1ae80a8c74dd8b65c7d8d8eb79991.log'),
    rawEvidence='outputs/path_comparison_20261031',
    extensionScope='Seed1 of each method received another 600 iterations / 50000 solver calls on 1201/1441 training samples. A separate diagnostic, not mixed into the 5-start primary comparison.')
diagnostic = []
diagnostic_file = root / 'local/matlab_4ba9ded010e24658b179fe20e1ae9909.log'
diagnostic_lines = diagnostic_file.read_text(encoding='utf-8').splitlines() if diagnostic_file.is_file() else []
for line in diagnostic_lines:
    if not re.match(r'^(cubic|bezier5|bspline3|bspline5) grid=',line):
        continue
    parts = line.split(); row = {'method': parts[0]}
    for part in parts[1:]:
        key, value = part.split('='); row[key] = finite(float(value.rstrip('x')))
    diagnostic.append(row)
report['seed1GridDiagnostic'] = diagnostic
report['seed1GridDiagnosticSource'] = diagnostic_file.relative_to(root).as_posix() if diagnostic else None
(root / 'data/path_method_comparison_20261031.json').write_text(json.dumps(report, ensure_ascii=False, indent=2, allow_nan=False) + '\n', encoding='utf-8')
lines = ['| 方法 | 主实验通过 | 数值稳定 | 压力极值中位数/° | 打卡误差中位数/mm | 回程角中位数/° | 自交段对范围 |',
         '|---|---:|---:|---:|---:|---:|---:|']
for title, group in zip(titles, groups):
    lo, hi = group['intersectionMinMax']
    lines.append(f"| {title} | {group['feasible']}/5 | {group['stable']}/5 | {display(group['pressureMedianDeg'])} | {display(group['hitMedianMM'])} | {display(group['returnMedianDeg'])} | {lo}–{hi} |")
lines += ['', '各列是五次运行的分别中位数，不表示同一个候选同时拥有这些指标。', '',
          '| 方法／初值1密网格追加 | 追加实际轮数 | 压力极值/° | 打卡误差/mm | 回程角/° | 自交段对 | 数值稳定 | 全部门限 |',
          '|---|---:|---:|---:|---:|---:|---|---|']
for title, r in zip(titles, continuation):
    lines.append(f"| {title} | {r['iterations']} | {display(r['pressureAudit']['maxPressureDeg'])} | {display(metric(r,'maxHitError'))} | {display(metric(r,'actualReturnDeg'))} | {display(metric(r,'intersectionCount'),0)} | {'是' if r['stable'] else '否'} | {'通过' if r['verifiedFeasible'] else '未通过'} |")
lines += ['', f"主实验实际 {sum(r['iterations'] for r in runs)} 轮、{sum(r['modelAttempts'] for r in runs):,} 次模型尝试；追加实际 {sum(r['iterations'] for r in continuation)} 轮、{sum(r['modelAttempts'] for r in continuation):,} 次模型尝试。该计数包含后端验收，外部加密审计另计。", '',
          '完整逐组终止原因、自由度、拟合误差、网格差与硬阈值检查见 [入库数值摘要](../data/path_method_comparison_20261031.json)。原始MAT包含全部历史和可重新加载的候选，保存在 `outputs/path_comparison_20261031`，不入Git。']
(folder / 'tables.md').write_text('\n'.join(lines)+'\n',encoding='utf-8')
print('\n'.join(lines))

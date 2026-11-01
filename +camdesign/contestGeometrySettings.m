function [cfg,state]=contestGeometrySettings(p)
% Read-only optional competition geometry. Empty dimensions are NOT defaults.
names={'leftMM','rightMM','frontMM','rearMM','coverXMinMM','coverXMaxMM','coverYMinMM','coverYMaxMM', ...
    'tagDiameterMM','boundaryMarginMM','coverageMarginMM'};
labels={'外包络左侧 / mm','外包络右侧 / mm','外包络前侧 / mm','外包络后侧 / mm', ...
    '覆盖区 X下界 / mm（有符号）','覆盖区 X上界 / mm（有符号）','覆盖区 Y下界 / mm（有符号）','覆盖区 Y上界 / mm（有符号）', ...
    '现场 UID直径 / mm','场界额外余量 / mm','覆盖额外余量 / mm'};
cfg=struct('version','rectangle-contest-geometry-v1','measurementsConfirmed',false,'coverageRectangleConfirmed',false);
for k=1:numel(names), cfg.(names{k})=[]; end
if isfield(p,'contestGeometry')
    raw=p.contestGeometry;
    assert(isstruct(raw) && isscalar(raw),'cam:ContestGeometryParameters','比赛几何设置须为标量结构。');
    for name=fieldnames(raw)'
        key=name{1}; assert(isfield(cfg,key),'cam:ContestGeometryParameters','未知比赛几何字段：%s',key); cfg.(key)=raw.(key);
    end
end
assert(strcmp(cfg.version,'rectangle-contest-geometry-v1'),'cam:ContestGeometryParameters','不支持的比赛几何版本。');
missing={};
for k=1:numel(names)
    value=cfg.(names{k});
    if isempty(value), missing{end+1}=names{k}; continue; end %#ok<AGROW>
    assert(isa(value,'double') && isscalar(value) && isreal(value) && isfinite(value), ...
        'cam:ContestGeometryParameters','%s须为有限实数；未知尺寸请留空，不能填NaN或Inf。',labels{k});
    if k<=4 || k>=9
        assert(value>=0,'cam:ContestGeometryParameters','%s不能为负。',labels{k});
    end
end
for name={'measurementsConfirmed','coverageRectangleConfirmed'}
    value=cfg.(name{1});
    assert((islogical(value) || isnumeric(value)) && isreal(value) && isscalar(value) && ismember(value,[0 1]), ...
        'cam:ContestGeometryParameters','确认状态须为true或false。');
    cfg.(name{1})=logical(value);
end
if ~isempty(cfg.tagDiameterMM), assert(cfg.tagDiameterMM>0,'cam:ContestGeometryParameters','UID直径必须大于0。'); end
configured=isempty(missing);
if configured
    assert(cfg.leftMM+cfg.rightMM>0 && cfg.frontMM+cfg.rearMM>0, ...
        'cam:ContestGeometryParameters','外包络宽度和长度必须大于0。');
    assert(cfg.coverXMaxMM>cfg.coverXMinMM && cfg.coverYMaxMM>cfg.coverYMinMM, ...
        'cam:ContestGeometryParameters','覆盖区域上下界顺序无效，必须形成正宽高矩形。');
    assert(cfg.coverXMinMM>=-cfg.leftMM && cfg.coverXMaxMM<=cfg.rightMM ...
        && cfg.coverYMinMM>=-cfg.rearMM && cfg.coverYMaxMM<=cfg.frontMM, ...
        'cam:ContestGeometryParameters','真实连续覆盖内接区域必须位于整车保守外包络内，不能把外接包围盒自动当成覆盖车身。');
end
state=struct('configured',configured,'readyForSampledAssessment',configured && cfg.measurementsConfirmed && cfg.coverageRectangleConfirmed, ...
    'missingFields',{missing},'fieldNames',{names},'labels',{labels}, ...
    'assumption','Body envelope encloses the entire vehicle including wires; independent coverage rectangle is an opaque, continuously covered INNER footprint. Origin=front steering axis; body X right, Y forward. No measured defaults.');
end

function settings=autoTuneSettings(params)
% Optional configuration: read-only and compatible with older projects.
settings=struct('trials',8,'maxIterations',600,'seed',2027,'polishCount',2,'selectedWeights',[]);
if isfield(params,'autoTune')
    value=params.autoTune;
    assert(isstruct(value) && isscalar(value),'cam:AutoTuneSettings','全自动设置须为单个结构。');
    names=fieldnames(value);
    for k=1:numel(names)
        assert(isfield(settings,names{k}),'cam:AutoTuneSettings','未知全自动设置：%s',names{k});
        settings.(names{k})=value.(names{k});
    end
end
validateattributes(settings.trials,{'double'},{'scalar','integer','>=',2,'<=',32});
validateattributes(settings.maxIterations,{'double'},{'scalar','integer','>=',1,'<=',10000});
validateattributes(settings.seed,{'double'},{'scalar','integer','>=',0,'<=',2^32-1});
validateattributes(settings.polishCount,{'double'},{'scalar','integer','>=',0,'<=',2});
if ~isempty(settings.selectedWeights)
    validateattributes(settings.selectedWeights,{'double'},{'vector','numel',6,'real','finite','nonnegative'});
    settings.selectedWeights=settings.selectedWeights(:)';
end
end

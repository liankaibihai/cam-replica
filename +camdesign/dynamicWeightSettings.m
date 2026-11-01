function settings=dynamicWeightSettings(params)
% Missing optional configuration keeps every legacy computation unchanged.
settings=struct('enabled',false,'interval',10,'gain',2,'maxMultiplier',5,'response',0.5);
if isfield(params,'dynamicWeights')
    supplied=params.dynamicWeights;
    assert(isstruct(supplied) && isscalar(supplied),'cam:DynamicWeights','动态权重设置必须是标量结构。');
    names=fieldnames(supplied);
    assert(all(ismember(names,fieldnames(settings))),'cam:DynamicWeights','存在未知动态权重设置。');
    for k=1:numel(names), settings.(names{k})=supplied.(names{k}); end
end
assert(isscalar(settings.enabled) && (islogical(settings.enabled) || isnumeric(settings.enabled)) ...
    && ismember(settings.enabled,[0 1]),'cam:DynamicWeights','动态权重开关必须为0或1。');
settings.enabled=logical(settings.enabled);
validateattributes(settings.interval,{'double'},{'scalar','real','finite','integer','>=',1,'<=',10000});
validateattributes(settings.gain,{'double'},{'scalar','real','finite','>=',0,'<=',100});
validateattributes(settings.maxMultiplier,{'double'},{'scalar','real','finite','>=',1,'<=',100});
validateattributes(settings.response,{'double'},{'scalar','real','finite','>',0,'<=',1});
end

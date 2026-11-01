function [weights,severity]=updateDynamicWeights(params,metrics,previous)
% Bounded, independently designed penalty schedule. Geometry limits do not move.
settings=camdesign.dynamicWeightSettings(params); base=params.weights(:)';
if nargin<3, previous=base; end
validateattributes(previous,{'double'},{'vector','numel',6,'real','finite','nonnegative'});
severity=[max(0,metrics.maxHitError/params.hitTolerance-1),0,0, ...
    max(0,metrics.maxPressureDeg/params.maxPressureDeg-1), ...
    max(0,metrics.maxSteeringDeg/params.maxSteeringDeg-1), ...
    max(0,(0.1-metrics.minUndercutMargin)/0.1)];
assert(all(isfinite(severity)),'cam:DynamicWeights','动态权重所需指标不是有限值。');
if ~settings.enabled, weights=base; return; end
target=base.*min(settings.maxMultiplier,1+settings.gain*severity);
weights=(1-settings.response)*previous(:)'+settings.response*target;
weights=max(base,min(base*settings.maxMultiplier,weights));
weights(2:3)=base(2:3); % Length/roughness have no physical violation threshold.
end

function [best,history,info]=optimize(project,callback,algorithm)
% Independent optimization paths; legacy-v1 is retained for comparison.
if nargin<2, callback=[]; end
if nargin<3, algorithm='peak-gradient-v2'; end
assert(~strcmp(camdesign.routeModel(project.params),'bspline-v1') || ...
    strcmp(algorithm,'fmincon-interior-point-experimental-v1'), ...
    'cam:BSplineBackend','标准B样条目前仅支持约束优化（内点法），不支持峰值、四方向、SQP或全自动组合。');
if strcmp(algorithm,'auto-tune-v1')
    [best,history,info]=camdesign.optimizeAuto(project,callback);
elseif strcmp(algorithm,'feasibility-four-direction-v1')
    [best,history,info]=camdesign.optimizeFeasibilityFour(project,callback);
elseif strcmp(algorithm,'legacy-v1')
    [best,history,info]=camdesign.optimizeLegacy(project,callback);
elseif strcmp(algorithm,'fmincon-sqp-experimental-v1')
    [best,history,info]=camdesign.optimizeFmincon(project,callback,Algorithm='sqp');
elseif strcmp(algorithm,'fmincon-interior-point-experimental-v1')
    [best,history,info]=camdesign.optimizeFmincon(project,callback,Algorithm='interior-point');
else
    [best,history,info]=camdesign.optimizeSearch(project,callback,algorithm);
end
end

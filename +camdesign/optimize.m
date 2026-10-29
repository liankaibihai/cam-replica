function [best,history,info]=optimize(project,callback,algorithm)
% Independent optimization paths; legacy-v1 is retained for comparison.
if nargin<2, callback=[]; end
if nargin<3, algorithm='peak-gradient-v2'; end
if strcmp(algorithm,'legacy-v1')
    [best,history,info]=camdesign.optimizeLegacy(project,callback);
else
    [best,history,info]=camdesign.optimizeSearch(project,callback,algorithm);
end
end

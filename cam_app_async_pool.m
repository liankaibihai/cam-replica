function [pool,executor,created]=cam_app_async_pool(kind,algorithm,create)
% Choose before executing any solver. Never retry a numerical task or delete
% someone else's pool. Current auto-tune uses interior-point, not SQP.
if nargin<3, create=true; end
pool=[]; executor='thread'; created=false;
if strcmp(kind,'optimize') && ismember(algorithm, ...
        {'relay-sqp-v1','multistart-relay-sqp-v1','fmincon-sqp-experimental-v1'})
    executor='process';
end
if ~create, return; end
if strcmp(executor,'thread'), pool=backgroundPool; return; end
assert(license('test','Distrib_Computing_Toolbox'),'cam:BackgroundProcessUnavailable', ...
    '此算法需要后台进程和Parallel Computing Toolbox；可明确选择前台兼容。');
pool=gcp('nocreate');
assert(isempty(pool) || ~isa(pool,'parallel.ThreadPool'),'cam:BackgroundPoolConflict', ...
    '已有用户线程池，未删除或替换它。此算法需进程池；请明确选择前台兼容，或自行处理现有池后重试。');
if isempty(pool), pool=parpool('Processes',1); created=true; end
end

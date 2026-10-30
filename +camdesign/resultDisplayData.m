function display=resultDisplayData(project,result,history,info,state,historyState)
% Read-only presentation adapter. Common score and constrained objective are
% deliberately separate series with separate units/scales.
if nargin<3, history=[]; end
if nargin<4, info=[]; end
if nargin<5, state='当前计算'; end
if nargin<6, historyState='本次训练'; end
display=struct('total',NaN,'rows',{cell(0,4)},'state',state,'consistent',false, ...
    'scoreVersion','未记录','grid',[NaN NaN],'historyState',historyState, ...
    'scoreX',[],'scoreY',[],'objectiveX',[],'objectiveY',[], ...
    'objectiveValue',NaN,'xLabel','迭代','description','本版六项加权通用评分，越低越好；不是原版十二项评分。');
if ~isempty(result) && isfield(result,'metrics') && isfield(result.metrics,'terms')
    m=result.metrics; terms=m.terms(:); weights=project.params.weights(:);
    assert(numel(terms)==6 && numel(weights)==6,'cam:DisplayScore','评分必须含六项。');
    labels={'打卡偏差','路线长度','转向变化','压力角超限','转角超限','欠切风险'};
    contributions=terms.*weights;
    display.rows=[labels(:),num2cell(terms),num2cell(weights),num2cell(contributions)];
    display.total=m.score;
    display.consistent=abs(sum(contributions)-m.score)<=1e-9*max(1,abs(m.score));
    if ~display.consistent, display.state=[state,'（权重来源不匹配）']; end
    if isfield(m,'objectiveVersion'), display.scoreVersion=m.objectiveVersion; end
    if isfield(result,'route') && isfield(result.route,'u'), display.grid(1)=numel(result.route.u); end
    if isfield(result,'cam') && isfield(result.cam,'actual'), display.grid(2)=size(result.cam.actual,1); end
end
for k=1:numel(history)
    x=k-1;
    if isfield(history,'iteration'), x=history(k).iteration;
    else, display.xLabel='记录序号（迭代未记录）'; end
    if isfield(history,'score') && isscalar(history(k).score) && isfinite(history(k).score)
        display.scoreX(end+1)=x; display.scoreY(end+1)=history(k).score;
    end
    if isfield(history,'objective') && isscalar(history(k).objective) && isfinite(history(k).objective)
        display.objectiveX(end+1)=x; display.objectiveY(end+1)=history(k).objective;
    end
end
if isstruct(info) && isfield(info,'returnedObjective'), display.objectiveValue=info.returnedObjective; end
end

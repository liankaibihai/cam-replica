function display=resultDisplayData(project,result,history,info,state,historyState,weightsMatchProject)
% Read-only presentation adapter. Common score and constrained objective are
% deliberately separate series with separate units/scales.
if nargin<3, history=[]; end
if nargin<4, info=[]; end
if nargin<5, state='当前计算'; end
if nargin<6, historyState='本次训练'; end
if nargin<7, weightsMatchProject=false; end
display=struct('total',NaN,'rows',{cell(0,4)},'state',state,'consistent',false, ...
    'routeLengthMM',NaN,'driveLengthMM',NaN, ...
    'scoreVersion','未记录','grid',[NaN NaN],'historyState',historyState, ...
    'scoreX',[],'scoreY',[],'objectiveX',[],'objectiveY',[], ...
    'objectiveValue',NaN,'xLabel','迭代','description','本版六项加权通用评分，越低越好；不是原版十二项评分。');
display.referenceWeights=[]; display.activeWeights=[]; display.activeRows=cell(0,4);
display.dynamicTotal=NaN; display.dynamicAvailable=false; display.dynamicX=[]; display.dynamicY=[];
display.weightMode='未记录'; display.weightUpdateIteration=NaN; display.weightSource='实际权重未记录或与显示项目不匹配';
if ~isempty(result) && isfield(result,'metrics')
    m=result.metrics;
    if isfield(m,'routeLength') && isnumeric(m.routeLength) && isscalar(m.routeLength) && isfinite(m.routeLength)
        display.routeLengthMM=m.routeLength;
    end
    if isfield(m,'driveLength') && isnumeric(m.driveLength) && isscalar(m.driveLength) && isfinite(m.driveLength)
        display.driveLengthMM=m.driveLength;
    end
end
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
    display.referenceWeights=weights(:)';
    record=[];
    if weightsMatchProject && ~isempty(history) && all(isfield(history,{'referenceWeights','activeWeights','weightMode'}))
        record=history(end);
    elseif weightsMatchProject && isstruct(info) && all(isfield(info,{'referenceWeights','finalActiveWeights','dynamicWeights'}))
        record=struct('referenceWeights',info.referenceWeights,'activeWeights',info.finalActiveWeights,'weightMode','fixed');
        if info.dynamicWeights.enabled, record.weightMode='violation-adaptive-v1'; end
    end
    if ~isempty(history) && isfield(history,'objective'), record=[]; end
    if ~isempty(record) && validWeights(record.referenceWeights) && validWeights(record.activeWeights) ...
            && isequal(record.referenceWeights(:),weights) && ismember(string(record.weightMode),["fixed","violation-adaptive-v1"])
        display.activeWeights=record.activeWeights(:)'; display.weightMode=char(record.weightMode);
        display.weightSource='已记录的固定权重';
        if isfield(record,'weightUpdateIteration') && isscalar(record.weightUpdateIteration) && isfinite(record.weightUpdateIteration)
            display.weightUpdateIteration=record.weightUpdateIteration;
        end
        if strcmp(display.weightMode,'violation-adaptive-v1')
            display.dynamicAvailable=true; display.dynamicTotal=sum(terms.*display.activeWeights(:));
            display.activeRows=[labels(:),num2cell(terms),num2cell(display.activeWeights(:)),num2cell(terms.*display.activeWeights(:))];
            display.weightSource='已记录的动态权重，按当前显示网格重评';
            if isfinite(display.weightUpdateIteration) && display.weightUpdateIteration>0
                display.weightSource=sprintf('更新用于第%d轮的实际权重，按当前显示网格重评',display.weightUpdateIteration);
            elseif display.weightUpdateIteration==0
                display.weightSource='已记录的初始实际权重，尚未进行轮次更新';
            end
        end
    end
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
    if all(isfield(history,{'weightMode','dynamicScore'})) && strcmp(history(k).weightMode,'violation-adaptive-v1') ...
            && isscalar(history(k).dynamicScore) && isfinite(history(k).dynamicScore)
        display.dynamicX(end+1)=x; display.dynamicY(end+1)=history(k).dynamicScore;
    end
end
if isstruct(info) && isfield(info,'returnedObjective'), display.objectiveValue=info.returnedObjective; end
end
function valid=validWeights(weights)
valid=isnumeric(weights) && isreal(weights) && numel(weights)==6 && all(isfinite(weights(:))) && all(weights(:)>=0);
end

function data=camInspectionData(project,result,info,source)
% A displayed cam and its intersection locations always share one result and
% one sampling grid. No fine coordinates are attached to a coarse contour.
if nargin<3, info=[]; end
if nargin<4, source='current'; end
assert(ismember(source,{'current','refined'}),'cam:DisplaySource','未知凸轮显示来源。');
project.params.autoRatio=false; requestedGrid=[project.params.samples project.params.camSamples];
if strcmp(source,'refined')
    requestedGrid=min(20001,4*(requestedGrid-1)+1);
    if isstruct(info) && isfield(info,'verification') && isfield(info.verification,'refinedGrid')
        fine=info.verification.refinedGrid;
        if isfield(fine,'routeSamples') && isfield(fine,'camSamples')
            requestedGrid=[fine.routeSamples fine.camSamples];
        end
    end
    project.params.samples=requestedGrid(1); project.params.camSamples=requestedGrid(2);
    result=camdesign.evaluate(project,true);
else
    assert(~isempty(result),'cam:NoDisplayResult','当前尚无已计算的凸轮。');
end
checked=isfield(result.metrics,'geometryChecked') && result.metrics.geometryChecked;
if checked
    if ~isfield(result,'intersectionPairs') || ~isfield(result,'intersectionPoints')
        [result.intersectionPairs,result.intersectionPoints]=camdesign.selfIntersections(result.cam.actual);
    end
else
    result.intersectionPairs=zeros(0,2); result.intersectionPoints=zeros(0,2);
end
assert(size(result.intersectionPairs,1)==size(result.intersectionPoints,1),'cam:DisplaySource','交点与轮廓来源不一致。');
grid=[numel(result.route.u),size(result.cam.actual,1)];
name='当前网格'; if strcmp(source,'refined'), name='加密复查'; end
status='自交未完整检查';
if checked, status=sprintf('实际自交 %d 对',size(result.intersectionPairs,1)); end
data=struct('project',project,'result',result,'source',source,'grid',grid,'checked',checked, ...
    'shortLabel',sprintf('%s · 凸轮%d点',name,grid(2)), ...
    'label',sprintf('%s：路线%d / 凸轮%d；固定传动比 %.6g；%s',name,grid(1),grid(2),project.params.gearRatio,status));
end

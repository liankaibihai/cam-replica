function spec=cam_app_ui_spec(key)
% Closed, data-only manifest of this App's persistent UI actions.
rows={ ...
 'closeRequested','closeRequested','fixed',{};
 'resizeLayout','resizeLayout','fixed',{};
 'routeEditorKey','routeEditorKey','event',{};
 'routePointerMove','routePointerMove','fixed',{};
 'route-click','routeMapClick','route-point',{};
 'routeModelChanged','routeModelChanged','fixed',{};
 'algorithmChanged','algorithmChanged','fixed',{};
 'invalidate','invalidate','fixed',{};
 'openTraining','openTraining','fixed',{};
 'openContestGeometry','openContestGeometry','fixed',{};
 'target-insert','modifyPoints','fixed',{'target',1};
 'target-delete','modifyPoints','fixed',{'target',-1};
 'node-insert','modifyPoints','fixed',{'node',1};
 'node-delete','modifyPoints','fixed',{'node',-1};
 'target-select','selectPoint','event',{'target'};
 'node-select','selectPoint','event',{'node'};
 'refineRoute','refineRoute','fixed',{};
 'dynamicWeightsChanged','dynamicWeightsChanged','fixed',{};
 'markTrainingDirty','markTrainingDirty','fixed',{};
 'applyTraining','applyTraining','fixed',{};
 'syncTrainingInputs','syncTrainingInputs','fixed',{};
 'force-model-switch','applyTraining','fixed',{true};
 'restoreModelSwitch','restoreModelSwitch','fixed',{};
 'beginRouteEditing','beginRouteEditing','fixed',{};
 'confirmRouteNode','confirmRouteNode','fixed',{};
 'cancelRouteEditing','cancelRouteEditing','fixed',{};
 'updateDiagnostics','updateDiagnostics','fixed',{};
 'details-score','openDiagnostics','fixed',{'score'};
 'details-log','openDiagnostics','fixed',{'log'};
 'details-crossings','openDiagnostics','fixed',{'crossings'};
 'checkActualClosure','checkActualClosure','fixed',{};
 'contestGeometryChanged','contestGeometryChanged','fixed',{};
 'checkContestGeometry','checkContestGeometry','fixed',{};
 'contest-body','locateContestGeometry','fixed',{'body'};
 'contest-target','locateContestGeometry','fixed',{'target'};
 'selectContestGeometryTarget','selectContestGeometryTarget','event',{};
 'changeCamSource','changeCamSource','value',{};
 'zoomCamCrossing','zoomCamCrossing','fixed',{};
 'resetCamView','resetCamView','fixed',{};
 'selectCamCrossing','selectCamCrossing','event',{} };
% These three App UI actions are handled by the external async service.
rows(end+1,:)={'execution-background','setExecutionMode','fixed',{'background'}};
rows(end+1,:)={'execution-foreground','setExecutionMode','fixed',{'foreground'}};
rows(end+1,:)={'execution-force-cancel','forceCancelBackground','fixed',{}};
for action={'import','save','seed','calculate','optimize','stop','simulate','export'}
    rows(end+1,:)={['action/' action{1}],'action','fixed',action}; %#ok<AGROW>
end
spec=cell2struct(rows,{'key','method','mode','fixedArguments'},2);
if nargin>0
    index=find(strcmp({spec.key},key));
    assert(isscalar(index),'cam:CallbackKey','未知或歧义的界面回调键：%s',key); spec=spec(index);
end
end

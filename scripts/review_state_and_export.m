function review=review_state_and_export()
% Find-only diagnostics. All writes remain in this independent review folder.
root=fileparts(fileparts(mfilename('fullpath'))); addpath(root); folder=fullfile(root,'local','review_20261031_executor'); if ~isfolder(folder), mkdir(folder); end
assert(batchStartupOptionUsed);
app=CamReplicaApp('off'); cleaner=onCleanup(@()closeOwn(app));
p=camdesign.defaultProject(); p.params.mechanism='flat'; p.params.gearRatio=35;
p.params.sensorX=0; p.params.sensorY=0; p.params.samples=101; p.params.camSamples=181;
p.params.bounds=[0 1000 0 1000]; p.nodes=[200 200;200 450;200 700]; p.targets=p.nodes;
app.Project=p; app.syncInputs(); app.calculate();
app.beginRouteEditing(); app.routeMapClick(app.Project.nodes(2,:),app.RouteAxes);
app.previewRouteNode(app.Project.nodes(2,:)+[.001 0],app.RouteAxes); app.confirmRouteNode();
review.map=struct('editFinished',~app.MapEditMode,'currentByPredicate',app.diagnosticsAreCurrent(), ...
    'displayState',app.ScoreDisplayData.state,'fineSelectorEnable',app.CrossSource.Enable);
assert(review.map.editFinished && review.map.currentByPredicate ...
    && contains(review.map.displayState,'历史') && strcmp(review.map.fineSelectorEnable,'off'));
fprintf('REVIEW_MAP_FINISH current=%d state=%s fineSelector=%s\n',review.map.currentByPredicate,review.map.displayState,review.map.fineSelectorEnable);

[bs,~]=camdesign.toBSpline(p,8,5); app.Project=bs; app.syncInputs(); app.calculate();
app.AlgorithmSelector.Value='auto-tune-v1'; callback=app.AlgorithmSelector.ValueChangedFcn; cam_invoke_ui_callback(callback,app.AlgorithmSelector,[]);
before=app.Project; app.action('seed');
review.failedSeed=struct('beforeModel',camdesign.routeModel(before.params), ...
    'afterModel',camdesign.routeModel(app.Project.params),'dropdown',app.TrainingModel.Value, ...
    'projectCount',size(app.Project.nodes,1),'tableCount',size(app.NodesTable.Data,1), ...
    'metadataLost',~isfield(app.Project.params,'bspline'),'lastLog',app.FullLog{end});
assert(strcmp(review.failedSeed.afterModel,'cubic') && strcmp(review.failedSeed.dropdown,'bspline-5') ...
    && review.failedSeed.projectCount~=review.failedSeed.tableCount && review.failedSeed.metadataLost);
fprintf('REVIEW_FAILED_SEED before=%s after=%s dropdown=%s projectCount=%d tableCount=%d metadataLost=%d\n', ...
    review.failedSeed.beforeModel,review.failedSeed.afterModel,review.failedSeed.dropdown, ...
    review.failedSeed.projectCount,review.failedSeed.tableCount,review.failedSeed.metadataLost);
filename=fullfile(folder,'failed_seed_saved.mat'); app.action('save',filename);
reloaded=camdesign.importProject(filename);
review.failedSeed.savedModel=camdesign.routeModel(reloaded.params);
review.failedSeed.savedOriginalCoefficientsAsInterpolationNodes=isequal(reloaded.nodes,before.nodes);
assert(strcmp(review.failedSeed.savedModel,'cubic') && review.failedSeed.savedOriginalCoefficientsAsInterpolationNodes);
fprintf('REVIEW_FAILED_SEED_SAVE model=%s originalCoefficientsReused=%d\n', ...
    review.failedSeed.savedModel,review.failedSeed.savedOriginalCoefficientsAsInterpolationNodes);

outside=p; outside.nodes(:,1)=60; outside.targets=outside.nodes;
result=camdesign.evaluate(outside,true); [~,boundary]=camdesign.trajectoryBounds(result.route,outside.params.bounds);
paths=camdesign.exportResult(outside,result,fullfile(folder,'export_outside'));
exported=jsondecode(fileread(paths.report));
review.export=struct('actualTrajectoryOutsideMM',boundary.maximumOutsideMM, ...
    'physicalBoundsSatisfied',boundary.satisfied,'warningCount',numel(exported.warnings), ...
    'hasBoundsResult',isfield(exported,'trajectoryBounds') || isfield(exported.metrics,'trajectoryBoundsSatisfied') ...
        || isfield(exported.metrics,'maxTrajectoryOutsideMM'),'status',exported.status);
assert(~review.export.physicalBoundsSatisfied && review.export.actualTrajectoryOutsideMM>19 ...
    && review.export.warningCount==0 && ~review.export.hasBoundsResult);
fprintf('REVIEW_EXPORTED_BOUNDS outsideMM=%.9g warnings=%d boundsResult=%d status=%s\n', ...
    review.export.actualTrajectoryOutsideMM,review.export.warningCount,review.export.hasBoundsResult,review.export.status);
fid=fopen(fullfile(folder,'findings.json'),'w','n','UTF-8'); closeFile=onCleanup(@()fclose(fid));
fprintf(fid,'%s\n',jsonencode(review,PrettyPrint=true));
end
function closeOwn(app)
if ~isempty(app.DiagnosticsFigure) && isgraphics(app.DiagnosticsFigure), delete(app.DiagnosticsFigure); end
if isgraphics(app.Figure), delete(app.Figure); end
end

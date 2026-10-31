function report=check_force_model_switch()
% Explicit approximate fitting and target rebuilding, without optimization.
assert(batchStartupOptionUsed,'cam:BatchOnly','Use independent MATLAB batch.');
root=fileparts(mfilename('fullpath')); folder=fullfile(root,'outputs','force_model_switch_20261031','core');
if ~isfolder(folder), mkdir(folder); end
saved=load(fullfile(root,'outputs','model_mapping_20261031','quality_cubic','result.mat'),'q'); source=saved.q; original=source;
strict=expect(@()camdesign.mapRouteModel(source,'bezier-blend-independent-v1',34,15),'cam:RouteMappingTolerance');
[forced,fit]=camdesign.mapRouteModel(source,'bezier-blend-independent-v1',34,15,AllowApproximate=true);
assert(fit.forced && fit.approximate && ~fit.withinTolerance && ~fit.shapePreservationGuaranteed);
assert(fit.finiteGeometry && fit.endpointConstraintsSatisfied && strcmp(fit.acceptance,'forced-approximate'));
assert(fit.actualControlPointCount==250 && isequaln(source,original));
assert(isequal(forced.nodes(1,:),source.nodes(1,:)) && isequaln(forced.targets,source.targets));
assert(forced.params.gearRatio==35 && forced.params.maxPressureDeg==source.params.maxPressureDeg);
u=linspace(0,fit.parameterLength,32003)'; [F,V]=camdesign.routeGeometry(source.nodes,source.params,u);
[Q,W]=camdesign.routeGeometry(forced.nodes,forced.params,u);
observed=struct('positionMaxMM',max(vecnorm(Q-F,2,2)),'positionRMSMM',sqrt(mean(sum((Q-F).^2,2))), ...
    'maxTangentErrorDeg',max(rad2deg(atan2(abs(V(:,1).*W(:,2)-V(:,2).*W(:,1)),sum(V.*W,2)))));
assert(observed.maxTangentErrorDeg>.05 && observed.positionMaxMM<1 && observed.maxTangentErrorDeg<2);
assert(~isequal(forced.nodes,source.nodes));
checks={'real solar cubic to Bezier15 rejects strict cap250 then accepts explicit finite endpoint-constrained approximate fit with truthful errors'};

[~,identity]=camdesign.mapRouteModel(source,'cubic',size(source.nodes,1),3,AllowApproximate=true);
assert(identity.withinTolerance && ~identity.forced && ~identity.approximate && strcmp(identity.acceptance,'exact'));
line=fixture(); [mapped,bounded]=camdesign.mapRouteModel(line,'bezier-blend-independent-v1',8,5,AllowApproximate=true);
assert(bounded.withinTolerance && ~bounded.forced && bounded.approximate && strcmp(bounded.acceptance,'within-tolerance'));
assert(mapped.params.bezier.degree==5);
checks{end+1}='identity/exact and tolerance-passing fits never falsely marked as forced';

bad=source; bad.nodes(3,1)=NaN;
expectAny(@()camdesign.mapRouteModel(bad,'bezier-blend-independent-v1',34,15,AllowApproximate=true));
[bs,~]=camdesign.mapRouteModel(line,'bspline-v1',8,3); badEnd=bs; badEnd.nodes(2,1)=badEnd.nodes(2,1)+1;
expect(@()camdesign.mapRouteModel(badEnd,'bezier-blend-independent-v1',8,5,AllowApproximate=true),'cam:EndpointConstraint');
expectAny(@()camdesign.applyTrainingSettings(source,struct('bezierDegree',50,'routeModel','bezier-blend-independent-v1'), ...
    'peak-gradient-v2',struct('AllowApproximate',true)));
expectAny(@()camdesign.applyTrainingSettings(source,struct('gradientForce',NaN),'peak-gradient-v2',struct('AllowApproximate',true)));
expect(@()camdesign.mapRouteModel(source,'bezier-blend-independent-v1',34,15,AllowApproximate=true,PositionMaxToleranceMM=1), ...
    'cam:RouteMappingToleranceSettings');
expect(@()camdesign.applyTrainingSettings(source,struct(),'auto-tune-v1',struct('AllowApproximate',true)),'cam:ForceManualOnly');
assert(isequaln(source,original));
checks{end+1}='force cannot bypass nonfinite inputs, endpoint constraints, invalid settings or automatic model lock';

changes=struct('routeModel','bezier-blend-independent-v1','controlPointCount',34,'bezierDegree',15,'interpolationPerSegment',10);
[applied,info]=camdesign.applyTrainingSettings(source,changes,'peak-gradient-v2',struct('AllowApproximate',true,'MaxControlPoints',34));
assert(info.forced && ~info.fitInfo.withinTolerance && ~isfield(applied,'routeMapping'));
% Persistence belongs to explicit UI operations; the general training
% adapter must not change project-level metadata used by automatic locks.
applied.routeMapping=info.fitInfo;
file=fullfile(folder,'forced_project.mat'); camdesign.saveProject(applied,file); imported=camdesign.importProject(file);
assert(isequaln(applied,imported));
checks{end+1}='explicit adapter exposes/persists forced metadata and complete saved project roundtrips';

[rebuilt,rebuildInfo]=camdesign.rebuildRoute(applied,changes,'peak-gradient-v2');
assert(strcmp(camdesign.routeModel(rebuilt.params),'bezier-blend-independent-v1') && rebuilt.params.bezier.degree==15);
assert(~isfield(rebuilt,'routeMapping') && rebuildInfo.rebuiltFromTargets && ~rebuildInfo.shapePreservationGuaranteed);
assert(isequal(rebuilt.nodes(1,:),applied.nodes(1,:)) && isequal(rebuilt.targets,applied.targets));
assert(isequal(rebuilt.params.gearRatio,source.params.gearRatio) && rebuilt.params.samples==331);
for mode={'bspline-3','bspline-5'}
    new=camdesign.rebuildRoute(source,struct('routeModel',mode{1},'controlPointCount',34), ...
        'fmincon-interior-point-experimental-v1'); camdesign.validateProject(new);
    assert(isequal(new.nodes(1,:),source.nodes(1,:)) && isequal(new.targets,source.targets));
end
checks{end+1}='rebuilding directly seeds selected Bezier15/B3/B5 from targets independently of old-curve mapping';

seed=camdesign.seedNodes(source.targets,source.params); seed(1,:)=source.nodes(1,:);
new=camdesign.rebuildRoute(source,struct('routeModel','cubic','controlPointCount',size(seed,1),'interpolationPerSegment',20));
assert(isequal(new.nodes,seed));
denser=camdesign.rebuildRoute(source,struct('routeModel','cubic','controlPointCount',size(seed,1)+7,'interpolationPerSegment',20));
base=new; [~,~,s]=camdesign.routeSpline(base.nodes,base.params); query=linspace(0,s(end),4001)';
assert(max(vecnorm(camdesign.routeGeometry(base.nodes,base.params,query)-camdesign.routeGeometry(denser.nodes,denser.params,query),2,2))<1e-8);
assert(all(ismember(seed,denser.nodes,'rows')));
expect(@()camdesign.rebuildRoute(bs,struct(),'auto-tune-v1'),'cam:BSplineBackend');
bad=source; bad.params.wheelDiameter=-1; expectAny(@()camdesign.rebuildRoute(bad,changes));
expectAny(@()camdesign.rebuildRoute(source,struct('controlPointCount',251)));
assert(isequaln(source,original));
checks{end+1}='new cubic retains all target seeds and exact extra refinement; illegal rebuilds preserve source and backend gate';

report=struct('release',version('-release'),'baseline','f069152','checksPassed',numel(checks),'checks',{checks}, ...
    'strictIdentifier',strict,'forcedFit',fit,'independentGrid',observed,'rebuild',rebuildInfo, ...
    'scope','Geometry/representation and persistence contracts; no optimization, physical feasibility or exact reproduction of an unavailable user MAT.');
save(fullfile(folder,'results.mat'),'report','source','forced','applied','rebuilt');
fid=fopen(fullfile(folder,'verification.json'),'w','n','UTF-8'); closer=onCleanup(@()fclose(fid));
fprintf(fid,'%s\n',jsonencode(report,PrettyPrint=true));
fprintf('FORCE_MODEL_SWITCH_CORE_PASS checks=%d solar15 controls=%d max/RMS=%.12g/%.12g mm tangent=%.12g deg\n', ...
    numel(checks),fit.actualControlPointCount,fit.positionMaxMM,fit.positionRMSMM,fit.maxTangentErrorDeg);
end
function id=expect(callback,wanted)
id=''; try, callback(); catch ex, id=ex.identifier; end
assert(strcmp(id,wanted),'Expected %s, received %s.',wanted,id);
end
function expectAny(callback)
failed=false; try, callback(); catch, failed=true; end; assert(failed);
end
function p=fixture()
p=camdesign.defaultProject(); p.params.mechanism='flat'; p.params.gearRatio=35;
p.params.sensorX=0; p.params.sensorY=0; p.params.bounds=[0 1000 0 1000];
p.params.samples=101; p.params.camSamples=181;
p.nodes=[200 200;200 450;200 700]; p.targets=p.nodes;
end

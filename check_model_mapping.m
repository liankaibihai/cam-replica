function report=check_model_mapping()
% Pure geometry contracts; never infer cam/vehicle feasibility from a fit.
root=fileparts(mfilename('fullpath')); addpath(root);
assert(batchStartupOptionUsed,'cam:MappingBatch','Use independent MATLAB batch.');
folder=fullfile(root,'outputs','model_mapping_20261031','contracts'); if ~isfolder(folder), mkdir(folder); end
checks={}; fits={};
p=fixture(); s=[0;250;500]; p.nodes=[200+1e-5*s.^2,200+s-1e-7*s.^3];
p.params.routeSpline=struct('type','fixed-clamped-cubic-v1','stations',s,'endDerivative',[.01 .925]);
for d=[3 5]
    [q,f]=camdesign.mapRouteModel(p,'bspline-v1',8,d);
    assert(f.shapePreservationGuaranteed && f.mathematicallyExactSpace && f.positionMaxMM<1e-8);
    inspect(p,q,f); fits{end+1}=f;
    [c,back]=camdesign.mapRouteModel(q,'cubic',3); inspect(q,c,back);
end
[dense,f]=camdesign.setControlPointCount(p,10); inspect(p,dense,f.fitInfo);
assert(f.shapePreservationGuaranteed && size(dense.nodes,1)==10);
checks{end+1}='exact clamped cubic refinement and cubic-to-standard-B3/B5 space embeddings, with independent roundtrip geometry checks';

line=fixture(); [b,f]=camdesign.mapRouteModel(line,'bezier-blend-independent-v1',8,5); inspect(line,b,f);
b.nodes(4,1)=b.nodes(4,1)+.1;
[other,f]=camdesign.mapRouteModel(b,'bezier-blend-independent-v1',8,3);
assert(~f.shapePreservationGuaranteed && f.withinTolerance && other.params.bezier.degree==3); inspect(b,other,f); fits{end+1}=f;
[cubic,f]=camdesign.mapRouteModel(b,'cubic',8); inspect(b,cubic,f); fits{end+1}=f;
[more,f]=camdesign.setControlPointCount(b,18); inspect(b,more,f.fitInfo);
assert(isequal(more.nodes(1,:),b.nodes(1,:)));
checks{end+1}='Bezier degree/count and Bezier-to-cubic use actual curve fits; no false exact-preservation claim and launch point remains bitwise fixed';

solar=camdesign.solarTestProject(); solar=camdesign.refineRoute(camdesign.refineRoute(solar));
before=solar; outcomes=cell(1,3); targets={'bezier-blend-independent-v1','bspline-v1','bspline-v1'}; degrees=[5 3 5];
for k=1:3
    try
        [q,f]=camdesign.mapRouteModel(solar,targets{k},34,degrees(k)); inspect(solar,q,f);
        outcomes{k}=struct('accepted',true,'fitInfo',f); fits{end+1}=f;
    catch ex
        assert(strcmp(ex.identifier,'cam:RouteMappingTolerance'),'Unexpected mapping failure: %s',ex.message);
        outcomes{k}=struct('accepted',false,'identifier',ex.identifier,'message',ex.message);
    end
    assert(isequaln(solar,before));
end
% Historical 34-control independent blend, deliberately constructed as the
% old project representation to test a real degree-change source geometry.
legacy=solar; legacy.params=rmfield(legacy.params,'routeSpline'); legacy.params.routeModel='bezier-blend-independent-v1';
[~,~,stations]=camdesign.routeSpline(solar.nodes,solar.params);
legacy.params.bezier=struct('type','overlap-bernstein-v1','degree',5,'parameterLength',stations(end));
try
    [q,f]=camdesign.mapRouteModel(legacy,'bezier-blend-independent-v1',34,3); inspect(legacy,q,f);
    assert(~f.shapePreservationGuaranteed); legacyOutcome=struct('accepted',true,'fitInfo',f); fits{end+1}=f;
catch ex
    assert(strcmp(ex.identifier,'cam:RouteMappingTolerance')); legacyOutcome=struct('accepted',false,'identifier',ex.identifier,'message',ex.message);
end
checks{end+1}='formal solar model/degree conversions either meet max/RMS/full-tangent gates or explicitly reject without returning an altered source';

rejected=false;
try, camdesign.mapRouteModel(solar,'bezier-blend-independent-v1',6,5,MaxControlPoints=6);
catch ex, rejected=strcmp(ex.identifier,'cam:RouteMappingTolerance'); end
assert(rejected && isequaln(solar,before));
rejected=false;
try, camdesign.mapRouteModel(p,'cubic',3,3,PositionMaxToleranceMM=1);
catch ex, rejected=strcmp(ex.identifier,'cam:RouteMappingToleranceSettings'); end
assert(rejected);
% The product application adapter exposes fitInfo and actual expanded count.
[q,info]=camdesign.applyTrainingSettings(p,struct('routeModel','bspline-5','controlPointCount',8), ...
    'fmincon-interior-point-experimental-v1');
assert(info.fitInfo.withinTolerance && info.shapePreservationGuaranteed && size(q.nodes,1)==info.controlPoints.actualCount);
assert(info.fitInfo.actualControlPointCount==size(q.nodes,1) && info.fitInfo.automaticallyIncreasedCount);
assert(q.params.gearRatio==p.params.gearRatio && q.params.hitTolerance==p.params.hitTolerance);
checks{end+1}='insufficient-cap mapping rejects atomically; application returns measured fitInfo and truthful automatic control count';

report=struct('release',version('-release'),'checks',{checks},'fits',{fits},'solarOutcomes',{outcomes}, ...
    'historicalBezierDegreeChange',legacyOutcome,'scope','Geometry and product-adapter contracts; no cam, RFID, convergence or real-car acceptance.');
save(fullfile(folder,'model_mapping.mat'),'report','solar','b','-v7');
fid=fopen(fullfile(folder,'model_mapping.json'),'w','n','UTF-8'); closer=onCleanup(@()fclose(fid));
fprintf(fid,'%s\n',jsonencode(report,PrettyPrint=true));
for k=1:numel(checks), fprintf('MODEL_MAPPING_CASE_PASS %s\n',checks{k}); end
fprintf('MODEL_MAPPING_PASS cases=%d\n',numel(checks));
end
function inspect(source,target,f)
if strcmp(camdesign.routeModel(source.params),'cubic'), [~,~,s]=camdesign.routeSpline(source.nodes,source.params); T=s(end);
elseif strcmp(camdesign.routeModel(source.params),'bspline-v1'), T=source.params.bspline.parameterLength;
else, T=source.params.bezier.parameterLength; end
u=linspace(0,T,32003)'; [F,V]=camdesign.routeGeometry(source.nodes,source.params,u); [P,W]=camdesign.routeGeometry(target.nodes,target.params,u);
angle=rad2deg(atan2(abs(V(:,1).*W(:,2)-V(:,2).*W(:,1)),sum(V.*W,2)));
assert(max(vecnorm(F-P,2,2))<=.05+1e-6 && sqrt(mean(sum((F-P).^2,2)))<=.01+1e-6 && max(angle)<=.05+1e-6);
assert(f.withinTolerance && max(f.endpointTangentErrorDeg)<=1e-5 && f.firstPointErrorMM<=1e-7);
assert(isequal(source.nodes(1,:),target.nodes(1,:)) && isequaln(source.targets,target.targets));
end
function p=fixture()
p=camdesign.defaultProject(); p.params.mechanism='flat'; p.params.gearRatio=35;
p.params.sensorX=0; p.params.sensorY=0; p.params.bounds=[0 1000 0 1000];
p.params.samples=101; p.params.camSamples=181;
p.nodes=[200 200;200 450;200 700]; p.targets=p.nodes;
end

function report=check_path_method_comparison(action,seedIds,methodIds)
% Paired representation experiment, solar preliminary flat car, fixed ratio35.
% Independent MATLAB batch only. Completed evidence is resumed, never replaced.
if nargin<1, action='run'; end
if nargin<2, seedIds=1:5; end
if nargin<3, methodIds=1:4; end
assert(batchStartupOptionUsed,'cam:BatchOnly','Use an independent batch instance.');
assert(ismember(action,{'run','prepare','summary','continue','audit-contract','storage-contract'}),'cam:ComparisonAction','Unknown comparison action.');
if strcmp(action,'audit-contract'), report=auditContract(); return; end
if strcmp(action,'storage-contract'), report=storageContract(); return; end
root=fileparts(mfilename('fullpath'));
baseFolder=fullfile(root,'outputs','path_comparison_20261031'); folder=baseFolder;
if strcmp(action,'continue'), folder=fullfile(baseFolder,'continuation_2x'); end
if ~isfolder(folder), mkdir(folder); end
names={'cubic','bezier5','bspline3','bspline5'};
baseline=camdesign.solarTestProject();
baseline=camdesign.refineRoute(camdesign.refineRoute(baseline));
baseline.params.samples=601; baseline.params.camSamples=721;
baseline.params.iterations=600;
baseline.params.controlBoundsPolicy='trajectory-only-v1';
[~,~,stations,endD]=camdesign.routeSpline(baseline.nodes,baseline.params);
count=size(baseline.nodes,1); dof=2*(count-1);
protocol=struct('version','paired-path-representation-v1','course','2027 solar preliminary ordered 10 visits', ...
    'mechanism','flat','gearRatio',35,'commonGrid',[601 721],'refinedGrids',[2401 2881;4801 5761], ...
    'methods',{names},'pairedSeeds',1:5,'effectiveDOF',dof,'requestedIterations',600, ...
    'maxFunctionEvaluations',50000,'maxSeconds',3600,'solver','fmincon-interior-point', ...
    'differenceStepMM',.1,'regularizationWeight',0,'weights',baseline.params.weights, ...
    'endDerivative',endD,'startPose',[baseline.nodes(1,:) baseline.params.headingDeg baseline.params.startSteeringDeg], ...
    'initialization','Seed1 original; seeds2-5 paired smooth 20mm sine perturbations before representation fitting.', ...
    'scope','Same discrete physics and constraints; unmeasured hardware defaults; no original software or vehicle equivalence.');
protocol.stage='primary';
protocol.physicalInput=physicalInput(baseline);
if strcmp(action,'continue')
    protocol.stage='diagnostic-2x-continuation'; protocol.commonGrid=[1201 1441];
    protocol.initialization='Continue saved primary candidates with 2x training density, same physical thresholds and common 4x/8x verification. Not a new paired initialization experiment.';
end
protocolFile=fullfile(folder,'protocol.json');
if isfile(protocolFile)
    assertProtocol(jsondecode(fileread(protocolFile)),protocol);
else
    writeJSON(protocolFile,protocol);
end
if strcmp(action,'summary'), report=summarize(folder,names); return; end
preparation=struct([]);
for seed=seedIds
    rng(20261031+seed,'twister'); source=baseline;
    if seed>1
        t=stations/stations(end); a=randn(3,2); a=a./vecnorm(a,2,1);
        offset=zeros(numel(t),2);
        for k=1:3, offset=offset+sin(k*pi*t)*a(k,:)/k; end
        source.nodes=source.nodes+20*offset;
    end
    for method=methodIds
        label=sprintf('seed%d_%s',seed,names{method});
        file=fullfile(folder,[label '.mat']);
        if ~strcmp(action,'prepare')
            lockFolder=[file '.lock']; lock=java.io.File(lockFolder);
            assert(lock.mkdir(),'cam:RunLocked','Run already owned or stale lock: %s',lockFolder);
            lockCleaner=onCleanup(@()rmdir(lockFolder));
            % Completion may happen immediately before lock acquisition.
            % Both recovery and new writes belong to this same exclusive region.
            if isfile(file)
                restoreSavedRecord(file,protocol,label);
                fprintf('RESUME validated %s\n',label); clear lockCleaner; continue;
            end
        end
        if strcmp(action,'continue')
            prior=load(fullfile(baseFolder,[label '.mat']),'q','fit');
            project=prior.q; fit=prior.fit;
            project.params.samples=1201; project.params.camSamples=1441;
        else
            [project,fit]=convert(source,method,count,endD);
        end
        fit.effectiveDOF=dof;
        compareSource=source; compareSource.params.samples=project.params.samples;
        sourceRoute=camdesign.route(compareSource.nodes,compareSource.params);
        fittedRoute=camdesign.route(project.nodes,project.params);
        if strcmp(action,'continue')
            fit=struct('primaryRepresentationFit',prior.fit,'effectiveDOF',dof, ...
                'positionRMSMM',sqrt(mean(sum((fittedRoute.front-sourceRoute.front).^2,2))), ...
                'positionMaxMM',max(vecnorm(fittedRoute.front-sourceRoute.front,2,2)), ...
                'positionCheckSamples',project.params.samples, ...
                'scope','Continuation initial geometry versus original paired source; primary representation fit kept separately.');
        end
        fit.steeringMaxDifferenceDeg=rad2deg(max(abs(fittedRoute.steering-sourceRoute.steering)));
        fit.sensorMaxDifferenceMM=max(vecnorm(fittedRoute.sensor-sourceRoute.sensor,2,2));
        before=camdesign.verifyConstrained(project,4);
        entry=struct('label',label,'fit',fit,'initial',before.optimizationGrid);
        if isempty(preparation), preparation=entry; else, preparation(end+1)=entry; end %#ok<AGROW>
        fprintf('PREP %s n=%d dof=%d fitRMS=%.6g fitMax=%.6g valid=%d pressure=%.5g\n', ...
            label,size(project.nodes,1),dof,fit.positionRMSMM,fit.positionMaxMM,before.optimizationGrid.valid,metric(before.optimizationGrid,'maxPressureDeg'));
        assert(before.optimizationGrid.valid,'cam:BenchmarkInitial','Invalid initial %s: %s',label,before.optimizationGrid.errorMessage);
        if strcmp(action,'prepare'), auditPressure(project); continue; end
        wall=tic;
        [q,h,info]=camdesign.optimizeFmincon(project,@checkpoint, ...
            Algorithm='interior-point',DifferenceStepMM=.1,MaxSeconds=3600, ...
            MaxFunctionEvaluations=50000,RefinementFactor=4,RegularizationWeight=0,EndDerivative=endD);
        solverWall=toc(wall);
        save(fullfile(folder,[label '_solver.mat']),'project','source','q','h','info','fit','protocol','-v7');
        assert(info.freeVariables==dof,'cam:BenchmarkDOF','Effective DOF mismatch: %s',label);
        assert(q.params.gearRatio==35 && isequal(q.params,project.params),'cam:BenchmarkHardware','Parameters changed.');
        assessment=camdesign.autoTuneAssessment(q,[601 721]);
        pressureAudit=auditPressure(q);
        record=struct('label',label,'seed',seed,'method',names{method},'fit',fit, ...
            'iterations',info.iterations,'requestedIterations',info.requestedIterations,'reason',info.reason, ...
            'modelAttempts',info.evaluations,'solverFunctionCount',info.solverOutput.funcCount, ...
            'solverSeconds',info.solverSeconds,'backendWallSeconds',solverWall,'effectiveDOF',info.freeVariables, ...
            'initial',before.optimizationGrid,'final',assessment.eight.refinedGrid, ...
            'stable',assessment.convergencePassed,'discreteFeasible',assessment.verifiedFeasible, ...
            'pressureAudit',pressureAudit,'verifiedFeasible',assessment.verifiedFeasible && pressureAudit.passed, ...
            'convergenceDelta',assessment.delta,'numericalChecks',assessment.numericalChecks, ...
            'last50ViolationImprovement',tailImprovement(h), ...
            'totalWallSeconds',toc(wall));
        save(file,'project','source','q','h','info','fit','record','assessment','protocol','-v7');
        writeJSON(fullfile(folder,[label '.json']),record);
        clear lockCleaner;
        fprintf('DONE %s iter=%d eval=%d reason=%s feasible=%d stable=%d pressure=%.5f exactPPPressure=%.5f hit=%.5f return=%.5f outside=%.5f\n', ...
            label,info.iterations,info.evaluations,info.reason,record.verifiedFeasible,record.stable, ...
            metric(record.final,'maxPressureDeg'),pressureAudit.maxPressureDeg,metric(record.final,'maxHitError'), ...
            metric(record.final,'actualReturnDeg'),record.final.maxTrajectoryOutsideMM);
    end
end
if ~isempty(preparation), writeJSON(fullfile(folder,'preparation.json'),preparation); end
report=summarize(folder,names);

    function stop=checkpoint(iter,q,h)
        stop=false;
        if mod(iter,25)~=0 && ~strcmp(h(end).event,'finished'), return; end
        hEnd=h(end);
        fprintf('PROGRESS %s iter=%d eval=%d violation=%.6g pressure=%.4f hit=%.4f return=%.4f\n', ...
            label,iter,hEnd.evaluations,hEnd.maxConstraintViolation,hEnd.metrics.maxPressureDeg, ...
            hEnd.metrics.maxHitError,hEnd.metrics.actualReturnDeg);
        save(fullfile(folder,[label '_checkpoint.mat']),'q','hEnd','-v7');
    end
end

function [q,fit]=convert(source,method,count,endD)
if method==1
    q=source; fit=struct('positionRMSMM',0,'positionMaxMM',0,'startDerivativeError',0,'endDerivativeError',0);
elseif method==2
    [px,py,stations]=camdesign.routeSpline(source.nodes,source.params);
    L=stations(end); n=count+1; degree=5;
    u=linspace(0,L,4001)'; F=[ppval(px,u),ppval(py,u)];
    scale=(n-1)/L; [B,~,~]=camdesign.independentBezierBasis(double(n),degree,u*scale);
    span=L*degree/(n-1); t=u/span; h=zeros(size(u)); active=t<=1;
    h(active)=span*t(active).*(1-t(active)).^4;
    desired=[cosd(source.params.headingDeg+source.params.startSteeringDeg),sind(source.params.headingDeg+source.params.startSteeringDeg)];
    A=B; A(:,1)=A(:,1)+h*scale; A(:,2)=A(:,2)-h*scale;
    E=zeros(2,n); E(1,1)=1; E(2,end-1:end)=[-scale scale];
    norms=vecnorm(E,2,2); E=E./norms;
    rhs=[source.nodes(1,:);endD]./norms;
    Z=null(E); particular=E'*((E*E')\rhs);
    q=source; q.nodes=particular+Z*((A*Z)\(F-h*desired-A*particular));
    q.params=rmfield(q.params,'routeSpline'); q.params.routeModel='bezier-blend-independent-v1';
    q.params.bezier=struct('type','overlap-bernstein-v1','degree',degree,'parameterLength',L);
    [P,V]=camdesign.bezierRoute(q.nodes,q.params,u); errorMM=vecnorm(P-F,2,2);
    fit=struct('positionRMSMM',sqrt(mean(errorMM.^2)),'positionMaxMM',max(errorMM), ...
        'startDerivativeError',norm(V(1,:)-desired),'endDerivativeError',norm(V(end,:)-endD));
else
    degree=3+2*(method==4); [q,rawFit]=camdesign.toBSpline(source,count+2,degree);
    [px,py,stations]=camdesign.routeSpline(source.nodes,source.params);
    u=linspace(0,stations(end),4001)'; F=[ppval(px,u),ppval(py,u)];
    [P,V]=camdesign.routeGeometry(q.nodes,q.params,u); errorMM=vecnorm(P-F,2,2);
    desired=[cosd(source.params.headingDeg+source.params.startSteeringDeg),sind(source.params.headingDeg+source.params.startSteeringDeg)];
    fit=struct('positionRMSMM',sqrt(mean(errorMM.^2)),'positionMaxMM',max(errorMM), ...
        'startDerivativeError',norm(V(1,:)-desired),'endDerivativeError',norm(V(end,:)-endD),'conversion',rawFit);
end
camdesign.validateProject(q);
end

function audit=auditPressure(project)
% All stationary points of |q'/q| on the final 8x piecewise-polynomial law.
% This closes uniform PHASE-grid misses on that law, not continuous vehicle error.
project.params.samples=4801; project.params.camSamples=5761;
try
    r=camdesign.evaluate(project,false); c=r.cam;
catch ex
    if ~ismember(ex.identifier,{'cam:Duplicate','cam:RouteSingularity','cam:ReverseWheel', ...
            'cam:ExtremeSteering','cam:GearRatio','cam:NegativeRadius','cam:ConstraintNonfinite'}), rethrow(ex); end
    audit=struct('maxPressureDeg',Inf,'phaseDeg',NaN,'minimumRadiusMM',NaN, ...
        'checkedPolynomialPoints',0,'passed',false,'scope',ex.identifier); return;
end
audit=auditCamLaw(c,project.params);
assert(audit.maxPressureDeg>=max(rad2deg(c.pressure))-1e-7,'cam:PressureExtrema','Analytic maximum missed a sampled value.');
end
function audit=auditCamLaw(c,p)
if isfield(c,'workPP'), pp=c.workPP; else, pp=spline(c.workPhi,c.workRadius); end
[breaks,coefs]=unmkpp(pp);
maxAlpha=0; peakPhi=NaN; minQ=Inf; count=0;
for k=1:size(coefs,1)+1
    if k<=size(coefs,1)
        origin=breaks(k); span=breaks(k+1)-origin;
        q=coefs(k,:).*span.^(size(coefs,2)-1:-1:0);
    else
        origin=c.workEnd; span=2*pi-origin; q=flipud(c.returnCoefficients)';
    end
    d=polyder(q); dd=polyder(d);
    stationary=polySubtract(conv(dd,q),conv(d,d));
    z=[0;1;realRoots01(stationary);realRoots01(d)];
    radius=polyval(q,z); minQ=min(minQ,min(radius));
    alpha=rad2deg(atan2(abs(polyval(d,z)/span),radius));
    [a,i]=max(alpha); if a>maxAlpha, maxAlpha=a; peakPhi=origin+span*z(i); end
    count=count+numel(z);
end
audit=struct('maxPressureDeg',maxAlpha,'phaseDeg',rad2deg(peakPhi),'minimumRadiusMM',minQ, ...
    'checkedPolynomialPoints',count,'passed',maxAlpha<=p.maxPressureDeg && minQ>p.rollerRadius+1e-6, ...
    'scope','Polynomial stationary roots and piece boundaries on 8x reconstructed cam law; does not certify exact continuous vehicle path or contact.');
end
function report=auditContract()
p=struct('maxPressureDeg',35,'rollerRadius',2);
c=struct('workPhi',linspace(0,pi,15)','workRadius',50*ones(15,1), ...
    'workEnd',pi,'returnCoefficients',[50;zeros(5,1)]);
a=auditCamLaw(c,p); assert(a.maxPressureDeg<1e-9 && abs(a.minimumRadiusMM-50)<1e-9);
c.workRadius=50+10*c.workPhi.^2; c.returnCoefficients=[50+10*pi^2;zeros(5,1)];
b=auditCamLaw(c,p); exact=rad2deg(atan(1/sqrt(5)));
assert(abs(b.maxPressureDeg-exact)<1e-8 && abs(deg2rad(b.phaseDeg)-sqrt(5))<1e-7);
c.workRadius=50*ones(15,1); c.returnCoefficients=[50;0;0;10;-15;6];
d=auditCamLaw(c,p); t=linspace(0,1,500001)';
q=polyval(flipud(c.returnCoefficients),t); der=polyval(polyder(flipud(c.returnCoefficients)'),t)/pi;
oracle=rad2deg(max(atan(abs(der)./q)));
assert(d.maxPressureDeg>=oracle-1e-10 && d.maxPressureDeg-oracle<1e-7);
% An explicit quintic working law must override poisoned legacy samples.
c.workPP=mkpp([0 pi],[.03 -.12 .2 .4 .5 50]); c.workRadius(:)=NaN;
e=auditCamLaw(c,p); phase=linspace(0,pi,500001)';
qq=ppval(c.workPP,phase); dq=ppval(camdesign.ppDerivative(c.workPP,1),phase);
workingOracle=rad2deg(max(atan(abs(dq)./qq)));
assert(abs(e.maxPressureDeg-max(workingOracle,oracle))<1e-7);
report=struct('constantPressureDeg',a.maxPressureDeg,'quadraticPressureDeg',b.maxPressureDeg, ...
    'quadraticExactDeg',exact,'returnPressureDeg',d.maxPressureDeg,'denseReturnOracleDeg',oracle, ...
    'explicitWorkPPPressureDeg',e.maxPressureDeg,'explicitWorkPPOracleDeg',max(workingOracle,oracle));
fprintf('PRESSURE_EXTREMA_CONTRACT_PASS constant/quadratic/quintic-return/explicit-work-law\n');
end
function c=polySubtract(a,b)
n=max(numel(a),numel(b)); c=[zeros(1,n-numel(a)),a]-[zeros(1,n-numel(b)),b];
end
function z=realRoots01(c)
threshold=max(abs(c))*1e-13; first=find(abs(c)>threshold,1);
if isempty(first), z=[]; return; end
v=roots(c(first:end)); z=real(v(abs(imag(v))<1e-7 & real(v)>0 & real(v)<1));
end
function value=tailImprovement(h)
first=max(1,numel(h)-50); value=h(first).maxConstraintViolation-h(end).maxConstraintViolation;
end
function v=metric(item,name)
v=NaN; if isstruct(item.metrics) && isfield(item.metrics,name), v=item.metrics.(name); end
end
function report=summarize(folder,names)
records=struct([]); groups=struct([]);
for m=1:numel(names)
    indices=[];
    for seed=1:5
        file=fullfile(folder,sprintf('seed%d_%s.json',seed,names{m}));
        if ~isfile(file), continue; end
        r=jsondecode(fileread(file));
        if isempty(records), records=r; else, records(end+1)=r; end %#ok<AGROW>
        indices(end+1)=numel(records); %#ok<AGROW>
    end
    if isempty(indices), continue; end
    rows=records(indices); pressure=arrayfun(@(x)finiteScalar(x.pressureAudit.maxPressureDeg,Inf),rows);
    group=struct('method',names{m},'runs',numel(rows),'feasible',sum([rows.verifiedFeasible]), ...
        'stable',sum([rows.stable]),'pressureMedianDeg',median(pressure),'pressureBestDeg',min(pressure), ...
        'medianSeconds',median([rows.solverSeconds]),'modelAttempts',sum([rows.modelAttempts]));
    if isempty(groups), groups=group; else, groups(end+1)=group; end %#ok<AGROW>
end
report=struct('protocol',jsondecode(fileread(fullfile(folder,'protocol.json'))),'groups',groups,'runs',records);
writeJSON(fullfile(folder,'summary.json'),report);
end
function value=finiteScalar(value,fallback)
if ~isnumeric(value) || ~isscalar(value) || ~isfinite(value), value=fallback; end
end
function restoreSavedRecord(file,requested,label)
saved=load(file,'record','protocol','project');
assert(all(isfield(saved,{'record','protocol','project'})),'cam:IncompleteRun','Incomplete MAT: %s',file);
assertProtocol(saved.protocol,requested);
assertPhysical(physicalInput(saved.project),requested.physicalInput);
assert(strcmp(saved.record.label,label),'cam:RunIdentity','Mismatched saved run.');
[folder,name]=fileparts(file); writeJSON(fullfile(folder,[name '.json']),saved.record);
end
function report=storageContract()
root=fileparts(mfilename('fullpath')); folder=tempname(fullfile(root,'local')); mkdir(folder);
cleaner=onCleanup(@()rmdir(folder,'s'));
protocol=struct('version','fixture','course','fixture','mechanism','flat','gearRatio',35, ...
    'commonGrid',[601 721],'effectiveDOF',66,'requestedIterations',600,'maxFunctionEvaluations',50000, ...
    'maxSeconds',3600,'solver','test','differenceStepMM',.1,'regularizationWeight',0, ...
    'weights',ones(1,6),'endDerivative',[1 0],'startPose',[0 0 0 0],'initialization','fixture');
project=camdesign.solarTestProject(); protocol.physicalInput=physicalInput(project);
record=struct('label','seed1_invalid','pressureAudit',struct('maxPressureDeg',Inf), ...
    'verifiedFeasible',false,'stable',false,'solverSeconds',1,'modelAttempts',1);
file=fullfile(folder,'seed1_invalid.mat'); save(file,'protocol','record','project');
restoreSavedRecord(file,protocol,record.label);
assert(isfile(fullfile(folder,'seed1_invalid.json')));
writeJSON(fullfile(folder,'protocol.json'),protocol);
summary=summarize(folder,{'invalid'}); assert(isinf(summary.groups.pressureMedianDeg) && summary.groups.feasible==0);
changed=protocol; changed.gearRatio=36; rejected=false;
try, restoreSavedRecord(file,changed,record.label); catch ex, rejected=strcmp(ex.identifier,'cam:ComparisonProtocol'); end
assert(rejected);
changed=protocol; changed.physicalInput.params.wheelDiameter=131; rejected=false;
try, restoreSavedRecord(file,changed,record.label); catch ex, rejected=strcmp(ex.identifier,'cam:ComparisonPhysicalInput'); end
assert(rejected);
changed=protocol; changed.physicalInput.targets(2,1)=changed.physicalInput.targets(2,1)+1; rejected=false;
try, restoreSavedRecord(file,changed,record.label); catch ex, rejected=strcmp(ex.identifier,'cam:ComparisonPhysicalInput'); end
assert(rejected);
% Legacy protocol migration checks actual saved project, not only metadata.
protocol=rmfield(protocol,'physicalInput'); save(file,'protocol','record','project');
requested=protocol; requested.physicalInput=physicalInput(project); restoreSavedRecord(file,requested,record.label);
project.params.maxPressureDeg=36; save(file,'protocol','record','project'); rejected=false;
try, restoreSavedRecord(file,requested,record.label); catch ex, rejected=strcmp(ex.identifier,'cam:ComparisonPhysicalInput'); end
assert(rejected);
lockPath=fullfile(folder,'lock'); first=java.io.File(lockPath); second=java.io.File(lockPath);
assert(first.mkdir() && ~second.mkdir()); rmdir(lockPath);
report=struct('missingJSONRecovered',true,'invalidPressureAggregated',true,'changedProtocolRejected',true, ...
    'physicalTargetsAndLegacyProjectChecked',true,'exclusiveDirectoryLock',true);
fprintf('COMPARISON_STORAGE_CONTRACT_PASS recovery/invalid-pressure/protocol/physical-input/exclusive-lock\n');
end
function assertProtocol(saved,requested)
fields={'version','course','mechanism','gearRatio','commonGrid','effectiveDOF','requestedIterations', ...
    'maxFunctionEvaluations','maxSeconds','solver','differenceStepMM','regularizationWeight','weights','endDerivative','startPose','initialization'};
for k=1:numel(fields)
    field=fields{k};
    assert(isfield(saved,field) && isequaln(saved.(field)(:),requested.(field)(:)), ...
        'cam:ComparisonProtocol','Existing protocol mismatch at %s; use a new output directory.',field);
end
if isfield(saved,'physicalInput'), assertPhysical(saved.physicalInput,requested.physicalInput); end
end
function input=physicalInput(project)
fields={'mechanism','wheelDiameter','gearRatio','lever','rollerRadius','referenceDiameter','thickness', ...
    'driveX','driveY','drivenX','drivenY','sensorX','sensorY','headingDeg','startSteeringDeg', ...
    'bounds','hitTolerance','maxPressureDeg','maxSteeringDeg','returnAngleDeg'};
p=struct();
for k=1:numel(fields), p.(fields{k})=project.params.(fields{k}); end
input=struct('targets',project.targets,'params',p);
end
function assertPhysical(actual,expected)
assert(isequaln(actual.targets,expected.targets),'cam:ComparisonPhysicalInput','Saved ordered targets changed.');
fields=fieldnames(expected.params);
for k=1:numel(fields)
    f=fields{k};
    assert(isfield(actual.params,f) && isequaln(actual.params.(f)(:),expected.params.(f)(:)), ...
        'cam:ComparisonPhysicalInput','Saved physical parameter changed: %s',f);
end
end
function writeJSON(file,value)
fid=fopen(file,'w','n','UTF-8'); assert(fid>=0); cleanup=onCleanup(@()fclose(fid));
fprintf(fid,'%s\n',jsonencode(value,PrettyPrint=true));
end

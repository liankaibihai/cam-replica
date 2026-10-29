function report=check_first_generation()
% Compare the faithful port to an UNMODIFIED r2.m in a hashed local fixture.
root=fileparts(mfilename('fullpath')); addpath(root);
assert(batchStartupOptionUsed,'cam:FirstGenerationBatchOnly','本检查只允许独立 MATLAB -batch 新实例运行。');
assert(isempty(findall(groot,'Type','figure')),'cam:FirstGenerationExistingFigures', ...
    '当前实例已有图形；拒绝运行以保护现有窗口，请使用独立 batch。');
fixture=fullfile(root,'local','first_generation_source','run_fixture');
folder=fullfile(root,'outputs','first_generation');
originalFolder=fullfile(folder,'original'); if ~isfolder(originalFolder), mkdir(originalFolder); end
assert(isfile(fullfile(fixture,'r2.m')) && isfile(fullfile(fixture,'routes.mat')), ...
    'cam:FirstGenerationFixture','缺少已核对哈希的第一代本地副本，请按来源文档准备。');
sourceHashes=struct('r2','538cc0310e89432879c77ee2eb420dde8d62cec3008c4cec8746efdc8c42e17e', ...
    'routes','a99b9e626d716eed786bbe19750163857b366b3a8019dbe32196acf1d32cc1e2');
assertSourceHashes(fixture,sourceHashes);
oldVisible=get(groot,'defaultFigureVisible'); set(groot,'defaultFigureVisible','off');
restoreVisibility=onCleanup(@()set(groot,'defaultFigureVisible',oldVisible));
routes=load(fullfile(fixture,'routes.mat')); tolerance=1e-12; caseRecords=cell(1,9);
fields={'rear','leftTrack','rightTrack','u','alpha','p','all','rearStepLengthsMM','rearDistanceMM'};
for k=1:9
    name=sprintf('Untitled%d',k); route=routes.(name);
    assert(istable(route) && width(route)==3);
    front=table2array(route(:,1:2));
    reference=runOriginal(fixture,name,originalFolder);
    actual=camdesign.firstGenerationCam(front); metrics=struct;
    for j=1:numel(fields)
        field=fields{j}; metrics.(field)=compareArray(actual.(field),reference.(field),tolerance);
    end
    assert(isequal(actual.u(1),actual.u(end)));
    assert(abs(actual.alpha(end)-2*pi)<tolerance);
    caseRecords{k}=struct('name',name,'rows',height(route),'columns',width(route), ...
        'allRows',size(actual.all,1),'metrics',metrics, ...
        'inputFirstXY',front(1,:),'inputLastXY',front(end,:), ...
        'inputEndpointGapMM',norm(front(end,:)-front(1,:)), ...
        'rearEndpointGapMM',norm(actual.rear(end,:)-actual.rear(1,:)), ...
        'totalRearDistanceMM',actual.totalRearDistanceMM, ...
        'liftRangeMM',[min(actual.u),max(actual.u)], ...
        'radiusRangeMM',[min(actual.p),max(actual.p)], ...
        'negativeSteeringSteps',nnz(actual.steeringRad<0), ...
        'positiveSteeringSteps',nnz(actual.steeringRad>0), ...
        'realFiniteOutput',isreal(actual.all) && all(isfinite(actual.all),'all'), ...
        'referenceMat',fullfile('outputs','first_generation','original',[name '.mat']));
    fprintf('FIRST_GENERATION_ROUTE_PASS %s %d points maxAbs=%.17g\n',name,height(route),maxMetric(metrics));
end
cases=[caseRecords{:}];

% Analytic first-pass positions: advance straight, then use the exact-x branch.
hand=camdesign.firstGenerationCam([5 0;8 0;3 4],a=5,b=2,c=2,d=20,f=1,initialRear=[0 0]);
assertClose(hand.firstPassRear,[0 0;3 0;3 -1],tolerance);
assertClose(hand.firstPassLeftTrack,[1 0;3 1;2 -1],tolerance);
assertClose(hand.firstPassRightTrack,[-1 0;3 -1;4 -1],tolerance);
checks={'hand-computed straight and vertical-turn first-pass rear/left/right displacement'};

% Collinear path: final pass has signed 0/pi angles; tan is zero to roundoff.
straight=camdesign.firstGenerationCam([0 0;10 0;20 0;30 0],a=5,b=2,c=2,d=20,f=1,initialRear=[-5 0]);
assertClose(straight.firstPassRear,[-5 0;5 0;15 0;25 0],tolerance);
assertClose(straight.rear,[25 0;15 0;15 0;25 0],tolerance);
assertClose(straight.u,zeros(4,1),tolerance);
assertClose(straight.rearDistanceMM,[0;10;10;20],tolerance);
assertClose(straight.alpha,[0;pi;pi;2*pi],tolerance);
assertClose(straight.p,10*ones(4,1),tolerance);
checks{end+1}='hand-computed two-pass straight path, zero lift and midpoint-chord phase';

% These two-point cases have zero rear travel, hence undefined source phase.
% Their steering/lift is independently known: +/-45 degrees and arms c/c+f.
up=camdesign.firstGenerationCam([1 0;4 3],a=5,b=2,c=2,d=20,f=1,initialRear=[0 0]);
down=camdesign.firstGenerationCam([1 0;4 -3],a=5,b=2,c=2,d=20,f=1,initialRear=[0 0]);
assertClose(up.steeringRad,-pi/4,tolerance); assertClose(up.u,[-3;-3],tolerance);
assertClose(down.steeringRad,pi/4,tolerance); assertClose(down.u,[2;2],tolerance);
assertClose(up.leverArmMM,3,tolerance); assertClose(down.leverArmMM,2,tolerance);
assert(all(isnan(up.alpha)) && all(isnan(down.alpha)));
checks{end+1}='hand-computed signed 45-degree lift uses c+f/c; zero-travel phase remains NaN';

front=table2array(routes.Untitled1(:,1:2));
base=camdesign.firstGenerationCam(front,f=0); thick=camdesign.firstGenerationCam(front,f=7);
assertClose(base.rear,thick.rear,tolerance); assertClose(base.leftTrack,thick.leftTrack,tolerance);
assertClose(base.rightTrack,thick.rightTrack,tolerance); assertClose(base.alpha,thick.alpha,tolerance);
positiveCross=base.crossZ>0; negativeOrZero=~positiveCross;
assert(any(positiveCross) && any(negativeOrZero));
delta=thick.u(1:end-1)-base.u(1:end-1);
assertClose(delta(positiveCross),7*tan(base.steeringRad(positiveCross)),tolerance);
assertClose(delta(negativeOrZero),zeros(nnz(negativeOrZero),1),tolerance);
assertClose(thick.p-base.p,thick.u-base.u,tolerance);
checks{end+1}='f changes only positive-cross signed-lift branch, leaving tracks and phase unchanged';

assertError(@()camdesign.firstGenerationCam([0 0]),'cam:FirstGenerationPointCount');
repeat=camdesign.firstGenerationCam([1 0;1 0],a=5,initialRear=[0 0]);
assert(isnan(repeat.u(1)) && isnan(repeat.alpha(1)));
checks{end+1}='minimum input guard and source nonfinite behavior for repeated front points';
assertSourceHashes(fixture,sourceHashes);

report=struct('date','2026-10-29','release',version('-release'), ...
    'sourceVersion','user-provided-first-generation-r2','absoluteTolerance',tolerance, ...
    'routesPassed',numel(cases),'routes',cases,'analyticChecksPassed',numel(checks),'analyticChecks',{checks}, ...
    'sourceScriptUnmodified',true,'sourceHashesBeforeAndAfter',sourceHashes, ...
    'independentBatchRequired',true,'initialFigureCount',0,'scriptFiguresVisible',false, ...
    'scope','Pointwise compatibility with supplied first-generation r2.m; no 3.1.2 or actual-vehicle equivalence.');
fid=fopen(fullfile(folder,'verification.json'),'w','n','UTF-8'); assert(fid>=0);
closer=onCleanup(@()fclose(fid)); fprintf(fid,'%s\n',jsonencode(report,PrettyPrint=true));
for i=1:numel(checks), fprintf('FIRST_GENERATION_ANALYTIC_PASS %s\n',checks{i}); end
fprintf('FIRST_GENERATION_PASS %d routes %d analytic checks\n',numel(cases),numel(checks));
end

function reference=runOriginal(fixture,routeName,folder)
% Only this local function workspace is populated by the source script.
source=load(fullfile(fixture,'routes.mat')); route=source.(routeName);
x00=table2array(route(:,1)); y00=table2array(route(:,2));
[x01,y01,x02,y02,xz,yz,xy,yy,u,alpha,p,all,l,x03]=deal([]);
previous=pwd; restoreDirectory=onCleanup(@()cd(previous)); cd(fixture);
run(fullfile(fixture,'r2.m'));
save(fullfile(folder,[routeName '.mat']),'x00','y00','x01','y01','x02','y02', ...
    'xz','yz','xy','yy','u','alpha','p','all','l','x03','a','b','c','d','f');
reference=struct('rear',[x02(:),y02(:)],'leftTrack',[xz(:),yz(:)], ...
    'rightTrack',[xy(:),yy(:)],'u',u(:),'alpha',alpha(:),'p',p(:),'all',all, ...
    'rearStepLengthsMM',l(:),'rearDistanceMM',x03(:));
end

function metric=compareArray(actual,expected,tolerance)
assert(isequal(size(actual),size(expected)));
finite=isfinite(actual) & isfinite(expected);
assert(isequaln(actual(~finite),expected(~finite)));
errors=abs(actual(finite)-expected(finite)); maxAbs=0;
if ~isempty(errors), maxAbs=max(errors,[],'all'); end
assert(maxAbs<=tolerance,'cam:FirstGenerationMismatch','原脚本逐点差异 %.17g 超过 %.17g。',maxAbs,tolerance);
metric=struct('elements',numel(actual),'maxAbs',maxAbs,'bitExact',isequaln(actual,expected));
end
function value=maxMetric(metrics)
names=fieldnames(metrics); value=0;
for i=1:numel(names), value=max(value,metrics.(names{i}).maxAbs); end
end
function assertClose(actual,expected,tolerance)
assert(isequal(size(actual),size(expected)) && all(abs(actual-expected)<=tolerance,'all'));
end
function assertError(action,identifier)
observed=''; try, action(); catch ex, observed=ex.identifier; end
assert(strcmp(observed,identifier),'Expected %s, observed %s.',identifier,observed);
end
function assertSourceHashes(fixture,expected)
assert(strcmp(fileSHA256(fullfile(fixture,'r2.m')),expected.r2), ...
    'cam:FirstGenerationSourceHash','r2.m 副本 SHA256 与登记的原始基准不一致。');
assert(strcmp(fileSHA256(fullfile(fixture,'routes.mat')),expected.routes), ...
    'cam:FirstGenerationRoutesHash','routes.mat 副本 SHA256 与登记的原始基准不一致。');
end
function value=fileSHA256(path)
fid=fopen(path,'rb'); assert(fid>=0); closer=onCleanup(@()fclose(fid));
bytes=fread(fid,Inf,'*uint8'); digest=java.security.MessageDigest.getInstance('SHA-256');
digest.update(typecast(bytes,'int8'));
value=lower(reshape(dec2hex(typecast(digest.digest(),'uint8'),2).',1,[]));
end

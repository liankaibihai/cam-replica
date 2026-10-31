function report=check_contest_geometry_review(folder)
% Independent polygon/edge oracle; does not use production coordinate inverse.
assert(batchStartupOptionUsed,'cam:BatchOnly','Use independent MATLAB batch.');
if nargin<1, folder=fullfile('outputs','contest_geometry_20261031','review'); end
if ~isfolder(folder), mkdir(folder); end
rng(31013); p=camdesign.teamSolarProject();
cfg=camdesign.contestGeometrySettings(p.params);
cfg.leftMM=60; cfg.rightMM=80; cfg.frontMM=35; cfg.rearMM=140;
cfg.coverXMinMM=-40; cfg.coverXMaxMM=50; cfg.coverYMinMM=-100; cfg.coverYMaxMM=20;
cfg.tagDiameterMM=23; cfg.boundaryMarginMM=3; cfg.coverageMarginMM=2;
cfg.measurementsConfirmed=true; cfg.coverageRectangleConfirmed=true;
p.params.contestGeometry=cfg; errors=[];
for k=1:100
    F=rand(1,2)*300; angle=(rand*6-3)*pi; target=F+(rand(1,2)-.5)*300;
    route=struct('front',F,'heading',angle);
    result=camdesign.contestGeometry(route,target,[-100 400 -100 400],p.params);
    % Standard planar rotation of forward/right axes, independent polygon edges.
    R=[cos(angle-pi/2),-sin(angle-pi/2);sin(angle-pi/2),cos(angle-pi/2)];
    local=[-60 -140;80 -140;80 35;-60 35]; vertices=local*R'+F;
    expected=min([vertices(:,1)+100;400-vertices(:,1);vertices(:,2)+100;400-vertices(:,2)])-3;
    errors(end+1)=abs(result.boundary.minimumMarginMM-expected); %#ok<AGROW>
    cover=[-40 -100;50 -100;50 20;-40 20]; cover=cover*R'+F;
    edge=cover([2:4 1],:)-cover; relative=target-cover;
    signed=(edge(:,1).*relative(:,2)-edge(:,2).*relative(:,1))./vecnorm(edge,2,2);
    expected=min(signed)-23/2-2;
    errors(end+1)=abs(result.coverage.visits.bestMarginMM-expected); %#ok<AGROW>
    assert(result.boundary.satisfied==(result.boundary.minimumMarginMM>1e-9));
    assert(~result.rfidCertified && ~result.competitionCertified && ~result.continuousCertified);
end
assert(max(errors)<1e-10,'Independent edge oracle mismatch.');
% Exactly tangent label: conservative guard must not report positive clearance.
route=struct('front',[0 0],'heading',pi/2);
target=[cfg.coverXMaxMM-cfg.tagDiameterMM/2-cfg.coverageMarginMM,0];
r=camdesign.contestGeometry(route,target,[-500 500 -500 500],p.params);
assert(abs(r.coverage.visits.bestMarginMM)<1e-10 && ~r.coverage.satisfied);
% User configuration and design metadata must stay immutable during inspection.
copy=p; [v,~]=camdesign.verifyContestGeometry(p);
assert(isequaln(copy,p) && p.params.gearRatio==35 && ~v.competitionCertified);
report=struct('release',version('-release'),'checksPassed',3,'randomPoses',100, ...
    'maxIndependentErrorMM',max(errors),'teamAssumedFootprintVerdict',v.verdict, ...
    'scope','Independent polygon-edge oracle, tangency and immutable inputs. Test rectangles are synthetic, not team dimensions.');
fid=fopen(fullfile(folder,'verification.json'),'w','n','UTF-8'); c=onCleanup(@()fclose(fid));
fprintf(fid,'%s',jsonencode(report,PrettyPrint=true));
fprintf('CONTEST_GEOMETRY_REVIEW_PASS %d oracleError=%g\n',report.checksPassed,max(errors));
end

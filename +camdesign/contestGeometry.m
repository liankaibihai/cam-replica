function report=contestGeometry(route,targets,bounds,p)
% Sampled rigid-rectangle/disk geometry; NOT RFID or competition scoring.
[cfg,state]=camdesign.contestGeometrySettings(p); tolerance=1e-9;
report=struct('version','sampled-contest-geometry-v1','valid',true,'configured',state.configured, ...
    'measurementsConfirmed',cfg.measurementsConfirmed,'coverageRectangleConfirmed',cfg.coverageRectangleConfirmed, ...
    'readyForSampledAssessment',state.readyForSampledAssessment,'sampledGeometryPassed',false, ...
    'competitionCertified',false,'rfidCertified',false,'continuousCertified',false, ...
    'settings',cfg,'missingFields',{state.missingFields},'boundary',[],'coverage',[], ...
    'sampleCount',0,'maxFrontStepMM',NaN,'maxHeadingStepDeg',NaN,'verdict','未配置，无法验收', ...
    'errorIdentifier','','errorMessage','','numericContactToleranceMM',tolerance, ...
    'scope',['Sampled body poses only; strict touch rejection within 1e-9mm numerical guard. ',state.assumption, ...
    ' No between-sample swept-volume, opaque-body measurement, tire slip, RFID timing, LED, speech, official score or continuous certification.']);
if ~state.configured, return; end
assert(isstruct(route) && all(isfield(route,{'front','heading'})),'cam:ContestGeometryRoute','需要前轮轴位置和车体航向。');
F=route.front; heading=route.heading(:); count=size(F,1);
assert(isa(F,'double') && isreal(F) && size(F,2)==2 && count>=1 && numel(heading)==count ...
    && isreal(heading) && all(isfinite([F(:);heading])),'cam:ContestGeometryRoute','路线位置/航向须为维数一致的有限实数。');
assert(isa(targets,'double') && ismatrix(targets) && size(targets,2)==2 && ~isempty(targets) ...
    && isreal(targets) && all(isfinite(targets),'all'),'cam:ContestGeometryRoute','目标须为有限XY序列；保留重复访问。');
assert(isa(bounds,'double') && numel(bounds)==4 && isreal(bounds) && all(isfinite(bounds)) ...
    && bounds(2)>bounds(1) && bounds(4)>bounds(3),'cam:Bounds','场界须为合法有限矩形。');
forward=[cos(heading),sin(heading)]; right=[sin(heading),-cos(heading)];
local=[-cfg.leftMM -cfg.rearMM;cfg.rightMM -cfg.rearMM;cfg.rightMM cfg.frontMM;-cfg.leftMM cfg.frontMM];
corners=zeros(count,2,4);
for k=1:4, corners(:,:,k)=F+local(k,1)*right+local(k,2)*forward; end
assert(all(isfinite(corners),'all'),'cam:ContestGeometryRoute','外廓变换超出有限数值范围。');
low=min(corners,[],3); high=max(corners,[],3);
sideMargins=[low(:,1)-bounds(1),bounds(2)-high(:,1),low(:,2)-bounds(3),bounds(4)-high(:,2)]-cfg.boundaryMarginMM;
[margins,whichSide]=min(sideMargins,[],2); [worst,worstSample]=min(margins); sides={'xmin','xmax','ymin','ymax'};
boundary=struct('satisfied',all(margins>tolerance),'minimumMarginMM',worst, ...
    'worstSampleIndex',worstSample,'worstSide',sides{whichSide(worstSample)}, ...
    'worstFrontXY',F(worstSample,:),'worstBodyHeadingRad',heading(worstSample), ...
    'worstPolygonXY',camdesign.contestBodyPolygon(F(worstSample,:),heading(worstSample),cfg), ...
    'violatingSampleIndices',find(margins<=tolerance),'violatingSampleCount',nnz(margins<=tolerance), ...
    'perSampleMarginMM',margins,'touchIsFailure',true,'marginIncludesExtraBufferMM',cfg.boundaryMarginMM);

[locations,~,expected]=unique(targets,'rows','stable'); locationCount=size(locations,1);
coverageMargins=zeros(count,locationCount); events=zeros(0,3); radius=cfg.tagDiameterMM/2;
for id=1:locationCount
    relative=locations(id,:)-F; x=sum(relative.*right,2); y=sum(relative.*forward,2);
    clearance=min([x-cfg.coverXMinMM,cfg.coverXMaxMM-x,y-cfg.coverYMinMM,cfg.coverYMaxMM-y],[],2)-radius-cfg.coverageMarginMM;
    coverageMargins(:,id)=clearance; full=clearance>tolerance;
    changes=diff([false;full;false]); first=find(changes==1); last=find(changes==-1)-1;
    events=[events;repmat(id,numel(first),1),first,last]; %#ok<AGROW>
end
assert(all(isfinite(coverageMargins),'all'),'cam:ContestGeometryRoute','覆盖变换超出有限数值范围。');
if ~isempty(events), events=sortrows(events,[2 1]); end
observed=events(:,1); ambiguous=numel(observed)>1 && any(diff(events(:,2))==0 & diff(observed)~=0);
orderOK=isequal(observed,expected) && ~ambiguous; next=1; assigned=zeros(size(expected)); visits=struct([]);
for visit=1:numel(expected)
    id=expected(visit); [best,bestSample]=max(coverageMargins(:,id));
    event=find(observed(next:end)==id,1);
    if ~isempty(event)
        event=next+event-1; assigned(visit)=event; next=event+1;
        range=events(event,2):events(event,3); [best,where]=max(coverageMargins(range,id)); bestSample=range(where);
        reason='独立全覆盖事件已找到';
    elseif best<=tolerance, reason='没有全覆盖样本';
    else, reason='缺少按序独立再进入事件'; end
    item=struct('visitIndex',visit,'locationID',id,'targetXY',targets(visit,:), ...
        'orderedCovered',assigned(visit)>0,'matchingEventIndex',assigned(visit), ...
        'bestMarginMM',best,'bestSampleIndex',bestSample,'bestFrontXY',F(bestSample,:), ...
        'bestBodyHeadingRad',heading(bestSample),'reason',reason);
    if visit==1, visits=item; else, visits(visit)=item; end
end
unmatched=find(assigned==0); extra=setdiff((1:size(events,1))',assigned(assigned>0));
problemVisits=unmatched;
if ~orderOK && isempty(problemVisits)
    if ~isempty(extra), problemVisits=find(ismember(expected,observed(extra)));
    else, problemVisits=(1:numel(expected))'; end
end
[worstCoverage,worstVisit]=min([visits.bestMarginMM]);
coverage=struct('allRequiredVisitsCovered',all(assigned>0),'orderSatisfied',orderOK, ...
    'satisfied',all(assigned>0) && orderOK,'expectedLocationIDs',expected','observedLocationIDs',observed', ...
    'eventsLocationEntryExitSample',events,'ambiguousSimultaneousEntries',ambiguous, ...
    'extraEventIndices',extra','unmatchedVisitIndices',unmatched','problemVisitIndices',problemVisits', ...
    'visits',visits,'worstBestMarginMM',worstCoverage,'worstVisitIndex',worstVisit, ...
    'tagDiameterMM',cfg.tagDiameterMM,'coverageExtraMarginMM',cfg.coverageMarginMM, ...
    'scope','Whole UID disk strictly inside independent opaque inner rectangle at sampled body poses. Continuous dwell is ONE event; re-entry is required for repeated start/end. No RFID trigger inference.');
report.boundary=boundary; report.coverage=coverage; report.sampleCount=count;
report.maxFrontStepMM=max([0;vecnorm(diff(F),2,2)]); report.maxHeadingStepDeg=rad2deg(max([0;abs(diff(heading))]));
report.sampledGeometryPassed=state.readyForSampledAssessment && boundary.satisfied && coverage.satisfied;
if ~state.readyForSampledAssessment, report.verdict='诊断结果；未确认实测/连续遮挡区域，无法验收';
elseif report.sampledGeometryPassed, report.verdict='已确认输入下采样几何通过；不是比赛或RFID认证';
else, report.verdict='采样比赛几何未通过'; end
end

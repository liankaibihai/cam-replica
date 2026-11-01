function [report,route]=verifyContestGeometry(project,options)
% Independently rebuild body route; cam generation is deliberately not called.
arguments
    project struct
    options.RefinementFactor (1,1) double {mustBeInteger,mustBePositive}=4
    options.MaxSamples (1,1) double {mustBeInteger,mustBePositive}=20001
    options.MaxFrontStepMM (1,1) double {mustBeFinite,mustBePositive}=5
    options.MaxHeadingStepDeg (1,1) double {mustBeFinite,mustBePositive}=.5
end
route=[];
report=struct('valid',false,'configured',false,'readyForSampledAssessment',false,'sampledGeometryPassed',false, ...
    'competitionCertified',false,'rfidCertified',false,'continuousCertified',false, ...
    'verdict','无法验收','errorIdentifier','','errorMessage','','boundary',[],'coverage',[], ...
    'sampleCounts',[],'resolutionSatisfied',false,'eventSequenceStable',false,'independentRefinement',false, ...
    'scope','Independent sampled competition geometry only; no cam feasibility, optimization-score, RFID or full competition approval.');
try
    [~,state]=camdesign.contestGeometrySettings(project.params);
    if ~state.configured
        report=camdesign.contestGeometry(struct(),project.targets,project.params.bounds,project.params);
        report.sampleCounts=[]; report.resolutionSatisfied=false; report.eventSequenceStable=false; report.independentRefinement=false; return;
    end
    camdesign.validateProject(project);
    assert(options.MaxSamples<=20001 && options.MaxSamples>=project.params.samples, ...
        'cam:ContestGeometryResolution','加密上限须介于当前路线点数与20001之间。');
    coarseRoute=camdesign.route(project.nodes,project.params);
    coarse=camdesign.contestGeometry(coarseRoute,project.targets,project.params.bounds,project.params);
    p=project.params; p.samples=min(options.MaxSamples,max(1001,options.RefinementFactor*(p.samples-1)+1));
    while true
        route=camdesign.route(project.nodes,p); fine=camdesign.contestGeometry(route,project.targets,p.bounds,p);
        resolved=fine.maxFrontStepMM<=options.MaxFrontStepMM && fine.maxHeadingStepDeg<=options.MaxHeadingStepDeg;
        if resolved || p.samples==options.MaxSamples, break; end
        p.samples=min(options.MaxSamples,2*(p.samples-1)+1);
    end
    report=fine; report.sampleCounts=[project.params.samples p.samples];
    report.independentRefinement=p.samples>project.params.samples;
    report.resolutionSatisfied=resolved;
    report.resolutionTargets=struct('maxFrontStepMM',options.MaxFrontStepMM,'maxHeadingStepDeg',options.MaxHeadingStepDeg,'sampleCap',options.MaxSamples);
    report.eventSequenceStable=isequal(coarse.coverage.observedLocationIDs,fine.coverage.observedLocationIDs) ...
        && coarse.coverage.ambiguousSimultaneousEntries==fine.coverage.ambiguousSimultaneousEntries;
    report.coarseBoundaryMinimumMarginMM=coarse.boundary.minimumMarginMM;
    report.coarseToFineBoundaryDifferenceMM=abs(coarse.boundary.minimumMarginMM-fine.boundary.minimumMarginMM);
    report.coarseObservedLocationIDs=coarse.coverage.observedLocationIDs;
    report.sampledGeometryPassed=fine.sampledGeometryPassed && coarse.sampledGeometryPassed && resolved && report.eventSequenceStable && report.independentRefinement;
    if ~fine.readyForSampledAssessment, report.verdict='仅诊断；尺寸/场界/UID或连续遮挡区域未确认，无法验收';
    elseif ~report.independentRefinement, report.verdict='仍为同一网格，未独立加密，无法双网格验收';
    elseif ~resolved || ~report.eventSequenceStable, report.verdict='采样分辨率不足或事件不稳定，无法验收';
    elseif report.sampledGeometryPassed, report.verdict='两档采样几何通过；不是连续、RFID或比赛认证';
    else, report.verdict='采样比赛几何未通过'; end
    report.routeSource=camdesign.routeModel(project.params); report.gearRatio=project.params.gearRatio;
catch ex
    report.valid=false; report.sampledGeometryPassed=false; report.verdict='无法验收：检查失败';
    report.errorIdentifier=ex.identifier; report.errorMessage=ex.message;
end
end

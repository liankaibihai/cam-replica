function report=check_route_resolution(projects,labels)
% Fixed-node sampling study. No optimization or changes to physical inputs.
if nargin<1
    rack=camdesign.defaultProject(); flat=rack; flat.params.mechanism='flat';
    projects={rack,flat}; labels={'default_rack','default_flat'};
end
if nargin==1, labels=arrayfun(@(k)sprintf('case_%d',k),1:numel(projects),'UniformOutput',false); end
assert(iscell(projects) && numel(projects)==numel(labels),'cam:ResolutionCases','每个项目需要一个标签。');
root=fileparts(mfilename('fullpath')); folder=fullfile(root,'outputs','route_resolution');
if ~isfolder(folder), mkdir(folder); end
levels=[601 721;1201 1441;2401 2881;4801 5761]; cases=cell(size(projects));
for k=1:numel(projects)
    original=projects{k}; results=cell(4,1); samples=cell(4,1);
    for j=1:4
        p=original; p.params.samples=levels(j,1); p.params.camSamples=levels(j,2);
        timer=tic; r=camdesign.evaluate(p,false);
        assert(isequal(p.nodes,original.nodes) && isequal(p.targets,original.targets));
        results{j}=r;
        samples{j}=struct('routeSamples',p.params.samples,'camSamples',p.params.camSamples, ...
            'elapsedSeconds',toc(timer),'metrics',r.metrics);
    end
    fine=results{end}; comparison=cell(3,1);
    for j=1:3
        r=results{j};
        sensorFine=interp1(fine.route.u,fine.route.sensor,r.route.u,'linear');
        steeringFine=interp1(fine.route.u,fine.route.steering,r.route.u,'linear');
        radiusFine=interp1(fine.cam.phi,fine.cam.radius,r.cam.phi,'linear');
        pressureFine=interp1(fine.cam.phi,fine.cam.pressure,r.cam.phi,'linear');
        comparison{j}=struct('routeSamples',levels(j,1),'camSamples',levels(j,2), ...
            'maxSensorDifferenceMM',max(vecnorm(r.route.sensor-sensorFine,2,2)), ...
            'maxSteeringDifferenceDeg',rad2deg(max(abs(r.route.steering-steeringFine))), ...
            'maxRadiusDifferenceMM',max(abs(r.cam.radius-radiusFine)), ...
            'maxPressureDifferenceDeg',rad2deg(max(abs(r.cam.pressure-pressureFine))), ...
            'workPeakDifferenceDeg',abs(r.metrics.maxWorkPressureDeg-fine.metrics.maxWorkPressureDeg), ...
            'returnPeakDifferenceDeg',abs(r.metrics.maxReturnPressureDeg-fine.metrics.maxReturnPressureDeg));
    end
    % Diagnostic acceptance concerns numerical stability, not engineering limits.
    last=comparison{end}; stable=last.maxSensorDifferenceMM<.1 && ...
        last.maxRadiusDifferenceMM<.05 && last.workPeakDifferenceDeg<.5 && last.returnPeakDifferenceDeg<.5;
    cases{k}=struct('label',labels{k},'mechanism',original.params.mechanism, ...
        'nodes',original.nodes,'targets',original.targets,'physicalParams',original.params, ...
        'samples',{samples},'versusFinest',{comparison},'lastRefinementStable',stable, ...
        'finestPressureLimitExceeded',fine.metrics.maxPressureDeg>original.params.maxPressureDeg);
    fprintf('RESOLUTION_CASE %s workPeak=%.6f/%.6f/%.6f/%.6f lastStable=%d limitExceeded=%d\n', ...
        labels{k},results{1}.metrics.maxWorkPressureDeg,results{2}.metrics.maxWorkPressureDeg, ...
        results{3}.metrics.maxWorkPressureDeg,results{4}.metrics.maxWorkPressureDeg,stable, ...
        cases{k}.finestPressureLimitExceeded);
end
report=struct('release',version('-release'),'levels',levels,'cases',{cases}, ...
    'scope','Fixed-node refinement within the independent model; no original-output equivalence. Self-intersections are not reevaluated in this sampling study.');
fid=fopen(fullfile(folder,'verification.json'),'w','n','UTF-8'); assert(fid>=0);
cleaner=onCleanup(@()fclose(fid)); fprintf(fid,'%s\n',jsonencode(report,PrettyPrint=true));
fprintf('RESOLUTION_STUDY_RECORDED %d cases; inspect lastRefinementStable and pressure limits separately\n',numel(cases));
end

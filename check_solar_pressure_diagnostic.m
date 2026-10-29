function report=check_solar_pressure_diagnostic()
% Locate the solar pressure peak and compare an independent chain-rule slope.
assert(batchStartupOptionUsed,'cam:PressureDiagnosticBatchOnly','Use an independent batch.');
root=fileparts(mfilename('fullpath')); addpath(root);
folder=fullfile(root,'outputs','route_refinement_20261029','pressure_diagnostic');
assert(~isfile(fullfile(folder,'verification.json')),'cam:DiagnosticArchiveExists','Refusing to overwrite diagnostic.');
if ~isfolder(folder), mkdir(folder); end
project=camdesign.solarTestProject(); samples=[601 2401 4801]; cases=cell(1,3);
for k=1:3
    p=project.params; p.samples=samples(k); p.camSamples=round(1.2*(samples(k)-1))+1;
    r=camdesign.route(project.nodes,p); c=camdesign.camProfile(r,p);
    work=find(c.workingMask); [peak,which]=max(c.pressure(work)); index=work(which);
    phase=c.phi(index); sample=interp1(c.workPhi,(1:p.samples)',phase);
    position=interp1(c.workPhi,r.front,phase);
    steering=interp1(c.workPhi,r.steering,phase);
    ddelta=gradient(r.steering,r.driveDistance);
    independentSlope=p.lever./cos(r.steering).^2.*ddelta*p.wheelDiameter*c.effectiveRatio/2;
    independentPressure=atan2(abs(independentSlope),p.referenceDiameter/2+p.lever*tan(r.steering));
    independentAtPeak=interp1(c.workPhi,rad2deg(independentPressure),phase);
    cases{k}=struct('routeSamples',p.samples,'camSamples',p.camSamples, ...
        'maxWorkPressureDeg',rad2deg(peak),'maxReturnPressureDeg',rad2deg(max(c.pressure(~c.workingMask))), ...
        'peakPhaseDeg',rad2deg(phase),'peakFrontXY',position,'fractionalRouteIndex',sample, ...
        'steeringAtPeakDeg',rad2deg(steering),'rollerCenterRadiusAtPeakMM',c.radius(index), ...
        'chainRulePressureAtPeakDeg',independentAtPeak, ...
        'maxChainRulePressureDeg',rad2deg(max(independentPressure(2:end-1))), ...
        'effectiveRatio',c.effectiveRatio,'routeLengthMM',r.frontDistance(end));
    fprintf('SOLAR_PRESSURE_GRID %d peak=%.9f chainAtPeak=%.9f phase=%.6f XY=%.3f,%.3f steering=%.6f radius=%.6f\n', ...
        p.samples,cases{k}.maxWorkPressureDeg,independentAtPeak,rad2deg(phase),position,rad2deg(steering),c.radius(index));
end
report=struct('release',version('-release'),'cases',{cases}, ...
    'scope','Fixed original 10-node solar flat input. Central finite-difference chain rule is independent of the cam-radius spline derivative. No optimizer or physical parameter changes.');
fid=fopen(fullfile(folder,'verification.json'),'w','n','UTF-8'); assert(fid>=0); cleaner=onCleanup(@()fclose(fid));
fprintf(fid,'%s\n',jsonencode(report,PrettyPrint=true));
end

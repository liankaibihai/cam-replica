function summary=check_actual_cam_dense()
% Reuse the frozen polygon from check_actual_cam, at the UI default density.
root=fileparts(mfilename('fullpath'));
folder=fullfile(root,'outputs','actual_cam_20261031');
saved=load(fullfile(folder,'core_results.mat'),'solar','result');
solar=saved.solar; result=saved.result; frozen=result.cam.actual;
[report,simulation]=camdesign.verifyActualClosure(solar,result);
assert(report.valid && report.contactValid && report.integrationConverged && report.closurePassed);
assert(~report.geometryFeasible && ~report.passed && ~report.pressureSatisfied && ~report.returnAngleSatisfied);
assert(isequal(report.integrationSamples,[4801 9601]));
assert(isequal(frozen,result.cam.actual) && report.physicalGearRatio==35);
summary=rmfield(report,{'contact','fullCycleContact','hits','visitOrder','trajectoryBounds'});
summary.release=version('-release');
summary.evidenceSource='Same frozen solar actual polygon saved by check_actual_cam; default verifyActualClosure samples, no cam regeneration or optimization.';
save(fullfile(folder,'solar_dense_results.mat'),'report','simulation');
fid=fopen(fullfile(folder,'solar_dense_verification.json'),'w','n','UTF-8'); assert(fid>=0);
closeFile=onCleanup(@()fclose(fid)); fprintf(fid,'%s\n',jsonencode(summary,PrettyPrint=true));
fprintf('ACTUAL_CAM_DENSE_PASS samples=%s sensor max/RMS=%.12g/%.12g mm front=%.12g mm steering=%.12g deg\n', ...
    mat2str(report.integrationSamples),report.maxSensorDeviationMM,report.rmsSensorDeviationMM,report.maxFrontDeviationMM,report.maxSteeringDeviationDeg);
fprintf('Integration sensor/front=%.12g/%.12g mm; pressure=%.12g deg return=%.12g deg; closure=%d feasible=%d\n', ...
    report.integrationMaxSensorDifferenceMM,report.integrationMaxFrontDifferenceMM,report.maxPressureDeg,report.actualReturnDeg,report.closurePassed,report.geometryFeasible);
end

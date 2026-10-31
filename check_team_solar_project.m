function report=check_team_solar_project(folder)
% Independent design-source, coordinate and persistence checks.
assert(batchStartupOptionUsed,'cam:BatchOnly','Use independent MATLAB batch.');
if nargin<1, folder=fullfile('outputs','contest_geometry_20261031','team'); end
if ~isfolder(folder), mkdir(folder); end
p=camdesign.teamSolarProject(); old=camdesign.solarTestProject();
assert(strcmp(p.params.mechanism,'flat') && p.params.gearRatio==35);
assert(isequal([p.params.wheelDiameter,p.params.driveX,p.params.driveY, ...
    p.params.drivenX,p.params.drivenY,p.params.sensorX,p.params.sensorY, ...
    p.params.lever,p.params.referenceDiameter],[135 60 -110 -105 -110 20 0 20 150]));
assert(isequal(p.targets,old.targets) && size(p.targets,1)==10 ...
    && isequal(p.targets(1,:),p.targets(end,:)));
assert(old.params.wheelDiameter==130 && old.params.driveY==-120);
% At the first pose the sensor, not the front wheel, sits on Earth.
right=[sind(p.params.headingDeg),-cosd(p.params.headingDeg)];
forward=[cosd(p.params.headingDeg),sind(p.params.headingDeg)];
assert(norm(p.nodes(1,:)+p.params.sensorX*right+p.params.sensorY*forward-p.targets(1,:))<1e-9);
assert(p.testContext.vehicleDesignConfirmed && ~p.testContext.vehicleDimensionsMeasured);
path=fullfile(folder,'team_project.mat'); camdesign.saveProject(p,path);
q=camdesign.importProject(path); assert(isequaln(p,q));
report=struct('checksPassed',5,'release',version('-release'), ...
    'confirmedDesign',true,'asBuiltMeasured',false,'sourceSHA256',p.testContext.designSourceSHA256, ...
    'wheelCircumferenceMM',pi*135,'oneCamRevolutionDriveDistanceMM',pi*135*35, ...
    'scope','Source mapping, sensor origin, historical fixture preservation and save/load only. Not physical route feasibility.');
fid=fopen(fullfile(folder,'verification.json'),'w','n','UTF-8'); c=onCleanup(@()fclose(fid));
fprintf(fid,'%s',jsonencode(report,PrettyPrint=true));
fprintf('TEAM_SOLAR_PROJECT_PASS %d\n',report.checksPassed);
end

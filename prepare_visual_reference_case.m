function paths = prepare_visual_reference_case()
% Deterministic straight-line input for visible original-app comparisons.
% Fresh public geometry only. Required legacy key stays 0 (unlicensed).
root=fileparts(mfilename('fullpath'));
folder=fullfile(root,'local','visual_reference');
if ~isfolder(folder), mkdir(folder); end
source=struct('file_format','txt_sw','export_type',10,'line_num',2,'key',0, ...
    'car_type',1,'dh',130,'i_total',20,'c',25,'r',2,'d',100,'f',5, ...
    'xmin',-1000,'xmax',500,'ymin',0,'ymax',2500, ...
    'driving_x',79.5,'driving_y',-120,'driven_x',-79.85,'driven_y',-120, ...
    'sensor_x',0,'sensor_y',-20,'vc_x',0,'vc_y',1, ...
    'train_times',1,'control_points_num',50,'segments_num',11, ...
    'bezier_index',15,'gradient_force',64,'study_rate',0.3, ...
    'smooth_rate',0.4,'disturb_gap',100,'disturb_index',1,'version','3.1.2');
weights=[10 2 8 7 6 5 5 8 5 6 5 8];
for k=1:numel(weights), source.(sprintf('index%d',k))=weights(k); end
source.pathway_points=[-300 260;-300 1260;-300 2260];
source.control_points=[-300*ones(50,1),linspace(280,2280,50)'];
source.optimal_gradient=zeros(50,2);
paths.originalInput=fullfile(folder,'codex_visual_straight_20261029.mat');
save(paths.originalInput,'-struct','source','-v7');

project=camdesign.defaultProject();
project.name='Visual reference: flat straight line';
project.params.mechanism='flat'; project.params.autoRatio=false;
project.params.wheelDiameter=source.dh; project.params.gearRatio=source.i_total;
project.params.lever=source.c; project.params.rollerRadius=source.r;
project.params.referenceDiameter=source.d; project.params.thickness=source.f;
project.params.driveX=source.driving_x; project.params.driveY=source.driving_y;
project.params.drivenX=source.driven_x; project.params.drivenY=source.driven_y;
project.params.sensorX=source.sensor_x; project.params.sensorY=source.sensor_y;
project.params.headingDeg=90; project.params.startSteeringDeg=0;
project.params.bounds=[-1000 500 0 2500];
project.targets=source.pathway_points;
project.nodes=[-300 280;-300 1280;-300 2280];
project.provenance='Synthetic straight-line calibration case; author default dimensions, not team measurements.';
result=camdesign.evaluate(project);
paths.outputDirectory=fullfile(root,'outputs','visual_reference_straight');
if ~isfolder(paths.outputDirectory), mkdir(paths.outputDirectory); end
paths.replicaData=fullfile(paths.outputDirectory,'replica.mat');
save(paths.replicaData,'project','result');
writematrix(result.cam.pitch,fullfile(paths.outputDirectory,'replica_theoretical.csv'));
writematrix(result.cam.actual,fullfile(paths.outputDirectory,'replica_actual.csv'));
expected=struct('case','flat_straight','optimized',false, ...
    'parameters',project.params,'targets',project.targets, ...
    'frontStart',project.nodes(1,:),'frontEnd',project.nodes(end,:), ...
    'theoreticalRadiusMM',50,'actualRadiusMM',48, ...
    'driveLengthMM',result.route.driveDistance(end), ...
    'maxSteeringDeg',result.metrics.maxSteeringDeg, ...
    'maxPressureDeg',result.metrics.maxPressureDeg, ...
    'maxHitErrorMM',result.metrics.maxHitError,'workPhaseDeg',rad2deg(result.cam.workEnd), ...
    'scope','Straight-line geometry only. Does not validate curved-path generation, optimization, phase direction or physical accuracy.');
assert(abs(expected.driveLengthMM-2000)<1e-8 && expected.maxSteeringDeg<1e-8);
assert(max(abs(vecnorm(result.cam.pitch,2,2)-50))<1e-8);
assert(max(abs(vecnorm(result.cam.actual,2,2)-48))<1e-8);
fid=fopen(fullfile(paths.outputDirectory,'expected.json'),'w','n','UTF-8');
assert(fid>=0); cleaner=onCleanup(@()fclose(fid));
fprintf(fid,'%s',jsonencode(expected,'PrettyPrint',true));
fprintf('VISUAL_CASE_READY %s\n',jsonencode(paths));
fprintf('Expected: drive=%.8f mm; pitch R=50 mm; actual R=48 mm; max pressure=%.8g deg\n', ...
    expected.driveLengthMM,expected.maxPressureDeg);
end

function report=check_training_controls()
% Independent formulas and short integration tests, not optimizer quality.
root=fileparts(mfilename('fullpath')); addpath(root);
assert(batchStartupOptionUsed,'cam:TrainingBatchOnly','请使用独立 batch。');
folder=fullfile(root,'outputs','training_controls_20261030'); if ~isfolder(folder), mkdir(folder); end
solar=camdesign.solarTestProject(); original=solar; settings=camdesign.trainingSettings(solar);
assert(isequaln(original,solar) && ~isfield(solar.params,'training') && strcmp(camdesign.routeModel(solar.params),'cubic'));
checks={'reading defaults preserves legacy project and route mode'};
[more,countInfo]=camdesign.setControlPointCount(solar,23);
assert(size(more.nodes,1)==23 && countInfo.shapePreservationGuaranteed && isequal(more.targets,solar.targets));
a=camdesign.route(solar.nodes,solar.params); b=camdesign.route(more.nodes,more.params);
preservation=max(vecnorm(a.front-b.front,2,2)); assert(preservation<1e-8 && more.params.samples==solar.params.samples);
[less,rebuild]=camdesign.setControlPointCount(more,12);
assert(size(less.nodes,1)==12 && ~rebuild.shapePreservationGuaranteed && isequal(less.targets,solar.targets));
checks{end+1}='arbitrary cubic increase is exact insertion; reduction is explicitly a rebuild';

[dense,~]=camdesign.applyTrainingSettings(solar,struct('interpolationPerSegment',12,'iterations',2));
assert(dense.params.samples==109 && dense.params.iterations==2);
fine=dense; fine.params.samples=4*(dense.params.samples-1)+1;
fineRoute=camdesign.route(fine.nodes,fine.params);
assert(numel(fineRoute.u)==433 && fine.params.training.interpolationPerSegment==12);
checks{end+1}='per-interval density sets actual samples only on application; refined p.samples takes precedence';

options=struct('routeModel','bezier-blend-independent-v1','controlPointCount',50, ...
    'bezierDegree',15,'interpolationPerSegment',11,'iterations',300);
[bezier,initialization]=camdesign.applyTrainingSettings(solar,options,'fmincon-interior-point-experimental-v1');
assert(size(bezier.nodes,1)==50 && bezier.params.samples==540 && ~isfield(bezier.params,'routeSpline'));
assert(isequal(bezier.targets,solar.targets) && isequal(bezier.nodes(1,:),solar.nodes(1,:)));
assert(~initialization.shapePreservationGuaranteed);
lengthMM=bezier.params.bezier.parameterLength; sample=linspace(0,lengthMM,121)';
[position,velocity,acceleration]=camdesign.bezierRoute(bezier.nodes,bezier.params,sample);
assert(norm(position(1,:)-bezier.nodes(1,:))<1e-9 && norm(position(end,:)-bezier.nodes(end,:))<1e-9);
assert(norm(velocity(1,:)-[0 1])<1e-10 && all(isfinite(acceleration),'all'));
nodeParameters=linspace(0,lengthMM,50)'; nodePositions=camdesign.bezierRoute(bezier.nodes,bezier.params,nodeParameters);
assert(max(vecnorm(nodePositions-bezier.nodes,2,2))>1);
changed=bezier; changed.nodes(2,:)=changed.nodes(2,:)+[7 -4];
[start,tangent]=camdesign.bezierRoute(changed.nodes,changed.params,0);
assert(norm(start-bezier.nodes(1,:))<1e-9 && norm(tangent-[0 1])<1e-10);
changed.params.headingDeg=31; changed.params.startSteeringDeg=-7;
[~,tangent]=camdesign.bezierRoute(changed.nodes,changed.params,0);
assert(norm(tangent-[cosd(24),sind(24)])<1e-10);
checks{end+1}='independent degree-15 blend is noninterpolating and fixes current initial pose/tangent without locking control two';

degree5=camdesign.applyTrainingSettings(bezier,struct('bezierDegree',5));
different=camdesign.bezierRoute(degree5.nodes,degree5.params,sample);
degreeEffect=max(vecnorm(position-different,2,2)); assert(degreeEffect>1);
u=lengthMM*linspace(.037,.953,19)'; h=lengthMM*1e-5;
[center,d1,d2]=camdesign.bezierRoute(bezier.nodes,bezier.params,u);
plus=camdesign.bezierRoute(bezier.nodes,bezier.params,u+h); minus=camdesign.bezierRoute(bezier.nodes,bezier.params,u-h);
derivativeError=max(abs(d1-(plus-minus)/(2*h)),[],'all');
secondError=max(abs(d2-(plus-2*center+minus)/h^2),[],'all');
assert(derivativeError<1e-6 && secondError<1e-6);
checks{end+1}='degree changes actual geometry; physical-parameter first/second derivatives match finite differences';

line=bezier; line.nodes=[linspace(0,900,50)',zeros(50,1)];
line.params.bezier.parameterLength=900; line.params.headingDeg=0; line.params.startSteeringDeg=0;
u=linspace(0,900,101)'; [xy,v,dd]=camdesign.bezierRoute(line.nodes,line.params,u);
assert(max(abs(xy-[u zeros(size(u))]),[],'all')<1e-8 && max(abs(v-[ones(size(u)) zeros(size(u))]),[],'all')<1e-9);
assert(max(abs(dd),[],'all')<1e-9);
checks{end+1}='straight controls reproduce analytic straight position and unit tangent';

initialResult=camdesign.evaluate(bezier,true);
assert(numel(initialResult.route.u)==540 && isfinite(initialResult.metrics.score));
bezierFine=bezier; bezierFine.params.samples=2157; bezierFine.params.camSamples=2881;
fineResult=camdesign.evaluate(bezierFine,false);
assert(numel(fineResult.route.u)==2157 && numel(fineResult.cam.phi)==2881);
save(fullfile(folder,'solar_bezier_initialized.mat'),'bezier','initialResult','initialization');
checks{end+1}='preferred solar 50-control degree-15 initialization evaluates and honors denser route/cam grids';

fixture=searchFixture(); observations={};
[legacy,legacyHistory]=camdesign.optimize(fixture,[],'peak-gradient-v2');
neutral=camdesign.applyTrainingSettings(fixture,struct('learningRate',1,'smoothingRate',0,'adjustInterval',10,'adjustExponent',0));
[neutralOutput,neutralHistory]=camdesign.optimize(neutral,[],'peak-gradient-v2');
assert(isequal(legacy.nodes,neutralOutput.nodes) && isequal([legacyHistory.score],[neutralHistory.score]));
checks{end+1}='legacy search equals explicitly neutral controls at identical geometry and sampling';

small=camdesign.applyTrainingSettings(fixture,struct('learningRate',.03,'gradientForce',.1));
[smallOutput,smallHistory]=camdesign.optimize(small,@observe,'peak-gradient-v2'); firstObservation=observations{end};
larger=camdesign.applyTrainingSettings(fixture,struct('learningRate',.06,'gradientForce',.1));
[largerOutput,largerHistory]=camdesign.optimize(larger,[],'peak-gradient-v2');
smallMove=norm(smallOutput.nodes-fixture.nodes,'fro'); largerMove=norm(largerOutput.nodes-fixture.nodes,'fro');
assert(smallMove>0 && abs(largerMove/smallMove-2)<1e-4);
assert(abs(smallHistory(end).scheduledStepMM-.03*fixture.params.stepMM)<1e-12);
force=camdesign.applyTrainingSettings(fixture,struct('learningRate',.03,'gradientForce',1));
camdesign.optimize(force,@observe,'peak-gradient-v2'); otherObservation=observations{end};
gradientEffect=norm(firstObservation.gradient-otherObservation.gradient,'fro');
assert(firstObservation.probeMM==.1 && otherObservation.probeMM==1 && gradientEffect>1e-9);
checks{end+1}='gradient force changes actual difference probes; learning rate scales accepted displacement';

smooth=camdesign.applyTrainingSettings(small,struct('smoothingRate',.4));
[smoothOutput,smoothHistory]=camdesign.optimize(smooth,[],'peak-gradient-v2');
assert(smoothHistory(end).smoothingAttempts>0 && smoothHistory(end).smoothingAlpha>0);
assert(norm(smoothOutput.nodes-smallOutput.nodes,'fro')>.1);
scheduled=camdesign.applyTrainingSettings(small,struct('iterations',3,'adjustInterval',2,'adjustExponent',1));
observations={}; camdesign.optimize(scheduled,@observe,'peak-gradient-v2');
assert(numel(observations)==3 && isequal(cellfun(@(x)x.scheduleScale,observations),[1 1 .5]));
changedInterval=scheduled.params; changedInterval.training.adjustInterval=1;
changedExponent=scheduled.params; changedExponent.training.adjustExponent=2;
assert(camdesign.searchSchedule(changedInterval,3).decay==1/3);
assert(camdesign.searchSchedule(changedExponent,3).decay==1/4);
checks{end+1}='smoothing produces accepted geometry changes; interval/exponent drive logged step decay';

mustReject(@()camdesign.applyTrainingSettings(fixture,struct('bezierDegree',5)),'cam:TrainingRouteParameter');
mustReject(@()camdesign.applyTrainingSettings(fixture,struct('learningRate',2),'fmincon-interior-point-experimental-v1'),'cam:TrainingBackend');
constrainedProbeClamps=[.75 .75;6 1;.0005 .001];
for index=1:size(constrainedProbeClamps,1)
    constrainedProbe=camdesign.applyTrainingSettings(fixture,struct('gradientForce',constrainedProbeClamps(index,1)),'fmincon-interior-point-experimental-v1');
    [~,~,probeInfo]=camdesign.optimizeFmincon(constrainedProbe,@(~,~,~)true);
    assert(abs(probeInfo.nominalDifferenceStepMM-constrainedProbeClamps(index,2))<1e-12 ...
        && strcmp(probeInfo.differenceStepSource,'project_gradient_probe'));
    assert(probeInfo.iterations==0 && strcmp(probeInfo.reason,'user_stop'));
end
mustReject(@()camdesign.applyTrainingSettings(fixture,struct('interpolationPerSegment',1)),'cam:TrainingSamples');
mustReject(@()camdesign.applyTrainingSettings(solar,struct('routeModel','bezier-blend-independent-v1','bezierDegree',15,'controlPointCount',4)),'cam:BezierCount');
camdesign.saveProject(bezier,fullfile(folder,'training_project.mat'));
loaded=camdesign.importProject(fullfile(folder,'training_project.mat')); assert(isequaln(loaded,bezier));
checks{end+1}='inapplicable/invalid settings are rejected; constrained nominal probe clamps and complete MAT round trip are real';

report=struct('release',version('-release'),'checks',{checks},'cubicPreservationMM',preservation, ...
    'degreeEffectMM',degreeEffect,'derivativeError',derivativeError,'secondDerivativeError',secondError, ...
    'gradientForceEffect',gradientEffect,'learningMovesMM',[smallMove largerMove], ...
    'smoothingAlpha',smoothHistory(end).smoothingAlpha,'bezierInitialMetrics',initialResult.metrics, ...
    'settings',camdesign.trainingSettings(bezier),'defaultSettings',settings,'constrainedProbeClamps',constrainedProbeClamps, ...
    'scope','Independent fusion/scheduling; short runs test functionality, not convergence or original-software identity.');
fid=fopen(fullfile(folder,'training_verification.json'),'w','n','UTF-8'); assert(fid>=0);
closer=onCleanup(@()fclose(fid)); fprintf(fid,'%s\n',jsonencode(report,PrettyPrint=true));
for k=1:numel(checks), fprintf('TRAINING_CORE_CASE_PASS %s\n',checks{k}); end
fprintf('TRAINING_CORE_PASS cases=%d bezierControls=50 degree=15 samples=540 d1=%.3g d2=%.3g\n',numel(checks),derivativeError,secondError);
    function stop=observe(~,~,history)
        stop=false;
        if strcmp(history(end).event,'searching'), observations{end+1}=history(end); end
    end
end
function project=searchFixture()
project=camdesign.defaultProject(); project.params.mechanism='flat';
project.params.sensorX=0; project.params.sensorY=0; project.params.autoRatio=false;
project.params.gearRatio=2; project.params.samples=101; project.params.camSamples=181;
project.params.iterations=1; project.params.stepMM=.1; project.params.bounds=[0 1000 0 1000];
project.targets=[200 200;200 450;200 700]; project.nodes=[200 200;195 450;200 700];
end
function mustReject(callback,identifier)
failed=false;
try, callback(); catch ex, failed=strcmp(ex.identifier,identifier); end
assert(failed,'Expected rejection %s.',identifier);
end

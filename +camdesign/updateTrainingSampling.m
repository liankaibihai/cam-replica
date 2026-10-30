function project=updateTrainingSampling(project)
% Call only after an explicit point-count/settings operation, not evaluation.
if isfield(project.params,'training') && project.params.training.densityManaged
    samples=1+project.params.training.interpolationPerSegment*(size(project.nodes,1)-1);
    assert(samples>=101 && samples<=20001,'cam:TrainingSamples','实际采样=(点数-1)×每段插值数量+1，须在101至20001之间。');
    project.params.samples=samples;
end
end

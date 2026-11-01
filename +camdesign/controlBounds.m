function report=controlBounds(project)
% Coefficient bounds and physical five-center trajectory bounds are distinct.
p=project.params; policy='legacy-node-bounds-v1';
if strcmp(camdesign.routeModel(p),'bspline-v1'), policy='trajectory-only-v1'; end
if isfield(p,'controlBoundsPolicy'), policy=p.controlBoundsPolicy; end
assert(ismember(policy,{'legacy-node-bounds-v1','trajectory-only-v1'}), ...
    'cam:ControlBoundsPolicy','未知节点/系数场界策略。');
low=p.bounds([1 3]); high=p.bounds([2 4]);
residual=[(low-project.nodes)./(high-low);(project.nodes-high)./(high-low)];
violation=max([0;residual(:)]);
outside=max([0;reshape([low-project.nodes;project.nodes-high],[],1)]);
enforced=strcmp(policy,'legacy-node-bounds-v1');
report=struct('policy',policy,'enforced',enforced,'satisfied',violation==0, ...
    'gatePassed',~enforced || violation==0,'maxScaledViolation',violation, ...
    'maximumOutsideMM',outside);
end

function nodes = seedNodes(targets,p)
% Front-wheel seeds from sensor targets and an estimated body direction.
validateattributes(targets,{'double'},{'2d','ncols',2,'finite','real'});
assert(size(targets,1)>=2,'cam:Targets','至少需要两个目标点。');
v = [targets(2,:)-targets(1,:); targets(3:end,:)-targets(1:end-2,:); ...
    targets(end,:)-targets(end-1,:)];
a = atan2(v(:,2),v(:,1)); a(1)=deg2rad(p.headingDeg);
nodes = targets-p.sensorX*[sin(a),-cos(a)]-p.sensorY*[cos(a),sin(a)];
end

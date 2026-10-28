function [project,notes] = importProject(filename)
% Whitelisted MAT import; authorization keys and arbitrary fields are ignored.
names=who('-file',filename); notes={};
if ismember('project',names)
    data=load(filename,'project'); project=data.project;
    camdesign.validateProject(project); return;
end
allowed={'pathway_points','control_points','optimal_gradient','car_type','dh','i_total','c','r','d','f', ...
    'driving_x','driving_y','driven_x','driven_y','sensor_x','sensor_y','vc_x','vc_y', ...
    'xmin','xmax','ymin','ymax','version'};
use=intersect(names,allowed); data=load(filename,use{:});
assert(isfield(data,'pathway_points'),'cam:Legacy','文件缺少 pathway_points。');
project=camdesign.defaultProject(); [~,project.name]=fileparts(filename);
p=project.params;
map={'dh','wheelDiameter';'i_total','gearRatio';'c','lever';'r','rollerRadius'; ...
    'd','referenceDiameter';'f','thickness';'driving_x','driveX';'driving_y','driveY'; ...
    'driven_x','drivenX';'driven_y','drivenY';'sensor_x','sensorX';'sensor_y','sensorY'};
for k=1:size(map,1)
    if isfield(data,map{k,1}), p.(map{k,2})=double(data.(map{k,1})); end
end
if isfield(data,'car_type')
    switch data.car_type
        case 1, p.mechanism='flat';
        case 4, p.mechanism='rack';
        otherwise, error('cam:Mechanism','旧 MAT 的机构类型为 %g，目前只支持 1 平推和 4 齿条。',data.car_type);
    end
end
if isfield(data,'vc_x') && isfield(data,'vc_y')
    assert(hypot(data.vc_x,data.vc_y)>0,'cam:Heading','发车方向不能为零。');
    p.headingDeg=atan2d(data.vc_y,data.vc_x);
end
b={'xmin','xmax','ymin','ymax'};
for k=1:4, if isfield(data,b{k}), p.bounds(k)=data.(b{k}); end, end
project.params=p; project.targets=double(data.pathway_points);
project.nodes=camdesign.seedNodes(project.targets,p);
project.provenance=['旧 MAT 导入：',char(filename)];
project.legacy=struct();
for field={'control_points','optimal_gradient','version'}
    if isfield(data,field{1}), project.legacy.(field{1})=data.(field{1}); end
end
notes={'导入车体参数和必过点；按独立三次样条重新创建路线。', ...
    '原控制点和梯度只保留为参考，未沿用原版贝塞尔或权重语义。'};
camdesign.validateProject(project);
end

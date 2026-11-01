function [project,notes] = importProject(filename,options)
% Whitelisted MAT import; authorization keys and arbitrary fields are ignored.
arguments
    filename (1,:) char
    options.TypeScheme (1,:) char {mustBeMember(options.TypeScheme,{'auto','3.1.2','legacy-manual'})} = 'auto'
    options.MechanismOverride (1,:) char {mustBeMember(options.MechanismOverride,{'','flat','rack'})} = ''
end
names=who('-file',filename); notes={};
if ismember('project',names)
    data=load(filename,'project'); project=data.project;
    camdesign.validateProject(project);
    if project.params.autoRatio
        notes{end+1}=sprintf('旧项目自动增比设置已停用；固定使用文件中的传动比 %.6g，仅用户可修改。',project.params.gearRatio);
    end
    project.params.autoRatio=false; return;
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
sourceMechanism='未记录'; scheme=options.TypeScheme;
if strcmp(scheme,'auto') && isfield(data,'version') && strcmp(string(data.version),'3.1.2')
    scheme='3.1.2';
end
if isfield(data,'car_type')
    assert(isscalar(data.car_type) && isfinite(data.car_type) && data.car_type==fix(data.car_type), ...
        'cam:Mechanism','原文件 car_type 必须为整数。');
    if strcmp(scheme,'3.1.2')
        kinds={'flat','rack','planetary','ball','slanted'};
        labels={'平推','齿条','周转','顶球','斜推'};
    elseif strcmp(scheme,'legacy-manual')
        kinds={'flat','slanted','ball','rack'};
        labels={'平推','斜推','顶球','齿条'};
    elseif data.car_type==1
        kinds={'flat'}; labels={'平推'};
    else
        error('cam:TypeScheme','原文件版本的机构编号尚未确认。请核对后指定 TypeScheme="3.1.2" 或 "legacy-manual"，不能把类型 4 自动当成齿条。');
    end
    assert(data.car_type>=1 && data.car_type<=numel(kinds),'cam:Mechanism','机构编号超出该版本范围。');
    sourceMechanism=labels{data.car_type}; sourceKind=kinds{data.car_type};
    if isempty(options.MechanismOverride)
        if ~ismember(sourceKind,{'flat','rack'})
            error('cam:UnsupportedMechanism','原文件类型 %g 在 %s 中为%s，本项目尚未实现。可明确选择沿用点位和车体参数另建齿条或平推方案，不能当作原机构直接计算。',data.car_type,scheme,sourceMechanism);
        end
        p.mechanism=sourceKind;
    else
        p.mechanism=options.MechanismOverride;
    end
elseif isempty(options.MechanismOverride)
    error('cam:Mechanism','原文件未记录机构，需显式指定 MechanismOverride。');
else
    p.mechanism=options.MechanismOverride;
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
project.legacy.typeScheme=scheme;
project.legacy.sourceMechanism=sourceMechanism;
project.legacy.mechanismOverride=options.MechanismOverride;
if isfield(data,'car_type'), project.legacy.car_type=data.car_type; end
for field={'control_points','optimal_gradient','version'}
    if isfield(data,field{1}), project.legacy.(field{1})=data.(field{1}); end
end
notes={'导入车体参数和必过点；按独立三次样条重新创建路线。', ...
    '原控制点和梯度只保留为参考，未沿用原版贝塞尔或权重语义。'};
if ~isempty(options.MechanismOverride)
    notes{end+1}=sprintf('原机构为%s；已按明确选择另建 %s 方案，不代表原机构结果。',sourceMechanism,p.mechanism);
    project.provenance=[project.provenance,'；',notes{end}];
end
camdesign.validateProject(project);
end

function project=teamSolarProject()
%TEAMSOLARPROJECT User-confirmed design inputs, not as-built measurements.
project=camdesign.solarTestProject();
root=fileparts(fileparts(mfilename('fullpath')));
source=jsondecode(fileread(fullfile(root,'data','team_solar_design_20261031.json')));
names=fieldnames(source.params);
for k=1:numel(names), project.params.(names{k})=source.params.(names{k}); end
project.name='本队太阳能初赛 · 平推设计（外廓待补）';
project.nodes=camdesign.seedNodes(project.targets,project.params);
project.provenance=['用户2026-10-31确认计算表为本队平推设计，顶球/生物质能标题是旧模板；', ...
    '采用轴距110、轮径135、主动轮X60、从动轮X-105、传感器(20,0)、c20、d150、传动比35。', ...
    '设计值不等于制造实测；外廓与连续遮挡区域未提供。', ...
    '初始航向90度、零转角及阈值为原测试假设，起点为首次地球观测，不含实际发车引入段。'];
project.testContext.vehicleDesignConfirmed=true;
project.testContext.vehicleDimensionsMeasured=false;
project.testContext.designSourceSHA256=source.sha256;
project.testContext.bodyFootprintKnown=false;
camdesign.validateProject(project);
end

function project = solarTestProject()
%SOLARTESTPROJECT Official preliminary visits, with explicit test-only sizing.
% The first Earth is a sensor observation, not a measured launch position.
course=camdesign.course2027Solar();
project=camdesign.defaultProject();
project.name='2027太阳能初赛 · 平推测试（尺寸待实测）';
project.params.mechanism='flat';
project.params.bounds=course.softwareBoundsMM(:)';
project.params.iterations=300;
project.targets=course.preliminarySoftwareMM;
project.nodes=camdesign.seedNodes(project.targets,project.params);
project.provenance=['太阳能规则表2初赛10次顺序访问，保留首尾地球；用户确认平推。', ...
    '机械尺寸、90度初始航向、零初始转角、传动比及阈值沿用历史测试配置，未实测。', ...
    '计算从传感器位于首个地球中心开始，不含实际发车引入段；末点为再次经过地球，不要求航向周期闭合。'];
project.testContext=struct('category','solar','stage','preliminary', ...
    'courseSourceSHA256',course.source.sha256,'orderedIDs',course.preliminaryIDs(:)', ...
    'teamMechanismConfirmed',true,'vehicleDimensionsMeasured',false, ...
    'launchLeadInIncluded',false,'initialHeadingMeasured',false, ...
    'coordinateReferenceOnly',true);
camdesign.validateProject(project);
end

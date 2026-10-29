function report = check_2027_course()
% Verify the PDF point set against the independent legacy fixture.
root=fileparts(mfilename('fullpath'));
c=camdesign.course2027Biomass(); old=camdesign.defaultProject();
expected=[300 460;760 950;1070 1080;1370 1396;1710 1260;2080 1010; ...
    2570 1030;2850 810;3400 300;3790 360;4630 1190;5517 1280];
assert(numel(c.points)==31 && isequal([c.points.id],1:31));
assert(isequal(c.preliminaryOfficialMM,expected));
assert(isequal(c.preliminarySoftwareMM,expected.*[-1 1]));
assert(isequal(old.targets(2:end,:),c.preliminarySoftwareMM));
assert(isequal(old.targets(1,:),c.legacyLeadIn.sensorMM(:)'));
assert(all([c.preliminaryPoints.preliminaryOrder]==1:12));
out=fullfile(root,'outputs','course_2027_biomass');
if ~isfolder(out), mkdir(out); end
points=c.points; official=reshape([points.officialMM],2,[])';
software=reshape([points.softwareMM],2,[])';
tableAll=table([points.id]',string({points.name})',official(:,1),official(:,2), ...
    software(:,1),software(:,2),[points.preliminaryOrder]', ...
    'VariableNames',{'ID','Name','OfficialX_mm','OfficialY_mm','SoftwareX_mm','SoftwareY_mm','PreliminaryOrder'});
writetable(tableAll,fullfile(out,'all_31_reference_points.csv'),'Encoding','UTF-8');
writetable(tableAll(c.preliminaryIDs,:),fullfile(out,'preliminary_12_points.csv'),'Encoding','UTF-8');
report=struct('allPointCount',31,'preliminaryPointCount',12, ...
    'matchesLegacyRows',2:13,'legacyFirstPointIsOfficial',false, ...
    'coordinateMapping','Xsoftware=-Xpdf, Ysoftware=Ypdf', ...
    'sourceSHA256',c.source.sha256,'referenceOnly',true,'finalRouteKnown',false);
fid=fopen(fullfile(out,'verification.json'),'w','n','UTF-8');
assert(fid>=0); cleanupFile=onCleanup(@()fclose(fid));
fprintf(fid,'%s',jsonencode(report,'PrettyPrint',true));

fig=figure('Visible','off','Color','w','Position',[100 100 1400 620]);
cleanupFigure=onCleanup(@()close(fig));
ax=axes(fig); hold(ax,'on'); ax.FontName='Microsoft YaHei';
h1=scatter(ax,software(:,1),software(:,2),34,[.65 .65 .65],'filled');
p=c.preliminarySoftwareMM;
h2=plot(ax,p(:,1),p(:,2),'o--','Color',[.75 .1 .1],'MarkerFaceColor',[.75 .1 .1],'LineWidth',1.1);
for k=1:size(p,1)
    dy=60; if mod(k,2)==0, dy=-110; end
    text(ax,p(k,1),p(k,2)+dy,sprintf('%d %s',k,extractBefore(string(c.preliminaryPoints(k).name)+"（","（")), ...
        'FontName','Microsoft YaHei','FontSize',10,'HorizontalAlignment','center');
end
lead=c.legacyLeadIn.sensorMM;
h3=plot(ax,lead(1),lead(2),'s','MarkerSize',7,'Color',[.1 .3 .7]);
text(ax,-100,100,'旧数据辅助点 (-290,260)，不计入 12 个标志点', ...
    'FontName','Microsoft YaHei','FontSize',10,'Color',[.1 .3 .7],'HorizontalAlignment','right');
axis(ax,'equal'); axis(ax,[-6000 0 0 2000]); grid(ax,'on');
xlabel(ax,'软件 X / mm（原表 X 取负）'); ylabel(ax,'Y / mm');
title(ax,{'2027 生物质能初赛：12 个标志点', ...
    '虚线仅表示经过顺序，不是设计轨迹；点位以现场为准'},'FontName','Microsoft YaHei');
legend(ax,[h1 h2 h3],{'31 个备选地点','初赛 12 点顺序','旧数据辅助点'}, ...
    'Location','northoutside','Orientation','horizontal','FontName','Microsoft YaHei');
exportgraphics(fig,fullfile(out,'preliminary_points.png'),'Resolution',140);
fprintf('COURSE_2027_PASS: 31 reference points, 12 preliminary; matches legacy rows 2:13.\n');
end

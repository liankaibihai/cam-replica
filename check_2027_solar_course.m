function report = check_2027_solar_course()
% Verify the team's solar route and repeated start/finish ordering.
root=fileparts(mfilename('fullpath')); c=camdesign.course2027Solar();
expected=[410 420;700 1580;1440 1100;3170 1560;4160 1440; ...
    5110 1630;5450 440;3250 350;2500 750;410 420];
assert(numel(c.points)==16 && isequal([c.points.id],1:16));
assert(isequal(c.preliminaryOfficialMM,expected));
assert(isequal(c.preliminarySoftwareMM,expected));
assert(isequal(c.preliminaryOfficialMM(1,:),c.preliminaryOfficialMM(end,:)));
assert(size(unique(expected,'rows'),1)==9);
assert(all([c.preliminaryPoints.preliminaryOrder]==1:10));
% A geometrically known complete loop must assign final Earth to the return,
% not reuse the initial Earth hit. This is not a physical RFID simulation.
hits=camdesign.orderedHits(expected,expected);
assert(max(hits.errors)<1e-8 && all(diff(hits.indices)>0));
assert(hits.indices(end)>hits.indices(1)+8);
out=fullfile(root,'outputs','course_2027_solar');
if ~isfolder(out), mkdir(out); end
points=c.points; xy=reshape([points.officialMM],2,[])';
assert(size(unique(xy,'rows'),1)==15);
t=table([points.id]',string({points.name})',xy(:,1),xy(:,2),[points.preliminaryOrder]', ...
    'VariableNames',{'ID','Name','X_mm','Y_mm','PreliminaryOrder'});
writetable(t,fullfile(out,'all_16_reference_records.csv'),'Encoding','UTF-8');
writetable(t(c.preliminaryIDs,:),fullfile(out,'preliminary_10_visits.csv'),'Encoding','UTF-8');
report=struct('tableRecordCount',16,'tableUniqueLocationCount',15, ...
    'preliminaryVisitCount',10,'preliminaryUniqueLocationCount',9, ...
    'finalEarthOrderedAfterOtherVisits',true, ...
    'sourceSHA256',c.source.sha256,'referenceOnly',true,'finalRouteKnown',false, ...
    'scope','Point data and ordered polyline projection only; not optimized cam, original-app comparison or real-car validation.');
fid=fopen(fullfile(out,'verification.json'),'w','n','UTF-8');
assert(fid>=0); cleanupFile=onCleanup(@()fclose(fid));
fprintf(fid,'%s',jsonencode(report,'PrettyPrint',true));
fig=figure('Visible','off','Color','w','Position',[100 100 1400 600]);
cleanupFigure=onCleanup(@()close(fig));
ax=axes(fig); hold(ax,'on'); ax.FontName='Microsoft YaHei';
h1=scatter(ax,xy(:,1),xy(:,2),32,[.7 .7 .7],'filled');
h2=plot(ax,expected(:,1),expected(:,2),'o--','Color',[.8 .2 .05], ...
    'MarkerFaceColor',[.8 .2 .05],'LineWidth',1.1);
for k=1:9
    label=sprintf('%d %s',k,c.preliminaryPoints(k).name);
    if k==1, label='1 / 10 地球（起终点）'; end
    text(ax,expected(k,1),expected(k,2)+85,label,'FontName','Microsoft YaHei', ...
        'FontSize',11,'HorizontalAlignment','center');
end
axis(ax,'equal'); axis(ax,[0 6000 0 2000]); grid(ax,'on');
xlabel(ax,'X / mm（保留规则原表坐标）'); ylabel(ax,'Y / mm');
title(ax,{'2027 太阳能初赛：10 次顺序访问，9 处不同位置', ...
    '虚线仅表示顺序，不是设计轨迹；从地球出发，最后返回地球'},'FontName','Microsoft YaHei');
legend(ax,[h1 h2],{'备选地点','初赛顺序'},'Location','northoutside', ...
    'Orientation','horizontal','FontName','Microsoft YaHei');
exportgraphics(fig,fullfile(out,'preliminary_points.png'),'Resolution',140);
fprintf('SOLAR_2027_PASS: 16 table records, 10 visits, 9 unique preliminary locations; return Earth ordering verified.\n');
end

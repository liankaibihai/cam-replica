function report=report_path_method_comparison(preview)
% Render the completed paired experiment. Never infer pass from solver status.
assert(batchStartupOptionUsed,'cam:BatchOnly','Use independent batch.');
if nargin<1, preview=false; end
root=fileparts(mfilename('fullpath')); folder=fullfile(root,'outputs','path_comparison_20261031');
figureFolder=folder;
if preview, figureFolder=fullfile(folder,'preview'); if ~isfolder(figureFolder), mkdir(figureFolder); end, end
names={'cubic','bezier5','bspline3','bspline5'};
titles={'三次插值样条','独立融合贝塞尔（五次）','标准三次 B 样条','标准五次 B 样条'};
report=check_path_method_comparison('summary');
assert(preview || numel(report.runs)==20,'cam:IncompleteComparison','Require all 20 complete runs before final report.');
selection=cell(1,4); colors=lines(5);
steerRange=max(20,5*ceil(max(arrayfun(@(r)metricValue(r,'maxSteeringDeg',0),report.runs))/5));
f=figure('Visible','off','Color','w','Position',[20 20 1900 1500]); closer=onCleanup(@()close(f));
layout=tiledlayout(f,4,4,'TileSpacing','compact','Padding','compact');
for method=1:4
    indices=find(strcmp({report.runs.method},names{method})); rows=report.runs(indices);
    violation=arrayfun(@(r)max(scalar(r.final.maxScaledViolation,Inf),(scalar(r.pressureAudit.maxPressureDeg,Inf)/35)^2-1),rows);
    [~,order]=sortrows([[~[rows.verifiedFeasible]]',[~[rows.stable]]',violation']);
    row=rows(order(1)); selection{method}=row.label;
    saved=load(fullfile(folder,[row.label '.mat']),'q'); q=saved.q;
    q.params.samples=4801; q.params.camSamples=5761;
    try
        result=camdesign.evaluate(q,true);
    catch ex
        if row.final.valid, rethrow(ex); end
        ax=nexttile(layout,(method-1)*4+1,[1 4]); axis(ax,'off');
        text(ax,.05,.5,sprintf('%s: 加密几何无效，未通过。%s',titles{method},ex.message),'Interpreter','none');
        continue;
    end
    r=result.route; c=result.cam;
    ax=nexttile(layout,(method-1)*4+1,[1 2]); hold(ax,'on');
    plot(ax,r.front(:,1),r.front(:,2),'k','LineWidth',1.2);
    plot(ax,r.sensor(:,1),r.sensor(:,2),'r','LineWidth',1.2);
    plot(ax,r.drive(:,1),r.drive(:,2),'b'); plot(ax,r.driven(:,1),r.driven(:,2),'b--');
    scatter(ax,q.targets(:,1),q.targets(:,2),28,'k','filled');
    repeated=isequal(q.targets(1,:),q.targets(end,:));
    for k=1:size(q.targets,1)
        if repeated && k==size(q.targets,1), continue; end
        label=num2str(k); if repeated && k==1, label=sprintf('1/%d',size(q.targets,1)); end
        text(ax,q.targets(k,1)+25,q.targets(k,2)+55,label,'FontSize',9);
    end
    plot(ax,[0 6000 6000 0 0],[0 0 2000 2000 0],'Color',[.5 .5 .5],'LineStyle',':','HandleVisibility','off');
    points=[r.front;r.sensor;r.drive;r.driven;r.rear;0 0;6000 2000];
    axis(ax,'equal'); xlim(ax,[min(points(:,1))-50 max(points(:,1))+50]); ylim(ax,[min(points(:,2))-50 max(points(:,2))+50]);
    grid(ax,'on'); xlabel(ax,'X / mm'); ylabel(ax,'Y / mm');
    title(ax,sprintf('%s · %s · 加密验收%s',titles{method},row.label,passText(row.verifiedFeasible)),'Interpreter','none');
    if method==1, legend(ax,{'前轮','传感器','主动轮','从动轮','目标'},'Location','northoutside','Orientation','horizontal'); end
    ax=nexttile(layout,(method-1)*4+3); plot(ax,r.frontDistance/1000,rad2deg(r.steering),'Color',[.1 .3 .8]);
    grid(ax,'on'); ylim(ax,[-steerRange steerRange]); xlabel(ax,'前轮行程 / m'); ylabel(ax,'转角 / °');
    title(ax,sprintf('压力极值 %.2f°；打卡 %.2f mm',row.pressureAudit.maxPressureDeg,row.final.metrics.maxHitError));
    ax=nexttile(layout,(method-1)*4+4); hold(ax,'on');
    plot(ax,c.pitch(:,1),c.pitch(:,2),'b','DisplayName','理论'); plot(ax,c.actual(:,1),c.actual(:,2),'r','LineWidth',1.1,'DisplayName','实际');
    a=linspace(0,2*pi,361); radius=q.params.referenceDiameter/2;
    plot(ax,radius*cos(a),radius*sin(a),'k:','DisplayName','零位参考圆d/2');
    if ~isempty(result.intersectionPoints), scatter(ax,result.intersectionPoints(:,1),result.intersectionPoints(:,2),50,'m','LineWidth',1.2,'DisplayName','自交位置'); end
    axis(ax,'equal'); grid(ax,'on'); xlabel(ax,'X / mm'); ylabel(ax,'Y / mm');
    title(ax,sprintf('回程 %.2f°；自交 %d',row.final.metrics.actualReturnDeg,row.final.metrics.intersectionCount));
    if method==1, legend(ax,'show','Location','southoutside','NumColumns',2,'FontSize',8); end
end
heading='太阳能初赛平推车 · 固定传动比35 · 同模型四方法比较（未实车标定）';
if preview, heading=['排版预览／实验未完成 · ' heading]; end
title(layout,heading,'FontSize',16);
exportgraphics(f,fullfile(figureFolder,'representatives.png'),'Resolution',130);
g=figure('Visible','off','Color','w','Position',[20 20 1600 430]); cleanup2=onCleanup(@()close(g));
tiles=tiledlayout(g,1,4,'TileSpacing','compact','Padding','compact');
trendAxes=gobjects(1,4);
for method=1:4
    ax=nexttile(tiles); hold(ax,'on');
    trendAxes(method)=ax;
    for seed=1:5
        file=fullfile(folder,sprintf('seed%d_%s.mat',seed,names{method}));
        if preview && ~isfile(file), continue; end
        saved=load(file,'h');
        h=saved.h; semilogy(ax,[h.iteration],max([h.maxConstraintViolation],1e-9),'Color',colors(seed,:),'LineWidth',1,'DisplayName',sprintf('初值%d',seed));
    end
    grid(ax,'on'); xlabel(ax,'实际迭代轮数'); ylabel(ax,'训练网格最大归一化违规'); title(ax,titles{method});
    set(ax,'YScale','log'); legend(ax,'show','Location','best');
end
limits=vertcat(trendAxes.YLim); commonLimits=[min(limits(:,1)) max(limits(:,2))];
for ax=trendAxes, ylim(ax,commonLimits); xlim(ax,[0 report.protocol.requestedIterations]); end
title(tiles,'保留候选的训练违规轨迹；最终合格与否另用加密验收，不由本图判定');
exportgraphics(g,fullfile(figureFolder,'convergence.png'),'Resolution',130);
if preview, fprintf('PATH_COMPARISON_PREVIEW_ONLY runs=%d\n',numel(report.runs)); return; end
report.representatives=selection;
input=load(fullfile(folder,'seed1_cubic.mat'),'project'); report.referenceInput=input.project;
report.selectionPolicy='Within each method: verified feasible first, stable next, then minimum common-grid worst scaled violation including polynomial pressure peak.';
report.timingCaution='Seed5, seed4 B5, and the diagnostic continuation ran in additional independent MATLAB processes while primary runs continued; elapsed time includes mixed CPU load and is not an isolated speed benchmark.';
file=fullfile(folder,'final_report.json'); fid=fopen(file,'w','n','UTF-8'); closeJSON=onCleanup(@()fclose(fid));
fprintf(fid,'%s\n',jsonencode(report,PrettyPrint=true));
fprintf('PATH_COMPARISON_REPORT_DONE runs=20\n');
end
function text=passText(value)
if value, text='通过'; else, text='未通过'; end
end
function value=scalar(value,fallback)
if ~isnumeric(value) || ~isscalar(value) || ~isfinite(value), value=fallback; end
end
function value=metricValue(row,name,fallback)
value=fallback;
if isstruct(row.final.metrics) && isfield(row.final.metrics,name), value=scalar(row.final.metrics.(name),fallback); end
end

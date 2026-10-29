function report=make_original_visual_comparison()
% Compare calibrated visible sensor trajectories, not hidden original output.
assert(batchStartupOptionUsed,'cam:ComparisonBatchOnly','Use an independent batch.');
root=fileparts(mfilename('fullpath'));
folder=fullfile(root,'outputs','original_comparison_20261029');
f=figure('Visible','off','Position',[100 100 1450 950]);
cleaner=onCleanup(@()close(f)); layout=tiledlayout(f,2,1,'TileSpacing','compact');
title(layout,'同目标 / 同车体 / 固定传动比20：传感器路线比较（不同路线算法）');
items={};
for kind={'rack','flat'}
    data=load(fullfile(folder,[kind{1},'_replica.mat']),'q','info');
    p=data.q; p.params.samples=4*(p.params.samples-1)+1;
    p.params.camSamples=4*(p.params.camSamples-1)+1;
    result=camdesign.evaluate(p);
    stations=readmatrix(fullfile(folder,[kind{1},'_pixels_stations.csv']));
    trace=readmatrix(fullfile(folder,[kind{1},'_pixels_trace.csv']));
    [xs,ix]=sort(result.route.sensor(:,1)); ys=result.route.sensor(ix,2);
    assert(all(diff(xs)>0),'cam:VisualInterpolation','Ambiguous duplicate sensor X');
    replicaY=interp1(xs,ys,stations(:,1),'linear');
    uncertainty=2000/352*2;
    leftY=interp1(xs,ys,stations(:,1)-uncertainty,'linear');
    rightY=interp1(xs,ys,stations(:,1)+uncertainty,'linear');
    difference=replicaY-stations(:,2);
    lower=min([leftY replicaY rightY],[],2)-stations(:,2)-uncertainty;
    upper=max([leftY replicaY rightY],[],2)-stations(:,2)+uncertainty;
    items{end+1}=struct('mechanism',kind{1},'stationX',stations(:,1), ...
        'originalScreenY',stations(:,2),'replicaY',replicaY, ...
        'replicaMinusOriginalY',difference,'readingEnvelopeLower',lower, ...
        'readingEnvelopeUpper',upper,'uncertaintyPerCoordinateMM',uncertainty, ...
        'replicaFineMetrics',result.metrics,'replicaActualIterations',data.info.iterations);
    ax=nexttile(layout); hold(ax,'on');
    plot(ax,trace(:,1),trace(:,2),'.','Color',[.8 .2 .15],'MarkerSize',7);
    plot(ax,result.route.sensor(:,1),result.route.sensor(:,2),'b-','LineWidth',1.5);
    plot(ax,p.targets(:,1),p.targets(:,2),'ko','MarkerSize',5);
    plot(ax,stations(:,1),stations(:,2),'s','Color',[.8 .2 .15],'MarkerSize',8);
    for k=1:size(stations,1)
        plot(ax,[stations(k,1) stations(k,1)],[stations(k,2) replicaY(k)],'k:');
    end
    xlim(ax,[-6000 0]); ylim(ax,[0 2000]); axis(ax,'equal'); grid(ax,'on');
    xlabel(ax,'场地 X / mm'); ylabel(ax,'场地 Y / mm');
    title(ax,sprintf('%s | 原版300次；复现版%d次（局部终止） | 图读数每坐标约±11 mm',kind{1},data.info.iterations));
    legend(ax,{'原版截图采样','复现版加密轨迹','打卡点','5个比对站位'},'Location','northoutside','Orientation','horizontal');
end
report=struct('cases',{items},'scope','Differences between separately designed sensor routes, not solver numerical error. Approximate 2-pixel coordinate reading uncertainty; sampled stations are not a full-path maximum or original hit-error measurement. No cam export or vehicle validation.');
exportgraphics(f,fullfile(folder,'sensor_route_comparison.png'),'Resolution',140);
fid=fopen(fullfile(folder,'visual_station_comparison.json'),'w','n','UTF-8'); assert(fid>=0);
outputCleanup=onCleanup(@()fclose(fid)); fprintf(fid,'%s',jsonencode(report,PrettyPrint=true));
for k=1:numel(items)
    fprintf('VISUAL_STATIONS %s maxAbsYDifference=%.6f mm\n',items{k}.mechanism,max(abs(items{k}.replicaMinusOriginalY)));
end
end

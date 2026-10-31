function report=check_plot_layout()
root=fileparts(mfilename('fullpath')); addpath(root);
assert(batchStartupOptionUsed,'cam:PlotLayoutBatchOnly','请使用独立 batch 运行布局检查。');
folder=fullfile(root,'outputs','results_panel_20261030','layout'); if ~isfolder(folder), mkdir(folder); end
app=CamReplicaApp('off'); cleaner=onCleanup(@()closeFigure(app));
app.SimulationSource.Value='theoretical'; % Preserve legacy theoretical-mode UI regression.
baseline=app.Project; cases=cell(6,1); sizes=[1320 860;1920 1080];
solar=camdesign.solarTestProject();
assert(strcmp(solar.params.mechanism,'flat') && size(solar.targets,1)==10 ...
    && isequal(solar.targets(1,:),solar.targets(end,:)));
for course=1:3
    if course==1
        project=solar; label='solar_flat';
    elseif course==2
        project=baseline; label='default_horizontal';
    else
        project=baseline; project.name='合成纵向场地，仅作布局检查'; project.params.mechanism='flat';
        project.params.bounds=[-1800 1800 -200 6000];
        project.targets=[0 0;-200 1000;200 2200;-200 3400;200 4600;0 5600];
        project.nodes=camdesign.seedNodes(project.targets,project.params); label='synthetic_vertical';
    end
    app.Project=project; app.syncInputs(); app.calculate(); originalResult=app.Result;
    for window=1:2
        app.Figure.Position=[10 10 sizes(window,:)];
        % Invisible figures do not reliably dispatch SizeChangedFcn themselves.
        callback=app.Figure.SizeChangedFcn; cam_invoke_ui_callback(callback,app.Figure,[]);
        stem=sprintf('%s_%dx%d',label,sizes(window,1),sizes(window,2));
        measured=captureLayout(app,fullfile(folder,[stem,'.png']),stem);
        fprintf('LAYOUT_MEASURE %s steeringShare=%.4f targets=%d nodes=%d routeSamples=%d camSamples=%d\n', ...
            stem,measured.steeringRowFraction,measured.coveredTargets,measured.coveredNodes,measured.coveredRouteSamples,measured.coveredCamSamples);
        assert(isequal(app.Figure.Position(3:4),sizes(window,:)));
        assert(isequaln(app.Project,project) && isequaln(app.Result,originalResult),'Resize changed project or numerical result.');
        assert(measured.routeColumnFraction>=.55 && measured.routeColumnFraction<=.60);
        assert(measured.steeringRowFraction>=.24 && measured.steeringRowFraction<=.30);
        assert(all(measured.camPlotPixels>=[280 280]),'Actual cam plot remains too small.');
        cases{2*(course-1)+window}=measured;
        fprintf('LAYOUT_CASE %s routePlot=%.2fx%.2f camPlot=%.2fx%.2f routeShare=%.4f steeringShare=%.4f legendCoverageTargets=%d nodes=%d frontSamples=%d camSamples=%d\n', ...
            stem,measured.routePlotPixels,measured.camPlotPixels,measured.routeColumnFraction, ...
            measured.steeringRowFraction,measured.coveredTargets,measured.coveredNodes,measured.coveredFrontSamples,measured.coveredCamSamples);
    end
end
assert(all(cases{2}.camPlotPixels>1.25*cases{1}.camPlotPixels),'Wide window did not enlarge cam plot.');
assert(cases{5}.routePlotPixels(2)>cases{5}.routePlotPixels(1),'Portrait viewport must remain taller than wide, including legend space.');
app.Figure.Position=[10 10 sizes(1,:)]; callback=app.Figure.SizeChangedFcn; cam_invoke_ui_callback(callback,app.Figure,[]);
app.Project=baseline; app.syncInputs(); app.calculate(); drawnow;
arrow=findobj(app.RouteAxes,'Tag','optimization-direction');
assert(all(isnan(arrow.XData)) && any(strcmp(app.RouteAxes.Legend.String,'AI')));
assert(~contains(app.RouteAxes.Title.String,'AI') && contains(app.DirectionStatus.Text,'无有效数据'));
proxy=findobj(app.RouteAxes,'Tag','optimization-direction-legend');
assert(isscalar(proxy) && isequal(proxy.Color,[.85 .15 .65]) && all(isnan(proxy.XData)));
checkCircle(app,50);
assert(numel(findobj(app.RouteAxes,'Tag','optimization-direction-legend'))==1 && numel(app.RouteAxes.Legend.String)==7);
row=find(strcmp(app.ParamsTable.Data(:,1),'零位中心距 ×2 / mm'));
app.ParamsTable.Data{row,2}=120; app.invalidate(); app.calculate(); checkCircle(app,60);
app.toggleSimulation();
row=find(strcmp(app.ParamsTable.Data(:,1),'零位中心距 ×2 / mm'));
app.ParamsTable.Data{row,2}=140; app.invalidate(); app.calculate(); checkCircle(app,60);
fixedCamLayout=captureLayout(app,fullfile(folder,'fixed_cam_reference_layout.png'),'fixed_cam_reference');
app.toggleSimulation(); checkCircle(app,60);
app.Project=solar; app.syncInputs(); app.calculate();
drawnow; exportapp(app.Figure,fullfile(folder,'main_map.png'));

p=baseline; p.params.samples=201; p.params.camSamples=241; p.params.iterations=2;
app.Project=p; app.syncInputs(); app.calculate(); app.setBusy(true);
searchUpdates=0; captured=[]; directionLayout=[];
[q,h,info]=camdesign.optimize(p,@observe,'peak-gradient-v2');
assert(searchUpdates==2 && strcmp(info.reason,'iteration_limit'));
app.Project=q; app.History=h; app.OptimizationDirection=[]; app.syncInputs(); app.setBusy(false); app.calculate();
arrow=findobj(app.RouteAxes,'Tag','optimization-direction'); assert(all(isnan(arrow.XData)));
app.beginRouteEditing(); app.routeMapClick(app.Project.nodes(5,:),app.RouteAxes);
app.previewRouteNode(app.Project.nodes(5,:)+[.1 .1],app.RouteAxes); app.cancelRouteEditing();
checkCircle(app,50);
report=struct('release',version('-release'),'windowPixels',app.Figure.Position(3:4), ...
    'primaryCourse','solar_flat','primaryMechanism',solar.params.mechanism, ...
    'primaryTargets',solar.targets,'primaryTestContext',solar.testContext, ...
    'cases',{cases},'mainMapPlotPixels',cases{1}.routePlotPixels, ...
    'fixedCamLayout',fixedCamLayout,'directionLayout',directionLayout, ...
    'searchUpdates',searchUpdates,'directionSample',captured, ...
    'referenceCircleRadiiCheckedMM',[50 60 60], ...
    'scope','Solar preliminary flat test is primary; vehicle sizing and heading remain explicit test assumptions. Default and synthetic portrait layouts are regressions. No numerical model changes or native input injection.');
fid=fopen(fullfile(folder,'verification.json'),'w','n','UTF-8'); assert(fid>=0);
closer=onCleanup(@()fclose(fid)); fprintf(fid,'%s\n',jsonencode(report,PrettyPrint=true));
fprintf('PLOT_LAYOUT_PASS cases=%d cam=%.1fx%.1fpx searchUpdates=%d designReferenceRetained=true\n',numel(cases),cases{1}.camPlotPixels,searchUpdates);
    function stop=observe(iteration,project,history)
        app.optimizationUpdate(iteration,project,history); stop=false;
        if strcmp(history(end).event,'searching')
            searchUpdates=searchUpdates+1; data=history(end);
            assert(isequal(data.directionBaseNodes,project.nodes) && all(data.descentDirection(1,:)==0));
            arrow=findobj(app.RouteAxes,'Tag','optimization-direction'); visible=vecnorm(data.descentDirection,2,2)>1e-12;
            assert(isequal(arrow.XData(:),project.nodes(visible,1)) && isequal(arrow.YData(:),project.nodes(visible,2)));
            vectors=[arrow.UData(:) arrow.VData(:)]; expected=data.descentDirection(visible,:);
            assert(all(sum(vectors.*expected,2)>0));
            assert(max(abs(vectors(:,1).*expected(:,2)-vectors(:,2).*expected(:,1)))<1e-8);
            assert(sum(data.gradient.*data.descentDirection,'all')<0);
            assert(~contains(app.RouteAxes.Title.String,'AI') && contains(app.DirectionStatus.Text,sprintf('第 %d 轮',data.directionIteration)));
            if searchUpdates==1
                captured=struct('baseNodes',data.directionBaseNodes,'gradient',data.gradient,'descentDirection',data.descentDirection);
                directionLayout=captureLayout(app,fullfile(folder,'actual_search_direction.png'),'actual_search_direction');
            end
        end
    end
end

function checkCircle(app,radius)
circle=findobj(app.CamAxes,'Tag','zero-reference-circle');
assert(isscalar(circle) && max(abs(hypot(circle.XData,circle.YData)-radius))<1e-10);
assert(numel(findobj(app.CamAxes,'Tag','cam-center'))==1);
assert(any(strcmp(app.CamAxes.Legend.String,'零位圆 d/2')));
end
function item=measureLayout(app,label)
assert(isequal(app.RouteAxes.DataAspectRatio,[1 1 1]) && isequal(app.CamAxes.DataAspectRatio,[1 1 1]));
assert(any(strcmp(app.RouteAxes.Legend.Location,{'northwest','northeast'})) && strcmp(app.CamAxes.Legend.Location,'north'));
assert(numel(app.RouteAxes.Legend.String)==7+app.SimulationMode && numel(app.CamAxes.Legend.String)==4);
assert(app.RouteAxes.Parent.Layout.Row==2 && app.RouteAxes.Parent.Layout.Column==1);
assert(app.SteeringAxes.Layout.Row==1 && app.SteeringAxes.Layout.Column==1);
assert(isequal(app.CamAxes.Layout.Row,[1 2]) && app.CamAxes.Layout.Column==2);
charts=app.CamAxes.Parent; routePanel=getpixelposition(app.RouteAxes.Parent,true);
chartPosition=getpixelposition(charts,true);
% Managed grids can return a cached size through getpixelposition after resize.
% Their Position dimensions are the current pixel dimensions used by children.
chartPosition(3:4)=charts.Position(3:4);
routePanel(3:4)=app.RouteAxes.Parent.Position(3:4);
routeBox=equalPlotBox(app.RouteAxes); camBox=equalPlotBox(app.CamAxes);
border=findall(app.RouteAxes,'Tag','course-boundary'); bounds=app.Project.params.bounds;
assert(isscalar(border),'Expected one field boundary, found %d.',numel(border));
assert(isequal(border.Position,[bounds(1) bounds(3) diff(bounds(1:2)) diff(bounds(3:4))]));
routeLegend=getpixelposition(app.RouteAxes.Legend,true); camLegend=getpixelposition(app.CamAxes.Legend,true);
front=findobj(app.RouteAxes,'Tag','route-front');
routeLines=findobj(app.RouteAxes,'Type','line'); coveredRoute=0; hiddenRoute=0;
for line=routeLines'
    points=[line.XData(:),line.YData(:)];
    coveredRoute=coveredRoute+covered(app.RouteAxes,points,routeLegend);
    hiddenRoute=hiddenRoute+nnz(any(points<[app.RouteAxes.XLim(1) app.RouteAxes.YLim(1)] ...
        | points>[app.RouteAxes.XLim(2) app.RouteAxes.YLim(2)],2));
end
coveredDirection=0;
for arrow=findobj(app.RouteAxes,'Type','quiver')'
    for fraction=linspace(0,1,21)
        points=[arrow.XData(:)+fraction*arrow.UData(:),arrow.YData(:)+fraction*arrow.VData(:)];
        coveredDirection=coveredDirection+covered(app.RouteAxes,points,routeLegend);
    end
end
cam=findobj(app.CamAxes,'Type','line'); coveredCam=0;
for line=cam'
    coveredCam=coveredCam+covered(app.CamAxes,[line.XData(:),line.YData(:)],camLegend);
end
item=struct('label',label,'windowPixels',app.Figure.Position(3:4), ...
    'chartPosition',chartPosition,'routePanelPosition',routePanel, ...
    'routeColumnFraction',routePanel(3)/(chartPosition(3)-charts.ColumnSpacing), ...
    'steeringRowFraction',outerHeightPixels(app.SteeringAxes)/(chartPosition(4)-charts.RowSpacing), ...
    'routePlotPixels',routeBox(3:4),'camPlotPixels',camBox(3:4), ...
    'routePlotBox',routeBox,'camPlotBox',camBox,'routeLegendBox',routeLegend,'camLegendBox',camLegend, ...
    'fieldBoundsMM',bounds,'routeViewLimitsMM',[app.RouteAxes.XLim app.RouteAxes.YLim], ...
    'routeLegendInside',containsBox(routeBox,routeLegend),'camLegendInside',containsBox(camBox,camLegend), ...
    'routeLegendColumns',app.RouteAxes.Legend.NumColumns,'routeLegendCorner',app.RouteAxes.Legend.Location, ...
    'coveredTargets',covered(app.RouteAxes,app.Project.targets,routeLegend), ...
    'coveredNodes',covered(app.RouteAxes,app.Project.nodes,routeLegend), ...
    'coveredFrontSamples',covered(app.RouteAxes,[front.XData(:),front.YData(:)],routeLegend), ...
    'coveredRouteSamples',coveredRoute,'hiddenRouteSamples',hiddenRoute, ...
    'coveredDirectionSamples',coveredDirection,'coveredCamSamples',coveredCam, ...
    'parameterTablePixels',app.ParamsTable.Position(3:4));
end
function measured=captureLayout(app,path,label)
% exportapp flushes the invisible figure's asynchronous managed layout.
settleLayout(); exportapp(app.Figure,path); settleLayout();
beforeRead=[app.RouteAxes.Position app.RouteAxes.InnerPosition app.CamAxes.Position app.CamAxes.InnerPosition];
measured=measureLayout(app,label);
afterRead=[app.RouteAxes.Position app.RouteAxes.InnerPosition app.CamAxes.Position app.CamAxes.InnerPosition];
assert(max(abs(beforeRead-afterRead))<1e-8,'Measurement mutated managed axes positions.');
exportapp(app.Figure,path); settleLayout(); afterExport=measureLayout(app,label);
assert(max(abs(measured.routeLegendBox-afterExport.routeLegendBox))<1 ...
    && max(abs(measured.camLegendBox-afterExport.camLegendBox))<1 ...
    && max(abs(measured.chartPosition-afterExport.chartPosition))<1,'Export changed layout.');
assert(measured.routeLegendInside && measured.camLegendInside,'Legend extends outside its plot box.');
assert(measured.hiddenRouteSamples==0,'Route plot clips trajectory samples.');
assert(measured.coveredTargets==0 && measured.coveredNodes==0 ...
    && measured.coveredRouteSamples==0 && measured.coveredDirectionSamples==0 ...
    && measured.coveredCamSamples==0,'Legend hides plotted data.');
end
function height=outerHeightPixels(a)
scale=axesPixelScale(a); height=a.OuterPosition(4)*scale(2);
end
function box=equalPlotBox(a)
scale=axesPixelScale(a); position=getpixelposition(a.Parent,true);
inner=a.InnerPosition.*[scale scale]; origin=position(1:2); ratio=diff(a.XLim)/diff(a.YLim);
dimensions=[min(inner(3),inner(4)*ratio),min(inner(4),inner(3)/ratio)];
box=[origin+inner(1:2)+(inner(3:4)-dimensions)/2,dimensions];
end
function scale=axesPixelScale(a)
% Never assign Units on managed axes: conversion writes can change layout.
scale=[1 1];
if strcmp(a.Units,'normalized'), scale=a.Parent.Position(3:4);
else, assert(strcmp(a.Units,'pixels'),'Unexpected managed axes units.'); end
end
function settleLayout()
drawnow; pause(.15); drawnow;
end
function yes=containsBox(outer,inner)
yes=all(inner(1:2)>=outer(1:2)-2) && all(inner(1:2)+inner(3:4)<=outer(1:2)+outer(3:4)+2);
end
function count=covered(a,points,rectangle)
box=equalPlotBox(a);
pixels=(points-[a.XLim(1),a.YLim(1)])./[diff(a.XLim),diff(a.YLim)].*box(3:4)+box(1:2);
count=nnz(all(pixels>=rectangle(1:2),2) & all(pixels<=rectangle(1:2)+rectangle(3:4),2));
end
function closeFigure(app)
if isgraphics(app.Figure), delete(app.Figure); end
end

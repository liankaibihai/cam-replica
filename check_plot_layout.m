function report=check_plot_layout()
root=fileparts(mfilename('fullpath')); addpath(root);
folder=fullfile(root,'outputs','plot_layout'); if ~isfolder(folder), mkdir(folder); end
app=CamReplicaApp('off'); cleaner=onCleanup(@()closeFigure(app));
app.Figure.Visible='on'; drawnow;
exportapp(app.Figure,fullfile(folder,'main_map.png'));
drawnow; mapSize=equalPlotSize(app.RouteAxes);
fprintf('LAYOUT_MEASURE map=%.2fx%.2f inner=%s outer=%s\n',mapSize,mat2str(app.RouteAxes.InnerPosition),mat2str(app.RouteAxes.OuterPosition));
assert(all(mapSize>=[750 250]),'Main map is still too small at 1320x860.');
assert(isequal(app.RouteAxes.DataAspectRatio,[1 1 1]));
arrow=findobj(app.RouteAxes,'Tag','optimization-direction');
assert(all(isnan(arrow.XData)) && any(contains(app.RouteAxes.Legend.String,'AI梯度方向')));
proxy=findobj(app.RouteAxes,'Tag','optimization-direction-legend');
assert(isscalar(proxy) && isequal(proxy.Color,[.85 .15 .65]) && all(isnan(proxy.XData)));
checkCircle(app,50);
assert(numel(findobj(app.RouteAxes,'Tag','optimization-direction-legend'))==1 && numel(app.RouteAxes.Legend.String)==7);
row=find(strcmp(app.ParamsTable.Data(:,1),'零位中心距 ×2 / mm'));
app.ParamsTable.Data{row,2}=120; app.invalidate(); app.calculate(); checkCircle(app,60);
app.toggleSimulation();
row=find(strcmp(app.ParamsTable.Data(:,1),'零位中心距 ×2 / mm'));
app.ParamsTable.Data{row,2}=140; app.invalidate(); app.calculate(); checkCircle(app,60);
app.toggleSimulation(); checkCircle(app,60);
app.Project=camdesign.defaultProject(); app.syncInputs(); app.calculate();
app.Figure.Visible='on'; drawnow; exportapp(app.Figure,fullfile(folder,'main_map.png'));

p=app.Project; p.params.samples=201; p.params.camSamples=241; p.params.iterations=2;
app.Project=p; app.syncInputs(); app.calculate(); app.setBusy(true);
searchUpdates=0; captured=[];
[q,h,info]=camdesign.optimize(p,@observe,'peak-gradient-v2');
assert(searchUpdates==2 && strcmp(info.reason,'iteration_limit'));
app.Project=q; app.History=h; app.OptimizationDirection=[]; app.syncInputs(); app.setBusy(false); app.calculate();
arrow=findobj(app.RouteAxes,'Tag','optimization-direction'); assert(all(isnan(arrow.XData)));
app.beginRouteEditing(); app.routeMapClick(app.Project.nodes(5,:),app.RouteAxes);
app.previewRouteNode(app.Project.nodes(5,:)+[.1 .1],app.RouteAxes); app.cancelRouteEditing();
checkCircle(app,50);
report=struct('release',version('-release'),'windowPixels',app.Figure.Position(3:4), ...
    'mainMapPlotPixels',mapSize,'previousApproxPlotPixels',[400 133], ...
    'searchUpdates',searchUpdates,'directionSample',captured, ...
    'referenceCircleRadiiCheckedMM',[50 60 60],'scope','Layout and callback checks; native mouse hit testing not simulated.');
fid=fopen(fullfile(folder,'verification.json'),'w','n','UTF-8'); assert(fid>=0);
closer=onCleanup(@()fclose(fid)); fprintf(fid,'%s\n',jsonencode(report,PrettyPrint=true));
fprintf('PLOT_LAYOUT_PASS map=%.1fx%.1fpx searchUpdates=%d designReferenceRetained=true\n',mapSize,searchUpdates);
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
            if searchUpdates==1
                captured=struct('baseNodes',data.directionBaseNodes,'gradient',data.gradient,'descentDirection',data.descentDirection);
                exportapp(app.Figure,fullfile(folder,'actual_search_direction.png'));
            end
        end
    end
end

function sizePixels=equalPlotSize(a)
a.Units='pixels'; box=a.InnerPosition; ratio=diff(a.XLim)/diff(a.YLim);
sizePixels=[min(box(3),box(4)*ratio),min(box(4),box(3)/ratio)];
end
function checkCircle(app,radius)
circle=findobj(app.CamAxes,'Tag','zero-reference-circle');
assert(isscalar(circle) && max(abs(hypot(circle.XData,circle.YData)-radius))<1e-10);
assert(numel(findobj(app.CamAxes,'Tag','cam-center'))==1);
assert(any(strcmp(app.CamAxes.Legend.String,'零位参考圆 d/2（原版称基圆）')));
end
function closeFigure(app)
if isgraphics(app.Figure), delete(app.Figure); end
end

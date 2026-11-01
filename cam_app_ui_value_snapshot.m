function snapshot=cam_app_ui_value_snapshot(app)
% Plain UI values supplement the existing complete model-switch snapshot.
roots=app.Figure;
if ~isempty(app.DiagnosticsFigure) && isgraphics(app.DiagnosticsFigure), roots(end+1)=app.DiagnosticsFigure; end
rows=struct('figure',{},'index',{},'class',{},'tag',{},'values',{});
selected={'Value','Data','Text','Enable','Visible','Tag','Name','Position','XLim','YLim','XLimMode','YLimMode'};
for k=1:numel(roots)
    objects=findall(roots(k));
    for n=1:numel(objects)
        object=objects(n); values=struct(); readable=properties(object);
        for j=1:numel(selected)
            % isprop also sees private graphics internals (for example a
            % ToolbarPushButton.Position). properties lists public readers.
            property=selected{j}; if ~ismember(property,readable), continue; end
            value=object.(property);
            if isnumeric(value) || islogical(value) || ischar(value) || isstring(value) || iscell(value)
                values.(property)=value;
            end
        end
        rows(end+1)=struct('figure',k,'index',n,'class',class(object),'tag',object.Tag,'values',values); %#ok<AGROW>
    end
end
snapshot=struct('model',app.snapshotModelSwitchState(),'uiValues',rows,'AutoTuneSeedText',app.AutoTuneSeed.Text, ...
    'flags',struct('Busy',app.Busy,'SimulationMode',app.SimulationMode,'MapEditMode',app.MapEditMode, ...
    'StopRequested',app.StopRequested,'CloseAfterStop',app.CloseAfterStop));
end

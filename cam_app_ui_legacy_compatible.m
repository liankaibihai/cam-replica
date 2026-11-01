function [yes,reason]=cam_app_ui_legacy_compatible(callback,app,key)
% Compare a closed legacy signature and captured values; never eval source.
if isempty(callback), yes=true; reason='empty canonical slot'; return; end
if cam_app_ui_callback_matches(callback,app,key), yes=true; reason='named canonical binding'; return; end
yes=false; reason='foreign, mismatched or unreadable callback';
if ~isa(callback,'function_handle'), return; end
try
    text=regexprep(func2str(callback),'\s+',''); info=functions(callback);
    spec=cam_app_ui_spec(key); prefix='@(~,~)'; args='';
    if startsWith(key,'action/'), args='actionName';
    else
        parts=cell(size(spec.fixedArguments));
        for k=1:numel(parts)
            value=spec.fixedArguments{k};
            if ischar(value), parts{k}=['''' value ''''];
            elseif islogical(value), if value, parts{k}='true'; else, parts{k}='false'; end
            else, parts{k}=num2str(value,17); end
        end
        args=strjoin(parts,',');
    end
    switch spec.mode
        case 'event'
            prefix='@(~,event)'; if ~isempty(args), args=[args ',']; end; args=[args 'event'];
        case 'value', prefix='@(object,~)'; args='object.Value';
        case 'route-point'
            prefix='@(source,~)'; args='source.CurrentPoint(1,1:2),source,app.Figure.SelectionType';
    end
    expected=[prefix 'app.' spec.method '(' args ')'];
    if ~strcmp(text,expected), return; end
    owner=false; action=true;
    if startsWith(key,'action/'), action=false; end
    for k=1:numel(info.workspace)
        workspace=info.workspace{k}; if ~isstruct(workspace), continue; end
        if isfield(workspace,'app') && isa(workspace.app,'CamReplicaApp') && workspace.app==app, owner=true; end
        if startsWith(key,'action/') && isfield(workspace,'actionName')
            action=strcmp(workspace.actionName,spec.fixedArguments{1});
        end
    end
    yes=owner && action;
    if yes, reason='exact legacy signature and captured App/argument identity'; end
catch
    reason='old metadata unreadable; cannot safely identify this slot';
end
end

function cam_app_ui_dispatch(source,event,app,key)
% Named callback bridge: no anonymous function tied to CamReplicaApp.m.
assert(isvalid(app),'cam:CallbackApp','回调对应的窗口对象已失效。');
spec=cam_app_ui_spec(key); args=spec.fixedArguments;
switch spec.mode
    case 'fixed'
    case 'event', args=[args {event}];
    case 'value', args={source.Value};
    case 'source', args={source};
    case 'route-point', args={source.CurrentPoint(1,1:2),source,app.Figure.SelectionType};
    otherwise, error('cam:CallbackMode','未知界面参数模式。');
end
% MATLAB dispatches this named method using app's class. Never eval callback
% source text or call an obsolete anonymous handle.
feval(spec.method,app,args{:});
end

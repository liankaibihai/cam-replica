function cam_app_ui_dispatch(~,~,app,method)
% Named callback bridge: no anonymous function tied to CamReplicaApp.m.
assert(isvalid(app),'cam:CallbackApp','回调对应的窗口对象已失效。');
assert(ismember(method,{'applyTraining','syncTrainingInputs'}),'cam:CallbackMethod','此入口仅分派应用训练设置或还原。');
% MATLAB dispatches this named method using app's class. Never eval callback
% source text or call an obsolete anonymous handle.
feval(method,app);
end

function cam_app_async_receive(message)
% Named DataQueue consumer, always on the client/main MATLAB thread.
if ~isstruct(message) || ~isfield(message,'runId'), return; end
entry=cam_app_async_registry('get',message.runId);
if isempty(entry), return; end
if ~isvalid(entry.app) || ~isgraphics(entry.app.Figure)
    if ~isempty(entry.future), cancel(entry.future); cam_app_async_registry('remove',sprintf('future:%g',entry.future.ID)); end
    cam_app_async_registry('remove',entry.runId); return;
end
cam_app_async('receive',entry.app,message);
end

function cam_app_async_complete(future)
% PassFuture=true also delivers cancellation/worker failures here.
key=sprintf('future:%g',future.ID); entry=cam_app_async_registry('get',key);
if isempty(entry), return; end
if ~isvalid(entry.app) || ~isgraphics(entry.app.Figure)
    cam_app_async_registry('remove',entry.runId); cam_app_async_registry('remove',key); return;
end
cam_app_async('complete',entry.app,future);
end

function cam_invoke_ui_callback(callback,source,event)
% Standard MATLAB callback invocation for tests/scripts and named cell form.
if isempty(callback), return; end
if isa(callback,'function_handle'), feval(callback,source,event);
elseif iscell(callback) && ~isempty(callback) && isa(callback{1},'function_handle')
    feval(callback{1},source,event,callback{2:end});
else, error('cam:CallbackFormat','仅支持function_handle或具名cell回调，不执行字符串代码。'); end
end

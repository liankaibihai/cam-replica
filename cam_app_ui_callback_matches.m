function yes=cam_app_ui_callback_matches(callback,app,key)
yes=false;
try
    yes=iscell(callback) && numel(callback)==3 && isa(callback{1},'function_handle') ...
        && strcmp(func2str(callback{1}),'cam_app_ui_dispatch') && callback{2}==app && strcmp(callback{3},key);
catch
    % Old unreadable metadata never needs to be invoked to repair a slot.
end
end

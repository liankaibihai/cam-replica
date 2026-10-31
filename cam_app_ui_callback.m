function callback=cam_app_ui_callback(app,key)
% Stable cell callback; captures only explicit values, no anonymous source.
cam_app_ui_spec(key); callback={@cam_app_ui_dispatch,app,key};
end

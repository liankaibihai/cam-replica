function value=cam_app_async_registry(action,key,value)
% Client-only registry; workers never receive an App or graphics handle.
persistent entries
if isempty(entries), entries=containers.Map('KeyType','char','ValueType','any'); end
if nargin<3, value=[]; end
switch action
    case 'put', entries(key)=value;
    case 'get', if isKey(entries,key), value=entries(key); end
    case 'remove', if isKey(entries,key), remove(entries,key); end
    otherwise, error('cam:BackgroundRegistry','Unknown registry operation.');
end
end

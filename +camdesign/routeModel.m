function mode=routeModel(p)
mode='cubic';
if isfield(p,'routeModel'), mode=p.routeModel; end
end

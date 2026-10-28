function value = lift(delta,p)
switch p.mechanism
    case 'flat', value=p.lever*tan(delta);
    case 'rack', value=p.lever*delta;
    otherwise, error('cam:Mechanism','尚未实现此机构。');
end
end

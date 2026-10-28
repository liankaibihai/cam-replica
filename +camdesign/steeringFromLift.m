function delta = steeringFromLift(h,p)
switch p.mechanism
    case 'flat', delta=atan(h/p.lever);
    case 'rack', delta=h/p.lever;
    otherwise, error('cam:Mechanism','尚未实现此机构。');
end
end

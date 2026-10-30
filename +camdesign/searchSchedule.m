function controls=searchSchedule(p,iteration)
controls=struct('custom',isfield(p,'training'),'decay',1,'learningScale',1,'smoothingRates',[]);
if controls.custom
    t=p.training;
    controls.decay=(1+floor((iteration-1)/t.adjustInterval))^(-t.adjustExponent);
    controls.learningScale=t.learningRate*controls.decay;
    if t.smoothingRate>0, controls.smoothingRates=t.smoothingRate*controls.decay*[1 .5 .25]; end
end
end

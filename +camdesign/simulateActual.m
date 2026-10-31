function simulation=simulateActual(c,p,frontStart,headingStart,options)
% Actual closed XY polygon -> direct disk contact -> steering -> vehicle.
% pitch/radius/workRadius are never read, even when present in the input.
arguments
    c struct
    p struct
    frontStart (1,2) double {mustBeFinite,mustBeReal}
    headingStart (1,1) double {mustBeFinite,mustBeReal}
    options.GearRatio (1,1) double {mustBeReal}=NaN
    options.Samples (1,1) double {mustBeReal}=NaN
    options.PhaseRange double=[]
    options.ContactToleranceMM (1,1) double {mustBeFinite,mustBePositive}=1e-7
    options.RotationConvention char='clockwise-cam-fixed-positive-x-v1'
end
assert(isfield(c,'actual'),'cam:ActualOutlineInvalid','实际轮廓反推需要actual XY。');
required={'gearRatio','wheelDiameter','driveY','drivenY','driveX','drivenX','sensorX','sensorY','referenceDiameter','lever','rollerRadius','mechanism'};
assert(all(isfield(p,required)),'cam:ActualParameters','缺少实际反推所需物理参数。');
for name=required(1:end-1)
    validateattributes(p.(name{1}),{'double'},{'scalar','finite','real'});
end
assert(p.wheelDiameter>0 && p.gearRatio>0 && p.driveY<0 && abs(p.driveY-p.drivenY)<1e-6 ...
    && p.referenceDiameter>0 && abs(p.lever)>1e-6,'cam:ActualParameters','实际反推物理参数无效。');
assert(ismember(p.mechanism,{'flat','rack'}),'cam:Mechanism','实际反推目前支持平推或齿条。');
ratio=p.gearRatio; if ~isnan(options.GearRatio), ratio=options.GearRatio; end
validateattributes(ratio,{'double'},{'scalar','real','finite','positive'});
phase=phaseSchedule(c,p,options.Samples,options.PhaseRange);
middle=(phase(1:end-1)+phase(2:end))/2;
[query,~,which]=unique([phase;middle]);
[q,contact]=camdesign.contactFromOutline(c.actual,p.rollerRadius,query, ...
    ContactToleranceMM=options.ContactToleranceMM,RotationConvention=options.RotationConvention);
delta=camdesign.steeringFromLift(q-p.referenceDiameter/2,p);
assert(all(isfinite(delta)) && max(abs(delta))<deg2rad(85),'cam:SimulationSteering','实际接触推程导致转角接近或超过85°。');
L=-p.driveY; curvature=tan(delta)/L; denominator=1+p.driveX*curvature;
assert(all(denominator>1e-8),'cam:InverseSingularity','实际反推主动轮速度为零或反向。');
n=numel(phase); endpoints=which(1:n); midpoints=which(n+1:end);
distance=(phase-phase(1))*p.wheelDiameter*ratio/2;
y=zeros(n,3); y(1,:)=[frontStart-L*[cos(headingStart),sin(headingStart)],headingStart];
for k=1:n-1
    h=distance(k+1)-distance(k); a=y(k,:);
    k1=rhs(a,endpoints(k)); k2=rhs(a+h*k1/2,midpoints(k));
    k3=rhs(a+h*k2/2,midpoints(k)); k4=rhs(a+h*k3,endpoints(k+1));
    y(k+1,:)=a+h*(k1+2*k2+2*k3+k4)/6;
end
fw=[cos(y(:,3)),sin(y(:,3))]; right=[sin(y(:,3)),-cos(y(:,3))];
front=y(:,1:2)+L*fw;
simulation=struct('front',front,'rear',y(:,1:2),'drive',y(:,1:2)+p.driveX*right, ...
    'driven',y(:,1:2)+p.drivenX*right,'sensor',front+p.sensorX*right+p.sensorY*fw, ...
    'heading',y(:,3),'driveDistance',distance,'phase',phase,'steering',delta(endpoints), ...
    'physicalGearRatio',ratio,'contactRadius',q(endpoints),'contact',contact, ...
    'maxSteeringDeg',rad2deg(max(abs(delta))),'maxPressureDeg',contact.maxPressureDeg, ...
    'model','actual-polygon-radial-disk-v1','rotationConvention',options.RotationConvention, ...
    'scope','Direct actual-polygon contact at all RK4 endpoints/midpoints; ideal no-slip vehicle, not real-car validation.');
    function out=rhs(state,index)
        out=[cos(state(3)),sin(state(3)),curvature(index)]/denominator(index);
    end
end

function phase=phaseSchedule(c,p,count,range)
hasSchedule=isfield(c,'workPhi') && ~isempty(c.workPhi);
if hasSchedule
    schedule=c.workPhi(:);
    assert(isreal(schedule) && all(isfinite(schedule)) && numel(schedule)>=2 && all(diff(schedule)>0), ...
        'cam:ActualPhase','workPhi仅作为严格递增的显式工作相位序列。');
end
if isempty(range)
    if isfield(c,'workEnd')
        validateattributes(c.workEnd,{'double'},{'scalar','finite','real','positive','<=',2*pi});
        range=[0 c.workEnd];
        if hasSchedule
            assert(abs(schedule(1))<1e-10 && abs(schedule(end)-c.workEnd)<1e-10, ...
                'cam:ActualPhase','workEnd与workPhi工作相位元数据不一致。');
        end
    else
        assert(hasSchedule,'cam:ActualPhase','必须显式提供workEnd、workPhi或PhaseRange，不能从actual顶点角度猜测工作段。');
        range=[schedule(1) schedule(end)];
    end
end
validateattributes(range,{'double'},{'vector','numel',2,'real','finite'}); range=range(:)';
assert(range(1)>=0 && range(2)>range(1) && range(2)<=2*pi+1e-12,'cam:ActualPhase','工作相位范围须位于[0,2π]内并严格递增。');
if isnan(count) && hasSchedule && abs(schedule(1)-range(1))<1e-10 && abs(schedule(end)-range(2))<1e-10
    phase=schedule;
else
    if isnan(count), count=p.samples; end
    validateattributes(count,{'double'},{'scalar','integer','finite','>=',2,'<=',40001});
    phase=linspace(range(1),range(2),count)';
end
end

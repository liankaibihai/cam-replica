function result=firstGenerationCam(frontPath,options)
%FIRSTGENERATIONCAM Faithful numerical port of the supplied first-gen r2.m.
% This compatibility entry point does not use the current route/cam defaults.
% Coordinates/lengths: mm; angles: rad. See docs/FIRST_GENERATION_SOURCE.md.
% The source's two passes, acos without clamp, sign, c/c+f and endpoint
% closure are intentional. Degenerate inputs can yield nonfinite/complex
% results, just as in the source; this function does not repair them.
arguments
    frontPath (:,2) double {mustBeReal,mustBeFinite}
    options.a (1,1) double {mustBeReal,mustBeFinite,mustBePositive}=150
    options.b (1,1) double {mustBeReal,mustBeFinite,mustBePositive}=81.5
    options.c (1,1) double {mustBeReal,mustBeFinite,mustBePositive}=23.5
    options.d (1,1) double {mustBeReal,mustBeFinite,mustBePositive}=200
    options.f (1,1) double {mustBeReal,mustBeFinite,mustBeNonnegative}=3
    options.initialRear double=[]
end
assert(size(frontPath,1)>=2,'cam:FirstGenerationPointCount','第一代算法至少需要两个前轮路线点。');
a=options.a; b=options.b; c=options.c; d=options.d; f=options.f;
initialRear=options.initialRear;
if isempty(initialRear), initialRear=[-1900,a]; end
validateattributes(initialRear,{'double'},{'size',[1 2],'real','finite'},mfilename,'initialRear');
x01=frontPath(:,1)'; y01=frontPath(:,2)'; s=size(frontPath,1);
initialLeft=initialRear+[b/2,0]; initialRight=initialRear-[b/2,0];
[firstRear,firstLeft,firstRight]=advance(x01,y01,a,b,initialRear,initialLeft,initialRight);
[rear,leftTrack,rightTrack]=advance(x01,y01,a,b,firstRear(end,:),firstLeft(end,:),firstRight(end,:));

x02=rear(:,1)'; y02=rear(:,2)';
u=zeros(1,s); l=zeros(1,s-1); x03=zeros(1,s);
steering=zeros(s-1,1); leverArm=zeros(s-1,1); crossZ=zeros(s-1,1);
for i=1:s-1
    v1=[x01(i)-x02(i) y01(i)-y02(i)];
    v2=[x01(i+1)-x01(i) y01(i+1)-y01(i)];
    v3=[x02(i+1)-x02(i) y02(i+1)-y02(i)];
    t=acos(dot(v1,v2)/(norm(v1)*norm(v2)));
    v4=cross([v1 0],[v2 0]);
    if v4(3)>0
        t=-t; m=c+f;
    else
        m=c;
    end
    li=norm(v3);
    u(i)=m*tan(t); l(i)=li; x03(i+1)=x03(i)+li;
    steering(i)=t; leverArm(i)=m; crossZ(i)=v4(3);
end
u(s)=u(1); t1=sum(l); alpha=x03/t1*2*pi; p=u+d/2;
xa=zeros(s-1,1); ya=zeros(s-1,1);
for i=1:s-1
    xa(i)=p(i)*cos(alpha(i)); ya(i)=p(i)*sin(alpha(i));
end
n=(1:s-1)'; o=zeros(size(n));
result=struct('sourceVersion','user-provided-first-generation-r2', ...
    'lengthUnit','mm','angleUnit','rad', ...
    'parameters',struct('a',a,'b',b,'c',c,'d',d,'f',f,'initialRear',initialRear), ...
    'front',frontPath,'rear',rear,'leftTrack',leftTrack,'rightTrack',rightTrack, ...
    'firstPassRear',firstRear,'firstPassLeftTrack',firstLeft,'firstPassRightTrack',firstRight, ...
    'steeringRad',steering,'leverArmMM',leverArm,'crossZ',crossZ, ...
    'rearStepLengthsMM',l(:),'rearDistanceMM',x03(:),'totalRearDistanceMM',t1, ...
    'u',u(:),'alpha',alpha(:),'p',p(:),'all',[n xa ya o]);
end

function [rear,leftTrack,rightTrack]=advance(x01,y01,a,b,rearStart,leftStart,rightStart)
% Same scalar branches/order as either of the source's two identical loops.
s=numel(x01); x02=zeros(1,s); y02=zeros(1,s);
xz=zeros(1,s); yz=zeros(1,s); xy=zeros(1,s); yy=zeros(1,s);
x02(1)=rearStart(1); y02(1)=rearStart(2);
xz(1)=leftStart(1); yz(1)=leftStart(2); xy(1)=rightStart(1); yy(1)=rightStart(2);
for i=1:s-1
    if x01(i+1)==x02(i)
        x=x01(i+1);
        if y01(i+1)>y02(i)
            xz(i+1)=x-b/2; xy(i+1)=x+b/2; y=y01(i+1)-a;
        else
            xz(i+1)=x+b/2; xy(i+1)=x-b/2; y=y01(i+1)+a;
        end
        yz(i+1)=y; yy(i+1)=y;
    else
        t=atan((y01(i+1)-y02(i))/(x01(i+1)-x02(i)));
        if x01(i+1)>x02(i)
            x=x01(i+1)-a*cos(t); y=y01(i+1)-a*sin(t);
            xz(i+1)=x-b/2*sin(t); xy(i+1)=x+b/2*sin(t);
            yz(i+1)=y+b/2*cos(t); yy(i+1)=y-b/2*cos(t);
        else
            x=x01(i+1)+a*cos(t); y=y01(i+1)+a*sin(t);
            xz(i+1)=x+b/2*sin(t); xy(i+1)=x-b/2*sin(t);
            yz(i+1)=y-b/2*cos(t); yy(i+1)=y+b/2*cos(t);
        end
    end
    x02(i+1)=x; y02(i+1)=y;
end
rear=[x02(:),y02(:)]; leftTrack=[xz(:),yz(:)]; rightTrack=[xy(:),yy(:)];
end

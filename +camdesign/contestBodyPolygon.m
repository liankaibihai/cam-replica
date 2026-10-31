function points=contestBodyPolygon(front,heading,cfg,kind)
% One pose, body heading (not front-wheel tangent), front-axis origin.
if nargin<4, kind='envelope'; end
if strcmp(kind,'envelope'), x=[-cfg.leftMM cfg.rightMM]; y=[-cfg.rearMM cfg.frontMM];
else, x=[cfg.coverXMinMM cfg.coverXMaxMM]; y=[cfg.coverYMinMM cfg.coverYMaxMM]; end
local=[x(1) y(1);x(2) y(1);x(2) y(2);x(1) y(2);x(1) y(1)];
points=front+local(:,1)*[sin(heading),-cos(heading)]+local(:,2)*[cos(heading),sin(heading)];
end

function report=check_video251_features()
% Hand-computed feature checks, independent of the production route/score.
root=fileparts(mfilename('fullpath')); addpath(root); checks={}; tolerance=1e-12;
triangle=[0 0;3 0;3 4;0 0];
f=camdesign.video251Features(triangle,triangle,[0 pi/6 -pi/6]);
assertClose(f.frontSegmentLengthsMM,[3;4;5],tolerance);
assertClose(f.controlSegmentLengthsMM,[3;4;5],tolerance);
assert(abs(f.frontPolylineLengthMM-12)<tolerance);
checks{end+1}='hand-computed 3-4-5 triangle segment lengths and perimeter';

straight=[0 0;1 0;4 0;7 0;9 0];
f=camdesign.video251Features(straight,[0 0;10 0],zeros(4,1));
assertClose(f.controlTurnAnglesRad,zeros(3,1),tolerance);
assertClose(f.controlTurnFirstDifferenceRad,zeros(2,1),tolerance);
assertClose(f.controlTurnSecondDifferenceRad,0,tolerance);
checks{end+1}='straight control polygon and first/second differences';

turns=[0 0;1 0;1 1;2 1;1 1];
f=camdesign.video251Features(turns,triangle,[0;0]);
assertClose(f.controlTurnAnglesRad,[pi/2;pi/2;pi],tolerance);
assertClose(f.controlTurnFirstDifferenceRad,[0;pi/2],tolerance);
assertClose(f.controlTurnSecondDifferenceRad,pi/2,tolerance);
checks{end+1}='unsigned right angles and reversal with known difference orders';

angles=[-pi/4;0;pi/6;-pi/3;pi/3];
f=camdesign.video251Features(turns,triangle,angles');
assertClose(f.frontWheelAnglesRad,angles,tolerance);
assertClose(f.frontWheelFirstDifferenceRad,[pi/4;pi/6;-pi/2;2*pi/3],tolerance);
assertClose(f.frontWheelSecondDifferenceRad,[-pi/12;-2*pi/3;7*pi/6],tolerance);
assert(strcmp(f.angleUnit,'rad') && f.frontWheelAngleCount==5 && f.frontPathPointCount==4);
assert(~f.aggregationImplemented && ~f.scoreImplemented && ~isfield(f,'score'));
checks{end+1}='signed radians preserved; no degree conversion, normalization or invented score';

control=[0 0;3 0;3 4;6 5;5 9];
base=camdesign.video251Features(control,triangle,angles);
a=.37; rotation=[cos(a) -sin(a);sin(a) cos(a)]; shift=[17 -9];
transformed=camdesign.video251Features(control*rotation+shift,triangle*rotation+shift,angles);
assertClose(transformed.frontSegmentLengthsMM,base.frontSegmentLengthsMM,tolerance);
assertClose(transformed.controlSegmentLengthsMM,base.controlSegmentLengthsMM,tolerance);
assertClose(transformed.controlTurnAnglesRad,base.controlTurnAnglesRad,tolerance);
assertClose(transformed.controlTurnFirstDifferenceRad,base.controlTurnFirstDifferenceRad,tolerance);
assertClose(transformed.controlTurnSecondDifferenceRad,base.controlTurnSecondDifferenceRad,tolerance);
assertClose(transformed.frontWheelAnglesRad,base.frontWheelAnglesRad,tolerance);
checks{end+1}='translation/rotation invariance of lengths, unsigned turns and supplied steering';

scale=2.5; scaled=camdesign.video251Features(scale*control,scale*triangle,angles);
assertClose(scaled.frontSegmentLengthsMM,scale*base.frontSegmentLengthsMM,tolerance);
assertClose(scaled.controlSegmentLengthsMM,scale*base.controlSegmentLengthsMM,tolerance);
assert(abs(scaled.frontPolylineLengthMM-scale*base.frontPolylineLengthMM)<tolerance);
assertClose(scaled.controlTurnAnglesRad,base.controlTurnAnglesRad,tolerance);
assertClose(scaled.controlTurnFirstDifferenceRad,base.controlTurnFirstDifferenceRad,tolerance);
assertClose(scaled.controlTurnSecondDifferenceRad,base.controlTurnSecondDifferenceRad,tolerance);
assertClose(scaled.frontWheelFirstDifferenceRad,base.frontWheelFirstDifferenceRad,tolerance);
assertClose(scaled.frontWheelSecondDifferenceRad,base.frontWheelSecondDifferenceRad,tolerance);
checks{end+1}='uniform scaling changes lengths only; raw angle differences are not per-mm derivatives';

assertError(@()camdesign.video251Features([0 0;0 0;1 0],triangle,angles),'cam:Video251ZeroControlEdge');
assertError(@()camdesign.video251Features(control,[0 0;0 0;1 0],angles),'cam:Video251ZeroFrontEdge');
assertError(@()camdesign.video251Features([0 0],triangle,angles),'cam:Video251ControlPointCount');
assertError(@()camdesign.video251Features(control,[0 0],angles),'cam:Video251FrontPointCount');
two=camdesign.video251Features([0 0;1 0],[0 0;1 0],0);
assert(isempty(two.controlTurnAnglesRad) && isempty(two.controlTurnFirstDifferenceRad) ...
    && isempty(two.controlTurnSecondDifferenceRad) && isempty(two.frontWheelFirstDifferenceRad) && isempty(two.frontWheelSecondDifferenceRad));
checks{end+1}='zero-length/one-point inputs rejected and minimal inputs return empty differences';

report=struct('release',version('-release'),'sourceVersion','2.5.1-visible-fragment', ...
    'checks',{checks},'passed',numel(checks),'tolerance',tolerance, ...
    'handExample',f,'scope','Raw visible feature formulas only; no unknown aggregation, score, Bezier generation, original 3.1.2 or vehicle equivalence.');
folder=fullfile(root,'outputs','video251_features'); if ~isfolder(folder), mkdir(folder); end
fid=fopen(fullfile(folder,'verification.json'),'w','n','UTF-8'); assert(fid>=0);
closer=onCleanup(@()fclose(fid)); fprintf(fid,'%s\n',jsonencode(report,PrettyPrint=true));
for i=1:numel(checks), fprintf('VIDEO251_FEATURE_CASE_PASS %s\n',checks{i}); end
fprintf('VIDEO251_FEATURES_PASS %d checks\n',numel(checks));
end

function assertClose(actual,expected,tolerance)
assert(isequal(size(actual),size(expected)) && all(abs(actual-expected)<tolerance,'all'));
end
function assertError(action,identifier)
observed=''; try, action(); catch ex, observed=ex.identifier; end
assert(strcmp(observed,identifier),'Expected %s, observed %s.',identifier,observed);
end

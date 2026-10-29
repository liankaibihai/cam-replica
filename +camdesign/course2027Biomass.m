function course = course2027Biomass()
%COURSE2027BIOMASS Reference checkpoints, separate from vehicle/launch data.
% Source: user-supplied 2027 rules PDF, table 4, pp. 15-16.
root=fileparts(fileparts(mfilename('fullpath')));
course=jsondecode(fileread(fullfile(root,'data','2027_biomass_course.json')));
course.preliminaryPoints=course.points(course.preliminaryIDs);
course.preliminaryOfficialMM=reshape([course.preliminaryPoints.officialMM],2,[])';
course.preliminarySoftwareMM=reshape([course.preliminaryPoints.softwareMM],2,[])';
end

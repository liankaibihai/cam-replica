function course = course2027Solar()
%COURSE2027SOLAR Team category; Earth is intentionally first and last.
% Source: user-supplied 2027 rules PDF, table 2, p. 6.
root=fileparts(fileparts(mfilename('fullpath')));
course=jsondecode(fileread(fullfile(root,'data','2027_solar_course.json')));
course.preliminaryPoints=course.points(course.preliminaryIDs);
course.preliminaryOfficialMM=reshape([course.preliminaryPoints.officialMM],2,[])';
course.preliminarySoftwareMM=reshape([course.preliminaryPoints.softwareMM],2,[])';
end

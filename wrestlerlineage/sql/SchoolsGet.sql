select	SchoolID = School.ID
		, School.SchoolName
from	School
where	School.Classification is not null
		and School.SchoolState = 'sc'
		and School.SchoolName <> 'fort mill'
		-- and school.id = 65
order by
		School.Classification desc
		, School.Region

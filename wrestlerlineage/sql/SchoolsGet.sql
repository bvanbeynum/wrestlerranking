select	SchoolID = School.ID
		, School.SchoolName
from	School
where	School.Classification is not null
		and School.SchoolState = 'sc'
		and School.SchoolName <> 'fort mill'
		-- and school.id = 65
order by
		case when School.Region = 3 and School.Classification like '5A%' then 1 else 2 end
		, trim(substring(School.Classification, 1, 2)) desc
		, School.Region

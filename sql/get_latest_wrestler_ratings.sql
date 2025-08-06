with latest_rating as (
	select
		EventWrestlerID
		, Rating
		, Deviation
		, row_number() over(partition by EventWrestlerID order by PeriodEndDate desc) as row_num
	from
		WrestlerRating
)
select
	EventWrestlerID
	, Rating
	, Deviation
from
	latest_rating
where
	row_num = 1;
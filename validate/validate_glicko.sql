-- Drop temporary tables if they exist to ensure a clean run
if object_id('tempdb..#MatchRatings') is not null drop table #MatchRatings;
if object_id('tempdb..#PredictionAnalysis') is not null drop table #PredictionAnalysis;

-- Step 1: Pre-calculate the validity period for each wrestler rating in a CTE.
-- This is the key optimization: we process the 8 million+ row WrestlerRating table only ONCE.
with WrestlerRatingWithValidityPeriod as (
	select
		EventWrestlerID
		, Rating
		, Deviation
		, PeriodEndDate as ValidFrom
		-- Find the start of the next rating period for this wrestler. This rating is valid until that next date.
		, lead(PeriodEndDate, 1, '9999-12-31') over (partition by EventWrestlerID order by PeriodEndDate) as ValidUntil
	from WrestlerRating with (nolock)
)
-- Step 2: Join matches to the pre-calculated rating periods.
-- This is now a much more efficient set-based range join instead of millions of lookups.
select
	MatchID = EventMatch.ID
	, Event.EventDate
	, EventMatch.Division
	, WinnerPreviousRating = WinnerRating.Rating
	, WinnerPreviousDeviation = WinnerRating.Deviation
	, LoserPreviousRating = LoserRating.Rating
	, LoserPreviousDeviation = LoserRating.Deviation
	, WinnerRatingPeriodCount = WinnerRatingCount.RatingPeriodCount
	, LoserRatingPeriodCount = LoserRatingCount.RatingPeriodCount
into #MatchRatings
from EventMatch with (nolock)
join Event with (nolock) on EventMatch.EventID = Event.ID
-- Get the winner of the match
join EventWrestlerMatch as Winner with (nolock)
	on EventMatch.ID = Winner.EventMatchID and Winner.IsWinner = 1
-- Get the loser of the match
join EventWrestlerMatch as Loser with (nolock)
	on EventMatch.ID = Loser.EventMatchID and Loser.IsWinner = 0
-- Join to the winner's rating that was valid at the time of the match
join WrestlerRatingWithValidityPeriod as WinnerRating
	on Winner.EventWrestlerID = WinnerRating.EventWrestlerID
	and Event.EventDate >= WinnerRating.ValidFrom
	and Event.EventDate < WinnerRating.ValidUntil
-- Join to the loser's rating that was valid at the time of the match
join WrestlerRatingWithValidityPeriod as LoserRating
	on Loser.EventWrestlerID = LoserRating.EventWrestlerID
	and Event.EventDate >= LoserRating.ValidFrom
	and Event.EventDate < LoserRating.ValidUntil
-- Get the counts using a more efficient cross apply on a smaller, pre-filtered dataset
cross apply (
    select count(ID) as RatingPeriodCount
    from WrestlerRating with (nolock)
    where EventWrestlerID = Winner.EventWrestlerID and PeriodEndDate < Event.EventDate
) as WinnerRatingCount
cross apply (
    select count(ID) as RatingPeriodCount
    from WrestlerRating with (nolock)
    where EventWrestlerID = Loser.EventWrestlerID and PeriodEndDate < Event.EventDate
) as LoserRatingCount;


-- Step 3: Stage the prediction analysis in a second temp table
select
	*
	, IsCorrectPrediction = case
		when WinnerPreviousRating > LoserPreviousRating then 1
		else 0
	end
into #PredictionAnalysis
from #MatchRatings;

-- Step 4: Final aggregation and bucketing from the pre-computed temp table
select
	Dimension = 'Overall'
	, Bucket = 'All'
	, CorrectPredictions = sum(IsCorrectPrediction)
	, TotalMatches = count(*)
	, Accuracy = (cast(sum(IsCorrectPrediction) as float) / count(*)) * 100
from #PredictionAnalysis

union all

-- Accuracy by Winner's Deviation
select
	Dimension = 'Winner Deviation'
	, Bucket = case
		when WinnerPreviousDeviation between 0 and 50 then '0-50'
		when WinnerPreviousDeviation between 51 and 100 then '51-100'
		when WinnerPreviousDeviation between 101 and 150 then '101-150'
		when WinnerPreviousDeviation between 151 and 200 then '151-200'
		when WinnerPreviousDeviation between 201 and 250 then '201-250'
		when WinnerPreviousDeviation between 251 and 300 then '251-300'
		when WinnerPreviousDeviation between 301 and 350 then '301-350'
		else '350+'
	end
	, CorrectPredictions = sum(IsCorrectPrediction)
	, TotalMatches = count(*)
	, Accuracy = (cast(sum(IsCorrectPrediction) as float) / count(*)) * 100
from #PredictionAnalysis
group by
	case
		when WinnerPreviousDeviation between 0 and 50 then '0-50'
		when WinnerPreviousDeviation between 51 and 100 then '51-100'
		when WinnerPreviousDeviation between 101 and 150 then '101-150'
		when WinnerPreviousDeviation between 151 and 200 then '151-200'
		when WinnerPreviousDeviation between 201 and 250 then '201-250'
		when WinnerPreviousDeviation between 251 and 300 then '251-300'
		when WinnerPreviousDeviation between 301 and 350 then '301-350'
		else '350+'
	end

union all

-- Accuracy by Winner's Rating Period Count
select
	Dimension = 'Winner Rating Periods'
	, Bucket = case
		when WinnerRatingPeriodCount >= 10 then '10+'
		else cast(WinnerRatingPeriodCount as varchar)
	end
	, CorrectPredictions = sum(IsCorrectPrediction)
	, TotalMatches = count(*)
	, Accuracy = (cast(sum(IsCorrectPrediction) as float) / count(*)) * 100
from #PredictionAnalysis
group by
	case
		when WinnerRatingPeriodCount >= 10 then '10+'
		else cast(WinnerRatingPeriodCount as varchar)
	end

union all

-- Accuracy by Time of Year (Month)
select
	Dimension = 'Month'
	, Bucket = cast(datepart(month, EventDate) as varchar)
	, CorrectPredictions = sum(IsCorrectPrediction)
	, TotalMatches = count(*)
	, Accuracy = (cast(sum(IsCorrectPrediction) as float) / count(*)) * 100
from #PredictionAnalysis
group by
	datepart(month, EventDate)

union all

-- Accuracy by Division
select
	Dimension = 'Division'
	, Bucket = Division
	, CorrectPredictions = sum(IsCorrectPrediction)
	, TotalMatches = count(*)
	, Accuracy = (cast(sum(IsCorrectPrediction) as float) / count(*)) * 100
from #PredictionAnalysis
where
	Division is not null
group by
	Division

order by
	Dimension, Bucket;

-- Clean up the temporary tables
if object_id('tempdb..#MatchRatings') is not null drop table #MatchRatings;
if object_id('tempdb..#PredictionAnalysis') is not null drop table #PredictionAnalysis;

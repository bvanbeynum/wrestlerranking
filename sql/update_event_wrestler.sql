update	EventWrestler
set	GlickoRating = @GlickoRating
	,GlickoDeviation = @GlickoDeviation
where
	ID = @ID;

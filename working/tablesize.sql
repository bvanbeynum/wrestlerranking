with TableAndIndexSizes as (
	select
		Schemas.name as SchemaName,
		Tables.name as TableName,
		coalesce(Indexes.name, 'HEAP') as IndexName,
		Indexes.type_desc as IndexType,
		sum(Partitions.rows) as TotalRows,
		sum(AllocationUnits.total_pages) * 8 as TotalSpaceInKB
	from
		sys.tables as Tables
	inner join
		sys.schemas as Schemas on Tables.schema_id = Schemas.schema_id
	inner join
		sys.indexes as Indexes on Tables.object_id = Indexes.object_id
	inner join
		sys.partitions as Partitions on Indexes.object_id = Partitions.object_id and Indexes.index_id = Partitions.index_id
	inner join
		sys.allocation_units as AllocationUnits on Partitions.partition_id = AllocationUnits.container_id
	where
		Tables.is_ms_shipped = 0
		and Indexes.object_id > 255
	group by
		Schemas.name,
		Tables.name,
		Indexes.name,
		Indexes.type_desc
),
TableTotalSizes as (
	select
		SchemaName,
		TableName,
		IndexName,
		IndexType,
		TotalRows,
		TotalSpaceInKB,
		sum(TotalSpaceInKB) over (partition by SchemaName, TableName) as TableTotalSpaceInKB
	from
		TableAndIndexSizes
)
select
	SchemaName,
	TableName,
	IndexName,
	IndexType,
	TotalRows,
	case
		when TotalSpaceInKB >= 1048576 -- 1024 * 1024
			then cast(cast(TotalSpaceInKB / 1048576.0 as decimal(18, 2)) as varchar(24)) + ' GB'
		when TotalSpaceInKB >= 1024
			then cast(cast(TotalSpaceInKB / 1024.0 as decimal(18, 2)) as varchar(24)) + ' MB'
		else
			cast(TotalSpaceInKB as varchar(24)) + ' KB'
	end as IndexReadableSize,
	case
		when TableTotalSpaceInKB >= 1048576 -- 1024 * 1024
			then cast(cast(TableTotalSpaceInKB / 1048576.0 as decimal(18, 2)) as varchar(24)) + ' GB'
		when TableTotalSpaceInKB >= 1024
			then cast(cast(TableTotalSpaceInKB / 1024.0 as decimal(18, 2)) as varchar(24)) + ' MB'
		else
			cast(TableTotalSpaceInKB as varchar(24)) + ' KB'
	end as TableReadableTotalSize
from
	TableTotalSizes
order by
	TableTotalSpaceInKB desc,
	TableName,
	TotalSpaceInKB desc;

--> row counts for all tables
select  [Schema] = schema_name(obj.schema_id),
        [Table] = obj.name,
        Rows = sum(dmv.row_count)
from    sys.objects as obj
        inner join sys.dm_db_partition_stats as dmv
          on obj.object_id = dmv.object_id
where   obj.type = 'U'
        and obj.is_ms_shipped = 0x0
        and dmv.index_id in (0,1)
group by obj.schema_id, obj.name
order by 1, 2

		--2/13/2020 Modified the checkings on RU patching and optimizer_features_enable for 19c
		--10/16/2019 Added db Character Set WE8MSWIN1252
		--9/10/2019 Checking in container db is TBD. If it is a pluggable db, get dbid and dbname from dba_pdbs.
		--8/19/2019 Ensure the default fix_control (BUGNO = 17376322) value 0 to allow more than 1000 columns in select
		--8/9/2019 Added Eagle System Setting parameters set in PACE_MASTERDBO.PACE_SYSTEM table
		--7/23/2019 Added checking for inmemory_size parameter:recommended value is the default 0 for IM column storage not used
		--5/21/2019 compare the patch_id/l_patchid without the last digit(day) as the patch release date could be 15,16 or 17
		--3/21/2019 disable auto evolving of Sql Plan Baselines
		--3/21/2019 set AUTO_STAT_EXTENSIONS OFF (default)
		--3/18/2019 set _cursor_obsolete_threshold=1024 for high cursor Mutex wait issue
		set linesize 500
		set serveroutput on
		set echo off
		ALTER SESSION SET NLS_DATE_FORMAT='YYYY-MM-DD HH24:MI:SS';
		declare
		l_name varchar2(64);
		l_version varchar2(64);
		l_cnt number;
		l_dbid number;
		l_type varchar2(10);
		l_patchid varchar2(10);
		l_currentdate number;
		l_patch_str varchar2(2000);
		l_str varchar2(100);
		l_report CLOB;
		FUNCTION GENERATE_REPORT(   
			DB_NAME VARCHAR2,
			DB_ID VARCHAR2,
			DB_VERSION  VARCHAR2, 
			PATCH_INFO  VARCHAR2,  
			PATCH_ID  VARCHAR2,
			DB_TYPE VARCHAR2)  
		RETURN CLOB
		IS
		l_sql clob;
		BEGIN
			 DBMS_OUTPUT.PUT_LINE(chr(10)||'Report Date: '||sysdate);
			 DBMS_OUTPUT.PUT_LINE('************************************************************ DB Setting Report for '||DB_NAME||'('||DB_VERSION||')**************************************************************'||chr(39));
			 DBMS_OUTPUT.PUT_LINE('--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------' ||chr(39));
			 DBMS_OUTPUT.PUT_LINE('Parameter Name                  EAGLE Recommended Value            Current Value  Comments(check Best Practice for details)');
			 DBMS_OUTPUT.PUT_LINE('--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------' ||chr(39));
			 l_sql := 'DECLARE
			 BEGIN
			 for i in (with eagle_db_settings as (select ''optimizer_mode'' name, ''ALL_ROWS'' recommended_value, '''' comments from dual union all
			 select ''db_block_size'' name, ''8192'' recommended_value, '''' comments from dual union all
			 select ''processes'' name, ''4000'' recommended_value, ''Generally, this parameter needs to be high to deal with engine concurrency requirements. '' comments from dual union all
			 select ''_unnest_subquery'' name,''TRUE'' recommended_value, ''Set to TRUE at database level'' comments from dual union all
			 select ''_asm_healthcheck_timeout'' name,''7200'' recommended_value, ''Set to 7200 for both DB and ASM Instance'' comments from dual union all
			 select ''cursor_sharing'' name, ''EXACT'' recommended_value, '''' comments from dual union all
			 select ''db_files'' name, ''350'' recommended_value, '''' comments from dual union all
			 select ''log_checkpoint_interval'' name, ''0'' recommended_value, '''' comments from dual union all
			 select ''log_checkpoint_timeout'' name, ''0'' recommended_value, '''' comments from dual union all
			 select ''parallel_adaptive_multi_user'' name, ''FALSE'' recommended_value, '''' comments from dual union all
			 select ''sga_target'' name,    case when value <8 then ''number of CPU <8'' END||
				case when value >= 8 and value<16 then ''12884901888'' END||
				case when value >=16 and value <24 then ''25769803776'' END ||
				case when value >= 24 and value <32 then ''38654705664'' END ||
				case when value >= 32 then ''51539607552'' END as recommended_value,    case when value <8 then ''Number of CPU is ''||value||'', recommend at least 8 CPUs'' END||
				case when value >= 8 and value<16 then ''For ''||value||'' CPUs, recommend SGA 12G'' END||
				case when value >=16 and value <24 then ''For ''||value||'' CPUs, recommend SGA 24G'' END ||
				case when value >= 24 and value <32 then ''For ''||value||'' CPUs, recommend SGA 36G'' END ||
				case when value >= 32 then ''For ''||value||'' CPUs, recommend SGA 48G'' END as comments from v$parameter where name like ''cpu_count'' union all
			 select ''pga_aggregate_target'' name,    case when value <8 then ''number of CPU <8'' END||
				case when value >= 8 and value<16 then ''12884901888'' END||
				case when value >=16 and value <24 then ''25769803776'' END ||
				case when value >= 24 and value <32 then ''38654705664'' END ||
				case when value >= 32 then ''51539607552'' END as recommended_value,    case when value <8 then ''Number of CPU is ''||value||'', recommend at least 8 CPUs'' END||
				case when value >= 8 and value<16 then ''For ''||value||'' CPUs, recommend PGA 12G'' END||
				case when value >=16 and value <24 then ''For ''||value||'' CPUs, recommend PGA 24G'' END ||
				case when value >= 24 and value <32 then ''For ''||value||'' CPUs, recommend PGA 36G'' END ||
				case when value >= 32 then ''For ''||value||'' CPUs, recommend PGA 48G'' END as comments from v$parameter where name like ''cpu_count'' union all
			 select ''query_rewrite_enabled'' name, ''TRUE'' recommended_value, '''' comments from dual union all
			 select ''query_rewrite_integrity'' name, ''TRUSTED'' recommended_value, '''' comments from dual union all  
			 select ''optimizer_capture_sql_plan_baselines'', ''FALSE'' recommended_value, '''' comments from dual union all	
			 select ''optimizer_use_sql_plan_baselines'', ''FALSE'' recommended_value, '''' comments from dual union all		 
			 select ''session_cached_cursors'' name, ''1000'' recommended_value, '' Set to 1000 to reduce "library cache" latch contention. It should be about 25% of the total cursors.'' comments from dual union all
			 select ''memory_target'' name, ''0'' recommended_value, ''Use ASMM'' comments from dual union all
			 select ''db_file_multiblock_read_count'' name, ''8'' recommended_value, '''' comments from dual union all
			 select ''workarea_size_policy'' name, ''AUTO'' recommended_value, '''' comments from dual union all    
			 select ''fast_start_mttr_target'' name, ''300'' recommended_value, '''' comments from dual union all
			 select ''undo_retention'' name, ''10800'' recommended_value, '''' comments from dual union all
			 select ''dml_locks'' name, ''19992'' recommended_value, ''4 * Transactions'' comments from dual union all
			 select ''temp_undo_enabled'' name, ''TRUE'' recommended_value, '''' comments from dual union all
			 select ''NLS_LANGUAGE'' name, ''AMERICAN'' recommended_value, '''' comments from dual union all
			 select ''NLS_CHARACTERSET'' name, ''WE8MSWIN1252 or WE8ISO8859P1 or WE8ISO8859P15'' recommended_value, '''' comments from dual union all
			 select ''nls_date_format'' name, ''MM/DD/YYYY'' recommended_value, ''*Informational*'' comments from dual union all
			 select ''awr_snapshot_interval'' name, ''30'' recommended_value, '''' comments from dual union all
			 select ''awr_retention_interval'' name, ''45'' recommended_value, '''' comments from dual union all
			 select ''_report_capture_cycle_time'' name, ''0'' recommended_value, '''' comments from dual union all
			 select ''recyclebin'' name, ''OFF'' recommended_value, '''' comments from dual union all
			 -- Modified for 19c on 2/13/2020
			 select ''optimizer_features_enable'' name, case when substr('''||DB_VERSION||''',1,2) not like ''19'' then substr('''||DB_VERSION||''',1,length('''||DB_VERSION||''')-2) END ||
				case when substr('''||DB_VERSION||''',1,2)=''19'' then ''19.1.0'' END as recommended_value, '''' comments from dual union all
			 select ''optimizer_adaptive_features'' name, ''FALSE'' recommended_value, ''Set to FALSE to disable the adaptive features'' comments from dual union all
			 select ''_optimizer_adaptive_plans'' name, ''FALSE'' recommended_value, ''Set to FALSE to disable the adaptive plans'' comments from dual union all
			 select ''optimizer_adaptive_statistics'' name, ''FALSE'' recommended_value,''Set to FALSE to disable the adaptive statistics'' comments from dual union all
			 select ''optimizer_adaptive_plans'' name, ''FALSE'' recommended_value, ''Set to FALSE to disable the adaptive plans'' comments from dual union all
			 select ''_optimizer_use_feedback'' name, ''FALSE'' recommended_value, ''Set to FALSE to disable the use feedback feature'' comments from dual union all
			 -- Added on 3/18/2019
			 select ''_cursor_obsolete_threshold'' name, ''1024'' recommended_value, '''' comments from dual union all
			 -- Added on 7/23/2019
			 select ''inmemory_size'' name, ''0'' recommended_value, '''' comments from dual)
			 select p.name,e.recommended_value, p.value,e.comments from eagle_db_settings e, v$parameter p where e.name=p.name and ((e.recommended_value!=p.value and p.value is not null) or (p.value is null))
			 union
			 select e.name,e.recommended_value, n.value,e.comments from eagle_db_settings e, nls_database_parameters n where e.name=n.parameter and n.parameter=''NLS_CHARACTERSET'' and n.value not in (''WE8ISO8859P1'',''WE8ISO8859P15'',''WE8MSWIN1252'')
			 union
			 select e.name,e.recommended_value, n.value,e.comments from eagle_db_settings e, nls_database_parameters n where e.name=n.parameter and n.parameter!=''NLS_CHARACTERSET'' and e.recommended_value!=n.value
			 union
			 select p.name, '''||DB_VERSION||''' recommended_value, p.value, ''Set to the current db version'' comments from v$parameter p where p.name=''compatible'' and substr('''||DB_VERSION||''',1,6)!=substr(p.value,1,6)
			 union
			 select p.name, ''DEFAULT'' recommended_value, p.value, ''Please reset it to the default (Remove this parameter from the initialization file)'' comments from v$parameter p where p.name=''pga_aggregate_limit'' and ( p.value=''0'' or p.isdefault=''FALSE'')
			 union    
			 select p.name, ''DEFAULT or bigger than 4550'' recommended_value, p.value, '''' comments from v$parameter p where p.name=''sessions'' and p.value < ''4550''
			 union
			 select p.name, ''4000'' recommended_value, p.value, '''' comments from v$parameter p where p.name=''open_cursors'' and p.value < ''4000''
			 union
			 select p.name, ''DEFAULT or bigger than 30MB'' recommended_value, p.value, '''' comments from v$parameter p where p.name=''log_buffer'' and p.value < ''31457280''
			 union
			 select p.name, ''DEFAULT or bigger than 19992'' recommended_value, p.value, ''4 * Transactions'' comments from v$parameter p where p.name=''dml_locks'' and p.value < ''19992''
			 union
			 select e.name,e.recommended_value,TO_CHAR(extract( day from snap_interval) *24*60+extract( hour from snap_interval) *60+extract( minute from snap_interval)) "value",e.comments from dba_hist_wr_control d,eagle_db_settings e
		where dbid='''||DB_ID||''' and e.name=''awr_snapshot_interval'' and e.recommended_value!=TO_CHAR(extract( day from snap_interval) *24*60+extract( hour from snap_interval) *60+extract( minute from snap_interval ))
			 union
			 select e.name,e.recommended_value,TO_CHAR((extract( day from retention) *24*60+extract( hour from retention) *60+extract( minute from retention ))/24/60) "value", e.comments from dba_hist_wr_control d,eagle_db_settings e
		where dbid='''||DB_ID||''' and e.name=''awr_retention_interval'' and e.recommended_value!=TO_CHAR((extract( day from retention) *24*60+extract( hour from retention) *60+extract( minute from retention ))/24/60)
			 union
			 select client_name "name",''DISABLED'' recommended_value, status "Value", '''' comments from dba_autotask_operation where status=''ENABLED''
			 union
			 select ''flashback_on'' "name",''NO'' recommended_value, flashback_on "Value", ''Recommend to turn off flashback to avoid performance overhead'' comments from v$database where flashback_on!=''NO''
			 union
			 select REGEXP_REPLACE('''||PATCH_INFO||''',''[[:digit:]]+'', ''''), '''||PATCH_ID||''' recommended_value, REGEXP_REPLACE('''||PATCH_INFO||''',''[^0-9]+'', ''''), ''The latest minus one Database Bundle Patch should be applied'' comments from dual where '''||PATCH_INFO||''' is not null
			 union
			 select ''fix_control:24010030'' name, ''1'' recommended_value, to_char(value) "Value", ''Turn on the fix for 24010030 '' comments from v$system_fix_control where bugno in (24010030) and value !=1
			 union
			 --8/19/2019 Ensure the default fix_control (BUGNO = 17376322) value 0 to allow more than 1000 columns in select
			 select ''fix_control:17376322'' name, ''0'' recommended_value, to_char(value) "Value", ''allow 1000 columns in select statement '' comments from v$system_fix_control where bugno in (17376322) and value !=0
			 union
			 select a.ksppinm "name",e.recommended_value, b.ksppstvl "Value", e.comments from eagle_db_settings e, x$ksppi a, x$ksppcv b where a.indx = b.indx and e.name=a.ksppinm and e.recommended_value!=b.ksppstvl
			 union
			 -- Added on 8/7/2019
			 select ''Eagle Syetem Setting: sys_item=97'' name,''10'' recommended_value, sys_value, ''update PACE_MASTERDBO.PACE_SYSTEM set sys_value=10 where sys_item=''''97'''''' comments from PACE_MASTERDBO.PACE_SYSTEM where sys_item=''97'' and sys_value!=10
			 union
			 select ''Eagle Syetem Setting: sys_item=98'' name,''10'' recommended_value, sys_value, ''update PACE_MASTERDBO.PACE_SYSTEM set sys_value=10 where sys_item=''''98'''''' comments from PACE_MASTERDBO.PACE_SYSTEM where sys_item=''98'' and sys_value!=10
			 union
			 select ''Eagle Syetem Setting: sys_item=158'' name,''0'' recommended_value, sys_value, ''update PACE_MASTERDBO.PACE_SYSTEM set sys_value=0 where sys_item=''''158'''''' comments from PACE_MASTERDBO.PACE_SYSTEM where sys_item=''158'' and sys_value!=0
			 union
			 -- Added on 3/21/2019
			 select ''SYS_AUTO_SPM_EVOLVE_TASK'' name, ''FALSE'' recommended_value, parameter_value "Value", ''BEGIN DBMS_SPM.set_evolve_task_parameter(task_name=>''''SYS_AUTO_SPM_EVOLVE_TASK'''',parameter=>''''ACCEPT_PLANS'''',value=>''''FALSE'''');END;'' comments FROM dba_advisor_parameters WHERE task_name = ''SYS_AUTO_SPM_EVOLVE_TASK'' AND parameter_value != ''FALSE'' and parameter_name=''ACCEPT_PLANS''
			 union
			 -- Added on 3/21/2019
			 select ''AUTO_STAT_EXTENSIONS'' name, ''OFF'' recommended_value,  DBMS_STATS.get_prefs(''AUTO_STAT_EXTENSIONS'') "Value", ''BEGIN DBMS_STATS.set_global_prefs (pname => ''''AUTO_STAT_EXTENSIONS'''', pvalue => ''''OFF'''');END;'' comments FROM dual where DBMS_STATS.get_prefs(''AUTO_STAT_EXTENSIONS'')!=''OFF''
			 union
			 select ''GLOBAL_TEMP_TABLE_STATS'' name, ''SHARED'' recommended_value,  DBMS_STATS.get_prefs(''GLOBAL_TEMP_TABLE_STATS'') "Value", ''BEGIN DBMS_STATS.set_global_prefs (pname => ''''GLOBAL_TEMP_TABLE_STATS'''', pvalue => ''''SHARED'''');END;'' comments FROM dual where DBMS_STATS.get_prefs(''GLOBAL_TEMP_TABLE_STATS'')!=''SHARED''
			 union
			 select ''Session: _unnest_subquery'' name,''FALSE'' recommended_value, ''Not set'' value, '' At session level _unnest_subquery should be set to FALSE in EAGLEMGR.STARTUP_PARAMETERS table'' comments from dual where not exists (select * from eaglemgr.STARTUP_PARAMETERS where lower(value) like ''%_unnest_subquery%false'' and owner=''ESTAR'' and ON_OFF=1))
			 LOOP
				DBMS_OUTPUT.PUT_LINE(rpad(i.name,35)||lpad(i.recommended_value,20)||lpad(i.value,25)||''  ''||rpad(i.comments,300));
			 END LOOP;
			 
			 -- Added on 2/22/2022 for 19c and 12c
			 DBMS_OUTPUT.PUT_LINE('' '');
			for r in (select ''Table Stats'' name, ''NULL'' recommended_value, s.num_rows value, ''  ''||s.owner||''.''||s.table_name||'' -- BEGIN DBMS_STATS.UNLOCK_TABLE_STATS(OWNNAME=>''''''||s.owner||'''''',TABNAME=>''''''||s.table_name||'''''');DBMS_STATS.DELETE_TABLE_STATS(OWNNAME=>''''''||s.owner||'''''',TABNAME=>''''''||s.table_name||'''''');DBMS_STATS.LOCK_TABLE_STATS(OWNNAME=>''''''||s.owner||'''''',TABNAME=>''''''||s.table_name||'''''');END;'' comments from dba_tab_statistics s, dba_tables t
			 where (s.owner in (select username from dba_users where username in (''TRADESDBO'',''EAGLEMGR'',''SECURITYDBO'',''EAGLEKB'',
			''RULESDBO'',''CTRLCTR'',''DATAEXCHDBO'',''HOLDINGDBO'',''PACE_MASTERDBO'',''CASHDBO'',''MSGCENTER_DBO'',''ESTAR'',''PERFORMDBO'',
			''LEDGERDBO'',''SCRUBDBO'',''ISTAR'',''ARCH_CTRLCTR'',''EAGLE_TEMP'',''ETK_USER'',''PROD_PARALLELDBO'',''EDMDBO'') 
			OR s.owner in (SELECT CURRENT_PHYSICAL_PARTITION
			FROM estar.star_partition
			WHERE LOGICAL_PARTITION_ID != 1)
			OR s.owner in (select username from dba_users where username like ''%MART%'')))
			and s.num_rows is not NULL 
			and s.owner=t.owner 
			and s.table_name=t.table_name 
			and (t.table_name=''VALUES_SET'' or t.temporary=''Y''))
			LOOP
				DBMS_OUTPUT.PUT_LINE(rpad(r.name,35)||lpad(r.recommended_value,20)||lpad(r.value,25)||rpad(r.comments,350));
			END LOOP;

			 END;';
			 execute immediate l_sql ;
			 RETURN NULL;

		END;

		BEGIN     
			 select version into l_version from v$instance;
			 select to_number(substr(replace(sysdate,'-',''),5,4)) into l_currentdate from dual;
			 -- the latest patch -1
			 if ( l_currentdate >= 117 and l_currentdate < 417 ) then
				l_patchid := substr(add_months(sysdate,-12),3,2)||'101x';
			 elsif ( l_currentdate >= 417 and l_currentdate < 717 ) then
				l_patchid := substr(sysdate,3,2)||'011x';
			 elsif ( l_currentdate >= 717 and l_currentdate < 1017 ) then
				l_patchid := substr(sysdate,3,2)||'041x';
			 elsif ( l_currentdate >= 1017 ) then
				l_patchid := substr(sysdate,3,2)||'071x';
			 elsif ( l_currentdate < 117 ) then
				l_patchid := substr(add_months( trunc(sysdate), -12 ),3,2)||'071x';
			 end if;

			 if ( substr(l_version,1,3) = '19.' ) then
				l_patch_str :='select ''DBRU Patch Applied ''||substr(description,36,6) from DBA_REGISTRY_SQLPATCH where rowid=(select max(rowid) from DBA_REGISTRY_SQLPATCH
		where patch_type=''RU'' and status=''SUCCESS'') and (substr(description,36,5) <'''||substr(l_patchid,1,5)||''' and description is not null) or description is null';
			 elsif ( substr(l_version,1,4) = '12.1' ) then
				l_patch_str :='select ''DBBP Patch Applied ''||bundle_id from DBA_REGISTRY_SQLPATCH where rowid=(select max(rowid) from DBA_REGISTRY_SQLPATCH
		where action=''APPLY'' and bundle_series =''DBBP'') and ((substr(bundle_id,1,5) <'''||substr(l_patchid,1,5)||''' and bundle_id is not null) or bundle_id is null)';
			 elsif ( substr(l_version,1,4) = '12.2' ) then
				l_patch_str :='select ''DBRU Patch Applied ''||bundle_id from DBA_REGISTRY_SQLPATCH where rowid=(select max(rowid) from DBA_REGISTRY_SQLPATCH
		where action=''APPLY'' and bundle_series =''DBRU'') and ((substr(bundle_id,1,5) <'''||substr(l_patchid,1,5)||''' and bundle_id is not null) or bundle_id is null)';
			 else
				l_patch_str :='select ''PSU Patch Applied '' ||id from sys.registry$history where rowid=(select max(rowid) from sys.registry$history
		where action=''APPLY'' and bundle_series =''PSU'') and ((substr(id,1,5)<'''||substr(l_patchid,1,5)||''' and id is not null) or id is null)';
			 end if;
			 begin
				execute immediate l_patch_str into l_str;
				exception
				--when NO_DATA_FOUND then l_str :='No DB Patch Applied!';
				when NO_DATA_FOUND then l_str := NULL;
			 end;

			 -- check if it is multi tenant env
			 select count(*) into l_cnt from dba_objects where object_name='DBA_PDBS' and OBJECT_TYPE='VIEW';
			 if ( l_cnt > 0 ) then
				select decode(sys_context('USERENV', 'CON_NAME'),'CDB$ROOT',sys_context('USERENV', 'DB_NAME'),sys_context('USERENV', 'CON_NAME')) DB_NAME,
				  decode(sys_context('USERENV','CON_ID'),1,'CDB','PDB') TYPE into l_name, l_type from DUAL;
				if ( l_type = 'CDB' ) then
				   DBMS_OUTPUT.PUT_LINE(chr(10)||'Database '||l_name||' is a container database. Please run this SQL at its plugable database. Exiting...');
				   return;
				else          
				   begin
					  select pdb_name,dbid into l_name,l_dbid from dba_pdbs ;             
					  EXCEPTION
					  WHEN NO_DATA_FOUND then
					  select name,dbid into l_name,l_dbid from v$database;                 
				   end;
				   l_report:=GENERATE_REPORT(l_name,l_dbid, l_version,l_str,l_patchid, l_type);
				   DBMS_OUTPUT.PUT_LINE(l_report);
				end if;  
			 else
				select name,dbid into l_name,l_dbid from v$database;   
				l_report:=GENERATE_REPORT(l_name,l_dbid, l_version,l_str,l_patchid, l_type);
				DBMS_OUTPUT.PUT_LINE(l_report);
			 end if;       
		END;
		/

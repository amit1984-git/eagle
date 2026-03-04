create or replace PACKAGE BODY          eagle_util
IS
  l_current_count PLS_INTEGER;
  l_last_week PLS_INTEGER := 0;
  last_sql_id v$sql.sql_id%TYPE;
  last_table_name sys.dba_tables.TABLE_NAME%TYPE;
  i_end pls_integer  := 0;
  i pls_integer      := 0;
  i_deep pls_integer := 0;
  l_program_id v$sql.program_id%TYPE;
  l_program_line# v$sql.program_line#%TYPE;
  l_byte_to_meg_conv NUMBER := 1048576;
type sql_info_type
IS
  TABLE OF VARCHAR2(4000) INDEX BY binary_integer;
  sql_info_table sql_info_type;
  l_number_mask     VARCHAR2(24) := '9,999,999,999';
  l_number_mask_d3  VARCHAR2(24) := '9,999,999.999';
  l_date_mask       VARCHAR2(24) := 'MM/DD/YYYY HH24:MI:SS';
  l_time_mask       VARCHAR2(24) := 'HH24:MI:SS';
  l_date_mask_short VARCHAR2(24) := 'MM/DD/YYYY HH24:MI';
  l_time_mask_short VARCHAR2(24) := 'HH24:MI';
  CURSOR sql_text_cur(owner_p    IN all_source.owner%TYPE, name_p IN all_source.name%TYPE, type_p IN all_source.type%TYPE, line_p IN all_source.type%TYPE)
  IS
    SELECT line,
      SUBSTR(LTRIM(REPLACE(REPLACE(REPLACE(REPLACE(text, '       ', ' '), '  ', ' '), CHR(10), ''), CHR(13), '')), 1, 254) text
    FROM sys.dba_source
    WHERE owner = owner_p
    AND name    = name_p
    AND type    = type_p
    AND line   >= line_p
    ORDER BY line;
  sql_text_rec sql_text_cur % rowtype;
  CURSOR dba_objects_cur(object_id_p IN dba_objects.object_id%TYPE)
  IS
    SELECT object_id,
      owner,
      object_name,
      object_type
    FROM sys.dba_objects
    WHERE object_id = object_id_p;
  dba_objects_rec dba_objects_cur % rowtype;
  CURSOR find_proc_cur(program_line#_p v$sql.program_line#%TYPE)
  IS
    (SELECT program_line#_p program_line#,
      line proc_line,
      SUBSTR(text, 1, instr(text, ' ') -1) sub_type,
      SUBSTR(LTRIM(SUBSTR(text, instr(text, ' '))), 1, instr(LTRIM(SUBSTR(text, instr(text, ' ')))
      || ' ', ' ') -1) sub_name
    FROM
      (SELECT line,
        UPPER(LTRIM(REPLACE(REPLACE(REPLACE(REPLACE(text, CHR(13), ' '), CHR(10), ' '), CHR(9), ' '), '(', ' '))) text
      FROM sys.dba_source
      WHERE owner = dba_objects_rec.owner
      AND name    = dba_objects_rec.object_name
      AND type    = dba_objects_rec.object_type
      AND line    =
        (SELECT MAX(line)
        FROM sys.dba_source
        WHERE owner                          = dba_objects_rec.owner
        AND name                             = dba_objects_rec.object_name
        AND type                             = dba_objects_rec.object_type
        AND line                            <= program_line#_p
        AND(SUBSTR(UPPER(LTRIM(text)), 1, 9) = 'PROCEDURE'
        OR SUBSTR(UPPER(LTRIM(text)), 1, 8)  = 'FUNCTION')
        )
      )
    ) ;
    find_proc_rec find_proc_cur % rowtype;
  PROCEDURE pop_dba_objects_rec(
      in_object_id dba_objects.object_id%TYPE,
      in_program_line# v$sql.program_line#%TYPE)
  IS
  BEGIN
    IF(dba_objects_rec.object_id  IS NULL OR dba_objects_rec.object_id <> in_object_id) THEN
      dba_objects_rec.owner       := '';
      dba_objects_rec.object_name := '';
      dba_objects_rec.object_type := '';
      OPEN dba_objects_cur(in_object_id);
      FETCH dba_objects_cur INTO dba_objects_rec;
      CLOSE dba_objects_cur;
      dba_objects_rec.object_id   := in_object_id;
      find_proc_rec.program_line# := NULL;
      find_proc_rec.sub_type      := '';
      find_proc_rec.sub_name      := '';
    END IF;
    IF(dba_objects_rec.object_type    = 'PACKAGE BODY') THEN
      IF(find_proc_rec.program_line# IS NULL OR find_proc_rec.program_line# <> in_program_line#) THEN
        OPEN find_proc_cur(in_program_line#);
        FETCH find_proc_cur INTO find_proc_rec;
        CLOSE find_proc_cur;
        find_proc_rec.program_line# := in_program_line#;
      END IF;
    ELSE
      find_proc_rec.sub_type := dba_objects_rec.object_type;
      find_proc_rec.sub_name := dba_objects_rec.object_name;
    END IF;
  END;
FUNCTION do_object_summary(
    in_object_id dba_objects.object_id%TYPE,
    in_program_line# v$sql.program_line#%TYPE)
  RETURN VARCHAR2
IS
BEGIN
  pop_dba_objects_rec(in_object_id, in_program_line#);
  IF(dba_objects_rec.object_type = 'PACKAGE BODY') THEN
    RETURN(dba_objects_rec.owner || ' ' || dba_objects_rec.object_name || ' ' || find_proc_rec.sub_type || ' ' || find_proc_rec.sub_name);
  ELSE
    RETURN(dba_objects_rec.owner || ' ' || find_proc_rec.sub_type || ' ' || find_proc_rec.sub_name);
  END IF;
END;
FUNCTION do_object_summary(
    in_sql_id v$sqlarea.sql_id%TYPE)
  RETURN VARCHAR2
IS
  l_object_id dba_objects.object_id%TYPE;
  l_program_line# v$sql.program_line#%TYPE;
BEGIN
  SELECT MIN(program_id),
    MIN(program_line#)
  INTO l_object_id,
    l_program_line#
  FROM v$sqlarea
  WHERE sql_id = in_sql_id;
  pop_dba_objects_rec(l_object_id, l_program_line#);
  IF (dba_objects_rec.object_type IS NULL) THEN
    RETURN(NULL);
  END IF;
  IF(dba_objects_rec.object_type = 'PACKAGE BODY') THEN
    RETURN(dba_objects_rec.owner || ' ' || dba_objects_rec.object_name || ' ' || find_proc_rec.sub_type || ' ' || find_proc_rec.sub_name || ' #' || l_program_line#);
  ELSE
    RETURN(dba_objects_rec.owner || ' ' || find_proc_rec.sub_type || ' ' || find_proc_rec.sub_name || ' #' || l_program_line#);
  END IF;
END;
PROCEDURE add_one(
    in_line VARCHAR2)
IS
BEGIN
  i_end                   := i_end + 1;
  IF(i_end                 = 1) THEN
    sql_info_table(i_end) := ' ';
    i_end                 := i_end + 1;
    sql_info_table(i_end) := 'EAGLE_UTIL Version 4';
    i_end                 := i_end + 1;
    sql_info_table(i_end) := '* AS OF ' || TO_CHAR(sysdate, l_date_mask);
    FOR rec               IN
    (SELECT instance_name FROM v$instance
    )
    LOOP
      i_end                 := i_end + 1;
      sql_info_table(i_end) := 'Instance Name: ' || rec.instance_name;
    END LOOP;
    i_end := i_end + 1;
  END IF;
  sql_info_table(i_end) := RTRIM(in_line);
END;
PROCEDURE add_on(
    in_line VARCHAR2,
    in_size pls_integer)
IS
BEGIN
  sql_info_table(i_end) := sql_info_table(i_end) || SUBSTR(lpad(NVL(in_line, 'NULL'), in_size), 1, in_size);
END;
PROCEDURE add_table_info(
    in_owner sys.dba_tables.owner%TYPE,
    in_table_name sys.dba_tables.TABLE_NAME %TYPE)
IS
BEGIN
  FOR rec_tab IN
  (SELECT DISTINCT owner,
    TABLE_NAME,
    TO_CHAR(num_rows, l_number_mask) num_rows,
    TO_CHAR(last_analyzed, l_date_mask) last_analyzed,
    TEMPORARY
  FROM sys.dba_tables
  WHERE owner    = in_owner
  AND TABLE_NAME = in_table_name
  )
  LOOP
    add_one('');
    add_one(rpad(rec_tab.owner || '.' || rec_tab.TABLE_NAME, 45));
    add_one('Last Analyzed: ' || NVL(rec_tab.last_analyzed, 'NULL'));
    add_one('Num Rows:      ' || LTRIM(NVL(rec_tab.num_rows, 'NULL')));
    IF(rec_tab.TEMPORARY = 'Y') THEN
      add_one('TEMPORARY TABLE');
    END IF;
    FOR rec_mod IN
    (SELECT inserts,
      updates,
      deletes,
      TIMESTAMP
    FROM sys.dba_tab_modifications
    WHERE table_owner = rec_tab.owner
    AND TABLE_NAME    = rec_tab.TABLE_NAME
    ORDER BY TIMESTAMP
    )
    LOOP
      add_one('Modifications (' || TO_CHAR(rec_mod.TIMESTAMP, l_date_mask) || ') - Inserts: ' || TO_CHAR(rec_mod.inserts, l_number_mask) || '  Updates: ' || TO_CHAR(rec_mod.updates, l_number_mask) || '  Deletes: ' || TO_CHAR(rec_mod.deletes, l_number_mask));
    END LOOP;
    add_one('');
    FOR rec_ind IN
    (SELECT owner,
      index_name,
      TO_CHAR(num_rows, l_number_mask) num_rows,
      TO_CHAR(last_analyzed, l_date_mask) last_analyzed,
      DECODE(uniqueness, 'UNIQUE', 'UNIQ', ' ') uniq
    FROM sys.dba_indexes
    WHERE owner    = rec_tab.owner
    AND TABLE_NAME = rec_tab.TABLE_NAME
    )
    LOOP
      add_one(rec_ind.num_rows || ' ' || rpad(rec_ind.index_name, 30) || ' ' || rpad(rec_ind.uniq, 4) || ' : ' || index_columns(rec_ind.owner, rec_ind.index_name));
    END LOOP;
  END LOOP;
END;
PROCEDURE add_view_info(
    in_preface VARCHAR2,
    in_owner sys.dba_objects.owner%TYPE,
    in_object_name sys.dba_objects.object_name%TYPE)
IS
BEGIN
  i_deep := i_deep + 1;
  add_one('');
  add_one(in_preface || in_owner || '.' || in_object_name);
  FOR rec_tab IN
  (SELECT owner,
    object_name
  FROM dba_objects
  WHERE object_id IN
    (SELECT referenced_object_id
    FROM public_dependency
    WHERE object_id IN
      (SELECT object_id
      FROM dba_objects
      WHERE owner     = in_owner
      AND object_name = in_object_name
      )
    )
  AND object_type = 'TABLE'
  )
  LOOP
    add_one('');
    add_one(in_owner || '.' || in_object_name || ' Refers To Table: ' || rec_tab.owner || '.' || rec_tab.object_name);
    add_table_info(rec_tab.owner, rec_tab.object_name);
  END LOOP;
  IF(i_deep       < 10) THEN
    FOR rec_view IN
    (SELECT owner,
      object_name
    FROM dba_objects
    WHERE object_id IN
      (SELECT referenced_object_id
      FROM public_dependency
      WHERE object_id IN
        (SELECT object_id
        FROM dba_objects
        WHERE owner     = in_owner
        AND object_name = in_object_name
        )
      )
    AND object_type = 'VIEW'
    )
    LOOP
      add_view_info(in_owner || '.' || in_object_name || ' Refers To View: ', rec_view.owner, rec_view.object_name);
    END LOOP;
  END IF;
  i_deep := i_deep -1;
END;
PROCEDURE add_plan(
    in_sql_id v$sql.sql_id%TYPE,
    in_child_number v$sql.child_number%TYPE)
IS
  l_plan_table sql_info_type;
BEGIN
  FOR rec IN
  (SELECT cpu_cost,
    io_cost,
    id
  FROM v$sql_plan
  WHERE sql_id     = in_sql_id
  AND child_number = in_child_number
  AND id           =
    (SELECT MIN(id)
    FROM v$sql_plan
    WHERE sql_id     = in_sql_id
    AND child_number = in_child_number
    AND cpu_cost    IS NOT NULL
    )
  )
  LOOP
    add_one('');
    add_one('(ID=' || TO_CHAR(rec.id) || ')   CPU_COST: ' || TO_CHAR(rec.cpu_cost, l_number_mask) || '    IO_COST: ' || TO_CHAR(rec.io_cost, l_number_mask));
  END LOOP;
  add_one('');
  SELECT *bulk collect
  INTO l_plan_table
  FROM TABLE(dbms_xplan.display_cursor(in_sql_id, in_child_number));
  i      := 1;
  WHILE(i < l_plan_table.COUNT AND instr(l_plan_table(i), 'Plan hash') < 1)
  LOOP
    i := i + 1;
  END LOOP;
  FOR indx IN i .. l_plan_table.COUNT
  LOOP
    add_one(l_plan_table(indx));
  END LOOP;
END;
PROCEDURE awr_history(
    in_sql_id    VARCHAR2,
    display_type VARCHAR2)
IS
BEGIN
  l_current_count := 20;
  add_one('');
  IF (display_type = 'RUN1') THEN
    add_one('--------- AWR History --------');
  ELSE
    add_one('--------- AWR History Per Execution --------');
  END IF;
  FOR rec_awr IN
  (SELECT sn.begin_interval_time awr_begin,
    sn.end_interval_time awr_end,
    sq.executions_delta executions,
    ROUND(sq.cpu_time_delta     / 1000000) cpu_time,
    ROUND(sq.elapsed_time_delta / 1000000) elapsed_time,
    sq.buffer_gets_delta buffer_gets,
    sq.disk_reads_delta disk_reads,
    sq.rows_processed_delta rows_processed,
    DECODE(NVL(sq.executions_delta, 0), 0, 1, sq.executions_delta) executions_1,
    sq.plan_hash_value
  FROM sys.DBA_HIST_SQLSTAT sq,
    sys.dba_hist_snapshot sn
  WHERE sq.sql_id           = in_sql_id
  AND sn.snap_id            = sq.snap_id
  AND sq.elapsed_time_delta > 0
  ORDER BY sn.begin_interval_time
  )
  LOOP
    l_current_count   := l_current_count + 1;
    IF(l_current_count > 20) THEN
      l_current_count := 1;
      add_one('');
      add_one(lpad('Beginning', 17));
      add_on('Ending', 7);
      add_on('Executions', 15);
      add_on('Elpsd (sec)', 15);
      add_on('CPU (sec)', 15);
      add_on('Buffer Gets', 15);
      add_on('Disk Reads', 15);
      add_on('Rows Processed', 15);
      add_on('Plan Value', 15);
    END IF;
    IF (display_type = 'RUN1') THEN
      add_one(lpad(TO_CHAR(rec_awr.awr_begin, l_date_mask_short), 17));
      add_on(TO_CHAR(rec_awr.awr_end, l_time_mask_short), 7);
      add_on(TO_CHAR(rec_awr.executions, l_number_mask), 15);
      add_on(TO_CHAR(rec_awr.elapsed_time, l_number_mask), 15);
      add_on(TO_CHAR(rec_awr.cpu_time, l_number_mask), 15);
      add_on(TO_CHAR(rec_awr.buffer_gets, l_number_mask), 15);
      add_on(TO_CHAR(rec_awr.disk_reads, l_number_mask), 15);
      add_on(TO_CHAR(rec_awr.rows_processed, l_number_mask), 15);
      add_on(TO_CHAR(rec_awr.plan_hash_value), 15);
    ELSE
      add_one(lpad(TO_CHAR(rec_awr.awr_begin, l_date_mask_short), 17));
      add_on(TO_CHAR(rec_awr.awr_end, l_time_mask_short), 7);
      add_on(TO_CHAR(rec_awr.executions, l_number_mask), 15);
      add_on(TO_CHAR(rec_awr.elapsed_time  /rec_awr.executions_1, l_number_mask_d3), 15);
      add_on(TO_CHAR(rec_awr.cpu_time      /rec_awr.executions_1, l_number_mask_d3), 15);
      add_on(TO_CHAR(rec_awr.buffer_gets   /rec_awr.executions_1, l_number_mask), 15);
      add_on(TO_CHAR(rec_awr.disk_reads    /rec_awr.executions_1, l_number_mask), 15);
      add_on(TO_CHAR(rec_awr.rows_processed/rec_awr.executions_1, l_number_mask), 15);
      add_on(TO_CHAR(rec_awr.plan_hash_value), 15);
    END IF;
  END LOOP;
END;
PROCEDURE add_plan_awr(
    in_sql_id v$sql.sql_id%TYPE,
    in_plan_hash_value v$sql.plan_hash_value%type)
IS
  l_plan_table sql_info_type;
BEGIN
  add_one(' ');
  add_one('(AWR Plan)');
  add_one(' ');
  i := 1;
  SELECT *bulk collect
  INTO l_plan_table
  FROM TABLE(dbms_xplan.display_awr(in_sql_id, in_plan_hash_value));
  IF (in_plan_hash_value IS NOT NULL) THEN
    WHILE(i               < l_plan_table.COUNT AND instr(l_plan_table(i), 'Plan hash') < 1)
    LOOP
      i := i + 1;
    END LOOP;
  END IF;
  FOR indx IN i .. l_plan_table.COUNT
  LOOP
    add_one(l_plan_table(indx));
  END LOOP;
END;
FUNCTION sql_id_info_line(
    in_line pls_integer)
  RETURN VARCHAR2
IS
BEGIN
  RETURN(info_line(in_line));
END;
FUNCTION info_line(
    in_line pls_integer)
  RETURN VARCHAR2
IS
BEGIN
  IF(in_line <= i_end) THEN
    RETURN(sql_info_table(in_line));
  END IF;
  last_sql_id := NULL;
  i_end       := 0;
  RETURN(' ');
END;
FUNCTION table_info(
    in_table_name sys.dba_tables.TABLE_NAME%TYPE)
  RETURN NUMBER
IS
BEGIN
  IF(last_table_name IS NULL OR last_table_name <> in_table_name) THEN
    last_table_name  := in_table_name;
    FOR rec          IN
    (SELECT owner,
      table_name
    FROM sys.dba_tables
    WHERE table_name = upper(in_table_name)
    )
    LOOP
      add_table_info(rec.owner, rec.table_name);
    END LOOP;
  END IF;
  RETURN(i_end + 1);
END;
FUNCTION sql_id_info(
    in_sql_id v$sql.sql_id%TYPE)
  RETURN NUMBER
IS
  i_cnt pls_integer := 0;
  i_found BOOLEAN   := FALSE;
  l_child_number v$sql.child_number%TYPE;
BEGIN
  IF(last_sql_id IS NULL OR last_sql_id <> in_sql_id) THEN
    last_sql_id  := in_sql_id;
    FOR rec      IN
    (WITH summary_t AS
    (SELECT sql_id,
      COUNT(*) child_count,
      MAX(child_number) child_number,
      MAX(program_id) program_id,
      MAX(program_line#) program_line#,
      SUM(fetches) fetches,
      SUM(executions) executions,
      SUM(cpu_time)              / 1000000 cpu_time,
      SUM(elapsed_time)          / 1000000 elapsed_time,
      SUM(CONCURRENCY_WAIT_TIME) / 1000000 CONCURRENCY_WAIT_TIME,
      SUM(USER_IO_WAIT_TIME)     / 1000000 USER_IO_WAIT_TIME,
      SUM(buffer_gets) buffer_gets,
      SUM(rows_processed) rows_processed,
      DECODE(SUM(executions), 0, 1, SUM(executions)) ok_executions,
      rpad(sql_text, 4000, ' ') sql_text,
      MAX(last_active_time) last_active_time,
      ROUND(SUM(sharable_mem)   / l_byte_to_meg_conv, 4) sharable_mem,
      ROUND(SUM(persistent_mem) / l_byte_to_meg_conv, 4) persistent_mem,
      ROUND(SUM(runtime_mem)    / l_byte_to_meg_conv, 4) runtime_mem
    FROM v$sql
    WHERE sql_id = in_sql_id
    GROUP BY sql_id,
      rpad(sql_text, 4000, ' ')
    )
  SELECT s.sql_id,
    s.child_count,
    s.fetches,
    s.executions,
    s.program_id,
    s.program_line#,
    ROUND(s.cpu_time, 2) cpu_time,
    ROUND(s.elapsed_time, 2) elapsed_time,
    ROUND(s.CONCURRENCY_WAIT_TIME, 2) CONCURRENCY_WAIT_TIME,
    ROUND(s.USER_IO_WAIT_TIME, 2) USER_IO_WAIT_TIME,
    s.buffer_gets,
    s.rows_processed,
    ROUND(s.cpu_time       / s.ok_executions, 4) cpu_x,
    ROUND(s.elapsed_time   / s.ok_executions, 4) elp_x,
    ROUND(s.buffer_gets    / s.ok_executions, 0) buf_x,
    ROUND(s.rows_processed / s.ok_executions, 4) rows_x,
    sharable_mem,
    persistent_mem,
    runtime_mem,
    TO_CHAR(s.last_active_time, l_date_mask) last_active_time,
    s.child_number,
    do.owner,
    do.object_name,
    do.object_type,
    sql_text
  FROM summary_t s,
    sys.dba_objects DO
  WHERE do.object_id(+) = s.program_id
    )
    LOOP
      i_found := TRUE;
      add_one('');
      add_one('>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>> SQL_ID: ' || rec.sql_id);
      add_one('');
      FOR rec_ses IN
      (SELECT sid,
        SUBSTR(client_info, 1, instr(client_info, ',') -1) event,
        SUBSTR(client_info, instr(client_info, ',')    + 1) event_id
      FROM v$session
      WHERE sql_id = in_sql_id
      )
      LOOP
        add_one('Current SQL SID (' || rec_ses.sid || ') Client Info Event / Event ID: ' || rec_ses.event || ' / ' || rec_ses.event_id);
      END LOOP;
      FOR rec_ses IN
      (SELECT sid,
        SUBSTR(client_info, 1, instr(client_info, ',') -1) event,
        SUBSTR(client_info, instr(client_info, ',')    + 1) event_id
      FROM v$session
      WHERE prev_sql_id = in_sql_id
      AND NVL(sql_id, in_sql_id
        || 'xxx') <> in_sql_id
      )
      LOOP
        add_one('Previous SQL SID (' || rec_ses.sid || ') Client Info Event / Event ID: ' || rec_ses.event || ' / ' || rec_ses.event_id);
      END LOOP;
      add_one('');
      add_one('SQL_TEXT:');
      add_one('');
      FOR rec IN
      (SELECT sql_fulltext,
        TO_CHAR(dbms_lob.substr(sql_fulltext, 4000, 1)) sql_text,
        dbms_lob.getlength(sql_fulltext) text_len,
        0 char_last,
        0 char_at,
        140 max_char
      FROM v$sqlarea
      WHERE sql_id = in_sql_id
      )
      LOOP
        WHILE rec.char_last < rec.text_len
        LOOP
          IF (rec.char_last + rec.max_char >= rec.text_len) THEN
            rec.char_at                    := rec.max_char;
          ELSE
            rec.sql_text := dbms_lob.substr(rec.sql_fulltext, rec.max_char, rec.char_last + 1);
            SELECT DECODE(MAX(bval), 0, rec.max_char, MAX(bval))
            INTO rec.char_at
            FROM
              (SELECT INSTR(rec.sql_text, ' ', -1, 1) bval FROM dual
              UNION ALL
              SELECT INSTR(rec.sql_text, ',', -1, 1) bval FROM dual
              );
          END IF;
          rec.sql_text  := dbms_lob.substr(rec.sql_fulltext, rec.char_at, rec.char_last + 1);
          rec.char_last := rec.char_last                                                + rec.char_at;
          add_one(rec.sql_text);
        END LOOP;
      END LOOP;
      add_one('');
      add_one('Number Of Children: ' || rec.child_count);
      IF(rec.child_count > 1) THEN
        add_one('');
        add_one('--- SUMMARY ---- ');
      END IF;
      add_one('');
      add_one('Last Active: ' || rec.last_active_time);
      add_one('');
      add_one(lpad('Executions: ', 20) || TO_CHAR(rec.executions, l_number_mask));
      add_one(lpad('Elapsed (sec): ', 20) || TO_CHAR(rec.elapsed_time, l_number_mask));
      add_one(lpad('CPU (sec): ', 20) || TO_CHAR(rec.cpu_time, l_number_mask));
      add_one(lpad('USER IO Wait (sec): ', 20) || TO_CHAR(rec.USER_IO_WAIT_TIME, l_number_mask));
      add_one(lpad('CNCURCY Wait (sec): ', 20) || TO_CHAR(rec.CONCURRENCY_WAIT_TIME, l_number_mask));
      add_one(lpad('Buffer Gets: ', 20) || TO_CHAR(rec.buffer_gets, l_number_mask));
      add_one(lpad('Rows Processed: ', 20) || TO_CHAR(rec.rows_processed, l_number_mask));
      add_one('');
      add_one(lpad('Elapsed Per Execution (sec): ', 32) || rec.elp_x);
      add_one(lpad('CPU Per Execution (sec): ', 32) || rec.cpu_x);
      add_one(lpad('Buffer Gets Per Execution: ', 32) || rec.buf_x);
      add_one(lpad('Rows Processed Per Execution: ', 32) || rec.rows_x);
      add_one('');
      add_one(lpad('Sharable Memory (Mega Bytes): ', 32) || rec.sharable_mem);
      add_one(lpad('Persistent Memory (Mega Bytes): ', 32) || rec.persistent_mem);
      add_one(lpad('Run Time Memory (Mega Bytes): ', 32) || rec.runtime_mem);
      add_one('');
      add_one(do_object_summary(rec.program_id, rec.program_line#) || ' - ' || NVL(TO_CHAR(rec.program_line#), ' '));
      add_one('');
      IF(rec.owner IS NOT NULL) THEN
        OPEN sql_text_cur(rec.owner, rec.object_name, rec.object_type, rec.program_line#);
        FETCH sql_text_cur INTO sql_text_rec;
        i_cnt      := 0;
        WHILE(i_cnt < 100 AND sql_text_cur % FOUND)
        LOOP
          IF(TRIM(LENGTH(sql_text_rec.text))    > 0) THEN
            IF(instr(sql_text_rec.text, 'LOOP') > 1) THEN
              i_cnt                            := 100;
            ELSE
              add_one('(' || TO_CHAR(sql_text_rec.line) || ') ' || sql_text_rec.text);
            END IF;
            IF(instr(sql_text_rec.text, ';') > 1) THEN
              i_cnt                         := 100;
            END IF;
          END IF;
          FETCH sql_text_cur
          INTO sql_text_rec;
          i_cnt := i_cnt + 1;
        END LOOP;
        CLOSE sql_text_cur;
      END IF;
      add_one('');
      IF(rec.child_count > 1) THEN
        FOR rec_child   IN
        (SELECT s.sql_id,
          s.plan_hash_value,
          COUNT(*) child_count,
          MAX(s.child_number) child_number,
          SUM(s.fetches) fetches,
          SUM(s.executions) executions,
          ROUND((SUM(s.cpu_time)     / 1000000), 2) cpu_time,
          ROUND((SUM(s.elapsed_time) / 1000000), 2) elapsed_time,
          SUM(s.buffer_gets) buffer_gets,
          SUM(s.rows_processed) rows_processed,
          ROUND((SUM(s.cpu_time)      / 1000000) / DECODE(SUM(s.executions), 0, 1, SUM(s.executions)), 4) cpu_x,
          ROUND((SUM(s.elapsed_time)  / 1000000) / DECODE(SUM(s.executions), 0, 1, SUM(s.executions)), 4) elp_x,
          ROUND(SUM(s.buffer_gets)    / DECODE(SUM(s.executions), 0, 1, SUM(s.executions)), 0) buf_x,
          ROUND(SUM(s.rows_processed) / DECODE(SUM(s.executions), 0, 1, SUM(s.executions)), 4) rows_x,
          TO_CHAR(MAX(s.last_active_time), l_date_mask) last_active_time
        FROM v$sql s
        WHERE sql_id = in_sql_id
        GROUP BY sql_id,
          plan_hash_value
        ORDER BY plan_hash_value
        )
        LOOP
          add_one('');
          IF(rec_child.child_count > 1) THEN
            add_one('Number Of Children For This Plan: ' || TO_CHAR(rec_child.child_count));
            add_one('Max Child Number: ' || TO_CHAR(rec_child.child_number));
          ELSE
            add_one('Child Number: ' || TO_CHAR(rec_child.child_number));
          END IF;
          add_one('');
          add_one('Last Active: ' || rec_child.last_active_time);
          add_one('');
          add_one(lpad('Executions: ', 20) || TO_CHAR(rec_child.executions, l_number_mask));
          add_one(lpad('Elapsed (sec): ', 20) || TO_CHAR(rec_child.elapsed_time, l_number_mask));
          add_one(lpad('CPU (sec): ', 20) || TO_CHAR(rec_child.cpu_time, l_number_mask));
          add_one(lpad('Buffer Gets: ', 20) || TO_CHAR(rec_child.buffer_gets, l_number_mask));
          add_one(lpad('Rows Processed: ', 20) || TO_CHAR(rec_child.rows_processed, l_number_mask));
          IF(rec_child.executions > 0) THEN
            add_one('');
            add_one(lpad('Elapsed Per Execution (sec): ', 32) || rec_child.elp_x);
            add_one(lpad('CPU Per Execution (sec): ', 32) || rec_child.cpu_x);
            add_one(lpad('Buffer Gets Per Execution: ', 32) || rec_child.buf_x);
            add_one(lpad('Rows Processed Per Execution: ', 32) || rec_child.rows_x);
          END IF;
          IF (rec.child_count < 20) THEN
            FOR rec_plan     IN
            (SELECT MAX(child_number) child_number
            FROM v$sql_plan
            WHERE sql_id     = in_sql_id
            AND child_number = rec_child.child_number
            HAVING COUNT(*)  > 0
            )
            LOOP
              add_plan(in_sql_id, rec_plan.child_number);
            END LOOP;
            l_child_number := -1;
            FOR v            IN
            (SELECT           *
            FROM
              (SELECT sql_id,
                child_number,
                executions,
                last_active_time,
                hash_value,
                child_address
              FROM v$sql
              WHERE sql_id        = in_sql_id
              AND plan_hash_value = rec_child.plan_hash_value
              ORDER BY sql_id,
                child_number
              )
            WHERE rownum < 21
            )
            LOOP
              FOR rec_bind IN
              (SELECT DISTINCT vc.sql_id,
                vc.child_number,
                vc.name,
                vc.value_string,
                vc.POSITION,
                TO_CHAR(v.last_active_time, l_date_mask) last_active_time,
                v.executions,
                datatype_string
              FROM v$sql_bind_capture vc
              WHERE vc.sql_id      = v.sql_id
              AND vc.child_number  = v.child_number
              AND vc.hash_value    = v.hash_value
              AND vc.child_address = v.child_address
              AND vc.was_captured  = 'YES'
              ORDER BY vc.child_number,
                vc.POSITION
              )
              LOOP
                IF(l_child_number <> rec_bind.child_number) THEN
                  add_one('');
                  add_one('Binds For Child Number: ' || TO_CHAR(rec_bind.child_number) || '   Last Active: ' || rec_bind.last_active_time || '   Executions: ' || rec_bind.executions);
                  add_one('');
                  l_child_number := rec_bind.child_number;
                END IF;
                add_one(TO_CHAR(rec_bind.name) || ' (' || rec_bind.datatype_string || ') : ' || rec_bind.value_string);
              END LOOP;
            END LOOP;
          END IF;
        END LOOP;
      ELSE
        add_plan(in_sql_id, rec.child_number);
      END IF;
      FOR rec_plan IN
      (SELECT DISTINCT plan_hash_value
      FROM sys.DBA_HIST_SQLSTAT
      WHERE sql_id = in_sql_id
      MINUS
      SELECT DISTINCT plan_hash_value FROM v$sql WHERE sql_id = in_sql_id
      )
      LOOP
        add_plan_awr(in_sql_id, rec_plan.plan_hash_value);
      END LOOP;
    END LOOP;
    SELECT COUNT(*)
    INTO i_cnt
    FROM sys.DBA_HIST_sqlstat
    WHERE sql_id = in_sql_id;
    IF(i_cnt     > 0) THEN
      IF(NOT i_found) THEN
        add_one('');
        add_one('>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>> SQL_ID: ' || in_sql_id);
        add_plan_awr(in_sql_id, NULL);
        i_found := TRUE;
      END IF;
    END IF;
    IF(i_found) THEN
      add_one('');
      add_one('--------- Indexes --------');
      add_one('');
      FOR rec_tab IN
      (WITH plan_objects AS
      (SELECT DISTINCT object_owner,
        object_name
      FROM v$sql_plan
      WHERE(address, hash_value, child_number) IN
        (SELECT address,
          hash_value,
          child_number
        FROM v$sql_plan
        WHERE sql_id = in_sql_id
        AND rownum   < 2
        )
      AND object_name IS NOT NULL
      UNION
      SELECT DISTINCT object_owner,
        object_name
      FROM sys.DBA_HIST_sql_plan
      WHERE sql_id     = in_sql_id
      AND object_name IS NOT NULL
      )
      (SELECT owner,
        TABLE_NAME
      FROM sys.dba_tables
      WHERE(owner, TABLE_NAME) IN
        (SELECT object_owner,
          object_name
        FROM
          (SELECT object_owner, object_name FROM plan_objects
          UNION
          SELECT table_owner,
            TABLE_NAME
          FROM sys.dba_indexes
          WHERE(owner, index_name) IN
            (SELECT object_owner, object_name FROM plan_objects
            )
          )
        )
      )
      )
      LOOP
        add_table_info(rec_tab.owner, rec_tab.TABLE_NAME);
      END LOOP;
      FOR rec_view IN
      (WITH plan_objects AS
      (SELECT DISTINCT object_owner,
        object_name
      FROM v$sql_plan
      WHERE(address, hash_value, child_number) IN
        (SELECT address,
          hash_value,
          child_number
        FROM v$sql_plan
        WHERE sql_id = in_sql_id
        AND rownum   < 2
        )
      AND object_name IS NOT NULL
      UNION
      SELECT DISTINCT object_owner,
        object_name
      FROM sys.DBA_HIST_sql_plan
      WHERE sql_id     = in_sql_id
      AND object_name IS NOT NULL
      )
    SELECT owner,
      object_name
    FROM sys.dba_objects
    WHERE(owner, object_name) IN
      (SELECT object_owner, object_name FROM plan_objects
      )
    AND object_type = 'VIEW'
      )
      LOOP
        add_view_info('View: ', rec_view.owner, rec_view.object_name);
      END LOOP;
    END IF;
    IF(i_cnt > 0) THEN
      awr_history(in_sql_id, 'RUN1');
      awr_history(in_sql_id, 'RUN2');
      i_found := TRUE;
    END IF;
    IF(NOT i_found) THEN
      add_one('');
      add_one('SQL_ID ' || in_sql_id || ' Not Found In V$SQL');
    END IF;
  END IF;
  RETURN(i_end + 1);
END;
FUNCTION week_count(
    i_week PLS_INTEGER)
  RETURN PLS_INTEGER
IS
BEGIN
  IF(l_last_week     = i_week) THEN
    l_current_count := l_current_count + 1;
  ELSE
    l_current_count := 1;
    l_last_week     := i_week;
  END IF;
  RETURN(l_current_count);
END;
FUNCTION index_columns(
    i_index_owner dba_ind_columns.index_owner%TYPE,
    i_index_name dba_ind_columns.index_name%TYPE)
  RETURN VARCHAR2
IS
  l_index VARCHAR2(3000);
BEGIN
  FOR rec IN
  (SELECT column_name
  FROM sys.dba_ind_columns
  WHERE index_owner = i_index_owner
  AND index_name    = i_index_name
  ORDER BY column_position
  )
  LOOP
    IF(SUBSTR(rec.column_name, 1, 4) = 'SYS_') THEN
      FOR rec_func                  IN
      (SELECT data_default
      FROM sys.dba_tab_cols
      WHERE column_name = rec.column_name
      AND owner         = i_index_owner
      )
      LOOP
        rec.column_name := rec_func.data_default;
      END LOOP;
    END IF;
    IF(l_index IS NULL) THEN
      l_index  := rec.column_name;
    ELSE
      l_index := l_index || ', ' || rec.column_name;
    END IF;
  END LOOP;
  RETURN(l_index);
END;
FUNCTION remove_constants(
    p_query IN VARCHAR2)
  RETURN VARCHAR2
AS
  l_query LONG;
  l_char      VARCHAR2(1);
  l_in_quotes BOOLEAN DEFAULT FALSE;
BEGIN
  FOR i IN 1 .. LENGTH(p_query)
  LOOP
    l_char        := SUBSTR(p_query, i, 1);
    IF(l_char      = '''' AND l_in_quotes) THEN
      l_in_quotes := FALSE;
    ELSIF(l_char   = '''' AND NOT l_in_quotes) THEN
      l_in_quotes := TRUE;
      l_query     := l_query || '''#';
    END IF;
    IF(NOT l_in_quotes) THEN
      l_query := l_query || l_char;
    END IF;
  END LOOP;
  l_query := TRANSLATE(l_query, '0123456789', '@@@@@@@@@@');
  FOR i   IN 0 .. 8
  LOOP
    l_query := REPLACE(l_query, lpad('@', 10 -i, '@'), '@');
    l_query := REPLACE(l_query, lpad(' ', 10 -i, ' '), ' ');
  END LOOP;
  RETURN UPPER(l_query);
END;
END eagle_util;

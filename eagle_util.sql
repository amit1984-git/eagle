create or replace PACKAGE          eagle_util
IS
FUNCTION info_line(in_line pls_integer) RETURN VARCHAR2;

FUNCTION sql_id_info(in_sql_id v$sql.sql_id%TYPE) RETURN NUMBER;

FUNCTION table_info(in_table_name sys.dba_tables.TABLE_NAME%TYPE) RETURN NUMBER;

FUNCTION sql_id_info_line(in_line pls_integer) RETURN VARCHAR2;

FUNCTION do_object_summary(in_sql_id v$sqlarea.sql_id%TYPE) RETURN VARCHAR2;

FUNCTION week_count(i_week PLS_INTEGER) RETURN PLS_INTEGER;

FUNCTION index_columns(i_index_owner dba_ind_columns.index_owner%TYPE, i_index_name dba_ind_columns.index_name%TYPE) RETURN VARCHAR2;

FUNCTION remove_constants(p_query IN VARCHAR2) RETURN VARCHAR2;
END eagle_util;

---- DROP PROCEDURE SP_IFRS_INITIAL_UPDATE;

CREATE OR REPLACE PROCEDURE SP_IFRS_INITIAL_UPDATE(
    IN P_RUNID VARCHAR(100) DEFAULT 'SYSTEMS', 
    IN P_DOWNLOAD_DATE DATE DEFAULT NULL,
    IN P_PRC VARCHAR(1) DEFAULT 'S')
LANGUAGE PLPGSQL AS $$
DECLARE
    ---- DATE
    V_PREVDATE DATE;
    V_PREVMONTH DATE;
    V_CURRDATE DATE;
    V_LASTYEAR DATE;
    V_LASTYEARNEXTMONTH DATE;

    ---- QUERY   
    V_STR_QUERY TEXT;

    ---- TABLE LIST       
    V_TABLENAME VARCHAR(100); 
    V_TABLENAME_MON VARCHAR(100);
    V_TABLEINSERT1 VARCHAR(100);
    V_TABLEINSERT2 VARCHAR(100);
    V_TABLEINSERT3 VARCHAR(100);
    V_TABLEINSERT4 VARCHAR(100);
    V_TABLEINSERT5 VARCHAR(100);
    V_TABLEINSERT6 VARCHAR(100);
    V_TABLEINSERT7 VARCHAR(100);

    ---- CONDITION
    V_RETURNROWS INT;
    V_RETURNROWS2 INT;
    V_TABLEDEST VARCHAR(100);
    V_COLUMNDEST VARCHAR(100);
    V_SPNAME VARCHAR(100);
    V_OPERATION VARCHAR(100);

    ---- RESULT
    V_QUERYS TEXT;

    --- VARIABLE
    V_SP_NAME VARCHAR(100);
    STACK TEXT; 
    FCESIG TEXT;
BEGIN 
    -------- ====== VARIABLE ======
	GET DIAGNOSTICS STACK = PG_CONTEXT;
	FCESIG := substring(STACK from 'function (.*?) line');
	V_SP_NAME := UPPER(LEFT(fcesig::regprocedure::text, POSITION('(' in fcesig::regprocedure::text)-1));

    IF COALESCE(P_PRC, NULL) IS NULL THEN
        P_PRC := 'S';
    END IF;

    IF COALESCE(P_RUNID, NULL) IS NULL THEN
        P_RUNID := 'SYSTEMS';
    END IF;

    IF P_PRC = 'S' THEN 
        V_TABLEINSERT1 := 'IFRS_PD_RULES_CONFIG_' || P_RUNID || '';
        V_TABLEINSERT2 := 'IFRS_CCF_RULES_CONFIG_' || P_RUNID || '';
        V_TABLEINSERT3 := 'IFRS_LGD_RULES_CONFIG_' || P_RUNID || '';
        V_TABLEINSERT4 := 'IFRS_EAD_RULES_CONFIG_' || P_RUNID || '';
    ELSE 
        V_TABLEINSERT1 := 'IFRS_PD_RULES_CONFIG';
        V_TABLEINSERT2 := 'IFRS_CCF_RULES_CONFIG';
        V_TABLEINSERT3 := 'IFRS_LGD_RULES_CONFIG';
        V_TABLEINSERT4 := 'IFRS_EAD_RULES_CONFIG';
    END IF;

    IF P_DOWNLOAD_DATE IS NULL 
    THEN
        SELECT
            CURRDATE INTO V_CURRDATE
        FROM
            IFRS_PRC_DATE;
    ELSE        
        V_CURRDATE := P_DOWNLOAD_DATE;
    END IF;
    
    V_PREVMONTH := F_EOMONTH(V_CURRDATE, 1, 'M', 'PREV');
    V_LASTYEAR := F_EOMONTH(V_CURRDATE, 1, 'Y', 'PREV');
    V_LASTYEARNEXTMONTH := F_EOMONTH(V_LASTYEAR, 1, 'M', 'NEXT');
    
    V_RETURNROWS2 := 0;
    -------- ====== VARIABLE ======

    -------- ====== PRE SIMULATION TABLE ======
    IF P_PRC = 'S' THEN
        V_STR_QUERY := 'DROP TABLE IF EXISTS ' || V_TABLEINSERT1 || '';
        V_STR_QUERY := V_STR_QUERY || '';
        EXECUTE (V_STR_QUERY);

        V_STR_QUERY := 'CREATE TABLE ' || V_TABLEINSERT1 || ' AS SELECT * FROM IFRS_PD_RULES_CONFIG WHERE 0=1';
        V_STR_QUERY := V_STR_QUERY || '';
        EXECUTE (V_STR_QUERY);

        V_STR_QUERY := 'DROP TABLE IF EXISTS ' || V_TABLEINSERT2 || '';
        V_STR_QUERY := V_STR_QUERY || '';
        EXECUTE (V_STR_QUERY);

        V_STR_QUERY := 'CREATE TABLE ' || V_TABLEINSERT2 || ' AS SELECT * FROM IFRS_CCF_RULES_CONFIG WHERE 0=1';
        V_STR_QUERY := V_STR_QUERY || '';
        EXECUTE (V_STR_QUERY);

        V_STR_QUERY := 'DROP TABLE IF EXISTS ' || V_TABLEINSERT3 || '';
        V_STR_QUERY := V_STR_QUERY || '';
        EXECUTE (V_STR_QUERY);

        V_STR_QUERY := 'CREATE TABLE ' || V_TABLEINSERT3 || ' AS SELECT * FROM IFRS_LGD_RULES_CONFIG WHERE 0=1';
        V_STR_QUERY := V_STR_QUERY || '';
        EXECUTE (V_STR_QUERY);

        V_STR_QUERY := 'DROP TABLE IF EXISTS ' || V_TABLEINSERT4 || '';
        V_STR_QUERY := V_STR_QUERY || '';
        EXECUTE (V_STR_QUERY);

        V_STR_QUERY := 'CREATE TABLE ' || V_TABLEINSERT4 || ' AS SELECT * FROM IFRS_EAD_RULES_CONFIG WHERE 0=1';
        V_STR_QUERY := V_STR_QUERY || '';
        EXECUTE (V_STR_QUERY);
    END IF;

    -------- ====== PRE SIMULATION TABLE ======
    
    -------- ====== BODY ======
    -------- ====== PD ======
    V_STR_QUERY := '';
    V_STR_QUERY := V_STR_QUERY || 'INSERT INTO ' || V_TABLEINSERT1 || ' (
    PKID, TM_RULE_NAME, SEGMENTATION_ID, PD_METHOD, CALC_METHOD, BUCKET_GROUP, EXPECTED_LIFE, INCREMENT_PERIOD,
    HISTORICAL_DATA, CUT_OFF_DATE, ACTIVE_FLAG, IS_DELETE, CREATEDBY, CREATEDDATE,
    CREATEDHOST, DEFAULT_RATIO_BY, LAG_1MONTH_FLAG, RUNNING_STATUS
    )
    SELECT * FROM dblink(''workflow_db_access'', ''SELECT pkid, pd_name, RIGHT(segment_code, 2) AS segment_code, pd_method, calculation_method_id, bucket_code, expected_lifetime, windows_moving,
    historical_data, effective_end_date, CASE WHEN is_active = TRUE THEN 1 ELSE 0 END AS is_active, 0 AS is_delete,
    created_by, created_date, created_host, default_ratio_by, CASE pd_method WHEN ''''MAA_CORP'''' THEN 0 WHEN ''''z'''' THEN 0 ELSE 1 END AS lag_1month_flag,
    ''''PENDING'''' AS running_status
    FROM "PdConfiguration_Dev" ORDER BY pkid ASC'') 
    AS IFRS_PD_RULES_CONFIG_DATA(
    PKID BIGINT, TM_RULE_NAME VARCHAR(250), SEGMENTATION_ID BIGINT, PD_METHOD VARCHAR(50), CALC_METHOD VARCHAR(20), BUCKET_GROUP VARCHAR(30), EXPECTED_LIFE BIGINT, INCREMENT_PERIOD BIGINT,
    HISTORICAL_DATA BIGINT, CUT_OFF_DATE DATE, ACTIVE_FLAG BIGINT, IS_DELETE BIGINT, CREATEDBY VARCHAR(36), CREATEDDATE DATE,
    CREATEDHOST VARCHAR(30), DEFAULT_RATIO_BY VARCHAR(20), LAG_1MONTH_FLAG BIGINT, RUNNING_STATUS VARCHAR(20)
    )';
    EXECUTE (V_STR_QUERY);
    -------- ====== PD ======

    -- V_STR_QUERY := '';
    -- V_STR_QUERY := V_STR_QUERY || '';
    -- EXECUTE (V_STR_QUERY);

    -- GET DIAGNOSTICS V_RETURNROWS = ROW_COUNT;
    -- V_RETURNROWS2 := V_RETURNROWS2 + V_RETURNROWS;
    -- V_RETURNROWS := 0;

    -- RAISE NOTICE 'XXX | AFFECTED RECORD : %', V_RETURNROWS2;
    -------- ====== BODY ======

    -- -------- ====== LOG ======
    -- V_TABLEDEST = V_TABLEINSERT4;
    -- V_COLUMNDEST = '-';
    -- V_SPNAME = 'XXX';
    -- V_OPERATION = 'INSERT';
    
    -- CALL SP_IFRS_EXEC_AND_LOG(V_CURRDATE, V_TABLEDEST, V_COLUMNDEST, V_SPNAME, V_OPERATION, V_RETURNROWS2, P_RUNID);
    -- -------- ====== LOG ======

    -- -------- ====== RESULT ======
    -- V_QUERYS = 'SELECT * FROM ' || V_TABLEINSERT4 || '';
    -- CALL SP_IFRS_RESULT_PREV(V_CURRDATE, V_QUERYS, V_SPNAME, V_RETURNROWS2, P_RUNID);
    -- -------- ====== RESULT ======

END;

$$;
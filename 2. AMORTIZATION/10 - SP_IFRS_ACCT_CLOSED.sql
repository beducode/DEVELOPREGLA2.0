---- DROP PROCEDURE SP_IFRS_ACCT_CLOSED;

CREATE OR REPLACE PROCEDURE SP_IFRS_ACCT_CLOSED(
    IN P_RUNID VARCHAR(20) DEFAULT 'S_00000_0000',
    IN P_DOWNLOAD_DATE DATE DEFAULT NULL,
    IN P_PRC VARCHAR(1) DEFAULT 'S')
LANGUAGE PLPGSQL AS $$
DECLARE
    ---- DATE
    V_PREVDATE DATE;
    V_CURRDATE DATE;

    ---- QUERY   
    V_STR_QUERY TEXT;

    ---- TABLE LIST       
    V_TABLENAME VARCHAR(100);
    V_TABLEINSERT1 VARCHAR(100);
    V_TABLEINSERT2 VARCHAR(100);
    V_TABLEINSERT3 VARCHAR(100);
    
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
        P_RUNID := 'S_00000_0000';
    END IF;

    IF P_PRC = 'S' THEN 
        V_TABLENAME := 'TMP_IMA_' || P_RUNID || '';
        V_TABLEINSERT1 := 'IFRS_IMA_AMORT_PREV_' || P_RUNID || '';
        V_TABLEINSERT2 := 'IFRS_IMA_AMORT_CURR_' || P_RUNID || '';
        V_TABLEINSERT3 := 'IFRS_ACCT_CLOSED_' || P_RUNID || '';
    ELSE 
        V_TABLENAME := 'IFRS_MASTER_ACCOUNT';
        V_TABLEINSERT1 := 'IFRS_IMA_AMORT_PREV';
        V_TABLEINSERT2 := 'IFRS_IMA_AMORT_CURR';
        V_TABLEINSERT3 := 'IFRS_ACCT_CLOSED';
    END IF;
    
    IF P_DOWNLOAD_DATE IS NULL 
    THEN
        SELECT
            CURRDATE, PREVDATE INTO V_CURRDATE, V_PREVDATE
        FROM
            IFRS_PRC_DATE;
    ELSE        
        V_CURRDATE := P_DOWNLOAD_DATE;
        V_PREVDATE := V_CURRDATE - INTERVAL '1 DAY';
    END IF;
    
    V_RETURNROWS2 := 0;
    -------- ====== VARIABLE ======

    -------- ====== PRE SIMULATION TABLE ======
    IF P_PRC = 'S' THEN
        V_STR_QUERY := '';
        V_STR_QUERY := V_STR_QUERY || 'DROP TABLE IF EXISTS ' || V_TABLEINSERT3 || ' ';
        EXECUTE (V_STR_QUERY);

        V_STR_QUERY := '';
        V_STR_QUERY := V_STR_QUERY || 'CREATE TABLE ' || V_TABLEINSERT3 || ' AS SELECT * FROM IFRS_ACCT_CLOSED WHERE 1=0 ';
        EXECUTE (V_STR_QUERY);
    END IF;
    -------- ====== PRE SIMULATION TABLE ======

    -------- ====== BODY ======
    CALL SP_IFRS_LOG_AMORT(V_CURRDATE, 'START', 'SP_IFRS_ACCT_CLOSED', '');

    ---- INSERT ACCOUNT CLOSED
    V_STR_QUERY := '';
    V_STR_QUERY := V_STR_QUERY || 'DELETE FROM ' || V_TABLEINSERT3 || ' WHERE DOWNLOAD_DATE = ''' || CAST(V_CURRDATE AS VARCHAR(10)) || ''':: DATE ';
    EXECUTE (V_STR_QUERY);

    V_STR_QUERY := '';
    V_STR_QUERY := V_STR_QUERY || 'INSERT INTO ' || V_TABLEINSERT3 || ' 
        (
            FACNO 
            ,CIFNO 
            ,DATASOURCE 
            ,DOWNLOAD_DATE 
            ,MASTERID 
            ,ACCTNO 
            ,CREATEDBY 
        ) SELECT 
            A.FACILITY_NUMBER 
            ,A.CUSTOMER_NUMBER 
            ,A.DATA_SOURCE 
            ,''' || CAST(V_CURRDATE AS VARCHAR(10)) || ''':: DATE AS DOWNLOAD_DATE 
            ,A.MASTERID 
            ,A.ACCOUNT_NUMBER 
            ,CASE WHEN A.ACCOUNT_STATUS = ''W'' THEN ''WO'' ELSE ''CLOSED'' END 
        FROM ' || V_TABLEINSERT2 || ' A 
        JOIN (
            SELECT DISTINCT MASTERID FROM ' || V_TABLEINSERT2 || ' WHERE AMORT_TYPE = ''EIR'' 
            UNION 
            SELECT DISTINCT MASTERID FROM ' || V_TABLEINSERT1 || ' WHERE AMORT_TYPE = ''EIR''
        ) C 
        ON A.MASTERID = C.MASTERID 
        WHERE (A.WRITEOFF_FLAG = ''Y'' OR A.ACCOUNT_STATUS = ''W'') 
        OR (ACCOUNT_STATUS IN (''C'', ''E'', ''CE'', ''CT'', ''CN'')) 
        OR (A.OUTSTANDING <= 0) 
        OR (A.LOAN_DUE_DATE <= ''' || CAST(V_CURRDATE AS VARCHAR(10)) || ''':: DATE) ';
    EXECUTE (V_STR_QUERY);

    GET DIAGNOSTICS V_RETURNROWS = ROW_COUNT;
    V_RETURNROWS2 := V_RETURNROWS2 + V_RETURNROWS;
    V_RETURNROWS := 0;

    V_STR_QUERY := '';
    V_STR_QUERY := V_STR_QUERY || 'INSERT INTO ' || V_TABLEINSERT3 || ' 
        ( 
            FACNO 
            ,CIFNO 
            ,DATASOURCE 
            ,DOWNLOAD_DATE 
            ,MASTERID 
            ,ACCTNO 
            ,CREATEDBY 
        ) SELECT 
            A.FACILITY_NUMBER 
            ,A.CUSTOMER_NUMBER 
            ,A.DATA_SOURCE 
            ,''' || CAST(V_CURRDATE AS VARCHAR(10)) || ''':: DATE AS DOWNLOAD_DATE 
            ,A.MASTERID 
            ,A.ACCOUNT_NUMBER 
            ,CASE WHEN A.ACCOUNT_STATUS = ''W'' THEN ''WO'' ELSE ''CLOSED'' END
        FROM ' || V_TABLEINSERT2 || ' A 
        JOIN (
            SELECT DISTINCT MASTERID FROM ' || V_TABLEINSERT2 || ' WHERE AMORT_TYPE = ''SL'' 
            UNION 
            SELECT DISTINCT MASTERID FROM ' || V_TABLEINSERT1 || ' WHERE AMORT_TYPE = ''SL''
        ) C 
        ON A.MASTERID = C.MASTERID 
        WHERE (A.WRITEOFF_FLAG = ''Y'' OR A.ACCOUNT_STATUS = ''W'')
        OR (ACCOUNT_STATUS IN (''C'', ''E'', ''CE'', ''CT'', ''CN''))
        OR (A.OUTSTANDING <= 0 AND A.DATA_SOURCE <> ''LIMIT'')
        OR (A.LOAN_DUE_DATE <= ''' || CAST(V_CURRDATE AS VARCHAR(10)) || ''':: DATE) ';
    EXECUTE (V_STR_QUERY);
    
    GET DIAGNOSTICS V_RETURNROWS = ROW_COUNT;
    V_RETURNROWS2 := V_RETURNROWS2 + V_RETURNROWS;
    V_RETURNROWS := 0;

    ---- ACCOUNT HILANG 
    V_STR_QUERY := '';
    V_STR_QUERY := V_STR_QUERY || 'INSERT INTO ' || V_TABLEINSERT3 || ' 
        ( 
            FACNO 
            ,CIFNO 
            ,DATASOURCE 
            ,DOWNLOAD_DATE 
            ,MASTERID 
            ,ACCTNO 
            ,CREATEDBY 
        ) SELECT 
            A.FACILITY_NUMBER 
            ,A.CUSTOMER_NUMBER 
            ,A.DATA_SOURCE 
            ,''' || CAST(V_CURRDATE AS VARCHAR(10)) || ''':: DATE AS DOWNLOAD_DATE 
            ,A.MASTERID 
            ,A.ACCOUNT_NUMBER 
            ,''CLOSED'' AS CREATEDBY 
        FROM ' || V_TABLEINSERT1 || ' A 
        LEFT JOIN ' || V_TABLEINSERT2 || ' B 
        ON A.MASTERID = B.MASTERID 
        WHERE B.MASTERID IS NULL ';
    EXECUTE (V_STR_QUERY);

    GET DIAGNOSTICS V_RETURNROWS = ROW_COUNT;
    V_RETURNROWS2 := V_RETURNROWS2 + V_RETURNROWS;
    V_RETURNROWS := 0;

    ---- PNL SISA UNAMORT IF IFRS9 CLASS FVTPL
    V_STR_QUERY := '';
    V_STR_QUERY := V_STR_QUERY || 'INSERT INTO ' || V_TABLEINSERT3 || ' 
        (
            FACNO 
            ,CIFNO 
            ,DATASOURCE 
            ,DOWNLOAD_DATE 
            ,MASTERID 
            ,ACCTNO 
            ,CREATEDBY 
        ) SELECT 
            A.FACILITY_NUMBER 
            ,A.CUSTOMER_NUMBER 
            ,A.DATA_SOURCE 
            ,''' || CAST(V_CURRDATE AS VARCHAR(10)) || ''':: DATE AS DOWNLOAD_DATE 
            ,A.MASTERID 
            ,A.ACCOUNT_NUMBER 
            ,''FVTPL'' AS CREATEDBY 
        FROM ' || V_TABLEINSERT2 || ' A 
        WHERE A.IFRS9_CLASS = ''FVTPL'' 
        AND A.DOWNLOAD_DATE = ''' || CAST(V_CURRDATE AS VARCHAR(10)) || ''':: DATE ';
    EXECUTE (V_STR_QUERY);

    GET DIAGNOSTICS V_RETURNROWS = ROW_COUNT;
    V_RETURNROWS2 := V_RETURNROWS2 + V_RETURNROWS;
    V_RETURNROWS := 0;

    ---- END
    CALL SP_IFRS_LOG_AMORT(V_CURRDATE, 'END', 'SP_IFRS_ACCT_CLOSED', '');

    RAISE NOTICE 'SP_IFRS_ACCT_CLOSED | AFFECTED RECORD : %', V_RETURNROWS2;
    ---------- ====== BODY ======

    -------- ====== LOG ======
    V_TABLEDEST = V_TABLEINSERT3;
    V_COLUMNDEST = '-';
    V_SPNAME = 'SP_IFRS_ACCT_CLOSED';
    V_OPERATION = 'INSERT';
    
    CALL SP_IFRS_EXEC_AND_LOG(V_CURRDATE, V_TABLEDEST, V_COLUMNDEST, V_SPNAME, V_OPERATION, V_RETURNROWS2, P_RUNID);
    -------- ====== LOG ======

    -------- ====== RESULT ======
    V_QUERYS = 'SELECT * FROM ' || V_TABLEINSERT3 || '';
    CALL SP_IFRS_RESULT_PREV(V_CURRDATE, V_QUERYS, V_SPNAME, V_RETURNROWS2, P_RUNID);
    -------- ====== RESULT ======

END;

$$;
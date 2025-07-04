---- DROP PROCEDURE SP_IFRS_SYNC_TRANS_PARAM;

CREATE OR REPLACE PROCEDURE SP_IFRS_SYNC_TRANS_PARAM(
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
    V_TABLEINSERT VARCHAR(100);
    
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
        V_TABLEINSERT := 'IFRS_TRANSACTION_PARAM_' || P_RUNID || '';
    ELSE 
        V_TABLEINSERT := 'IFRS_TRANSACTION_PARAM';
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
        V_STR_QUERY := V_STR_QUERY || 'DROP TABLE IF EXISTS ' || V_TABLEINSERT || ' ';
        EXECUTE (V_STR_QUERY);

        V_STR_QUERY := '';
        V_STR_QUERY := V_STR_QUERY || 'CREATE TABLE ' || V_TABLEINSERT || ' AS SELECT * FROM IFRS_TRANSACTION_PARAM WHERE 1=0 ';
        EXECUTE (V_STR_QUERY);
    END IF;
    -------- ====== PRE SIMULATION TABLE ======

    -------- ====== BODY ======
    CALL SP_IFRS_LOG_AMORT(V_CURRDATE, 'START', 'SP_IFRS_ACCT_EIR_UPD_UNAMORT', '');

    V_STR_QUERY := '';
    V_STR_QUERY := V_STR_QUERY || 'TRUNCATE TABLE ' || V_TABLEINSERT || ' ';
    EXECUTE (V_STR_QUERY);
    
    CALL SP_IFRS_LOG_AMORT(V_CURRDATE, 'DEBUG', V_SP_NAME, 'INSERT TRANS PARAM');

    V_STR_QUERY := '';
    V_STR_QUERY := V_STR_QUERY || 'INSERT INTO ' || V_TABLEINSERT || ' 
        ( 
            DATA_SOURCE 
            ,PRD_TYPE 
            ,PRD_CODE 
            ,TRX_CODE 
            ,CCY 
            ,IFRS_TXN_CLASS 
            ,AMORTIZATION_FLAG 
            ,AMORT_TYPE 
            ,GL_CODE 
            ,TENOR_TYPE 
            ,TENOR_AMORTIZATION 
            ,SL_EXP_LIFE 
            ,FEE_MAT_TYPE 
            ,FEE_MAT_AMT 
            ,COST_MAT_TYPE 
            ,COST_MAT_AMT 
        ) SELECT 
            DATA_SOURCE 
            ,PRD_TYPE 
            ,PRD_CODE 
            ,TRX_CODE 
            ,CCY 
            ,IFRS_TXN_CLASS 
            ,CASE WHEN AMORTIZATION_FLAG = 1 THEN ''Y'' ELSE ''N'' END AS AMORTIZATION_FLAG 
            ,AMORT_TYPE 
            ,GL_CODE 
            ,TENOR_TYPE 
            ,TENOR_AMORTIZATION 
            ,SL_EXP_LIFE 
            ,ORG_FEE_MAT_TYPE 
            ,ORG_FEE_MAT_AMT 
            ,TXN_COST_MAT_TYPE 
            ,TXN_COST_MAT_AMT 
        FROM IFRS_MASTER_TRANS_PARAM 
        WHERE INST_CLS_VALUE IN (''A'', ''O'') 
        AND IS_DELETE = 0 ';
    EXECUTE (V_STR_QUERY);

    GET DIAGNOSTICS V_RETURNROWS = ROW_COUNT;
    V_RETURNROWS2 := V_RETURNROWS2 + V_RETURNROWS;
    V_RETURNROWS := 0;
    
    CALL SP_IFRS_LOG_AMORT(V_CURRDATE, 'END', V_SP_NAME, '');

    RAISE NOTICE 'SP_IFRS_SYNC_TRANS_PARAM | AFFECTED RECORD : %', V_RETURNROWS2;
    ---------- ====== BODY ======

    -------- ====== LOG ======
    V_TABLEDEST = V_TABLEINSERT;
    V_COLUMNDEST = '-';
    V_SPNAME = 'SP_IFRS_SYNC_TRANS_PARAM';
    V_OPERATION = 'INSERT';
    
    CALL SP_IFRS_EXEC_AND_LOG(V_CURRDATE, V_TABLEDEST, V_COLUMNDEST, V_SPNAME, V_OPERATION, V_RETURNROWS2, P_RUNID);
    -------- ====== LOG ======

    -------- ====== RESULT ======
    V_QUERYS = 'SELECT * FROM ' || V_TABLEINSERT || '';
    CALL SP_IFRS_RESULT_PREV(V_CURRDATE, V_QUERYS, V_SPNAME, V_RETURNROWS2, P_RUNID);
    -------- ====== RESULT ======

END;

$$;
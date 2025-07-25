---- DROP PROCEDURE SP_IFRS_IMP_SYNC_RESTRU_COVID;

CREATE OR REPLACE PROCEDURE SP_IFRS_IMP_SYNC_RESTRU_COVID(
    IN P_RUNID VARCHAR(20) DEFAULT 'S_00000_0000',
    IN P_DOWNLOAD_DATE DATE DEFAULT NULL,
    IN P_PRC VARCHAR(1) DEFAULT 'S')
LANGUAGE PLPGSQL AS $$
DECLARE
    ---- DATE
    V_PREVDATE DATE;
    V_PREVMONTH DATE;
    V_CURRDATE DATE;

    ---- QUERY   
    V_STR_QUERY TEXT;

    ---- TABLE LIST       
    V_TABLENAME VARCHAR(100);
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
        V_TABLENAME := 'TMP_IMA_' || P_RUNID || '';
        V_TABLEINSERT := 'IFRS_MASTER_RESTRU_COVID_' || P_RUNID || '';
    ELSE 
        V_TABLENAME := 'IFRS_MASTER_ACCOUNT';
        V_TABLEINSERT := 'IFRS_MASTER_RESTRU_COVID';
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

    V_PREVMONTH := F_EOMONTH(V_CURRDATE, 1, 'M', 'PREV');
    
    V_RETURNROWS2 := 0;
    -------- ====== VARIABLE ======

    -------- ====== PRE SIMULATION TABLE ======
    IF P_PRC = 'S' THEN
        V_STR_QUERY := '';
        V_STR_QUERY := V_STR_QUERY || 'DROP TABLE IF EXISTS ' || V_TABLEINSERT || ' ';
        EXECUTE (V_STR_QUERY);

        V_STR_QUERY := '';
        V_STR_QUERY := V_STR_QUERY || 'CREATE TABLE ' || V_TABLEINSERT || ' AS SELECT * FROM IFRS_MASTER_RESTRU_COVID WHERE 1=0 ';
        EXECUTE (V_STR_QUERY);
    END IF;
    -------- ====== PRE SIMULATION TABLE ======

    -------- ====== BODY ======
    V_STR_QUERY := '';
    V_STR_QUERY := V_STR_QUERY || 'DELETE FROM ' || V_TABLEINSERT || ' WHERE DOWNLOAD_DATE = ''' || CAST(V_CURRDATE AS VARCHAR(10)) || '''::DATE ';
    EXECUTE (V_STR_QUERY);

    V_STR_QUERY := '';
    V_STR_QUERY := V_STR_QUERY || 'INSERT INTO ' || V_TABLEINSERT || ' 
        (
            DOWNLOAD_DATE 
            ,MASTERID 
            ,PREV_MASTERID 
            ,CUSTOMER_NUMBER 
            ,ACCOUNT_NUMBER 
            ,PREV_ACCOUNT_NUMBER 
            ,PRODUCT_CODE 
            ,PREV_PRODUCT_CODE 
            ,STAGE 
            ,BUCKET_NAME 
            ,SOURCE_SYSTEM 
            ,CREATEDBY 
            ,CREATEDDATE 
            ,CREATEDHOST 
        ) SELECT 
            TRIM(BUSS_DATE)::DATE AS DOWNLOAD_DATE 
            ,CASE 
                --WHEN TRIM(SOURCE_SYSTEM) = ''T24'' THEN TRIM(NEW_DEAL_REF) 
                WHEN TRIM(SOURCE_SYSTEM) IN (''LIQ'', ''DOKA'', ''TIS'', ''TRSUPL'', ''T24'') THEN TRIM(NEW_DEAL_REF) 
                ELSE CONCAT(TRIM(CIF), ''_'', TRIM(NEW_DEAL_REF), ''_'', TRIM(NEW_DEAL_TYPE)) 
            END AS MASTERID 
            ,CASE 
                --WHEN TRIM(SOURCE_SYSTEM) = ''T24'' THEN TRIM(OLD_DEAL_REF)
                WHEN TRIM(SOURCE_SYSTEM) IN (''LIQ'', ''DOKA'', ''TIS'', ''TRSUPL'', ''T24'') THEN TRIM(OLD_DEAL_REF)  
                ELSE CONCAT(TRIM(CIF), ''_'', TRIM(OLD_DEAL_REF), ''_'', TRIM(OLD_DEAL_TYPE)) 
            END AS PREV_MASTERID 
            ,TRIM(CIF) AS CUSTOMER_NUMBER 
            ,TRIM(NEW_DEAL_REF) AS ACCOUNT_NUMBER 
            ,TRIM(OLD_DEAL_REF) AS PREV_ACCOUNT_NUMBER 
            ,TRIM(NEW_DEAL_TYPE) AS PRODUCT_CODE 
            ,TRIM(OLD_DEAL_TYPE) AS PREV_PRODUCT_CODE 
            ,TRIM(STAGE) AS STAGE 
            ,TRIM(BUCKET) AS BUCKET_NAME 
            ,TRIM(SOURCE_SYSTEM) AS SOURCE_SYSTEM 
            ,CREATEDBY 
            ,CREATEDDATE 
            ,CREATEDHOST 
        FROM TBLU_RESTRU_COVID 
        WHERE TRIM(BUSS_DATE)::DATE = ''' || CAST(V_CURRDATE AS VARCHAR(10)) || '''::DATE ';
    EXECUTE (V_STR_QUERY);

    GET DIAGNOSTICS V_RETURNROWS = ROW_COUNT;
    V_RETURNROWS2 := V_RETURNROWS2 + V_RETURNROWS;
    V_RETURNROWS := 0;

    RAISE NOTICE 'SP_IFRS_IMP_SYNC_RESTRU_COVID | AFFECTED RECORD : %', V_RETURNROWS2;
    ---------- ====== BODY ======

    -------- ====== LOG ======
    V_TABLEDEST = V_TABLEINSERT;
    V_COLUMNDEST = '-';
    V_SPNAME = 'SP_IFRS_IMP_SYNC_RESTRU_COVID';
    V_OPERATION = 'INSERT';
    
    CALL SP_IFRS_EXEC_AND_LOG(V_CURRDATE, V_TABLEDEST, V_COLUMNDEST, V_SPNAME, V_OPERATION, V_RETURNROWS2, P_RUNID);
    -------- ====== LOG ======

    -------- ====== RESULT ======
    V_QUERYS = 'SELECT * FROM ' || V_TABLEINSERT || '';
    CALL SP_IFRS_RESULT_PREV(V_CURRDATE, V_QUERYS, V_SPNAME, V_RETURNROWS2, P_RUNID);
    -------- ====== RESULT ======

END;

$$;
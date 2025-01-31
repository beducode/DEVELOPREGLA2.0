---- DROP PROCEDURE SP_IFRS_IMP_PD_MAA_AVERAGE;

CREATE OR REPLACE PROCEDURE SP_IFRS_IMP_PD_MAA_AVERAGE(
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
    V_TABLEPDCONFIG VARCHAR(100);

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
        V_TABLENAME := 'TMP_IMA_' || P_RUNID || '';
        V_TABLENAME_MON := 'TMP_IMAM_' || P_RUNID || '';
        V_TABLEINSERT1 := 'TMP_IFRS_ECL_IMA_' || P_RUNID || '';
        V_TABLEINSERT2 := 'IFRS_IMA_IMP_CURR_' || P_RUNID || '';
        V_TABLEINSERT3 := 'IFRS_PD_MAA_ENR_' || P_RUNID || '';
        V_TABLEINSERT4 := 'IFRS_PD_MAA_AVERAGE_' || P_RUNID || '';
    ELSE 
        V_TABLENAME := 'IFRS_MASTER_ACCOUNT';
        V_TABLENAME_MON := 'IFRS_MASTER_ACCOUNT_MONTHLY';
        V_TABLEINSERT1 := 'TMP_IFRS_ECL_IMA';
        V_TABLEINSERT2 := 'IFRS_IMA_IMP_CURR';
        V_TABLEINSERT3 := 'IFRS_PD_MAA_ENR';
        V_TABLEINSERT4 := 'IFRS_PD_MAA_AVERAGE';
    END IF;

    V_TABLEPDCONFIG := 'IFRS_PD_RULES_CONFIG_' || P_RUNID || '';

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
        V_STR_QUERY := '';
        V_STR_QUERY := V_STR_QUERY || 'DROP TABLE IF EXISTS ' || V_TABLEINSERT4 || ' ';
        EXECUTE (V_STR_QUERY);

        V_STR_QUERY := '';
        V_STR_QUERY := V_STR_QUERY || 'CREATE TABLE ' || V_TABLEINSERT4 || ' AS SELECT * FROM IFRS_PD_MAA_AVERAGE WHERE 0=1';
        EXECUTE (V_STR_QUERY);
    END IF;
    -------- ====== PRE SIMULATION TABLE ======
    
    -------- ====== BODY ======

    V_STR_QUERY := '';
    V_STR_QUERY := V_STR_QUERY || 'DELETE FROM ' || V_TABLEINSERT4 || ' A
    USING ' || V_TABLEPDCONFIG || ' B 
    WHERE A.PD_RULE_ID = B.PKID
    AND TO_DATE = ''' || CAST(V_CURRDATE AS VARCHAR(10)) || '''::DATE
    AND B.ACTIVE_FLAG = 1 AND B.IS_DELETE = 0';
    EXECUTE (V_STR_QUERY);

    V_STR_QUERY := '';
    V_STR_QUERY := V_STR_QUERY || 'INSERT INTO ' || V_TABLEINSERT4 || ' 
    (DOWNLOAD_DATE
    ,BASE_DATE
    ,TO_DATE
    ,PD_RULE_ID
    ,PD_RULE_NAME
    ,BUCKET_GROUP
    ,BUCKET_FROM
    ,BUCKET_TO
    ,CALC_METHOD
    ,AVERAGE_RATE
    ,CREATEDBY
    ,CREATEDDATE)
    SELECT 
    MAX(DOWNLOAD_DATE) AS DOWNLOAD_DATE
    ,MAX(BASE_DATE) AS BASE_DATE
    ,''' || CAST(V_CURRDATE AS VARCHAR(10)) || '''::DATE AS TO_DATE
    ,PD_RULE_ID
    ,MAX(PD_RULE_NAME)
    ,MAX(A.BUCKET_GROUP)
    ,BUCKET_FROM
    ,BUCKET_TO
    ,MAX(A.CALC_METHOD)
    ,AVG(PERCENTAGE) AS AVERAGE_RATE
    ,''SP_IFRS_IMP_PD_MAA_AVERAGE'' AS CREATEDBY
    ,CURRENT_DATE AS CREATEDDATE
    FROM ' || V_TABLEINSERT3 || ' A 
    INNER JOIN ' || V_TABLEPDCONFIG || ' B ON A.PD_RULE_ID = B.PKID
    WHERE TO_DATE <= ''' || CAST(V_CURRDATE AS VARCHAR(10)) || '''::DATE 
    AND TO_DATE >= F_EOMONTH(''' || CAST(V_CURRDATE AS VARCHAR(10)) || '''::DATE, B.HISTORICAL_DATA, ''M'', ''PREV'') AND DOWNLOAD_DATE >= B.CUT_OFF_DATE  
    AND B.ACTIVE_FLAG = 1 AND B.IS_DELETE = 0
    GROUP BY PD_RULE_ID ,BUCKET_FROM,BUCKET_TO';
    EXECUTE (V_STR_QUERY);

    GET DIAGNOSTICS V_RETURNROWS = ROW_COUNT;
    V_RETURNROWS2 := V_RETURNROWS2 + V_RETURNROWS;
    V_RETURNROWS := 0;

    V_STR_QUERY := '';
    V_STR_QUERY := V_STR_QUERY || 'UPDATE ' || V_TABLEINSERT4 || ' A
    SET AVERAGE_RATE = CASE WHEN A.BUCKET_TO = B.MAX_BUCKET_ID THEN 1 ELSE 0 END
    FROM VW_IFRS_MAX_BUCKET AS B, ' || V_TABLEPDCONFIG || ' AS C 
    WHERE A.PD_RULE_ID = C.PKID AND A.BUCKET_GROUP = B.BUCKET_GROUP AND A.BUCKET_FROM = B.MAX_BUCKET_ID
    AND TO_DATE = ''' || CAST(V_CURRDATE AS VARCHAR(10)) || '''::DATE
    AND C.ACTIVE_FLAG = 1 AND C.IS_DELETE = 0';
    EXECUTE (V_STR_QUERY);

    RAISE NOTICE 'SP_IFRS_IMP_PD_MAA_AVERAGE | AFFECTED RECORD : %', V_RETURNROWS2;
    -------- ====== BODY ======

    -------- ====== LOG ======
    V_TABLEDEST = V_TABLEINSERT4;
    V_COLUMNDEST = '-';
    V_SPNAME = 'SP_IFRS_IMP_PD_MAA_AVERAGE';
    V_OPERATION = 'INSERT';
    
    CALL SP_IFRS_EXEC_AND_LOG(V_CURRDATE, V_TABLEDEST, V_COLUMNDEST, V_SPNAME, V_OPERATION, V_RETURNROWS2, P_RUNID);
    -------- ====== LOG ======

    -------- ====== RESULT ======
    V_QUERYS = 'SELECT * FROM ' || V_TABLEINSERT4 || '';
    CALL SP_IFRS_RESULT_PREV(V_CURRDATE, V_QUERYS, V_SPNAME, V_RETURNROWS2, P_RUNID);
    -------- ====== RESULT ======

END;

$$;
---- DROP PROCEDURE SP_IFRS_IMP_PD_CHR_SUMM;

CREATE OR REPLACE PROCEDURE SP_IFRS_IMP_PD_CHR_SUMM(
    IN P_RUNID VARCHAR(20) DEFAULT 'S_00000_0000', 
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

    ---- VARIABLE PROCESS
    V_PD_RULE_ID INT;         
    V_HISTORICAL_DATA INT;         
    V_INCREMENT_PERIOD INT;         
    V_CUT_OFF_DATE DATE;         
    V_MIN_DATE DATE;         
    V_MAX_DATE DATE;        
    V_LIST_DATE DATE; 

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
        V_TABLEINSERT3 := 'IFRS_IMA_IMP_PREV_' || P_RUNID || '';
        V_TABLEPDCONFIG := 'IFRS_PD_RULES_CONFIG_' || P_RUNID || '';
    ELSE 
        V_TABLENAME := 'IFRS_MASTER_ACCOUNT';
        V_TABLENAME_MON := 'IFRS_MASTER_ACCOUNT_MONTHLY';
        V_TABLEINSERT1 := 'TMP_IFRS_ECL_IMA';
        V_TABLEINSERT2 := 'IFRS_IMA_IMP_CURR';
        V_TABLEINSERT3 := 'IFRS_IMA_IMP_PREV';
        V_TABLEPDCONFIG := 'IFRS_PD_RULES_CONFIG';
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
    -- IF P_PRC = 'S' THEN
    --     V_STR_QUERY := '';
    --     V_STR_QUERY := V_STR_QUERY || 'DROP TABLE IF EXISTS ' || V_TABLEINSERT4 || ' ';
    --     EXECUTE (V_STR_QUERY);

    --     V_STR_QUERY := '';
    --     V_STR_QUERY := V_STR_QUERY || 'CREATE TABLE ' || V_TABLEINSERT4 || ' AS SELECT * FROM XXX WHERE 0=1';
    --     EXECUTE (V_STR_QUERY);
    -- END IF;
    -------- ====== PRE SIMULATION TABLE ======
    
    -------- ====== BODY ======
    V_STR_QUERY := '';
    V_STR_QUERY := V_STR_QUERY || 'DELETE FROM IFRS_PD_CHR_BASE_DATA A         
    USING ' || V_TABLEPDCONFIG || ' B WHERE A.PD_RULE_ID = B.PKID         
    AND DOWNLOAD_DATE = F_EOMONTH(''' || CAST(V_CURRDATE AS VARCHAR(10)) || '''::DATE, B.INCREMENT_PERIOD, ''M'', ''PREV'')
    AND B.ACTIVE_FLAG = 1 AND B.IS_DELETE = 0';
    EXECUTE (V_STR_QUERY);


    V_STR_QUERY := '';
    V_STR_QUERY := V_STR_QUERY || 'INSERT INTO IFRS_PD_CHR_BASE_DATA (DOWNLOAD_DATE        
    ,PROJECTION_DATE        
    ,PD_RULE_ID        
    ,PD_RULE_NAME        
    ,BUCKET_GROUP        
    ,PD_UNIQUE_ID        
    ,SEGMENT        
    ,CALC_METHOD        
    ,BUCKET_ID        
    ,BUCKET_NAME        
    ,OUTSTANDING        
    ,DEFAULT_FLAG        
    ,BI_COLLECTABILITY        
    ,RATING_CODE        
    ,DAY_PAST_DUE        
    ,NEXT_12M_DEFAULT_FLAG)        
    SELECT DOWNLOAD_DATE        
    ,F_EOMONTH(''' || CAST(V_CURRDATE AS VARCHAR(10)) || '''::DATE, 0, ''M'', ''PREV'') AS PROJECTION_DATE        
    ,PD_RULE_ID        
    ,MAX(PD_RULE_NAME)        
    ,MAX(A.BUCKET_GROUP)        
    ,A.PD_UNIQUE_ID        
    ,MAX(SEGMENT)        
    ,MAX(A.CALC_METHOD)        
    ,MAX(A.BUCKET_ID)        
    ,MAX(CASE WHEN C.BUCKET_NAME IS NULL THEN ''FP'' ELSE C.BUCKET_NAME END) AS BUCKET_NAME        
    ,SUM(OUTSTANDING)        
    ,MAX(CASE WHEN DEFAULT_FLAG = 1 THEN 1 ELSE 0 END) AS DEFAULT_FLAG        
    ,MAX(BI_COLLECTABILITY)        
    ,MAX(RATING_CODE)        
    ,MAX(DAY_PAST_DUE)        
    ,MAX(CASE WHEN NEXT_12M_DEFAULT_FLAG = 1 THEN 1 ELSE 0 END) AS NEXT_12M_DEFAULT_FLAG         
    FROM IFRS_PD_SCENARIO_DATA A         
    INNER JOIN ' || V_TABLEPDCONFIG || ' B ON A.PD_RULE_ID = B.PKID AND  B.ACTIVE_FLAG = 1 AND B.IS_DELETE = 0        
    LEFT JOIN (SELECT * FROM IFRS_BUCKET_DETAIL WHERE IS_DELETE = 0 AND ACTIVE_FLAG = 1) C  ON A.BUCKET_GROUP = C.BUCKET_GROUP AND A.BUCKET_ID = C.BUCKET_ID         
    WHERE  DOWNLOAD_DATE = F_EOMONTH(''' || CAST(V_CURRDATE AS VARCHAR(10)) || '''::DATE, B.INCREMENT_PERIOD, ''M'', ''PREV'') AND  A.PD_METHOD = ''CHR''         
    GROUP BY DOWNLOAD_DATE,PD_RULE_ID,PD_UNIQUE_ID';
    EXECUTE (V_STR_QUERY);

    GET DIAGNOSTICS V_RETURNROWS = ROW_COUNT;
    V_RETURNROWS2 := V_RETURNROWS2 + V_RETURNROWS;
    V_RETURNROWS := 0;

    V_STR_QUERY := '';
    V_STR_QUERY := V_STR_QUERY || 'TRUNCATE TABLE TMP_IFRS_PD_LIST_DATE';
    EXECUTE (V_STR_QUERY);

    FOR V_PD_RULE_ID,V_HISTORICAL_DATA,V_INCREMENT_PERIOD,V_CUT_OFF_DATE IN
        EXECUTE 'SELECT PKID AS PD_RULE_ID ,HISTORICAL_DATA, INCREMENT_PERIOD, CUT_OFF_DATE 
        FROM ' || V_TABLEPDCONFIG || ' 
        WHERE  IS_DELETE = 0 AND ACTIVE_FLAG = 1 AND PD_METHOD = ''CHR''         
        AND CUT_OFF_DATE <= F_EOMONTH(''' || CAST(V_CURRDATE AS VARCHAR(10)) || '''::DATE, INCREMENT_PERIOD, ''M'', ''PREV'')'
    LOOP

        V_MIN_DATE := F_EOMONTH(V_CURRDATE, V_HISTORICAL_DATA, 'M', 'PREV');        
        V_MAX_DATE := F_EOMONTH(V_CURRDATE, V_INCREMENT_PERIOD, 'M', 'PREV');

        WHILE V_MIN_DATE <= V_MAX_DATE 
        LOOP
            EXECUTE 'INSERT INTO TMP_IFRS_PD_LIST_DATE         
            (PD_RULE_ID        
            ,LIST_DATE        
            ,REMARK)        
            SELECT ' || V_PD_RULE_ID || ' AS PD_RULE_ID        
            ,''' || CAST(V_MIN_DATE AS VARCHAR(10)) || '''::DATE AS LIST_DATE        
            ,''SP_IFRS_IMP_PD_CHR_SUMM'' AS REMARK        
            WHERE ' || V_CUT_OFF_DATE || ' <= ' || V_MIN_DATE || '';

            V_MIN_DATE := F_EOMONTH(V_MIN_DATE, V_INCREMENT_PERIOD, 'M', 'NEXT');

        END LOOP;

    END LOOP;


    V_STR_QUERY := '';
    V_STR_QUERY := V_STR_QUERY || 'TRUNCATE TABLE TMP_IFRS_PD_CHR_BASE_DATA';
    EXECUTE (V_STR_QUERY);

    V_STR_QUERY := '';
    V_STR_QUERY := V_STR_QUERY || 'SELECT A.* FROM IFRS_PD_CHR_BASE_DATA A        
    INNER JOIN TMP_IFRS_PD_LIST_DATE B ON A.PD_RULE_ID = B.PD_RULE_ID AND A.DOWNLOAD_DATE = B.LIST_DATE';
    EXECUTE (V_STR_QUERY);

    V_PD_RULE_ID := NULL;

    V_STR_QUERY := '';
    V_STR_QUERY := V_STR_QUERY || 'DELETE FROM IFRS_PD_CHR_DATA A 
    USING ' || V_TABLEPDCONFIG || ' B WHERE A.PD_RULE_ID = B.PKID 
    AND PROJECTION_DATE = ''' || CAST(V_CURRDATE AS VARCHAR(10)) || '''::DATE AND B.ACTIVE_FLAG = 1 AND B.IS_DELETE = 0';
    EXECUTE (V_STR_QUERY);

    FOR V_PD_RULE_ID, V_LIST_DATE IN
        EXECUTE 'SELECT PD_RULE_ID, LIST_DATE FROM TMP_IFRS_PD_LIST_DATE'
    LOOP

        V_STR_QUERY := '';
        V_STR_QUERY := V_STR_QUERY || 'DROP TABLE IF EXISTS BASE_' || P_RUNID || '';
        EXECUTE (V_STR_QUERY);

        V_STR_QUERY := '';
        V_STR_QUERY := V_STR_QUERY || 'CREATE TEMP TABLE BASE_' || P_RUNID || ' AS 
        SELECT * FROM TMP_IFRS_PD_CHR_BASE_DATA WHERE DOWNLOAD_DATE = ''' || CAST(V_LIST_DATE AS VARCHAR(10)) || '''::DATE AND PD_RULE_ID = ' || V_PD_RULE_ID || '';
        EXECUTE (V_STR_QUERY);

        V_STR_QUERY := '';
        V_STR_QUERY := V_STR_QUERY || 'DROP TABLE IF EXISTS NEXT_PERIOD_' || P_RUNID || '';
        EXECUTE (V_STR_QUERY);

        V_STR_QUERY := '';
        V_STR_QUERY := V_STR_QUERY || 'CREATE TEMP TABLE NEXT_PERIOD_' || P_RUNID || ' AS 
        SELECT ''' || CAST(V_CURRDATE AS VARCHAR(10)) || '''::DATE AS PROJECTION_DATE,A.PD_RULE_ID,PD_UNIQUE_ID,MAX(CASE WHEN NEXT_12M_DEFAULT_FLAG = 1 THEN 1 ELSE 0 END) AS NEXT_12M_DEFAULT_FLAG
        FROM TMP_IFRS_PD_CHR_BASE_DATA A         
        WHERE  A.PD_RULE_ID = ' || V_PD_RULE_ID || '  AND DOWNLOAD_DATE >= ''' || CAST(V_LIST_DATE AS VARCHAR(10)) || '''::DATE        
        GROUP BY A.PD_RULE_ID,PD_UNIQUE_ID';
        EXECUTE (V_STR_QUERY);

        V_STR_QUERY := '';
        V_STR_QUERY := V_STR_QUERY || 'INSERT INTO IFRS_PD_CHR_DATA (DOWNLOAD_DATE        
        ,PROJECTION_DATE        
        ,PD_RULE_ID        
        ,PD_RULE_NAME        
        ,BUCKET_GROUP        
        ,PD_UNIQUE_ID        
        ,SEGMENT        
        ,CALC_METHOD        
        ,BUCKET_ID        
        ,BUCKET_NAME        
        ,OUTSTANDING        
        ,DEFAULT_FLAG        
        ,BI_COLLECTABILITY        
        ,RATING_CODE        
        ,DAY_PAST_DUE        
        ,NEXT_12M_DEFAULT_FLAG)        
        SELECT A.DOWNLOAD_DATE        
        ,''' || CAST(V_CURRDATE AS VARCHAR(10)) || '''::DATE AS PROJECTION_DATE        
        ,A.PD_RULE_ID        
        ,A.PD_RULE_NAME        
        ,A.BUCKET_GROUP        
        ,A.PD_UNIQUE_ID        
        ,A.SEGMENT        
        ,A.CALC_METHOD        
        ,A.BUCKET_ID        
        ,CASE WHEN A.BUCKET_ID = 0 THEN ''FP'' ELSE A.BUCKET_NAME END         
        ,A.OUTSTANDING        
        ,A.DEFAULT_FLAG        
        ,A.BI_COLLECTABILITY        
        ,A.RATING_CODE        
        ,A.DAY_PAST_DUE        
        ,B.NEXT_12M_DEFAULT_FLAG 
        FROM BASE_' || P_RUNID || ' A         
        LEFT JOIN NEXT_PERIOD_' || P_RUNID || ' B ON  A.PD_RULE_ID = B.PD_RULE_ID AND A.PD_UNIQUE_ID =  B.PD_UNIQUE_ID';
        EXECUTE (V_STR_QUERY);

        GET DIAGNOSTICS V_RETURNROWS = ROW_COUNT;
        V_RETURNROWS2 := V_RETURNROWS2 + V_RETURNROWS;
        V_RETURNROWS := 0;

    END LOOP;

    V_STR_QUERY := '';
    V_STR_QUERY := V_STR_QUERY || 'DELETE FROM IFRS_PD_CHR_SUMM A
    USING ' || V_TABLEPDCONFIG || ' B WHERE A.PD_RULE_ID = B.PKID 
    AND PROJECTION_DATE = ''' || CAST(V_CURRDATE AS VARCHAR(10)) || '''::DATE AND
    B.ACTIVE_FLAG = 1 AND B.IS_DELETE = 0';
    EXECUTE (V_STR_QUERY);

    V_STR_QUERY := '';
    V_STR_QUERY := V_STR_QUERY || 'INSERT INTO IFRS_PD_CHR_SUMM (DOWNLOAD_DATE        
    ,PROJECTION_DATE        
    ,PD_RULE_ID        
    ,PD_RULE_NAME        
    ,SEGMENT        
    ,CALC_METHOD        
    ,BUCKET_GROUP        
    ,BUCKET_ID        
    ,BUCKET_NAME        
    ,SEQ_YEAR        
    ,TOTAL_COUNT        
    ,TOTAL_DEFAULT        
    ,CUMULATIVE_ODR        
    ,MARGINAL_COUNT        
    ,MARGINAL_DEFAULT_COUNT        
    ,MARGINAL_ODR        
    ,CREATEDBY        
    ,CREATEDDATE)        
    SELECT A.DOWNLOAD_DATE        
    ,''' || CAST(V_CURRDATE AS VARCHAR(10)) || '''::DATE AS PROJECTION_DATE        
    ,A.PD_RULE_ID AS PD_RULE_ID        
    ,MAX(A.PD_RULE_NAME)        
    ,MAX(A.SEGMENT)        
    ,MAX(A.CALC_METHOD)        
    ,MAX(A.BUCKET_GROUP) AS BUCKET_GROUP        
    ,A.BUCKET_ID        
    ,MAX(A.BUCKET_NAME) AS BUCKET_NAME  
    ,(EXTRACT(MONTH FROM AGE(DOWNLOAD_DATE, PROJECTION_DATE))/MAX(B.INCREMENT_PERIOD))::INT AS SEQ_YEAR
    ,COUNT(1) AS TOTAL_COUNT        
    ,SUM (CASE WHEN NEXT_12M_DEFAULT_FLAG  = 1 THEN 1 ELSE 0 END ) AS TOTAL_DEFAULT        
    ,CAST(SUM (CASE WHEN NEXT_12M_DEFAULT_FLAG  = 1 THEN 1 ELSE 0 END ) AS FLOAT)/CAST(COUNT(1) AS FLOAT)  AS CUMULATIVE_ODR        
    ,NULL AS MARGINAL_COUNT        
    ,NULL AS MARGINAL_DEFAULT_COUNT        
    ,NULL AS MARGINAL_ODR        
    ,''SYSTEM'' AS CREATEDBY        
    ,CURRENT_DATE AS CREATEDDATE        
    FROM IFRS_PD_CHR_DATA A
    INNER JOIN ' || V_TABLEPDCONFIG || ' B ON A.PD_RULE_ID = B.PKID WHERE PROJECTION_DATE = ''' || CAST(V_CURRDATE AS VARCHAR(10)) || '''::DATE        
    AND B.ACTIVE_FLAG = 1 AND B.IS_DELETE = 0
    GROUP BY A.PD_RULE_ID, A.DOWNLOAD_DATE,A.PROJECTION_DATE, A.BUCKET_ID         
    ORDER BY A.PD_RULE_ID,A.DOWNLOAD_DATE,A.PROJECTION_DATE, A.BUCKET_ID';
    EXECUTE (V_STR_QUERY);

    GET DIAGNOSTICS V_RETURNROWS = ROW_COUNT;
    V_RETURNROWS2 := V_RETURNROWS2 + V_RETURNROWS;
    V_RETURNROWS := 0;

    V_STR_QUERY := '';
    V_STR_QUERY := V_STR_QUERY || 'DROP TABLE IF EXISTS CHR_PREV_' || P_RUNID || '';
    EXECUTE (V_STR_QUERY);

    V_STR_QUERY := '';
    V_STR_QUERY := V_STR_QUERY || 'CREATE TEMP TABLE CHR_PREV_' || P_RUNID || ' AS 
    SELECT A.* FROM IFRS_PD_CHR_SUMM A 
    INNER JOIN ' || V_TABLEPDCONFIG || ' B ON A.PD_RULE_ID = B.PKID         
    WHERE PROJECTION_DATE = F_EOMONTH(''' || CAST(V_CURRDATE AS VARCHAR(10)) || '''::DATE, B.INCREMENT_PERIOD, ''M'', ''PREV'')       
    AND B.ACTIVE_FLAG = 1 AND B.IS_DELETE = 0';
    EXECUTE (V_STR_QUERY);

    V_STR_QUERY := '';
    V_STR_QUERY := V_STR_QUERY || 'UPDATE IFRS_PD_CHR_SUMM A        
    SET MARGINAL_COUNT = COALESCE(A.TOTAL_COUNT,0) - COALESCE(B.TOTAL_COUNT,0)        
    ,MARGINAL_DEFAULT_COUNT = COALESCE(A.TOTAL_DEFAULT,0) - COALESCE(B.TOTAL_DEFAULT,0)        
    ,MARGINAL_ODR =  CAST(COALESCE(A.TOTAL_DEFAULT,0) - COALESCE(B.TOTAL_DEFAULT,0) AS FLOAT)/A.TOTAL_COUNT        
    FROM  CHR_PREV_' || P_RUNID || ' AS B, ' || V_TABLEPDCONFIG || ' AS C 
    WHERE A.PD_RULE_ID = C.PKID AND A.PROJECTION_DATE = ''' || CAST(V_CURRDATE AS VARCHAR(10)) || '''::DATE        
    AND C.ACTIVE_FLAG = 1 AND C.IS_DELETE = 0
    AND A.DOWNLOAD_DATE = B.DOWNLOAD_DATE AND A.PD_RULE_ID = B.PD_RULE_ID AND A.BUCKET_ID = B.BUCKET_ID';
    EXECUTE (V_STR_QUERY);

    RAISE NOTICE 'SP_IFRS_IMP_PD_CHR_SUMM | AFFECTED RECORD : %', V_RETURNROWS2;
    -------- ====== BODY ======

    -------- ====== LOG ======
    V_TABLEDEST = 'IFRS_PD_CHR_SUMM';
    V_COLUMNDEST = '-';
    V_SPNAME = 'SP_IFRS_IMP_PD_CHR_SUMM';
    V_OPERATION = 'INSERT';
    
    CALL SP_IFRS_EXEC_AND_LOG(V_CURRDATE, V_TABLEDEST, V_COLUMNDEST, V_SPNAME, V_OPERATION, V_RETURNROWS2, P_RUNID);
    -------- ====== LOG ======

    -------- ====== RESULT ======
    V_QUERYS = 'SELECT * FROM IFRS_PD_CHR_SUMM';
    CALL SP_IFRS_RESULT_PREV(V_CURRDATE, V_QUERYS, V_SPNAME, V_RETURNROWS2, P_RUNID);
    -------- ====== RESULT ======

END;

$$;
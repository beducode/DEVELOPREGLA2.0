---- DROP PROCEDURE SP_IFRS_IMP_PD_TERM_YEARLY;

CREATE OR REPLACE PROCEDURE SP_IFRS_IMP_PD_TERM_YEARLY(
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

    ---- VARIABLE PROCESS
    V_MAX_YEAR INT;            
    V_MIN_YEAR INT;           
    V_COUNT_MIN INT = 1;             
    V_COUNT_MAX INT = 12;  

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
        V_TABLEINSERT3 := 'IFRS_IMA_IMP_PREV_' || P_RUNID || '';
        V_TABLEINSERT4 := 'IFRS_PD_TERM_STRUCTURE_NOFL_YEARLY_' || P_RUNID || '';
        V_TABLEPDCONFIG := 'IFRS_PD_RULES_CONFIG_' || P_RUNID || '';
    ELSE 
        V_TABLENAME := 'IFRS_MASTER_ACCOUNT';
        V_TABLENAME_MON := 'IFRS_MASTER_ACCOUNT_MONTHLY';
        V_TABLEINSERT1 := 'TMP_IFRS_ECL_IMA';
        V_TABLEINSERT2 := 'IFRS_IMA_IMP_CURR';
        V_TABLEINSERT3 := 'IFRS_IMA_IMP_PREV';
        V_TABLEINSERT4 := 'IFRS_PD_TERM_STRUCTURE_NOFL_YEARLY';
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
    
    V_PREVDATE := F_EOMONTH(V_CURRDATE, 1, 'D', 'PREV');
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
        V_STR_QUERY := V_STR_QUERY || 'CREATE TABLE ' || V_TABLEINSERT4 || ' AS SELECT * FROM IFRS_PD_TERM_STRUCTURE_NOFL_YEARLY WHERE 0=1';
        EXECUTE (V_STR_QUERY);
    END IF;
    -------- ====== PRE SIMULATION TABLE ======
    
    -------- ====== BODY ======

    V_STR_QUERY := '';
    V_STR_QUERY := V_STR_QUERY || 'UPDATE IFRS_MPD_CHR_RESULT_YEARLY A          
    SET CUMULATIVE_PD_RATE = 1             
    ,MARGINAL_PD_RATE = CASE WHEN SEQ_YEAR = 1 THEN 1 ELSE 0 END             
    FROM VW_IFRS_MAX_BUCKET AS B, ' || V_TABLEPDCONFIG || ' AS C 
    WHERE A.PD_RULE_ID = C.PKID AND IS_DELETE = 0 AND ACTIVE_FLAG = 1
    AND A.BUCKET_GROUP = B.BUCKET_GROUP AND A.BUCKET_ID  = B.MAX_BUCKET_ID   
    AND DOWNLOAD_DATE = (CASE WHEN LAG_1MONTH_FLAG = 1 
    THEN F_EOMONTH(''' || CAST(V_CURRDATE AS VARCHAR(10)) || '''::DATE, C.INCREMENT_PERIOD, ''M'', ''PREV'') 
    ELSE F_EOMONTH(''' || CAST(V_CURRDATE AS VARCHAR(10)) || '''::DATE, C.INCREMENT_PERIOD, ''M'', ''PREV'') END )';
    EXECUTE (V_STR_QUERY);

    V_STR_QUERY := '';
    V_STR_QUERY := V_STR_QUERY || 'DELETE FROM ' || V_TABLEINSERT4 || ' A       
    USING ' || V_TABLEPDCONFIG || ' C 
    WHERE A.PD_RULE_ID = C.PKID AND IS_DELETE = 0 AND ACTIVE_FLAG = 1      
    AND CURR_DATE  = (CASE WHEN LAG_1MONTH_FLAG = 1 THEN ''' || CAST(V_CURRDATE AS VARCHAR(10)) || '''::DATE ELSE ''' || CAST(V_CURRDATE AS VARCHAR(10)) || '''::DATE  END)';
    EXECUTE (V_STR_QUERY);

    V_STR_QUERY := '';
    V_STR_QUERY := V_STR_QUERY || 'INSERT INTO ' || V_TABLEINSERT4 || '            
    (DOWNLOAD_DATE            
    ,CURR_DATE            
    ,PD_RULE_ID            
    ,PD_RULE_NAME            
    ,BUCKET_GROUP            
    ,BUCKET_ID            
    ,BUCKET_NAME            
    ,FL_SEQ            
    ,FL_YEAR            
    ,PD_RATE            
    ,CREATEDBY            
    ,CREATEDDATE            
    )            
    SELECT DOWNLOAD_DATE            
    ,CASE WHEN LAG_1MONTH_FLAG = 1 THEN ''' || CAST(V_CURRDATE AS VARCHAR(10)) || '''::DATE ELSE ''' || CAST(V_CURRDATE AS VARCHAR(10)) || '''::DATE END AS CURR_DATE            
    ,PD_RULE_ID            
    ,PD_RULE_NAME            
    ,A.BUCKET_GROUP            
    ,A.BUCKET_ID            
    ,B.BUCKET_NAME            
    ,A.SEQ_YEAR AS FL_SEQ            
    ,A.SEQ_YEAR AS FL_YEAR            
    ,MARGINAL_PD_RATE AS PD_RATE            
    ,''SYSTEM'' AS CREATEDBY            
    ,CURRENT_DATE AS CREATEDDATE 
    FROM IFRS_MPD_CHR_RESULT_YEARLY A            
    JOIN (SELECT BUCKET_GROUP, BUCKET_ID, MAX(BUCKET_NAME) AS BUCKET_NAME FROM IFRS_BUCKET_DETAIL GROUP BY BUCKET_GROUP, BUCKET_ID) B      
    ON A.BUCKET_GROUP = B.BUCKET_GROUP               
    and A.BUCKET_ID=B.BUCKET_ID                     
    INNER JOIN ' || V_TABLEPDCONFIG || ' C ON A.PD_RULE_ID = C.PKID AND C.IS_DELETE = 0 AND C.ACTIVE_FLAG = 1        
    WHERE A.DOWNLOAD_DATE = (CASE WHEN LAG_1MONTH_FLAG = 1 
    THEN F_EOMONTH(''' || CAST(V_CURRDATE AS VARCHAR(10)) || '''::DATE, C.INCREMENT_PERIOD, ''M'', ''PREV'') 
    ELSE F_EOMONTH(''' || CAST(V_CURRDATE AS VARCHAR(10)) || '''::DATE, C.INCREMENT_PERIOD, ''M'', ''PREV'') END )';
    EXECUTE (V_STR_QUERY);

    GET DIAGNOSTICS V_RETURNROWS = ROW_COUNT;
    V_RETURNROWS2 := V_RETURNROWS2 + V_RETURNROWS;
    V_RETURNROWS := 0;

    V_STR_QUERY := '';
    V_STR_QUERY := V_STR_QUERY || 'INSERT INTO ' || V_TABLEINSERT4 || '            
    (DOWNLOAD_DATE            
    ,CURR_DATE            
    ,PD_RULE_ID            
    ,PD_RULE_NAME            
    ,BUCKET_GROUP            
    ,BUCKET_ID            
    ,BUCKET_NAME            
    ,FL_SEQ            
    ,FL_YEAR            
    ,PD_RATE            
    ,CREATEDBY            
    ,CREATEDDATE            
    )            
    SELECT DOWNLOAD_DATE            
    ,(CASE WHEN LAG_1MONTH_FLAG = 1 THEN ''' || CAST(V_CURRDATE AS VARCHAR(10)) || '''::DATE ELSE ''' || CAST(V_CURRDATE AS VARCHAR(10)) || '''::DATE   END ) AS CURR_DATE            
    ,PD_RULE_ID            
    ,PD_RULE_NAME            
    ,A.BUCKET_GROUP            
    ,A.BUCKET_ID            
    ,B.BUCKET_NAME            
    ,A.FL_SEQ AS FL_SEQ            
    ,A.FL_SEQ AS FL_YEAR            
    ,MARGINAL_PD_RATE AS PD_RATE            
    ,''SYSTEM'' AS CREATEDBY            
    ,CURRENT_DATE AS CREATEDDATE FROM IFRS_PD_MAA_RESULT A            
    JOIN (SELECT BUCKET_GROUP, BUCKET_ID, MAX(BUCKET_NAME) AS BUCKET_NAME FROM IFRS_BUCKET_DETAIL GROUP BY BUCKET_GROUP, BUCKET_ID) B      
    ON A.BUCKET_GROUP = B.BUCKET_GROUP               
    and A.BUCKET_ID=B.BUCKET_ID                     
    INNER JOIN ' || V_TABLEPDCONFIG || ' C ON A.PD_RULE_ID = C.PKID AND C.IS_DELETE = 0 AND C.ACTIVE_FLAG = 1        
    WHERE A.TO_DATE = (CASE WHEN LAG_1MONTH_FLAG = 1 THEN ''' || CAST(V_CURRDATE AS VARCHAR(10)) || '''::DATE ELSE ''' || CAST(V_CURRDATE AS VARCHAR(10)) || '''::DATE   END )';
    EXECUTE (V_STR_QUERY);

    GET DIAGNOSTICS V_RETURNROWS = ROW_COUNT;
    V_RETURNROWS2 := V_RETURNROWS2 + V_RETURNROWS;
    V_RETURNROWS := 0;

    V_STR_QUERY := '';
    V_STR_QUERY := V_STR_QUERY || 'DELETE FROM ' || V_TABLEINSERT4 || ' A
    USING ' || V_TABLEPDCONFIG || ' B 
    WHERE A.PD_RULE_ID = B.PKID
    AND A.CREATEDBY = ''NFR'' 
    AND B.ACTIVE_FLAG = 1 AND B.IS_DELETE = 0';
    EXECUTE (V_STR_QUERY);

    V_STR_QUERY := '';
    V_STR_QUERY := V_STR_QUERY || 'INSERT INTO ' || V_TABLEINSERT4 || ' (DOWNLOAD_DATE        
    ,CURR_DATE        
    ,PD_RULE_ID        
    ,PD_RULE_NAME        
    ,BUCKET_GROUP        
    ,BUCKET_ID        
    ,BUCKET_NAME        
    ,FL_SEQ        
    ,FL_YEAR        
    ,PD_RATE        
    ,CREATEDBY        
    ,CREATEDDATE        
    )        
    SELECT DOWNLOAD_DATE        
    ,A.DOWNLOAD_DATE AS CURR_DATE        
    ,A.PD_RULE_ID        
    ,A.PD_RULE_NAME        
    ,A.BUCKET_GROUP        
    ,A.BUCKET_ID        
    ,NULL AS BUCKET_NAME        
    ,1 AS FL_SEQ        
    ,1 AS FL_YEAR        
    ,A.PD_RATE        
    ,''NFR'' AS CREATEDBY        
    ,A.CREATEDDATE 
    FROM IFRS_PD_NFR_RESULT A     
    INNER JOIN ' || V_TABLEPDCONFIG || ' B ON A.PD_RULE_ID = B.PKID 
    WHERE B.ACTIVE_FLAG = 1 AND B.IS_DELETE = 0';
    EXECUTE (V_STR_QUERY);
    
    GET DIAGNOSTICS V_RETURNROWS = ROW_COUNT;
    V_RETURNROWS2 := V_RETURNROWS2 + V_RETURNROWS;
    V_RETURNROWS := 0;

    V_STR_QUERY := '';
    V_STR_QUERY := V_STR_QUERY || 'INSERT INTO ' || V_TABLEINSERT4 || '            
    (DOWNLOAD_DATE            
    ,CURR_DATE            
    ,PD_RULE_ID            
    ,PD_RULE_NAME            
    ,BUCKET_GROUP            
    ,BUCKET_ID            
    ,BUCKET_NAME            
    ,FL_SEQ            
    ,FL_YEAR            
    ,PD_RATE            
    ,CREATEDBY            
    ,CREATEDDATE            
    )            
    SELECT DOWNLOAD_DATE            
    ,TO_DATE AS CURR_DATE            
    ,PD_RULE_ID            
    ,PD_RULE_NAME            
    ,A.BUCKET_GROUP            
    ,A.BUCKET_ID            
    ,a.BUCKET_NAME            
    ,A.FL_SEQ AS FL_SEQ            
    ,A.FL_SEQ AS FL_YEAR            
    ,MARGINAL_PD_RATE AS PD_RATE            
    ,''SYSTEM'' AS CREATEDBY            
    ,CURRENT_DATE AS CREATEDDATE 
    FROM IFRS_PD_MAA_CORP_EXTRAPOLATION A            
    INNER JOIN ' || V_TABLEPDCONFIG || ' C ON A.PD_RULE_ID = C.PKID AND C.IS_DELETE = 0 AND C.ACTIVE_FLAG = 1        
    WHERE A.TO_DATE = (CASE WHEN LAG_1MONTH_FLAG = 1 THEN ''' || CAST(V_CURRDATE AS VARCHAR(10)) || '''::DATE ELSE ''' || CAST(V_CURRDATE AS VARCHAR(10)) || '''::DATE END )';
    EXECUTE (V_STR_QUERY);
    
    GET DIAGNOSTICS V_RETURNROWS = ROW_COUNT;
    V_RETURNROWS2 := V_RETURNROWS2 + V_RETURNROWS;
    V_RETURNROWS := 0;

    V_STR_QUERY := '';
    V_STR_QUERY := V_STR_QUERY || 'DROP TABLE IF EXISTS MAX_DATE_' || P_RUNID || '';
    EXECUTE (V_STR_QUERY);

    V_STR_QUERY := '';
    V_STR_QUERY := V_STR_QUERY || 'CREATE TEMP TABLE MAX_DATE_' || P_RUNID || ' AS
    SELECT SEGMENT, MAX(DOWNLOAD_DATE) AS MAX_DATE FROM IFRS_PD_EXTERNAL_TREASURY WHERE DOWNLOAD_DATE <= ''' || CAST(V_CURRDATE AS VARCHAR(10)) || '''::DATE GROUP BY SEGMENT';
    EXECUTE (V_STR_QUERY);

    V_STR_QUERY := '';
    V_STR_QUERY := V_STR_QUERY || 'DROP TABLE IF EXISTS EXT_TREASURY_' || P_RUNID || '';
    EXECUTE (V_STR_QUERY);

    V_STR_QUERY := '';
    V_STR_QUERY := V_STR_QUERY || 'CREATE TEMP TABLE EXT_TREASURY_' || P_RUNID || ' AS
    SELECT A.* FROM IFRS_PD_EXTERNAL_TREASURY A 
    INNER JOIN MAX_DATE_' || P_RUNID || ' B ON A.DOWNLOAD_DATE = B.MAX_DATE AND A.SEGMENT = B.SEGMENT';
    EXECUTE (V_STR_QUERY);

    V_STR_QUERY := '';
    V_STR_QUERY := V_STR_QUERY || 'INSERT INTO ' || V_TABLEINSERT4 || '           
    (DOWNLOAD_DATE            
    ,CURR_DATE            
    ,PD_RULE_ID            
    ,PD_RULE_NAME            
    ,BUCKET_GROUP            
    ,BUCKET_ID            
    ,BUCKET_NAME            
    ,FL_SEQ            
    ,FL_YEAR            
    ,PD_RATE            
    ,CREATEDBY            
    ,CREATEDDATE            
    )            
    SELECT ''' || CAST(V_CURRDATE AS VARCHAR(10)) || '''::DATE AS DOWNLOAD_DATE            
    ,''' || CAST(V_CURRDATE AS VARCHAR(10)) || '''::DATE AS CURR_DATE            
    ,C.PKID AS PD_RULE_ID            
    ,C.TM_RULE_NAME AS PD_RULE_NAME            
    ,C.BUCKET_GROUP            
    ,D.BUCKET_ID            
    ,D.BUCKET_NAME            
    ,A.REMAINING_TENOR_YEAR AS FL_SEQ            
    ,A.REMAINING_TENOR_YEAR AS FL_YEAR            
    ,A.MARGINAL_PD AS PD_RATE            
    ,''EXTERNAL_TREASURY'' AS CREATEDBY            
    ,CURRENT_DATE AS CREATEDDATE 
    FROM EXT_TREASURY_' || P_RUNID || ' A     
    INNER JOIN IFRS_MSTR_SEGMENT_RULES_HEADER B ON A.SEGMENT  = B.SEGMENT AND B.IS_DELETE = 0  AND B.SEGMENT_TYPE = ''PD_SEGMENT''       
    INNER JOIN ' || V_TABLEPDCONFIG || ' C ON B.PKID = C.SEGMENTATION_ID AND C.IS_DELETE = 0  AND PD_METHOD = ''EXT'' AND C.ACTIVE_FLAG = 1 
    INNER JOIN (SELECT DISTINCT BUCKET_GROUP,BUCKET_ID, BUCKET_NAME FROM IFRS_BUCKET_DETAIL WHERE IS_DELETE = 0 AND ACTIVE_FLAG = 1) D   
    ON C.BUCKET_GROUP = D.BUCKET_GROUP AND A.RATING_CODE = D.BUCKET_NAME';
    EXECUTE (V_STR_QUERY);

    GET DIAGNOSTICS V_RETURNROWS = ROW_COUNT;
    V_RETURNROWS2 := V_RETURNROWS2 + V_RETURNROWS;
    V_RETURNROWS := 0;

    RAISE NOTICE 'SP_IFRS_IMP_PD_TERM_YEARLY | AFFECTED RECORD : %', V_RETURNROWS2;
    -------- ====== BODY ======

    -------- ====== LOG ======
    V_TABLEDEST = V_TABLEINSERT4;
    V_COLUMNDEST = '-';
    V_SPNAME = 'SP_IFRS_IMP_PD_TERM_YEARLY';
    V_OPERATION = 'INSERT';
    
    CALL SP_IFRS_EXEC_AND_LOG(V_CURRDATE, V_TABLEDEST, V_COLUMNDEST, V_SPNAME, V_OPERATION, V_RETURNROWS2, P_RUNID);
    -------- ====== LOG ======

    -------- ====== RESULT ======
    V_QUERYS = 'SELECT * FROM ' || V_TABLEINSERT4 || '';
    CALL SP_IFRS_RESULT_PREV(V_CURRDATE, V_QUERYS, V_SPNAME, V_RETURNROWS2, P_RUNID);
    -------- ====== RESULT ======

END;

$$;
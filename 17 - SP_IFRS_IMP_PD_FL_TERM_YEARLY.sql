---- DROP PROCEDURE SP_IFRS_IMP_PD_FL_TERM_YEARLY;

CREATE OR REPLACE PROCEDURE SP_IFRS_IMP_PD_FL_TERM_YEARLY(
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
        V_TABLENAME := 'TMP_IMA_' || P_RUNID || '';
        V_TABLENAME_MON := 'TMP_IMAM_' || P_RUNID || '';
        V_TABLEINSERT1 := 'TMP_IFRS_ECL_IMA_' || P_RUNID || '';
        V_TABLEINSERT2 := 'IFRS_IMA_IMP_CURR_' || P_RUNID || '';
        V_TABLEINSERT3 := 'IFRS_IMA_IMP_PREV_' || P_RUNID || '';
        V_TABLEINSERT4 := 'IFRS_IMP_PD_FL_TERM_YEARLY_' || P_RUNID || '';
    ELSE 
        V_TABLENAME := 'IFRS_MASTER_ACCOUNT';
        V_TABLENAME_MON := 'IFRS_MASTER_ACCOUNT_MONTHLY';
        V_TABLEINSERT1 := 'TMP_IFRS_ECL_IMA';
        V_TABLEINSERT2 := 'IFRS_IMA_IMP_CURR';
        V_TABLEINSERT3 := 'IFRS_IMA_IMP_PREV';
        V_TABLEINSERT4 := 'IFRS_IMP_PD_FL_TERM_YEARLY';
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
        V_STR_QUERY := '';
        V_STR_QUERY := V_STR_QUERY || 'DROP TABLE IF EXISTS ' || V_TABLEINSERT4 || ' ';
        EXECUTE (V_STR_QUERY);

        V_STR_QUERY := '';
        V_STR_QUERY := V_STR_QUERY || 'CREATE TABLE ' || V_TABLEINSERT4 || ' AS SELECT * FROM IFRS_IMP_PD_FL_TERM_YEARLY WHERE 0=1';
        EXECUTE (V_STR_QUERY);
    END IF;
    -------- ====== PRE SIMULATION TABLE ======
    
    -------- ====== BODY ======
    V_STR_QUERY := '';
    V_STR_QUERY := V_STR_QUERY || 'DELETE FROM ' || V_TABLEINSERT4 || ' A 
    USING IFRS_PD_RULES_CONFIG B WHERE A.PD_RULE_ID = B.PKID
    AND DOWNLOAD_DATE = ''' || CAST(V_CURRDATE AS VARCHAR(10)) || '''::DATE
    AND B.ACTIVE_FLAG = 1 AND B.IS_DELETE = 0';
    EXECUTE (V_STR_QUERY);

    V_STR_QUERY := '';
    V_STR_QUERY := V_STR_QUERY || 'INSERT INTO ' || V_TABLEINSERT4 || '
    (
    DOWNLOAD_DATE
    ,PD_EFFECTIVE_DATE
    ,SCALAR_EFFECTIVE_DATE
    ,ECL_MODEL_ID
    ,SEGMENTATION_ID
    ,PD_RULE_ID
    ,PD_RULE_NAME
    ,ME_MODEL_ID
    ,BUCKET_GROUP
    ,BUCKET_ID
    ,BUCKET_NAME
    ,FL_SEQ
    ,FL_YEAR
    ,PD_RATE
    ,SCALAR
    ,PD_FINAL
    ,CREATEDBY
    ,CREATEDDATE
    ,PD_SCALAR
    ,CUMULATIVE_PD_SCALAR
    )
    SELECT ''' || CAST(V_CURRDATE AS VARCHAR(10)) || '''::DATE AS DOWNLOAD_DATE
    ,B.EFF_DATE AS PD_EFFECTIVE_DATE
    ,B.SCALAR_EFF_DATE
    ,B.ECL_MODEL_ID
    ,B.SEGMENTATION_ID AS SEGMENTATION_ID
    ,PD_RULE_ID
    ,PD_RULE_NAME
    ,ME_MODEL_ID
    ,C.BUCKET_GROUP
    ,BUCKET_ID
    ,BUCKET_NAME
    ,FL_SEQ
    ,C.FL_YEAR
    ,PD_RATE
    ,COALESCE(D.SCALAR_FINAL,1)
    ,NULL AS PD_FINAL
    ,''SYSTEM'' AS CREATEDBY
    ,CURRENT_DATE AS CREATEDDATE
    ,CASE WHEN E.BUCKET_GROUP IS NOT NULL AND FL_SEQ = 1 THEN 1 
    WHEN PD_RATE* COALESCE(D.SCALAR_FINAL,1) > 1 THEN 1 
    ELSE PD_RATE* COALESCE(D.SCALAR_FINAL,1) END AS PD_FINAL
    ,NULL AS CUMULATIVE_PD_SCALAR
    FROM IFRS_ECL_MODEL_HEADER A 
    INNER JOIN IFRS_ECL_MODEL_DETAIL_PD B ON A.PKID = B.ECL_MODEL_ID 
    INNER JOIN IFRS_PD_TERM_STRUCTURE_NOFL_YEARLY C ON B.PD_MODEL_ID = C.PD_RULE_ID AND B.EFF_DATE = C.DOWNLOAD_DATE
    LEFT JOIN IFRS_ME_FL_SCALAR_RESULT D ON B.ME_MODEL_ID = D.MODEL_ID AND B.SCALAR_EFF_DATE = D.PERIOD_DATE AND C.FL_YEAR = D.FL_YEAR
    LEFT JOIN VW_IFRS_MAX_BUCKET E ON C.BUCKET_GROUP = E.BUCKET_GROUP AND C.BUCKET_ID = E.MAX_BUCKET_ID
    WHERE  A.IS_DELETE = 0 AND A.ACTIVE_STATUS::INT = 1';
    EXECUTE (V_STR_QUERY);

    GET DIAGNOSTICS V_RETURNROWS = ROW_COUNT;
    V_RETURNROWS2 := V_RETURNROWS2 + V_RETURNROWS;
    V_RETURNROWS := 0;

    V_STR_QUERY := '';
    V_STR_QUERY := V_STR_QUERY || 'DROP TABLE IF EXISTS CUMMULATIVE_PD_' || P_RUNID || '';
    EXECUTE (V_STR_QUERY);

    V_STR_QUERY := '';
    V_STR_QUERY := V_STR_QUERY || 'CREATE TEMP TABLE CUMMULATIVE_PD_' || P_RUNID || ' AS 
    SELECT *, 
    CASE WHEN SUM(PD_SCALAR) OVER (PARTITION BY DOWNLOAD_DATE,ECL_MODEL_ID, PD_RULE_ID,BUCKET_ID,SEGMENTATION_ID ORDER BY FL_SEQ)  > 1 THEN CAST( 1 AS FLOAT) 
    ELSE CAST(SUM(PD_SCALAR) OVER (PARTITION BY DOWNLOAD_DATE,ECL_MODEL_ID, PD_RULE_ID,BUCKET_ID,SEGMENTATION_ID ORDER BY FL_SEQ) AS FLOAT) END  AS CUMULATIVE_PD_SCALAR2
    FROM ' || V_TABLEINSERT4 || ' WHERE DOWNLOAD_DATE = ''' || CAST(V_CURRDATE AS VARCHAR(10)) || '''::DATE';
    EXECUTE (V_STR_QUERY);

    V_STR_QUERY := '';
    V_STR_QUERY := V_STR_QUERY || 'DROP TABLE IF EXISTS PD_FINAL_' || P_RUNID || '';
    EXECUTE (V_STR_QUERY);

    V_STR_QUERY := '';
    V_STR_QUERY := V_STR_QUERY || 'CREATE TEMP TABLE PD_FINAL_' || P_RUNID || ' AS 
    SELECT *,
    CAST(COALESCE(CUMULATIVE_PD_SCALAR2,0) AS FLOAT) - CAST(COALESCE(LAG(CUMULATIVE_PD_SCALAR2) OVER (PARTITION BY DOWNLOAD_DATE,ECL_MODEL_ID, PD_RULE_ID,BUCKET_ID,SEGMENTATION_ID ORDER BY FL_SEQ),0) AS FLOAT) AS PD_FINAL2
    FROM CUMMULATIVE_PD_' || P_RUNID || '
    WHERE DOWNLOAD_DATE = ''' || CAST(V_CURRDATE AS VARCHAR(10)) || '''::DATE';
    EXECUTE (V_STR_QUERY);
 
    V_STR_QUERY := '';
    V_STR_QUERY := V_STR_QUERY || 'UPDATE ' || V_TABLEINSERT4 || ' A
    SET  PD_FINAL = B.PD_FINAL2
    ,CUMULATIVE_PD_SCALAR = B.CUMULATIVE_PD_SCALAR2
    FROM PD_FINAL_' || P_RUNID || ' AS B, IFRS_PD_RULES_CONFIG AS C 
    WHERE A.PD_RULE_ID = C.PKID
    AND A.ECL_MODEL_ID = B.ECL_MODEL_ID AND A.SEGMENTATION_ID = B.SEGMENTATION_ID AND A.PD_RULE_ID = B.PD_RULE_ID 
    AND A.BUCKET_ID = B.BUCKET_ID AND A.FL_SEQ = B.FL_SEQ
    AND A.DOWNLOAD_DATE = ''' || CAST(V_CURRDATE AS VARCHAR(10)) || '''::DATE
    AND C.ACTIVE_FLAG = 1 AND C.IS_DELETE = 0';
    EXECUTE (V_STR_QUERY);

    RAISE NOTICE 'SP_IFRS_IMP_PD_FL_TERM_YEARLY | AFFECTED RECORD : %', V_RETURNROWS2;
    -------- ====== BODY ======

    -------- ====== LOG ======
    V_TABLEDEST = V_TABLEINSERT4;
    V_COLUMNDEST = '-';
    V_SPNAME = 'SP_IFRS_IMP_PD_FL_TERM_YEARLY';
    V_OPERATION = 'INSERT';
    
    CALL SP_IFRS_EXEC_AND_LOG(V_CURRDATE, V_TABLEDEST, V_COLUMNDEST, V_SPNAME, V_OPERATION, V_RETURNROWS2, P_RUNID);
    -------- ====== LOG ======

    -------- ====== RESULT ======
    V_QUERYS = 'SELECT * FROM ' || V_TABLEINSERT4 || '';
    CALL SP_IFRS_RESULT_PREV(V_CURRDATE, V_QUERYS, V_SPNAME, V_RETURNROWS2, P_RUNID);
    -------- ====== RESULT ======

END;

$$;
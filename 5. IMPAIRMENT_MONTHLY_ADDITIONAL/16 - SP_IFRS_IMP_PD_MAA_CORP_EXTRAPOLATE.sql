---- DROP PROCEDURE SP_IFRS_IMP_PD_MAA_CORP_EXTRAPOLATE;

CREATE OR REPLACE PROCEDURE SP_IFRS_IMP_PD_MAA_CORP_EXTRAPOLATE(
    IN P_RUNID VARCHAR(20) DEFAULT 'S_00000_0000',
    IN P_DOWNLOAD_DATE DATE DEFAULT NULL,
    IN P_PRC VARCHAR(1) DEFAULT 'S')
LANGUAGE PLPGSQL AS $$
DECLARE
    ---- DATE
    V_PREVDATE DATE;
    V_CURRDATE DATE;
    V_LASTYEAR DATE;
    V_CURRMONTH DATE;
    V_LASTYEARNEXTMONTH DATE;
    
    V_PREVDATE_NOLAG DATE;
    V_CURRDATE_NOLAG DATE;

    ---- QUERY   
    V_STR_QUERY TEXT;

    ---- TABLE LIST       
    V_TABLENAME VARCHAR(100);
    V_TABLEINSERT1 VARCHAR(100);
    V_TABLEINSERT2 VARCHAR(100);
    
    ---- VARIABLE PROCESS
    V_SEGMENT RECORD;
    V_MIN_SEQ INT;
    V_MAX_SEQ INT;
    
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
        V_TABLEINSERT1 := 'IFRS_PD_MAA_CORP_MMULT_' || P_RUNID || '';
        V_TABLEINSERT2 := 'IFRS_PD_MAA_CORP_EXTRAPOLATION_' || P_RUNID || '';
    ELSE 
        V_TABLENAME := 'IFRS_MASTER_ACCOUNT';
        V_TABLEINSERT1 := 'IFRS_PD_MAA_CORP_MMULT';
        V_TABLEINSERT2 := 'IFRS_PD_MAA_CORP_EXTRAPOLATION';
    END IF;
    
    IF P_DOWNLOAD_DATE IS NULL 
    THEN
        SELECT F_EOMONTH(CURRDATE, 1, 'M', 'PREV') INTO V_CURRDATE
        FROM IFRS_PRC_DATE;
        
        SELECT F_EOMONTH(CURRDATE, 0, 'M', 'PREV') INTO V_CURRDATE_NOLAG
        FROM IFRS_PRC_DATE;
    ELSE        
        V_CURRDATE := F_EOMONTH(P_DOWNLOAD_DATE, 1, 'M', 'PREV');
        V_CURRDATE_NOLAG := F_EOMONTH(P_DOWNLOAD_DATE, 0, 'M', 'PREV');
        V_PREVDATE := V_CURRDATE - INTERVAL '1 DAY';
        V_PREVDATE_NOLAG := V_CURRDATE_NOLAG - INTERVAL '1 DAY';
    END IF;

    V_CURRMONTH := F_EOMONTH(V_CURRDATE, 0, 'M', 'NEXT');
    V_LASTYEAR := F_EOMONTH(V_CURRDATE, 1, 'Y', 'PREV');
    V_LASTYEARNEXTMONTH := F_EOMONTH(V_LASTYEAR, 1, 'M', 'NEXT');

    V_RETURNROWS2 := 0;
    -------- ====== VARIABLE ======

    -------- ====== PRE SIMULATION TABLE ======
    IF P_PRC = 'S' THEN 
        V_STR_QUERY := '';
        V_STR_QUERY := V_STR_QUERY || 'DROP TABLE IF EXISTS ' || V_TABLEINSERT2 || ' ';
        EXECUTE (V_STR_QUERY);

        V_STR_QUERY := '';
        V_STR_QUERY := V_STR_QUERY || 'CREATE TABLE ' || V_TABLEINSERT2 || ' AS SELECT * FROM IFRS_PD_MAA_CORP_EXTRAPOLATION WHERE 1=0 ';
        EXECUTE (V_STR_QUERY);
    END IF;
    -------- ====== PRE SIMULATION TABLE ======

    -------- ====== BODY ======
    V_STR_QUERY := '';
    V_STR_QUERY := V_STR_QUERY || 'DROP TABLE IF EXISTS ' || 'TMP_MMULT_MAX_BUCKET' || '';
    EXECUTE (V_STR_QUERY);

    V_STR_QUERY := '';
    V_STR_QUERY := V_STR_QUERY || 'CREATE TEMP TABLE ' || 'TMP_MMULT_MAX_BUCKET' || ' AS 
        SELECT A.* FROM (
            SELECT * FROM ' || V_TABLEINSERT1 || ' 
            WHERE TO_DATE = ''' || CAST(V_CURRDATE_NOLAG AS VARCHAR(10)) || '''::DATE 
        ) A 
        WHERE TO_DATE = ''' || CAST(V_CURRDATE_NOLAG AS VARCHAR(10)) || '''::DATE ';
    EXECUTE (V_STR_QUERY);

    V_STR_QUERY := '';
    V_STR_QUERY := V_STR_QUERY || 'DELETE FROM ' || V_TABLEINSERT2 || ' A 
        USING ' || 'IFRS_PD_RULES_CONFIG' || ' B 
        WHERE A.PD_RULE_ID = B.PKID
        AND TO_DATE = ''' || CAST(V_CURRDATE_NOLAG AS VARCHAR(10)) || '''::DATE
        AND B.ACTIVE_FLAG = 1 AND B.IS_DELETE = 0 ';
    EXECUTE (V_STR_QUERY);

    V_STR_QUERY := '';
    V_STR_QUERY := V_STR_QUERY || 'INSERT INTO ' || V_TABLEINSERT2 || ' 
        (
            DOWNLOAD_DATE  
            ,TO_DATE  
            ,PD_RULE_ID  
            ,PD_RULE_NAME  
            ,BUCKET_GROUP  
            ,BUCKET_ID  
            ,BUCKET_NAME  
            ,FL_SEQ  
            ,CUMULATIVE_PD_RATE  
            ,MARGINAL_PD_RATE
        )  
        SELECT
            F_EOMONTH(CAST(''' || CAST(V_CURRDATE_NOLAG AS VARCHAR(10)) || '''::DATE - (A.INCREMENT_PERIOD * INTERVAL ''1 MONTH'') AS DATE), 0, ''M'', ''NEXT'') AS  DOWNLOAD_DATE  
            ,''' || CAST(V_CURRDATE_NOLAG AS VARCHAR(10)) || '''::DATE AS TO_DATE  
            ,A.PKID AS PD_RULE_ID  
            ,A.TM_RULE_NAME AS PD_RULE_NAME  
            ,A.BUCKET_GROUP2 AS BUCKET_GROUP  
            ,B.BUCKET_ID AS BUCKET_ID  
            ,B.BUCKET_NAME AS BUCKET_NAME  
            ,C.FL_SEQ  
            ,CASE WHEN D.MAX_BUCKET_ID IS NOT NULL THEN 1 ELSE NULL END  AS CUMULATIVE_PD_RATE  
            ,NULL AS MARGINAL_PD_RATE  
        FROM ' || 'IFRS_PD_RULES_CONFIG' || ' A  
        JOIN (
            SELECT BUCKET_GROUP, BUCKET_ID, BUCKET_NAME 
            FROM ' || 'IFRS_BUCKET_DETAIL' || ' 
            GROUP BY BUCKET_GROUP, BUCKET_ID, BUCKET_NAME
        ) B 
            ON A.BUCKET_GROUP2 = B.BUCKET_GROUP   
        JOIN (
            SELECT PD_RULE_ID, FL_SEQ 
            FROM (
                SELECT * FROM ' || V_TABLEINSERT1 || ' 
                WHERE TO_DATE = ''' || CAST(V_CURRDATE_NOLAG AS VARCHAR(10)) || '''::DATE 
            ) A 
            GROUP BY PD_RULE_ID, FL_SEQ
        ) C 
            ON A.PKID = C.PD_RULE_ID  
        LEFT JOIN ' || 'VW_IFRS_MAX_BUCKET' || ' D 
            ON A.BUCKET_GROUP2  = D.BUCKET_GROUP 
            AND B.BUCKET_ID = D.MAX_BUCKET_ID  
        WHERE A.IS_DELETE = 0 
            AND A.ACTIVE_FLAG = 1 
            AND A.PD_METHOD = ''MAA_CORP'' ';
    EXECUTE (V_STR_QUERY);

    GET DIAGNOSTICS V_RETURNROWS = ROW_COUNT;
    V_RETURNROWS2 := V_RETURNROWS2 + V_RETURNROWS;
    V_RETURNROWS := 0;

    V_STR_QUERY := '';
    V_STR_QUERY := V_STR_QUERY || 'DROP TABLE IF EXISTS ' || 'TMP_EXTRAPOL' || '';
    EXECUTE (V_STR_QUERY);

    V_STR_QUERY := '';
    V_STR_QUERY := V_STR_QUERY || 'CREATE TEMP TABLE ' || 'TMP_EXTRAPOL' || ' AS 
        SELECT * FROM ' || V_TABLEINSERT2 || ' 
        WHERE TO_DATE = ''' || CAST(V_CURRDATE_NOLAG AS VARCHAR(10)) || '''::DATE ';
    EXECUTE (V_STR_QUERY);

    V_STR_QUERY := '';
    V_STR_QUERY := V_STR_QUERY || 'DROP TABLE IF EXISTS ' || 'TMP_GROUP_BUCKET' || '';
    EXECUTE (V_STR_QUERY);

    V_STR_QUERY := '';
    V_STR_QUERY := V_STR_QUERY || 'CREATE TEMP TABLE ' || 'TMP_GROUP_BUCKET' || ' AS 
        SELECT 
            *
            ,LEFT(BUCKET_NAME,1) AS GROUP_BUCKET
            ,RANK() OVER ( PARTITION BY PD_RULE_ID,BUCKET_GROUP,LEFT(BUCKET_NAME,1) ORDER BY BUCKET_NAME ) AS RANK
        FROM (  
            SELECT TO_DATE, PD_RULE_ID, A.BUCKET_GROUP, BUCKET_ID, BUCKET_NAME 
            FROM ' || 'TMP_EXTRAPOL' || ' A  
            JOIN ' || 'VW_IFRS_MAX_BUCKET' || ' B 
                ON A.BUCKET_GROUP = B.BUCKET_GROUP 
                AND A.BUCKET_ID <> B.MAX_BUCKET_ID  
            WHERE TO_DATE = ''' || CAST(V_CURRDATE_NOLAG AS VARCHAR(10)) || '''::DATE 
            GROUP BY TO_DATE,PD_RULE_ID,A.BUCKET_GROUP, BUCKET_ID, BUCKET_NAME 
        ) A ';
    EXECUTE (V_STR_QUERY);

    V_STR_QUERY := '';
    V_STR_QUERY := V_STR_QUERY || 'DROP TABLE IF EXISTS ' || 'TMP_COUNT_BUCKET' || '';
    EXECUTE (V_STR_QUERY);

    V_STR_QUERY := '';
    V_STR_QUERY := V_STR_QUERY || 'CREATE TEMP TABLE ' || 'TMP_COUNT_BUCKET' || ' AS 
        SELECT TO_DATE, PD_RULE_ID, BUCKET_GROUP, GROUP_BUCKET, COUNT(1) AS MAX_RANK 
        FROM ' || 'TMP_GROUP_BUCKET' || ' 
        GROUP BY TO_DATE, PD_RULE_ID, BUCKET_GROUP, GROUP_BUCKET ';
    EXECUTE (V_STR_QUERY);

    V_STR_QUERY := '';
    V_STR_QUERY := V_STR_QUERY || 'UPDATE ' || 'TMP_EXTRAPOL' || ' 
        SET CUMULATIVE_PD_RATE = CASE   
            WHEN C.MAX_RANK = 3 
            THEN COALESCE(D.MMULT,0)+((COALESCE(B.MMULT,0) - COALESCE(D.MMULT,0))/3*2 )  
            ELSE (B.MMULT + D.MMULT)/2 
        END   
        FROM ' || 'TMP_EXTRAPOL' || ' A  
        JOIN ' || 'TMP_MMULT_MAX_BUCKET' || ' B 
            ON A.PD_RULE_ID = B.PD_RULE_ID 
            AND A.TO_DATE = B.TO_DATE 
            AND A.FL_SEQ = B.FL_SEQ 
            AND CAST(LEFT(A.BUCKET_NAME,1) AS INT) = B.BUCKET_FROM  
        JOIN ' || 'TMP_MMULT_MAX_BUCKET' || ' D 
            ON A.PD_RULE_ID = D.PD_RULE_ID 
            AND A.TO_DATE = D.TO_DATE 
            AND A.FL_SEQ = D.FL_SEQ 
            AND CAST(LEFT(A.BUCKET_NAME,1) AS INT) = D.BUCKET_FROM + 1   
        JOIN ' || 'TMP_COUNT_BUCKET' || ' C 
             ON  A.PD_RULE_ID = C.PD_RULE_ID 
             AND A.BUCKET_GROUP = C.BUCKET_GROUP  
             AND CAST(LEFT(A.BUCKET_NAME,1) AS INT) = CAST(GROUP_BUCKET AS INT) + 1  
        WHERE A.TO_DATE = ''' || CAST(V_CURRDATE_NOLAG AS VARCHAR(10)) || '''::DATE 
            AND SUBSTRING(A.BUCKET_NAME,2,1) IN (''A'') 
            AND A.BUCKET_ID <> 1 ';
    EXECUTE (V_STR_QUERY);

    V_STR_QUERY := '';
    V_STR_QUERY := V_STR_QUERY || 'UPDATE ' || 'TMP_EXTRAPOL' || ' 
        SET CUMULATIVE_PD_RATE =  CASE   
            WHEN C.MAX_RANK = 3 
            THEN COALESCE(B.MMULT,0)+((COALESCE(D.MMULT,0) - COALESCE(B.MMULT,0))/3*1)  
            ELSE (B.MMULT + D.MMULT)/2 
        END   
        FROM ' || 'TMP_EXTRAPOL' || ' A  
        JOIN ' || 'TMP_MMULT_MAX_BUCKET' || ' B 
            ON A.PD_RULE_ID = B.PD_RULE_ID 
            AND A.TO_DATE = B.TO_DATE 
            AND A.FL_SEQ = B.FL_SEQ 
            AND CAST(LEFT(A.BUCKET_NAME,1) AS INT) = B.BUCKET_FROM  
        JOIN ' || 'TMP_MMULT_MAX_BUCKET' || ' D 
            ON A.PD_RULE_ID = D.PD_RULE_ID 
            AND A.TO_DATE = D.TO_DATE 
            AND A.FL_SEQ = D.FL_SEQ 
            AND CAST(LEFT(A.BUCKET_NAME,1) AS INT) = D.BUCKET_FROM - 1   
        JOIN ' || 'TMP_COUNT_BUCKET' || ' C  
            ON  A.PD_RULE_ID = C.PD_RULE_ID 
            AND A.BUCKET_GROUP = C.BUCKET_GROUP  
            AND CAST(LEFT(A.BUCKET_NAME,1) AS INT) = CAST(GROUP_BUCKET AS INT) - 1  
        WHERE A.TO_DATE = ''' || CAST(V_CURRDATE_NOLAG AS VARCHAR(10)) || '''::DATE 
            AND SUBSTRING(A.BUCKET_NAME,2,1) IN (''C'') ';
    EXECUTE (V_STR_QUERY);

    V_STR_QUERY := '';
    V_STR_QUERY := V_STR_QUERY || 'UPDATE ' || 'TMP_EXTRAPOL' || ' A 
        SET CUMULATIVE_PD_RATE = 0.0003  
        WHERE TO_DATE = ''' || CAST(V_CURRDATE_NOLAG AS VARCHAR(10)) || '''::DATE 
        AND BUCKET_ID = 1 ';
    EXECUTE (V_STR_QUERY);

    V_STR_QUERY := '';
    V_STR_QUERY := V_STR_QUERY || 'UPDATE ' || 'TMP_EXTRAPOL' || ' A 
        SET CUMULATIVE_PD_RATE = B.MMULT  
        FROM ' || 'TMP_MMULT_MAX_BUCKET' || ' B 
        WHERE A.PD_RULE_ID = B.PD_RULE_ID 
            AND A.TO_DATE = B.TO_DATE 
            AND A.FL_SEQ = B.FL_SEQ 
            AND CAST(LEFT(A.BUCKET_NAME,1) AS INT) = B.BUCKET_FROM  
            AND A.TO_DATE = ''' || CAST(V_CURRDATE_NOLAG AS VARCHAR(10)) || '''::DATE 
            AND SUBSTRING(A.BUCKET_NAME,2,1) IN ('''',''B'') ';
    EXECUTE (V_STR_QUERY);

    V_STR_QUERY := '';
    V_STR_QUERY := V_STR_QUERY || 'UPDATE ' || 'TMP_EXTRAPOL' || ' A 
        SET CUMULATIVE_PD_RATE = B.MMULT  
        FROM ' || 'TMP_MMULT_MAX_BUCKET' || ' B 
        WHERE A.PD_RULE_ID = B.PD_RULE_ID 
            AND A.TO_DATE = B.TO_DATE 
            AND A.FL_SEQ = B.FL_SEQ 
            AND CAST(LEFT(A.BUCKET_NAME,1) AS INT) = B.BUCKET_FROM  
            AND A.TO_DATE = ''' || CAST(V_CURRDATE_NOLAG AS VARCHAR(10)) || '''::DATE 
            AND  SUBSTRING(A.BUCKET_NAME,2,1) IN ('''',''B'') ';
    EXECUTE (V_STR_QUERY);

    V_STR_QUERY := '';
    V_STR_QUERY := V_STR_QUERY || 'UPDATE ' || V_TABLEINSERT2 || ' A 
        SET CUMULATIVE_PD_RATE = B.CUMULATIVE_PD_RATE  
        FROM ' || 'TMP_EXTRAPOL' || ' B 
        WHERE A.PD_RULE_ID = B.PD_RULE_ID 
            AND A.TO_DATE = B.TO_DATE 
            AND A.FL_SEQ = B.FL_SEQ 
            AND A.BUCKET_ID = B.BUCKET_ID   
            AND A.TO_DATE = ''' || CAST(V_CURRDATE_NOLAG AS VARCHAR(10)) || '''::DATE ';
    EXECUTE (V_STR_QUERY);

    V_STR_QUERY := '';
    V_STR_QUERY := V_STR_QUERY || 'UPDATE ' || V_TABLEINSERT2 || ' A 
        SET MARGINAL_PD_RATE = COALESCE(A.CUMULATIVE_PD_RATE,0) - COALESCE(B.CUMULATIVE_PD_RATE,0)  
        FROM ' || 'TMP_EXTRAPOL' || ' B 
        WHERE A.PD_RULE_ID = B.PD_RULE_ID 
            AND A.TO_DATE = A.TO_DATE 
            AND A.BUCKET_ID  = B.BUCKET_ID 
            AND A.FL_SEQ = B.FL_SEQ+1   
            AND A.TO_DATE = ''' || CAST(V_CURRDATE_NOLAG AS VARCHAR(10)) || '''::DATE ';
    EXECUTE (V_STR_QUERY);

    RAISE NOTICE 'SP_IFRS_IMP_PD_MAA_CORP_EXTRAPOLATE | AFFECTED RECORD : %', V_RETURNROWS2;
    ---------- ====== BODY ======

    -------- ====== LOG ======
    V_TABLEDEST = V_TABLEINSERT2;
    V_COLUMNDEST = '-';
    V_SPNAME = 'SP_IFRS_IMP_PD_MAA_CORP_EXTRAPOLATE';
    V_OPERATION = 'INSERT';
    
    CALL SP_IFRS_EXEC_AND_LOG(V_CURRDATE, V_TABLEDEST, V_COLUMNDEST, V_SPNAME, V_OPERATION, V_RETURNROWS2, P_RUNID);
    -------- ====== LOG ======

    -------- ====== RESULT ======
    V_QUERYS = 'SELECT * FROM ' || V_TABLEINSERT2 || '';
    CALL SP_IFRS_RESULT_PREV(V_CURRDATE, V_QUERYS, V_SPNAME, V_RETURNROWS2, P_RUNID);
    -------- ====== RESULT ======

END;

$$;
---- DROP PROCEDURE SP_IFRS_IMP_PD_NFR_RESULT;

CREATE OR REPLACE PROCEDURE SP_IFRS_IMP_PD_NFR_RESULT(
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
    V_TABLEINSERT3 VARCHAR(100);
    
    ---- VARIABLE PROCESS
    V_SEGMENT RECORD;
    
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
        V_TABLEINSERT1 := 'IFRS_PD_NFR_RESULT_' || P_RUNID || '';
        V_TABLEINSERT2 := 'IFRS_PD_NFR_FLOWRATE_' || P_RUNID || '';
        V_TABLEINSERT3 := 'IFRS_PD_NFR_FLOWTOLOSS_' || P_RUNID || '';
    ELSE 
        V_TABLENAME := 'IFRS_MASTER_ACCOUNT';
        V_TABLEINSERT1 := 'IFRS_PD_NFR_RESULT';
        V_TABLEINSERT2 := 'IFRS_PD_NFR_FLOWRATE';
        V_TABLEINSERT3 := 'IFRS_PD_NFR_FLOWTOLOSS';
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
        V_STR_QUERY := V_STR_QUERY || 'DROP TABLE IF EXISTS ' || V_TABLEINSERT1 || ' ';
        EXECUTE (V_STR_QUERY);

        V_STR_QUERY := '';
        V_STR_QUERY := V_STR_QUERY || 'CREATE TABLE ' || V_TABLEINSERT1 || ' AS SELECT * FROM IFRS_PD_NFR_RESULT WHERE 1=0 ';
        EXECUTE (V_STR_QUERY);
    END IF;
    -------- ====== PRE SIMULATION TABLE ======

    -------- ====== BODY ======
    V_STR_QUERY := '';
    V_STR_QUERY := V_STR_QUERY || 'DELETE FROM ' || V_TABLEINSERT1 || ' 
        WHERE DOWNLOAD_DATE = ''' || CAST(V_CURRDATE AS VARCHAR(10)) || '''::DATE ';
    EXECUTE (V_STR_QUERY);

    V_STR_QUERY := '';
    V_STR_QUERY := V_STR_QUERY || 'INSERT INTO ' || V_TABLEINSERT1 || ' 
        (
            DOWNLOAD_DATE
            ,PD_RULE_ID
            ,PD_RULE_NAME
            ,BUCKET_GROUP
            ,BUCKET_ID
            ,CALC_METHOD
            ,PD_RATE
            ,CREATEDBY
            ,CREATEDDATE
        ) SELECT 
            ''' || CAST(V_CURRDATE AS VARCHAR(10)) || '''::DATE AS DOWNLOAD_DATE
            ,A.PD_RULE_ID
            ,MAX(A.PD_RULE_NAME)
            ,MAX(A.BUCKET_GROUP)
            ,A.BUCKET_ID
            ,MAX(A.CALC_METHOD)
            ,CASE COUNT(
                CASE SIGN(C.FLOW_TO_LOSS)
                    WHEN 0 
                    THEN 1
                    ELSE NULL
                END) -- COUNT ZEROS IN GROUP
                WHEN 0  -- NO ZEROES: PROCEED NORMALLY
                -- LN ONLY ACCEPTS POSITIVE VALUES. HERE, WE COUNT HOW MANY NEGATIVE NUMBERS THERE WERE IN A GROUP:
                THEN CASE (SUM(
                    CASE SIGN(C.FLOW_TO_LOSS)
                        WHEN -1 
                        THEN 1
                        ELSE 0
                    END) % 2)
                    WHEN 1 
                    THEN -1 -- ODD NUMBER OF NEGATIVE NUMBERS: RESULT WILL BE NEGATIVE
                    ELSE 1 -- EVEN NUMBER OF NEGATIVE NUMBERS: RESULT WILL BE POSITIVE
                    -- MULTIPLY -1 OR 1 WITH THE FOLLOWING EXPRESSION
                END * EXP(SUM(LOG(
                    -- ONLY POSITIVE (NON-ZERO) VALUES!
                    ABS(CASE C.FLOW_TO_LOSS
                        WHEN 0 
                        THEN NULL
                        ELSE C.FLOW_TO_LOSS
                    END))))
                ELSE 0 -- THERE WERE ZEROES, SO THE ENTIRE PRODUCT IS 0, TOO.
            END  AS PD_RATE
            ,''SP_IFRS_IMP_PD_NFR_RESULT'' AS CREATEDBY
            ,CURRENT_TIMESTAMP AS CREATEDDATE
        FROM ' || V_TABLEINSERT2 || ' A
        JOIN ' || V_TABLEINSERT3 || ' C  
            ON A.PD_RULE_ID = C.PD_RULE_ID 
            AND A.DOWNLOAD_DATE = C.DOWNLOAD_DATE 
            AND A.BUCKET_ID <= C.BUCKET_ID
        WHERE A.DOWNLOAD_DATE = ''' || CAST(V_CURRDATE AS VARCHAR(10)) || '''::DATE
        GROUP BY A.DOWNLOAD_DATE, A.PD_RULE_ID, A.BUCKET_ID ';
    EXECUTE (V_STR_QUERY);

    GET DIAGNOSTICS V_RETURNROWS = ROW_COUNT;
    V_RETURNROWS2 := V_RETURNROWS2 + V_RETURNROWS;
    V_RETURNROWS := 0;

    RAISE NOTICE 'SP_IFRS_IMP_PD_NFR_RESULT | AFFECTED RECORD : %', V_RETURNROWS2;
    ---------- ====== BODY ======

    -------- ====== LOG ======
    V_TABLEDEST = V_TABLEINSERT1;
    V_COLUMNDEST = '-';
    V_SPNAME = 'SP_IFRS_IMP_PD_NFR_RESULT';
    V_OPERATION = 'INSERT';
    
    CALL SP_IFRS_EXEC_AND_LOG(V_CURRDATE, V_TABLEDEST, V_COLUMNDEST, V_SPNAME, V_OPERATION, V_RETURNROWS2, P_RUNID);
    -------- ====== LOG ======

    -------- ====== RESULT ======
    V_QUERYS = 'SELECT * FROM ' || V_TABLEINSERT1 || '';
    CALL SP_IFRS_RESULT_PREV(V_CURRDATE, V_QUERYS, V_SPNAME, V_RETURNROWS2, P_RUNID);
    -------- ====== RESULT ======

END;

$$;
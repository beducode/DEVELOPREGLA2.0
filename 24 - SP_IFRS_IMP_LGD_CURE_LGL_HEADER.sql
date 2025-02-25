---- DROP PROCEDURE SP_IFRS_IMP_LGD_CURE_LGL_HEADER;

CREATE OR REPLACE PROCEDURE SP_IFRS_IMP_LGD_CURE_LGL_HEADER(
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
    V_TABLELGDCONFIG VARCHAR(100);

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
        V_TABLENAME_MON := 'TMP_IMAM_' || P_RUNID || '';
        V_TABLEINSERT1 := 'TMP_IFRS_ECL_IMA_' || P_RUNID || '';
        V_TABLEINSERT2 := 'IFRS_IMA_IMP_CURR_' || P_RUNID || '';
        V_TABLEINSERT3 := 'IFRS_IMA_IMP_PREV_' || P_RUNID || '';
        V_TABLEINSERT4 := 'IFRS_LGD_TERM_STRUCTURE_' || P_RUNID || '';
        V_TABLELGDCONFIG := 'IFRS_LGD_RULES_CONFIG_' || P_RUNID || '';
    ELSE 
        V_TABLENAME := 'IFRS_MASTER_ACCOUNT';
        V_TABLENAME_MON := 'IFRS_MASTER_ACCOUNT_MONTHLY';
        V_TABLEINSERT1 := 'TMP_IFRS_ECL_IMA';
        V_TABLEINSERT2 := 'IFRS_IMA_IMP_CURR';
        V_TABLEINSERT3 := 'IFRS_IMA_IMP_PREV';
        V_TABLEINSERT4 := 'IFRS_LGD_TERM_STRUCTURE';
        V_TABLELGDCONFIG := 'IFRS_LGD_RULES_CONFIG';
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
        V_STR_QUERY := V_STR_QUERY || 'CREATE TABLE ' || V_TABLEINSERT4 || ' AS SELECT * FROM IFRS_LGD_TERM_STRUCTURE WHERE 0=1';
        EXECUTE (V_STR_QUERY);
    END IF;
    -------- ====== PRE SIMULATION TABLE ======
    
    -------- ====== BODY ======
    V_STR_QUERY := '';
    V_STR_QUERY := V_STR_QUERY || 'DROP TABLE IF EXISTS HEADER_' || P_RUNID || '';
    EXECUTE (V_STR_QUERY);

    V_STR_QUERY := '';
    V_STR_QUERY := V_STR_QUERY || 'CREATE TEMP TABLE HEADER_' || P_RUNID || ' AS
    SELECT * FROM IFRS_LGD_CURE_LGL_HEADER WHERE 1 = 2';
    EXECUTE (V_STR_QUERY);

    V_STR_QUERY := '';
    V_STR_QUERY := V_STR_QUERY || 'INSERT INTO HEADER_' || P_RUNID || '            
    (            
    DOWNLOAD_DATE            
    ,LGD_RULE_ID            
    ,LGD_RULE_NAME            
    ,DEFAULT_RULE_ID            
    )            
    SELECT            
    A.DOWNLOAD_DATE            
    ,A.LGD_RULE_ID            
    ,A.LGD_RULE_NAME            
    ,A.DEFAULT_RULE_ID            
    FROM IFRS_LGD_CURE_LGL_DETAIL A       
    JOIN ' || V_TABLELGDCONFIG || ' B        
    ON A.LGD_RULE_ID = B.PKID        
    AND A.DEFAULT_RULE_ID = B.DEFAULT_RULE_ID        
    WHERE A.DEFAULT_DATE >= B.CUT_OFF_DATE
    AND A.DEFAULT_DATE >= F_EOMONTH(CASE WHEN B.LAG_1MONTH_FLAG = 1 THEN ''' || CAST(V_PREVMONTH AS VARCHAR(10)) || '''::DATE ELSE ''' || CAST(V_CURRDATE AS VARCHAR(10)) || '''::DATE END, B.LGW_HISTORICAL_DATA, ''M'', ''PREV'')
    AND A.DOWNLOAD_DATE = CASE WHEN B.LAG_1MONTH_FLAG = 1 THEN ''' || CAST(V_PREVMONTH AS VARCHAR(10)) || '''::DATE ELSE ''' || CAST(V_CURRDATE AS VARCHAR(10)) || '''::DATE END        
    AND B.ACTIVE_FLAG = 1
    AND B.IS_DELETE = 0
    GROUP BY         
    A.DOWNLOAD_DATE        
    ,A.LGD_RULE_ID        
    ,A.LGD_RULE_NAME        
    ,A.DEFAULT_RULE_ID';
    EXECUTE (V_STR_QUERY);

    V_STR_QUERY := '';
    V_STR_QUERY := V_STR_QUERY || 'UPDATE HEADER_' || P_RUNID || ' A         
    SET CURE_COUNT = B.CURE_COUNT        
    FROM (               
    SELECT        
    A.DOWNLOAD_DATE        
    ,A.LGD_RULE_ID        
    ,A.LGD_RULE_NAME        
    ,A.DEFAULT_RULE_ID        
    ,COUNT(1) AS CURE_COUNT        
    FROM IFRS_LGD_CURE_LGL_DETAIL A       
    JOIN ' || V_TABLELGDCONFIG || ' B        
    ON A.LGD_RULE_ID = B.PKID        
    AND A.DEFAULT_RULE_ID = B.DEFAULT_RULE_ID        
    WHERE A.DEFAULT_DATE >= B.CUT_OFF_DATE
    AND A.DEFAULT_DATE >= F_EOMONTH(CASE WHEN B.LAG_1MONTH_FLAG = 1 THEN ''' || CAST(V_PREVMONTH AS VARCHAR(10)) || '''::DATE ELSE ''' || CAST(V_CURRDATE AS VARCHAR(10)) || '''::DATE END, B.LGW_HISTORICAL_DATA, ''M'', ''PREV'')       
    AND A.DOWNLOAD_DATE = CASE WHEN B.LAG_1MONTH_FLAG = 1 THEN ''' || CAST(V_PREVMONTH AS VARCHAR(10)) || '''::DATE ELSE ''' || CAST(V_CURRDATE AS VARCHAR(10)) || '''::DATE END        
    AND A.FINAL_STATUS LIKE ''%CURE%''
    AND B.ACTIVE_FLAG = 1 
    AND B.IS_DELETE = 0
    GROUP BY         
    A.DOWNLOAD_DATE        
    ,A.LGD_RULE_ID        
    ,A.LGD_RULE_NAME        
    ,A.DEFAULT_RULE_ID        
    ) B WHERE A.DOWNLOAD_DATE = B.DOWNLOAD_DATE        
    AND A.LGD_RULE_ID = B.LGD_RULE_ID                         
    AND A.DEFAULT_RULE_ID = B.DEFAULT_RULE_ID';
    EXECUTE (V_STR_QUERY);

    V_STR_QUERY := '';
    V_STR_QUERY := V_STR_QUERY || 'UPDATE HEADER_' || P_RUNID || ' A         
    SET LIQPEN_COUNT = B.LIQPEN_COUNT        
    FROM (        
    SELECT        
    A.DOWNLOAD_DATE        
    ,A.LGD_RULE_ID        
    ,A.LGD_RULE_NAME        
    ,A.DEFAULT_RULE_ID        
    ,COUNT(1) AS LIQPEN_COUNT               
    FROM IFRS_LGD_CURE_LGL_DETAIL A       
    JOIN ' || V_TABLELGDCONFIG || ' B        
    ON A.LGD_RULE_ID = B.PKID        
    AND A.DEFAULT_RULE_ID = B.DEFAULT_RULE_ID        
    WHERE A.DEFAULT_DATE >= B.CUT_OFF_DATE                      
    AND A.DEFAULT_DATE >= F_EOMONTH(CASE WHEN B.LAG_1MONTH_FLAG = 1 THEN ''' || CAST(V_PREVMONTH AS VARCHAR(10)) || '''::DATE ELSE ''' || CAST(V_CURRDATE AS VARCHAR(10)) || '''::DATE END, B.LGW_HISTORICAL_DATA, ''M'', ''PREV'')       
    AND A.DOWNLOAD_DATE = CASE WHEN B.LAG_1MONTH_FLAG = 1 THEN ''' || CAST(V_PREVMONTH AS VARCHAR(10)) || '''::DATE ELSE ''' || CAST(V_CURRDATE AS VARCHAR(10)) || '''::DATE END
    AND A.FINAL_STATUS IN (''LIQUIDATED'', ''PENDING'', ''CURE & LIQUIDATED'', ''CURE & PENDING'')        
    AND ((COALESCE(B.EXCLUDE_RESTRUCTURE_FLAG, 0) = 1 AND COALESCE(A.RESTRU_SIFAT_FLAG, 0) <> 1) OR (COALESCE(B.EXCLUDE_RESTRUCTURE_FLAG, 0) = 0))            
    AND B.ACTIVE_FLAG = 1
    AND B.IS_DELETE = 0
    GROUP BY         
    A.DOWNLOAD_DATE        
    ,A.LGD_RULE_ID        
    ,A.LGD_RULE_NAME        
    ,A.DEFAULT_RULE_ID        
    ) B WHERE A.DOWNLOAD_DATE = B.DOWNLOAD_DATE        
    AND A.LGD_RULE_ID = B.LGD_RULE_ID                         
    AND A.DEFAULT_RULE_ID = B.DEFAULT_RULE_ID';
    EXECUTE (V_STR_QUERY);

    V_STR_QUERY := '';
    V_STR_QUERY := V_STR_QUERY || 'UPDATE HEADER_' || P_RUNID || ' A         
    SET AVG_LGL = B.AVG_LGL , DISC_AVG_LGL = B.DISC_AVG_LGL        
    FROM (        
    SELECT DOWNLOAD_DATE, LGD_RULE_ID, DEFAULT_RULE_ID, AVG_LGL, DISC_AVG_LGL        
    FROM        
    (        
    SELECT        
    A.DOWNLOAD_DATE        
    ,A.LGD_RULE_ID        
    ,A.DEFAULT_RULE_ID        
    ,AVG(LGL) AS AVG_LGL        
    ,AVG(DISC_LGL) AS DISC_AVG_LGL        
    FROM IFRS_LGD_CURE_LGL_DETAIL A        
    JOIN ' || V_TABLELGDCONFIG || ' B        
    ON A.LGD_RULE_ID = B.PKID        
    AND A.DEFAULT_RULE_ID = B.DEFAULT_RULE_ID        
    WHERE A.DEFAULT_DATE >= B.CUT_OFF_DATE                          
    AND A.DEFAULT_DATE >= F_EOMONTH(CASE WHEN B.LAG_1MONTH_FLAG = 1 THEN ''' || CAST(V_PREVMONTH AS VARCHAR(10)) || '''::DATE ELSE ''' || CAST(V_CURRDATE AS VARCHAR(10)) || '''::DATE END, B.LGW_HISTORICAL_DATA, ''M'', ''PREV'')       
    AND A.DOWNLOAD_DATE = CASE WHEN B.LAG_1MONTH_FLAG = 1 THEN ''' || CAST(V_PREVMONTH AS VARCHAR(10)) || '''::DATE ELSE ''' || CAST(V_CURRDATE AS VARCHAR(10)) || '''::DATE END       
    AND ((COALESCE(B.EXCLUDE_RESTRUCTURE_FLAG, 0) = 1 AND COALESCE(A.RESTRU_SIFAT_FLAG, 0) <> 1) OR (COALESCE(B.EXCLUDE_RESTRUCTURE_FLAG, 0) = 0))            
    AND REPLACE(A.LGD_UNIQUE_ID, ''_'', '''') NOT IN (SELECT BUYBACK_AGREE_ID FROM IFRS_LGD_BUYBACK)        
    AND A.DEFAULT_DATE >= F_EOMONTH(''' || CAST(V_CURRDATE AS VARCHAR(10)) || '''::DATE, CASE WHEN COALESCE(B.WORKOUT_PERIOD, 0) <> 0 THEN B.WORKOUT_PERIOD ELSE 0 END, ''M'', ''PREV'')
    AND COALESCE(B.WORKOUT_PERIOD, 0) <> 0        
    AND A.FINAL_STATUS NOT IN (''CURE'')        
    AND B.ACTIVE_FLAG = 1
    AND B.IS_DELETE = 0
    GROUP BY         
    A.DOWNLOAD_DATE        
    ,A.LGD_RULE_ID        
    ,A.LGD_RULE_NAME        
    ,A.DEFAULT_RULE_ID        
    UNION ALL        
    SELECT        
    A.DOWNLOAD_DATE        
    ,A.LGD_RULE_ID        
    ,A.DEFAULT_RULE_ID        
    ,AVG(LGL) AS AVG_LGL        
    ,AVG(DISC_LGL) AS DISC_AVG_LGL        
    FROM IFRS_LGD_CURE_LGL_DETAIL A       
    JOIN ' || V_TABLELGDCONFIG || ' B        
    ON A.LGD_RULE_ID = B.PKID        
    AND A.DEFAULT_RULE_ID = B.DEFAULT_RULE_ID        
    WHERE A.DEFAULT_DATE >= B.CUT_OFF_DATE
    AND A.DEFAULT_DATE >= F_EOMONTH(CASE WHEN B.LAG_1MONTH_FLAG = 1 THEN ''' || CAST(V_PREVMONTH AS VARCHAR(10)) || '''::DATE ELSE ''' || CAST(V_CURRDATE AS VARCHAR(10)) || '''::DATE END, B.LGW_HISTORICAL_DATA, ''M'', ''PREV'')       
    AND A.DOWNLOAD_DATE = CASE WHEN B.LAG_1MONTH_FLAG = 1 THEN ''' || CAST(V_PREVMONTH AS VARCHAR(10)) || '''::DATE ELSE ''' || CAST(V_CURRDATE AS VARCHAR(10)) || '''::DATE END         
    AND ((COALESCE(B.EXCLUDE_RESTRUCTURE_FLAG, 0) = 1 AND COALESCE(A.RESTRU_SIFAT_FLAG, 0) <> 1) OR (COALESCE(B.EXCLUDE_RESTRUCTURE_FLAG, 0) = 0))            
    AND REPLACE(A.LGD_UNIQUE_ID, ''_'', '''') NOT IN (SELECT BUYBACK_AGREE_ID FROM IFRS_LGD_BUYBACK)        
    AND COALESCE(B.WORKOUT_PERIOD, 0) = 0        
    AND A.FINAL_STATUS NOT IN (''CURE'')        
    AND B.ACTIVE_FLAG = 1
    AND B.IS_DELETE = 0
    GROUP BY         
    A.DOWNLOAD_DATE        
    ,A.LGD_RULE_ID        
    ,A.LGD_RULE_NAME        
    ,A.DEFAULT_RULE_ID        
    ) X GROUP BY DOWNLOAD_DATE, LGD_RULE_ID, DEFAULT_RULE_ID, AVG_LGL, DISC_AVG_LGL        
    ) B WHERE A.DOWNLOAD_DATE = B.DOWNLOAD_DATE        
    AND A.LGD_RULE_ID = B.LGD_RULE_ID        
    AND A.DEFAULT_RULE_ID = B.DEFAULT_RULE_ID';
    EXECUTE (V_STR_QUERY);

    V_STR_QUERY := '';
    V_STR_QUERY := V_STR_QUERY || ' DELETE FROM IFRS_LGD_CURE_LGL_HEADER A        
    USING ' || V_TABLELGDCONFIG || ' B        
    WHERE A.LGD_RULE_ID = B.PKID                            
    AND A.DOWNLOAD_DATE = CASE WHEN B.LAG_1MONTH_FLAG = 1 THEN ''' || CAST(V_PREVMONTH AS VARCHAR(10)) || '''::DATE ELSE ''' || CAST(V_CURRDATE AS VARCHAR(10)) || '''::DATE END
    AND B.ACTIVE_FLAG = 1 AND B.IS_DELETE = 0';
    EXECUTE (V_STR_QUERY);

    V_STR_QUERY := '';
    V_STR_QUERY := V_STR_QUERY || 'INSERT INTO IFRS_LGD_CURE_LGL_HEADER        
    (        
    DOWNLOAD_DATE        
    ,LGD_RULE_ID        
    ,LGD_RULE_NAME        
    ,DEFAULT_RULE_ID        
    ,CURE_COUNT        
    ,LIQPEN_COUNT        
    ,TOTAL_CURE_LIQPEN        
    ,CURE_RATE        
    ,AVG_LGL        
    ,DISC_AVG_LGL        
    ,LGD        
    )        
    SELECT        
    DOWNLOAD_DATE        
    ,LGD_RULE_ID        
    ,LGD_RULE_NAME        
    ,DEFAULT_RULE_ID        
    ,COALESCE(CURE_COUNT, 0) AS CURE_COUNT          
    ,COALESCE(LIQPEN_COUNT, 0) LIQPEN_COUNT          
    ,(COALESCE(LIQPEN_COUNT, 0) + COALESCE(CURE_COUNT, 0)) AS TOTAL_CURE_LIQPEN        
    ,CAST(COALESCE(CURE_COUNT, 0) AS FLOAT) / CAST((COALESCE(LIQPEN_COUNT, 0) + COALESCE(CURE_COUNT, 0)) AS FLOAT) AS CURE_RATE        
    ,AVG_LGL        
    ,DISC_AVG_LGL        
    ,(1 - CAST(COALESCE(CURE_COUNT, 0) AS FLOAT) / CAST((COALESCE(LIQPEN_COUNT, 0) + COALESCE(CURE_COUNT, 0)) AS FLOAT)) * DISC_AVG_LGL AS LGD        
    FROM HEADER_' || P_RUNID || '';
    EXECUTE (V_STR_QUERY);

    V_STR_QUERY := '';
    V_STR_QUERY := V_STR_QUERY || 'DELETE FROM ' || V_TABLEINSERT4 || ' A        
    USING ' || V_TABLELGDCONFIG || ' B        
    WHERE A.LGD_RULE_ID = B.PKID AND B.ACTIVE_FLAG = 1 AND B.IS_DELETE = 0        
    AND A.DEFAULT_RULE_ID = B.DEFAULT_RULE_ID        
    AND A.DOWNLOAD_DATE = CASE WHEN B.LAG_1MONTH_FLAG = 1 THEN ''' || CAST(V_PREVMONTH AS VARCHAR(10)) || '''::DATE ELSE ''' || CAST(V_CURRDATE AS VARCHAR(10)) || '''::DATE END AND B.LGD_METHOD = ''CR X LGL''';
    EXECUTE (V_STR_QUERY);

    V_STR_QUERY := '';
    V_STR_QUERY := V_STR_QUERY || 'INSERT INTO ' || V_TABLEINSERT4 || '                            
    (                            
    DOWNLOAD_DATE                            
    ,LGD_RULE_ID                            
    ,LGD_RULE_NAME                            
    ,DEFAULT_RULE_ID                            
    ,LGD                            
    )                            
    SELECT                            
    DOWNLOAD_DATE                            
    ,A.LGD_RULE_ID                            
    ,A.LGD_RULE_NAME                            
    ,A.DEFAULT_RULE_ID                            
    ,LGD                            
    FROM IFRS_LGD_CURE_LGL_HEADER A                          
    JOIN ' || V_TABLELGDCONFIG || ' B                          
    ON A.LGD_RULE_ID = B.PKID        
    AND A.DEFAULT_RULE_ID = B.DEFAULT_RULE_ID        
    WHERE A.DOWNLOAD_DATE = CASE WHEN B.LAG_1MONTH_FLAG = 1 THEN ''' || CAST(V_PREVMONTH AS VARCHAR(10)) || '''::DATE ELSE ''' || CAST(V_CURRDATE AS VARCHAR(10)) || '''::DATE END  
    AND B.ACTIVE_FLAG = 1 AND B.IS_DELETE = 0
    UNION ALL  
    SELECT   
    A.DOWNLOAD_DATE,   
    C.PKID AS LGD_RULE_ID,   
    C.LGD_RULE_NAME,   
    C.DEFAULT_RULE_ID,   
    (1 - RECOVERY_RATE) AS LGD  
    FROM IFRS_RECOVERY_RATE_TREASURY A  
    JOIN IFRS_MSTR_SEGMENT_RULES_HEADER B ON A.SEGMENT = B.SEGMENT AND B.SEGMENT_TYPE = ''LGD_SEGMENT''  
    JOIN ' || V_TABLELGDCONFIG || ' C ON B.PKID = C.SEGMENTATION_ID  
    WHERE C.LGD_METHOD = ''EXTERNAL'' AND A.DOWNLOAD_DATE = CASE WHEN C.LAG_1MONTH_FLAG = 1 THEN ''' || CAST(V_PREVMONTH AS VARCHAR(10)) || '''::DATE ELSE ''' || CAST(V_CURRDATE AS VARCHAR(10)) || '''::DATE END
    AND C.ACTIVE_FLAG = 1  AND B.IS_DELETE = 0';
    EXECUTE (V_STR_QUERY);

    GET DIAGNOSTICS V_RETURNROWS = ROW_COUNT;
    V_RETURNROWS2 := V_RETURNROWS2 + V_RETURNROWS;
    V_RETURNROWS := 0;

    RAISE NOTICE 'SP_IFRS_IMP_LGD_CURE_LGL_HEADER | AFFECTED RECORD : %', V_RETURNROWS2;
    -------- ====== BODY ======

    -------- ====== LOG ======
    V_TABLEDEST = V_TABLEINSERT4;
    V_COLUMNDEST = '-';
    V_SPNAME = 'SP_IFRS_IMP_LGD_CURE_LGL_HEADER';
    V_OPERATION = 'INSERT';
    
    CALL SP_IFRS_EXEC_AND_LOG(V_CURRDATE, V_TABLEDEST, V_COLUMNDEST, V_SPNAME, V_OPERATION, V_RETURNROWS2, P_RUNID);
    -------- ====== LOG ======

    -------- ====== RESULT ======
    V_QUERYS = 'SELECT * FROM ' || V_TABLEINSERT4 || '';
    CALL SP_IFRS_RESULT_PREV(V_CURRDATE, V_QUERYS, V_SPNAME, V_RETURNROWS2, P_RUNID);
    -------- ====== RESULT ======

END;

$$;
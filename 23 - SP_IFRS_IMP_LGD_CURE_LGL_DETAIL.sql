---- DROP PROCEDURE SP_IFRS_IMP_LGD_CURE_LGL_DETAIL;

CREATE OR REPLACE PROCEDURE SP_IFRS_IMP_LGD_CURE_LGL_DETAIL(
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
        V_TABLEINSERT4 := 'IFRS_LGD_CURE_LGL_DETAIL_' || P_RUNID || '';
        V_TABLELGDCONFIG := 'IFRS_LGD_RULES_CONFIG_' || P_RUNID || '';
    ELSE 
        V_TABLENAME := 'IFRS_MASTER_ACCOUNT';
        V_TABLENAME_MON := 'IFRS_MASTER_ACCOUNT_MONTHLY';
        V_TABLEINSERT1 := 'TMP_IFRS_ECL_IMA';
        V_TABLEINSERT2 := 'IFRS_IMA_IMP_CURR';
        V_TABLEINSERT3 := 'IFRS_IMA_IMP_PREV';
        V_TABLEINSERT4 := 'IFRS_LGD_CURE_LGL_DETAIL';
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
        V_STR_QUERY := V_STR_QUERY || 'CREATE TABLE ' || V_TABLEINSERT4 || ' AS SELECT * FROM IFRS_LGD_CURE_LGL_DETAIL WHERE 0=1';
        EXECUTE (V_STR_QUERY);
    END IF;
    -------- ====== PRE SIMULATION TABLE ======
    
    -------- ====== BODY ======
    V_STR_QUERY := '';
    V_STR_QUERY := V_STR_QUERY || 'DELETE FROM ' || V_TABLEINSERT4 || ' A           
    USING ' || V_TABLELGDCONFIG || ' B          
    WHERE A.LGD_RULE_ID = B.PKID         
    AND A.DOWNLOAD_DATE = CASE WHEN B.LAG_1MONTH_FLAG = 1 THEN ''' || CAST(V_PREVMONTH AS VARCHAR(10)) || '''::DATE ELSE ''' || CAST(V_CURRDATE AS VARCHAR(10)) || '''::DATE END
    AND B.ACTIVE_FLAG = 1         
    AND B.IS_DELETE = 0';
    EXECUTE (V_STR_QUERY);

    V_STR_QUERY := '';
    V_STR_QUERY := V_STR_QUERY || 'DROP TABLE IF EXISTS CURRENT_' || P_RUNID || '';
    EXECUTE (V_STR_QUERY);

    V_STR_QUERY := '';
    V_STR_QUERY := V_STR_QUERY || 'CREATE TABLE CURRENT_' || P_RUNID || ' AS 
    SELECT           
    X.DOWNLOAD_DATE           
    ,X.LGD_RULE_ID           
    ,MAX(Y.LGD_RULE_NAME) AS LGD_RULE_NAME           
    ,X.DEFAULT_RULE_ID           
    ,X.SEGMENT           
    ,X.SUB_SEGMENT           
    ,X.GROUP_SEGMENT           
    ,X.EIR_SEGMENT           
    ,X.LGD_METHOD           
    ,X.CALC_METHOD           
    ,X.CALC_AMOUNT           
    ,MAX(CAST(X.DEFAULT_FLAG AS CHAR(1))) AS DEFAULT_FLAG           
    ,SUM(X.FAIR_VALUE_AMOUNT) AS FAIR_VALUE_AMOUNT           
    ,MAX(X.BI_COLLECTABILITY) AS BI_COLLECTABILITY           
    ,MAX(X.RATING_CODE) AS RATING_CODE           
    ,MIN(X.LOAN_START_DATE) AS LOAN_START_DATE           
    ,MAX(X.DAY_PAST_DUE) AS DAY_PAST_DUE           
    ,MAX(X.DPD_CIF) AS DPD_CIF           
    ,MAX(X.DPD_FINAL) AS DPD_FINAL           
    ,MAX(X.DPD_FINAL_CIF) AS DPD_FINAL_CIF           
    ,SUM(X.OUTSTANDING) AS OUTSTANDING          
    ,X.LGD_UNIQUE_ID           
    ,AVG(X.AVG_EIR) AS AVG_EIR        
    ,MAX(CAST(X.RESTRU_SIFAT_FLAG AS INT)) AS RESTRU_SIFAT_FLAG        
    ,MAX(CAST(X.WO_FLAG AS INT)) AS WO_FLAG        
    ,MIN(CAST(X.FP_FLAG_ORIG AS CHAR(1))) AS FP_FLAG_ORIG                   
    FROM IFRS_LGD_SCENARIO_DATA X          
    JOIN ' || V_TABLELGDCONFIG || ' Y           
    ON X.LGD_RULE_ID = Y.PKID AND X.DEFAULT_RULE_ID = Y.DEFAULT_RULE_ID           
    WHERE X.DOWNLOAD_DATE = CASE WHEN Y.LAG_1MONTH_FLAG = 1 THEN ''' || CAST(V_PREVMONTH AS VARCHAR(10)) || '''::DATE ELSE ''' || CAST(V_CURRDATE AS VARCHAR(10)) || '''::DATE END 
    AND Y.ACTIVE_FLAG = 1  
    AND Y.IS_DELETE = 0
    GROUP BY        
    X.DOWNLOAD_DATE           
    ,X.LGD_RULE_ID          
    ,X.DEFAULT_RULE_ID           
    ,X.SEGMENT          
    ,X.SUB_SEGMENT           
    ,X.GROUP_SEGMENT           
    ,X.EIR_SEGMENT           
    ,X.LGD_METHOD           
    ,X.CALC_METHOD           
    ,X.CALC_AMOUNT        
    ,X.LGD_UNIQUE_ID';
    EXECUTE (V_STR_QUERY);

    V_STR_QUERY := '';
    V_STR_QUERY := V_STR_QUERY || 'DROP TABLE IF EXISTS PREVIOUS_' || P_RUNID || '';
    EXECUTE (V_STR_QUERY);

    V_STR_QUERY := '';
    V_STR_QUERY := V_STR_QUERY || 'CREATE TABLE PREVIOUS_' || P_RUNID || ' AS 
    SELECT A.*, CASE WHEN B.LAG_1MONTH_FLAG = 1 THEN ''' || CAST(V_PREVMONTH AS VARCHAR(10)) || '''::DATE ELSE ''' || CAST(V_CURRDATE AS VARCHAR(10)) || '''::DATE END REC_WO_DATE                     
    FROM ' || V_TABLEINSERT4 || ' A           
    JOIN ' || V_TABLELGDCONFIG || ' B          
    ON A.LGD_RULE_ID = B.PKID AND A.DEFAULT_RULE_ID = B.DEFAULT_RULE_ID           
    WHERE A.DOWNLOAD_DATE = CASE WHEN B.LAG_1MONTH_FLAG = 1 THEN ''' || CAST(V_PREVMONTH AS VARCHAR(10)) || '''::DATE ELSE ''' || CAST(V_CURRDATE AS VARCHAR(10)) || '''::DATE END
    AND B.ACTIVE_FLAG = 1     
    AND B.IS_DELETE = 0';
    EXECUTE (V_STR_QUERY);

    V_STR_QUERY := '';
    V_STR_QUERY := V_STR_QUERY || 'DROP INDEX IF EXISTS NCI_PREVIOUS_' || P_RUNID || ' ';
    EXECUTE (V_STR_QUERY);

    V_STR_QUERY := '';
    V_STR_QUERY := V_STR_QUERY || 'CREATE INDEX IF NOT EXISTS NCI_PREVIOUS_' || P_RUNID || '
    ON PREVIOUS_' || P_RUNID || ' USING BTREE
    (DOWNLOAD_DATE ASC NULLS LAST, LGD_RULE_ID ASC NULLS LAST, DEFAULT_RULE_ID ASC NULLS LAST, LGD_UNIQUE_ID ASC NULLS LAST)
    TABLESPACE PG_DEFAULT';
    EXECUTE (V_STR_QUERY);

    V_STR_QUERY := '';
    V_STR_QUERY := V_STR_QUERY || 'DROP TABLE IF EXISTS WO_' || P_RUNID || '';
    EXECUTE (V_STR_QUERY);

    V_STR_QUERY := '';
    V_STR_QUERY := V_STR_QUERY || 'CREATE TABLE WO_' || P_RUNID || ' AS 
    SELECT        
    A.DOWNLOAD_DATE AS DOWNLOAD_DATE          
    ,SUM(A.OUTSTANDING_WO) AS OUTSTANDING_WO         
    ,MIN(A.WRITEOFF_DATE) AS WRITEOFF_DATE        
    ,A.LGD_UNIQUE_ID         
    ,A.LGD_RULE_ID                 
    FROM IFRS_WO_SCENARIO_DATA A           
    JOIN PREVIOUS_' || P_RUNID || ' B           
    ON A.DOWNLOAD_DATE = B.REC_WO_DATE AND A.LGD_UNIQUE_ID = B.LGD_UNIQUE_ID         
    AND A.LGD_RULE_ID = B.LGD_RULE_ID      
    JOIN ' || V_TABLELGDCONFIG || ' C        
    ON B.LGD_RULE_ID = C.PKID AND B.DEFAULT_RULE_ID = C.DEFAULT_RULE_ID           
    WHERE A.DOWNLOAD_DATE = CASE WHEN C.LAG_1MONTH_FLAG = 1 THEN ''' || CAST(V_PREVMONTH AS VARCHAR(10)) || '''::DATE ELSE ''' || CAST(V_CURRDATE AS VARCHAR(10)) || '''::DATE END
    AND C.ACTIVE_FLAG = 1      
    AND C.IS_DELETE = 0
    GROUP BY A.DOWNLOAD_DATE, A.LGD_UNIQUE_ID, A.LGD_RULE_ID';
    EXECUTE (V_STR_QUERY);

    V_STR_QUERY := '';
    V_STR_QUERY := V_STR_QUERY || 'DROP TABLE IF EXISTS REC_' || P_RUNID || '';
    EXECUTE (V_STR_QUERY);

    V_STR_QUERY := '';
    V_STR_QUERY := V_STR_QUERY || 'CREATE TABLE REC_' || P_RUNID || ' AS
    SELECT           
    A.DOWNLOAD_DATE         
    ,A.LGD_UNIQUE_ID           
    ,SUM(A.RECOVERY_AMOUNT) AS RECOVERY_AMOUNT         
    ,A.LGD_RULE_ID                     
    FROM IFRS_RECOVERY_SCENARIO_DATA A                   
    JOIN ' || V_TABLELGDCONFIG || ' C           
    ON A.LGD_RULE_ID = C.PKID AND A.DEFAULT_RULE_ID = C.DEFAULT_RULE_ID           
    WHERE A.DOWNLOAD_DATE = CASE WHEN C.LAG_1MONTH_FLAG = 1 THEN ''' || CAST(V_PREVMONTH AS VARCHAR(10)) || '''::DATE ELSE ''' || CAST(V_CURRDATE AS VARCHAR(10)) || '''::DATE END
    AND C.ACTIVE_FLAG = 1
    AND C.IS_DELETE = 0
    GROUP BY A.DOWNLOAD_DATE, A.LGD_UNIQUE_ID, A.LGD_RULE_ID';
    EXECUTE (V_STR_QUERY);
    
    V_STR_QUERY := '';
    V_STR_QUERY := V_STR_QUERY || 'DROP TABLE IF EXISTS CURE_LGL_' || P_RUNID || '';
    EXECUTE (V_STR_QUERY);

    V_STR_QUERY := '';
    V_STR_QUERY := V_STR_QUERY || 'CREATE TABLE CURE_LGL_' || P_RUNID || ' AS
    SELECT * FROM ' || V_TABLEINSERT4 || ' WHERE 1 = 2';
    EXECUTE (V_STR_QUERY);

    V_STR_QUERY := '';
    V_STR_QUERY := V_STR_QUERY || 'INSERT INTO CURE_LGL_' || P_RUNID || '           
    (           
    DOWNLOAD_DATE           
    ,LGD_RULE_ID           
    ,LGD_RULE_NAME           
    ,DEFAULT_RULE_ID           
    ,LGD_UNIQUE_ID        
    ,SEGMENT           
    ,SUB_SEGMENT             
    ,GROUP_SEGMENT           
    ,EIR_SEGMENT           
    ,CALC_METHOD        
    ,LOAN_START_DATE           
    ,WO_DATE           
    ,LAST_SNAPSHOT_DATE           
    ,LAST_DPD           
    ,DEFAULT_FLAG           
    ,DEFAULT_DATE           
    ,DEFAULT_MOVEMENT           
    ,OS_AT_DEFAULT         
    ,OS_LAST_DEFAULT           
    ,LAST_OS           
    ,AVG_EIR           
    ,WO_AMOUNT             
    ,RECOVERY_WO_MTD         
    ,RECOVERY_WO           
    ,DISC_RECOVERY_WO_MTD           
    ,DISC_RECOVERY_WO           
    ,RESTRU_SIFAT_FLAG         
    ,CURE_FLAG         
    ,LIQUIDATED_FLAG          
    ,LAST_DEFAULT_DATE          
    ,LAST_CURE_DATE        
    ,WO_FLAG            
    ,FP_FLAG_ORIG          
    )           
    SELECT           
    CASE WHEN B.LAG_1MONTH_FLAG = 1 THEN ''' || CAST(V_PREVMONTH AS VARCHAR(10)) || '''::DATE ELSE ''' || CAST(V_CURRDATE AS VARCHAR(10)) || '''::DATE END AS DOWNLOAD_DATE        
    ,PREV.LGD_RULE_ID           
    ,MAX(B.LGD_RULE_NAME) AS LGD_RULE_NAME          
    ,PREV.DEFAULT_RULE_ID           
    ,PREV.LGD_UNIQUE_ID           
    ,PREV.SEGMENT           
    ,PREV.SUB_SEGMENT           
    ,PREV.GROUP_SEGMENT           
    ,PREV.EIR_SEGMENT           
    ,PREV.CALC_METHOD         
    ,MIN(PREV.LOAN_START_DATE) AS LOAN_START_DATE           
    ,CASE        
    WHEN WO.WRITEOFF_DATE IS NOT NULL THEN WO.WRITEOFF_DATE        
    ELSE PREV.WO_DATE           
    END AS WO_DATE             
    ,CASE           
    WHEN CURR.DOWNLOAD_DATE IS NOT NULL AND RIGHT(PREV.DEFAULT_MOVEMENT, 1) <> ''2'' THEN         
    CASE        
    WHEN B.LAG_1MONTH_FLAG = 1 THEN ''' || CAST(V_PREVMONTH AS VARCHAR(10)) || '''::DATE ELSE ''' || CAST(V_CURRDATE AS VARCHAR(10)) || '''::DATE END           
    ELSE PREV.LAST_SNAPSHOT_DATE           
    END AS LAST_SNAPSHOT_DATE           
    ,CASE        
    WHEN CURR.LGD_UNIQUE_ID IS NULL THEN PREV.LAST_DPD        
    ELSE        
    CASE CURR.CALC_METHOD          
    WHEN ''ACCOUNT'' THEN CURR.DAY_PAST_DUE        
    WHEN ''CUSTOMER'' THEN CURR.DPD_CIF        
    END        
    END AS LAST_DPD           
    ,CASE             
    WHEN CURR.DOWNLOAD_DATE IS NULL OR PREV.WO_DATE IS NOT NULL THEN CAST(PREV.DEFAULT_FLAG AS CHAR(1))          
    ELSE CAST(COALESCE(CURR.DEFAULT_FLAG, ''0'') AS CHAR(1))           
    END AS DEFAULT_FLAG           
    ,PREV.DEFAULT_DATE           
    ,CONCAT(PREV.DEFAULT_MOVEMENT,        
    CASE        
    WHEN WO.WRITEOFF_DATE IS NOT NULL OR RIGHT(PREV.DEFAULT_MOVEMENT, 1) = ''2'' OR (CURR.DOWNLOAD_DATE IS NULL AND WO.WRITEOFF_DATE IS NULL) THEN ''2''         
    ELSE CAST(COALESCE(CURR.DEFAULT_FLAG, ''0'') AS CHAR(1))          
    END) AS DEFAULT_MOVEMENT           
    ,PREV.OS_AT_DEFAULT         
    ,CASE        
    WHEN RIGHT(CONCAT(PREV.DEFAULT_MOVEMENT,        
    CASE        
    WHEN WO.WRITEOFF_DATE IS NOT NULL OR RIGHT(PREV.DEFAULT_MOVEMENT, 1) = ''2'' OR (CURR.DOWNLOAD_DATE IS NULL AND WO.WRITEOFF_DATE IS NULL) THEN ''2''         
    ELSE CAST(COALESCE(CURR.DEFAULT_FLAG, ''0'') AS CHAR(1))        
    END), 2) = ''01''             
    THEN CURR.OUTSTANDING             
    ELSE PREV.OS_LAST_DEFAULT        
    END AS OS_LAST_DEFAULT             
    ,CASE        
    WHEN WO.WRITEOFF_DATE IS NOT NULL OR RIGHT(PREV.DEFAULT_MOVEMENT, 1) = ''2'' OR (CURR.DOWNLOAD_DATE IS NULL AND MIN(WO.DOWNLOAD_DATE) IS NULL) THEN PREV.LAST_OS         
    ELSE CURR.OUTSTANDING             
    END AS LAST_OS           
    ,PREV.AVG_EIR           
    ,CASE        
    WHEN WO.WRITEOFF_DATE IS NOT NULL THEN WO.OUTSTANDING_WO ELSE PREV.WO_AMOUNT         
    END AS WO_AMOUNT           
    ,COALESCE(REC.RECOVERY_AMOUNT, 0) AS RECOVERY_WO_MTD           
    ,COALESCE(PREV.RECOVERY_WO, 0) + COALESCE(REC.RECOVERY_AMOUNT, 0) AS RECOVERY_WO            
    ,CASE         
    WHEN (EXTRACT(MONTH FROM AGE(PREV.DEFAULT_DATE, REC.DOWNLOAD_DATE)))::INT <= 12         
    THEN COALESCE(REC.RECOVERY_AMOUNT, 0)         
    ELSE          
    CAST((CAST(COALESCE(REC.RECOVERY_AMOUNT, 0) AS FLOAT) / CAST(POWER((1 + PREV.AVG_EIR), CAST((EXTRACT(MONTH FROM AGE(PREV.DEFAULT_DATE, REC.DOWNLOAD_DATE)))::INT AS FLOAT) / 12.00) AS FLOAT)) AS FLOAT)         
    END AS DISC_RECOVERY_WO_MTD             
    ,COALESCE(PREV.DISC_RECOVERY_WO, 0) + COALESCE(CASE         
    WHEN (EXTRACT(MONTH FROM AGE(PREV.DEFAULT_DATE, REC.DOWNLOAD_DATE)))::INT <= 12         
    THEN COALESCE(REC.RECOVERY_AMOUNT, 0)         
    ELSE         
    CAST((CAST(COALESCE(REC.RECOVERY_AMOUNT, 0) AS FLOAT) / CAST(POWER((1 + PREV.AVG_EIR), CAST((EXTRACT(MONTH FROM AGE(PREV.DEFAULT_DATE, REC.DOWNLOAD_DATE)))::INT AS FLOAT) / 12.00) AS FLOAT)) AS FLOAT)         
    END,0) AS DISC_RECOVERY_WO           
    ,CASE WHEN COALESCE(PREV.RESTRU_SIFAT_FLAG, 0) = 1 THEN 1 ELSE COALESCE(PREV.RESTRU_SIFAT_FLAG, 0) END AS RESTRU_SIFAT_FLAG         
    ,PREV.CURE_FLAG         
    ,PREV.LIQUIDATED_FLAG          
    ,CASE        
    WHEN RIGHT(CONCAT(PREV.DEFAULT_MOVEMENT,        
    CASE        
    WHEN WO.WRITEOFF_DATE IS NOT NULL OR RIGHT(PREV.DEFAULT_MOVEMENT, 1) = ''2'' OR (CURR.DOWNLOAD_DATE IS NULL AND WO.WRITEOFF_DATE IS NULL) THEN ''2''         
    ELSE CAST(COALESCE(CURR.DEFAULT_FLAG, ''0'') AS CHAR(1))        
    END), 2) = ''01''             
    THEN CURR.DOWNLOAD_DATE             
    ELSE PREV.LAST_DEFAULT_DATE        
    END AS LAST_DEFAULT_DATE          
    ,PREV.LAST_CURE_DATE AS LAST_CURE_DATE        
    ,CASE WHEN COALESCE(PREV.WO_FLAG, 0) = 1 THEN 1 ELSE COALESCE(PREV.WO_FLAG, 0) END AS WO_FLAG        
    ,MIN(CAST(CURR.FP_FLAG_ORIG AS CHAR(1)))::INT AS FP_FLAG_ORIG          
    FROM PREVIOUS_' || P_RUNID || ' PREV           
    JOIN ' || V_TABLELGDCONFIG || ' B ON PREV.LGD_RULE_ID = B.PKID AND PREV.DEFAULT_RULE_ID = B.DEFAULT_RULE_ID           
    LEFT JOIN CURRENT_' || P_RUNID || ' CURR ON PREV.DOWNLOAD_DATE = F_EOMONTH(CURR.DOWNLOAD_DATE, 1, ''M'', ''PREV'') AND PREV.LGD_UNIQUE_ID = CURR.LGD_UNIQUE_ID         
    LEFT JOIN WO_' || P_RUNID || ' WO ON PREV.DOWNLOAD_DATE = F_EOMONTH(WO.DOWNLOAD_DATE, 1, ''M'', ''PREV'')         
    AND PREV.LGD_UNIQUE_ID = WO.LGD_UNIQUE_ID AND PREV.LGD_RULE_ID = WO.LGD_RULE_ID          
    LEFT JOIN REC_' || P_RUNID || ' REC ON PREV.DOWNLOAD_DATE = F_EOMONTH(REC.DOWNLOAD_DATE, 1, ''M'', ''PREV'') AND PREV.LGD_UNIQUE_ID = REC.LGD_UNIQUE_ID AND PREV.LGD_RULE_ID = REC.LGD_RULE_ID         
    WHERE PREV.DOWNLOAD_DATE = CASE WHEN B.LAG_1MONTH_FLAG = 1 THEN ''' || CAST(V_PREVMONTH AS VARCHAR(10)) || '''::DATE ELSE ''' || CAST(V_PREVMONTH AS VARCHAR(10)) || '''::DATE END        
    AND B.ACTIVE_FLAG = 1  AND B.IS_DELETE = 0  
    GROUP BY           
    B.LAG_1MONTH_FLAG           
    ,PREV.LGD_RULE_ID          
    ,PREV.DEFAULT_RULE_ID           
    ,PREV.LGD_UNIQUE_ID          
    ,PREV.SEGMENT           
    ,PREV.SUB_SEGMENT        
    ,PREV.GROUP_SEGMENT           
    ,PREV.EIR_SEGMENT        
    ,PREV.CALC_METHOD           
    ,PREV.WO_DATE          
    ,CURR.DOWNLOAD_DATE          
    ,PREV.DEFAULT_MOVEMENT           
    ,PREV.LAST_SNAPSHOT_DATE          
    ,CURR.LGD_UNIQUE_ID          
    ,PREV.LAST_DPD           
    ,CURR.CALC_METHOD        
    ,CURR.DAY_PAST_DUE           
    ,CURR.DPD_CIF            
    ,CURR.DEFAULT_FLAG           
    ,PREV.DEFAULT_FLAG           
    ,PREV.DEFAULT_DATE        
    ,PREV.OS_AT_DEFAULT           
    ,PREV.OS_LAST_DEFAULT        
    ,PREV.LAST_OS        
    ,CURR.OUTSTANDING          
    ,PREV.AVG_EIR        
    ,PREV.WO_AMOUNT         
    ,COALESCE(REC.RECOVERY_AMOUNT, 0)          
    ,REC.DOWNLOAD_DATE          
    ,COALESCE(PREV.RECOVERY_WO, 0)           
    ,COALESCE(PREV.RESTRU_SIFAT_FLAG, 0)           
    ,COALESCE(PREV.DISC_RECOVERY_WO, 0)             
    ,WO.DOWNLOAD_DATE             
    ,WO.LGD_RULE_ID             
    ,WO.LGD_UNIQUE_ID          
    ,WO.OUTSTANDING_WO         
    ,WO.WRITEOFF_DATE         
    ,PREV.CURE_FLAG         
    ,PREV.LIQUIDATED_FLAG          
    ,PREV.LAST_DEFAULT_DATE          
    ,PREV.LAST_CURE_DATE           
    ,COALESCE(PREV.WO_FLAG, 0)';
    EXECUTE (V_STR_QUERY);

    V_STR_QUERY := '';
    V_STR_QUERY := V_STR_QUERY || 'DROP INDEX IF EXISTS NCI_CURE_LGL_' || P_RUNID || ' ';
    EXECUTE (V_STR_QUERY);

    V_STR_QUERY := '';
    V_STR_QUERY := V_STR_QUERY || 'CREATE INDEX IF NOT EXISTS NCI_CURE_LGL_' || P_RUNID || '
    ON CURE_LGL_' || P_RUNID || ' USING BTREE
    (DOWNLOAD_DATE ASC NULLS LAST, LGD_RULE_ID ASC NULLS LAST, DEFAULT_RULE_ID ASC NULLS LAST, LGD_UNIQUE_ID ASC NULLS LAST)
    TABLESPACE PG_DEFAULT';
    EXECUTE (V_STR_QUERY);

    V_STR_QUERY := '';
    V_STR_QUERY := V_STR_QUERY || 'DROP TABLE IF EXISTS CURR_CURE_RATE_' || P_RUNID || '';
    EXECUTE (V_STR_QUERY);

    V_STR_QUERY := '';
    V_STR_QUERY := V_STR_QUERY || 'CREATE TABLE CURR_CURE_RATE_' || P_RUNID || ' AS
    SELECT           
    X.DOWNLOAD_DATE,           
    X.LGD_RULE_ID,           
    X.DEFAULT_RULE_ID,           
    X.LGD_UNIQUE_ID,           
    X.DEFAULT_MOVEMENT,          
    Y.LAG_1MONTH_FLAG                     
    FROM CURE_LGL_' || P_RUNID || ' X          
    JOIN ' || V_TABLELGDCONFIG || ' Y          
    ON X.LGD_RULE_ID = Y.PKID AND X.DEFAULT_RULE_ID = Y.DEFAULT_RULE_ID           
    WHERE X.DOWNLOAD_DATE = CASE WHEN Y.LAG_1MONTH_FLAG = 1 THEN ''' || CAST(V_PREVMONTH AS VARCHAR(10)) || '''::DATE ELSE ''' || CAST(V_CURRDATE AS VARCHAR(10)) || '''::DATE END
    AND Y.ACTIVE_FLAG = 1           
    AND Y.IS_DELETE = 0';
    EXECUTE (V_STR_QUERY);

    V_STR_QUERY := '';
    V_STR_QUERY := V_STR_QUERY || 'INSERT INTO CURE_LGL_' || P_RUNID || '           
    (         
    DOWNLOAD_DATE           
    ,LGD_RULE_ID           
    ,LGD_RULE_NAME           
    ,DEFAULT_RULE_ID           
    ,LGD_UNIQUE_ID           
    ,SEGMENT          
    ,SUB_SEGMENT           
    ,GROUP_SEGMENT           
    ,EIR_SEGMENT           
    ,CALC_METHOD           
    ,LOAN_START_DATE           
    ,WO_DATE           
    ,LAST_SNAPSHOT_DATE           
    ,LAST_DPD           
    ,DEFAULT_FLAG           
    ,DEFAULT_DATE           
    ,DEFAULT_MOVEMENT           
    ,OS_AT_DEFAULT        
    ,OS_LAST_DEFAULT           
    ,LAST_OS           
    ,AVG_EIR       
    ,RESTRU_SIFAT_FLAG          
    ,LAST_DEFAULT_DATE         
    ,WO_FLAG          
    ,FP_FLAG_ORIG        
    ,RECOVERY_WO_MTD                     
    ,RECOVERY_WO          
    ,DISC_RECOVERY_WO_MTD          
    ,DISC_RECOVERY_WO         
    )           
    SELECT           
    A.DOWNLOAD_DATE           
    ,A.LGD_RULE_ID           
    ,A.LGD_RULE_NAME           
    ,A.DEFAULT_RULE_ID           
    ,A.LGD_UNIQUE_ID           
    ,A.SEGMENT           
    ,A.SUB_SEGMENT           
    ,A.GROUP_SEGMENT           
    ,A.EIR_SEGMENT           
    ,UPPER(A.CALC_METHOD) AS CALC_METHOD           
    ,A.LOAN_START_DATE           
    ,NULL AS WO_DATE           
    ,A.DOWNLOAD_DATE AS LAST_SNAPSHOT_DATE           
    ,CASE A.CALC_METHOD WHEN ''ACCOUNT'' THEN A.DAY_PAST_DUE WHEN ''CUSTOMER'' THEN A.DPD_CIF END AS LAST_DPD           
    ,A.DEFAULT_FLAG           
    ,A.DOWNLOAD_DATE AS DEFAULT_DATE           
    ,''1'' AS DEFAULT_MOVEMENT             
    ,OUTSTANDING AS OS_AT_DEFAULT          
    ,OUTSTANDING AS OS_LAST_DEFAULT           
    ,OUTSTANDING AS LAST_OS           
    ,A.AVG_EIR           
    ,A.RESTRU_SIFAT_FLAG          
    ,A.DOWNLOAD_DATE AS LAST_DEFAULT_DATE        
    ,A.WO_FLAG            
    ,A.FP_FLAG_ORIG::INT           
    ,COALESCE(REC.RECOVERY_AMOUNT, 0) AS RECOVERY_WO_MTD
    ,COALESCE(REC.RECOVERY_AMOUNT, 0) AS RECOVERY_WO            
    ,COALESCE(CASE         
    WHEN (EXTRACT(MONTH FROM AGE(A.DOWNLOAD_DATE, REC.DOWNLOAD_DATE)))::INT <= 12         
    THEN COALESCE(REC.RECOVERY_AMOUNT, 0)         
    ELSE          
    CAST((CAST(COALESCE(REC.RECOVERY_AMOUNT, 0) AS FLOAT) / CAST(POWER((1 + A.AVG_EIR), CAST((EXTRACT(MONTH FROM AGE(A.DOWNLOAD_DATE, REC.DOWNLOAD_DATE)))::INT AS FLOAT) / 12.00) AS FLOAT)) AS FLOAT)         
    END,0) AS DISC_RECOVERY_WO_MTD             
    ,COALESCE(CASE         
    WHEN (EXTRACT(MONTH FROM AGE(A.DOWNLOAD_DATE, REC.DOWNLOAD_DATE)))::INT <= 12         
    THEN COALESCE(REC.RECOVERY_AMOUNT, 0)         
    ELSE         
    CAST((CAST(COALESCE(REC.RECOVERY_AMOUNT, 0) AS FLOAT) / CAST(POWER((1 + A.AVG_EIR), CAST((EXTRACT(MONTH FROM AGE(A.DOWNLOAD_DATE, REC.DOWNLOAD_DATE)))::INT AS FLOAT) / 12.00) AS FLOAT)) AS FLOAT)         
    END,0) AS DISC_RECOVERY_WO           
    FROM CURRENT_' || P_RUNID || ' A           
    JOIN ' || V_TABLELGDCONFIG || ' C           
    ON A.LGD_RULE_ID = C.PKID AND A.DEFAULT_RULE_ID = C.DEFAULT_RULE_ID           
    LEFT JOIN CURR_CURE_RATE_' || P_RUNID || ' D           
    ON A.DOWNLOAD_DATE = D.DOWNLOAD_DATE AND A.LGD_UNIQUE_ID = D.LGD_UNIQUE_ID AND A.LGD_RULE_ID = D.LGD_RULE_ID             
    LEFT JOIN REC_' || P_RUNID || ' REC       
    ON A.DOWNLOAD_DATE = REC.DOWNLOAD_DATE AND A.LGD_UNIQUE_ID = REC.LGD_UNIQUE_ID AND A.LGD_RULE_ID = REC.LGD_RULE_ID        
    WHERE A.DOWNLOAD_DATE = CASE WHEN C.LAG_1MONTH_FLAG = 1 THEN ''' || CAST(V_PREVMONTH AS VARCHAR(10)) || '''::DATE ELSE ''' || CAST(V_CURRDATE AS VARCHAR(10)) || '''::DATE END        
    AND A.DEFAULT_FLAG::INT = 1 AND D.LGD_UNIQUE_ID IS NULL   
    AND C.ACTIVE_FLAG = 1       
    AND C.IS_DELETE = 0';
    EXECUTE (V_STR_QUERY);

    V_STR_QUERY := '';
    V_STR_QUERY := V_STR_QUERY || 'UPDATE CURE_LGL_' || P_RUNID || ' A           
    SET LIQUIDATED_FLAG = 0                  
    FROM ' || V_TABLELGDCONFIG || ' B           
    WHERE A.LGD_RULE_ID = B.PKID AND A.DEFAULT_RULE_ID = B.DEFAULT_RULE_ID        
    AND A.DOWNLOAD_DATE = CASE WHEN B.LAG_1MONTH_FLAG = 1 THEN ''' || CAST(V_PREVMONTH AS VARCHAR(10)) || '''::DATE ELSE ''' || CAST(V_CURRDATE AS VARCHAR(10)) || '''::DATE END        
    AND (RIGHT(DEFAULT_MOVEMENT, 1)::INT <> 2 AND LIQUIDATED_FLAG=1)
    AND B.ACTIVE_FLAG = 1        
    AND B.IS_DELETE = 0';
    EXECUTE (V_STR_QUERY);

    V_STR_QUERY := '';
    V_STR_QUERY := V_STR_QUERY || 'UPDATE CURE_LGL_' || P_RUNID || ' A           
    SET LIQUIDATED_FLAG = 1                    
    FROM ' || V_TABLELGDCONFIG || ' B           
    WHERE A.LGD_RULE_ID = B.PKID AND A.DEFAULT_RULE_ID = B.DEFAULT_RULE_ID        
    AND A.DOWNLOAD_DATE = CASE WHEN B.LAG_1MONTH_FLAG = 1 THEN ''' || CAST(V_PREVMONTH AS VARCHAR(10)) || '''::DATE ELSE ''' || CAST(V_CURRDATE AS VARCHAR(10)) || '''::DATE END        
    AND (DEFAULT_MOVEMENT LIKE ''%12%'' OR (LAST_DPD > 180 AND RIGHT(DEFAULT_MOVEMENT, 1)::INT = 1 AND (COALESCE(WO_FLAG,0)=1 OR COALESCE(RESTRU_SIFAT_FLAG,0)=1 OR COALESCE(FP_FLAG_ORIG,0)=1)  )           
    OR ((DEFAULT_MOVEMENT LIKE ''%02%'' OR RIGHT(DEFAULT_MOVEMENT, 1)::INT = 0) AND LAST_DPD>90))           
    AND B.ACTIVE_FLAG = 1          
    AND B.IS_DELETE = 0';
    EXECUTE (V_STR_QUERY);

    V_STR_QUERY := '';
    V_STR_QUERY := V_STR_QUERY || 'ALTER TABLE CURE_LGL_' || P_RUNID || ' ADD MOD INT';
    EXECUTE (V_STR_QUERY);

    V_STR_QUERY := '';
    V_STR_QUERY := V_STR_QUERY || 'UPDATE CURE_LGL_' || P_RUNID || ' A             
    SET MOD = FLOOR(ABS((EXTRACT(MONTH FROM AGE(A.DOWNLOAD_DATE, A.LOAN_START_DATE)))::INT) % B.CURED_DEFINITION) + 1                       
    FROM ' || V_TABLELGDCONFIG || ' B         
    WHERE A.LGD_RULE_ID = B.PKID AND A.DEFAULT_RULE_ID = B.DEFAULT_RULE_ID
    AND B.ACTIVE_FLAG = 1  AND B.IS_DELETE = 0';
    EXECUTE (V_STR_QUERY);

    V_STR_QUERY := '';
    V_STR_QUERY := V_STR_QUERY || ' UPDATE CURE_LGL_' || P_RUNID || ' A           
    SET PENDING_FLAG = 1           
    FROM ' || V_TABLELGDCONFIG || ' B           
    WHERE A.LGD_RULE_ID = B.PKID AND A.DEFAULT_RULE_ID = B.DEFAULT_RULE_ID        
    AND A.DOWNLOAD_DATE = CASE WHEN B.LAG_1MONTH_FLAG = 1 THEN ''' || CAST(V_PREVMONTH AS VARCHAR(10)) || '''::DATE ELSE ''' || CAST(V_CURRDATE AS VARCHAR(10)) || '''::DATE END
    AND B.ACTIVE_FLAG = 1 AND B.IS_DELETE = 0        
    AND           
    (           
    (COALESCE(A.LAST_CURE_DATE,''20000131''::DATE)<A.LAST_DEFAULT_DATE AND RIGHT(DEFAULT_MOVEMENT, 1)::INT = 0 AND A.MOD < B.CURED_DEFINITION) OR         
    (RIGHT(DEFAULT_MOVEMENT, 1)::INT = 1)           
    )            
    AND COALESCE(LIQUIDATED_FLAG, 0) <> ''1''';
    EXECUTE (V_STR_QUERY);

    V_STR_QUERY := '';
    V_STR_QUERY := V_STR_QUERY || 'UPDATE CURE_LGL_' || P_RUNID || ' A           
    SET CURE_FLAG = 1           
    FROM ' || V_TABLELGDCONFIG || ' B          
    WHERE A.LGD_RULE_ID = B.PKID AND A.DEFAULT_RULE_ID = B.DEFAULT_RULE_ID        
    AND A.DOWNLOAD_DATE = CASE WHEN B.LAG_1MONTH_FLAG = 1 THEN ''' || CAST(V_PREVMONTH AS VARCHAR(10)) || '''::DATE ELSE ''' || CAST(V_CURRDATE AS VARCHAR(10)) || '''::DATE END
    AND B.ACTIVE_FLAG = 1 AND B.IS_DELETE = 0    
    AND            
    (          
    (           
    (A.DEFAULT_MOVEMENT LIKE ''%10%'')           
    AND A.LAST_DPD <= 90          
    AND COALESCE(A.PENDING_FLAG,0)=0        
    )           
    OR (DEFAULT_MOVEMENT LIKE ''%02%'' AND LAST_DPD <= 90)         
    )          
    AND     
    COALESCE(A.LIQUIDATED_FLAG,0)=0';
    EXECUTE (V_STR_QUERY);

    V_STR_QUERY := '';
    V_STR_QUERY := V_STR_QUERY || 'UPDATE CURE_LGL_' || P_RUNID || ' A           
    SET FINAL_STATUS =        
    CASE        
    WHEN COALESCE(LIQUIDATED_FLAG, 0) = 1 AND COALESCE(CURE_FLAG, 0) = 0 AND COALESCE(PENDING_FLAG, 0) = 0 THEN ''LIQUIDATED''        
    WHEN COALESCE(LIQUIDATED_FLAG, 0) = 0 AND COALESCE(CURE_FLAG, 0) = 1 AND COALESCE(PENDING_FLAG, 0) = 0 THEN ''CURE''             
    WHEN COALESCE(LIQUIDATED_FLAG, 0) = 0 AND COALESCE(CURE_FLAG, 0) = 0 AND COALESCE(PENDING_FLAG, 0) = 1 THEN ''PENDING''          
    WHEN COALESCE(LIQUIDATED_FLAG, 0) = 0 AND COALESCE(CURE_FLAG, 0) = 1 AND COALESCE(PENDING_FLAG, 0) = 1 THEN ''CURE & PENDING''          
    WHEN COALESCE(LIQUIDATED_FLAG, 0) = 1 AND COALESCE(CURE_FLAG, 0) = 1 AND COALESCE(PENDING_FLAG, 0) = 0 THEN ''CURE & LIQUIDATED''        
    END,             
    LAST_CURE_DATE =        
    CASE        
    WHEN COALESCE(CURE_FLAG, 0) = 1 AND COALESCE(PENDING_FLAG, 0) = 0 AND COALESCE(LIQUIDATED_FLAG, 0) = 0 THEN A.DOWNLOAD_DATE        
    ELSE A.LAST_CURE_DATE          
    END             
    FROM ' || V_TABLELGDCONFIG || ' B           
    WHERE A.LGD_RULE_ID = B.PKID AND A.DEFAULT_RULE_ID = B.DEFAULT_RULE_ID        
    AND A.DOWNLOAD_DATE = CASE WHEN B.LAG_1MONTH_FLAG = 1 THEN ''' || CAST(V_PREVMONTH AS VARCHAR(10)) || '''::DATE ELSE ''' || CAST(V_CURRDATE AS VARCHAR(10)) || '''::DATE END
    AND B.ACTIVE_FLAG = 1 AND B.IS_DELETE = 0';
    EXECUTE (V_STR_QUERY);

    V_STR_QUERY := '';
    V_STR_QUERY := V_STR_QUERY || ' UPDATE CURE_LGL_' || P_RUNID || ' A           
    SET MOVEMENT_OS = CASE WHEN (COALESCE(A.OS_LAST_DEFAULT, 0) - COALESCE(A.LAST_OS, 0)) <= 0 THEN 0 ELSE COALESCE(A.OS_LAST_DEFAULT, 0) - COALESCE(A.LAST_OS, 0) END           
    FROM ' || V_TABLELGDCONFIG || ' B           
    WHERE A.LGD_RULE_ID = B.PKID AND A.DEFAULT_RULE_ID = B.DEFAULT_RULE_ID         
    AND A.DOWNLOAD_DATE = CASE WHEN B.LAG_1MONTH_FLAG = 1 THEN ''' || CAST(V_PREVMONTH AS VARCHAR(10)) || '''::DATE ELSE ''' || CAST(V_CURRDATE AS VARCHAR(10)) || '''::DATE END        
    AND A.FINAL_STATUS NOT IN (''CURE'')          
    AND ((COALESCE(B.EXCLUDE_RESTRUCTURE_FLAG, 0) = 1 AND COALESCE(A.RESTRU_SIFAT_FLAG, 0) <> 1) OR (COALESCE(B.EXCLUDE_RESTRUCTURE_FLAG, 0) = 0))
    AND B.ACTIVE_FLAG = 1 AND B.IS_DELETE = 0';
    EXECUTE (V_STR_QUERY);

    V_STR_QUERY := '';
    V_STR_QUERY := V_STR_QUERY || ' UPDATE CURE_LGL_' || P_RUNID || ' A           
    SET RECOVERY_FP = CASE WHEN (COALESCE(A.LAST_OS, 0) - COALESCE(A.WO_AMOUNT, 0)) <= 0 THEN 0 ELSE COALESCE(A.LAST_OS, 0) - COALESCE(A.WO_AMOUNT, 0) END          
    FROM ' || V_TABLELGDCONFIG || ' B           
    WHERE A.LGD_RULE_ID = B.PKID AND A.DEFAULT_RULE_ID = B.DEFAULT_RULE_ID         
    AND A.DOWNLOAD_DATE = CASE WHEN B.LAG_1MONTH_FLAG = 1 THEN ''' || CAST(V_PREVMONTH AS VARCHAR(10)) || '''::DATE ELSE ''' || CAST(V_CURRDATE AS VARCHAR(10)) || '''::DATE END        
    AND A.LAST_DPD <= 180           
    AND A.WO_DATE IS NULL           
    AND FINAL_STATUS IN (''CURE & LIQUIDATED'', ''LIQUIDATED'')           
    AND ((COALESCE(B.EXCLUDE_RESTRUCTURE_FLAG, 0) = 1 AND COALESCE(A.RESTRU_SIFAT_FLAG, 0) <> 1) OR (COALESCE(B.EXCLUDE_RESTRUCTURE_FLAG, 0) = 0))
    AND B.ACTIVE_FLAG = 1 AND B.IS_DELETE = 0';
    EXECUTE (V_STR_QUERY);

    V_STR_QUERY := '';
    V_STR_QUERY := V_STR_QUERY || 'UPDATE CURE_LGL_' || P_RUNID || ' A           
    SET RECOVERY_LOS_WO = CASE WHEN (COALESCE(A.LAST_OS, 0) - COALESCE(A.WO_AMOUNT, 0)) <= 0 THEN 0 ELSE COALESCE(A.LAST_OS, 0) - COALESCE(A.WO_AMOUNT, 0) END         
    FROM ' || V_TABLELGDCONFIG || ' B           
    WHERE A.LGD_RULE_ID = B.PKID AND A.DEFAULT_RULE_ID = B.DEFAULT_RULE_ID         
    AND A.DOWNLOAD_DATE = CASE WHEN B.LAG_1MONTH_FLAG = 1 THEN ''' || CAST(V_PREVMONTH AS VARCHAR(10)) || '''::DATE ELSE ''' || CAST(V_CURRDATE AS VARCHAR(10)) || '''::DATE END        
    AND A.WO_DATE IS NOT NULL        
    AND FINAL_STATUS NOT IN (''CURE'')
    AND B.ACTIVE_FLAG = 1 AND B.IS_DELETE = 0';
    EXECUTE (V_STR_QUERY);
      
    V_STR_QUERY := '';
    V_STR_QUERY := V_STR_QUERY || 'UPDATE CURE_LGL_' || P_RUNID || ' A           
    SET TOTAL_RECOVERY = COALESCE(A.MOVEMENT_OS, 0) + COALESCE(RECOVERY_FP, 0) + COALESCE(RECOVERY_LOS_WO, 0) + COALESCE(RECOVERY_WO, 0),          
    LGL = CASE WHEN A.OS_AT_DEFAULT <= 0 THEN 0 ELSE CAST(1.00 - (CAST((COALESCE(A.MOVEMENT_OS, 0) + COALESCE(RECOVERY_FP, 0) + COALESCE(RECOVERY_LOS_WO, 0) + COALESCE(RECOVERY_WO, 0)) AS FLOAT) / CAST(COALESCE(A.OS_AT_DEFAULT, 0) AS FLOAT)) AS FLOAT) END,
    DISC_MOVEMENT_OS =        
    CAST(CASE        
    WHEN (EXTRACT(MONTH FROM AGE(A.DEFAULT_DATE, LAST_SNAPSHOT_DATE))::INT <= 12) THEN A.MOVEMENT_OS             
    ELSE CAST(CAST(A.MOVEMENT_OS AS FLOAT) / CAST((POWER((1.00 + A.AVG_EIR), (CAST(EXTRACT(MONTH FROM AGE(A.DEFAULT_DATE, LAST_SNAPSHOT_DATE))::INT AS FLOAT) / 12.00))) AS FLOAT) AS FLOAT)          
    END AS FLOAT),           
    DISC_RECOVERY_FP =        
    CAST(CASE         
    WHEN (EXTRACT(MONTH FROM AGE(A.DEFAULT_DATE, LAST_SNAPSHOT_DATE))::INT <= 12) THEN A.RECOVERY_FP        
    ELSE CAST(CAST(A.RECOVERY_FP AS FLOAT) / CAST((POWER((1.00 + A.AVG_EIR), (CAST(EXTRACT(MONTH FROM AGE(A.DEFAULT_DATE, LAST_SNAPSHOT_DATE))::INT AS FLOAT) / 12.00))) AS FLOAT) AS FLOAT)
    END AS FLOAT),           
    DISC_RECOVERY_LOS_WO =        
    CAST(CASE        
    WHEN (EXTRACT(MONTH FROM AGE(A.DEFAULT_DATE, LAST_SNAPSHOT_DATE))::INT <= 12) THEN A.RECOVERY_LOS_WO          
    ELSE CAST(CAST(A.RECOVERY_LOS_WO AS FLOAT) / CAST((POWER((1.00 + A.AVG_EIR), (CAST(EXTRACT(MONTH FROM AGE(A.DEFAULT_DATE, LAST_SNAPSHOT_DATE))::INT AS FLOAT) / 12.00))) AS FLOAT) AS FLOAT)
    END AS FLOAT),           
    DISC_TOTAL_RECOVERY =          
    CAST(COALESCE(CASE          
    WHEN (EXTRACT(MONTH FROM AGE(A.DEFAULT_DATE, LAST_SNAPSHOT_DATE))::INT <= 12) THEN A.MOVEMENT_OS          
    ELSE CAST(CAST(A.MOVEMENT_OS AS FLOAT) / CAST((POWER((1.00 + A.AVG_EIR), (CAST(EXTRACT(MONTH FROM AGE(A.DEFAULT_DATE, LAST_SNAPSHOT_DATE))::INT AS FLOAT) / 12.00))) AS FLOAT) AS FLOAT)
    END, 0) AS FLOAT) +         
    CAST(COALESCE(CASE          
    WHEN (EXTRACT(MONTH FROM AGE(A.DEFAULT_DATE, LAST_SNAPSHOT_DATE))::INT <= 12) THEN A.RECOVERY_FP           
    ELSE CAST(CAST(A.RECOVERY_FP AS FLOAT) / CAST((POWER((1.00 + A.AVG_EIR), (CAST(EXTRACT(MONTH FROM AGE(A.DEFAULT_DATE, LAST_SNAPSHOT_DATE))::INT AS FLOAT) / 12.00))) AS FLOAT) AS FLOAT)
    END, 0) AS FLOAT) +         
    CAST(COALESCE(CASE        
    WHEN (EXTRACT(MONTH FROM AGE(A.DEFAULT_DATE, LAST_SNAPSHOT_DATE))::INT <= 12) THEN A.RECOVERY_LOS_WO           
    ELSE CAST(CAST(A.RECOVERY_FP AS FLOAT) / CAST((POWER((1.00 + A.AVG_EIR), (CAST(EXTRACT(MONTH FROM AGE(A.DEFAULT_DATE, LAST_SNAPSHOT_DATE))::INT AS FLOAT) / 12.00))) AS FLOAT) AS FLOAT)
	END, 0) AS FLOAT) + COALESCE(A.DISC_RECOVERY_WO, 0)          
    FROM ' || V_TABLELGDCONFIG || ' B           
    WHERE A.LGD_RULE_ID = B.PKID AND A.DEFAULT_RULE_ID = B.DEFAULT_RULE_ID         
    AND A.DOWNLOAD_DATE = CASE WHEN B.LAG_1MONTH_FLAG = 1 THEN ''' || CAST(V_PREVMONTH AS VARCHAR(10)) || '''::DATE ELSE ''' || CAST(V_CURRDATE AS VARCHAR(10)) || '''::DATE END 
    AND B.ACTIVE_FLAG = 1 AND B.IS_DELETE = 0';
    EXECUTE (V_STR_QUERY);

    V_STR_QUERY := '';
    V_STR_QUERY := V_STR_QUERY || 'INSERT INTO ' || V_TABLEINSERT4 || '           
    (           
    DOWNLOAD_DATE             
    ,LGD_RULE_ID         
    ,LGD_RULE_NAME             
    ,DEFAULT_RULE_ID             
    ,LGD_UNIQUE_ID             
    ,SEGMENT             
    ,SUB_SEGMENT             
    ,GROUP_SEGMENT             
    ,EIR_SEGMENT             
    ,CALC_METHOD             
    ,LOAN_START_DATE             
    ,RESTRU_SIFAT_FLAG             
    ,WO_DATE             
    ,WO_AMOUNT             
    ,RECOVERY_WO_MTD             
    ,RECOVERY_WO             
    ,OS_AT_DEFAULT          
    ,OS_LAST_DEFAULT             
    ,LAST_OS             
    ,LAST_SNAPSHOT_DATE             
    ,LAST_DPD             
    ,AVG_EIR             
    ,DEFAULT_FLAG             
    ,DEFAULT_DATE             
    ,DEFAULT_MOVEMENT             
    ,CURE_FLAG             
    ,LIQUIDATED_FLAG        
    ,PENDING_FLAG             
    ,FINAL_STATUS             
    ,MOVEMENT_OS             
    ,RECOVERY_FP             
    ,RECOVERY_LOS_WO             
    ,TOTAL_RECOVERY             
    ,LGL             
    ,DISC_MOVEMENT_OS             
    ,DISC_RECOVERY_FP             
    ,DISC_RECOVERY_LOS_WO             
    ,DISC_RECOVERY_WO_MTD          
    ,DISC_RECOVERY_WO             
    ,DISC_TOTAL_RECOVERY             
    ,DISC_LGL          
    ,LAST_DEFAULT_DATE          
    ,LAST_CURE_DATE        
    ,WO_FLAG         
    ,FP_FLAG_ORIG          
    )           
    SELECT        
    DOWNLOAD_DATE             
    ,LGD_RULE_ID             
    ,LGD_RULE_NAME             
    ,DEFAULT_RULE_ID             
    ,LGD_UNIQUE_ID             
    ,SEGMENT             
    ,SUB_SEGMENT             
    ,GROUP_SEGMENT             
    ,EIR_SEGMENT             
    ,CALC_METHOD             
    ,LOAN_START_DATE             
    ,RESTRU_SIFAT_FLAG             
    ,WO_DATE          
    ,COALESCE(WO_AMOUNT, 0) AS WO_AMOUNT            
    ,COALESCE(RECOVERY_WO_MTD, 0) AS RECOVERY_WO_MTD         
    ,COALESCE(RECOVERY_WO, 0) AS RECOVERY_WO            
    ,OS_AT_DEFAULT        
    ,OS_LAST_DEFAULT             
    ,LAST_OS             
    ,LAST_SNAPSHOT_DATE             
    ,LAST_DPD             
    ,AVG_EIR             
    ,DEFAULT_FLAG             
    ,DEFAULT_DATE             
    ,DEFAULT_MOVEMENT         
    ,COALESCE(CURE_FLAG, 0) AS CURE_FLAG             
    ,COALESCE(LIQUIDATED_FLAG, 0) AS LIQUIDATED_FLAG             
    ,COALESCE(PENDING_FLAG, 0) AS PENDING_FLAG             
    ,FINAL_STATUS             
    ,COALESCE(MOVEMENT_OS, 0) AS MOVEMENT_OS             
    ,COALESCE(RECOVERY_FP, 0) AS RECOVERY_FP             
    ,COALESCE(RECOVERY_LOS_WO, 0) AS RECOVERY_LOS_WO             
    ,COALESCE(TOTAL_RECOVERY, 0) AS TOTAL_RECOVERY             
    ,CASE WHEN COALESCE(LGL, 0) < 0 THEN 0 ELSE CASE WHEN COALESCE(LGL, 0) > 1 THEN 1 ELSE COALESCE(LGL, 0) END END AS LGL          
    ,COALESCE(DISC_MOVEMENT_OS, 0) AS DISC_MOVEMENT_OS             
    ,COALESCE(DISC_RECOVERY_FP, 0) AS DISC_RECOVERY_FP             
    ,COALESCE(DISC_RECOVERY_LOS_WO, 0) AS DISC_RECOVERY_LOS_WO             
    ,COALESCE(DISC_RECOVERY_WO_MTD, 0) AS DISC_RECOVERY_WO_MTD             
    ,COALESCE(DISC_RECOVERY_WO, 0) AS DISC_RECOVERY_WO             
    ,COALESCE(DISC_TOTAL_RECOVERY, 0) AS DISC_TOTAL_RECOVERY
    ,CASE  
    WHEN OS_AT_DEFAULT <= 0 THEN 0   
    WHEN CAST(1 - CAST((CAST(DISC_TOTAL_RECOVERY AS FLOAT) / CAST(OS_AT_DEFAULT AS FLOAT)) AS FLOAT) AS FLOAT) < 0 THEN 0   
    ELSE CASE   
    WHEN CAST(1 - CAST((CAST(DISC_TOTAL_RECOVERY AS FLOAT) / CAST(OS_AT_DEFAULT AS FLOAT)) AS FLOAT) AS FLOAT) > 1 THEN 1   
    ELSE CAST(1 - CAST((CAST(DISC_TOTAL_RECOVERY AS FLOAT) / CAST(OS_AT_DEFAULT AS FLOAT)) AS FLOAT) AS FLOAT)   
    END   
    END AS DISC_LGL
    ,LAST_DEFAULT_DATE             
    ,LAST_CURE_DATE         
    ,WO_FLAG         
    ,FP_FLAG_ORIG            
    FROM CURE_LGL_' || P_RUNID || '';
    EXECUTE (V_STR_QUERY);

    GET DIAGNOSTICS V_RETURNROWS = ROW_COUNT;
    V_RETURNROWS2 := V_RETURNROWS2 + V_RETURNROWS;
    V_RETURNROWS := 0;

    RAISE NOTICE 'SP_IFRS_IMP_LGD_CURE_LGL_DETAIL | AFFECTED RECORD : %', V_RETURNROWS2;
    -------- ====== BODY ======

    -------- ====== LOG ======
    V_TABLEDEST = V_TABLEINSERT4;
    V_COLUMNDEST = '-';
    V_SPNAME = 'SP_IFRS_IMP_LGD_CURE_LGL_DETAIL';
    V_OPERATION = 'INSERT';
    
    CALL SP_IFRS_EXEC_AND_LOG(V_CURRDATE, V_TABLEDEST, V_COLUMNDEST, V_SPNAME, V_OPERATION, V_RETURNROWS2, P_RUNID);
    -------- ====== LOG ======

    -------- ====== RESULT ======
    V_QUERYS = 'SELECT * FROM ' || V_TABLEINSERT4 || '';
    CALL SP_IFRS_RESULT_PREV(V_CURRDATE, V_QUERYS, V_SPNAME, V_RETURNROWS2, P_RUNID);
    -------- ====== RESULT ======

END;

$$;
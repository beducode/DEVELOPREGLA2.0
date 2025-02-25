---- DROP PROCEDURE SP_IFRS_IMP_CCF_SCENARIO_DATA;

CREATE OR REPLACE PROCEDURE SP_IFRS_IMP_CCF_SCENARIO_DATA(
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
    V_TABLECCFCONFIG VARCHAR(100);

    ---- CONDITION
    V_RETURNROWS INT;
    V_RETURNROWS2 INT;
    V_RETURNROWS3 INT;
    V_RETURNROWS4 INT;
    V_TABLEDEST VARCHAR(100);
    V_COLUMNDEST VARCHAR(100);
    V_SPNAME VARCHAR(100);
    V_OPERATION VARCHAR(100);

    ---- VARIABLE PROCESS
    V_TABLE_NAME VARCHAR(100);
    V_STR_SQL_RULE TEXT;
    V_DATADATE VARCHAR(10);
    V_CCF_RULE_ID VARCHAR(250);        
    V_ID BIGINT= 0;        
    V_MAX_ID BIGINT= 0;        
    V_SEGMENTATION_ID VARCHAR(250);        
    V_SEGMENT_TYPE VARCHAR(250);        
    V_SEGMENT VARCHAR(50);        
    V_SBSEGMENT VARCHAR(50);        
    V_GRPSEGMENT VARCHAR(50);          
    V_CUT_OFF_DATE VARCHAR(10);        
    V_LAG VARCHAR(1);        
    V_CALC_METHOD VARCHAR(20);        
    V_DEFAULT_RULE_ID VARCHAR(10);

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
        V_TABLEINSERT4 := 'IFRS_CCF_SCENARIO_DATA_' || P_RUNID || '';
        V_TABLEINSERT5 := 'IFRS_CCF_SCENARIO_DATA_SUMM_' || P_RUNID || '';
        V_TABLECCFCONFIG  := 'IFRS_CCF_RULES_CONFIG_' || P_RUNID || '';
    ELSE 
        V_TABLENAME := 'IFRS_MASTER_ACCOUNT';
        V_TABLENAME_MON := 'IFRS_MASTER_ACCOUNT_MONTHLY';
        V_TABLEINSERT1 := 'TMP_IFRS_ECL_IMA';
        V_TABLEINSERT2 := 'IFRS_IMA_IMP_CURR';
        V_TABLEINSERT3 := 'IFRS_IMA_IMP_PREV';
        V_TABLEINSERT4 := 'IFRS_CCF_SCENARIO_DATA';
        V_TABLEINSERT5 := 'IFRS_CCF_SCENARIO_DATA_SUMM';
        V_TABLECCFCONFIG  := 'IFRS_CCF_RULES_CONFIG';
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
    V_RETURNROWS4 := 0;
    -------- ====== VARIABLE ======

    -------- ====== PRE SIMULATION TABLE ======
    IF P_PRC = 'S' THEN
        V_STR_QUERY := '';
        V_STR_QUERY := V_STR_QUERY || 'DROP TABLE IF EXISTS ' || V_TABLEINSERT4 || ' ';
        EXECUTE (V_STR_QUERY);

        V_STR_QUERY := '';
        V_STR_QUERY := V_STR_QUERY || 'CREATE TABLE ' || V_TABLEINSERT4 || ' AS SELECT * FROM IFRS_CCF_SCENARIO_DATA WHERE 0=1';
        EXECUTE (V_STR_QUERY);

        V_STR_QUERY := '';
        V_STR_QUERY := V_STR_QUERY || 'DROP TABLE IF EXISTS ' || V_TABLEINSERT5 || ' ';
        EXECUTE (V_STR_QUERY);

        V_STR_QUERY := '';
        V_STR_QUERY := V_STR_QUERY || 'CREATE TABLE ' || V_TABLEINSERT5 || ' AS SELECT * FROM IFRS_CCF_SCENARIO_DATA_SUMM WHERE 0=1';
        EXECUTE (V_STR_QUERY);
    END IF;
    -------- ====== PRE SIMULATION TABLE ======
    
    -------- ====== BODY ======
    V_STR_QUERY := '';
    V_STR_QUERY := V_STR_QUERY || 'DELETE FROM ' || V_TABLEINSERT4 || '         
    WHERE RULE_TYPE = ''CCF_SEGMENT''         
    AND DOWNLOAD_DATE = CASE WHEN COALESCE(LAG_1MONTH_FLAG, 1) = 1 THEN ''' || CAST(V_PREVMONTH AS VARCHAR(10)) || '''::DATE ELSE ''' || CAST(V_CURRDATE AS VARCHAR(10)) || '''::DATE END';
    EXECUTE (V_STR_QUERY);

    V_STR_QUERY := '';
    V_STR_QUERY := V_STR_QUERY || 'DELETE FROM ' || V_TABLEINSERT5 || '              
    WHERE RULE_TYPE = ''CCF_SEGMENT''         
    AND DOWNLOAD_DATE = CASE WHEN COALESCE(LAG_1MONTH_FLAG, 1) = 1 THEN ''' || CAST(V_PREVMONTH AS VARCHAR(10)) || '''::DATE ELSE ''' || CAST(V_CURRDATE AS VARCHAR(10)) || '''::DATE END';
    EXECUTE (V_STR_QUERY);

    V_STR_QUERY := '';
    V_STR_QUERY := V_STR_QUERY || 'DROP TABLE IF EXISTS TMP_CCF_RULES_CONFIG_' || P_RUNID || '';
    EXECUTE (V_STR_QUERY);

    V_STR_QUERY := '';
    V_STR_QUERY := V_STR_QUERY || 'CREATE TEMP TABLE TMP_CCF_RULES_CONFIG_' || P_RUNID || ' AS 
    SELECT        
    PKID,          
    CCF_RULE_NAME,          
    SEGMENTATION_ID,          
    LAG_1MONTH_FLAG,             
    CUT_OFF_DATE,        
    UPPER(CALC_METHOD) AS CALC_METHOD,        
    DEFAULT_RULE_ID,        
    OBSERV_PERIOD_MOVING,        
    OS_DEF_ZERO_EXCLUDE,        
    HEADROOM_ZERO_EXCLUDE
    FROM ' || V_TABLECCFCONFIG || '         
    WHERE ACTIVE_FLAG = 1         
    AND IS_DELETE = 0        
    AND CALC_METHOD <> ''EXT''';
    EXECUTE (V_STR_QUERY);

    V_STR_QUERY := '';
    V_STR_QUERY := V_STR_QUERY || 'DROP TABLE IF EXISTS TMP_IFRS_SCN_GENERATE_QUERY_' || P_RUNID || '';
    EXECUTE (V_STR_QUERY);

    V_STR_QUERY := '';
    V_STR_QUERY := V_STR_QUERY || 'CREATE TEMP TABLE TMP_IFRS_SCN_GENERATE_QUERY_' || P_RUNID || ' AS 
    SELECT ROW_NUMBER() OVER(ORDER BY SEGMENTATION_ID, DATA_DATE) AS ID, *
    FROM         
    (         
    SELECT DISTINCT        
    RULE_ID AS SEGMENTATION_ID,        
    B.PKID AS CCF_RULE_ID,        
    SEGMENT_TYPE,        
    ''' || V_TABLENAME || ''' AS TABLE_NAME,        
    CONDITION,              
    CASE WHEN B.LAG_1MONTH_FLAG = 1 THEN ''' || CAST(V_PREVMONTH AS VARCHAR(10)) || '''::DATE ELSE ''' || CAST(V_CURRDATE AS VARCHAR(10)) || '''::DATE END AS DATA_DATE,          
    CCF_RULE_NAME AS SEGMENT,        
    SUB_SEGMENT,              
    GROUP_SEGMENT,        
    CUT_OFF_DATE,        
    LAG_1MONTH_FLAG,        
    B.CALC_METHOD,        
    DEFAULT_RULE_ID        
    FROM IFRS_SCENARIO_SEGMENT_GENERATE_QUERY A         
    JOIN TMP_CCF_RULES_CONFIG_' || P_RUNID || ' B ON A.RULE_ID = B.SEGMENTATION_ID           
    WHERE A.SEGMENT_TYPE = ''CCF_SEGMENT''               
    ) TMP';
    EXECUTE (V_STR_QUERY);

    EXECUTE 'SELECT MAX(ID) FROM TMP_IFRS_SCN_GENERATE_QUERY_' || P_RUNID || '' INTO V_MAX_ID;

    WHILE V_ID < V_MAX_ID
    LOOP
        EXECUTE 'SELECT MIN(ID) FROM TMP_IFRS_SCN_GENERATE_QUERY_' || P_RUNID || ' WHERE ID > ' || V_ID || '' INTO V_ID;

        EXECUTE 'SELECT        
        SEGMENTATION_ID,        
        CCF_RULE_ID,        
        SEGMENT_TYPE,        
        TABLE_NAME,        
        CONDITION,           
        DATA_DATE,        
        SEGMENT,        
        SUB_SEGMENT,        
        GROUP_SEGMENT,          
        CUT_OFF_DATE,        
        CALC_METHOD,        
        LAG_1MONTH_FLAG,        
        DEFAULT_RULE_ID        
        FROM TMP_IFRS_SCN_GENERATE_QUERY_' || P_RUNID || '         
        WHERE ID = ' || V_ID || '         
        AND SEGMENT_TYPE = ''CCF_SEGMENT''' INTO V_SEGMENTATION_ID
        , V_CCF_RULE_ID
        , V_SEGMENT_TYPE
        , V_TABLE_NAME
        , V_STR_SQL_RULE
        , V_DATADATE
        , V_SEGMENT
        , V_SBSEGMENT
        , V_GRPSEGMENT
        , V_CUT_OFF_DATE
        , V_CALC_METHOD
        , V_LAG
        , V_DEFAULT_RULE_ID;

        V_STR_QUERY := '';
        V_STR_QUERY := V_STR_QUERY || 'INSERT INTO ' || V_TABLEINSERT4 || '        
        (        
        DOWNLOAD_DATE        
        ,CCF_RULE_ID     
        ,DEFAULT_RULE_ID        
        ,SEQUENCE        
        ,SEGMENT        
        ,SUB_SEGMENT        
        ,GROUP_SEGMENT        
        ,RULE_TYPE        
        ,MASTERID        
        ,CUSTOMER_NUMBER        
        ,CUSTOMER_NAME        
        ,FACILITY_NUMBER        
        ,PLAFOND        
        ,OUTSTANDING        
        ,EXCHANGE_RATE        
        ,BI_COLLECTABILITY        
        ,SOURCE_PROCESS        
        ,REVOLVING_FLAG        
        ,CCF_UNIQUE_ID        
        ,CALC_METHOD        
        ,LAG_1MONTH_FLAG        
        ,CURRENCY        
        ,LIMIT_CURRENCY        
        )        
        SELECT         
        A.DOWNLOAD_DATE,        
        ' || V_CCF_RULE_ID || ' AS CCF_RULE_ID,         
        ' || V_DEFAULT_RULE_ID || ' AS DEFAULT_RULE_ID,        
        ' || V_SEGMENTATION_ID || ' AS SEQUENCE,         
        ''' || V_SEGMENT || ''' AS SEGMENT,        
        ''' || V_SBSEGMENT || ''' AS SUB_SEGMENT,        
        ''' || V_GRPSEGMENT || ''' AS GROUP_SEGMENT,         
        ''' || V_SEGMENT_TYPE || ''' AS RULE_TYPE,        
        A.MASTERID,        
        A.CUSTOMER_NUMBER,        
        A.CUSTOMER_NAME,        
        CASE WHEN A.FACILITY_NUMBER IS NULL AND A.PRODUCT_TYPE_1 =''PRK'' THEN A.MASTERID ELSE A.FACILITY_NUMBER END AS FACILITY_NUMBER,        
        A.PLAFOND,        
        A.OUTSTANDING,        
        COALESCE(A.EXCHANGE_RATE, B.RATE_AMOUNT) AS EXCHANGE_RATE,        
        A.BI_COLLECTABILITY,        
        ''SP_IFRS_IMP_CCF_RULE_DATA_CIF'' AS SOURCE_PROCESS,        
        A.REVOLVING_FLAG,        
        ' || CASE V_CALC_METHOD WHEN 'CUSTOMER' THEN 'A.CUSTOMER_NUMBER' WHEN 'ACCOUNT' THEN 'A.MASTERID' WHEN 'FACILITY' THEN 'A.FACILITY_NUMBER' END || ' AS CCF_UNIQUE_ID,        
        ''' || V_CALC_METHOD || ''' AS CALC_METHOD,        
        ''' || V_LAG || ''' AS LAG_1MONTH_FLAG,        
        A.CURRENCY,        
        A.LIMIT_CURRENCY        
        FROM  ' || V_TABLE_NAME || ' A       
        LEFT JOIN IFRS_MASTER_EXCHANGE_RATE B        
        ON A.DOWNLOAD_DATE = B.DOWNLOAD_DATE AND A.CURRENCY = B.CURRENCY        
        WHERE  
        A.DOWNLOAD_DATE =  ''' || CAST(V_DATADATE AS VARCHAR(10)) || '''::DATE         
        AND A.ACCOUNT_STATUS = ''A''             
        AND CASE WHEN A.FACILITY_NUMBER IS NULL AND A.PRODUCT_TYPE_1 =''PRK'' THEN A.MASTERID ELSE A.FACILITY_NUMBER END IS NOT NULL   
        ' || CASE WHEN V_GRPSEGMENT LIKE '%JENIUS%' THEN 'AND A.CUSTOMER_NUMBER NOT IN (SELECT DISTINCT CUSTOMER_NUMBER FROM IFRS_EXCLUDE_JENIUS) ' ELSE '' END || ' AND (' || RTRIM(COALESCE(REPLACE(V_STR_SQL_RULE,'"',''), '')) || ')' || '';
        EXECUTE (V_STR_QUERY);

        GET DIAGNOSTICS V_RETURNROWS = ROW_COUNT;
        V_RETURNROWS2 := V_RETURNROWS2 + V_RETURNROWS;
        V_RETURNROWS := 0;

    END LOOP;

    V_STR_QUERY := '';
    V_STR_QUERY := V_STR_QUERY || 'INSERT INTO ' || V_TABLEINSERT5 || '        
    (        
    DOWNLOAD_DATE,        
    CCF_UNIQUE_ID,        
    CCF_RULE_ID,        
    DEFAULT_RULE_ID,        
    DEFAULT_FLAG,        
    SEQUENCE,        
    SEGMENT,        
    SUB_SEGMENT,        
    GROUP_SEGMENT,        
    RULE_TYPE,        
    CUSTOMER_NAME,        
    FACILITY_NUMBER,        
    PLAFOND,        
    OUTSTANDING,        
    EXCHANGE_RATE,        
    SOURCE_PROCESS,        
    LAG_1MONTH_FLAG,        
    CALC_METHOD,        
    CURRENCY,        
    LIMIT_CURRENCY        
    )        
    SELECT        
    DOWNLOAD_DATE,        
    CCF_UNIQUE_ID,        
    CCF_RULE_ID,        
    DEFAULT_RULE_ID,        
    DEFAULT_FLAG,        
    SEQUENCE,        
    SEGMENT,        
    SUB_SEGMENT,        
    GROUP_SEGMENT,        
    RULE_TYPE,        
    MAX(CUSTOMER_NAME) AS CUSTOMER_NAME,        
    MAX(FACILITY_NUMBER) AS FACILITY_NUMBER,        
    SUM(PLAFOND) AS PLAFOND,        
    SUM(OUTSTANDING) AS OUTSTANDING,        
    EXCHANGE_RATE,        
    SOURCE_PROCESS,        
    LAG_1MONTH_FLAG,        
    CALC_METHOD,        
    CURRENCY,        
    LIMIT_CURRENCY        
    FROM        
    (         
    SELECT        
    DOWNLOAD_DATE,        
    CCF_UNIQUE_ID,        
    CCF_RULE_ID,        
    A.DEFAULT_RULE_ID,        
    DEFAULT_FLAG,        
    SEQUENCE,        
    SEGMENT,        
    SUB_SEGMENT,        
    GROUP_SEGMENT,        
    RULE_TYPE,        
    MAX(CUSTOMER_NAME) AS CUSTOMER_NAME,        
    FACILITY_NUMBER,        
    MAX(PLAFOND) AS PLAFOND,        
    SUM(OUTSTANDING) AS OUTSTANDING,        
    EXCHANGE_RATE,        
    SOURCE_PROCESS,        
    A.LAG_1MONTH_FLAG,        
    A.CALC_METHOD,        
    A.CURRENCY,        
    A.LIMIT_CURRENCY        
    FROM ' || V_TABLEINSERT4 || ' A        
    JOIN ' || V_TABLECCFCONFIG || ' B ON A.CCF_RULE_ID = B.PKID AND A.DEFAULT_RULE_ID = B.DEFAULT_RULE_ID        
    WHERE DOWNLOAD_DATE = CASE WHEN A.LAG_1MONTH_FLAG = 1 THEN ''' || CAST(V_PREVMONTH AS VARCHAR(10)) || '''::DATE ELSE ''' || CAST(V_CURRDATE AS VARCHAR(10)) || '''::DATE END              
    GROUP BY        
    DOWNLOAD_DATE,        
    CCF_UNIQUE_ID,        
    CCF_RULE_ID,        
    A.DEFAULT_RULE_ID,        
    DEFAULT_FLAG,        
    SEQUENCE,        
    SEGMENT,        
    SUB_SEGMENT,        
    GROUP_SEGMENT,        
    RULE_TYPE,            
    FACILITY_NUMBER,         
    EXCHANGE_RATE,        
    SOURCE_PROCESS,        
    A.LAG_1MONTH_FLAG,        
    A.CALC_METHOD,        
    A.CURRENCY,        
    A.LIMIT_CURRENCY        
    ) X        
    GROUP BY         
    DOWNLOAD_DATE,        
    CCF_UNIQUE_ID,        
    CCF_RULE_ID,        
    DEFAULT_RULE_ID,        
    DEFAULT_FLAG,        
    SEQUENCE,        
    SEGMENT,        
    SUB_SEGMENT,        
    GROUP_SEGMENT,        
    RULE_TYPE,        
    EXCHANGE_RATE,        
    SOURCE_PROCESS,        
    LAG_1MONTH_FLAG,        
    CALC_METHOD,        
    CURRENCY,        
    LIMIT_CURRENCY';
    EXECUTE (V_STR_QUERY);

    GET DIAGNOSTICS V_RETURNROWS3 = ROW_COUNT;
    V_RETURNROWS4 := V_RETURNROWS4 + V_RETURNROWS3;
    V_RETURNROWS3 := 0;

    V_STR_QUERY := '';
    V_STR_QUERY := V_STR_QUERY || 'UPDATE ' || V_TABLEINSERT5 || ' A 
    SET DEFAULT_FLAG = CASE WHEN CASE A.CALC_METHOD WHEN ''ACCOUNT'' THEN B.MASTERID WHEN ''CUSTOMER'' THEN B.CUSTOMER_NUMBER WHEN ''FACILITY'' THEN B.FACILITY_NUMBER END IS NOT NULL THEN 1 ELSE 0 END        
    FROM IFRS_DEFAULT_NOLAG B          
    WHERE A.DOWNLOAD_DATE = B.DOWNLOAD_DATE        
    AND A.CCF_UNIQUE_ID = CASE A.CALC_METHOD WHEN ''ACCOUNT'' THEN B.MASTERID WHEN ''CUSTOMER'' THEN B.CUSTOMER_NUMBER WHEN ''FACILITY'' THEN B.FACILITY_NUMBER END        
    AND A.DEFAULT_RULE_ID = B.RULE_ID         
    AND A.DOWNLOAD_DATE = CASE WHEN A.LAG_1MONTH_FLAG = 1 THEN ''' || CAST(V_PREVMONTH AS VARCHAR(10)) || '''::DATE ELSE ''' || CAST(V_CURRDATE AS VARCHAR(10)) || '''::DATE END        
    AND COALESCE(A.LAG_1MONTH_FLAG, 0) = 0 ';
    EXECUTE (V_STR_QUERY);

    V_STR_QUERY := '';
    V_STR_QUERY := V_STR_QUERY || ';WITH CTE_CUSTNO AS (
    SELECT DISTINCT DOWNLOAD_DATE,CUSTOMER_NUMBER,RULE_ID  
    FROM IFRS_DEFAULT WHERE DOWNLOAD_DATE = ''' || CAST(V_PREVMONTH AS VARCHAR(10)) || '''::DATE
    ),
    CTE_FACILITY AS (
    SELECT DISTINCT DOWNLOAD_DATE, FACILITY_NUMBER,RULE_ID FROM IFRS_DEFAULT WHERE DOWNLOAD_DATE = ''' || CAST(V_PREVMONTH AS VARCHAR(10)) || '''::DATE
    ),
    CTE_ACCOUNT AS (
    SELECT DOWNLOAD_DATE, MASTERID,RULE_ID FROM IFRS_DEFAULT WHERE DOWNLOAD_DATE = ''' || CAST(V_PREVMONTH AS VARCHAR(10)) || '''::DATE
    )

    UPDATE ' || V_TABLEINSERT5 || ' A 
    SET DEFAULT_FLAG = CASE WHEN CASE A.CALC_METHOD WHEN ''ACCOUNT'' THEN ACT.MASTERID WHEN ''CUSTOMER'' THEN CUST.CUSTOMER_NUMBER WHEN ''FACILITY'' THEN FAC.FACILITY_NUMBER END IS NOT NULL THEN 1 ELSE 0 END  
    FROM CTE_ACCOUNT AS ACT, CTE_CUSTNO AS CUST, CTE_FACILITY AS FAC 
    WHERE A.CCF_UNIQUE_ID = FAC.FACILITY_NUMBER AND A.DEFAULT_RULE_ID = FAC.RULE_ID AND A.DOWNLOAD_DATE = FAC.DOWNLOAD_DATE
    AND A.CCF_UNIQUE_ID = ACT.MASTERID AND A.DEFAULT_RULE_ID = ACT.RULE_ID AND A.DOWNLOAD_DATE = ACT.DOWNLOAD_DATE
    AND A.CCF_UNIQUE_ID = CUST.CUSTOMER_NUMBER AND A.DEFAULT_RULE_ID = CUST.RULE_ID AND A.DOWNLOAD_DATE = CUST.DOWNLOAD_DATE 
    AND A.DOWNLOAD_DATE = CASE WHEN A.LAG_1MONTH_FLAG = 1 THEN ''' || CAST(V_PREVMONTH AS VARCHAR(10)) || '''::DATE ELSE ''' || CAST(V_CURRDATE AS VARCHAR(10)) || '''::DATE END   
    AND COALESCE(A.LAG_1MONTH_FLAG, 0) = 1';
    EXECUTE (V_STR_QUERY);

    RAISE NOTICE 'SP_IFRS_IMP_CCF_SCENARIO_DATA | AFFECTED RECORD : %', V_RETURNROWS4;
    -------- ====== BODY ======

    -------- ====== LOG ======
    V_TABLEDEST = V_TABLEINSERT4;
    V_COLUMNDEST = '-';
    V_SPNAME = 'SP_IFRS_IMP_CCF_SCENARIO_DATA';
    V_OPERATION = 'INSERT';
    
    CALL SP_IFRS_EXEC_AND_LOG(V_CURRDATE, V_TABLEDEST, V_COLUMNDEST, V_SPNAME, V_OPERATION, V_RETURNROWS2, P_RUNID);

    -- V_TABLEDEST = V_TABLEINSERT5;
    -- V_COLUMNDEST = '-';
    -- V_SPNAME = 'SP_IFRS_IMP_CCF_SCENARIO_DATA';
    -- V_OPERATION = 'INSERT';

    -- CALL SP_IFRS_EXEC_AND_LOG(V_CURRDATE, V_TABLEDEST, V_COLUMNDEST, V_SPNAME, V_OPERATION, V_RETURNROWS4, P_RUNID);
    -------- ====== LOG ======

    -------- ====== RESULT ======
    V_QUERYS = 'SELECT * FROM ' || V_TABLEINSERT4 || '';
    CALL SP_IFRS_RESULT_PREV(V_CURRDATE, V_QUERYS, V_SPNAME, V_RETURNROWS2, P_RUNID);
    -------- ====== RESULT ======

END;

$$;
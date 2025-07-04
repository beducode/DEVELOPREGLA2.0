---- DROP PROCEDURE SP_IFRS_IMP_DEFAULT_RULE;

CREATE OR REPLACE PROCEDURE SP_IFRS_IMP_DEFAULT_RULE(
    IN P_RUNID VARCHAR(20) DEFAULT 'S_00000_0000', 
    IN P_DOWNLOAD_DATE DATE DEFAULT NULL,
    IN P_PRC VARCHAR(1) DEFAULT 'S',
    IN P_MODEL_TYPE VARCHAR(10) DEFAULT '')
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
    V_STR_SQL_RULE TEXT;

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
    V_RULE_ID BIGINT;
    V_RULE_CODE1 VARCHAR(250);
    V_RULE_TYPE VARCHAR(25);
    V_PKID INT;
    V_AOC VARCHAR(3);
    V_QG INT;
    V_PREV_QG INT;
    V_NEXT_QG INT;
    V_JML INT;
    V_RN INT;
    V_COLUMN_NAME VARCHAR(250);
    V_DATA_TYPE VARCHAR(250);
    V_OPERATOR VARCHAR(50);
    V_VALUE1 VARCHAR(250);
    V_VALUE2 VARCHAR(250);
    V_TABLE_NAME VARCHAR(30);
    V_UPDATED_TABLE VARCHAR(30);
    V_UPDATED_COLUMN VARCHAR(30);

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

    IF COALESCE(P_MODEL_TYPE, NULL) IS NULL THEN
        P_MODEL_TYPE := '';
    END IF;

    IF P_PRC = 'S' THEN 
        V_TABLENAME := 'TMP_IMA_' || P_RUNID || '';
        V_TABLENAME_MON := 'TMP_IMAM_' || P_RUNID || '';
        V_TABLEINSERT1 := 'TMP_IFRS_ECL_IMA_' || P_RUNID || '';
        V_TABLEINSERT2 := 'IFRS_IMA_IMP_CURR_' || P_RUNID || '';
        V_TABLEINSERT3 := 'IFRS_DEFAULT';
    ELSE 
        V_TABLENAME := 'IFRS_MASTER_ACCOUNT';
        V_TABLENAME_MON := 'IFRS_MASTER_ACCOUNT_MONTHLY';
        V_TABLEINSERT1 := 'TMP_IFRS_ECL_IMA';
        V_TABLEINSERT2 := 'IFRS_IMA_IMP_CURR';
        V_TABLEINSERT3 := 'IFRS_DEFAULT';
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

    -- -------- ====== PRE SIMULATION TABLE ======
    -- IF P_PRC = 'S' THEN
    --     V_STR_QUERY := '';
    --     V_STR_QUERY := V_STR_QUERY || 'DROP TABLE IF EXISTS ' || V_TABLEINSERT3 || ' ';
    --     EXECUTE (V_STR_QUERY);

    --     V_STR_QUERY := '';
    --     V_STR_QUERY := V_STR_QUERY || 'CREATE TABLE ' || V_TABLEINSERT3 || ' AS SELECT * FROM IFRS_DEFAULT WHERE 0=1';
    --     EXECUTE (V_STR_QUERY);
    -- END IF;
    -- -------- ====== PRE SIMULATION TABLE ======
    
    -------- ====== BODY ======
    V_STR_QUERY := '';
    V_STR_QUERY := V_STR_QUERY || 'DROP TABLE IF EXISTS TMPRULE_' || P_RUNID || '';
    EXECUTE (V_STR_QUERY);

    V_STR_QUERY := '';
    V_STR_QUERY := V_STR_QUERY || 'CREATE TABLE TMPRULE_' || P_RUNID || ' AS 
    SELECT DISTINCT B.PKID AS DEFAULT_RULE_ID      
    FROM IFRS_SCENARIO_RULES_HEADER B      
    WHERE B.RULE_TYPE = ''DEFAULT_RULE'' AND IS_DELETE = 0';
    EXECUTE (V_STR_QUERY);

    V_STR_QUERY := '';
    V_STR_QUERY := V_STR_QUERY || 'DELETE FROM IFRS_SCENARIO_GENERATE_QUERY WHERE RULE_TYPE = ''DEFAULT_RULE''';
    EXECUTE (V_STR_QUERY);

    V_STR_QUERY := '';
    V_STR_QUERY := V_STR_QUERY || 'DELETE FROM ' || V_TABLEINSERT3 || ' A      
    USING TMPRULE_' || P_RUNID || ' B      
    WHERE A.RULE_ID = B.DEFAULT_RULE_ID      
    AND A.DOWNLOAD_DATE = ''' || CAST(V_PREVMONTH AS VARCHAR(10)) || '''::DATE';
    EXECUTE (V_STR_QUERY);

    FOR V_UPDATED_TABLE, V_UPDATED_COLUMN, V_RULE_TYPE, V_TABLE_NAME, V_RULE_CODE1, V_RULE_ID IN
    EXECUTE 'SELECT DISTINCT      
    UPDATED_TABLE,      
    UPDATED_COLUMN,      
    RULE_TYPE,      
    ''' || V_TABLENAME || ''' AS TABLE_NAME,      
    A.RULE_NAME,      
    A.PKID      
    FROM IFRS_SCENARIO_RULES_HEADER A      
    INNER JOIN IFRS_SCENARIO_RULES_DETAIL B      
    ON A.PKID = B.RULE_ID      
    INNER JOIN TMPRULE_' || P_RUNID || ' C      
    ON A.PKID = C.DEFAULT_RULE_ID      
    WHERE A.IS_DELETE = 0      
    AND B.IS_DELETE = 0'
    LOOP
        V_STR_SQL_RULE := '';
        V_STR_QUERY := '';

        FOR V_COLUMN_NAME,V_DATA_TYPE,V_OPERATOR,V_VALUE1,V_VALUE2,V_QG,V_AOC,V_PREV_QG,V_NEXT_QG,V_JML,V_RN,V_PKID IN
        EXECUTE 'SELECT      
        ''A.'' || COLUMN_NAME,      
        DATA_TYPE,      
        OPERATOR,      
        VALUE1,      
        VALUE2,      
        QUERY_GROUPING,      
        AND_OR_CONDITION,      
        LAG(QUERY_GROUPING, 1, MIN_QG) OVER (PARTITION BY RULE_ID ORDER BY QUERY_GROUPING, SEQUENCE) PREV_QG,      
        LEAD(QUERY_GROUPING, 1, MAX_QG) OVER (PARTITION BY RULE_ID ORDER BY QUERY_GROUPING, SEQUENCE) NEXT_QG,      
        JML,      
        RN,      
        PKID      
        FROM (SELECT      
        MIN(QUERY_GROUPING) OVER (PARTITION BY RULE_ID) MIN_QG,      
        MAX(QUERY_GROUPING) OVER (PARTITION BY RULE_ID) MAX_QG,      
        ROW_NUMBER() OVER (PARTITION BY RULE_ID ORDER BY QUERY_GROUPING, SEQUENCE) RN,      
        COUNT(0) OVER (PARTITION BY RULE_ID) JML,      
        COLUMN_NAME,      
        DATA_TYPE,      
        OPERATOR,      
        VALUE1,      
        VALUE2,      
        QUERY_GROUPING,      
        RULE_ID,      
        AND_OR_CONDITION,      
        PKID,
        SEQUENCE      
        FROM IFRS_SCENARIO_RULES_DETAIL      
        WHERE RULE_ID = ' || V_RULE_ID || ' AND IS_DELETE = 0) A'
        LOOP

        V_STR_SQL_RULE := V_STR_SQL_RULE
                || ' '
                || V_AOC
                || ' '
                || CASE
                WHEN V_QG <> V_PREV_QG THEN
                '('
                ELSE
                ' '
                END
                || COALESCE(
                CASE
                WHEN TRIM(V_DATA_TYPE) IN ('NUMBER', 'DECIMAL', 'NUMERIC', 'FLOAT', 'INT') THEN
                CASE
                WHEN V_OPERATOR IN ('=', '<>', '>', '<', '>=', '<=') THEN
                V_COLUMN_NAME
                || ' '
                || V_OPERATOR
                || ' '
                || V_VALUE1
                WHEN UPPER(V_OPERATOR) = 'BETWEEN' THEN
                V_COLUMN_NAME
                || ' '
                || V_OPERATOR
                || ' '
                || V_VALUE1
                || ' AND '
                || V_VALUE2
                WHEN UPPER(V_OPERATOR) = 'IN' THEN
                V_COLUMN_NAME
                || ' '
                || V_OPERATOR
                || ' ('
                || V_VALUE1
                || ')'
                ELSE
                'XXX'
                END
                WHEN TRIM(V_DATA_TYPE) IN ('DATE', 'DATETIME') THEN
                CASE
                WHEN V_OPERATOR IN ('=', '<>', '>', '<', '>=', '<=') THEN
                V_COLUMN_NAME
                || ' '
                || V_OPERATOR
                || ' TO_DATE('''
                || V_VALUE1
                || ''',''MM/DD/YYYY'')'
                WHEN UPPER(V_OPERATOR) = 'BETWEEN' THEN
                V_COLUMN_NAME
                || ' '
                || V_OPERATOR
                || ' '
                || ' CONVERT(DATE,'''
                || V_VALUE1
                || ''',110)'
                || ' AND '
                || ' CONVERT(DATE,'''
                || V_VALUE2
                || ''',110)'
                WHEN UPPER(V_OPERATOR) IN ('=', '<>', '>', '<', '>=', '<=') THEN
                V_COLUMN_NAME
                || ' '
                || V_OPERATOR
                || ' ('
                || ' TO_DATE('''
                || V_VALUE1
                || ''',''MM/DD/YYYY'')'
                || ')'
                ELSE
                'XXX'
                END
                WHEN UPPER(TRIM(V_DATA_TYPE)) IN ('CHAR', 'CHARACTER', 'VARCHAR', 'VARCHAR2', 'BIT') THEN
                CASE
                WHEN TRIM(V_OPERATOR) = '=' THEN
                V_COLUMN_NAME
                || ' '
                || V_OPERATOR
                || ''''
                || V_VALUE1
                || ''''
                WHEN UPPER(V_OPERATOR) = 'BETWEEN' THEN
                V_COLUMN_NAME
                || ' '
                || V_OPERATOR
                || ' '
                || V_VALUE1
                || ' AND '
                || V_VALUE2
                WHEN UPPER(V_OPERATOR) = 'IN' THEN
                V_COLUMN_NAME
                || ' '
                || V_OPERATOR
                || ' ('''
                || REPLACE(V_VALUE1, ',', ''',''')
                || ''')'
                ELSE
                'XXX'
                END
                ELSE
                'XXX'
                END,
                ' ')
                || CASE
                WHEN V_QG <> V_NEXT_QG OR V_RN = V_JML THEN
                ')'
                ELSE
                ' '
            END;
        END LOOP;

        V_STR_SQL_RULE := '(' || TRIM(SUBSTRING(V_STR_SQL_RULE, 6, LENGTH(V_STR_SQL_RULE)));

        V_STR_QUERY := V_STR_QUERY
        || 'SELECT DOWNLOAD_DATE, '
        || V_RULE_ID
        || ', MASTERID, ACCOUNT_NUMBER, CUSTOMER_NUMBER, OUTSTANDING, OUTSTANDING * EXCHANGE_RATE, PLAFOND, PLAFOND * EXCHANGE_RATE, COALESCE(EIR, MARGIN_RATE), CURRENT_DATE FROM '
        || V_UPDATED_TABLE || ' A WHERE A.DOWNLOAD_DATE = ''' || TO_CHAR(V_CURRDATE, 'YYYYMMDD') || ''' AND ' || V_STR_SQL_RULE || ' ';

        EXECUTE FORMAT('INSERT INTO ' || V_TABLEINSERT3 || ' (DOWNLOAD_DATE, RULE_ID, MASTERID, ACCOUNT_NUMBER, CUSTOMER_NUMBER, OS_AT_DEFAULT, EQV_AT_DEFAULT, PLAFOND_AT_DEFAULT, EQV_PLAFOND_AT_DEFAULT, EIR_AT_DEFAULT, CREATED_DATE) %s', V_STR_QUERY);
        
        GET DIAGNOSTICS V_RETURNROWS = ROW_COUNT;
        V_RETURNROWS2 := V_RETURNROWS2 + V_RETURNROWS;
        V_RETURNROWS := 0;


        INSERT INTO IFRS_SCENARIO_GENERATE_QUERY (
            RULE_ID,
            RULE_NAME,
            RULE_TYPE,
            TABLE_NAME,
            PD_RULES_QRY_RESULT,
            CREATEDBY,
            CREATEDDATE
        ) VALUES (
            CAST(V_RULE_ID AS INT),
            V_RULE_CODE1,
            V_RULE_TYPE,
            V_TABLE_NAME,
            V_STR_SQL_RULE,
            'SP_IFRS_IMP_DEFAULT_RULE',
            CURRENT_DATE
        );

    GET DIAGNOSTICS V_RETURNROWS = ROW_COUNT;
    V_RETURNROWS2 := V_RETURNROWS2 + V_RETURNROWS;
    V_RETURNROWS := 0;

    END LOOP;

    RAISE NOTICE 'SP_IFRS_IMP_DEFAULT_RULE | AFFECTED RECORD : %', V_RETURNROWS2;
    -------- ====== BODY ======

    -------- ====== LOG ======
    V_TABLEDEST = V_TABLEINSERT3;
    V_COLUMNDEST = '-';
    V_SPNAME = 'SP_IFRS_IMP_DEFAULT_RULE';
    V_OPERATION = 'INSERT';
    
    CALL SP_IFRS_EXEC_AND_LOG(V_CURRDATE, V_TABLEDEST, V_COLUMNDEST, V_SPNAME, V_OPERATION, V_RETURNROWS2, P_RUNID);
    -------- ====== LOG ======

    -------- ====== RESULT ======
    V_QUERYS = 'SELECT * FROM ' || V_TABLEINSERT3 || '';
    CALL SP_IFRS_RESULT_PREV(V_CURRDATE, V_QUERYS, V_SPNAME, V_RETURNROWS2, P_RUNID);
    -------- ====== RESULT ======

    CALL SP_IFRS_IMP_DEFAULT_RULE_NOLAG(P_RUNID, NULL, P_PRC);

END;

$$;
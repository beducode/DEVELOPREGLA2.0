---- DROP PROCEDURE SP_IFRS_AMT_INITIAL_UPDATE;

CREATE OR REPLACE PROCEDURE SP_IFRS_AMT_INITIAL_UPDATE(
    IN P_RUNID VARCHAR(20) DEFAULT 'S_00000_0000',
    IN P_DOWNLOAD_DATE DATE DEFAULT NULL,
    IN P_PRC VARCHAR(1) DEFAULT 'S')
LANGUAGE PLPGSQL AS $$
DECLARE
    ---- DATE
    V_PREVDATE DATE;
    V_CURRDATE DATE;

    ---- QUERY   
    V_STR_QUERY TEXT;

    ---- TABLE LIST       
    V_TABLENAME VARCHAR(100);
    V_TABLEINSERT1 VARCHAR(100);
    V_TABLEINSERT2 VARCHAR(100);
    V_TABLEINSERT3 VARCHAR(100);
    
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
        V_TABLEINSERT1 := 'IFRS_TRANSACTION_DAILY_' || P_RUNID || '';
        V_TABLEINSERT2 := 'IFRS_TRANSACTION_PARAM_' || P_RUNID || '';
        V_TABLEINSERT3 := 'TBLM_CURRENCY_' || P_RUNID || '';
    ELSE 
        V_TABLENAME := 'IFRS_MASTER_ACCOUNT';
        V_TABLEINSERT1 := 'IFRS_TRANSACTION_DAILY';
        V_TABLEINSERT2 := 'IFRS_TRANSACTION_PARAM';
        V_TABLEINSERT3 := 'TBLM_CURRENCY';
    END IF;
    
    IF P_DOWNLOAD_DATE IS NULL 
    THEN
        SELECT
            CURRDATE, PREVDATE INTO V_CURRDATE, V_PREVDATE
        FROM
            IFRS_PRC_DATE;
    ELSE        
        V_CURRDATE := P_DOWNLOAD_DATE;
        V_PREVDATE := V_CURRDATE - INTERVAL '1 DAY';
    END IF;
    
    V_RETURNROWS2 := 0;
    -------- ====== VARIABLE ======

    -------- ====== PRE SIMULATION TABLE ======
    IF P_PRC = 'S' THEN
        V_STR_QUERY := '';
        V_STR_QUERY := V_STR_QUERY || 'DROP TABLE IF EXISTS ' || V_TABLEINSERT3 || ' ';
        EXECUTE (V_STR_QUERY);

        V_STR_QUERY := '';
        V_STR_QUERY := V_STR_QUERY || 'CREATE TABLE ' || V_TABLEINSERT3 || ' AS SELECT * FROM TBLM_CURRENCY WHERE 1=0 ';
        EXECUTE (V_STR_QUERY);
    END IF;
    -------- ====== PRE SIMULATION TABLE ======

    -------- ====== BODY ======
    CALL SP_IFRS_LOG_AMORT(V_CURRDATE, 'START', 'SP_IFRS_AMT_INITIAL_UPDATE', '');

    ---- UPDATE FACILITY_NUMBER & PLAFOND FROM LIMIT
    CALL SP_IFRS_LOG_AMORT(V_CURRDATE, 'DEBUG', 'SP_IFRS_AMT_INITIAL_UPDATE', 'UPDATE FACILITY_NUMBER & PLAFOND FROM LIMIT');

    V_STR_QUERY := '';
    V_STR_QUERY := V_STR_QUERY || 'UPDATE ' || V_TABLENAME || ' A 
        SET 
            FACILITY_NUMBER = B.COMMITMENT_ID 
            ,PLAFOND = B.LIMIT_AMT 
        FROM (
            SELECT DOWNLOAD_DATE, ACCOUNT_NUMBER, COMMITMENT_ID, LIMIT_AMT 
            FROM IFRS_MASTER_LIMIT 
        ) B 
        WHERE A.DOWNLOAD_DATE = B.DOWNLOAD_DATE 
        AND A.ACCOUNT_NUMBER = B.ACCOUNT_NUMBER 
        AND A.DOWNLOAD_DATE = ''' || CAST(V_CURRDATE AS VARCHAR(10)) || '''::DATE ';
    EXECUTE (V_STR_QUERY);

    ---- UPDATE IMP FIELD FROM PREVDATE
    CALL SP_IFRS_LOG_AMORT(V_CURRDATE, 'DEBUG', 'SP_IFRS_AMT_INITIAL_UPDATE', 'UPDATE IMP FIELD FROM PREVDATE');

    V_STR_QUERY := '';
    V_STR_QUERY := V_STR_QUERY || 'UPDATE ' || V_TABLENAME || ' A 
        SET 
            ECL_AMOUNT = B.ECL_AMOUNT 
            ,CA_UNWINDING_AMOUNT = B.CA_UNWINDING_AMOUNT 
            ,IA_UNWINDING_AMOUNT = B.IA_UNWINDING_AMOUNT 
            ,BEGINNING_BALANCE = B.BEGINNING_BALANCE 
            ,CHARGE_AMOUNT = B.CHARGE_AMOUNT 
            ,WRITEBACK_AMOUNT = B.WRITEBACK_AMOUNT 
            ,ENDING_BALANCE = B.ENDING_BALANCE 
            ,IS_IMPAIRED = B.IS_IMPAIRED 
            ,IMPAIRED_FLAG = B.IMPAIRED_FLAG 
            ,INITIAL_UNAMORT_ORG_FEE = B.INITIAL_UNAMORT_ORG_FEE 
            ,INITIAL_UNAMORT_TXN_COST = B.INITIAL_UNAMORT_TXN_COST 
            ,UNAMORT_FEE_AMT = B.UNAMORT_FEE_AMT 
            ,UNAMORT_COST_AMT = B.UNAMORT_COST_AMT 
            ,FIRST_INSTALLMENT_DATE = COALESCE(B.FIRST_INSTALLMENT_DATE, A.NEXT_PAYMENT_DATE) 
        FROM (
            SELECT 
                MASTERID 
                ,PRODUCT_GROUP 
                ,ECL_AMOUNT 
                ,CA_UNWINDING_AMOUNT 
                ,IA_UNWINDING_AMOUNT 
                ,BEGINNING_BALANCE 
                ,CHARGE_AMOUNT 
                ,WRITEBACK_AMOUNT 
                ,ENDING_BALANCE 
                ,IS_IMPAIRED 
                ,STAFF_LOAN_FLAG 
                ,IMPAIRED_FLAG 
                ,INITIAL_UNAMORT_ORG_FEE 
                ,INITIAL_UNAMORT_TXN_COST 
                ,UNAMORT_FEE_AMT 
                ,UNAMORT_COST_AMT 
                ,FIRST_INSTALLMENT_DATE 
            FROM ' || V_TABLENAME || ' 
            WHERE DOWNLOAD_DATE = ''' || CAST(V_PREVDATE AS VARCHAR(10)) || '''::DATE 
        ) B 
        WHERE A.MASTERID = B.MASTERID 
        AND A.DOWNLOAD_DATE = ''' || CAST(V_CURRDATE AS VARCHAR(10)) || '''::DATE ';
    EXECUTE (V_STR_QUERY);

    ---- UPDATE LAST & NEXT PAYMENT DATE --? IMPLEMENTATION MISSING IN SQLSERVER
    ---- CALL SP_IFRS_LOG_AMORT(V_CURRDATE, 'DEBUG', 'SP_IFRS_AMT_INITIAL_UPDATE', 'UPDATE LAST & NEXT PAYMENT DATE');

    ---- UPDATE AMORT TYPE & PRODUCT NAME
    CALL SP_IFRS_LOG_AMORT(V_CURRDATE, 'DEBUG', 'SP_IFRS_AMT_INITIAL_UPDATE', 'UPDATE AMORT TYPE & PRODUCT NAME');

    V_STR_QUERY := '';
    V_STR_QUERY := V_STR_QUERY || 'UPDATE ' || V_TABLENAME || ' A 
        SET 
            PRODUCT_GROUP = B.PRD_GROUP 
            ,PRODUCT_TYPE = B.PRD_TYPE 
            ,PRODUCT_TYPE_1 = B.PRD_TYPE_1 
            ,AMORT_TYPE = B.AMORT_TYPE 
            ,MARKET_RATE = B.MARKET_RATE 
            ,IAS_CLASS = B.FLAG_AL 
            ,STAFF_LOAN_FLAG = CASE WHEN B.IS_STAF_LOAN = ''Y'' THEN 1 ELSE 0 END 
        FROM (
            SELECT X.*, Y.* 
            FROM IFRS_PRODUCT_PARAM X 
            CROSS JOIN IFRS_PRC_DATE_AMORT Y 
        ) B 
        WHERE A.DATA_SOURCE = B.DATA_SOURCE 
        AND A.PRODUCT_CODE = B.PRD_CODE 
        AND (A.CURRENCY = B.CCY OR B.CCY = ''ALL'') 
        AND A.DOWNLOAD_DATE = ''' || CAST(V_CURRDATE AS VARCHAR(10)) || '''::DATE 
        AND A.ACCOUNT_STATUS = ''A'' ';
    EXECUTE (V_STR_QUERY);

    V_STR_QUERY := '';
    V_STR_QUERY := V_STR_QUERY || 'UPDATE ' || V_TABLENAME || ' A 
        SET REVOLVING_FLAG = CASE 
            WHEN A.DATA_SOURCE IN (''LOAN_T24'', ''TRADE_T24'', ''TRS'') THEN A.REVOLVING_FLAG 
            WHEN B.REPAY_TYPE_VALUE = ''REV'' THEN 1
            ELSE 0 END 
        FROM IFRS_PRODUCT_PARAM B 
        WHERE A.DATA_SOURCE = B.DATA_SOURCE 
        AND A.PRODUCT_CODE = B.PRD_CODE 
        AND A.PRODUCT_TYPE = B.PRD_TYPE 
        AND (A.CURRENCY = B.CCY OR B.CCY = ''ALL'') 
        AND A.DOWNLOAD_DATE = ''' || CAST(V_CURRDATE AS VARCHAR(10)) || '''::DATE 
        AND SOURCE_SYSTEM <> ''T24'' ';
    EXECUTE (V_STR_QUERY);

    V_STR_QUERY := '';
    V_STR_QUERY := V_STR_QUERY || 'UPDATE ' || V_TABLEINSERT1 || ' A 
        SET DEBET_CREDIT_FLAG = CASE IFRS_TXN_CLASS WHEN ''FEE'' THEN ''C'' WHEN ''COST'' THEN ''D'' END 
        FROM ' || V_TABLEINSERT2 || ' B 
        WHERE A.TRX_CODE = B.TRX_CODE 
        AND A.DATA_SOURCE = B.DATA_SOURCE 
        AND (A.CCY = B.CCY OR B.CCY = ''ALL'') 
        AND (A.PRD_CODE = B.PRD_CODE OR B.PRD_CODE = ''ALL'') 
        AND (A.PRD_TYPE = B.PRD_TYPE OR B.PRD_TYPE = ''ALL'') 
        AND A.DOWNLOAD_DATE = ''' || CAST(V_CURRDATE AS VARCHAR(10)) || '''::DATE 
        AND DEBET_CREDIT_FLAG IS NULL ';
    EXECUTE (V_STR_QUERY);

    ---- EXCHANGE RATE CURR & PREV --? IMPLEMENTATION MISSING IN SQLSERVER
    ---- CALL SP_IFRS_LOG_AMORT(V_CURRDATE, 'DEBUG', 'SP_IFRS_AMT_INITIAL_UPDATE', 'EXCHANGE RATE CURR & PREV');

    ---- UPDATE IFRS9 CLASS BASED ON SPPI & BUSINESS MODEL TEST
    CALL SP_IFRS_LOG_AMORT(V_CURRDATE, 'DEBUG', 'SP_IFRS_AMT_INITIAL_UPDATE', 'UPDATE IFRS9 CLASS BASED ON SPPI & BUSINESS MODEL TEST');

    V_STR_QUERY := '';
    V_STR_QUERY := V_STR_QUERY || 'UPDATE ' || V_TABLENAME || ' A 
        SET IFRS9_CLASS = C.IFRS9_CLASS 
        FROM ' || V_TABLENAME || ' C 
        WHERE A.MASTERID = C.MASTERID 
        AND A.DOWNLOAD_DATE = ''' || CAST(V_CURRDATE AS VARCHAR(10)) || '''::DATE 
        AND C.DOWNLOAD_DATE = ''' || CAST(V_PREVDATE AS VARCHAR(10)) || '''::DATE 
        AND ''' || CAST(V_CURRDATE AS VARCHAR(10)) || '''::DATE <> ''' || CAST(F_EOMONTH(V_CURRDATE, 0, '', '') AS VARCHAR(10)) || '''::DATE ';
    EXECUTE (V_STR_QUERY);

    V_STR_QUERY := '';
    V_STR_QUERY := V_STR_QUERY || 'UPDATE ' || V_TABLENAME || ' A 
        SET IFRS9_CLASS = CASE 
            WHEN B.ASSET_CLASS = ''AMORT'' THEN ''AMORTIZED COST'' 
            WHEN B.ASSET_CLASS = ''FVTPL'' THEN ''FVTPL'' 
            WHEN B.ASSET_CLASS = ''FVOCI'' THEN ''FVOCI'' 
            WHEN COALESCE(B.ASSET_CLASS, '''') = '''' THEN NULL 
            END 
        -- FROM VW_AC_PRODUCT_CLASS B --* ORIGINAL SQLSERVER
        FROM IFRS_AC_PRODUCT_CLASS B 
        WHERE A.PRODUCT_CODE = B.PRD_CODE 
        AND A.DOWNLOAD_DATE = ''' || CAST(V_CURRDATE AS VARCHAR(10)) || '''::DATE ';
    EXECUTE (V_STR_QUERY);

    V_STR_QUERY := '';
    V_STR_QUERY := V_STR_QUERY || 'UPDATE ' || V_TABLENAME || ' A 
        SET IFRS9_CLASS = CASE 
            WHEN B.ASSET_CLS = ''AMORT'' THEN ''AMORTIZED COST'' 
            WHEN B.ASSET_CLS = ''FVTPL'' THEN ''FVTPL'' 
            WHEN B.ASSET_CLS = ''FVOCI'' THEN ''FVOCI'' 
            END 
        FROM IFRS_AC_OVERRIDE B 
        WHERE A.MASTERID = B.MASTERID 
        AND A.DOWNLOAD_DATE = ''' || CAST(V_CURRDATE AS VARCHAR(10)) || '''::DATE 
        AND F_EOMONTH(A.DOWNLOAD_DATE, 0, '''', '''') >= ''' || F_EOMONTH(V_CURRDATE, 0, '', '') || ''' ';
    EXECUTE (V_STR_QUERY);

    ---- RELOAD MASTER CURRENCY TABLE
    CALL SP_IFRS_LOG_AMORT(V_CURRDATE, 'DEBUG', 'SP_IFRS_AMT_INITIAL_UPDATE', 'RELOAD MASTER CURRENCY TABLE');

    V_STR_QUERY := '';
    V_STR_QUERY := V_STR_QUERY || 'DELETE FROM ' || V_TABLEINSERT3 || ' ';
    EXECUTE (V_STR_QUERY);

    V_STR_QUERY := '';
    V_STR_QUERY := V_STR_QUERY || 'INSERT INTO ' || V_TABLEINSERT3 || ' 
        ( 
            CCY 
            ,CCY_TYPE 
            ,CCY_DESC 
            ,CREATEDBY 
            ,CREATEDDATE 
        ) SELECT 
            CURRENCY 
            ,CURRENCY 
            ,COALESCE(CURRENCY_DESC, ''N/A'') AS CURRENCY_DESC 
            ,''SP_IFRS_AMT_INITIAL_UPDATE'' AS CREATEDBY 
            ,CURRENT_TIMESTAMP AS CREATEDDATE 
        FROM IFRS_MASTER_EXCHANGE_RATE 
        WHERE DOWNLOAD_DATE = ''' || CAST(V_CURRDATE AS VARCHAR(10)) || '''::DATE ';
    EXECUTE (V_STR_QUERY);

    GET DIAGNOSTICS V_RETURNROWS = ROW_COUNT;
    V_RETURNROWS2 := V_RETURNROWS2 + V_RETURNROWS;
    V_RETURNROWS := 0;

    ----? ORIGINAL IMPLEMENTATION USING TABLE FOR B AND UPDATE A LEFT JOIN B
    V_STR_QUERY := '';
    V_STR_QUERY := V_STR_QUERY || 'UPDATE ' || V_TABLENAME || ' A 
        SET 
            DPD_CIF = CASE WHEN B.CUSTOMER_NUMBER IS NULL THEN 0 ELSE B.DAY_PAST_DUE_CIF END 
            ,BI_COLLECT_CIF = CASE WHEN B.CUSTOMER_NUMBER IS NULL THEN 1 ELSE B.BI_COLLECT_CIF END 
        FROM (
            SELECT 
                CUSTOMER_NUMBER 
                ,MAX(DAY_PAST_DUE) AS DAY_PAST_DUE_CIF 
                ,MAX(BI_COLLECTABILITY) AS BI_COLLECT_CIF 
            FROM ' || V_TABLENAME || ' 
            WHERE DOWNLOAD_DATE = ''' || CAST(V_CURRDATE AS VARCHAR(10)) || '''::DATE 
            GROUP BY CUSTOMER_NUMBER 
        ) B 
        WHERE A.CUSTOMER_NUMBER = B.CUSTOMER_NUMBER 
        AND A.DOWNLOAD_DATE = ''' || CAST(V_CURRDATE AS VARCHAR(10)) || '''::DATE ';
    EXECUTE (V_STR_QUERY);

    ---- UPDATE GL_CONSTNAME
    CALL SP_IFRS_LOG_AMORT(V_CURRDATE, 'DEBUG', 'SP_IFRS_AMT_INITIAL_UPDATE', 'UPDATE GL_CONSTNAME');
    CALL SP_IFRS_EXEC_RULE(P_RUNID, V_CURRDATE, P_PRC, 'GL');

    ---- END
    CALL SP_IFRS_LOG_AMORT(V_CURRDATE, 'END', 'SP_IFRS_AMT_INITIAL_UPDATE', '');

    RAISE NOTICE 'SP_IFRS_AMT_INITIAL_UPDATE | AFFECTED RECORD : %', V_RETURNROWS2;
    ---------- ====== BODY ======

    -------- ====== LOG ======
    V_TABLEDEST = V_TABLEINSERT3;
    V_COLUMNDEST = '-';
    V_SPNAME = 'SP_IFRS_AMT_INITIAL_UPDATE';
    V_OPERATION = 'INSERT';
    
    CALL SP_IFRS_EXEC_AND_LOG(V_CURRDATE, V_TABLEDEST, V_COLUMNDEST, V_SPNAME, V_OPERATION, V_RETURNROWS2, P_RUNID);
    -------- ====== LOG ======

    -------- ====== RESULT ======
    V_QUERYS = 'SELECT * FROM ' || V_TABLEINSERT3 || '';
    CALL SP_IFRS_RESULT_PREV(V_CURRDATE, V_QUERYS, V_SPNAME, V_RETURNROWS2, P_RUNID);
    -------- ====== RESULT ======


END;

$$;
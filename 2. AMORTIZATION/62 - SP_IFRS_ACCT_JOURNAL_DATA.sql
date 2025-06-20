---- DROP PROCEDURE SP_IFRS_ACCT_JOURNAL_DATA;

CREATE OR REPLACE PROCEDURE SP_IFRS_ACCT_JOURNAL_DATA(
    IN P_RUNID VARCHAR(20) DEFAULT 'S_00000_0000', 
    IN P_DOWNLOAD_DATE DATE DEFAULT NULL,
    IN P_PRC VARCHAR(1) DEFAULT 'S')
LANGUAGE PLPGSQL 
AS $$
DECLARE
    ---- DATE
    V_PREVDATE DATE;
    V_PREVMONTH DATE;
    V_CURRDATE DATE;
    V_LASTYEAR DATE;
    V_LASTYEARNEXTMONTH DATE;
    V_MIGRATIONDATE DATE;

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
    V_TABLEINSERT8 VARCHAR(100);
    V_TABLEINSERT9 VARCHAR(100);
    V_TABLEINSERT10 VARCHAR(100);

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
        V_TABLEINSERT1 := 'IFRS_ACCT_JOURNAL_INTM';
        V_TABLEINSERT2 := 'IFRS_IMA_AMORT_CURR_' || P_RUNID || '';
        V_TABLEINSERT3 := 'IFRS_MASTER_EXCHANGE_RATE_' || P_RUNID || '';
        V_TABLEINSERT4 := 'IFRS_MASTER_PRODUCT_PARAM_' || P_RUNID || '';
        V_TABLEINSERT5 := 'IFRS_ACCT_JOURNAL_DATA';
    ELSE 
        V_TABLEINSERT1 := 'IFRS_ACCT_JOURNAL_INTM';
        V_TABLEINSERT2 := 'IFRS_IMA_AMORT_CURR';
        V_TABLEINSERT3 := 'IFRS_MASTER_EXCHANGE_RATE';
        V_TABLEINSERT4 := 'IFRS_MASTER_PRODUCT_PARAM';
        V_TABLEINSERT5 := 'IFRS_ACCT_JOURNAL_DATA';
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

    EXECUTE 'SELECT VALUE2 FROM TBLM_COMMONCODEDETAIL WHERE VALUE1 = ''ITRCGM'' ' INTO V_MIGRATIONDATE;
    -------- ====== VARIABLE ======

    -- V_STR_QUERY := '';
    -- V_STR_QUERY := '';
    -- EXECUTE (V_STR_QUERY);

    V_STR_QUERY := '';
    V_STR_QUERY := ' UPDATE ' || V_TABLEINSERT1 || '              
    SET METHOD = ''EIR''              
    WHERE DOWNLOAD_DATE = ''' || CAST(V_CURRDATE AS VARCHAR(10)) || '''::DATE              
    AND SUBSTRING(SOURCEPROCESS, 1, 3) = ''EIR'' ';
    EXECUTE (V_STR_QUERY);


    V_STR_QUERY := '';
    V_STR_QUERY := 'UPDATE ' || V_TABLEINSERT1 || '      
    SET FLAG_AL = CASE WHEN ISNULL(B.IAS_CLASS,'') = '' THEN D.INST_CLS_VALUE ELSE B.IAS_CLASS END ,      
    N_AMOUNT_IDR = A.N_AMOUNT * COALESCE(C.RATE_AMOUNT, 1)       
    FROM ' || V_TABLEINSERT1 || ' A       
    LEFT JOIN ' || V_TABLEINSERT2 || ' B       
    ON A.MASTERID = B.MASTERID       
    LEFT JOIN ' || V_TABLEINSERT3 || ' C      
    ON A.CCY = C.CURRENCY  AND A.DOWNLOAD_DATE = C.DOWNLOAD_DATE       
    LEFT JOIN ' || V_TABLEINSERT4 || ' D ON     
    A.DATASOURCE = D.DATA_SOURCE  AND A.PRDCODE = D.PRD_CODE                                            
    AND (                                            
        A.CCY = D.CCY  OR D.CCY = ''ALL''                                            
    )                                        
    WHERE A.DOWNLOAD_DATE = ''' || CAST(V_CURRDATE AS VARCHAR(10)) || '''::DATE  ';
    EXECUTE (V_STR_QUERY);

    V_STR_QUERY := '';
    V_STR_QUERY := 'DELETE FROM ' || V_TABLEINSERT5 || '              
                    WHERE DOWNLOAD_DATE >= ''' || CAST(V_CURRDATE AS VARCHAR(10)) || '''::DATE ';
    EXECUTE (V_STR_QUERY);

    V_STR_QUERY := '';
    V_STR_QUERY := '';
    EXECUTE (V_STR_QUERY);

    GET DIAGNOSTICS V_RETURNROWS = ROW_COUNT;
    V_RETURNROWS2 := V_RETURNROWS2 + V_RETURNROWS;

    RAISE NOTICE 'SP_IFRS_ACCT_JOURNAL_DATA | AFFECTED RECORD : %', V_RETURNROWS2;
    
        -------- ====== LOG ======
    V_TABLEDEST = V_TABLEINSERT1;
    V_COLUMNDEST = '-';
    V_SPNAME = 'SP_IFRS_ACCT_JOURNAL_DATA';
    V_OPERATION = 'INSERT';
    
    CALL SP_IFRS_EXEC_AND_LOG(V_CURRDATE, V_TABLEDEST, V_COLUMNDEST, V_SPNAME, V_OPERATION, V_RETURNROWS2, P_RUNID);
    -------- ====== LOG ======

    -------- ====== RESULT ======
    V_QUERYS = 'SELECT * FROM ' || V_TABLEINSERT1 || '';
    CALL SP_IFRS_RESULT_PREV(V_CURRDATE, V_QUERYS, V_SPNAME, V_RETURNROWS2, P_RUNID);
    -------- ====== RESULT ======
    
END;

$$;
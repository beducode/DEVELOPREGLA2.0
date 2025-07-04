---- DROP PROCEDURE SP_IFRS_ACCT_EIR_SWITCH;

CREATE OR REPLACE PROCEDURE SP_IFRS_ACCT_EIR_SWITCH(
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
    V_TABLEINSERT1 VARCHAR(100);
    V_TABLEINSERT2 VARCHAR(100);
    V_TABLEINSERT3 VARCHAR(100);
    V_TABLEINSERT4 VARCHAR(100);
    V_TABLEINSERT5 VARCHAR(100);
    V_TABLEINSERT6 VARCHAR(100);
    V_TMPTABLE1 VARCHAR(100);

    ---- VARIABLE PROCESS
    V_NUM INT;
    
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
        V_TABLEINSERT1 := 'IFRS_ACCT_SL_ACF_' || P_RUNID || '';
        V_TABLEINSERT2 := 'IFRS_ACCT_SL_COST_FEE_PREV_' || P_RUNID || '';
        V_TABLEINSERT3 := 'IFRS_ACCT_SL_ECF_' || P_RUNID || '';
        V_TABLEINSERT4 := 'IFRS_IMA_AMORT_CURR_' || P_RUNID || '';
        V_TABLEINSERT5 := 'IFRS_ACCT_CLOSED_' || P_RUNID || '';
        V_TABLEINSERT6 := 'IFRS_ACCT_SL_COST_FEE_ECF_' || P_RUNID || '';
        V_TABLEINSERT7 := 'TMP_P1_' || P_RUNID || '';
        V_TABLEINSERT8 := 'TMP_T2_' || P_RUNID || '';
    ELSE 
        V_TABLEINSERT1 := 'IFRS_ACCT_SL_ACF';
        V_TABLEINSERT2 := 'IFRS_ACCT_SL_COST_FEE_PREV';
        V_TABLEINSERT3 := 'IFRS_ACCT_SL_ECF';
        V_TABLEINSERT4 := 'IFRS_IMA_AMORT_CURR';
        V_TABLEINSERT5 := 'IFRS_ACCT_CLOSED';
        V_TABLEINSERT6 := 'IFRS_ACCT_SL_COST_FEE_ECF';
        V_TABLEINSERT7 := 'TMP_P1';
        V_TABLEINSERT8 := 'TMP_T2';
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

    -------- ====== BODY ======
    CALL SP_IFRS_LOG_AMORT(V_CURRDATE, 'START', 'SP_IFRS_ACCT_SL_ACF_ACCRU', '');

    V_STR_QUERY := '';
    V_STR_QUERY := V_STR_QUERY || 'DELETE ' || V_TABLEINSERT1 || '
        AND DOWNLOAD_DATE = ''' || CAST(V_CURRDATE AS VARCHAR(10)) || '''::DATE 
            AND DO_AMORT = ''N''
        ';
    EXECUTE (V_STR_QUERY);

    V_STR_QUERY := '';
    V_STR_QUERY := V_STR_QUERY || 'DELETE ' || V_TABLEINSERT2 || '
        AND DOWNLOAD_DATE = ''' || CAST(V_CURRDATE AS VARCHAR(10)) || '''::DATE 
            AND CREATEDBY = ''SLACF02''
        ';
    EXECUTE (V_STR_QUERY);

    V_STR_QUERY := '';
    V_STR_QUERY := V_STR_QUERY || 'INSERT INTO ' || V_TABLEINSERT1 || ' (
         DOWNLOAD_DATE      
        ,FACNO      
        ,CIFNO      
        ,DATASOURCE      
        ,N_UNAMORT_COST      
        ,N_UNAMORT_FEE      
        ,N_AMORT_COST      
        ,N_AMORT_FEE      
        ,N_ACCRU_COST      
        ,N_ACCRU_FEE      
        ,N_ACCRUFULL_COST      
        ,N_ACCRUFULL_FEE      
        ,ECFDATE      
        ,CREATEDDATE      
        ,CREATEDBY      
        ,MASTERID      
        ,ACCTNO      
        ,DO_AMORT      
        ,BRANCH      
        ,ACF_CODE      
        ,FLAG_AL
        ) SELECT 
            ''' || CAST(V_CURRDATE AS VARCHAR(10)) || '''::DATE AS DOWNLOAD_DATE
            ,M.FACILITY_NUMBER      
            ,M.CUSTOMER_NUMBER      
            ,M.DATA_SOURCE
            ,CASE       
                WHEN CAST((DATEDIFF(DD, A.PREVDATE, ''' || CAST(V_CURRDATE AS VARCHAR(10)) || '''::DATE) + 1) AS FLOAT) --AS NUMERIC(32,6))      
                    / CAST(A.I_DAYSCNT AS FLOAT) > 1 --AS NUMERIC(32, 6)) > 1      
                    THEN (A.N_UNAMORT_COST - A.UNAMORT_COST_PREV)      
                ELSE CAST((DATEDIFF(DD, A.PREVDATE, ''' || CAST(V_CURRDATE AS VARCHAR(10)) || '''::DATE) + 1) AS FLOAT) --AS NUMERIC(32,6))      
                    / CAST(A.I_DAYSCNT AS FLOAT) --AS NUMERIC(32, 6))      
                    * (A.N_UNAMORT_COST - A.UNAMORT_COST_PREV)      
                END + A.UNAMORT_COST_PREV      
            ,CASE       
                WHEN CAST((DATEDIFF(DD, A.PREVDATE, ''' || CAST(V_CURRDATE AS VARCHAR(10)) || '''::DATE) + 1) AS FLOAT) --AS NUMERIC(32,6))      
                    / CAST(A.I_DAYSCNT AS FLOAT) > 1 --AS NUMERIC(32, 6)) > 1      
                    THEN (A.N_UNAMORT_FEE - A.UNAMORT_FEE_PREV)      
                ELSE CAST((DATEDIFF(DD, A.PREVDATE, ''' || CAST(V_CURRDATE AS VARCHAR(10)) || '''::DATE) + 1) AS FLOAT) --AS NUMERIC(32,6))      
                    / CAST(A.I_DAYSCNT AS FLOAT) --AS NUMERIC(32, 6))      
                    * (A.N_UNAMORT_FEE - A.UNAMORT_FEE_PREV)      
                END + A.UNAMORT_FEE_PREV      
            ,(C.N_UNAMORT_COST) /*( A.N_UNAMORT_COST + A.N_AMORT_COST )*/      
            - (      
            CASE       
                WHEN CAST((DATEDIFF(DD, A.PREVDATE, ''' || CAST(V_CURRDATE AS VARCHAR(10)) || '''::DATE) + 1) AS FLOAT) -- AS NUMERIC(32, 6))      
                / CAST(A.I_DAYSCNT AS FLOAT) > 1 --AS NUMERIC(32, 6)) > 1      
                THEN (A.N_UNAMORT_COST - A.UNAMORT_COST_PREV)      
                ELSE CAST((DATEDIFF(DD, A.PREVDATE, ''' || CAST(V_CURRDATE AS VARCHAR(10)) || '''::DATE) + 1) AS FLOAT) --AS NUMERIC(32, 6))      
                / CAST(A.I_DAYSCNT AS FLOAT) --AS NUMERIC(32, 6))      
                * (A.N_UNAMORT_COST - A.UNAMORT_COST_PREV)      
                END + A.UNAMORT_COST_PREV      
            )      
            ,(C.N_UNAMORT_FEE) /*( A.N_UNAMORT_FEE + A.N_AMORT_FEE )*/      
            - (      
            CASE       
                WHEN CAST((DATEDIFF(DD, A.PREVDATE, ''' || CAST(V_CURRDATE AS VARCHAR(10)) || '''::DATE) + 1) AS FLOAT) --AS NUMERIC(32, 6))      
                / CAST(A.I_DAYSCNT AS FLOAT) > 1 --AS NUMERIC(32, 6)) > 1      
                THEN (A.N_UNAMORT_FEE - A.UNAMORT_FEE_PREV)      
                ELSE CAST((DATEDIFF(DD, A.PREVDATE, ''' || CAST(V_CURRDATE AS VARCHAR(10)) || '''::DATE) + 1) AS FLOAT) --AS NUMERIC(32, 6))      
                / CAST(A.I_DAYSCNT AS NUMERIC(32, 6)) * (A.N_UNAMORT_FEE - A.UNAMORT_FEE_PREV)      
                END + A.UNAMORT_FEE_PREV      
            )      
            ,CASE       
            WHEN CAST((DATEDIFF(DD, A.PREVDATE, ''' || CAST(V_CURRDATE AS VARCHAR(10)) || '''::DATE) + 1) AS FLOAT) --AS NUMERIC(32,6))      
                / CAST(A.I_DAYSCNT AS FLOAT) > 1 --AS NUMERIC(32, 6)) > 1      
                THEN (A.N_UNAMORT_COST - A.UNAMORT_COST_PREV)      
            ELSE CAST((DATEDIFF(DD, A.PREVDATE, ''' || CAST(V_CURRDATE AS VARCHAR(10)) || '''::DATE) + 1) AS FLOAT) --AS NUMERIC(32,6))      
                / CAST(A.I_DAYSCNT AS FLOAT) --AS NUMERIC(32, 6))      
                * (A.N_UNAMORT_COST - A.UNAMORT_COST_PREV)      
            END - ISNULL(A.SW_ADJ_COST, 0)      
            ,CASE       
            WHEN CAST((DATEDIFF(DD, A.PREVDATE, ''' || CAST(V_CURRDATE AS VARCHAR(10)) || '''::DATE) + 1) AS FLOAT) --AS NUMERIC(32,6))      
                / CAST(A.I_DAYSCNT AS FLOAT) > 1 --AS NUMERIC(32, 6)) > 1      
                THEN (A.N_UNAMORT_FEE - A.UNAMORT_FEE_PREV)      
            ELSE CAST((DATEDIFF(DD, A.PREVDATE, ''' || CAST(V_CURRDATE AS VARCHAR(10)) || '''::DATE) + 1) AS FLOAT) --AS NUMERIC(32,6))      
                / CAST(A.I_DAYSCNT AS FLOAT) --AS NUMERIC(32, 6))      
                * (A.N_UNAMORT_FEE - A.UNAMORT_FEE_PREV)      
            END - ISNULL(A.SW_ADJ_FEE, 0) 
            ,A.N_UNAMORT_COST - A.UNAMORT_COST_PREV - ISNULL(A.SW_ADJ_COST, 0) AS [N_ACCRUFULL_COST]      
            ,A.N_UNAMORT_FEE - A.UNAMORT_FEE_PREV - ISNULL(A.SW_ADJ_FEE, 0) AS [N_ACCRUFULL_FEE]      
            ,A.DOWNLOAD_DATE      
            ,CURRENT_TIMESTAMP      
            ,''SP_ACCT_SL_ACF_ACCRU 1''      
            ,M.MASTERID      
            ,M.ACCOUNT_NUMBER      
            ,''N'' DO_AMORT      
            ,M.BRANCH_CODE      
            ,''2'' ACFCODE    
            ,M.FLAG_AL
        FROM ' || V_TABLEINSERT3 || ' A
        JOIN (
            SELECT 
                M.MASTERID      
                ,M.ACCOUNT_NUMBER      
                ,M.BRANCH_CODE      
                ,M.FACILITY_NUMBER      
                ,M.CUSTOMER_NUMBER      
                ,M.DATA_SOURCE      
                ,M.IAS_CLASS AS FLAG_AL
            FROM ' || V_TABLEINSERT4 || ' M
            LEFT JOIN (
                SELECT DISTINCT
                    MASTERID, dOWNLOAD_DATE 
                FROM ' || V_TABLEINSERT5 || ' 
                WHERE DOWNLOAD_DATE = ''' || CAST(V_CURRDATE AS VARCHAR(10)) || '''::DATE 
            ) D ON M.DOWNLOAD_DATE = D.DOWNLOAD_DATE
            AND M.MASTERID = D.MASTERIDE
            WHERE DOWNLOAD_DATE = ''' || CAST(V_CURRDATE AS VARCHAR(10)) || '''::DATE
        ) M ON M.MASTERID = A.MASTERID
        JOIN ' || V_TABLEINSERT3 || ' C ON C.AMORTSTOPDATE IS NULL
            AND C.MASTERID = A.MASTERID
            AND C.PMTDATE = C.PREVDATE
        WHERE A.PMTDATE <> A.PREVDATE
            AND A.PMTDATE = ''' || CAST(V_CURRDATE AS VARCHAR(10)) || '''::DATE
            AND A.PREVDATE = ''' || CAST(V_CURRDATE AS VARCHAR(10)) || '''::DATE
            AND A.AMORTSTOPDATE IS NULL 
        ';
    EXECUTE (V_STR_QUERY);

    CALL SP_IFRS_LOG_AMORT(V_CURRDATE, 'START', 'SP_IFRS_ACCT_SL_ACF_ACRU', 'ACF INSERTED');

    V_STR_QUERY := '';
    V_STR_QUERY := V_STR_QUERY || 'TRUNCATE TABLE ' || V_TABLEINSERT7 ||
    EXECUTE (V_STR_QUERY);

    V_STR_QUERY := '';
    V_STR_QUERY := V_STR_QUERY || 'INSERT INTO ' || V_TABLEINSERT7 || ' (ID)
        SELECT MAX(ID) AS ID
        FROM ' || V_TABLEINSERT1 || '
        WHERE DOWNLOAD_DATE = ''' || CAST(V_CURRDATE AS VARCHAR(10)) || '''::DATE
            AND DO_AMORT = ''N''
        GROUP BY MASTERID';
    EXECUTE (V_STR_QUERY);

    CALL SP_IFRS_LOG_AMORT(V_CURRDATE, 'DEBUG', 'SP_IFRS_ACCT_SL_ACF_ACRU', 'P1');

    V_STR_QUERY := '';
    V_STR_QUERY := V_STR_QUERY || 'TRUNCATE TABLE ' || V_TABLEINSERT7 ||
    EXECUTE (V_STR_QUERY);

    V_STR_QUERY := '';
    V_STR_QUERY := V_STR_QUERY || 'INSERT INTO ' || V_TABLEINSERT7 || ' (
        SUM_AMT      
        ,DOWNLOAD_DATE      
        ,FACNO      
        ,CIFNO      
        ,DATASOURCE      
        ,ACCTNO      
        ,MASTERID
        )
        SELECT SUM(A.N_AMOUNT) AS SUM_AMT      
        ,A.DOWNLOAD_DATE      
        ,A.FACNO      
        ,A.CIFNO      
        ,A.DATASOURCE      
        ,A.ACCTNO      
        ,A.MASTERID
        FROM (
            SELECT CASE       
            WHEN A.FLAG_REVERSE = ''Y''      
                THEN - 1 * A.AMOUNT      
            ELSE A.AMOUNT      
            END AS N_AMOUNT      
            ,A.ECFDATE DOWNLOAD_DATE      
            ,A.FACNO      
            ,A.CIFNO      
            ,A.DATASOURCE      
            ,A.ACCTNO      
            ,A.MASTERID      
            FROM ' || V_TABLEINSERT6 || ' A      
            WHERE A.FLAG_CF = ''F'' AND A.STATUS = ''ACT''
        ) A
        GROUP BY 
            A.DOWNLOAD_DATE      
            ,A.FACNO      
            ,A.CIFNO      
            ,A.DATASOURCE      
            ,A.ACCTNO      
            ,A.MASTERID
        ';
    EXECUTE (V_STR_QUERY);

    CALL SP_IFRS_LOG_AMORT(V_CURRDATE, 'DEBUG', 'SP_IFRS_ACCT_SL_ACF_ACRU', 'T1 FEE');

    CALL SP_IFRS_LOG_AMORT(V_CURRDATE, 'DEBUG', 'SP_IFRS_ACCT_SL_ACF_ACRU', 'INSERT FEE');

    V_STR_QUERY := '';
    V_STR_QUERY := V_STR_QUERY || 'INSERT INTO ' || V_TABLEINSERT7 || ' (
        FACNO      
        ,CIFNO      
        ,DOWNLOAD_DATE      
        ,ECFDATE      
        ,DATASOURCE      
        ,PRDCODE      
        ,TRXCODE      
        ,CCY      
        ,AMOUNT      
        ,STATUS      
        ,CREATEDDATE      
        ,ACCTNO      
        ,MASTERID      
        ,FLAG_CF      
        ,FLAG_REVERSE      
        ,BRCODE      
        ,SRCPROCESS      
        ,METHOD      
        ,CREATEDBY      
        ,SEQ      
        ,AMOUNT_ORG      
        ,ORG_CCY      
        ,ORG_CCY_EXRATE      
        ,PRDTYPE      
        ,CF_ID
        SELECT 
            A.FACNO      
            ,A.CIFNO      
            ,A.DOWNLOAD_DATE      
            ,A.ECFDATE      
            ,A.DATASOURCE      
            ,B.PRDCODE      
            ,B.TRXCODE      
            ,B.CCY      
            ,CAST(CAST(B.AMOUNT AS FLOAT) / CAST(C.SUM_AMT AS FLOAT) AS NUMERIC(32, 20)) * A.N_UNAMORT_FEE AS N_AMOUNT      
            ,B.STATUS      
            ,CURRENT_TIMESTAMP      
            ,A.ACCTNO      
            ,A.MASTERID      
            ,B.FLAG_CF      
            ,B.FLAG_REVERSE      
            ,B.BRCODE      
            ,B.SRCPROCESS      
            ,''SL''      
            ,''SLACF02''      
            ,''2''      
            ,B.AMOUNT_ORG      
            ,B.ORG_CCY      
            ,B.ORG_CCY_EXRATE      
            ,B.PRDTYPE      
            ,B.CF_ID
        FROM ' || V_TABLEINSERT1 || ' A
        JOIN ' || V_TABLEINSERT7 || ' D ON A.ID = D.ID
            AND A.MASTERID = B.MASTERID
            AND B.FLAG_CF = ''F''  AND B.STATUS = ''ACT''
        JOIN ' || V_TABLEINSERT7 || ' C ON C.DOWNLOAD_DATE = A.ECFDATE
            AND C.MASTERID  = B.MASTERID
        WHERE A.DOWNLOAD_DATE = ''' || CAST(V_CURRDATE AS VARCHAR(10)) || '''::DATE
            AND (
            (
                A.N_UNAMORT_FEE < 0
                AND A.FLAG_AL IN (''A'', ''O'')
            ) OR (
                A.N_UNAMORT_FEE > 0
                AND A.FLAG_AL = ''L' '
            )
        ';
    EXECUTE (V_STR_QUERY);

    CALL SP_IFRS_LOG_AMORT(V_CURRDATE, 'DEBUG', 'SP_IFRS_ACCT_SL_ACF_ACRU', 'FEE FEE');

    V_STR_QUERY := '';
    V_STR_QUERY := V_STR_QUERY || 'TRUNCATE TABLE ' || V_TABLEINSERT8 ||
    EXECUTE (V_STR_QUERY);

    V_STR_QUERY := '';
    V_STR_QUERY := V_STR_QUERY || 'INSERT INTO ' || V_TABLEINSERT8 || ' (
        SUM_AMT      
        ,DOWNLOAD_DATE      
        ,FACNO      
        ,CIFNO      
        ,DATASOURCE      
        ,ACCTNO      
        ,MASTERID
        )
        SELECT SUM(A.N_AMOUNT) AS SUM_AMT      
        ,A.DOWNLOAD_DATE      
        ,A.FACNO      
        ,A.CIFNO      
        ,A.DATASOURCE      
        ,A.ACCTNO      
        ,A.MASTERID
        FROM (
            SELECT CASE       
            WHEN A.FLAG_REVERSE = ''Y''      
                THEN - 1 * A.AMOUNT      
            ELSE A.AMOUNT      
            END AS N_AMOUNT      
            ,A.ECFDATE DOWNLOAD_DATE      
            ,A.FACNO      
            ,A.CIFNO      
            ,A.DATASOURCE      
            ,A.ACCTNO      
            ,A.MASTERID      
            FROM ' || V_TABLEINSERT6 || ' A      
            WHERE A.FLAG_CF = ''C'' AND A.STATUS = ''ACT''
        ) A
        GROUP BY 
            A.DOWNLOAD_DATE      
            ,A.FACNO      
            ,A.CIFNO      
            ,A.DATASOURCE      
            ,A.ACCTNO      
            ,A.MASTERID
        ';
    EXECUTE (V_STR_QUERY);

    CALL SP_IFRS_LOG_AMORT(V_CURRDATE, 'DEBUG', 'SP_IFRS_ACCT_SL_ACF_ACRU', 'T2 COST');

    V_STR_QUERY := '';
    V_STR_QUERY := V_STR_QUERY || 'INSERT INTO ' || V_TABLEINSERT2 || ' (
        FACNO      
        ,CIFNO      
        ,DOWNLOAD_DATE      
        ,ECFDATE      
        ,DATASOURCE      
        ,PRDCODE      
        ,TRXCODE      
        ,CCY      
        ,AMOUNT      
        ,STATUS      
        ,CREATEDDATE      
        ,ACCTNO      
        ,MASTERID      
        ,FLAG_CF      
        ,FLAG_REVERSE      
        ,BRCODE      
        ,SRCPROCESS      
        ,METHOD      
        ,CREATEDBY      
        ,SEQ      
        ,AMOUNT_ORG      
        ,ORG_CCY      
        ,ORG_CCY_EXRATE      
        ,PRDTYPE      
        ,CF_ID
        )
        SELECT A.FACNO      
        ,A.CIFNO      
        ,A.DOWNLOAD_DATE      
        ,A.ECFDATE      
        ,A.DATASOURCE      
        ,B.PRDCODE      
        ,B.TRXCODE      
        ,B.CCY      
        ,CAST(CAST(B.AMOUNT AS FLOAT) / CAST(C.SUM_AMT AS FLOAT) AS NUMERIC(32, 20)) * A.N_UNAMORT_COST AS N_AMOUNT      
        ,B.STATUS      
        ,CURRENT_TIMESTAMP      
        ,A.ACCTNO      
        ,A.MASTERID      
        ,B.FLAG_CF      
        ,B.FLAG_REVERSE      
        ,B.BRCODE      
        ,B.SRCPROCESS      
        ,''SL''      
        ,''SLACF02''      
        ,''2''      
        ,B.AMOUNT_ORG      
        ,B.ORG_CCY      
        ,B.ORG_CCY_EXRATE      
        ,B.PRDTYPE      
        ,B.CF_ID 
        FROM ' || V_TABLEINSERT1 || ' A      
        JOIN ' || V_TABLEINSERT7 || ' D ON A.ID = D.ID
        FROM ' || V_TABLEINSERT6 || ' B ON B.ECFDATE = A.ECFDATE
            AND B.MASTERID = A.MASTERID
            AND B.FLAG_CF = ''C''  AND B.STATUS = ''ACT''
        JOIN ' || V_TABLEINSERT8 || ' C ON C.DOWNLOAD_DATE = A.ECFDATE
            AND C.MASTERID  = B.MASTERID
        WHERE A.DOWNLOAD_DATE = ''' || CAST(V_CURRDATE AS VARCHAR(10)) || '''::DATE
            AND (
            (
                A.N_UNAMORT_COST < 0
                AND A.FLAG_AL IN (''A'', ''O'')
            ) OR (
                A.N_UNAMORT_COST > 0
                AND A.FLAG_AL = ''L''
            )   
        ';
    EXECUTE (V_STR_QUERY);

    CALL SP_IFRS_LOG_AMORT(V_CURRDATE, 'DEBUG', 'SP_IFRS_ACCT_SL_ACF_ACRU', 'COST PREV');
    
    ---- END
    CALL SP_IFRS_LOG_AMORT(V_CURRDATE, 'END', 'SP_IFRS_ACCT_SL_ACF_ACCRU', '');

    RAISE NOTICE 'SP_IFRS_ACCT_EIR_SWITCH | AFFECTED RECORD : %', V_RETURNROWS2;
    ---------- ====== BODY ======

    -------- ====== LOG ======
    V_TABLEDEST = V_TABLEINSERT6;
    V_COLUMNDEST = '-';
    V_SPNAME = 'SP_IFRS_ACCT_EIR_SWITCH';
    V_OPERATION = 'INSERT';
    
    CALL SP_IFRS_EXEC_AND_LOG(V_CURRDATE, V_TABLEDEST, V_COLUMNDEST, V_SPNAME, V_OPERATION, V_RETURNROWS2, P_RUNID);
    -------- ====== LOG ======

    -------- ====== RESULT ======
    V_QUERYS = 'SELECT * FROM ' || V_TABLEINSERT6 || '';
    CALL SP_IFRS_RESULT_PREV(V_CURRDATE, V_QUERYS, V_SPNAME, V_RETURNROWS2, P_RUNID);
    -------- ====== RESULT ======

END;

$$;
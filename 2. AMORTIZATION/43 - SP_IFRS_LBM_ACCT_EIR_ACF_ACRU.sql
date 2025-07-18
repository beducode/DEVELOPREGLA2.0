---- DROP PROCEDURE SP_IFRS_ACCT_SWITCH;

CREATE OR REPLACE PROCEDURE SP_IFRS_ACCT_SWITCH(
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
        V_TABLEINSERT1 := 'IFRS_LBM_ACCT_EIR_ACF_' || P_RUNID || '';
        V_TABLEINSERT2 := 'IFRS_LBM_ACCT_EIR_COST_FEE_PREV_' || P_RUNID || '';
        V_TABLEINSERT3 := 'IFRS_LBM_ACCT_EIR_ECF_' || P_RUNID || '';
        V_TABLEINSERT4 := 'IFRS_IMA_AMORT_CURR_' || P_RUNID || '';
        V_TABLEINSERT5 := 'IFRS_ACCT_CLOSED_' || P_RUNID || '';
        V_TABLEINSERT6 := 'IFRS_LBM_ACCT_EIR_COST_FEE_ECF_' || P_RUNID || '';
    ELSE 
        V_TABLEINSERT1 := 'IFRS_LBM_ACCT_EIR_ACF';
        V_TABLEINSERT2 := 'IFRS_LBM_ACCT_EIR_COST_FEE_PREV';
        V_TABLEINSERT3 := 'IFRS_LBM_ACCT_EIR_ECF';
        V_TABLEINSERT4 := 'IFRS_IMA_AMORT_CURR';
        V_TABLEINSERT5 := 'IFRS_ACCT_CLOSED';
        V_TABLEINSERT6 := 'IFRS_LBM_ACCT_EIR_COST_FEE_ECF';
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
        V_STR_QUERY := V_STR_QUERY || 'DROP TABLE IF EXISTS ' || V_TABLEINSERT1 || ' ';
        EXECUTE (V_STR_QUERY);

        V_STR_QUERY := '';
        V_STR_QUERY := V_STR_QUERY || 'CREATE TABLE ' || V_TABLEINSERT1 || ' AS SELECT * FROM IFRS_ACCT_SWITCH WHERE 1=0 ';
        EXECUTE (V_STR_QUERY);

        V_STR_QUERY := '';
        V_STR_QUERY := V_STR_QUERY || 'DROP TABLE IF EXISTS ' || V_TABLEINSERT2 || ' ';
        EXECUTE (V_STR_QUERY);

        V_STR_QUERY := '';
        V_STR_QUERY := V_STR_QUERY || 'CREATE TABLE ' || V_TABLEINSERT2 || ' AS SELECT * FROM IFRS_LBM_ACCT_SWITCH WHERE 1=0 ';
        EXECUTE (V_STR_QUERY);

        V_STR_QUERY := '';
        V_STR_QUERY := V_STR_QUERY || 'DROP TABLE IF EXISTS ' || V_TABLEINSERT10 || ' ';
        EXECUTE (V_STR_QUERY);

        V_STR_QUERY := '';
        V_STR_QUERY := V_STR_QUERY || 'CREATE TABLE ' || V_TABLEINSERT10 || ' AS SELECT * FROM IFRS_LBM_ACCT_EIR_ECF WHERE 1=0 ';
        EXECUTE (V_STR_QUERY);
    END IF;
    -------- ====== PRE SIMULATION TABLE ======

    -------- ====== BODY ======
    CALL SP_IFRS_LOG_AMORT(V_CURRDATE, 'START', 'SP_IFRS_LBM_ACCT_EIR_ACF_ACRU', '');

    V_STR_QUERY := '';
    V_STR_QUERY := V_STR_QUERY || 'DELETE FROM ' || V_TABLEINSERT1 || ' 
        WHERE DOWNLOAD_DATE >= ''' || CAST(V_CURRDATE AS VARCHAR(10)) || '''::DATE 
            AND DO_AMORT = ''N''';
    EXECUTE (V_STR_QUERY);

    V_STR_QUERY := '';
    V_STR_QUERY := V_STR_QUERY || 'DELETE FROM ' || V_TABLEINSERT2 || ' 
        WHERE DOWNLOAD_DATE >= ''' || CAST(V_CURRDATE AS VARCHAR(10)) || '''::DATE 
            AND CREATEDBY = ''EIRACF02''';
    EXECUTE (V_STR_QUERY);

    CALL SP_IFRS_LOG_AMORT(V_CURRDATE, 'DEBUG', 'SP_IFRS_LBM_ACCT_EIR_ACF_ACRU', 'V');

    V_STR_QUERY := '';
    V_STR_QUERY := V_STR_QUERY || 'INSERT INTO ' || V_TABLEINSERT1 || ' 
        ( 
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
            ,FLAG_AL -- AR : ADDITIONAL ASSET / LIAB FLAG
            ,N_ACCRU_NOCF -- FROM NO COST FEE ECF
            ,N_UNAMORT_NOCF
            ,N_UNAMORT_PREV_NOCF 
        ) SELECT 
            ''' || CAST(V_CURRDATE AS VARCHAR(10)) || '''::DATE AS DOWNLOAD_DATE 
            ,M.FACILITY_NUMBER
            ,M.CUSTOMER_NUMBER
            ,M.DATA_SOURCE 
            ,CASE 
                WHEN CAST((DATEDIFF(DD, A.PREV_PMT_DATE, ''' || CAST(V_CURRDATE AS VARCHAR(10)) || '''::DATE) + 1) AS FLOAT) / CAST(A.I_DAYS2 AS FLOAT) > 1
                    THEN (A.N_COST_UNAMORT_AMT - A.N_COST_UNAMORT_AMT_PREV)
                ELSE ROUND(CAST((DATEDIFF(DD, A.PREV_PMT_DATE, ''' || CAST(V_CURRDATE AS VARCHAR(10)) || '''::DATE) + 1) AS FLOAT) / CAST(A.I_DAYS2 AS FLOAT) * (A.N_COST_UNAMORT_AMT - A.N_COST_UNAMORT_AMT_PREV), ''' || CAST(V_ROUND AS VARCHAR(10)) || ''', ''' || CAST(V_FUNCROUND AS VARCHAR(10)) || '''
                END + A.N_COST_UNAMORT_AMT_PREV
            ,CASE 
                WHEN CAST((DATEDIFF(DD, A.PREV_PMT_DATE, ''' || CAST(V_CURRDATE AS VARCHAR(10)) || '''::DATE) + 1) AS FLOAT) / CAST(A.I_DAYS2 AS FLOAT) > 1
                    THEN (A.N_COST_UNAMORT_AMT - A.N_COST_UNAMORT_AMT_PREV)
                ELSE ROUND(CAST((DATEDIFF(DD, A.PREV_PMT_DATE, ''' || CAST(V_CURRDATE AS VARCHAR(10)) || '''::DATE) + 1) AS FLOAT) / CAST(A.I_DAYS2 AS FLOAT) * (A.N_FEE_UNAMORT_AMT - A.N_FEE_UNAMORT_AMT_PREV), ''' || CAST(V_ROUND AS VARCHAR(10)) || ''', ''' || CAST(V_FUNCROUND AS VARCHAR(10)) || '''
                END + A.N_FEE_UNAMORT_AMT_PREV
            ,(C.N_COST_UNAMORT_AMT) - (CASE 
                WHEN CAST((DATEDIFF(DD, A.PREV_PMT_DATE, ''' || CAST(V_CURRDATE AS VARCHAR(10)) || '''::DATE) + 1) AS FLOAT) / CAST(A.I_DAYS2 AS FLOAT) > 1
                    THEN (A.N_COST_UNAMORT_AMT - A.N_COST_UNAMORT_AMT_PREV)
                ELSE ROUND(CAST((DATEDIFF(DD, A.PREV_PMT_DATE, ''' || CAST(V_CURRDATE AS VARCHAR(10)) || '''::DATE) + 1) AS FLOAT) / CAST(A.I_DAYS2 AS FLOAT) * (A.N_COST_UNAMORT_AMT - A.N_COST_UNAMORT_AMT_PREV), ''' || CAST(V_ROUND AS VARCHAR(10)) || ''', ''' || CAST(V_FUNCROUND AS VARCHAR(10)) || '''
                END + A.N_COST_UNAMORT_AMT_PREV
                )
            ,(C.N_FEE_UNAMORT_AMT) - (CASE 
                WHEN CAST((DATEDIFF(DD, A.PREV_PMT_DATE, ''' || CAST(V_CURRDATE AS VARCHAR(10)) || '''::DATE) + 1) AS FLOAT) / CAST(A.I_DAYS2 AS FLOAT) > 1
                    THEN (A.N_COST_UNAMORT_AMT - A.N_COST_UNAMORT_AMT_PREV)
                ELSE ROUND(CAST((DATEDIFF(DD, A.PREV_PMT_DATE, ''' || CAST(V_CURRDATE AS VARCHAR(10)) || '''::DATE) + 1) AS FLOAT) / CAST(A.I_DAYS2 AS FLOAT) * (A.N_FEE_UNAMORT_AMT - A.N_FEE_UNAMORT_AMT_PREV), ''' || CAST(V_ROUND AS VARCHAR(10)) || ''', ''' || CAST(V_FUNCROUND AS VARCHAR(10)) || '''
                END + A.N_FEE_UNAMORT_AMT_PREV
                )
            ,CASE 
                WHEN CAST((DATEDIFF(DD, A.PREV_PMT_DATE, ''' || CAST(V_CURRDATE AS VARCHAR(10)) || '''::DATE) + 1) AS FLOAT) / CAST(A.I_DAYS2 AS FLOAT) > 1
                    THEN (A.N_COST_UNAMORT_AMT - A.N_COST_UNAMORT_AMT_PREV)
                ELSE ROUND(CAST((DATEDIFF(DD, A.PREV_PMT_DATE, ''' || CAST(V_CURRDATE AS VARCHAR(10)) || '''::DATE) + 1) AS FLOAT) / CAST(A.I_DAYS2 AS FLOAT) * (A.N_COST_UNAMORT_AMT - A.N_COST_UNAMORT_AMT_PREV), ''' || CAST(V_ROUND AS VARCHAR(10)) || ''', ''' || CAST(V_FUNCROUND AS VARCHAR(10)) || '''
                END - COALESCE(A.SW_ADJ_COST, 0)
            ,CASE 
                WHEN CAST((DATEDIFF(DD, A.PREV_PMT_DATE, ''' || CAST(V_CURRDATE AS VARCHAR(10)) || '''::DATE) + 1) AS FLOAT) / CAST(A.I_DAYS2 AS FLOAT) > 1
                    THEN (A.N_COST_UNAMORT_AMT - A.N_COST_UNAMORT_AMT_PREV)
                ELSE ROUND(CAST((DATEDIFF(DD, A.PREV_PMT_DATE, ''' || CAST(V_CURRDATE AS VARCHAR(10)) || '''::DATE) + 1) AS FLOAT) / CAST(A.I_DAYS2 AS FLOAT) * (A.N_FEE_UNAMORT_AMT - A.N_FEE_UNAMORT_AMT_PREV), ''' || CAST(V_ROUND AS VARCHAR(10)) || ''', ''' || CAST(V_FUNCROUND AS VARCHAR(10)) || '''
                END - COALESCE(A.SW_ADJ_FEE, 0)
            ,A.N_COST_AMORT_AMT - COALESCE(A.SW_ADJ_COST, 0) AS ACCRUFULL_COST
            ,A.N_FEE_AMORT_AMT - COALESCE(A.SW_ADJ_FEE, 0) AS ACCRUFULL_FEE
            ,A.DOWNLOAD_DATE
            ,CURRENT_TIMESTAMP
            ,''SP_ACCT_EIR_ACF_ACCRU 2''
            ,M.MASTERID
            ,M.ACCOUNT_NUMBER
            ,''N'' DO_AMORT
            ,M.BRANCH_CODE
            ,''2'' ACFCODE
            ,M.FLAG_AL
            ,CASE 
                WHEN CAST((DATEDIFF(DD, A.PREV_PMT_DATE, ''' || CAST(V_CURRDATE AS VARCHAR(10)) || '''::DATE) + 1) AS FLOAT) / CAST(A.I_DAYS2 AS FLOAT) > 1
                    THEN A.NOCF_AMORT_AMT
                ELSE ROUND(CAST((DATEDIFF(DD, A.PREV_PMT_DATE, ''' || CAST(V_CURRDATE AS VARCHAR(10)) || '''::DATE) + 1) AS FLOAT) / CAST(A.I_DAYS2 AS FLOAT) * A.NOCF_AMORT_AMT, ''' || CAST(V_ROUND AS VARCHAR(10)) || ''', ''' || CAST(V_FUNCROUND AS VARCHAR(10)) || ''')
                END
		,A.NOCF_UNAMORT_AMT
		,A.NOCF_UNAMORT_AMT_PREV
        FROM ' || V_TABLEINSERT3 || ' A 
        JOIN (
            SELECT M.DATA_SOURCE
                ,M.BRANCH_CODE
                ,M.MASTERID
                ,M.ACCOUNT_NUMBER
                ,M.FACILITY_NUMBER
                ,M.CUSTOMER_NUMBER
                ,M.IAS_CLASS AS FLAG_AL
            FROM ' || V_TABLEINSERT4 || ' M
            LEFT JOIN (
                SELECT DISTINCT DOWNLOAD_DATE, MASTERID
                FROM ' || V_TABLEINSERT5 || ' 
                WHERE DOWNLOAD_DATE = ''' || CAST(V_CURRDATE AS VARCHAR(10)) || '''::DATE
            ) D M.DOWNLOAD_DATE = D.DOWNLOAD_DATE
			AND M.MASTERID = D.MASTERID
            WHERE M.DOWNLOAD_DATE = ''' || CAST(V_CURRDATE AS VARCHAR(10)) || '''::DATE
            AND D.MASTERID IS NULL
        ) M ON A.MASTERID = M.MASTERID
        JOIN ' || V_TABLEINSERT3 || ' C ON C.AMORTSTOPDATE IS NULL
            AND C.MASTERID = A.MASTERID
            AND C.PMT_DATE = C.PREV_PMT_DATE
        WHERE A.PMT_DATE > ''' || CAST(V_CURRDATE AS VARCHAR(10)) || '''::DATE
            AND A.DOWNLOAD_DATE = ''' || CAST(V_CURRDATE AS VARCHAR(10)) || '''::DATE
            AND A.PREV_PMT_DATE <= ''' || CAST(V_CURRDATE AS VARCHAR(10)) || '''::DATE
            AND A.AMORTSTOPDATE IS NULL';
    EXECUTE (V_STR_QUERY);

    CALL SP_IFRS_LOG_AMORT(V_CURRDATE, 'DEBUG', 'SP_IFRS_LBM_ACCT_EIR_ACF_ACRU', 'ACF INSERTED');

    V_STR_QUERY := '';
    V_STR_QUERY := V_STR_QUERY || 'TRUNCATE TABLE ' || TMP_P1 || ' ';
    EXECUTE (V_STR_QUERY);

    V_STR_QUERY := '';
    V_STR_QUERY := V_STR_QUERY || 'INSERT INTO ' || TMP_P1 || ' (ID)
        SELECT MAX(ID) AS ID 
        FROM ' || V_TABLEINSERT1 || ' 
        WHERE DOWNLOAD_DATE = ''' || CAST(V_CURRDATE AS VARCHAR(10)) || '''::DATE 
            AND DO_AMORT = ''N'' 
        GROUP BY MASTERID';
    EXECUTE (V_STR_QUERY);

    CALL SP_IFRS_LOG_AMORT(V_CURRDATE, 'DEBUG', 'SP_IFRS_LBM_ACCT_EIR_ACF_ACRU', 'P1');

    V_STR_QUERY := '';
    V_STR_QUERY := V_STR_QUERY || 'TRUNCATE TABLE ' || TMP_T2 || ' ';
    EXECUTE (V_STR_QUERY);

    V_STR_QUERY := '';
    V_STR_QUERY := V_STR_QUERY || 'INSERT INTO ' || TMP_P1 || ' (
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
        GROUP BY A.DOWNLOAD_DATE
            ,A.FACNO
            ,A.CIFNO
            ,A.DATASOURCE
            ,A.ACCTNO
            ,A.MASTERID';
    EXECUTE (V_STR_QUERY);

    CALL SP_IFRS_LOG_AMORT(V_CURRDATE, 'DEBUG', 'SP_IFRS_LBM_ACCT_EIR_ACF_ACRU', 'T1 FEE');
   
    V_STR_QUERY := '';
    V_STR_QUERY := V_STR_QUERY || 'UPDATE ' || V_TABLEINSERT6 || ' 
        SET SUM_AMT = B.SUM_AMT
        FROM ' || TMP_P1 || ' B 
        WHERE B.MASTERID = ' || V_TABLEINSERT6 || '.MASTERID
            AND B.DOWNLOAD_DATE =  ' || V_TABLEINSERT6 || '.ECFDATE
            AND ' || V_TABLEINSERT6 || '.FLAG_CF = ''F''
        ';
    EXECUTE (V_STR_QUERY);

    CALL SP_IFRS_LOG_AMORT(V_CURRDATE, 'DEBUG', 'SP_IFRS_LBM_ACCT_EIR_ACF_ACRU', 'INSERT FEE');

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
            ,ROUND(CAST(CAST(B.AMOUNT AS FLOAT) / CAST(B.SUM_AMT AS FLOAT) AS DECIMAL(32, 20)) * A.N_UNAMORT_FEE, @V_ROUND, @V_FUNCROUND) AS N_AMOUNT
            ,B.STATUS
            ,CURRENT_TIMESTAMP
            ,A.ACCTNO
            ,A.MASTERID
            ,B.FLAG_CF
            ,B.FLAG_REVERSE
            ,B.BRCODE
            ,B.SRCPROCESS
            ,''EIR''
            ,''EIRACF02''
            ,''2''
            ,B.AMOUNT_ORG
            ,B.ORG_CCY
            ,B.ORG_CCY_EXRATE
            ,B.PRDTYPE
            ,B.CF_ID 
        FROM ' || V_TABLEINSERT1 || ' A 
        JOIN ' || TMP_P1 || ' C ON A.ID = C.ID
        JOIN ' || V_TABLEINSERT6 || ' B ON B.ECFDATE = A.ECFDATE
            AND A.MASTERID = B.MASTERID
            AND B.FLAG_CF = ''F''
            AND B.STATUS = ''ACT''
        WHERE A.DOWNLOAD_DATE = ''' || CAST(V_CURRDATE AS VARCHAR(10)) || '''::DATE 
            AND (
            (
                A.N_UNAMORT_FEE < 0
                AND A.FLAG_AL = ''A''
            ) OR (
                A.N_UNAMORT_FEE > 0
                AND A.FLAG_AL = ''L''
            )
            )

        ';
    EXECUTE (V_STR_QUERY);

    CALL SP_IFRS_LOG_AMORT(V_CURRDATE, 'DEBUG', 'SP_IFRS_LBM_ACCT_EIR_ACF_ACRU', 'FEE PREV');

    V_STR_QUERY := '';
    V_STR_QUERY := V_STR_QUERY || 'TRUNCATE TABLE ' || TMP_T2 || ' ';
    EXECUTE (V_STR_QUERY);

    V_STR_QUERY := '';
    V_STR_QUERY := V_STR_QUERY || 'INSERT INTO ' || TMP_T2 || ' (
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
        GROUP BY A.DOWNLOAD_DATE
            ,A.FACNO
            ,A.CIFNO
            ,A.DATASOURCE
            ,A.ACCTNO
            ,A.MASTERID';
    EXECUTE (V_STR_QUERY);

    CALL SP_IFRS_LOG_AMORT(V_CURRDATE, 'DEBUG', 'SP_IFRS_LBM_ACCT_EIR_ACF_ACRU', 'T2 COST');

    V_STR_QUERY := '';
    V_STR_QUERY := V_STR_QUERY || 'UPDATE ' || V_TABLEINSERT6 || ' 
        SET SUM_AMT = B.SUM_AMT
        FROM ' || TMP_T2 || ' B 
        WHERE B.MASTERID = ' || V_TABLEINSERT6 || '.MASTERID
            AND B.DOWNLOAD_DATE =  ' || V_TABLEINSERT6 || '.ECFDATE
            AND ' || V_TABLEINSERT6 || '.FLAG_CF = ''C''
    ';
    EXECUTE (V_STR_QUERY);

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
        ) SELECT A.FACNO
            ,A.CIFNO
            ,A.DOWNLOAD_DATE
            ,A.ECFDATE
            ,A.DATASOURCE
            ,B.PRDCODE
            ,B.TRXCODE
            ,B.CCY
            ,ROUND(CAST(CAST(B.AMOUNT AS FLOAT) / CAST(B.SUM_AMT AS FLOAT) AS DECIMAL(32, 20)) * A.N_UNAMORT_COST, @V_ROUND, @V_FUNCROUND) AS N_AMOUNT
            ,B.STATUS
            ,CURRENT_TIMESTAMP
            ,A.ACCTNO
            ,A.MASTERID
            ,B.FLAG_CF
            ,B.FLAG_REVERSE
            ,B.BRCODE
            ,B.SRCPROCESS
            ,''EIR''
            ,''EIRACF02''
            ,''2''
            ,B.AMOUNT_ORG
            ,B.ORG_CCY
            ,B.ORG_CCY_EXRATE
            ,B.PRDTYPE
            ,B.CF_ID
        FROM ' || V_TABLEINSERT1 || ' A
        JOIN ' || TMP_P1 || ' C ON A.ID = C.ID
        JOIN ' || V_TABLEINSERT6 || ' B ON B.ECFDATE = A.ECFDATE
            AND A.MASTERID = B.MASTERID
            AND B.FLAG_CF = ''C''
            AND B.STATUS = ''ACT''
        WHERE A.DOWNLOAD_DATE = ''' || CAST(V_CURRDATE AS VARCHAR(10)) || '''::DATE 
            AND (
            (
                A.N_UNAMORT_COST < 0
                AND A.FLAG_AL = ''A''
            ) OR (
                A.N_UNAMORT_COST > 0
                AND A.FLAG_AL = ''L''
            )
            )
    ';
    EXECUTE (V_STR_QUERY);

    ---- END
    CALL SP_IFRS_LOG_AMORT(V_CURRDATE, 'END', 'SP_IFRS_LBM_ACCT_EIR_ACF_ACRU', '');

    RAISE NOTICE 'SP_IFRS_ACCT_SWITCH | AFFECTED RECORD : %', V_RETURNROWS2;
    ---------- ====== BODY ======

    -------- ====== LOG ======
    V_TABLEDEST = V_TABLEINSERT1;
    V_COLUMNDEST = '-';
    V_SPNAME = 'SP_IFRS_ACCT_SWITCH';
    V_OPERATION = 'INSERT';
    
    CALL SP_IFRS_EXEC_AND_LOG(V_CURRDATE, V_TABLEDEST, V_COLUMNDEST, V_SPNAME, V_OPERATION, V_RETURNROWS2, P_RUNID);
    -------- ====== LOG ======

    -------- ====== RESULT ======
    V_QUERYS = 'SELECT * FROM ' || V_TABLEINSERT1 || '';
    CALL SP_IFRS_RESULT_PREV(V_CURRDATE, V_QUERYS, V_SPNAME, V_RETURNROWS2, P_RUNID);
    -------- ====== RESULT ======

END;

$$;
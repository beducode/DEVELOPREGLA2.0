---- DROP PROCEDURE SP_IFRS_CHECK_AMORT_NOCF;

CREATE OR REPLACE PROCEDURE SP_IFRS_CHECK_AMORT_NOCF(
    IN P_RUNID VARCHAR(20) DEFAULT 'S_00000_0000',
    IN P_DOWNLOAD_DATE DATE DEFAULT NULL,
    IN P_PRC VARCHAR(1) DEFAULT 'S')
LANGUAGE PLPGSQL AS $$
DECLARE
    ---- DATE
    V_PREVDATE DATE;
    V_CURRDATE DATE;
    V_LASTYEAR DATE;
    V_PREVMONTH DATE;
    V_CURRMONTH DATE;
    V_LASTYEARNEXTMONTH DATE;

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
        V_TABLEINSERT1 := 'IFRS_CHECK_AMORT_NOCF_' || P_RUNID || '';
        V_TABLEINSERT2 := 'IFRS_ACCT_JOURNAL_INTM_SUMM_' || P_RUNID || '';
        V_TABLEINSERT3 := 'IFRS_ACCT_EIR_ACF_' || P_RUNID || '';
    ELSE 
        V_TABLENAME := 'IFRS_MASTER_ACCOUNT';
        V_TABLEINSERT1 := 'IFRS_CHECK_AMORT_NOCF';
        V_TABLEINSERT2 := 'IFRS_ACCT_JOURNAL_INTM_SUMM';
        V_TABLEINSERT3 := 'IFRS_ACCT_EIR_ACF';
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
    
    V_PREVMONTH := F_EOMONTH(V_PREVDATE, 1, 'M', 'PREV');
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
        V_STR_QUERY := V_STR_QUERY || 'CREATE TABLE ' || V_TABLEINSERT1 || ' AS SELECT * FROM IFRS_CHECK_AMORT_NOCF WHERE 1=0 ';
        EXECUTE (V_STR_QUERY);
    END IF;
    -------- ====== PRE SIMULATION TABLE ======

    -------- ====== BODY ======
    CALL SP_IFRS_LOG_AMORT(V_CURRDATE, 'START', 'SP_IFRS_CHECK_AMORT_NOCF', '');

    V_STR_QUERY := '';
    V_STR_QUERY := V_STR_QUERY || 'TRUNCATE TABLE ' || V_TABLEINSERT1 || '';
    EXECUTE (V_STR_QUERY);

    V_STR_QUERY := '';
    V_STR_QUERY := V_STR_QUERY || 'TRUNCATE TABLE ' || 'TMP_X' || '';
    EXECUTE (V_STR_QUERY);

    V_STR_QUERY := '';
    V_STR_QUERY := V_STR_QUERY || 'INSERT INTO ' || 'TMP_X' || ' 
        (
            DOWNLOAD_DATE
            ,CCY
            ,MASTERID
            ,JOURNALCODE
            ,AMOUNT
        )
        SELECT 
            DOWNLOAD_DATE
            ,CCY
            ,MASTERID
            ,CASE 
                WHEN JOURNALCODE = ''ACRU4''
                THEN ''AMRT4''
                ELSE JOURNALCODE
            END AS JOURNALCODE
            ,SUM(CASE 
                WHEN REVERSE = ''Y''
                THEN - 1 * N_AMOUNT
                ELSE N_AMOUNT
            END) AS AMOUNT
        FROM ' || V_TABLEINSERT2 || '
        WHERE DOWNLOAD_DATE = ''' || CAST(V_CURRDATE AS VARCHAR(10)) || '''::DATE 
            AND JOURNALCODE IN (
                ''ACRU4''
                ,''AMRT4''
            )
        GROUP BY 
            DOWNLOAD_DATE
            ,CCY
            ,CASE 
                WHEN JOURNALCODE = ''ACRU4''
                THEN ''AMRT4''
                ELSE JOURNALCODE
            END
            ,MASTERID ';
    EXECUTE (V_STR_QUERY);

    V_STR_QUERY := '';
    V_STR_QUERY := V_STR_QUERY || 'INSERT INTO ' || V_TABLEINSERT1 || ' 
        (
            DOWNLOAD_DATE
            ,MASTERID
            ,CCY
            ,JURNAL_AMORT_AMT
		)
        SELECT 
            DOWNLOAD_DATE
            ,MASTERID
            ,CCY
            ,AMOUNT
        FROM ' || 'TMP_X' || ' ';
    EXECUTE (V_STR_QUERY);

    GET DIAGNOSTICS V_RETURNROWS = ROW_COUNT;
    V_RETURNROWS2 := V_RETURNROWS2 + V_RETURNROWS;
    V_RETURNROWS := 0;

    V_STR_QUERY := '';
    V_STR_QUERY := V_STR_QUERY || 'UPDATE ' || V_TABLEINSERT1 || ' A 
        SET ACF_UNAMORT_AMT = B.N_UNAMORT_PREV_NOCF + B.N_ACCRU_NOCF
        FROM (
            SELECT A.*
            FROM ' || V_TABLEINSERT3 || ' A
            WHERE A.ID IN (
                SELECT MAX(ID)
                FROM ' || V_TABLEINSERT3 || '
                WHERE DOWNLOAD_DATE >= ''' || CAST(V_PREVDATE AS VARCHAR(10)) || '''::DATE 
                    AND DOWNLOAD_DATE <= ''' || CAST(V_CURRDATE AS VARCHAR(10)) || '''::DATE 
                    AND MASTERID IN (
                        SELECT MASTERID
                        FROM TMP_X
                    )
                GROUP BY MASTERID
            )
        ) B
        WHERE A.MASTERID = B.MASTERID ';
    EXECUTE (V_STR_QUERY);

    V_STR_QUERY := '';
    V_STR_QUERY := V_STR_QUERY || 'UPDATE ' || V_TABLEINSERT1 || ' A 
        SET CONTROL_AMT = JURNAL_AMORT_AMT - ACF_UNAMORT_AMT ';
    EXECUTE (V_STR_QUERY);

    ---- END
    CALL SP_IFRS_LOG_AMORT(V_CURRDATE, 'END', 'SP_IFRS_CHECK_AMORT_NOCF', '');

    RAISE NOTICE 'SP_IFRS_CHECK_AMORT_NOCF | AFFECTED RECORD : %', V_RETURNROWS2;
    ---------- ====== BODY ======

    -------- ====== LOG ======
    V_TABLEDEST = V_TABLEINSERT1;
    V_COLUMNDEST = '-';
    V_SPNAME = 'SP_IFRS_CHECK_AMORT_NOCF';
    V_OPERATION = 'INSERT';
    
    CALL SP_IFRS_EXEC_AND_LOG(V_CURRDATE, V_TABLEDEST, V_COLUMNDEST, V_SPNAME, V_OPERATION, V_RETURNROWS2, P_RUNID);
    -------- ====== LOG ======

    -------- ====== RESULT ======
    V_QUERYS = 'SELECT * FROM ' || V_TABLEINSERT1 || '';
    CALL SP_IFRS_RESULT_PREV(V_CURRDATE, V_QUERYS, V_SPNAME, V_RETURNROWS2, P_RUNID);
    -------- ====== RESULT ======

END;

$$;
---- DROP PROCEDURE SP_IFRS_IMP_AVG_EIR;

CREATE OR REPLACE PROCEDURE SP_IFRS_IMP_AVG_EIR(
    IN P_RUNID VARCHAR(20) DEFAULT 'S_00000_0000', 
    IN P_DOWNLOAD_DATE DATE DEFAULT NULL,
    IN P_PRC VARCHAR(1) DEFAULT 'S')
LANGUAGE PLPGSQL AS $$
DECLARE
    V_STARTDATE_OF_YEAR DATE;
    V_START DATE;
    V_END DATE;
    ---- DATE
    V_PREVDATE DATE;
    V_PREVMONTH DATE;
    V_CURRDATE DATE;
    V_LASTYEAR DATE;
    V_LASTYEARNEXTMONTH DATE;
       
    V_STR_QUERY TEXT;
    V_STR_SQL_RULE TEXT;        
    V_TABLENAME VARCHAR(100); 
    V_TABLENAME_MON VARCHAR(100);
    V_TABLEINSERT1 VARCHAR(100);
    V_TABLEINSERT2 VARCHAR(100);
    V_TABLEINSERT3 VARCHAR(100);
    V_CODITION TEXT;
    V_RETURNROWS INT;
    V_RETURNROWS2 INT;
    V_TABLEDEST VARCHAR(100);
    V_COLUMNDEST VARCHAR(100);
    V_SPNAME VARCHAR(100);
    V_OPERATION VARCHAR(100);

    ---- RESULT
    V_QUERYS TEXT;
    V_CODITION2 TEXT;

    ---
    V_LOG_SEQ INTEGER;
    V_DIFF_LOG_SEQ INTEGER;
    V_SP_NAME VARCHAR(100);
    V_PRC_NAME VARCHAR(100);
    V_SEQ INTEGER;
    V_SP_NAME_PREV VARCHAR(100);
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
    ELSE 
        V_TABLENAME := 'IFRS_MASTER_ACCOUNT';
        V_TABLENAME_MON := 'IFRS_MASTER_ACCOUNT_MONTHLY';
        V_TABLEINSERT1 := 'TMP_IFRS_ECL_IMA';
        V_TABLEINSERT2 := 'IFRS_IMA_IMP_CURR';
        V_TABLEINSERT3 := 'IFRS_IMA_IMP_PREV';
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

    V_STARTDATE_OF_YEAR := CONCAT(DATE_PART('YEAR',V_CURRDATE),'0101');
    V_START := F_EOMONTH(V_STARTDATE_OF_YEAR, 0, 'M', 'PREV');
    V_END :=  V_PREVMONTH;
    
    V_RETURNROWS2 := 0;
    -------- ====== VARIABLE ======

    -------- ====== BODY ======
    V_STR_QUERY := '';
    V_STR_QUERY := V_STR_QUERY || 'DROP TABLE IF EXISTS IMA_' || P_RUNID || '';
    EXECUTE (V_STR_QUERY);

    V_STR_QUERY := '';
    V_STR_QUERY := V_STR_QUERY || 'CREATE TABLE IMA_' || P_RUNID || ' AS 
    SELECT DOWNLOAD_DATE, MASTERID, EIR_SEGMENT, EIR, MARGIN_RATE, LOAN_START_DATE                              
    FROM ' || V_TABLENAME_MON || '                
    WHERE 1 = 2 ';
    EXECUTE (V_STR_QUERY);


    WHILE V_START <= V_END                
    LOOP                
        EXECUTE 'INSERT INTO IMA_' || P_RUNID || ' (DOWNLOAD_DATE, MASTERID, EIR_SEGMENT, EIR, MARGIN_RATE, LOAN_START_DATE)            
        SELECT DOWNLOAD_DATE, MASTERID, EIR_SEGMENT, EIR, MARGIN_RATE, LOAN_START_DATE            
        FROM ' || V_TABLENAME_MON || '                
        WHERE DOWNLOAD_DATE = ''' || CAST(V_START AS VARCHAR(10)) || '''::DATE                
        ORDER BY DOWNLOAD_DATE, MASTERID';
                                        
        V_START := (DATE_TRUNC('MONTH',(DATE_TRUNC('MONTH', V_START) + INTERVAL '1 MONTH - 1 DAY' + INTERVAL '1 MONTH')) + INTERVAL '1 MONTH - 1 DAY')::DATE;
    END LOOP;

    V_STR_QUERY := '';
    V_STR_QUERY := V_STR_QUERY || 'INSERT INTO IMA_' || P_RUNID || ' (DOWNLOAD_DATE, MASTERID, EIR_SEGMENT, EIR, MARGIN_RATE, LOAN_START_DATE) 
    SELECT DOWNLOAD_DATE, MASTERID, EIR_SEGMENT, EIR, MARGIN_RATE, LOAN_START_DATE 
    FROM ' || V_TABLEINSERT2 || '
    WHERE DOWNLOAD_DATE = ''' || CAST(V_CURRDATE AS VARCHAR(10)) || '''::DATE
    ORDER BY DOWNLOAD_DATE, MASTERID';
    EXECUTE (V_STR_QUERY);

    GET DIAGNOSTICS V_RETURNROWS = ROW_COUNT;
    V_RETURNROWS2 := V_RETURNROWS2 + V_RETURNROWS;
    V_RETURNROWS := 0;

    V_STR_QUERY := '';
    V_STR_QUERY := V_STR_QUERY || 'DELETE FROM IFRS_IMP_AVG_EIR WHERE DOWNLOAD_DATE = ''' || CAST(V_CURRDATE AS VARCHAR(10)) || '''::DATE AND CREATEDBY <> ''AVG_FS''';
    EXECUTE (V_STR_QUERY);

    V_STR_QUERY := '';
    V_STR_QUERY := V_STR_QUERY || ' INSERT INTO IFRS_IMP_AVG_EIR (DOWNLOAD_DATE, AVG_EIR, EIR_SEGMENT, CREATEDBY)                      
    SELECT ''' || CAST(V_CURRDATE AS VARCHAR(10)) || '''::DATE AS DOWNLOAD_DATE, AVG(EIR)/100 AS AVG_EIR, EIR_SEGMENT, ''AVG_EIR''                
    FROM IMA_' || P_RUNID || '                
    WHERE EIR_SEGMENT IS NOT NULL AND DOWNLOAD_DATE >= ''20190101''
    GROUP BY EIR_SEGMENT';
    EXECUTE (V_STR_QUERY);

    GET DIAGNOSTICS V_RETURNROWS = ROW_COUNT;
    V_RETURNROWS2 := V_RETURNROWS2 + V_RETURNROWS;
    V_RETURNROWS := 0;

    V_STR_QUERY := '';
    V_STR_QUERY := V_STR_QUERY || 'UPDATE IFRS_IMP_AVG_EIR AVG                
    SET AVG_EIR = IMA.AVG_EIR, CREATEDBY = IMA.CREATEDBY                
    FROM (                
    SELECT ''' || CAST(V_CURRDATE AS VARCHAR(10)) || '''::DATE AS DOWNLOAD_DATE, AVG(MARGIN_RATE)/100 AS AVG_EIR, EIR_SEGMENT, ''AVG_INT'' AS CREATEDBY                
    FROM IMA_' || P_RUNID || '                
    WHERE DATE_PART(''YEAR'',LOAN_START_DATE) = DATE_PART(''YEAR'',''' || CAST(V_CURRDATE AS VARCHAR(10)) || '''::DATE)               
    AND EIR_SEGMENT IN (SELECT EIR_SEGMENT FROM IFRS_IMP_AVG_EIR WHERE AVG_EIR IS NULL)            
    GROUP BY EIR_SEGMENT                
    ) IMA WHERE AVG.EIR_SEGMENT = IMA.EIR_SEGMENT AND AVG.DOWNLOAD_DATE = IMA.DOWNLOAD_DATE            
    AND AVG.AVG_EIR IS NULL AND AVG.CREATEDBY <> ''AVG_FS''';
    EXECUTE (V_STR_QUERY);

    V_STR_QUERY := '';
    V_STR_QUERY := V_STR_QUERY || 'UPDATE ' || V_TABLEINSERT2 || ' A            
    SET AVG_EIR = B.AVG_EIR            
    FROM IFRS_IMP_AVG_EIR B            
    WHERE A.DOWNLOAD_DATE = B.DOWNLOAD_DATE            
    AND A.EIR_SEGMENT = B.EIR_SEGMENT            
    AND A.DOWNLOAD_DATE = ''' || CAST(V_CURRDATE AS VARCHAR(10)) || '''::DATE';
    EXECUTE (V_STR_QUERY);   

    RAISE NOTICE 'SP_IFRS_IMP_AVG_EIR | AFFECTED RECORD : %', V_RETURNROWS2;
    -------- ====== BODY ======

    -------- ====== LOG ======
    V_TABLEDEST = 'IFRS_IMP_AVG_EIR';
    V_COLUMNDEST = '-';
    V_SPNAME = 'SP_IFRS_IMP_AVG_EIR';
    V_OPERATION = 'INSERT';
    
    CALL SP_IFRS_EXEC_AND_LOG(V_CURRDATE, V_TABLEDEST, V_COLUMNDEST, V_SPNAME, V_OPERATION, V_RETURNROWS2, P_RUNID);
    -------- ====== LOG ======

    -------- ====== RESULT ======
    V_QUERYS = 'SELECT * FROM IFRS_IMP_AVG_EIR';
    CALL SP_IFRS_RESULT_PREV(V_CURRDATE, V_QUERYS, V_SPNAME, V_RETURNROWS2, P_RUNID);
    -------- ====== RESULT ======

END;

$$;
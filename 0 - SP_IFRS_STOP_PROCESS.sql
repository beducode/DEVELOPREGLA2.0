---- DROP PROCEDURE SP_IFRS_STOP_PROCESS;

CREATE OR REPLACE PROCEDURE SP_IFRS_STOP_PROCESS(
    IN P_RUNID VARCHAR(5) DEFAULT 'S0000',
    IN P_DOWNLOAD_DATE DATE DEFAULT NULL)
LANGUAGE PLPGSQL AS $$
DECLARE
	V_PROCESS_ID INT;
    V_CURRDATE DATE; 
BEGIN

    IF P_DOWNLOAD_DATE IS NULL 
    THEN
        SELECT
            CURRDATE INTO V_CURRDATE
        FROM
            IFRS_PRC_DATE;
    ELSE        
        V_CURRDATE := P_DOWNLOAD_DATE;
    END IF;

    EXECUTE 'SELECT PROCESS_ID FROM IFRS_RUNNING_LOGS WHERE DOWNLOAD_DATE = ''' || CAST(V_CURRDATE AS VARCHAR(10)) || '''::DATE AND RUN_ID = ''' || P_RUNID || ''' ' INTO V_PROCESS_ID;
    EXECUTE 'SELECT PG_TERMINATE_BACKEND(PID) 
    FROM PG_STAT_ACTIVITY 
    WHERE PID = ' || V_PROCESS_ID || ' AND PID <> PG_BACKEND_PID() AND DATNAME = ''IFRS9''';
END;
$$;
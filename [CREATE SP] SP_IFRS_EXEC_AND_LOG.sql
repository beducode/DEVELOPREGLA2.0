---- DROP PROCEDURE SP_IFRS_EXEC_AND_LOG;

CREATE OR REPLACE PROCEDURE SP_IFRS_EXEC_AND_LOG (
	IN P_DOWNLOAD_DATE DATE DEFAULT NULL::DATE,
	IN P_TABLE_DEST VARCHAR(100) DEFAULT NULL,
	IN P_COLUMN_DEST TEXT DEFAULT NULL,
	IN P_STORENAME VARCHAR(100) DEFAULT NULL, 
	IN P_OPERATION VARCHAR(100) DEFAULT NULL,
	IN P_AFFECTED_RECORD INT DEFAULT NULL,
	IN P_RUNID VARCHAR(5) DEFAULT 'S0000') 
LANGUAGE PLPGSQL AS $$
BEGIN
	---- RESET LOG
	DELETE FROM IFRS_LOGS_PROCESS WHERE DOWNLOAD_DATE = P_DOWNLOAD_DATE AND TABLE_DEST = P_TABLE_DEST AND SP_NAME = P_STORENAME AND OPERATION = P_OPERATION AND COLUMN_DEST = P_COLUMN_DEST;
	
	---- INSERT LOG
	INSERT INTO IFRS_LOGS_PROCESS (DOWNLOAD_DATE,TABLE_DEST,COLUMN_DEST,SP_NAME,OPERATION,RUN_ID,PROCESS_ID,AFFECTED_RECORD,PROCESS_DATE) VALUES (P_DOWNLOAD_DATE,P_TABLE_DEST,P_COLUMN_DEST,P_STORENAME,P_OPERATION,P_RUNID,PG_BACKEND_PID(),P_AFFECTED_RECORD,CLOCK_TIMESTAMP());

	RAISE NOTICE '%', P_OPERATION || ' ' || P_TABLE_DEST; 
END;
$$;

---- DROP PROCEDURE SP_IFRS_RESULT_PREV;


CREATE OR REPLACE PROCEDURE SP_IFRS_RESULT_PREV (
	IN P_DOWNLOAD_DATE DATE DEFAULT NULL::DATE,
	IN P_QUERYS TEXT DEFAULT NULL,
    IN P_SOURCE_OBJECT VARCHAR(100) DEFAULT NULL, 
	IN P_AFFECTED_RECORD INT DEFAULT NULL,
	IN P_RUNID VARCHAR(20) DEFAULT 'S_000_0000'::VARCHAR(100))
LANGUAGE PLPGSQL AS $$
BEGIN
	---- RESET
	DELETE FROM IFRS_RESULT_PREVIEW WHERE DOWNLOAD_DATE = P_DOWNLOAD_DATE AND SOURCE_OBJECT = P_SOURCE_OBJECT AND QUERY_RESULT = P_QUERYS AND RUN_ID = P_RUNID;
	
	---- INSERT
	INSERT INTO IFRS_RESULT_PREVIEW (DOWNLOAD_DATE,QUERY_RESULT,SOURCE_OBJECT,AFFECTED_RECORD, RUN_ID,PROCESS_DATE)
	VALUES (P_DOWNLOAD_DATE,P_QUERYS,P_SOURCE_OBJECT,P_AFFECTED_RECORD,P_RUNID,CLOCK_TIMESTAMP());

	RAISE NOTICE 'QUERY RESULT : %', P_QUERYS;
END;
$$;
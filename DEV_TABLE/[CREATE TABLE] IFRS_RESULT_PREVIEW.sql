DROP TABLE IF EXISTS IFRS_RESULT_PREVIEW;

CREATE TABLE IF NOT EXISTS IFRS_RESULT_PREVIEW (
  PKID SERIAL PRIMARY KEY,
  DOWNLOAD_DATE DATE,
  QUERY_RESULT TEXT NOT NULL,
  SOURCE_OBJECT VARCHAR(100) NOT NULL,
  AFFECTED_RECORD INT NOT NULL,
  RUN_ID VARCHAR(100) NOT NULL,
  PROCESS_DATE TIMESTAMP WITHOUT TIME ZONE
)
DROP TABLE IF EXISTS IFRS_RUNNING_LOGS;

CREATE TABLE IF NOT EXISTS IFRS_RUNNING_LOGS (
  PKID SERIAL PRIMARY KEY,
  DOWNLOAD_DATE DATE,
  RUN_ID VARCHAR(100) NOT NULL,
  PROCESS_ID BIGINT NOT NULL,
  PROCESS_DATE TIMESTAMP WITHOUT TIME ZONE
)
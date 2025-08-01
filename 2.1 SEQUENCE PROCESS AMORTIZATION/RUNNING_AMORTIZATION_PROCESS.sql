---- PREP DATA SIMULATION ----
-----------------------------------------
CALL SP_IFRS_IMP_SIMULATION_DATA();
-----------------------------------------
---- START AMORTIZATION ENGINE ----
-----------------------------------------
CALL SP_IFRS_AMT_SYNC_BEFORE_PROCESS();
CALL SP_IFRS_AMT_PROCESS_TRAN_DAILY();
CALL SP_IFRS_AMT_ACCT_SWITCH();
CALL SP_IFRS_AMT_GENERATE_PAYM_SCHD();
-- CALL SP_IFRS_AMT_CALC_ACCT_EIR();
-- ------- FIXING
-- CALL SP_IFRS_AMT_ACCT_LBM_PROCESS();
-- CALL SP_IFRS_AMT_ACCT_SL_PROCESS();
-- CALL SP_IFRS_AMT_JOURNAL_RPT();
-----------------------------------------
----- ON PROGRESS FIXING
-----------------------------------------
-- CALL SP_IFRS_AMT_ACCT_LBM_PROCESS();
-- CALL SP_IFRS_AMT_ACCT_SL_PROCESS();
-- CALL SP_IFRS_AMT_JOURNAL_RPT();
-----------------------------------------
-- -- #6
-- ----------------------------------------
-- CALL SP_IFRS_LBM_RESET_AMT_PRC();
-- CALL SP_IFRS_LBM_ACCT_EIR_SWITCH();
-- CALL SP_IFRS_LBM_ACCT_EIR_ACF_PMTDT();
-- CALL SP_LBM_SYNC_PAYM_CORE();
-- CALL SP_IFRS_LBM_ACCT_EIR_ECF_MAIN();
-- CALL SP_IFRS_LBM_STAFF_BENEFIT_SUMM();
-- CALL SP_IFRS_LBM_ACCT_EIR_ACF_ACRU();
-- CALL SP_IFRS_LBM_ACCT_EIR_UPD_ACRU();
-- CALL SP_IFRS_LBM_ACCT_EIR_LAST_ACF();
-- CALL SP_IFRS_LBM_ACCT_EIR_JRNL_INTM();
-- CALL SP_IFRS_LBM_ACCT_EIR_UPD_UNAMRT();
-- ----------------------------------------
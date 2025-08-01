DO
$$
DECLARE
	V_PID BIGINT;
BEGIN
-- ============== PREP ==============
V_PID := (SELECT PG_BACKEND_PID());
RAISE NOTICE 'PROCESS ID ---> %', V_PID;
TRUNCATE TABLE IFRS_LOGS_PROCESS;
TRUNCATE TABLE IFRS_RESULT_PREVIEW;
TRUNCATE TABLE IFRS_RUNNING_LOGS;
-- ============== PREP ==============
-- ============== CALCULATION AMORTIZATION ==============

-- ============== #1 ==============
CALL SP_IFRS_IMP_SIMULATION_DATA(); -- 0
CALL SP_IFRS_RESET_AMT_PRC(); -- 1
CALL SP_IFRS_SYNC_PRODUCT_PARAM(); -- 2
CALL SP_IFRS_SYNC_TRANS_PARAM(); -- 3
CALL SP_IFRS_SYNC_JOURNAL_PARAM(); -- 4
CALL SP_IFRS_SYNC_UPLOAD_TRAN_DAILY(); -- 5 ----> NO DATA
CALL SP_IFRS_AC_SYNC_LIST_VALUE(); -- 6
CALL SP_IFRS_AMT_INITIAL_UPDATE(); -- 7 & 8
-- ============== #1 ==============
-- ============== #2 ==============
CALL SP_IFRS_FILL_IMA_AMORT_PREV_CURR(); --10
CALL SP_IFRS_ACCT_AMORT_RESTRU(); -- 11
CALL SP_IFRS_ACCT_CLOSED(); -- 12
CALL SP_IFRS_PROCESS_TRAN_DAILY(); -- 13
CALL SP_IFRS_COST_FEE_STATUS(); -- 14
CALL SP_IFRS_ACCT_COST_FEE_SUMM(); -- 15 ----> NO DATA
-- ============== #2 ==============
-- ============== #3 ==============
CALL SP_IFRS_ACCT_SWITCH(); -- 16 ----> NO DATA
CALL SP_IFRS_ACCT_SL_SWITCH(); -- 17 ----> NO DATA
CALL SP_IFRS_ACCT_EIR_SWITCH(); -- 18 ----> NO DATA
CALL SP_IFRS_ACCT_EIR_ACF_PMTDT(); -- 19 ----> NO DATA
CALL SP_IFRS_ACCT_EIR_ECF_EVENT(); -- 20
-- ============== #3 ==============

-- CALL SP_IFRS_PAYM_SCHD(); -- 21
-- CALL SP_IFRS_PAYM_SCHD_SRC(); -- 22
-- CALL SP_IFRS_PAYM_SCHD_MTM(); -- 23
-- CALL SP_IFRS_ACCT_EIR_ECF_MAIN(); -- 24
-- CALL SP_IFRS_PAYM_CORE_PROC_NOP(); -- 25
-- CALL SP_IFRS_ACCT_EIR_CF_ECF_GRP(); -- 26
-- CALL SP_IFRS_ACCT_EIR_GS_RANGE(); -- 27
-- CALL SP_IFRS_ACCT_EIR_GS_PROC3(); -- 28
-- CALL SP_IFRS_ACCT_EIR_GS_INSERT4(); -- 29
-- CALL SP_IFRS_ACCT_EIR_ECF_ALIGN4(); -- 30
-- CALL SP_IFRS_ACCT_EIR_GS_INSERT(); -- 31
-- CALL SP_IFRS_ACCT_EIR_ECF_ALIGN(); -- 32
-- CALL SP_IFRS_ACCT_EIR_ECF_MERGE(); -- 33
-- CALL SP_IFRS_STAFF_BENEFIT_SUMM(); -- 34
-- CALL SP_IFRS_ACCT_EIR_ACF_ACRU(); -- 35
-- -- CALL SP_IFRS_ACCT_EIR_UPD_ACRU -- 36 SKIP
-- CALL SP_IFRS_ACCT_EIR_LAST_ACF(); -- 37
-- CALL SP_IFRS_ACCT_EIR_JRNL_INTM(); -- 38
-- CALL SP_IFRS_LBM_RESET_AMT_PRC(); -- 39
-- CALL SP_IFRS_LBM_ACCT_EIR_SWITCH(); -- 40
-- CALL SP_IFRS_LBM_ACCT_EIR_ACF_PMTDT(); -- 41
-- CALL SP_LBM_SYNC_PAYM_CORE(); -- 42
-- CALL SP_IFRS_LBM_ACCT_EIR_ECF_MAIN(); -- 43
-- CALL SP_IFRS_LBM_STAFF_BENEFIT_SUMM(); -- 44
-- CALL SP_IFRS_LBM_ACCT_EIR_ACF_ACRU(); -- 45
-- CALL SP_IFRS_LBM_ACCT_EIR_UPD_ACRU(); -- 46
-- CALL SP_IFRS_LBM_ACCT_EIR_LAST_ACF(); -- 47
-- CALL SP_IFRS_LBM_ACCT_EIR_JRNL_INTM(); -- 48
-- CALL SP_IFRS_LBM_ACCT_EIR_UPD_UNAMRT(); -- 49
-- CALL SP_IFRS_ACCT_SL_ACF_PMTDATE(); -- 50
-- CALL SP_IFRS_ACCT_SL_ECF_EVENT(); -- 51
-- CALL SP_IFRS_ACCT_SL_ACF_ACCRU(); -- 52
-- CALL SP_IFRS_ACCT_SL_UPD_ACRU(); -- 53
-- CALL SP_IFRS_ACCT_SL_LAST_ACF(); -- 54
-- -- CALL SP_IFRS_ACCT_SL_LAST_ACF -- 55 SKIP
-- CALL SP_IFRS_ACCT_SL_UPD_UNAMRT(); -- 56
-- CALL SP_IFRS_ACCT_SL_JRNL_INTM(); -- 57
-- CALL SP_IFRS_ACCT_EIR_UPD_UNAMRT(); -- 58
-- CALL SP_IFRS_ACCT_JRNL_INTM_SUMM(); -- 59
-- CALL SP_IFRS_CFID_JRNL_INTM_SUMM(); -- 60
-- CALL SP_IFRS_JRNL_ACF_ABN_ADJ(); -- 61
-- CALL SP_IFRS_ACCT_JOURNAL_DATA(); -- 62
-- CALL SP_IFRS_ACCT_JRNL_DATA_MTM(); -- 63
-- CALL SP_IFRS_GL_OUTBOUNDsql(); -- 64
-- CALL SP_IFRS_REPORT_RECON(); -- 65
-- CALL SP_IFRS_LBM_REPORT_RECON(); -- 66
-- CALL SP_IFRS_NOMINATIF(); -- 67
-- CALL SP_IFRS_TREASURY_NOMINATIF(); -- 68
-- CALL SP_IFRS_CHECK_AMORT(); -- 69
-- CALL SP_IFRS_CHECK_AMORT_NOCF(); -- 70
-- CALL SP_IFRS_EXCEPTION_REPORT(); -- 71
-- ============== CALCULATION AMORTIZATION ==============
END;
$$;
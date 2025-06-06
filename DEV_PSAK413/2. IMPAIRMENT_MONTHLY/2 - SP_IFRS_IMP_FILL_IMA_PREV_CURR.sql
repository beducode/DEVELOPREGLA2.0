---- DROP PROCEDURE SP_IFRS_IMP_FILL_IMA_PREV_CURR;

CREATE OR REPLACE PROCEDURE SP_IFRS_IMP_FILL_IMA_PREV_CURR(
    IN P_RUNID VARCHAR(20) DEFAULT 'S_00000_0000', 
    IN P_DOWNLOAD_DATE DATE DEFAULT NULL,
    IN P_PRC VARCHAR(1) DEFAULT 'S')
LANGUAGE PLPGSQL AS $$
DECLARE
    V_PREVDATE DATE;
    V_PREVMONTH DATE;
    V_CURRDATE DATE;
    V_LASTYEAR DATE;
    V_LASTYEARNEXTMONTH DATE;
     
    V_STR_QUERY TEXT;        
    V_TABLENAME VARCHAR(100); 
    V_TABLENAME_MON VARCHAR(100);
    V_TABLEINSERT1 VARCHAR(100);
    V_TABLEINSERT2 VARCHAR(100);
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
        V_TABLEINSERT1 := 'IFRS_IMA_IMP_CURR_' || P_RUNID || '';
        V_TABLEINSERT2 := 'IFRS_IMA_IMP_PREV_' || P_RUNID || '';
    ELSE 
        V_TABLENAME := 'IFRS_MASTER_ACCOUNT';
        V_TABLENAME_MON := 'IFRS_MASTER_ACCOUNT_MONTHLY';
        V_TABLEINSERT1 := 'IFRS_IMA_IMP_CURR';
        V_TABLEINSERT2 := 'IFRS_IMA_IMP_PREV';
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

    V_RETURNROWS2 := 0;
    -------- ====== VARIABLE ======

    -------- ====== BODY ======
    IF P_PRC = 'S' THEN
            V_STR_QUERY := '';
            V_STR_QUERY := V_STR_QUERY || 'DROP TABLE IF EXISTS ' || V_TABLEINSERT1 || ' ';
            EXECUTE (V_STR_QUERY);

            V_STR_QUERY := '';
            V_STR_QUERY := V_STR_QUERY || 'CREATE TABLE ' || V_TABLEINSERT1 || ' AS SELECT * FROM IFRS_IMA_IMP_CURR WHERE 0=1';
            EXECUTE (V_STR_QUERY);

            V_STR_QUERY := '';
            V_STR_QUERY := V_STR_QUERY || 'DROP SEQUENCE IF EXISTS ' || V_TABLEINSERT1 || '_PKID_SEQ ';
            EXECUTE (V_STR_QUERY);

            V_STR_QUERY := '';
            V_STR_QUERY := V_STR_QUERY || 'CREATE SEQUENCE IF NOT EXISTS ' || V_TABLEINSERT1 || '_PKID_SEQ
            INCREMENT 1
            START 1
            MINVALUE 1
            MAXVALUE 9223372036854775807
            CACHE 1';
            EXECUTE (V_STR_QUERY);

            V_STR_QUERY := '';
            V_STR_QUERY := V_STR_QUERY || 'ALTER TABLE ' || V_TABLEINSERT1 || ' ALTER COLUMN PKID SET DEFAULT nextval('' ' || V_TABLEINSERT1 || '_PKID_SEQ '') ';
            EXECUTE (V_STR_QUERY);

            V_STR_QUERY := '';
            V_STR_QUERY := V_STR_QUERY || 'DROP INDEX IF EXISTS NCI_' || V_TABLEINSERT1 || ' ';
            EXECUTE (V_STR_QUERY);

            V_STR_QUERY := '';
            V_STR_QUERY := V_STR_QUERY || 'CREATE INDEX IF NOT EXISTS NCI_' || V_TABLEINSERT1 || '
            ON ' || V_TABLEINSERT1 || ' USING BTREE
            (DOWNLOAD_DATE ASC NULLS LAST, MASTERID ASC NULLS LAST, MASTER_ACCOUNT_CODE ASC NULLS LAST, PRODUCT_CODE ASC NULLS LAST, ACCOUNT_NUMBER ASC NULLS LAST)
            TABLESPACE PG_DEFAULT';
            EXECUTE (V_STR_QUERY);
        ELSE
            V_STR_QUERY := '';
            V_STR_QUERY := V_STR_QUERY || 'TRUNCATE TABLE ' || V_TABLEINSERT1 || '';
            EXECUTE (V_STR_QUERY);

            V_STR_QUERY := '';
            V_STR_QUERY := V_STR_QUERY || 'TRUNCATE TABLE ' || V_TABLEINSERT2 || '';
            EXECUTE (V_STR_QUERY);

    END IF;

    V_STR_QUERY := '';
    V_STR_QUERY := V_STR_QUERY || 'INSERT INTO ' || V_TABLEINSERT1 || '                                                    
    (                                                
    DOWNLOAD_DATE                                
    ,MASTERID                                
    ,MASTER_ACCOUNT_CODE                                
    ,DATA_SOURCE                                
    ,GLOBAL_CUSTOMER_NUMBER                                
    ,CUSTOMER_NUMBER                                
    ,CUSTOMER_NAME                                
    ,FACILITY_NUMBER                                
    ,ACCOUNT_NUMBER                                
    ,PREVIOUS_ACCOUNT_NUMBER                                
    ,ACCOUNT_STATUS                                
    ,MARGIN_RATE                                
    ,MARKET_RATE                                
    ,PRODUCT_GROUP                                
    ,PRODUCT_TYPE                                
    ,PRODUCT_CODE                                
    ,PRODUCT_ENTITY                                
    ,GL_CONSTNAME                                
    ,BRANCH_CODE                                
    ,BRANCH_CODE_OPEN                                
    ,CURRENCY                                
    ,EXCHANGE_RATE                                
    ,INITIAL_OUTSTANDING                                
    ,OUTSTANDING                                
    ,OUTSTANDING_IDC                                
    ,OUTSTANDING_JF                                
    ,OUTSTANDING_BANK                                
    ,OUTSTANDING_PASTDUE                                
    ,OUTSTANDING_WO                                
    ,PLAFOND                                
    ,PLAFOND_CASH                                
    ,MARGIN_ACCRUED                                
    ,INSTALLMENT_AMOUNT                                
    ,UNUSED_AMOUNT                                
    ,DOWN_PAYMENT_AMOUNT                                
    ,JF_FLAG                                
    ,LOAN_START_DATE                                
    ,LOAN_DUE_DATE                                
    ,LOAN_START_AMORTIZATION                                
    ,LOAN_END_AMORTIZATION                                
    ,INSTALLMENT_GRACE_PERIOD                                
    ,NEXT_PAYMENT_DATE                                
    ,NEXT_INT_PAYMENT_DATE                                
    ,LAST_PAYMENT_DATE                                
    ,FIRST_INSTALLMENT_DATE                                
    ,TENOR                                
    ,REMAINING_TENOR                                
    ,PAYMENT_CODE                                
    ,PAYMENT_TERM                                
    ,MARGIN_CALCULATION_CODE                                
    ,MARGIN_PAYMENT_TERM                                
    ,RESTRUCTURE_DATE                                
    ,RESTRUCTURE_FLAG                                
    ,POCI_FLAG                                
    ,STAFF_LOAN_FLAG                                
    ,BELOW_MARKET_FLAG                               
    ,BTB_FLAG                                
    ,COMMITTED_FLAG                                
    ,REVOLVING_FLAG                                
    ,IAS_CLASS                                
    ,IFRS9_CLASS                                
    ,AMORT_TYPE                                
    ,EIR_STATUS                                
    ,ECF_STATUS                                
    ,EIR                                
    ,EIR_AMOUNT                                
    ,FAIR_VALUE_AMOUNT                                
    ,INITIAL_UNAMORT_TXN_COST                     
    ,INITIAL_UNAMORT_ORG_FEE                                
    ,UNAMORT_COST_AMT                                
    ,UNAMORT_FEE_AMT                                
    ,DAILY_AMORT_AMT                                
    ,UNAMORT_AMT_TOTAL_JF                                
    ,UNAMORT_FEE_AMT_JF                                
    ,UNAMORT_COST_AMT_JF                                
    ,ORIGINAL_COLLECTABILITY                                
    ,BI_COLLECTABILITY                             
    ,DAY_PAST_DUE                                
    ,DPD_START_DATE                                
    ,DPD_ZERO_COUNTER                                
    ,NPL_DATE                                
    ,NPL_FLAG                                
    ,DEFAULT_DATE                       
    ,DEFAULT_FLAG                                
    ,WRITEOFF_FLAG                                
    ,WRITEOFF_DATE                                
    ,IMPAIRED_FLAG                                
    ,IS_IMPAIRED                                
    ,GROUP_SEGMENT                                
    ,SEGMENT                       
    ,SUB_SEGMENT                                
    ,STAGE                                
    ,LIFETIME                                
    ,EAD_RULE_ID                                
    ,EAD_SEGMENT                                
    ,EAD_AMOUNT                                
    ,LGD_RULE_ID                                
    ,LGD_SEGMENT                                
    ,PD_RULE_ID                                
    ,PD_SEGMENT                                
    ,BUCKET_GROUP                                
    ,BUCKET_ID                                
    ,EIL_12_AMOUNT                                
    ,EIL_LIFETIME_AMOUNT                                
    ,EIL_AMOUNT                                
    ,CA_UNWINDING_AMOUNT                                
    ,IA_UNWINDING_AMOUNT                                
    ,IA_UNWINDING_SUM_AMOUNT                                
    ,BEGINNING_BALANCE                                
    ,ENDING_BALANCE                                
    ,WRITEBACK_AMOUNT                                
    ,CHARGE_AMOUNT                                
    ,CREATEDBY                                
    ,CREATEDDATE                                
    ,CREATEDHOST                                
    ,UPDATEDBY                                
    ,UPDATEDDATE                                
    ,UPDATEDHOST                                
    ,INITIAL_BENEFIT                                
    ,UNAMORT_BENEFIT                                
    ,SPPI_RESULT                                
    ,BM_RESULT                                
    ,ECONOMIC_SECTOR                                
    ,AO_CODE                                
    ,SUFFIX                                
    ,ACCOUNT_TYPE                                
    ,CUSTOMER_TYPE                                
    ,OUTSTANDING_PROFIT_DUE                                
    ,RESTRUCTURE_COLLECT_FLAG                                
    ,DPD_FINAL                                
    ,EIR_SEGMENT                                
    ,DPD_CIF                                
    ,DPD_FINAL_CIF                                
    ,BI_COLLECT_CIF                                
    ,PRODUCT_TYPE_1                                
    ,RATING_CODE                                
    ,CCF                                
    ,CCF_RULE_ID                                
    ,CCF_EFF_DATE                              
    ,EIL_AMOUNT_BFL                                
    ,AVG_EIR                                
    ,EIL_MODEL_ID                                
    ,SEGMENTATION_ID                                
    ,PD_ME_MODEL_ID                                
    ,DEFAULT_RULE_ID                    
    ,PLAFOND_CIF                      
    ,RESTRUCTURE_COLLECT_FLAG_CIF                   
    ,SOURCE_SYSTEM              
    ,INITIAL_RATING_CODE              
    ,PD_INITIAL_RATE              
    ,PD_CURRENT_RATE              
    ,PD_CHANGE              
    ,LIMIT_CURRENCY              
    ,SUN_ID              
    ,RATING_DOWNGRADE              
    ,WATCHLIST_FLAG              
    ,COLL_AMOUNT              
    ,FACILITY_NUMBER_PARENT            
    ,EXT_RATING_AGENCY            
    ,EXT_RATING_CODE            
    ,EXT_INIT_RATING_CODE            
    ,MARGIN_TYPE            
    ,SOVEREIGN_FLAG            
    ,ISIN_CODE            
    ,INV_TYPE            
    ,UNAMORT_DISCOUNT_PREMIUM            
    ,DISCOUNT_PREMIUM_AMOUNT            
    ,PRODUCT_CODE_T24            
    ,EXT_RATING_DOWNGRADE            
    ,SANDI_BANK        
    ,LOB_CODE         
    ,COUNTER_GUARANTEE_FLAG      
    ,EARLY_PAYMENT        
    ,EARLY_PAYMENT_FLAG        
    ,EARLY_PAYMENT_DATE    
    ,SEGMENT_FLAG      
    )                                                    
    SELECT                                                 
    DOWNLOAD_DATE                                
    ,MASTERID                                
    ,MASTER_ACCOUNT_CODE                                
    ,DATA_SOURCE                                
    ,GLOBAL_CUSTOMER_NUMBER                                
    ,CUSTOMER_NUMBER                                
    ,CUSTOMER_NAME                                
    ,FACILITY_NUMBER                                
    ,ACCOUNT_NUMBER                                
    ,PREVIOUS_ACCOUNT_NUMBER                                
    ,ACCOUNT_STATUS                                
    ,MARGIN_RATE                                
    ,MARKET_RATE                                
    ,PRODUCT_GROUP                                
    ,PRODUCT_TYPE                                
    ,PRODUCT_CODE                                
    ,PRODUCT_ENTITY                                
    ,GL_CONSTNAME                                
    ,BRANCH_CODE                                
    ,BRANCH_CODE_OPEN                    
    ,CURRENCY                                
    ,EXCHANGE_RATE                                
    ,COALESCE(INITIAL_OUTSTANDING, 0) AS INITIAL_OUTSTANDING            
    ,COALESCE(OUTSTANDING, 0) AS OUTSTANDING            
    ,OUTSTANDING_IDC                                
    ,OUTSTANDING_JF                                
    ,OUTSTANDING_BANK                                
    ,OUTSTANDING_PASTDUE                                
    ,OUTSTANDING_WO                                
    ,PLAFOND                                
    ,PLAFOND_CASH                                
    ,COALESCE(MARGIN_ACCRUED, 0) AS MARGIN_ACCRUED            
    ,INSTALLMENT_AMOUNT                                
    ,COALESCE(UNUSED_AMOUNT, 0) AS UNUSED_AMOUNT            
    ,DOWN_PAYMENT_AMOUNT                                
    ,JF_FLAG                                
    ,LOAN_START_DATE                                
    ,LOAN_DUE_DATE                                
    ,LOAN_START_AMORTIZATION                                
    ,LOAN_END_AMORTIZATION                                
    ,INSTALLMENT_GRACE_PERIOD                                
    ,NEXT_PAYMENT_DATE                                
    ,NEXT_INT_PAYMENT_DATE                                
    ,LAST_PAYMENT_DATE                                
    ,FIRST_INSTALLMENT_DATE                                
    ,TENOR                                
    ,REMAINING_TENOR                                
    ,PAYMENT_CODE                                
    ,PAYMENT_TERM                                
    ,MARGIN_CALCULATION_CODE                                
    ,MARGIN_PAYMENT_TERM                                
    ,RESTRUCTURE_DATE                                
    ,RESTRUCTURE_FLAG                     
    ,POCI_FLAG                                
    ,STAFF_LOAN_FLAG                                
    ,BELOW_MARKET_FLAG                                
    ,BTB_FLAG                                
    ,COMMITTED_FLAG                                
    ,REVOLVING_FLAG                                
    ,IAS_CLASS                                
    ,IFRS9_CLASS                                
    ,AMORT_TYPE                                
    ,EIR_STATUS                                
    ,ECF_STATUS                                
    ,EIR                                
    ,EIR_AMOUNT       
    ,FAIR_VALUE_AMOUNT                                
    ,INITIAL_UNAMORT_TXN_COST                
    ,INITIAL_UNAMORT_ORG_FEE                                
    ,UNAMORT_COST_AMT                                
    ,UNAMORT_FEE_AMT                                
    ,DAILY_AMORT_AMT                                
    ,UNAMORT_AMT_TOTAL_JF                                
    ,UNAMORT_FEE_AMT_JF                                
    ,UNAMORT_COST_AMT_JF                                
    ,ORIGINAL_COLLECTABILITY                                
    ,BI_COLLECTABILITY                                
    ,DAY_PAST_DUE                           
    ,DPD_START_DATE                                
    ,DPD_ZERO_COUNTER                                
    ,NPL_DATE                                
    ,NPL_FLAG                                
    ,DEFAULT_DATE                                
    ,DEFAULT_FLAG                                
    ,WRITEOFF_FLAG                                
    ,WRITEOFF_DATE                                
    ,IMPAIRED_FLAG                                
    ,IS_IMPAIRED                                
    ,GROUP_SEGMENT                                
    ,SEGMENT                                
    ,SUB_SEGMENT                                
    ,STAGE                          
    ,LIFETIME                                
    ,NULL AS EAD_RULE_ID                                
    ,NULL AS EAD_SEGMENT                                
    ,0 AS EAD_AMOUNT                                
    ,NULL AS LGD_RULE_ID                                
    ,NULL AS LGD_SEGMENT                                
    ,NULL AS PD_RULE_ID                                
    ,NULL AS PD_SEGMENT                                
    ,BUCKET_GROUP                                
    ,BUCKET_ID                                
    ,EIL_12_AMOUNT                                
    ,EIL_LIFETIME_AMOUNT                                
    ,CASE WHEN IMPAIRED_FLAG = ''I'' THEN EIL_AMOUNT ELSE 0 END AS EIL_AMOUNT                                
    ,CA_UNWINDING_AMOUNT                                
    ,IA_UNWINDING_AMOUNT                                
    ,IA_UNWINDING_SUM_AMOUNT                                
    ,BEGINNING_BALANCE                                
    ,ENDING_BALANCE                                
    ,WRITEBACK_AMOUNT                                
    ,CHARGE_AMOUNT                                
    ,CREATEDBY                                
    ,CREATEDDATE                                
    ,CREATEDHOST                                
    ,UPDATEDBY                                
    ,UPDATEDDATE                                
    ,UPDATEDHOST                                
    ,INITIAL_BENEFIT                                
    ,UNAMORT_BENEFIT                                
    ,SPPI_RESULT                                
    ,BM_RESULT                                
    ,ECONOMIC_SECTOR                                
    ,AO_CODE                                
    ,SUFFIX                                
    ,ACCOUNT_TYPE                                
    ,CUSTOMER_TYPE                                
    ,OUTSTANDING_PROFIT_DUE                                
    ,RESTRUCTURE_COLLECT_FLAG                                
    ,DPD_FINAL                                
    ,EIR_SEGMENT                                
    ,DPD_CIF                                
    ,DPD_FINAL_CIF                                
    ,BI_COLLECT_CIF                                
    ,PRODUCT_TYPE_1                                
    ,RATING_CODE                                
    ,NULL AS CCF                                
    ,NULL AS CCF_RULE_ID      
    ,NULL AS CCF_EFF_DATE                                
    ,CASE WHEN IMPAIRED_FLAG = ''I'' THEN EIL_AMOUNT_BFL ELSE 0 END EIL_AMOUNT_BFL                                
    ,AVG_EIR                                
    ,EIL_MODEL_ID                                
    ,SEGMENTATION_ID                                
    ,PD_ME_MODEL_ID                                
    ,DEFAULT_RULE_ID                                
    ,PLAFOND_CIF                       
    ,RESTRUCTURE_COLLECT_FLAG_CIF                  
    ,SOURCE_SYSTEM               
    ,INITIAL_RATING_CODE              
    ,PD_INITIAL_RATE              
    ,PD_CURRENT_RATE              
    ,PD_CHANGE              
    ,LIMIT_CURRENCY              
    ,SUN_ID          
    ,RATING_DOWNGRADE            
    ,WATCHLIST_FLAG              
    ,COALESCE(COLL_AMOUNT, 0) AS COLL_AMOUNT            
    ,FACILITY_NUMBER_PARENT            
    ,EXT_RATING_AGENCY            
    ,EXT_RATING_CODE            
    ,EXT_INIT_RATING_CODE            
    ,MARGIN_TYPE            
    ,SOVEREIGN_FLAG            
    ,ISIN_CODE            
    ,INV_TYPE            
    ,UNAMORT_DISCOUNT_PREMIUM            
    ,DISCOUNT_PREMIUM_AMOUNT            
    ,PRODUCT_CODE_T24            
    ,EXT_RATING_DOWNGRADE              
    ,SANDI_BANK        
    ,LOB_CODE          
    ,COUNTER_GUARANTEE_FLAG        
    ,EARLY_PAYMENT        
    ,EARLY_PAYMENT_FLAG        
    ,EARLY_PAYMENT_DATE        
    ,SEGMENT_FLAG   
    FROM    ' || V_TABLENAME || '                                              
    WHERE   DOWNLOAD_DATE = ''' || CAST(V_CURRDATE AS VARCHAR(10)) || ''' ';
    EXECUTE (V_STR_QUERY);

    GET DIAGNOSTICS V_RETURNROWS = ROW_COUNT;
    V_RETURNROWS2 := V_RETURNROWS2 + V_RETURNROWS;
    V_RETURNROWS := 0;

    IF P_PRC = 'S' THEN
        V_STR_QUERY := '';
        V_STR_QUERY := V_STR_QUERY || 'DROP TABLE IF EXISTS ' || V_TABLEINSERT2 || ' ';
        EXECUTE (V_STR_QUERY);

        V_STR_QUERY := '';
        V_STR_QUERY := V_STR_QUERY || 'CREATE TABLE ' || V_TABLEINSERT2 || ' AS SELECT * FROM IFRS_IMA_IMP_PREV WHERE 0=1';
        EXECUTE (V_STR_QUERY);

        V_STR_QUERY := '';
        V_STR_QUERY := V_STR_QUERY || 'DROP SEQUENCE IF EXISTS ' || V_TABLEINSERT2 || '_PKID_SEQ ';
        EXECUTE (V_STR_QUERY);

        V_STR_QUERY := '';
        V_STR_QUERY := V_STR_QUERY || 'CREATE SEQUENCE IF NOT EXISTS ' || V_TABLEINSERT2 || '_PKID_SEQ
        INCREMENT 1
        START 1
        MINVALUE 1
        MAXVALUE 9223372036854775807
        CACHE 1';
        EXECUTE (V_STR_QUERY);

        V_STR_QUERY := '';
        V_STR_QUERY := V_STR_QUERY || 'ALTER TABLE ' || V_TABLEINSERT2 || ' ALTER COLUMN PKID SET DEFAULT nextval('' ' || V_TABLEINSERT2 || '_PKID_SEQ '') ';
        EXECUTE (V_STR_QUERY);

        V_STR_QUERY := '';
        V_STR_QUERY := V_STR_QUERY || 'DROP INDEX IF EXISTS NCI_' || V_TABLEINSERT2 || ' ';
        EXECUTE (V_STR_QUERY);

        V_STR_QUERY := '';
        V_STR_QUERY := V_STR_QUERY || 'CREATE INDEX IF NOT EXISTS NCI_' || V_TABLEINSERT2 || '
        ON ' || V_TABLEINSERT2 || ' USING BTREE
        (DOWNLOAD_DATE ASC NULLS LAST, MASTERID ASC NULLS LAST, MASTER_ACCOUNT_CODE ASC NULLS LAST, PRODUCT_CODE ASC NULLS LAST, ACCOUNT_NUMBER ASC NULLS LAST)
        TABLESPACE PG_DEFAULT';
        EXECUTE (V_STR_QUERY);
    END IF;

    V_STR_QUERY := '';
    V_STR_QUERY := V_STR_QUERY || 'INSERT INTO ' || V_TABLEINSERT2 || '                                              
    (                                       
    DOWNLOAD_DATE                                
    ,MASTERID                                
    ,MASTER_ACCOUNT_CODE                                
    ,DATA_SOURCE                                
    ,GLOBAL_CUSTOMER_NUMBER                                
    ,CUSTOMER_NUMBER                                
    ,CUSTOMER_NAME                                
    ,FACILITY_NUMBER                                
    ,ACCOUNT_NUMBER                                
    ,PREVIOUS_ACCOUNT_NUMBER                                
    ,ACCOUNT_STATUS                                
    ,MARGIN_RATE                                
    ,MARKET_RATE                    
    ,PRODUCT_GROUP                                
    ,PRODUCT_TYPE                                
    ,PRODUCT_CODE                                
    ,PRODUCT_ENTITY                                
    ,GL_CONSTNAME                                
    ,BRANCH_CODE                                
    ,BRANCH_CODE_OPEN                                
    ,CURRENCY                                
    ,EXCHANGE_RATE                                
    ,INITIAL_OUTSTANDING                                
    ,OUTSTANDING                                
    ,OUTSTANDING_IDC                                
    ,OUTSTANDING_JF                                
    ,OUTSTANDING_BANK                                
    ,OUTSTANDING_PASTDUE                                
    ,OUTSTANDING_WO                                
    ,PLAFOND                                
    ,PLAFOND_CASH                                
    ,MARGIN_ACCRUED                                
    ,INSTALLMENT_AMOUNT                                
    ,UNUSED_AMOUNT                                
    ,DOWN_PAYMENT_AMOUNT                                
    ,JF_FLAG                                
    ,LOAN_START_DATE                      
    ,LOAN_DUE_DATE                                
    ,LOAN_START_AMORTIZATION                                
    ,LOAN_END_AMORTIZATION                                
    ,INSTALLMENT_GRACE_PERIOD                                
    ,NEXT_PAYMENT_DATE                                
    ,NEXT_INT_PAYMENT_DATE                                
    ,LAST_PAYMENT_DATE                                
    ,FIRST_INSTALLMENT_DATE                                
    ,TENOR                                
    ,REMAINING_TENOR                                
    ,PAYMENT_CODE                                
    ,PAYMENT_TERM                   
    ,MARGIN_CALCULATION_CODE                                
    ,MARGIN_PAYMENT_TERM                                
    ,RESTRUCTURE_DATE                                
    ,RESTRUCTURE_FLAG                                
    ,POCI_FLAG                                
    ,STAFF_LOAN_FLAG                                
    ,BELOW_MARKET_FLAG                                
    ,BTB_FLAG                                
    ,COMMITTED_FLAG                                
    ,REVOLVING_FLAG                                
    ,IAS_CLASS                                
    ,IFRS9_CLASS                                
    ,AMORT_TYPE                
    ,EIR_STATUS                                
    ,ECF_STATUS                                
    ,EIR                                
    ,EIR_AMOUNT                                
    ,FAIR_VALUE_AMOUNT                                
    ,INITIAL_UNAMORT_TXN_COST                                
    ,INITIAL_UNAMORT_ORG_FEE                                
    ,UNAMORT_COST_AMT                                
    ,UNAMORT_FEE_AMT                                
    ,DAILY_AMORT_AMT                                
    ,UNAMORT_AMT_TOTAL_JF                                
    ,UNAMORT_FEE_AMT_JF                                
    ,UNAMORT_COST_AMT_JF                                
    ,ORIGINAL_COLLECTABILITY                                
    ,BI_COLLECTABILITY                                
    ,DAY_PAST_DUE                                
    ,DPD_START_DATE                                
    ,DPD_ZERO_COUNTER                                
    ,NPL_DATE                                
    ,NPL_FLAG                                
    ,DEFAULT_DATE                                
    ,DEFAULT_FLAG                                
    ,WRITEOFF_FLAG                                
    ,WRITEOFF_DATE                                
    ,IMPAIRED_FLAG                                
    ,IS_IMPAIRED                                
    ,GROUP_SEGMENT                                
    ,SEGMENT                                
    ,SUB_SEGMENT                                
    ,STAGE                                
    ,LIFETIME                                
    ,EAD_RULE_ID                                
    ,EAD_SEGMENT                                
    ,EAD_AMOUNT                                
    ,LGD_RULE_ID                          
    ,LGD_SEGMENT                                
    ,PD_RULE_ID                                
    ,PD_SEGMENT                                
    ,BUCKET_GROUP                                
    ,BUCKET_ID                                
    ,EIL_12_AMOUNT                                
    ,EIL_LIFETIME_AMOUNT                                
    ,EIL_AMOUNT                                
    ,CA_UNWINDING_AMOUNT                                
    ,IA_UNWINDING_AMOUNT                                
    ,IA_UNWINDING_SUM_AMOUNT                                
    ,BEGINNING_BALANCE                                
    ,ENDING_BALANCE                                
    ,WRITEBACK_AMOUNT                                
    ,CHARGE_AMOUNT                                
    ,CREATEDBY                                
    ,CREATEDDATE                                
    ,CREATEDHOST                                
    ,UPDATEDBY                                
    ,UPDATEDDATE                                
    ,UPDATEDHOST                                
    ,INITIAL_BENEFIT                                
    ,UNAMORT_BENEFIT                                
    ,SPPI_RESULT                                
    ,BM_RESULT                                
    ,ECONOMIC_SECTOR                                
    ,AO_CODE                                
    ,SUFFIX                                
    ,ACCOUNT_TYPE                                
    ,CUSTOMER_TYPE                                
    ,OUTSTANDING_PROFIT_DUE                                
    ,RESTRUCTURE_COLLECT_FLAG                                
    ,DPD_FINAL                                
    ,EIR_SEGMENT                                
    ,DPD_CIF                                
    ,DPD_FINAL_CIF                                
    ,BI_COLLECT_CIF           
    ,PRODUCT_TYPE_1                                
    ,RATING_CODE                                
    ,CCF                                
    ,CCF_RULE_ID                                
    ,CCF_EFF_DATE                                
    ,EIL_AMOUNT_BFL                                
    ,AVG_EIR                         
    ,EIL_MODEL_ID                                
    ,SEGMENTATION_ID                                
    ,PD_ME_MODEL_ID                                
    ,DEFAULT_RULE_ID                                
    ,PLAFOND_CIF                  
    ,RESTRUCTURE_COLLECT_FLAG_CIF                
    ,SOURCE_SYSTEM                
    ,INITIAL_RATING_CODE              
    ,PD_INITIAL_RATE              
    ,PD_CURRENT_RATE              
    ,PD_CHANGE              
    ,LIMIT_CURRENCY              
    ,SUN_ID              
    ,RATING_DOWNGRADE              
    ,WATCHLIST_FLAG              
    ,COLL_AMOUNT              
    ,FACILITY_NUMBER_PARENT            
    ,EXT_RATING_AGENCY            
    ,EXT_RATING_CODE            
    ,EXT_INIT_RATING_CODE            
    ,MARGIN_TYPE            
    ,SOVEREIGN_FLAG      
    ,ISIN_CODE            
    ,INV_TYPE            
    ,UNAMORT_DISCOUNT_PREMIUM            
    ,DISCOUNT_PREMIUM_AMOUNT            
    ,PRODUCT_CODE_T24            
    ,EXT_RATING_DOWNGRADE            
    ,SANDI_BANK        
    ,LOB_CODE        
    ,COUNTER_GUARANTEE_FLAG --202202207 INDRA        
    ,EARLY_PAYMENT        
    ,EARLY_PAYMENT_FLAG        
    ,EARLY_PAYMENT_DATE        
    ,SEGMENT_FLAG      
    )                                                    
    SELECT                                
    DOWNLOAD_DATE                                
    ,MASTERID                                
    ,MASTER_ACCOUNT_CODE                                
    ,DATA_SOURCE                                
    ,GLOBAL_CUSTOMER_NUMBER                                
    ,CUSTOMER_NUMBER                                
    ,CUSTOMER_NAME                                
    ,FACILITY_NUMBER                                
    ,ACCOUNT_NUMBER                                
    ,PREVIOUS_ACCOUNT_NUMBER                                
    ,ACCOUNT_STATUS                                
    ,MARGIN_RATE                                
    ,MARKET_RATE                                
    ,PRODUCT_GROUP                      
    ,PRODUCT_TYPE                                
    ,PRODUCT_CODE            
    ,PRODUCT_ENTITY                                
    ,GL_CONSTNAME                                
    ,BRANCH_CODE                                
    ,BRANCH_CODE_OPEN                                
    ,CURRENCY                                
    ,EXCHANGE_RATE                                
    ,COALESCE(INITIAL_OUTSTANDING, 0) AS INITIAL_OUTSTANDING            
    ,COALESCE(OUTSTANDING, 0) AS OUTSTANDING            
    ,OUTSTANDING_IDC                                
    ,OUTSTANDING_JF                                
    ,OUTSTANDING_BANK                                
    ,OUTSTANDING_PASTDUE                                
    ,OUTSTANDING_WO                                
    ,PLAFOND                                
    ,PLAFOND_CASH                                
    ,COALESCE(MARGIN_ACCRUED, 0) AS MARGIN_ACCRUED            
    ,INSTALLMENT_AMOUNT                                
    ,COALESCE(UNUSED_AMOUNT, 0) AS UNUSED_AMOUNT            
    ,DOWN_PAYMENT_AMOUNT                                
    ,JF_FLAG                                
    ,LOAN_START_DATE                                
    ,LOAN_DUE_DATE                                
    ,LOAN_START_AMORTIZATION                                
    ,LOAN_END_AMORTIZATION                                
    ,INSTALLMENT_GRACE_PERIOD                                
    ,NEXT_PAYMENT_DATE                             
    ,NEXT_INT_PAYMENT_DATE                                
    ,LAST_PAYMENT_DATE                                
    ,FIRST_INSTALLMENT_DATE                                
    ,TENOR                                
    ,REMAINING_TENOR                                
    ,PAYMENT_CODE                                
    ,PAYMENT_TERM                                
    ,MARGIN_CALCULATION_CODE                                
    ,MARGIN_PAYMENT_TERM                           
    ,RESTRUCTURE_DATE                                
    ,RESTRUCTURE_FLAG            
    ,POCI_FLAG                                
    ,STAFF_LOAN_FLAG                                
    ,BELOW_MARKET_FLAG                                
    ,BTB_FLAG                                
    ,COMMITTED_FLAG                                
    ,REVOLVING_FLAG                                
    ,IAS_CLASS                                
    ,IFRS9_CLASS                                
    ,AMORT_TYPE                                
    ,EIR_STATUS                                
    ,ECF_STATUS                                
    ,EIR                                
    ,EIR_AMOUNT                                
    ,FAIR_VALUE_AMOUNT                                
    ,INITIAL_UNAMORT_TXN_COST                                
    ,INITIAL_UNAMORT_ORG_FEE                                
    ,UNAMORT_COST_AMT                                
    ,UNAMORT_FEE_AMT                                
    ,DAILY_AMORT_AMT                                
    ,UNAMORT_AMT_TOTAL_JF                                
    ,UNAMORT_FEE_AMT_JF                                
    ,UNAMORT_COST_AMT_JF                                
    ,ORIGINAL_COLLECTABILITY                                
    ,BI_COLLECTABILITY                        
    ,DAY_PAST_DUE                                
    ,DPD_START_DATE                                
    ,DPD_ZERO_COUNTER                                
    ,NPL_DATE                                
    ,NPL_FLAG                                
    ,DEFAULT_DATE                                
    ,DEFAULT_FLAG                                
    ,WRITEOFF_FLAG                                
    ,WRITEOFF_DATE                                
    ,IMPAIRED_FLAG                                
    ,IS_IMPAIRED                                
    ,GROUP_SEGMENT                                
    ,SEGMENT                                
    ,SUB_SEGMENT                                
    ,STAGE                                
    ,LIFETIME                                
    ,NULL AS EAD_RULE_ID                                
    ,NULL AS EAD_SEGMENT                                
    ,0 AS EAD_AMOUNT                                
    ,NULL AS LGD_RULE_ID                                
    ,NULL AS LGD_SEGMENT                                
    ,NULL AS PD_RULE_ID                                
    ,NULL AS PD_SEGMENT                        
    ,BUCKET_GROUP                                
    ,BUCKET_ID                                
    ,EIL_12_AMOUNT                                
    ,EIL_LIFETIME_AMOUNT                                
    ,EIL_AMOUNT                                
    ,CA_UNWINDING_AMOUNT             
    ,IA_UNWINDING_AMOUNT                                
    ,IA_UNWINDING_SUM_AMOUNT                                
    ,BEGINNING_BALANCE                                
    ,ENDING_BALANCE                  
    ,WRITEBACK_AMOUNT                                
    ,CHARGE_AMOUNT                                
    ,CREATEDBY                                
    ,CREATEDDATE                                
    ,CREATEDHOST                                
    ,UPDATEDBY                                
    ,UPDATEDDATE                                
    ,UPDATEDHOST                                
    ,INITIAL_BENEFIT                                
    ,UNAMORT_BENEFIT                                
    ,SPPI_RESULT                                
    ,BM_RESULT                                
    ,ECONOMIC_SECTOR                                
    ,AO_CODE                                
    ,SUFFIX                                
    ,ACCOUNT_TYPE                                
    ,CUSTOMER_TYPE                                
    ,OUTSTANDING_PROFIT_DUE                                
    ,RESTRUCTURE_COLLECT_FLAG                                
    ,DPD_FINAL                                
    ,EIR_SEGMENT                                
    ,DPD_CIF                                
    ,DPD_FINAL_CIF                                
    ,BI_COLLECT_CIF                                
    ,PRODUCT_TYPE_1                                
    ,RATING_CODE                               
    ,NULL AS CCF                                
    ,NULL AS CCF_RULE_ID                                
    ,NULL AS CCF_EFF_DATE                                
    ,EIL_AMOUNT_BFL                                
    ,AVG_EIR                                
    ,EIL_MODEL_ID                                
    ,SEGMENTATION_ID                                
    ,PD_ME_MODEL_ID                                
    ,DEFAULT_RULE_ID                                
    ,PLAFOND_CIF                  
    ,RESTRUCTURE_COLLECT_FLAG_CIF                  
    ,SOURCE_SYSTEM              
    ,INITIAL_RATING_CODE              
    ,PD_INITIAL_RATE              
    ,PD_CURRENT_RATE              
    ,PD_CHANGE              
    ,LIMIT_CURRENCY              
    ,SUN_ID              
    ,RATING_DOWNGRADE              
    ,WATCHLIST_FLAG           
    ,COALESCE(COLL_AMOUNT, 0) AS COLL_AMOUNT              
    ,FACILITY_NUMBER_PARENT            
    ,EXT_RATING_AGENCY            
    ,EXT_RATING_CODE            
    ,EXT_INIT_RATING_CODE            
    ,MARGIN_TYPE            
    ,SOVEREIGN_FLAG            
    ,ISIN_CODE            
    ,INV_TYPE            
    ,UNAMORT_DISCOUNT_PREMIUM            
    ,DISCOUNT_PREMIUM_AMOUNT            
    ,PRODUCT_CODE_T24            
    ,EXT_RATING_DOWNGRADE            
    ,SANDI_BANK        
    ,LOB_CODE        
    ,COUNTER_GUARANTEE_FLAG       
    ,EARLY_PAYMENT        
    ,EARLY_PAYMENT_FLAG        
    ,EARLY_PAYMENT_DATE        
    ,SEGMENT_FLAG     
    FROM ' || V_TABLENAME_MON || '                               
    WHERE DOWNLOAD_DATE = ''' || CAST(V_PREVMONTH AS VARCHAR(10)) || ''' ';
    EXECUTE (V_STR_QUERY);

    GET DIAGNOSTICS V_RETURNROWS = ROW_COUNT;
    V_RETURNROWS2 := V_RETURNROWS2 + V_RETURNROWS;
    V_RETURNROWS := 0;

    V_STR_QUERY := '';
    V_STR_QUERY := V_STR_QUERY || 'DELETE FROM ' || V_TABLENAME_MON || ' WHERE DOWNLOAD_DATE = ''' || CAST(V_CURRDATE AS VARCHAR(10)) || ''' ';
    EXECUTE (V_STR_QUERY);

    V_STR_QUERY := '';
    V_STR_QUERY := V_STR_QUERY || 'INSERT INTO ' || V_TABLENAME_MON || '                              
    (                              
    DOWNLOAD_DATE                                
    ,MASTERID                                
    ,MASTER_ACCOUNT_CODE                     
    ,DATA_SOURCE                                
    ,GLOBAL_CUSTOMER_NUMBER                                
    ,CUSTOMER_NUMBER                                
    ,CUSTOMER_NAME                                
    ,FACILITY_NUMBER                                
    ,ACCOUNT_NUMBER                                
    ,PREVIOUS_ACCOUNT_NUMBER                   
    ,ACCOUNT_STATUS                                
    ,MARGIN_RATE                                
    ,MARKET_RATE                                
    ,PRODUCT_GROUP                                
    ,PRODUCT_TYPE                                
    ,PRODUCT_CODE                                
    ,PRODUCT_ENTITY                                
    ,GL_CONSTNAME                                
    ,BRANCH_CODE                                
    ,BRANCH_CODE_OPEN                                
    ,CURRENCY                                
    ,EXCHANGE_RATE                                
    ,INITIAL_OUTSTANDING                                
    ,OUTSTANDING                                
    ,OUTSTANDING_IDC                                
    ,OUTSTANDING_JF                                
    ,OUTSTANDING_BANK                                
    ,OUTSTANDING_PASTDUE                                
    ,OUTSTANDING_WO                                
    ,PLAFOND                               
    ,PLAFOND_CASH                                
    ,MARGIN_ACCRUED                                
    ,INSTALLMENT_AMOUNT                                
    ,UNUSED_AMOUNT                                
    ,DOWN_PAYMENT_AMOUNT                                
    ,JF_FLAG                                
    ,LOAN_START_DATE                                
    ,LOAN_DUE_DATE                                
    ,LOAN_START_AMORTIZATION                                
    ,LOAN_END_AMORTIZATION                                
    ,INSTALLMENT_GRACE_PERIOD                                
    ,NEXT_PAYMENT_DATE                                
    ,NEXT_INT_PAYMENT_DATE                                
    ,LAST_PAYMENT_DATE                                
    ,FIRST_INSTALLMENT_DATE                                
    ,TENOR      
    ,REMAINING_TENOR                                
    ,PAYMENT_CODE                                
    ,PAYMENT_TERM                                
    ,MARGIN_CALCULATION_CODE                                
    ,MARGIN_PAYMENT_TERM                                
    ,RESTRUCTURE_DATE                                
    ,RESTRUCTURE_FLAG                                
    ,POCI_FLAG                                
    ,STAFF_LOAN_FLAG                                
    ,BELOW_MARKET_FLAG                                
    ,BTB_FLAG                                
    ,COMMITTED_FLAG                                
    ,REVOLVING_FLAG                                
    ,IAS_CLASS                                
    ,IFRS9_CLASS                                
    ,AMORT_TYPE                                
    ,EIR_STATUS                                
    ,ECF_STATUS                                
    ,EIR                                
    ,EIR_AMOUNT                                
    ,FAIR_VALUE_AMOUNT                                
    ,INITIAL_UNAMORT_TXN_COST                                
    ,INITIAL_UNAMORT_ORG_FEE                                
    ,UNAMORT_COST_AMT                                
    ,UNAMORT_FEE_AMT                                
    ,DAILY_AMORT_AMT                                
    ,UNAMORT_AMT_TOTAL_JF                                
    ,UNAMORT_FEE_AMT_JF                                
    ,UNAMORT_COST_AMT_JF                                
    ,ORIGINAL_COLLECTABILITY                                
    ,BI_COLLECTABILITY                                
    ,DAY_PAST_DUE                             
    ,DPD_START_DATE                        
    ,DPD_ZERO_COUNTER                                
    ,NPL_DATE                                
    ,NPL_FLAG                                
    ,DEFAULT_DATE                                
    ,DEFAULT_FLAG                                
    ,WRITEOFF_FLAG                                
    ,WRITEOFF_DATE                                
    ,IMPAIRED_FLAG                                
    ,IS_IMPAIRED                                
    ,GROUP_SEGMENT                                
    ,SEGMENT                                
    ,SUB_SEGMENT                                
    ,STAGE                                
    ,LIFETIME                                
    ,EAD_RULE_ID                                
    ,EAD_SEGMENT                                
    ,EAD_AMOUNT                                
    ,LGD_RULE_ID                                
    ,LGD_SEGMENT                                
    ,PD_RULE_ID                                
    ,PD_SEGMENT                                
    ,BUCKET_GROUP                                
    ,BUCKET_ID                                
    ,EIL_12_AMOUNT                                
    ,EIL_LIFETIME_AMOUNT                                
    ,EIL_AMOUNT                                
    ,CA_UNWINDING_AMOUNT                                
    ,IA_UNWINDING_AMOUNT                                
    ,IA_UNWINDING_SUM_AMOUNT                                
    ,BEGINNING_BALANCE                           
    ,ENDING_BALANCE                                
    ,WRITEBACK_AMOUNT                                
    ,CHARGE_AMOUNT                                
    ,CREATEDBY                                
    ,CREATEDDATE                                
    ,CREATEDHOST                                
    ,UPDATEDBY                                
    ,UPDATEDDATE                                
    ,UPDATEDHOST                                
    ,INITIAL_BENEFIT                                
    ,UNAMORT_BENEFIT                                
    ,SPPI_RESULT                                
    ,BM_RESULT                                
    ,ECONOMIC_SECTOR                                
    ,AO_CODE                                
    ,SUFFIX                                
    ,ACCOUNT_TYPE                                
    ,CUSTOMER_TYPE                                
    ,OUTSTANDING_PROFIT_DUE                                
    ,RESTRUCTURE_COLLECT_FLAG                                
    ,DPD_FINAL                                
    ,EIR_SEGMENT         
    ,DPD_CIF                                
    ,DPD_FINAL_CIF                                
    ,BI_COLLECT_CIF                                
    ,PRODUCT_TYPE_1                                
    ,RATING_CODE                                
    ,CCF                                
    ,CCF_RULE_ID                                
    ,CCF_EFF_DATE                                
    ,EIL_AMOUNT_BFL                                
    ,AVG_EIR                                
    ,EIL_MODEL_ID                                
    ,SEGMENTATION_ID                                
    ,PD_ME_MODEL_ID                                
    ,DEFAULT_RULE_ID                                
    ,PLAFOND_CIF                   
    ,RESTRUCTURE_COLLECT_FLAG_CIF                   
    ,SOURCE_SYSTEM              
    ,INITIAL_RATING_CODE              
    ,PD_INITIAL_RATE              
    ,PD_CURRENT_RATE              
    ,PD_CHANGE              
    ,LIMIT_CURRENCY              
    ,SUN_ID              
    ,RATING_DOWNGRADE              
    ,WATCHLIST_FLAG              
    ,COLL_AMOUNT              
    ,FACILITY_NUMBER_PARENT            
    ,EXT_RATING_AGENCY            
    ,EXT_RATING_CODE            
    ,EXT_INIT_RATING_CODE            
    ,MARGIN_TYPE            
    ,SOVEREIGN_FLAG            
    ,ISIN_CODE            
    ,INV_TYPE            
    ,UNAMORT_DISCOUNT_PREMIUM            
    ,DISCOUNT_PREMIUM_AMOUNT            
    ,PRODUCT_CODE_T24            
    ,EXT_RATING_DOWNGRADE            
    ,SANDI_BANK        
    ,LOB_CODE        
    ,COUNTER_GUARANTEE_FLAG        
    ,EARLY_PAYMENT        
    ,EARLY_PAYMENT_FLAG        
    ,EARLY_PAYMENT_DATE        
    ,SEGMENT_FLAG    
    )                                                    
    SELECT                                                 
    DOWNLOAD_DATE                                
    ,MASTERID                                
    ,MASTER_ACCOUNT_CODE                                
    ,DATA_SOURCE                                
    ,GLOBAL_CUSTOMER_NUMBER                                
    ,CUSTOMER_NUMBER                                
    ,CUSTOMER_NAME                                
    ,FACILITY_NUMBER                                
    ,ACCOUNT_NUMBER                                
    ,PREVIOUS_ACCOUNT_NUMBER                                
    ,ACCOUNT_STATUS                                
    ,MARGIN_RATE                                
    ,MARKET_RATE                                
    ,PRODUCT_GROUP                                
    ,PRODUCT_TYPE                                
    ,PRODUCT_CODE                                
    ,PRODUCT_ENTITY                                
    ,GL_CONSTNAME                                
    ,BRANCH_CODE                                
    ,BRANCH_CODE_OPEN                                
    ,CURRENCY                                
    ,EXCHANGE_RATE                                
    ,COALESCE(INITIAL_OUTSTANDING, 0) AS INITIAL_OUTSTANDING            
    ,COALESCE(OUTSTANDING, 0) AS OUTSTANDING            
    ,OUTSTANDING_IDC                                
    ,OUTSTANDING_JF                                
    ,OUTSTANDING_BANK                                
    ,OUTSTANDING_PASTDUE                                
    ,OUTSTANDING_WO                                
    ,PLAFOND                                
    ,PLAFOND_CASH                                
    ,COALESCE(MARGIN_ACCRUED, 0) AS MARGIN_ACCRUED            
    ,INSTALLMENT_AMOUNT                                
    ,COALESCE(UNUSED_AMOUNT, 0) AS UNUSED_AMOUNT            
    ,DOWN_PAYMENT_AMOUNT                                
    ,JF_FLAG                                
    ,LOAN_START_DATE                                
    ,LOAN_DUE_DATE                                
    ,LOAN_START_AMORTIZATION                                
    ,LOAN_END_AMORTIZATION                                
    ,INSTALLMENT_GRACE_PERIOD                                
    ,NEXT_PAYMENT_DATE                                
    ,NEXT_INT_PAYMENT_DATE                                
    ,LAST_PAYMENT_DATE                                
    ,FIRST_INSTALLMENT_DATE                                
    ,TENOR                                
    ,REMAINING_TENOR                 
    ,PAYMENT_CODE                                
    ,PAYMENT_TERM                             
    ,MARGIN_CALCULATION_CODE                                
    ,MARGIN_PAYMENT_TERM                                
    ,RESTRUCTURE_DATE                                
    ,RESTRUCTURE_FLAG                                
    ,POCI_FLAG                                
    ,STAFF_LOAN_FLAG                                
    ,BELOW_MARKET_FLAG                                
    ,BTB_FLAG                                
    ,COMMITTED_FLAG                                
    ,REVOLVING_FLAG                                
    ,IAS_CLASS                                
    ,IFRS9_CLASS                                
    ,AMORT_TYPE                                
    ,EIR_STATUS                                
    ,ECF_STATUS                                
    ,EIR                                
    ,EIR_AMOUNT                                
    ,FAIR_VALUE_AMOUNT                                
    ,INITIAL_UNAMORT_TXN_COST                                
    ,INITIAL_UNAMORT_ORG_FEE                                
    ,UNAMORT_COST_AMT                                
    ,UNAMORT_FEE_AMT                                
    ,DAILY_AMORT_AMT                                
    ,UNAMORT_AMT_TOTAL_JF                                
    ,UNAMORT_FEE_AMT_JF                                
    ,UNAMORT_COST_AMT_JF                                
    ,ORIGINAL_COLLECTABILITY                                
    ,BI_COLLECTABILITY                                
    ,DAY_PAST_DUE                                
    ,DPD_START_DATE                                
    ,DPD_ZERO_COUNTER                                
    ,NPL_DATE                                
    ,NPL_FLAG                                
    ,DEFAULT_DATE                                
    ,DEFAULT_FLAG                                
    ,WRITEOFF_FLAG                            
    ,WRITEOFF_DATE                                
    ,IMPAIRED_FLAG                                
    ,IS_IMPAIRED           
    ,GROUP_SEGMENT                                
    ,SEGMENT                                
    ,SUB_SEGMENT                                
    ,STAGE                                
    ,LIFETIME                                
    ,EAD_RULE_ID                                
    ,EAD_SEGMENT                                
    ,EAD_AMOUNT                                
    ,LGD_RULE_ID                                
    ,LGD_SEGMENT                                
    ,PD_RULE_ID                                
    ,PD_SEGMENT                         
    ,BUCKET_GROUP                                
    ,BUCKET_ID                                
    ,EIL_12_AMOUNT                                
    ,EIL_LIFETIME_AMOUNT                                
    ,EIL_AMOUNT                                
    ,CA_UNWINDING_AMOUNT                                
    ,IA_UNWINDING_AMOUNT                                
    ,IA_UNWINDING_SUM_AMOUNT                                
    ,BEGINNING_BALANCE                                
    ,ENDING_BALANCE                                
    ,WRITEBACK_AMOUNT                                
    ,CHARGE_AMOUNT                                
    ,CREATEDBY                                
    ,CREATEDDATE                                
    ,CREATEDHOST                                
    ,UPDATEDBY                                
    ,UPDATEDDATE                                
    ,UPDATEDHOST                                
    ,INITIAL_BENEFIT                                
    ,UNAMORT_BENEFIT                                
    ,SPPI_RESULT                                
    ,BM_RESULT                                
    ,ECONOMIC_SECTOR                                
    ,AO_CODE                                
    ,SUFFIX                                
    ,ACCOUNT_TYPE                                
    ,CUSTOMER_TYPE                                
    ,OUTSTANDING_PROFIT_DUE                                
    ,RESTRUCTURE_COLLECT_FLAG                                
    ,DPD_FINAL                                
    ,EIR_SEGMENT                                
    ,DPD_CIF                                
    ,DPD_FINAL_CIF                                
    ,BI_COLLECT_CIF                                
    ,PRODUCT_TYPE_1                                
    ,RATING_CODE                       
    ,CCF                                
    ,CCF_RULE_ID                                
    ,CCF_EFF_DATE                                
    ,EIL_AMOUNT_BFL                                
    ,AVG_EIR                                
    ,EIL_MODEL_ID                                
    ,SEGMENTATION_ID                                
    ,PD_ME_MODEL_ID                                
    ,DEFAULT_RULE_ID                                
    ,PLAFOND_CIF                         
    ,RESTRUCTURE_COLLECT_FLAG_CIF                    
    ,SOURCE_SYSTEM               
    ,INITIAL_RATING_CODE              
    ,PD_INITIAL_RATE              
    ,PD_CURRENT_RATE              
    ,PD_CHANGE              
    ,LIMIT_CURRENCY              
    ,SUN_ID              
    ,RATING_DOWNGRADE        
    ,WATCHLIST_FLAG            
    ,COALESCE(COLL_AMOUNT, 0) AS COLL_AMOUNT          
    ,FACILITY_NUMBER_PARENT            
    ,EXT_RATING_AGENCY            
    ,EXT_RATING_CODE            
    ,EXT_INIT_RATING_CODE            
    ,MARGIN_TYPE            
    ,SOVEREIGN_FLAG            
    ,ISIN_CODE            
    ,INV_TYPE            
    ,UNAMORT_DISCOUNT_PREMIUM            
    ,DISCOUNT_PREMIUM_AMOUNT            
    ,PRODUCT_CODE_T24            
    ,EXT_RATING_DOWNGRADE            
    ,SANDI_BANK        
    ,LOB_CODE        
    ,COUNTER_GUARANTEE_FLAG         
    ,EARLY_PAYMENT        
    ,EARLY_PAYMENT_FLAG        
    ,EARLY_PAYMENT_DATE        
    ,SEGMENT_FLAG 
    FROM    ' || V_TABLEINSERT1 || '                     
    WHERE   DOWNLOAD_DATE = ''' || CAST(V_CURRDATE AS VARCHAR(10)) || ''' ';
    EXECUTE (V_STR_QUERY);

    -- RAISE NOTICE '----> %', V_STR_QUERY;

    GET DIAGNOSTICS V_RETURNROWS = ROW_COUNT;
    V_RETURNROWS2 := V_RETURNROWS2 + V_RETURNROWS;
    V_RETURNROWS := 0;

    RAISE NOTICE 'SP_IFRS_IMP_FILL_IMA_PREV_CURR | AFFECTED RECORD : %', V_RETURNROWS2;
    -------- ====== BODY ======

    -------- ====== LOG ======
    V_TABLEDEST = V_TABLEINSERT1;
    V_COLUMNDEST = '-';
    V_SPNAME = 'SP_IFRS_IMP_FILL_IMA_PREV_CURR';
    V_OPERATION = 'INSERT';
    
    CALL SP_IFRS_EXEC_AND_LOG(V_CURRDATE, V_TABLEDEST, V_COLUMNDEST, V_SPNAME, V_OPERATION, V_RETURNROWS2, P_RUNID);

    -- V_TABLEDEST = V_TABLEINSERT2;
    -- V_COLUMNDEST = '-';
    -- V_SPNAME = 'SP_IFRS_IMP_FILL_IMA_PREV_CURR';
    -- V_OPERATION = 'INSERT';
    
    -- CALL SP_IFRS_EXEC_AND_LOG(V_CURRDATE, V_TABLEDEST, V_COLUMNDEST, V_SPNAME, V_OPERATION, V_RETURNROWS2, P_RUNID);
    -------- ====== LOG ======

    -------- ====== RESULT ======
    V_QUERYS = 'SELECT * FROM ' || V_TABLEINSERT1 || '';
    CALL SP_IFRS_RESULT_PREV(V_CURRDATE, V_QUERYS, V_SPNAME, V_RETURNROWS2, P_RUNID);
    -------- ====== RESULT ======

END;

$$;
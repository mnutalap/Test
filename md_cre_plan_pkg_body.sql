create or replace PACKAGE BODY md_cre_plan_pkg AS

  --------------------------------------------------------------------------------------
  --  NAME:  md_cre_plan_pkg_body.sql
  --  PURPOSE:  Create package in RMS_MDO user
  --            This package is going to be used to create markdown
  --            plan for SAS MDO application weekly
  --
  --  CREATED:  6/25/2009 Farah Shooshtarian, Stage Stores Inc.
  -- CR  87668  SAS Markdown Optimization Create MDO Plan
  --  REVISED:
  -- TPR 89156  Farah 09/10/2009
  -- PPR 89209 9/14/2009 Farah
  -- Calls to md_common_pkg.get_date function
  -- PPR 89312 9/24/2009 Farah
  -- PPR 89586  10/9/2009 Farah
  -- TPR 89619 10/13/2009 Farah
  -- PPR 89984 11/3/2009 Farah
  -- TPR 90605 12/8/2009 Farah
  -- PPR 91163 01/22/2010  Bryan Peebles
  --                       Do not insert GEO_PRODs during week of creation.
  -- PPR 91065 and PPR 91126 Purnima Kunwor
  --     Plan Creation over Calendar Year and table name changes to meet standards.
  -- PPR 91484 02/11/2010 Purnima Kunwor
  --    Remove plan if all of the members have been removed.
  -- CR 91722 05/05/2010 Bryan Peebles
  --   Exclude items from plan generation if flagged with a UDA set to exclude.
  -- PPR 93178 06/07/2010 Bryan Peebles
  --   Add NVL to UDA exclude check.
  -- CR 87831 06/08/2010 Purnima Kunwor
  --  Added functions to check for missing plan parameters and plan overrides.
  --  Use rank to determine the best matching plan parameters and plan override records
  --  Make plan duration as specified in RM_MDO_PLAN_PARAMETERS.
  -- TPR 93749 07/19/2010 Bryan Peebles
  --   Stop sending Full Price plan deletes if the Plan has completed.
  -- PPR 94083 Update ARI alerts to not sent the duplicates and send ARI only when there
  -- are exceptions
  -- CR 92175  08/13/2010 Bryan Peebles
  --      Do not add items already at Kill Price to plans.
  -- TPR 94345 08/24/2010 Bryan Peebles
  --      Change ARI Alert Group from 9 to 24.
  --
  -- Revised:  Manoj Kumar. CR 94875. 10/21/2010.
  --    Modified the Function BUILD_PLAN_GEO_PROD
  --    Changes made to the query that creates the table MD_STYLE_COLOR_KILL_PRICE
  --
  -- Revised:  Manoj Kumar. CR 94577. 11/19/2010.
  --    Modifed the function SET_DATE. use GET_REF_DATE.
  --    Modified the Function OVERRIDE_PLAN. Added the below.
  --    1.  Added column FORCE_MARKDN_WEEK to ' CREATE TABLE '||O_TAB_NAME ||
  --    2.  Update O_TAB_NAME
  --            set ALLOWED_MARKDN_PERIODS = MD_GET_FORCE_MARKDOWN_STRING(group_no, start_dt, end_dt, force_markdn_week);
  --    3.  Modified Function INSERT_MDO_PLAN
  --    Populate new column FORCE_MARKDN_WEEK in table MD_IMPORT_PLAN
  --    4.  Added new Function REFRESH_PLAN_EXECUTION_STRING(called by job md_refresh_plan_execution_string)
  --    refreshes the column MD_IMPORT_PLAN.ALLOWED_MARKDN_PERIODS
  --
  -- Revised:  Purnima Kunwor PPR 96787 2/3/2011
  -- Modified to not send delete multiple times when item goes back to full price
  --
  -- CR97219 DPARK 10-MAY-2011
  --   modified the creation of plan to exclude styles with items having recent price
  --   changes or existing in the new style exclusion table
  --
  -- Revised:  Purnima Kunwor TPR 98943 6/21/2011
  -- Should not look at price changes if value is set to 0
  -- Revised:  Purnima Kunwor PPR 99025 6/27/2011
  -- Fix issue with MDO exclusion
  -- Revised:  Purnima Kunwor PPR 98793 7/1/2011
  -- Modified creation of MD_STYLE_COLOR_KILL_PRICE to fix issue with kill price not working
  -- Revised     : Basavanna Olekar, CR 98359   06/08/2011
  -- Modified as below in SET_DATE function so to call Md_Common_Pkg.GET_REF_DATE_PLAN instead of Md_Common_Pkg.GET_REF_DATE
  --
  -- Modified:  Manoj Kumar. CR 100954. 12/15/2011.
  -- Modified:  Purnima Kunwor CR 102994 03/08/2012
  -- Revised: Rahul Madadi PPR 103923 05/03/2012
  --   Modified the Function CHECK_MISSING_PLAN_PARAM.Previously all records are written into a single line.
  --   Now each record is written as a line into the file.
  -- Revised: Rahul Madadi PPR 104647 08/02/2012
  -- Modified the function CHECK_MISSING_PLAN_OVERRIDE.while sending alert sending only the first 1000 characters
  -- Revised: Purnima Kunwor PPR 107205 12/11/2012
  -- Modified the function CREATE_PLAN_PARAMS_TAB to remove min_sellling_week and plan_duration from grouping for 
  -- creation of MD_PLAN_PARAMETERS table
  -- Modified:  Purnima Kunwor CR 107643 03/12/2013
  -- Modified by: Purnima Kunwor  Sep 23, 2013
  -- Purpose: CR 109443 - MDO changes for store level pricing
  -- Modified by: Purnima Kunwor  Oct 7, 2013
  -- Purpose: CR 111417 - Send MDO plan deletions wkly on Mon nights
  -- Modified by: Purnima Kunwor  Dec 20, 2013
  -- Purpose: PPR 112720 - Fix performance issue with md_plan_geo_prod
  -- Modified by: Purnima Kunwor  May 22, 2014
  -- Purpose: PPR 114539 - Changes to MDO plan member deletes
  -- Modified By: Ravindranath Seetharamagowdu  
  -- CR-118541 - Remove Clearance stores from MDO system.-- 
  -- Purpose: To stop clearance stores integrates in MDO system for NEW MDO plans and also mark deleted status 
  -- for already integrated store records in MDO system.
  -- Modified by: Purnima Kunwor  Sep 3, 2015
  -- Purpose: PPR 121168 - Move the logic for clearance store during determining eligible geo prod
  --Modified by veera adepu CR 124654 changes to MDO plan creation for MDO upgrade
  --Modified by Purnima Kunwor 12/30/2016 PPR 126807
  --Modified by Veera Adepu CR 129315 Setting chain level parameters 09/27/217 
  --Modified by Purnima Kunwor 3/29/2018 PPR 131628
  --Modified by Rakesh Suravarapu 06/09/2018 CR 132023
  --Modified by Mani Nutalapati 10/05/2018 CR-132020 Modified to applY DC inventory filter and exclude last receipt dates
  --                                       for new stores
  --Added comment
  ---------------------------------------------------------------------------------------------------------------------

  active            CONSTANT VARCHAR2(30) := 'ACTIVE';
  clearance         CONSTANT VARCHAR2(30) := 'CLEARANCE';
  repl_ind          CONSTANT VARCHAR2(1) := 'N';
  v_send            CONSTANT VARCHAR2(1) := 'S';
  v_new             CONSTANT VARCHAR2(1) := 'N';
  v_complete        CONSTANT VARCHAR2(1) := 'C';
  v_mdo_grp         CONSTANT VARCHAR2(10) := 'MDO_GRP';
  active_no         CONSTANT NUMBER := 1;
  clearance_no      CONSTANT NUMBER := 2;
  v_remove          CONSTANT NUMBER := 4; -- Remove Action for plan member is represented by 4
  v_plan_remove     CONSTANT NUMBER := 4; -- Remove Action for plan is represented by 4
  v_add             CONSTANT NUMBER := 1;
  v_update          CONSTANT NUMBER := 6;
  v_merch           CONSTANT VARCHAR2(5) := '19';
  v_season          CONSTANT VARCHAR2(5) := '10';
  purge_day         CONSTANT NUMBER := 30;
  v_max_plan_length CONSTANT NUMBER := 25; -- Actual max plan length is 26, 25 used as a week may be added during end date calculation

  g_date              DATE;
  g_year              NUMBER;
  g_date_chr          VARCHAR2(30);
  g_date_yy_mm        VARCHAR2(30);
  g_tablespace        VARCHAR2(30);
  g_num_days          NUMBER := 7;
  g_week_no           VARCHAR2(1);
  g_max_style         NUMBER := 300;
  g_end_range         NUMBER := 3000000;
  g_st_range          NUMBER := 1;
  g_bucket            NUMBER := 3000000 / 300;
  g_prod_num          NUMBER := 1000;
  g_geo_prod_num      NUMBER := 140000;
  g_sell_through_type NUMBER;
  v_gordmans_chain	  NUMBER := 6;
  v_dc_oh_threshold   NUMBER;

  -- ----------------------------------------------------------------
  FUNCTION set_date(o_error_message IN OUT VARCHAR2) RETURN BOOLEAN;
  -- ----------------------------------------------------------------
  FUNCTION get_tablespace(o_error_message IN OUT VARCHAR2) RETURN BOOLEAN;
  -- ----------------------------------------------------------------
  FUNCTION create_index(o_error_message IN OUT VARCHAR2,
                        i_user          IN VARCHAR2,
                        i_tab_name      IN VARCHAR2,
                        i_index         IN VARCHAR2,
                        i_columns       IN VARCHAR2,
                        i_flg           IN VARCHAR2) RETURN BOOLEAN;
  -- ---------------------------------------------------------------
  FUNCTION drop_table(o_error_message IN OUT VARCHAR2,
                      i_prefix        IN VARCHAR2) RETURN BOOLEAN;
  -- --------------------------------------------------------------
  FUNCTION extract_plan(o_error_message IN OUT VARCHAR2,
                        i_output_path   IN VARCHAR2,
                        i_tab_name      IN VARCHAR2) RETURN BOOLEAN;
  -- ---------------------------------------------------------------
  FUNCTION build_plan_geo_prod(o_error_message IN OUT VARCHAR2)
    RETURN BOOLEAN;
  -- ---------------------------------------------------------------
  FUNCTION find_mdo_plan_uda(o_error_message IN OUT VARCHAR2) RETURN BOOLEAN;
  -- ----------------------------------------------------------------
  FUNCTION find_mdo_candidate(o_error_message IN OUT VARCHAR2,
                              i_merch_type    IN VARCHAR2,
                              i_season        IN VARCHAR2) RETURN BOOLEAN;
  -- ---------------------------------------------------------------
  FUNCTION insert_mdo_plan(o_error_message IN OUT VARCHAR2,
                           i_tab_name      IN VARCHAR2) RETURN BOOLEAN;
  -- ----------------------------------------------------------------
  FUNCTION insert_mdo_plan_mem(o_error_message IN OUT VARCHAR2,
                               i_tab_name      IN VARCHAR2) RETURN BOOLEAN;
  -- ------------------------------------------------------------------
  -- --------------------------------------------------------------------
  FUNCTION update_plan_status_compl(o_error_message IN OUT VARCHAR2)
    RETURN BOOLEAN;
  -- --------------------------------------------------------------------
  FUNCTION purge_mdo_plan(o_error_message IN OUT VARCHAR2) RETURN BOOLEAN;
  -- -------------------------------------------------------------------
  FUNCTION override_plan(o_error_message IN OUT VARCHAR2,
                         i_tab_name      IN VARCHAR2,
                         o_tab_name      IN VARCHAR2) RETURN BOOLEAN;
  -- -------------------------------------------------------------------
  FUNCTION brk_mdo_plan(o_error_message IN OUT VARCHAR2,
                        i_tab_name      IN VARCHAR2,
                        o_tab_name      IN VARCHAR2) RETURN BOOLEAN;
  -- -------------------------------------------------------------------
  FUNCTION count_mdo_plan(o_error_message IN OUT VARCHAR2,
                          i_tab_name      IN VARCHAR2) RETURN BOOLEAN;
  -- --------------------------------------------------------------------
  FUNCTION create_plan_params_tab(o_error_message IN OUT VARCHAR2)
    RETURN BOOLEAN;
  -- --------------------------------------------------------------------
  FUNCTION create_plan_candidate_tab(o_error_message IN OUT VARCHAR2)
    RETURN BOOLEAN;
  -- --------------------------------------------------------------------
  FUNCTION send_alert(p_ari_subject   IN VARCHAR2,
                      p_ari_message   IN VARCHAR2,
                      p_alert_code    NUMBER,
                      o_error_message IN OUT VARCHAR2) RETURN BOOLEAN;
  -- --------------------------------------------------------------------

  -- =====================================================================
  --**** Public
  FUNCTION process_plan_geo_prod(o_error_message IN OUT VARCHAR2)
    RETURN BOOLEAN IS
  
    l_module VARCHAR2(64) := 'MD_CRE_PLAN_PKG.PROCESS_PLAN_GEO_PROD';
  
  BEGIN
  
    IF get_tablespace(o_error_message) = FALSE THEN
      RAISE program_error;
    END IF;
  
    IF set_date(o_error_message) = FALSE THEN
      RAISE program_error;
    END IF;
  
    IF build_plan_geo_prod(o_error_message) = FALSE THEN
      RAISE program_error;
    END IF;
  
    -- --------------------------------------------
    -- Insert new records to existing plan member
    -- --------------------------------------------
    IF insert_mdo_plan_mem(o_error_message, 'MD_PLN_INSERT_GEO_PROD_MEM') =
       FALSE THEN
      RAISE program_error;
    END IF;
  
    RETURN TRUE;
  
  EXCEPTION
    WHEN OTHERS THEN
      IF o_error_message IS NULL THEN
        o_error_message := substr(l_module || ' ' || SQLCODE || ' ' ||
                                  SQLERRM,
                                  1,
                                  2000);
      END IF;
    
      RETURN FALSE;
    
  END process_plan_geo_prod;
  -- ==========================================================

  --**** Public
  FUNCTION process_plan_uda(o_error_message IN OUT VARCHAR2) RETURN BOOLEAN IS
  
    l_module VARCHAR2(64) := 'MD_CRE_PLAN_PKG.PROCESS_PLAN_UDA';
  
  BEGIN
  
    IF get_tablespace(o_error_message) = FALSE THEN
      RAISE program_error;
    END IF;
  
    IF set_date(o_error_message) = FALSE THEN
      RAISE program_error;
    END IF;
  
    -- --------------------------------------------
    -- Create parameter table MD_PLAN_PARAMETERS
    -- -------------------------------------------
    IF create_plan_params_tab(o_error_message) = FALSE THEN
      RAISE program_error;
    END IF;
  
    IF find_mdo_plan_uda(o_error_message) = FALSE THEN
      -- table MD_PLN_UDA_VL is created here. it has item, style, colour, merch type(FAB, SEA, PSEA), season code, mdo uda
      RAISE program_error;
    END IF;
  
    -- ---------------------------------------------
    -- Create plan candidate table MD_PLAN_CANDIDATE
    -- ---------------------------------------------
    IF create_plan_candidate_tab(o_error_message) = FALSE THEN
      RAISE program_error;
    END IF;
  
    RETURN TRUE;
  
  EXCEPTION
    WHEN OTHERS THEN
      IF o_error_message IS NULL THEN
        o_error_message := substr(l_module || ' ' || SQLCODE || ' ' ||
                                  SQLERRM,
                                  1,
                                  2000);
      END IF;
      RETURN FALSE;
  END process_plan_uda;
  -- ===========================================================

  --**** Public
  FUNCTION process_plan_candidate(o_error_message IN OUT VARCHAR2,
                                  i_merch_type    IN VARCHAR2,
                                  i_season        IN VARCHAR2) RETURN BOOLEAN IS
  
    l_module       VARCHAR2(64) := 'MD_CRE_PLAN_PKG.PROCESS_PLAN_CANDIDATE';
    i_tab_name     VARCHAR2(30) := 'MD_' || i_merch_type || '_' || i_season ||
                                   '_ALL';
    o_tab_name_ovr VARCHAR2(30) := 'MD_' || i_merch_type || '_' || i_season ||
                                   '_OVR';
    o_tab_name_brk VARCHAR2(30) := 'MD_' || i_merch_type || '_' || i_season ||
                                   '_BRK';
    o_tab_name_mem VARCHAR2(30) := 'MD_' || i_merch_type || '_' || i_season ||
                                   '_BRKMEM';
  
  BEGIN
  
    IF drop_table(o_error_message,
                  'MD_' || i_merch_type || '_' || i_season || '%') = FALSE THEN
      RAISE program_error;
    END IF;
  
    IF get_tablespace(o_error_message) = FALSE THEN
      RAISE program_error;
    END IF;
  
    IF set_date(o_error_message) = FALSE THEN
      RAISE program_error;
    END IF;
  
    -- ---------------------------------------------------
    -- Set override SELL_THROUGH_TYPE base on merch type
    -- PPR 89586  Farah
    -- ---------------------------------------------------
    IF i_merch_type IN (v_sea, v_psea) THEN
      g_sell_through_type := 1;
    ELSE
      g_sell_through_type := 0;
    END IF;
  
    IF find_mdo_candidate(o_error_message, i_merch_type, i_season) = FALSE THEN
      RAISE program_error;
    END IF;
  
    IF brk_mdo_plan(o_error_message, i_tab_name, o_tab_name_brk) = FALSE THEN
      RAISE program_error;
    END IF;
  
    IF override_plan(o_error_message, o_tab_name_brk, o_tab_name_ovr) =
       FALSE THEN
      RAISE program_error;
    END IF;
  
    IF insert_mdo_plan(o_error_message, o_tab_name_ovr) = FALSE THEN
      RAISE program_error;
    END IF;
  
    IF insert_mdo_plan_mem(o_error_message, o_tab_name_mem) = FALSE THEN
      RAISE program_error;
    END IF;
  
    IF drop_table(o_error_message,
                  'MD_PRM_' || i_merch_type || '_' || i_season) = FALSE THEN
      RAISE program_error;
    END IF;
  
    IF drop_table(o_error_message,
                  'MD_PRM0_' || i_merch_type || '_' || i_season) = FALSE THEN
      RAISE program_error;
    END IF;
  
    EXECUTE IMMEDIATE 'rename ' || 'MD_' || i_merch_type || '_' || i_season ||
                      '_PRM to MD_PRM_' || i_merch_type || '_' || i_season;
    EXECUTE IMMEDIATE 'rename ' || 'MD_' || i_merch_type || '_' || i_season ||
                      '_PRM0 to MD_PRM0_' || i_merch_type || '_' ||
                      i_season;
  
    IF drop_table(o_error_message,
                  'MD_' || i_merch_type || '_' || i_season || '%') = FALSE THEN
      RAISE program_error;
    END IF;
  
    EXECUTE IMMEDIATE 'rename MD_PRM_' || i_merch_type || '_' || i_season ||
                      ' to ' || 'MD_' || i_merch_type || '_' || i_season ||
                      '_PRM';
    EXECUTE IMMEDIATE 'rename MD_PRM0_' || i_merch_type || '_' || i_season ||
                      ' to ' || 'MD_' || i_merch_type || '_' || i_season ||
                      '_PRM0';
  
    RETURN TRUE;
  
  EXCEPTION
    WHEN OTHERS THEN
      IF o_error_message IS NULL THEN
        o_error_message := substr(l_module || ' ' || SQLCODE || ' ' ||
                                  SQLERRM,
                                  1,
                                  2000);
      END IF;
    
      RETURN FALSE;
    
  END process_plan_candidate;
  -- ===========================================================

  --**** public
  FUNCTION process_plan_extract(o_error_message IN OUT VARCHAR2,
                                i_output_path   IN VARCHAR2,
                                i_tab_name      IN VARCHAR2) RETURN BOOLEAN IS
  
    l_module   VARCHAR2(64) := 'MD_CRE_PLAN_PKG.PROCESS_PLAN_EXTRACT';
    v_tab_name VARCHAR2(100);
  
  BEGIN
  
    IF i_tab_name = 'MD_IMPORT_PLAN_52' THEN
      v_tab_name := substr(i_tab_name, 1, length(i_tab_name) - 3);
    ELSE
      v_tab_name := i_tab_name;
    END IF;
  
    IF get_tablespace(o_error_message) = FALSE THEN
      RAISE program_error;
    END IF;
  
    IF set_date(o_error_message) = FALSE THEN
      RAISE program_error;
    END IF;
  
    IF count_mdo_plan(o_error_message, i_tab_name) = FALSE THEN
      RAISE program_error;
    END IF;
  
    IF extract_plan(o_error_message, i_output_path, i_tab_name) = FALSE THEN
      RAISE program_error;
    END IF;
  
   /* 
   CR 124654 MDo upgrade5.2
   
   IF update_mdo_plan_status(o_error_message, v_tab_name) = FALSE THEN
      RAISE program_error;
    END IF;*/
  
    -- drop
    IF drop_table(o_error_message, 'MD_PLN_PURGE_PLAN_PRG') = FALSE THEN
      RAISE program_error;
    END IF;
  
    RETURN TRUE;
  EXCEPTION
    WHEN OTHERS THEN
      IF o_error_message IS NULL THEN
        o_error_message := substr(l_module || ' ' || SQLCODE || ' ' ||
                                  SQLERRM,
                                  1,
                                  2000);
      END IF;
      RETURN FALSE;
  END process_plan_extract;
  -- ============================================================

  --**** Public
  FUNCTION move_sea_plans_to_fab_plans(o_error_message IN OUT VARCHAR2)
    RETURN BOOLEAN IS
  
    l_module VARCHAR2(64) := 'MD_CRE_PLAN_PKG.MOVE_SEA_PLANS_TO_FAB_PLANS';
  
  BEGIN
  
    EXECUTE IMMEDIATE 'analyze table md_import_plan_member estimate statistics sample 10 percent';
  
    IF drop_table(o_error_message, 'MD_IMPORT_PLAN_MEMBER_TMP') = FALSE THEN
      RAISE program_error;
    END IF;
  
    IF get_tablespace(o_error_message) = FALSE THEN
      RAISE program_error;
    END IF;
  
    /******************************************************************************
    -- capture current plan members whose products are identified to be moved to FAB
    *****************************************************************************/
    EXECUTE IMMEDIATE ' create table md_import_plan_member_tmp ' || chr(10) ||
                      ' tablespace ' || g_tablespace || '  NOLOGGING as ' ||
                      chr(10) || ' select md.* ' || chr(10) ||
                      '  from md_import_plan_member md ' || chr(10) ||
                      '      ,md_import_plan_mem_move_to_fab mv ' ||
                      chr(10) || ' where mv.style = md.style ' || chr(10) ||
                      '   and mv.colour = md.colour';
  
    IF create_index(o_error_message,
                    USER,
                    'MD_IMPORT_PLAN_MEMBER_TMP',
                    'MD_IMPORT_PLAN_MEMBER_TMP_i1',
                    'geo_id, prod_id',
                    'Y') = FALSE THEN
      RAISE program_error;
    END IF;
  
    /******************************************************************************
    -- create new plan records with FAB in the plan name for plans identified above
    *****************************************************************************/
    EXECUTE IMMEDIATE ' insert into md_import_plan(MDO_PLAN_NM     ' ||
                      chr(10) || '      ,MDO_PLAN_DESC       ' || chr(10) ||
                      '      ,MERCH_TYPE          ' || chr(10) ||
                      '      ,SEASON_CODE         ' || chr(10) ||
                      '      ,DEPT                ' || chr(10) ||
                      '      ,CLASS               ' || chr(10) ||
                      '      ,GROUP_NO            ' || chr(10) ||
                      '      ,MDO_UDA             ' || chr(10) ||
                      '      ,MDO_VALUE           ' || chr(10) ||
                      '      ,AUTO_EVAL_OPT_FLG     ' || chr(10) ||
                      '      ,START_DT              ' || chr(10) ||
                      '      ,END_DT                ' || chr(10) ||
                      '      ,OBJECTIVE_CD          ' || chr(10) ||
                      '      ,DECISION_GEO_LVL      ' || chr(10) ||
                      '      ,DECISION_PROD_LVL     ' || chr(10) ||
                      '      ,TARGET_INV_VALUE_TYPE     ' || chr(10) ||
                      '      ,TARGET_INV_VALUE          ' || chr(10) ||
                      '      ,INV_POOL_LVL_CD           ' || chr(10) ||
                      '      ,SALVAGE_VALUE_TYPE        ' || chr(10) ||
                      '      ,SALVAGE_VALUE             ' || chr(10) ||
                      '      ,MAX_MARKDN_NUM            ' || chr(10) ||
                      '      ,MIN_PERIODS_BETWEEN_MARKDN   ' || chr(10) ||
                      '      ,MAX_DISC_PCT_OFF_REG_PRICE   ' || chr(10) ||
                      '      ,MIN_DISC_PCT_FOR_INIT_MARKDN   ' || chr(10) ||
                      '      ,MIN_DISC_PCT_FOR_NEXT_MARKDN   ' || chr(10) ||
                      '      ,MAX_DISC_PCT_FOR_SINGLE_MARKDN ' || chr(10) ||
                      '      ,MARKDN_COST_AMT                ' || chr(10) ||
                      '      ,MARKDN_UNIT_COST_AMT           ' || chr(10) ||
                      '      ,ALLOWED_MARKDN_PERIODS         ' || chr(10) ||
                      '      ,PRICE_VALUE_TYPE               ' || chr(10) ||
                      '      ,PRICE_VALUE_LIST               ' || chr(10) ||
                      '      ,PRICE_ENDING_LIST              ' || chr(10) ||
                      '      ,FINAL_DISC_VALUE_TYPE          ' || chr(10) ||
                      '      ,FINAL_DISC_VALUE               ' || chr(10) ||
                      '      ,SELL_THROUGH_TYPE              ' || chr(10) ||
                      '      ,PLAN_STATUS_CD                 ' || chr(10) ||
                      '      ,ACTIVE_PLAN_NM                 ' || chr(10) ||
                      '      ,ACTION_CD                      ' || chr(10) ||
                      '      ,STATUS                         ' || chr(10) ||
                      '      ,SOURCE                         ' || chr(10) ||
                      '      ,UPDATE_DT                      ' || chr(10) ||
                      '      ,FORCE_MARKDN_WEEK				 ' || chr(10) ||
					  '      ,GEO_HIER_ASSOC_CD				 ' || chr(10) ||
					  '      ,PROD_HIER_ASSOC_CD			 ' || chr(10) ||
					  '      ,INV_POOL_PROD_LVL			 	 ' || chr(10) ||
					  '      ,MAX_FUTURE_MARKDN_NUM		 	 ' || chr(10) ||
					  '      ,MAX_DISC_PCT_FOR_INIT_MARKDN	 ' || chr(10) ||
					  '      ,FORCE_MARKDN_MIN_DEPTH_VALUE	 ' || chr(10) ||
					  '      ,LOW_BASELINE_DEMAND_DISC_VALUE ' || chr(10) ||
					  '      ,SCHEDULING_TAG 				 ' || chr(10) ||
					  '      ,UNIFORM_TIMING_NUM_MARKDN		 ' || chr(10) ||
					  '      ,UNIFORM_TIMING_PROD_LVL		 ' || chr(10) ||
					  '      ,UNIFORM_TIMING_GEO_LVL		 ' || chr(10) ||
					  '      ,ALLOW_MARKDN_DURING_PROMO_CD	 ' || chr(10) ||
					  '      ,MULTI_OBJ_INV_WEIGHT	 		 ' || chr(10) ||
					  '      ,ALLOW_MARKDN_BELOW_COST_CD	 ' || chr(10) ||
					  '      ,ALLOW_MARKDN_BELOW_COST_PRDS)	 ' || chr(10) ||
                      ' select replace(MDO_PLAN_NM, ''SEA'', ''FAB'') MDO_PLAN_NM ' ||
                      chr(10) || '  ,MDO_PLAN_DESC       ' || chr(10) ||
                      '  ,''FAB'' MERCH_TYPE     ' || chr(10) ||
                      '  ,SEASON_CODE       ' || chr(10) ||
                      '  ,DEPT         ' || chr(10) || '  ,CLASS         ' ||
                      chr(10) || '  ,GROUP_NO       ' || chr(10) ||
                      '  ,MDO_UDA       ' || chr(10) ||
                      '  ,MDO_VALUE       ' || chr(10) ||
                      '  ,AUTO_EVAL_OPT_FLG     ' || chr(10) ||
                      '  ,START_DT       ' || chr(10) || '  ,END_DT       ' ||
                      chr(10) || '  ,OBJECTIVE_CD       ' || chr(10) ||
                      '  ,DECISION_GEO_LVL     ' || chr(10) ||
                      '  ,DECISION_PROD_LVL     ' || chr(10) ||
                      '  ,TARGET_INV_VALUE_TYPE     ' || chr(10) ||
                      '  ,TARGET_INV_VALUE     ' || chr(10) ||
                      '  ,INV_POOL_LVL_CD     ' || chr(10) ||
                      '  ,SALVAGE_VALUE_TYPE     ' || chr(10) ||
                      '  ,SALVAGE_VALUE       ' || chr(10) ||
                      '  ,MAX_MARKDN_NUM     ' || chr(10) ||
                      '  ,MIN_PERIODS_BETWEEN_MARKDN   ' || chr(10) ||
                      '  ,MAX_DISC_PCT_OFF_REG_PRICE   ' || chr(10) ||
                      '  ,MIN_DISC_PCT_FOR_INIT_MARKDN   ' || chr(10) ||
                      '  ,MIN_DISC_PCT_FOR_NEXT_MARKDN   ' || chr(10) ||
                      '  ,MAX_DISC_PCT_FOR_SINGLE_MARKDN ' || chr(10) ||
                      '  ,MARKDN_COST_AMT     ' || chr(10) ||
                      '  ,MARKDN_UNIT_COST_AMT     ' || chr(10) ||
                      '  ,ALLOWED_MARKDN_PERIODS   ' || chr(10) ||
                      '  ,PRICE_VALUE_TYPE     ' || chr(10) ||
                      '  ,PRICE_VALUE_LIST     ' || chr(10) ||
                      '  ,PRICE_ENDING_LIST     ' || chr(10) ||
                      '  ,FINAL_DISC_VALUE_TYPE     ' || chr(10) ||
                      '  ,FINAL_DISC_VALUE     ' || chr(10) ||
                      '  ,SELL_THROUGH_TYPE     ' || chr(10) ||
                      '  ,PLAN_STATUS_CD     ' || chr(10) ||
                      '  ,ACTIVE_PLAN_NM     ' || chr(10) ||
                      '  ,ACTION_CD       ' || chr(10) ||
                      '  ,STATUS       ' || chr(10) ||
                      '  ,SOURCE||''_FAB'' SOURCE  ' || chr(10) ||
                      '  ,UPDATE_DT       ' || chr(10) ||
                      '  ,FORCE_MARKDN_WEEK     ' || chr(10) ||
					  '  ,GEO_HIER_ASSOC_CD				 ' || chr(10) ||
					  '  ,PROD_HIER_ASSOC_CD			 ' || chr(10) ||
					  '  ,INV_POOL_PROD_LVL			 	 ' || chr(10) ||
					  '  ,MAX_FUTURE_MARKDN_NUM		 	 ' || chr(10) ||
					  '  ,MAX_DISC_PCT_FOR_INIT_MARKDN	 ' || chr(10) ||
					  '  ,FORCE_MARKDN_MIN_DEPTH_VALUE	 ' || chr(10) ||
					  '  ,LOW_BASELINE_DEMAND_DISC_VALUE ' || chr(10) ||
					  '  ,SCHEDULING_TAG 				 ' || chr(10) ||
					  '  ,UNIFORM_TIMING_NUM_MARKDN		 ' || chr(10) ||
					  '  ,UNIFORM_TIMING_PROD_LVL		 ' || chr(10) ||
					  '  ,UNIFORM_TIMING_GEO_LVL		 ' || chr(10) ||
					  '  ,ALLOW_MARKDN_DURING_PROMO_CD	 ' || chr(10) ||
					  '  ,MULTI_OBJ_INV_WEIGHT	 		 ' || chr(10) ||
					  '  ,ALLOW_MARKDN_BELOW_COST_CD	 ' || chr(10) ||
					  '  ,ALLOW_MARKDN_BELOW_COST_PRDS	 ' || chr(10) ||
                      '   from md_import_plan     ' || chr(10) ||
                      '  where mdo_plan_nm in(select distinct tmp.mdo_plan_nm ' ||
                      chr(10) ||
                      '          from md_import_plan_member_tmp tmp) ';
  
    /******************************************************************************
    -- update current plan members. replace plan name with FAB plan name.
    *****************************************************************************/
    EXECUTE IMMEDIATE 'update md_import_plan_member md         ' || chr(10) ||
                      '   set mdo_plan_nm = replace(mdo_plan_nm, ''SEA'', ''FAB'')   ' ||
                      chr(10) || ' where exists(select 1            ' ||
                      chr(10) ||
                      '                from md_import_plan_member_tmp tmp     ' ||
                      chr(10) ||
                      '               where md.geo_id = tmp.geo_id       ' ||
                      chr(10) ||
                      '                 and md.prod_id = tmp.prod_id)     ';
  
    /******************************************************************************
    -- delete plan if all members under it were moved to the new FAB name plan
    *****************************************************************************/
    EXECUTE IMMEDIATE ' delete from md_import_plan plan         ' ||
                      chr(10) ||
                      '  where mdo_plan_nm in(select distinct tmp.mdo_plan_nm   ' ||
                      chr(10) ||
                      '          from md_import_plan_member_tmp tmp)   ' ||
                      chr(10) || '    and not exists(select 1           ' ||
                      chr(10) ||
                      '          from md_import_plan_member mem     ' ||
                      chr(10) ||
                      '         where mem.mdo_plan_nm = plan.mdo_plan_nm)  ';
  
    COMMIT; -- after above insert, update, delete
  
    /******************************************************************************
    -- drop tmp table
    *****************************************************************************/
    IF drop_table(o_error_message, 'MD_IMPORT_PLAN_MEMBER_TMP') = FALSE THEN
      RAISE program_error;
    END IF;
  
    RETURN TRUE;
  
  EXCEPTION
    WHEN OTHERS THEN
      IF o_error_message IS NULL THEN
        o_error_message := substr(l_module || ' ' || SQLCODE || ' ' ||
                                  SQLERRM,
                                  1,
                                  2000);
      END IF;
    
      RETURN FALSE;
  END move_sea_plans_to_fab_plans;
  -- ============================================================
  FUNCTION set_date(o_error_message IN OUT VARCHAR2) RETURN BOOLEAN IS
  
    l_module VARCHAR2(64) := 'MD_CRE_PLAN_PKG.SET_DATE';
  
  BEGIN
    -- ------------------------------------------------
    -- set current G_week_in_year and G_date
    -- G_week_in_month
    -- -----------------------------------------------
    IF md_common_pkg.get_ref_date_plan(o_error_message --CR 98359
                                      ,
                                       g_date) = FALSE THEN
      RAISE program_error;
    END IF;
  
    g_date_chr := to_char(g_date, 'MM/DD/YYYY');
    g_year     := to_number(to_char(g_date, 'YYYY'));
  
    SELECT week_no, t_date_yy_mm
      INTO g_week_no, g_date_yy_mm
      FROM (SELECT DISTINCT week_no,
                            substr(v_year_no, 3) ||
                            lpad(to_number(to_char(to_date(month_in_year ||
                                                           v_year_no,
                                                           'MONYYYY'),
                                                   'MM')),
                                 2,
                                 0) || week_no t_date_yy_mm
              FROM (SELECT year_no,
                           half_no,
                           month_no,
                           week_no,
                           week_in_year,
                           CASE
                             WHEN substr(half_no, 5, 1) = 2 AND month_no = 6 THEN
                              year_no + 1
                             ELSE
                              year_no
                           END v_year_no,
                           CASE
                             WHEN substr(half_no, 5, 1) = 1 AND month_no = 1 THEN
                              'FEB'
                             WHEN substr(half_no, 5, 1) = 1 AND month_no = 2 THEN
                              'MAR'
                             WHEN substr(half_no, 5, 1) = 1 AND month_no = 3 THEN
                              'APR'
                             WHEN substr(half_no, 5, 1) = 1 AND month_no = 4 THEN
                              'MAY'
                             WHEN substr(half_no, 5, 1) = 1 AND month_no = 5 THEN
                              'JUN'
                             WHEN substr(half_no, 5, 1) = 1 AND month_no = 6 THEN
                              'JUL'
                             WHEN substr(half_no, 5, 1) = 2 AND month_no = 1 THEN
                              'AUG'
                             WHEN substr(half_no, 5, 1) = 2 AND month_no = 2 THEN
                              'SEP'
                             WHEN substr(half_no, 5, 1) = 2 AND month_no = 3 THEN
                              'OCT'
                             WHEN substr(half_no, 5, 1) = 2 AND month_no = 4 THEN
                              'NOV'
                             WHEN substr(half_no, 5, 1) = 2 AND month_no = 5 THEN
                              'DEC'
                             WHEN substr(half_no, 5, 1) = 2 AND month_no = 6 THEN
                              'JAN'
                           END month_in_year
                      FROM pl_fiscal_calendar
                     WHERE g_date BETWEEN bow_date AND eow_date)
             WHERE rownum = 1);
  
    RETURN TRUE;
  
  EXCEPTION
    WHEN OTHERS THEN
      IF o_error_message IS NULL THEN
        o_error_message := substr(l_module || ' ' || SQLCODE || ' ' ||
                                  SQLERRM,
                                  1,
                                  2000);
      END IF;
    
      RETURN FALSE;
    
  END set_date;
  -- ==========================================================

  FUNCTION build_plan_geo_prod(o_error_message IN OUT VARCHAR2)
    RETURN BOOLEAN IS
  
    l_module VARCHAR2(64) := 'MD_CRE_PLAN_PKG.BUILD_PLAN_GEO_PROD';
    v_err    VARCHAR2(200);
    v_exception EXCEPTION;
  
  BEGIN
    -- ---------------------------------
    -- Find the new geo - prod
    -- ---------------------------------
    IF drop_table(o_error_message, 'MD_PLN_NEW_GEO_PROD') = FALSE THEN
      RAISE program_error;
    END IF;
  
    IF drop_table(o_error_message, 'MD_PLN_RCPT_DT_PROD') = FALSE THEN
      RAISE program_error;
    END IF;
  
    IF drop_table(o_error_message, 'MD_PLN_EXIST_PROD') = FALSE THEN
      RAISE program_error;
    END IF;
  
    IF drop_table(o_error_message, 'MD_PLN_INSERT_GEO_PROD_MEM') = FALSE THEN
      RAISE program_error;
    END IF;
  
    IF drop_table(o_error_message, 'MD_PLN_STYLE_COLOUR') = FALSE THEN
      RAISE program_error;
    END IF;
  
    IF drop_table(o_error_message, 'MD_STYLE_COLOR_KILL_PRICE') = FALSE THEN
      RAISE program_error;
    END IF;
  
    IF drop_table(o_error_message, 'MD_VALID_STYLES_WORK') = FALSE THEN
      RAISE program_error;
    END IF;
  
    -------------------------------
    -- Get styles for exclusion
    --------------------------------
  
    EXECUTE IMMEDIATE 'CREATE TABLE MD_VALID_STYLES_WORK
 TABLESPACE ' || g_tablespace ||
                      '  NOLOGGING AS
 SELECT STYLE
   FROM RAG_SKUS
 MINUS
 SELECT STYLE
   FROM retek.RM_MDO_STYLE_EXCLUDE';
  
    -- ---------------------------------------------------
    -- Get geo_id/prod_id;
    -- not already in active MDO plan
    -- no replenishment; no full price
    -- WHERE status = '''||V_SEND||'''
    -- -----------------------------------------------------
    EXECUTE IMMEDIATE 'CREATE TABLE MD_PLN_NEW_GEO_PROD
 TABLESPACE ' || g_tablespace ||
                      '  NOLOGGING AS
 SELECT GEO_ID,PROD_ID,STYLE,COLOUR,STORE
   FROM (SELECT g.geo_id,g.prod_id,g.style,g.colour, g.loc STORE
     FROM MD_STG_GEO_PROD_CURR g,rag_style s, MD_GEO_PROD_SALES_INTRO_DT d, MD_VALID_STYLES_WORK v
          WHERE g.status IN (''' || active || ''',''' ||
                      clearance || ''')
            AND s.style = g.style
            AND s.style = v.style
            AND s.repl_ind = ''' || repl_ind || '''
            AND g.style = d.style
            AND g.colour = d.colour
            AND g.loc = d.loc
      AND g.loc IN (SELECT store from STORE_ATTRIBUTES WHERE NVL(clearance_store, ''N'') = ''N'')
            AND d.insert_dt < ''' || g_date || '''
         MINUS
         SELECT geo_id,prod_id,style,colour,STORE
           FROM MD_IMPORT_PLAN_MEMBER
         )
MINUS
SELECT GEO_ID,PROD_ID,STYLE,COLOUR,a.STORE
  FROM MD_ACTIVE_STATUS_RM a
 WHERE END_DT >= ' || ' TO_DATE(''' || g_date_chr ||
                      ''',''MM/DD/YYYY'') ';
  
    IF create_index(o_error_message,
                    USER,
                    'MD_PLN_NEW_GEO_PROD',
                    'MD_PLN_NEW_GEO_PROD_i1',
                    'style,colour,store',
                    'Y') = FALSE THEN
      RAISE program_error;
    END IF;
  
    -- -----------------------------------------------
    -- Find all active style - colour
    -- ---------------------------------------------
    EXECUTE IMMEDIATE 'CREATE TABLE MD_PLN_STYLE_COLOUR
 TABLESPACE ' || g_tablespace ||
                      '  NOLOGGING AS
 SELECT DISTINCT STYLE,COLOUR,STORE
   FROM MD_PLN_NEW_GEO_PROD ';
  
    IF create_index(o_error_message,
                    USER,
                    'MD_PLN_STYLE_COLOUR',
                    'MD_PLN_STYLE_COLOUR_i1',
                    'style,colour,store',
                    'Y') = FALSE THEN
      RAISE program_error;
    END IF;
  
    -- -----------------------------------------------
    -- Find Style/Colors already at Kill Price
    -- ---------------------------------------------
    EXECUTE IMMEDIATE '
CREATE TABLE MD_STYLE_COLOR_KILL_PRICE
TABLESPACE ' || g_tablespace ||
                      '  NOLOGGING AS
SELECT rnk.style,
       rnk.colour,
       rnk.store,
       rnk.unit_retail,
       rnk.original_retail,
       rnk.final_disc_value
  FROM
(select ovr.rank,
       RANK() OVER (PARTITION BY sty.STYLE,sty.COLOUR
                    ORDER BY ovr.rank ) PLAN_RANK,
       sty.style,
       sty.colour,
       sty.store,
       sty.dept,
       sty.class,
       sty.group_no,
       sty.chain_id,
       sty.merch_type,
       sty.season_code,
       sty.mdo_uda,
       sty.mdo_value,
       sty.unit_retail,
       sty.original_retail,
       decode(ovr.final_disc_value_type, 1, (1 - ovr.final_disc_value/100)*sty.original_retail,  ovr.final_disc_value) final_disc_value
from
     (select distinct mp.style,
                      mp.colour,
                      mp.store,
                      dl.dept,
                      dl.class,
                      dl.subclass,
                      d.group_no,
                      dl.chain_id,
                      v.merch_type,
                      v.season_code,
                      v.mdo_uda,
                      v.mdo_value,
                      mp.unit_retail,
                      mp.original_retail
        from
                      (select m.style,
                              m.colour,
                              m.store,
                              max(g.unit_retail) unit_retail,
                              nvl(max(NVL(g.original_retail,0)),0) original_retail
                         from md_pln_style_colour m,
                  md_stg_geo_prod_curr g
                        where m.style = g.style
                          and m.colour = g.colour
                          and m.store = g.loc
                        group by m.style, m.colour, m.store
                        ) mp,
            desc_look dl,
            deps d,
            md_pln_uda_vl v
      where dl.sku = mp.style
        and d.dept = dl.dept
        and mp.style = v.style
        and mp.colour = v.colour) sty,
   rm_mdo_plan_override ovr
where sty.chain_id = ovr.chain_id
  and sty.group_no = ovr.group_no
  and sty.dept = ovr.dept
  and sty.class = NVL(ovr.class,sty.class)
  and sty.season_code = NVL(ovr.season_code,sty.season_code)
  and NVL(sty.mdo_uda,0) = NVL(ovr.mdo_uda,NVL(sty.mdo_uda,0))
  and NVL(sty.mdo_value,0) = NVL(ovr.mdo_value,NVL(sty.mdo_value,0))) rnk
WHERE rnk.plan_rank = 1
  AND rnk.unit_retail <= rnk.final_disc_value ';
  
    -- ---------------------------------------------
    -- Remove Style/Colors already at Kill Price
    -- ---------------------------------------------
    EXECUTE IMMEDIATE ' DELETE FROM MD_PLN_STYLE_COLOUR
   WHERE (style,colour, store) IN (SELECT style,colour, store
            FROM MD_STYLE_COLOR_KILL_PRICE) ';
  
    EXECUTE IMMEDIATE ' DELETE FROM MD_PLN_NEW_GEO_PROD
   WHERE (style,colour, store) IN (SELECT style,colour, store
            FROM MD_STYLE_COLOR_KILL_PRICE) ';
  
    -- ------------------------------------------
    -- This table may have eligible style-colour
    -- Farah
    -- 
    -- CR-132020: Added addl condition to ignore last receipt dates for "New Stores"
    -- Mani Nutalapati
    -- ------------------------------------------
    EXECUTE IMMEDIATE 'CREATE TABLE MD_PLN_RCPT_DT_PROD' || ' tablespace ' ||
                      g_tablespace || '  NOLOGGING as
  SELECT s.style
         ,s.colour
         ,ch.cluster_group_id
         ,MIN(TRUNC(s.first_received)) first_received
         ,MAX(TRUNC(s.last_received)) last_received
    FROM MD_STG_GEO_PROD_CURR s
         ,MD_PLN_STYLE_COLOUR g
         ,RM_CLUSTER_GROUP_HEAD ch
         ,RM_CLUSTER_GROUP_DETAIL cd
         ,RM_STORE_CLUSTER sc
   WHERE s.style = g.style
     AND s.colour = g.colour
     AND s.loc = g.store
     AND s.status IN (''' || active || ''',''' ||
                      clearance || ''')
     AND ch.cluster_group_id = cd.cluster_group_id
     AND cd.cluster_value = sc.cluster_value
     AND sc.store = g.store
     AND NOT EXISTS ( SELECT 1
                        FROM
                      (          
                      SELECT cal_tab.store, cal_tab.store_open_date, 
                             (CASE WHEN (cal_tab.total_weeks = 4 AND cal_tab.week_no IN (1,2))
                                   THEN cal_tab.eom_date  
                                   WHEN (cal_tab.total_weeks = 4 AND cal_tab.week_no IN (3,4))
                                   THEN cal_tab.next_eom_date 
                                   WHEN (cal_tab.total_weeks = 5 AND cal_tab.week_no IN (1,2,3))
                                   THEN cal_tab.eom_date  
                                   WHEN (cal_tab.total_weeks = 5 AND cal_tab.week_no IN (4,5))
                                   THEN cal_tab.next_eom_date
                              END 
                              )new_store_eod 
                        FROM 
                      (
                      SELECT s.store, s.store_open_date, c.week_in_year, c.month_no, c.bow_date, c.eow_date, c.week_no, 
                             (SELECT MAX(week_no)
                                FROM pl_fiscal_calendar c1
                               WHERE c1.year_no = c.year_no
                                 AND c1.month_no = c.month_no
                                 AND c1.half_no = c.half_no) total_weeks, 
                              eom_date,  
                              (SELECT MIN(eom_date)
                                 FROM pl_fiscal_calendar c1
                                WHERE eom_date > c.eom_date) next_eom_date   
                        FROM pl_fiscal_calendar c, STORE s
                       WHERE s.store_open_date BETWEEN bow_date AND eow_date      
                         AND (s.store_open_date > TRUNC(SYSDATE)
                              OR
                              s.store_open_date > TRUNC(SYSDATE)-60)
                         AND s.store_close_date IS NULL
                       ORDER BY week_in_year, half_no, bow_date, week_no
                       ) cal_tab
                       ) new_stores    
                       WHERE new_stores.new_store_eod >= TRUNC(SYSDATE) 
                         AND new_stores.store = sc.store
                   )
   GROUP BY s.style,s.colour, ch.cluster_group_id ';
  
    IF create_index(o_error_message,
                    USER,
                    'MD_PLN_RCPT_DT_PROD',
                    'MD_PLN_RCPT_DT_PRODA_i1',
                    'style,colour, cluster_group_id',
                    'Y') = FALSE THEN
      RAISE program_error;
    END IF;
  
    -- ------------------------------------------------------
    -- Find existing eligible style-colour from new geo-prod
    -- Farah
    -- ------------------------------------------------------
    EXECUTE IMMEDIATE 'CREATE TABLE MD_PLN_EXIST_PROD' || ' tablespace ' ||
                      g_tablespace || '  NOLOGGING as
   SELECT s.style,s.colour, s.cluster_group_id
     FROM MD_PLN_RCPT_DT_PROD s
   INTERSECT
   SELECT m.style,m.colour, m.cluster_group_id
     FROM MD_IMPORT_PLAN_MEMBER m ';
  
    EXECUTE IMMEDIATE ' DELETE FROM MD_PLN_RCPT_DT_PROD
   WHERE (style,colour, cluster_group_id) IN (SELECT style,colour, cluster_group_id
            FROM MD_PLN_EXIST_PROD) ';
    COMMIT;
  
    -- ----------------------------------------------------
    -- Insert records from MDO_INSERT_GEO_PROD_MEM table
    -- to mdo_import_plan_member
    -- PPR 92205 - Purnima Kunwor - Do not insert additional
    -- members if Plan is Complete or Deleted
    -- -----------------------------------------------------
    EXECUTE IMMEDIATE 'CREATE TABLE MD_PLN_INSERT_GEO_PROD_MEM' ||
                      ' tablespace ' || g_tablespace ||
                      '  NOLOGGING as
  SELECT DISTINCT G.GEO_ID
         ,G.PROD_ID
         ,cd.CLUSTER_GROUP_ID
         ,G.STYLE
         ,G.COLOUR
         ,G.STORE
         ,M.MDO_PLAN_NM
    FROM MD_PLN_NEW_GEO_PROD G
         ,MD_IMPORT_PLAN_MEMBER M
         ,MD_PLN_EXIST_PROD D
         ,MD_IMPORT_PLAN P
         ,RM_CLUSTER_GROUP_DETAIL cd
         ,RM_STORE_CLUSTER sc
   WHERE G.STYLE = D.STYLE
     AND G.COLOUR = D.COLOUR
     AND M.STYLE = D.STYLE
     AND M.COLOUR = D.COLOUR
     AND cd.cluster_value = sc.cluster_value
     AND cd.cluster_group_id = m.cluster_group_id
     AND g.store = sc.store
     AND P.MDO_PLAN_NM = M.MDO_PLAN_NM
     AND P.STATUS <> ''C''
     AND P.ACTION_CD <> 4
   MINUS
  SELECT DISTINCT M.GEO_ID
    ,M.PROD_ID
    ,M.CLUSTER_GROUP_ID
    ,M.STYLE
    ,M.COLOUR
    ,M.STORE
    ,M.MDO_PLAN_NM
    FROM MD_IMPORT_PLAN_MEMBER M
        ,MD_PLN_EXIST_PROD D
   WHERE M.STYLE = D.STYLE
     AND M.COLOUR = D.COLOUR
     AND M.CLUSTER_GROUP_ID = D.CLUSTER_GROUP_ID';
  
    -- -------------------------------------------------
    -- If same style - colour exist for multiple plan
    -- then keep one PPR 89984 Farah
    -- ---------------------------------------------------
    EXECUTE IMMEDIATE '  DELETE FROM MD_PLN_INSERT_GEO_PROD_MEM
    WHERE ROWID IN (
  SELECT ROWID FROM MD_PLN_INSERT_GEO_PROD_MEM
   MINUS
  SELECT MAX(ROWID) 
      FROM MD_PLN_INSERT_GEO_PROD_MEM
     GROUP BY GEO_ID,PROD_ID)';
  
    RETURN TRUE;
  
  EXCEPTION
    WHEN v_exception THEN
      o_error_message := l_module || ' ' || v_err;
      RETURN FALSE;
    
    WHEN OTHERS THEN
      IF o_error_message IS NULL THEN
        o_error_message := substr(l_module || ' ' || SQLCODE || ' ' ||
                                  SQLERRM,
                                  1,
                                  2000);
      END IF;
    
      RETURN FALSE;
    
  END build_plan_geo_prod;
  -- ==================================================================

  FUNCTION find_mdo_plan_uda(o_error_message IN OUT VARCHAR2) RETURN BOOLEAN IS
  
    l_module VARCHAR2(64) := 'MD_CRE_PLAN_PKG.FIND_MDO_UDA';
    l_season VARCHAR2(2000);
  
    CURSOR c_season IS
      SELECT code_type, code, code_desc
        FROM code_detail
       WHERE code_type = v_season;
  
  BEGIN
    IF drop_table(o_error_message, 'MD_PLN_MDO_UDA1') = FALSE THEN
      RAISE program_error;
    END IF;
  
    IF drop_table(o_error_message, 'MD_PLN_MDO_UDA') = FALSE THEN
      RAISE program_error;
    END IF;
  
    IF drop_table(o_error_message, 'MD_PLN_UDA_CNT') = FALSE THEN
      RAISE program_error;
    END IF;
  
    IF drop_table(o_error_message, 'MD_PLN_UDA_VL') = FALSE THEN
      RAISE program_error;
    END IF;
  
    FOR rec IN c_season LOOP
      IF l_season IS NULL THEN
        l_season := '''' || rec.code_desc || '''';
      ELSE
        l_season := l_season || ' ,''' || rec.code_desc || '''';
      END IF;
    END LOOP;
  
    -- --------------------------------------------------
    -- row to column  Farah
    -- merch ,season and mdo_uda
    -- --------------------------------------------------
    EXECUTE IMMEDIATE 'CREATE TABLE MD_PLN_MDO_UDA1' || ' tablespace ' ||
                      g_tablespace || '  NOLOGGING as
      SELECT item,
             merch_type_uda,
             merch_type_value,
             season_uda,
             season_value,
             mdo_uda,
             mdo_value,
             exclude_uda
       FROM (
       SELECT item,
              SUM(merch_type_uda) merch_type_uda,
              SUM(merch_type_value) merch_type_value,
              SUM(season_uda) season_uda,
              SUM(season_value) season_value,
              SUM(mdo_uda) mdo_uda,
              SUM(mdo_value) mdo_value,
              MAX(exclude_uda) exclude_uda
        FROM (
        SELECT DISTINCT U.item,
        (CASE  c.code_desc
         WHEN ''SL'' THEN ''FAB''
         ELSE ''SEA''
         END ) merch_type,
               1 merch_type_uda,
               1 merch_type_value,
               c.code_desc season_code,
               u.uda_id season_uda,
               u.uda_value season_value,
               NULL mdo_uda,
               NULL mdo_value,
               NULL exclude_uda
          FROM UDA_ITEM_LOV u, code_detail c
         WHERE c.code_desc IN (' || l_season || ')
           AND c.code_type = u.uda_id
           AND c.code = u.uda_value
           AND c.code_type = ''10''
          UNION ALL
        SELECT DISTINCT U.item,
               NULL merch_type,
               NULL merch_type_uda,
               NULL merch_type_value,
               NULL season_code,
               NULL season_uda,
               NULL season_value,
               u.uda_id  mdo_uda,
               u.uda_value mdo_value,
               NULL exclude_uda
          FROM UDA_ITEM_LOV u, code_detail c
         WHERE c.code_desc = ''' || v_mdo_grp || '''
           AND c.code_type = u.uda_id
           AND c.code_type = ''25''
          UNION ALL
        SELECT DISTINCT U.item,
               NULL merch_type,
               NULL merch_type_uda,
               NULL merch_type_value,
               NULL season_code,
               NULL season_uda,
               NULL season_value,
               NULL mdo_uda,
               NULL mdo_value,
               ''X'' exclude_uda
          FROM (select item
                  from rm_uda_exclude e,
                       uda_item_lov lov
                 where e.uda_id = lov.uda_id
                   and nvl(e.uda_lov_value, lov.uda_value)  = lov.uda_value
                   and e.process_id = ''MDPL''
                   and e.exclude_ind = ''Y''
                UNION
                select item
                  from rm_uda_exclude e,
                       uda_item_ff ff
                 where e.uda_id = ff.uda_id
                   and nvl(e.uda_ff_value, ff.uda_text) = ff.uda_text
                   and e.process_id = ''MDPL''
                   and e.exclude_ind = ''Y''
                UNION
                select item
                  from rm_uda_exclude e,
                       uda_item_date dt
                 where e.uda_id = dt.uda_id
                   and nvl(e.uda_date_value, dt.uda_date) = dt.uda_date
                   and e.process_id = ''MDPL''
                   and e.exclude_ind = ''Y'') U
      ) GROUP BY ITEM
      ) WHERE merch_type_value IS NOT NULL
          AND season_value IS NOT NULL ';
  
    IF create_index(o_error_message,
                    USER,
                    'MD_PLN_MDO_UDA1',
                    'MD_PLN_MDO_UDA1_i1',
                    'mdo_uda,mdo_value',
                    'Y') = FALSE THEN
      RAISE program_error;
    END IF;
  
    -- ------------------------------------------
    -- Add merch_type, season_code and style, colour  Farah
    -- --------------------------------------------
    EXECUTE IMMEDIATE 'CREATE TABLE MD_PLN_MDO_UDA' || ' tablespace ' ||
                      g_tablespace || '  NOLOGGING as
  SELECT D.item,
         R.STYLE,
         R.COLOUR,
         D.MERCH_TYPE,
         D.SEASON_CODE,
         D.merch_type_uda,
         D.merch_type_value,
         D.season_uda,
         D.season_value,
         D.mdo_uda,
         D.mdo_value,
         D.exclude_uda
   FROM (SELECT A.item,
    cast(
    (CASE  c.code_desc
       WHEN ''SL'' THEN ''FAB''
       ELSE ''SEA''
       END
      ) as varchar2(5)) merch_type,
              c.code_desc SEASON_CODE,
              A.merch_type_uda,
              A.merch_type_value,
              A.season_uda,
              A.season_value,
              A.mdo_uda,
              A.mdo_value,
              A.exclude_uda
         FROM MD_PLN_MDO_UDA1 A,
                CODE_DETAIL C
         WHERE TO_CHAR(A.season_uda) = C.CODE_TYPE
             AND TO_CHAR(A.season_value) = C.CODE) D
                ,RAG_SKUS R
  WHERE D.ITEM = R.SKU  ';
  
    IF create_index(o_error_message,
                    USER,
                    'MD_PLN_MDO_UDA',
                    'MD_PLN_MDO_UDA_i1',
                    'STYLE,MERCH_TYPE,SEASON_CODE',
                    'Y') = FALSE THEN
      RAISE program_error;
    END IF;
  
    -- ---------------------------------------------------------------
    -- update MD_PLN_MDO_UDA.merch type to 'PSEA' for items with merch type currently 'SEA'
    -- ----------------------------------------------------------------
    EXECUTE IMMEDIATE 'update MD_PLN_MDO_UDA md
       set merch_type = ''PSEA''
     where merch_type = ''SEA''
       and mdo_uda is null
       and exists(select 1
                    from desc_look dl
                        ,deps d
                        ,rm_mdo_hier_exceptions hier
                   where dl.sku = md.item
                     and dl.dept = d.dept
                     and d.group_no = hier.group_no
                     and dl.dept = NVL(hier.dept, dl.dept)
                     and dl.class = NVL(hier.class, dl.class)
                     and dl.subclass = NVL(hier.subclass, dl.subclass)
                 )';
  
    COMMIT;
  
    -- ---------------------------------------------------------------
    -- update MD_PLN_MDO_UDA.merch type to 'PSEA'/'FAB' for items with mdo_uda = 25
    -- ----------------------------------------------------------------
    EXECUTE IMMEDIATE 'update MD_PLN_MDO_UDA md
       set merch_type = ''PSEA''
     where merch_type = ''SEA''
       and mdo_uda is not null
       and mdo_uda = 25
       and exists(select 1
               from md_plan_parameters pp
              where pp.mdo_uda = md.mdo_uda
                and pp.mdo_value = md.mdo_value)';
  
    COMMIT;
  
    EXECUTE IMMEDIATE 'update MD_PLN_MDO_UDA md
       set merch_type = ''FAB''
     where merch_type = ''SEA''
       and mdo_uda is not null
       and mdo_uda = 25
       and not exists(select 1
                 from md_plan_parameters pp
                  where pp.mdo_uda = md.mdo_uda
                   and pp.mdo_value = md.mdo_value)';
  
    COMMIT;
  
    -- ---------------------------------------------------------------
    -- START CR 132023 Move Gordmans SEA products to FAB
    -- ----------------------------------------------------------------
    EXECUTE IMMEDIATE 'UPDATE MD_PLN_MDO_UDA md
                          SET merch_type = ''FAB''
                        WHERE merch_type = ''SEA''
                          AND EXISTS (SELECT 1 
                                        FROM desc_look dl 
                                       WHERE dl.sku = md.item 
                                         AND dl.chain_id =  '|| v_gordmans_chain || ')';

    COMMIT;
    -- ---------------------------------------------------------------
    -- END CR 132023 Move Gordmans SEA products to FAB
    -- ----------------------------------------------------------------

    -- ---------------------------------------------------------------
    -- Find the merch_type and season_code of style-colour with the most SKUs  Farah
    -- ----------------------------------------------------------------
  
    EXECUTE IMMEDIATE 'CREATE TABLE MD_PLN_UDA_CNT' || ' tablespace ' ||
                      g_tablespace || '  NOLOGGING as
     SELECT E.item,
            CC.MERCH_SEA_cnt,
            E.STYLE,
            E.COLOUR,
            E.MERCH_TYPE,
            E.SEASON_CODE,
            E.merch_type_uda,
            E.merch_type_value,
            E.season_uda,
            E.season_value,
            E.mdo_uda,
            E.mdo_value,
            E.exclude_uda
       FROM MD_PLN_MDO_UDA E INNER JOIN
            (SELECT MERCH_SEA_cnt, STYLE,COLOUR,MERCH_TYPE,SEASON_CODE,
                    RANK() OVER (PARTITION BY STYLE,COLOUR
                    ORDER BY MERCH_SEA_cnt,SEASON_CODE,MERCH_TYPE DESC ) STYLE_RANK
               FROM (
             SELECT COUNT(*) MERCH_SEA_cnt, STYLE,COLOUR,MERCH_TYPE,SEASON_CODE
               FROM MD_PLN_MDO_UDA
              GROUP BY STYLE,COLOUR,MERCH_TYPE,SEASON_CODE
              )
              ) CC
         ON E.STYLE = CC.STYLE
        AND E.COLOUR = CC.COLOUR
        AND E.MERCH_TYPE = CC.MERCH_TYPE
        AND E.SEASON_CODE = CC.SEASON_CODE
        AND CC.STYLE_RANK = 1 ';
  
    IF create_index(o_error_message,
                    USER,
                    'MD_PLN_UDA_CNT',
                    'MD_PLN_UDA_CNT_i1',
                    'mdo_uda,mdo_value',
                    'Y') = FALSE THEN
      RAISE program_error;
    END IF;
  
    -- -------------------------------------------
    -- Add MDO uda description
    -- -------------------------------------------
    EXECUTE IMMEDIATE ' CREATE TABLE MD_PLN_UDA_VL' || ' tablespace ' ||
                      g_tablespace ||
                      '  NOLOGGING as
     SELECT u.item,
            u.style,
            u.colour,
            u.merch_type,
            u.merch_type_uda,
            u.merch_type_value,
            u.season_code,
            u.season_uda,
            u.season_value,
            u.mdo_uda,
            u.mdo_value,
            NULL mdo_value_desc,
            u.exclude_uda
       FROM MD_PLN_UDA_CNT u
        WHERE u.mdo_uda IS NULL
      UNION ALL
     SELECT u.item,
            u.style,
            u.colour,
            u.merch_type,
            u.merch_type_uda,
            u.merch_type_value,
            u.season_code,
            u.season_uda,
            u.season_value,
            u.mdo_uda,
            u.mdo_value,
            v.uda_value_desc mdo_value_desc,
            u.exclude_uda
       FROM MD_PLN_UDA_CNT u,
            uda_values v
        WHERE v.uda_id = u.mdo_uda
          AND v.uda_value = u.mdo_value ';
  
    IF create_index(o_error_message,
                    USER,
                    'MD_PLN_UDA_VL',
                    'MD_PLN_UDA_VL_i1',
                    'ITEM',
                    'Y') = FALSE THEN
      RAISE program_error;
    END IF;
  
    IF drop_table(o_error_message, 'MD_PLN_MDO_UDA1') = FALSE THEN
      RAISE program_error;
    END IF;
    /*
        IF DROP_TABLE(O_error_message,
                      'MD_PLN_MDO_UDA' ) = FALSE then
            raise PROGRAM_ERROR;
        END IF;
    */
    IF drop_table(o_error_message, 'MD_PLN_UDA_CNT') = FALSE THEN
      RAISE program_error;
    END IF;
  
    RETURN TRUE;
  EXCEPTION
    WHEN OTHERS THEN
      IF o_error_message IS NULL THEN
        o_error_message := substr(l_module || ' ' || SQLCODE || ' ' ||
                                  SQLERRM,
                                  1,
                                  2000);
      END IF;
      RETURN FALSE;
  END find_mdo_plan_uda;
  -- =================================================================

  FUNCTION find_mdo_candidate(o_error_message IN OUT VARCHAR2,
                              i_merch_type    IN VARCHAR2,
                              i_season        IN VARCHAR2) RETURN BOOLEAN IS
  
    l_module           VARCHAR2(64) := 'MD_CRE_PLAN_PKG.FIND_MDO_CANDIDATE';
    v_on_order_weeks   NUMBER;
    v_merch_type_where VARCHAR2(4000);
	
	--CR 129315 MDo chain level parameters
	g_v_on_order_weeks   NUMBER;
	v_chain_id number;
  
  BEGIN
  
    BEGIN
      SELECT numeric_value
        INTO v_on_order_weeks
        FROM rm_system_globals
       WHERE variable_name = 'MDO_PLAN_ON_ORDER_WEEKS';
    
    EXCEPTION
      WHEN OTHERS THEN
        o_error_message := 'variable RM_SYSTEM_GLOBALS.MDO_PLAN_ON_ORDER_WEEKS not defined. error in procedure FIND_MDO_CANDIDATE.';
        RAISE program_error;
    END;
  
  --CR 129315 MDo chain level parameters
  BEGIN
      SELECT numeric_value
        INTO g_v_on_order_weeks
        FROM rm_system_globals
       WHERE variable_name = 'G_MDO_PLAN_ON_ORDER_WEEKS';
    
    EXCEPTION
      WHEN OTHERS THEN
        o_error_message := 'variable RM_SYSTEM_GLOBALS.G_MDO_PLAN_ON_ORDER_WEEKS not defined. error in procedure FIND_MDO_CANDIDATE.';
        RAISE program_error;
    END;
	
	BEGIN
	  SELECT chain_id into v_chain_id FROM chain   
 WHERE chain_name = 'Gordmans';
 
  EXCEPTION
      WHEN OTHERS THEN
        o_error_message := 'variable Gordmans chain id not defined in chain table. error in procedure FIND_MDO_CANDIDATE.';
        RAISE program_error;
    END;
  
  -- CR-132020: Apply DC inventory thresholds to exclude styles from plan creation
  BEGIN
    SELECT NUMERIC_VALUE
      INTO v_dc_oh_threshold
      FROM RM_SYSTEM_GLOBALS
     WHERE variable_name = 'MDO_PLAN_DC_ON_HANDS_THRESHOLD';
  EXCEPTION
     WHEN OTHERS
     THEN
        o_error_message := 'variable RM_SYSTEM_GLOBALS.MDO_PLAN_DC_ON_HANDS_THRESHOLD not defined. error in procedure FIND_MDO_CANDIDATE.';
        RAISE program_error;
  END;

	
    -- -------------------------------------------
    -- Add dept,class, group...
    -- -------------------------------------------
  
    EXECUTE IMMEDIATE ' CREATE TABLE MD_' || i_merch_type || '_' ||
                      i_season || '_UDA_DPT_CHG' || ' tablespace ' ||
                      g_tablespace || '  NOLOGGING as
     SELECT DISTINCT style,
            colour,
            chain_id,
            cluster_group_id,
            dept,
            dept_name,
            CASE
              WHEN mdo_value IS NOT NULL THEN
                   0
              ELSE
                  CLASS
            END CLASS,
            class_name,
            group_no,
            group_name,
            merch_type,
            merch_type_uda,
            merch_type_value,
            season_code,
            season_uda,
            season_value,
            mdo_uda,
            mdo_value,
            first_received,
            last_received,
            mdo_value_desc
    FROM (
       SELECT DISTINCT r.style,
              r.colour,
              d.chain_id,
              r.cluster_group_id,
              s.dept,
              d.dept_name,
              s.CLASS,
              c.class_name,
              d.group_no,
              g.group_name,
              u.merch_type,
              u.merch_type_uda,
              u.merch_type_value,
              u.season_code,
              u.season_uda,
              u.season_value,
              u.mdo_uda,
              u.mdo_value,
              r.first_received,
              r.last_received,
              u.mdo_value_desc
         FROM rag_style s,
              MD_PLN_UDA_VL u,
              MD_PLN_RCPT_DT_PROD r,
              deps d,
              CLASS c,
              GROUPS g
        WHERE u.style = s.style
          AND u.style = r.style
          AND u.colour = r.colour
          AND s.dept = d.dept
          AND d.dept = c.dept
          AND d.SEND_TO_MDO = ''Y''
          AND s.CLASS = c.CLASS
          AND d.group_no = g.group_no
          AND s.repl_ind = ''' || repl_ind || '''
          AND u.merch_type = ''' || i_merch_type || '''
          AND u.season_code = ''' || i_season || '''
          AND NVL(u.exclude_uda,''N'') <> ''X''
         ) ';
  
    IF create_index(o_error_message,
                    USER,
                    'MD_' || i_merch_type || '_' || i_season ||
                    '_UDA_DPT_CHG',
                    'MD_' || i_merch_type || '_' || i_season ||
                    '_UDA_DPT_C_i1',
                    'dept,class,chain_id,cluster_group_id,group_no,merch_type,season_code,mdo_uda,mdo_value',
                    'Y') = FALSE THEN
      RAISE program_error;
    END IF;
  
    -- -------------------------------------------------
    -- Get min, max of received date using style+season+merch_type+MDO UDA
    -- TPR 90605 Farah
    -- -------------------------------------------------
    EXECUTE IMMEDIATE ' CREATE TABLE MD_' || i_merch_type || '_' ||
                      i_season || '_UDA_DT' || ' tablespace ' ||
                      g_tablespace || '  NOLOGGING as
     SELECT DISTINCT A.style,
            A.colour,
            A.chain_id,
            A.cluster_group_id,
            A.dept,
            A.dept_name,
            A.CLASS,
            A.class_name,
            A.group_no,
            A.group_name,
            A.merch_type,
            A.merch_type_uda,
            A.merch_type_value,
            A.season_code,
            A.season_uda,
            A.season_value,
            A.mdo_uda,
            A.mdo_value,
            DD.first_received,
            DD.last_received,
            A.mdo_value_desc
       FROM (SELECT style,
        cluster_group_id,
        merch_type,
        season_code,
        mdo_uda,
        mdo_value,
        MIN(first_received) first_received ,
        MAX(last_received) last_received
               FROM MD_' || i_merch_type || '_' ||
                      i_season || '_UDA_DPT_CHG
        GROUP BY style,cluster_group_id,merch_type,season_code,mdo_uda,mdo_value
      ) DD,
      MD_' || i_merch_type || '_' || i_season ||
                      '_UDA_DPT_CHG A
      WHERE DD.style = A.style
        AND DD.cluster_group_id = A.cluster_group_id
        AND DD.merch_type = A.merch_type
        AND DD.season_code = A.season_code
        AND NVL(DD.MDO_UDA,0) = NVL(A.MDO_UDA,0)
        AND NVL(DD.MDO_VALUE,0) = NVL(A.MDO_VALUE,0) ';
  
    IF create_index(o_error_message,
                    USER,
                    'MD_' || i_merch_type || '_' || i_season || '_UDA_DT',
                    'MD_' || i_merch_type || '_' || i_season || '_UDA_DT_i1',
                    'dept,class,chain_id,cluster_group_id,group_no,merch_type,season_code,mdo_uda,mdo_value',
                    'Y') = FALSE THEN
      RAISE program_error;
    END IF;
  
    -- -----------------------------------------------------
    -- Force the recived date to be same for all styles that
    -- have mdo_uda attached to them for given dept
    -- TPR 90605 Farah
    -- -----------------------------------------------------
    EXECUTE IMMEDIATE ' CREATE TABLE MD_' || i_merch_type || '_' ||
                      i_season || '_UDA_DPT' || ' tablespace ' ||
                      g_tablespace || '  NOLOGGING as
     SELECT DISTINCT style,
            colour,
            chain_id,
            cluster_group_id,
            dept,
            dept_name,
            CLASS,
            class_name,
            group_no,
            group_name,
            merch_type,
            merch_type_uda,
            merch_type_value,
            season_code,
            season_uda,
            season_value,
            mdo_uda,
            mdo_value,
            first_received,
            last_received,
            mdo_value_desc
      FROM(
     SELECT DISTINCT A.style,
            A.colour,
            A.chain_id,
            A.cluster_group_id,
            A.dept,
            A.dept_name,
            A.CLASS,
            A.class_name,
            A.group_no,
            A.group_name,
            A.merch_type,
            A.merch_type_uda,
            A.merch_type_value,
            A.season_code,
            A.season_uda,
            A.season_value,
            A.mdo_uda,
            A.mdo_value,
            DD.first_received,
            DD.last_received,
            A.mdo_value_desc
       FROM (SELECT dept,
              mdo_uda,
              mdo_value,
              MIN(first_received) first_received ,
              MIN(last_received) last_received
         FROM MD_' || i_merch_type || '_' || i_season ||
                      '_UDA_DT
        WHERE mdo_uda IS NOT NULL
        GROUP BY dept,mdo_uda,mdo_value
            ) DD
           ,MD_' || i_merch_type || '_' || i_season ||
                      '_UDA_DT A
      WHERE A.mdo_uda IS NOT NULL
        AND DD.DEPT = A.DEPT
        AND DD.MDO_VALUE = A.MDO_VALUE
        AND DD.MDO_UDA = A.MDO_UDA
     UNION ALL
     SELECT DISTINCT style,
            colour,
            chain_id,
            cluster_group_id,
            dept,
            dept_name,
            CLASS,
            class_name,
            group_no,
            group_name,
            merch_type,
            merch_type_uda,
            merch_type_value,
            season_code,
            season_uda,
            season_value,
            mdo_uda,
            mdo_value,
            first_received,
            last_received,
            mdo_value_desc
       FROM MD_' || i_merch_type || '_' || i_season ||
                      '_UDA_DT
      WHERE mdo_uda IS NULL
     ) ';
  
    IF create_index(o_error_message,
                    USER,
                    'MD_' || i_merch_type || '_' || i_season || '_UDA_DPT',
                    'MD_' || i_merch_type || '_' || i_season ||
                    '_UDA_DPT_i1',
                    'dept,class,chain_id,cluster_group_id,group_no,merch_type,season_code,mdo_uda,mdo_value',
                    'Y') = FALSE THEN
      RAISE program_error;
    END IF;
  
    -- -------------------------------------------------
    -- Insert possible candidates into MD_PLAN_CANDIDATES
    -- CR 87831
    --
    -- -------------------------------------------------
    EXECUTE IMMEDIATE ' INSERT INTO MD_PLAN_CANDIDATES
  SELECT DISTINCT merch_type,
      season_code,
      chain_id,
      group_no,
      dept,
      class,
      mdo_uda,
      mdo_value,
      cluster_group_id
    FROM MD_' || i_merch_type || '_' || i_season ||
                      '_UDA_DPT';
  
    COMMIT;
  
    -- Add information to check if style has 50% or more markdown in PCMS 
    -- in the week
  
    EXECUTE IMMEDIATE ' CREATE TABLE MD_' || i_merch_type || '_' ||
                      i_season || '_PCMS_MKDN' || ' tablespace ' ||
                      g_tablespace ||
                      '  NOLOGGING as 
  SELECT style,
         colour,
         chain_id,
         cluster_group_id,
         dept,
         dept_name,
         CLASS,
         class_name,
         group_no,
         group_name,
         merch_type,
         merch_type_uda,
         merch_type_value,
         season_code,
         season_uda,
         season_value,
         mdo_uda,
         mdo_value,
         first_received,
         last_received,
         mdo_value_desc,
         price_change,
         case 
           when price_change is null then
             ''N''
         else
           ''Y''
         end pcms_mkdn
    FROM     
 (SELECT r.*,
         pc.price_change
    FROM
           (SELECT distinct rs.style, rs.colour, ch.cluster_group_id, h.price_change
              FROM price_susp_head h,
                   price_susp_detail d,
                   rm_price_susp_store ps,
                   retek.rm_store_cluster sc,
                   retek.rm_cluster_group_detail cd,
                   retek.rm_cluster_group_head ch,
                   retek.rag_skus rs
             WHERE h.price_change = d.price_change 
               AND h.status = ''D''
               AND ps.ticket_color in (''5'',''6'', ''7'', ''K'')
               AND h.active_date between TO_DATE( ''' ||
                      g_date_chr || ''',''mm/dd/yyyy'') - 7
               AND TO_DATE( ''' || g_date_chr ||
                      ''',''mm/dd/yyyy'')' || '
               AND (rs.sku =  d.sku or rs.style = d.sku)
               AND d.price_susp_detail_id = ps.price_susp_detail_id
               AND ps.store = sc.store
               AND sc.cluster_value = cd.cluster_value
               AND cd.cluster_group_id = ch.cluster_group_id
           )pc, MD_' || i_merch_type || '_' ||
                      i_season || '_UDA_DT r
   WHERE r.style = pc.style(+)
     AND r.colour = pc.colour(+)
     AND r.cluster_group_id = pc.cluster_group_id(+)
 )';
  
    IF create_index(o_error_message,
                    USER,
                    'MD_' || i_merch_type || '_' || i_season || '_PCMS_MKDN',
                    'MD_' || i_merch_type || '_' || i_season ||
                    '_PCMS_MKDN_i1',
                    'dept,class,chain_id,cluster_group_id,group_no,merch_type,season_code,mdo_uda,mdo_value',
                    'Y') = FALSE THEN
      RAISE program_error;
    END IF;
  
    -- ------------------------------------------
    -- Add parameters
    -- CALCULATE START_DT, END_DATE,
    -- FIND PLAN description
    -- Get correct parameter (most and)  Farah
    -- ------------------------------------------
  
    -- eliminate style colors that will have on order in the next v_on_order_weeks after plan eligibility(last_received + min selling weeeks) for FAB items
    -- CR-132020 Modified to applY DC inventory filter
    IF i_merch_type = 'FAB' THEN
    
      v_merch_type_where := '  where r.pcms_mkdn = ''Y'' OR 
                                                       ( NOT EXISTS (select 1
                                                                       from md_style_colour_oo oo
                                                                      where oo.style = r.style
                                                                        and ( nvl(oo.cluster_group_id, r.cluster_group_id) = r.cluster_group_id 
                                                                              OR 
                                                                              oo.store in (select wh from wh)
                                                                            )
                                                                        and (oo.min_otb_eow_date between r.last_received + r.MIN_SELLING_WEEK
                                                                             and r.last_received + r.MIN_SELLING_WEEK +  decode(r.chain_id,  ' || v_chain_id || ' , '
						                                 || g_v_on_order_weeks * g_num_days ||',' || v_on_order_weeks * g_num_days || ')
                                                                             OR
                                                                             oo.max_otb_eow_date between r.last_received + r.MIN_SELLING_WEEK
                                                                                and r.last_received + r.MIN_SELLING_WEEK + decode(r.chain_id,  ' || v_chain_id || ' , '
						                             || g_v_on_order_weeks * g_num_days ||','||v_on_order_weeks * g_num_days || ')
                                                                            )
                                                                     ) 
                                                         AND NOT EXISTS (SELECT 1   
                                                                           FROM rag_skus_wh rs
                                                                          WHERE rs.style = r.style
                                                                          GROUP BY rs.style HAVING SUM(NVL(rs.stock_on_hand,0)) > '|| v_dc_oh_threshold || '
                                                                         ) 
                                                         AND NOT EXISTS (SELECT 1 
                                                                           FROM packsku ps, rag_skus rs
                                                                          WHERE ps.sku = rs.sku
                                                                            AND rs.style = r.style
                                                                            AND EXISTS (SELECT 1
                                                                                          FROM packwh pw
                                                                                         WHERE pw.pack_no = ps.pack_no
                                                                                         GROUP BY pw.pack_no HAVING SUM(stock_on_hand) > '|| v_dc_oh_threshold || '
                                                                                        )
                                                                         ) 
                                                        ) ';
    -- ----------------------------------------------------------------------------------------
    -- START CR 132023 Should look for On Order no matter if the Plan Eligibility is reached or not
    -- ----------------------------------------------------------------------------------------
    -- CR-132020: Apply DC inventory filter
    ELSIF i_merch_type = 'SEA' THEN
      v_merch_type_where := '  where r.pcms_mkdn = ''Y'' OR 
                                                      (     NOT EXISTS (select 1 
                                                                          from md_style_colour_oo oo
                                                                         where oo.style = r.style
                                                                           and (nvl(oo.cluster_group_id, r.cluster_group_id) = r.cluster_group_id OR oo.store in (select wh from wh))               
                                                                           and (oo.min_otb_eow_date > (r.last_received + r.MIN_SELLING_WEEK)
                                                                            OR  oo.max_otb_eow_date > (r.last_received + r.MIN_SELLING_WEEK))
                                                                        )
                                                        AND NOT EXISTS (SELECT 1   
                                                                          FROM rag_skus_wh rs
                                                                         WHERE rs.style = r.style
                                                                         GROUP BY rs.style HAVING SUM(NVL(rs.stock_on_hand,0)) > '|| v_dc_oh_threshold || '
                                                                        )   
                                                        AND NOT EXISTS (SELECT 1 
                                                                          FROM packsku ps, rag_skus rs
                                                                         WHERE ps.sku = rs.sku
                                                                           AND rs.style = r.style
                                                                           AND EXISTS (SELECT 1
                                                                                         FROM packwh pw
                                                                                        WHERE pw.pack_no = ps.pack_no
                                                                                        GROUP BY pw.pack_no HAVING SUM(stock_on_hand) > '|| v_dc_oh_threshold || '
                                                                                       )
                                                                        )
                                                     ) ';
    -- ----------------------------------------------------------------------------------------
    -- END CR 132023 Should look for On Order no matter if the Plan Eligibility is reached or not
    -- ----------------------------------------------------------------------------------------
    ELSE
      v_merch_type_where := ' where 1=1 or r.pcms_mkdn = ''Y'' ';
    END IF;

BEGIN    
    EXECUTE IMMEDIATE ' CREATE TABLE MD_' || i_merch_type || '_' ||
                      i_season || '_PRM0' || ' tablespace ' || g_tablespace ||
                      '  NOLOGGING as
      select *
              from (SELECT DISTINCT
         p.rank,
         r.style,
         r.colour,
         r.chain_id,
         r.cluster_group_id,
         r.dept,
         r.dept_name,
         r.mdo_value_desc,
         r.CLASS,
         r.class_name,
         r.group_no,
         r.group_name,
         r.merch_type,
         r.merch_type_uda,
         r.merch_type_value,
         r.season_code,
         r.season_uda,
         r.season_value,
         r.mdo_uda,
         r.mdo_value,
         CASE
         WHEN r.MDO_VALUE IS NOT NULL THEN
              r.mdo_value||''-''||r.mdo_value_desc
         ELSE
              r.mdo_value_desc
         END  v_mdo_desc,
        (p.MIN_SELLING_WEEK *' || g_num_days ||
                      ') MIN_SELLING_WEEK,
        ((p.plan_duration_week) *' || g_num_days ||
                      ') plan_duration,
        p.OUTDATE,
        r.first_received,
        r.last_received,
        r.price_change,
        r.pcms_mkdn
          FROM MD_' || i_merch_type || '_' || i_season ||
                      '_PCMS_MKDN r,
               MD_PLAN_PARAMETERS p
         WHERE r.dept = NVL(p.dept,r.dept)
           AND r.CLASS = NVL(p.CLASS,r.CLASS)
           AND r.chain_id = NVL(p.chain_id,r.chain_id)
           AND r.cluster_group_id = NVL(p.cluster_group_id, r.cluster_group_id)
           AND r.group_no = NVL(p.group_no,r.group_no)
           AND r.season_code = NVL(p.season_code,r.season_code)
           AND NVL(r.mdo_uda,0) = NVL(p.mdo_uda,NVL(r.mdo_uda,0))
           AND NVL(r.mdo_value,0) = NVL(p.mdo_value,NVL(r.mdo_value,0))
                 ) r ' || v_merch_type_where;
    DBMS_OUTPUT.PUT_LINE('Created table MD_FAB_WI_PRM0');
    EXCEPTION
        WHEN OTHERS
        THEN
           DBMS_OUTPUT.PUT_LINE('ERROR creating table MD_FAB_WI_PRM0 :: '||SQLERRM);
    END;
   
  
    EXECUTE IMMEDIATE ' CREATE TABLE MD_' || i_merch_type || '_' ||
                      i_season || '_PRM' || ' tablespace ' || g_tablespace ||
                      '  NOLOGGING as
     SELECT DISTINCT
            rank,
            style,
            colour,
            chain_id,
            cluster_group_id,
            dept,
            dept_name,
            mdo_value_desc,
            CLASS,
            class_name,
            group_no,
            group_name,
            merch_type,
            merch_type_uda,
            merch_type_value,
            season_code,
            season_uda,
            season_value,
            mdo_uda,
            mdo_value,
            v_mdo_desc,
            CASE
             WHEN MDO_VALUE IS NULL THEN
                group_no||'' ''||group_name||'' ''||dept||'' ''||dept_name||'' ''||
                CLASS||'' ''||class_name
             WHEN MDO_VALUE IS NOT NULL THEN
               group_no||'' ''||group_name||'' ''||dept||'' ''||dept_name||'' ''||''MLT''||
               '' ''||mdo_value||'' ''||mdo_value_desc
            END MDO_PLAN_DESC,
            MIN_SELLING_WEEK,
            plan_duration,
            OUTDATE,
            START_DATE,
            START_DT,
            CASE
              WHEN merch_type = ''' || v_fab ||
                      ''' THEN
                 LEAST(START_DATE + plan_duration, START_DT + ' ||
                      v_max_plan_length * g_num_days || ')
              WHEN merch_type = ''' || v_psea ||
                      ''' THEN
                 LEAST(OUTDATE, START_DT + ' ||
                      v_max_plan_length * g_num_days || ')
              WHEN merch_type = ''' || v_sea ||
                      ''' AND MOVE_TO_FAB = ''N'' THEN
                 LEAST(OUTDATE, START_DT + ' ||
                      v_max_plan_length * g_num_days || ')
              WHEN merch_type = ''' || v_sea ||
                      ''' AND MOVE_TO_FAB = ''Y'' THEN
                 LEAST(START_DATE + plan_duration, START_DT + ' ||
                      v_max_plan_length * g_num_days || ')
            END END_DATE,
               first_received,
               last_received,
               pcms_mkdn,
               MOVE_TO_FAB
     FROM (
       SELECT DISTINCT
              rank,
              style,
              colour,
              chain_id,
              cluster_group_id,
              dept,
              dept_name,
              mdo_value_desc,
              CLASS,
              class_name,
              group_no,
              group_name,
              merch_type,
              merch_type_uda,
              merch_type_value,
              season_code,
              season_uda,
              season_value,
              mdo_uda,
              mdo_value,
              v_mdo_desc,
              MIN_SELLING_WEEK,
              plan_duration,
              OUTDATE,
              first_received,
              last_received,
              pcms_mkdn,
              START_DATE,
              CASE
              WHEN pcms_mkdn = ''Y'' OR START_DATE <' ||
                      ' TO_DATE( ''' || g_date_chr || ''',''mm/dd/yyyy'')' ||
                      ' THEN
                   TO_DATE( ''' || g_date_chr ||
                      ''',''mm/dd/yyyy'')' || '
              ELSE
                 START_DATE
              END START_DT,
              CASE
              WHEN merch_type = ''' || v_sea ||
                      ''' AND (pcms_mkdn = ''Y'' OR ((OUTDATE - plan_duration)  > first_received AND
                   (OUTDATE - plan_duration)  >= last_received AND
                 LEAST((last_received + MIN_SELLING_WEEK), (OUTDATE - plan_duration)) < (OUTDATE - plan_duration) AND
                 (OUTDATE - plan_duration) > ' ||
                      ' TO_DATE( ''' || g_date_chr ||
                      ''',''mm/dd/yyyy''))) then
                 ''Y''
        ELSE
           ''N''
              END MOVE_TO_FAB
      FROM (
      SELECT DISTINCT
              rank,
              RANK() OVER (PARTITION BY STYLE,COLOUR, CLUSTER_GROUP_ID
                    ORDER BY rank ) PLAN_RANK,
              style,
              colour,
              chain_id,
              cluster_group_id,
              dept,
              dept_name,
              mdo_value_desc,
              CLASS,
              class_name,
              group_no,
              group_name,
              merch_type,
              merch_type_uda,
              merch_type_value,
              season_code,
              season_uda,
              season_value,
              mdo_uda,
              mdo_value,
              v_mdo_desc,
              MIN_SELLING_WEEK,
              plan_duration,
              OUTDATE,
              first_received,
              last_received,
              CASE
              WHEN merch_type = ''' || v_fab ||
                      ''' THEN
                   last_received + MIN_SELLING_WEEK
              WHEN merch_type = ''' || v_psea ||
                      ''' AND
                   (OUTDATE - plan_duration)  >= first_received  THEN
                   OUTDATE - plan_duration
              WHEN merch_type = ''' || v_psea ||
                      ''' AND
                   (OUTDATE - plan_duration)  < first_received  THEN
                   first_received
              WHEN merch_type = ''' || v_sea ||
                      ''' AND (OUTDATE - plan_duration)  > first_received AND
                   (OUTDATE - plan_duration)  >= last_received THEN
                   last_received + MIN_SELLING_WEEK
              WHEN merch_type = ''' || v_sea ||
                      ''' AND (OUTDATE - plan_duration)  < first_received THEN
                   first_received
              END START_DATE,
              pcms_mkdn
        FROM ' || 'MD_' || i_merch_type || '_' ||
                      i_season || '_PRM0' || '
           ) WHERE PLAN_RANK = 1
          ) WHERE pcms_mkdn = ''Y'' OR START_DATE <= ' ||
                      ' TO_DATE( ''' || g_date_chr || ''',''mm/dd/yyyy'')';
  
    -- Check for conflicting cluster and keep only the highest rank
    EXECUTE IMMEDIATE ' CREATE TABLE MD_' || i_merch_type || '_' ||
                      i_season || '_CONF_CLUSTER' || ' tablespace ' ||
                      g_tablespace || '  NOLOGGING as
SELECT DISTINCT p1.style, p1.colour, p1.cluster_group_id
  FROM' || ' MD_' || i_merch_type || '_' || i_season ||
                      '_PRM' || ' p1, ' || 'MD_' || i_merch_type || '_' ||
                      i_season || '_PRM' || ' p2
 WHERE p1.style = p2.style
   AND p1.colour = p2.colour
   AND EXISTS(SELECT 1 from RM_CLUSTER_GROUP_DETAIL g1, RM_CLUSTER_GROUP_DETAIL g2
 WHERE p1.cluster_group_id <> p2.cluster_group_id
   AND p1.cluster_group_id = g1.cluster_group_id
   AND p2.cluster_group_id = g2.cluster_group_id
   AND g1.cluster_value = g2.cluster_value)';
  
    EXECUTE IMMEDIATE 'delete from ' || 'MD_' || i_merch_type || '_' ||
                      i_season || '_PRM p' || ' where (style, colour, cluster_group_id) IN
        (select style, colour, cluster_group_id
           from ' || 'MD_' || i_merch_type || '_' ||
                      i_season || '_CONF_CLUSTER' || ') 
     and rank <> (select min(rank) from ' || 'MD_' ||
                      i_merch_type || '_' || i_season || '_PRM' ||
                      ' where style = p.style and colour = p.colour)';
    COMMIT;
  
    --*******************************************
    -- insert products with MOVE_TO_FAB into a table
    --*******************************************
    EXECUTE IMMEDIATE 'delete from md_import_plan_mem_move_to_fab where merch_type = ' || '''' ||
                      i_merch_type || '''' || ' and season_code = ' || '''' ||
                      i_season || '''';
    COMMIT;
  
    EXECUTE IMMEDIATE 'insert into md_import_plan_mem_move_to_fab(style, colour, merch_type, season_code)
 select distinct style
       ,colour
       ,merch_type
       ,season_code
   from ' || 'MD_' || i_merch_type || '_' || i_season ||
                      '_PRM' || ' where move_to_fab = ''Y''';
  
    COMMIT;
  
    -- ------------------------------------------
    -- Calendar END_DT  Farah
    -- Fiscal date in DATE_YY_MM
    -- TPR 89156  Farah
    -- -----------------------------------------
    EXECUTE IMMEDIATE ' CREATE TABLE MD_' || i_merch_type || '_' ||
                      i_season || '_CAL' || ' tablespace ' || g_tablespace ||
                      '  NOLOGGING as
   SELECT GROUP_NO,END_DATE,END_DT+6 end_dt,WEEK_NO,
          SUBSTR(V_YEAR_NO,3)||
          LPAD(TO_NUMBER(TO_CHAR(TO_DATE(MONTH_IN_YEAR||
          V_YEAR_NO,''MONYYYY''),''MM'')),2,0)||WEEK_NO  DATE_YY_MM
   FROM (
   SELECT AA.GROUP_NO,AA.END_DATE,AA.END_DT,R.WEEK_NO,
          R.MONTH_IN_YEAR,
          CASE
            WHEN R.MONTH_IN_YEAR = ''JAN'' THEN
                R.YEAR_NO +1
            ELSE
               R.YEAR_NO
            END V_YEAR_NO
     FROM (
         SELECT C.GROUP_NO,P.END_DATE,MAX(C.BOW_DATE) END_DT
           FROM MD_' || i_merch_type || '_' ||
                      i_season || '_PRM P,
                rm_mdo_approval_cal C
          WHERE C.GROUP_NO = P.GROUP_NO
            AND C.APP_FLG = 1
            AND C.BOW_DATE <= P.END_DATE
          GROUP BY C.GROUP_NO,P.END_DATE ) AA ,
                rm_mdo_approval_cal R
    WHERE AA.GROUP_NO = R.GROUP_NO
      AND AA.END_DT = R.BOW_DATE
   ) ';
  
    -- -------------------------------------------------------
    -- END_DT
    -- PLan Name
    -- -------------------------------------------------------
    EXECUTE IMMEDIATE ' CREATE TABLE MD_' || i_merch_type || '_' ||
                      i_season || '_NM' || ' tablespace ' || g_tablespace ||
                      '  NOLOGGING as
    SELECT DISTINCT
            rank,
            style,
            colour,
            chain_id,
            cluster_group_id,
            dept,
            mdo_value_desc,
            CLASS,
            group_no,
            merch_type,
            merch_type_uda,
            merch_type_value,
            season_code,
            season_uda,
            season_value,
            mdo_uda,
            mdo_value,
            v_mdo_desc,
            CASE
              WHEN MDO_VALUE IS NULL THEN
               season_code||''-''||dept||''-''||CLASS||''-''||''CL-'' || cluster_group_name||''-''||
               merch_type||''-''||''' || g_date_yy_mm ||
                      '''||''-''||DATE_YY_MM || decode(pcms_mkdn, ''Y'', ''-P'') 
              WHEN MDO_VALUE IS NOT NULL THEN
               season_code||''-''||dept||''-''||''MLT''||''-''||''CL-'' || cluster_group_name||''-''||
               merch_type||''-''||''' || g_date_yy_mm ||
                      '''||''-''||
               DATE_YY_MM||''-''||SUBSTR(v_mdo_desc,1,55) || decode(pcms_mkdn, ''Y'', ''-P'')
            END MDO_PLAN_NM,
            MDO_PLAN_DESC,
            START_DT,
            END_DT,
            pcms_mkdn
     FROM (
     SELECT DISTINCT
            P.rank,
            P.style,
            P.colour,
            P.chain_id,
            P.cluster_group_id,
            ch.cluster_group_name,
            P.dept,
            P.mdo_value_desc,
            P.CLASS,
            P.group_no,
            P.merch_type,
            P.merch_type_uda,
            P.merch_type_value,
            P.season_code,
            P.season_uda,
            P.season_value,
            P.mdo_uda,
            P.mdo_value,
            P.v_mdo_desc,
            P.MDO_PLAN_DESC,
            P.MIN_SELLING_WEEK,
            P.plan_duration,
            P.OUTDATE,
            P.START_DATE,
            P.START_DT,
            P.END_DATE,
            P.first_received,
            P.last_received,
            P.pcms_mkdn,
            C.END_DT,
            C.WEEK_NO,
            C.DATE_YY_MM
       FROM MD_' || i_merch_type || '_' || i_season ||
                      '_PRM P,
            MD_' || i_merch_type || '_' || i_season ||
                      '_CAL C,
            rm_cluster_group_head ch
      where C.GROUP_NO = P.GROUP_NO
        AND C.END_DATE = P.END_DATE
        AND P.cluster_group_id = ch.cluster_group_id
   )
      WHERE END_DT > START_DT ';
  
    -- --------------------------------------------------
    -- LOAD BALANCING
    --G_MAX_STYLE  := 300;
    --G_END_RANGE := 3000000;
    --G_ST_RANGE := 1;
    --G_BUCKET := 3000000/300;
    -- --------------------------------------------------
    EXECUTE IMMEDIATE ' CREATE TABLE MD_' || i_merch_type || '_' ||
                      i_season || '_ALL' || ' tablespace ' || g_tablespace ||
                      '  NOLOGGING as
     SELECT DISTINCT
            row_no,
            width_bucket(row_no,' || g_st_range || ',' ||
                      g_end_range || ',' || g_bucket || ') style_buckets,
            style_cnt,
            style,
            colour,
            chain_id,
            cluster_group_id,
            dept,
            mdo_value_desc,
            CLASS,
            group_no,
            merch_type,
            merch_type_uda,
            merch_type_value,
            season_code,
            season_uda,
            season_value,
            mdo_uda,
            mdo_value,
            MDO_PLAN_NM,
            MDO_PLAN_DESC,
            START_DT,
            END_DT,
            pcms_mkdn
     FROM (
     SELECT row_number() over (PARTITION BY P.MDO_PLAN_NM
                         ORDER BY p.style,P.colour) row_no,
            prod_cnt.style_cnt,
            P.style,
            P.colour,
            P.chain_id,
            P.cluster_group_id,
            P.dept,
            P.mdo_value_desc,
            P.CLASS,
            P.group_no,
            P.merch_type,
            P.merch_type_uda,
            P.merch_type_value,
            P.season_code,
            P.season_uda,
            P.season_value,
            P.mdo_uda,
            P.mdo_value,
            P.v_mdo_desc,
            P.MDO_PLAN_NM,
            P.MDO_PLAN_DESC,
            START_DT,
            P.END_DT,
            P.pcms_mkdn
       FROM MD_' || i_merch_type || '_' || i_season ||
                      '_NM P
            INNER JOIN
            (SELECT COUNT(*) style_cnt, MDO_PLAN_NM
               FROM MD_' || i_merch_type || '_' ||
                      i_season || '_NM
              GROUP BY MDO_PLAN_NM ) PROD_CNT
         ON P.MDO_PLAN_NM = PROD_CNT.MDO_PLAN_NM
   ) ';
  
    RETURN TRUE;
  
  EXCEPTION
    WHEN OTHERS THEN
      IF o_error_message IS NULL THEN
        o_error_message := substr(l_module || ' ' || SQLCODE || ' ' ||
                                  SQLERRM,
                                  1,
                                  2000);
      END IF;
      RETURN FALSE;
  END find_mdo_candidate;
  -- =================================================================
  FUNCTION refresh_plan_execution_string(o_error_message IN OUT VARCHAR2)
    RETURN BOOLEAN IS
  
    CURSOR c_force_markdwn_plans IS
      SELECT mdo_plan_nm,
             allowed_markdn_periods current_execution_string,
             md_get_force_markdown_string(group_no,
                                          start_dt,
                                          end_dt,
                                          force_markdn_week) new_execution_string
        FROM md_import_plan
       WHERE force_markdn_week IS NOT NULL
         AND end_dt > get_vdate
         AND action_cd <> v_plan_remove
         AND status IN ('N', 'S');
  
  BEGIN
  
    FOR rec IN c_force_markdwn_plans LOOP
    
      IF rec.current_execution_string <> rec.new_execution_string THEN
      
        UPDATE md_import_plan
           SET allowed_markdn_periods = rec.new_execution_string,
               status                 = v_new,
               action_cd              = v_update
         WHERE mdo_plan_nm = rec.mdo_plan_nm;
      
        UPDATE md_import_plan_member
           SET status = v_new, action_cd = v_update
         WHERE mdo_plan_nm = rec.mdo_plan_nm
           AND action_cd <> v_plan_remove
           AND status IN ('N', 'S');
      
      END IF;
    
    END LOOP;
  
    RETURN TRUE;
  
  EXCEPTION
    WHEN OTHERS THEN
      o_error_message := substr(SQLCODE || ' ' || SQLERRM, 1, 2000);
      RETURN FALSE;
    
  END refresh_plan_execution_string;
  -- =================================================================

  FUNCTION extract_plan(o_error_message IN OUT VARCHAR2,
                        i_output_path   IN VARCHAR2,
                        i_tab_name      IN VARCHAR2) RETURN BOOLEAN IS
  
    l_module VARCHAR2(64) := 'MD_CRE_PLAN_PKG.EXTRACT_PLAN';
    TYPE l_refcur IS REF CURSOR;
    l_rec      l_refcur;
    l_sql_stmt VARCHAR2(4000);
  
    --Remove plan if all of the members have been removed. Members are removed when product goes back to full price
    CURSOR c_rm_plan IS
      SELECT DISTINCT mdo_plan_nm
        FROM md_import_plan_member m, md_active_status_rm r
       WHERE m.style = r.style
         AND m.colour = r.colour
         AND m.store = r.store
         AND NOT EXISTS (SELECT 1
                FROM md_import_plan_member mb
               WHERE mb.mdo_plan_nm = m.mdo_plan_nm
                 AND action_cd <> v_remove)
      UNION
      SELECT DISTINCT mdo_plan_nm
        FROM md_import_plan_member m, rm_mdo_style_exclude mse
       WHERE m.style = mse.style
         AND NOT EXISTS
       (SELECT 1
                FROM md_stg_geo_prod_curr g, md_import_plan_member pm
               WHERE g.geo_id = pm.geo_id
                 AND g.prod_id = pm.prod_id
                 AND g.status <> 'INACTIVE'
                 AND pm.mdo_plan_nm = m.mdo_plan_nm
                 AND pm.style <> mse.style);
  
    CURSOR c_extract IS
      SELECT DISTINCT col_name,
                      CASE
                        WHEN instr(col_name, 'TO_CHAR') > 0 THEN
                         substr(col_name, 9, (instr(col_name, ',') - 9))
                        ELSE
                         col_name
                      END col_name_f,
                      tab_name,
                      file_name,
                      file_ext,
                      order_by,
                      seq_num,
                      v_where
        FROM md_column_tab_to_file
       WHERE tab_name = i_tab_name
       ORDER BY seq_num;
  
    v_st_time          VARCHAR2(10);
    v_ed_time          VARCHAR2(10);
    v_all_col          VARCHAR2(4000);
    v_col_name         VARCHAR2(4000);
    l_where            VARCHAR2(4000);
    v_output_record    VARCHAR2(4000);
    v_order_by         VARCHAR2(255);
    v_output_fptr      utl_file.file_type;
    v_output_file_name VARCHAR2(100) := NULL;
    l_output_file_name VARCHAR2(100) := NULL;
    v_rec_count        NUMBER := 0;
    v_seq_nm           NUMBER := 0;
    v_file_ext         VARCHAR2(3);
    v_max_row          NUMBER := 500000;
    v_tab_name         VARCHAR2(100);
  BEGIN
    -- --------------------------------
    -- add seq_num to v_output_file_name
    -- ---------------------------------
    SELECT to_char(SYSDATE, 'SSSSS') INTO v_st_time FROM dual;
  
    IF i_tab_name IN ( 'MD_IMPORT_PLAN', 'MD_IMPORT_PLAN_52' ) THEN
      FOR rec IN c_rm_plan LOOP
        UPDATE md_import_plan
           SET action_cd = v_plan_remove, status = v_new
         WHERE mdo_plan_nm = rec.mdo_plan_nm
           AND action_cd <> v_plan_remove
           AND status <> v_complete;
      END LOOP;
    END IF;
  
    COMMIT;
  
    FOR rec IN c_extract LOOP
      IF v_all_col IS NULL THEN
        v_all_col  := rec.col_name;
        v_col_name := rec.col_name_f;
      ELSE
        v_all_col  := v_all_col || '||''|''||';
        v_all_col  := v_all_col || rec.col_name;
        v_col_name := v_col_name || '|';
        v_col_name := v_col_name || rec.col_name_f;
      END IF;
      v_output_file_name := rec.file_name;
      l_output_file_name := rec.file_name || '_' ||
                            to_char(g_date, 'YYYYMMDD') || '.' ||
                            rec.file_ext;
      v_file_ext         := rec.file_ext;
      v_order_by         := rec.order_by;
      l_where            := rec.v_where;
    END LOOP;
  
    IF utl_file.is_open(v_output_fptr) THEN
      utl_file.fclose(v_output_fptr);
    END IF;
  
    v_output_fptr := utl_file.fopen(i_output_path, l_output_file_name, 'W');
  
    utl_file.put_line(v_output_fptr, v_col_name);
  
    IF i_tab_name = 'MD_IMPORT_PLAN_52' THEN
      v_tab_name := substr(i_tab_name, 1, length(i_tab_name) - 3);
    
    ELSE
      v_tab_name := i_tab_name;
    
    END IF;
  
    l_sql_stmt := ' SELECT ' || v_all_col || ' FROM ' || v_tab_name ||
                  ' WHERE ' || l_where || ' ORDER BY ' || v_order_by;
  
    OPEN l_rec FOR l_sql_stmt;
    LOOP
      FETCH l_rec
        INTO v_output_record;
      EXIT WHEN l_rec%NOTFOUND;
      -- No more than 500000 records in the file
      v_rec_count := v_rec_count + 1;
      IF v_rec_count <= v_max_row THEN
        utl_file.put_line(v_output_fptr, v_output_record);
      ELSE
        v_rec_count := 0;
        v_seq_nm    := v_seq_nm + 1;
        IF utl_file.is_open(v_output_fptr) THEN
          utl_file.fclose(v_output_fptr);
        END IF;
        l_output_file_name := v_output_file_name || '_' ||
                              to_char(g_date, 'YYYYMMDD') || '_' ||
                              v_seq_nm || '.' || v_file_ext;
      
        v_output_fptr := utl_file.fopen(i_output_path,
                                        l_output_file_name,
                                        'W');
      
        utl_file.put_line(v_output_fptr, v_col_name);
        utl_file.put_line(v_output_fptr, v_output_record);
      END IF;
    
    END LOOP;
    CLOSE l_rec;
    utl_file.fclose(v_output_fptr);
  
    dbms_output.put_line('Minutes Elapsed : ' ||
                         round((v_ed_time - v_st_time) / 60, 2));
  
    RETURN TRUE;
  EXCEPTION
    WHEN utl_file.invalid_path THEN
      IF utl_file.is_open(v_output_fptr) THEN
        utl_file.fclose(v_output_fptr);
      END IF;
      o_error_message := '-20001,INVALID PATH exception raised';
    WHEN utl_file.invalid_mode THEN
      IF utl_file.is_open(v_output_fptr) THEN
        utl_file.fclose(v_output_fptr);
      END IF;
      o_error_message := '-20002,INVALID_MODE exception raised';
    WHEN utl_file.invalid_filehandle THEN
      IF utl_file.is_open(v_output_fptr) THEN
        utl_file.fclose(v_output_fptr);
      END IF;
      o_error_message := '-20003,INVALID_FILEHANDLE exception raised';
    WHEN utl_file.invalid_operation THEN
      IF utl_file.is_open(v_output_fptr) THEN
        utl_file.fclose(v_output_fptr);
      END IF;
      o_error_message := '-20004,INVALID_OPERATION exception raised';
    WHEN utl_file.read_error THEN
      IF utl_file.is_open(v_output_fptr) THEN
        utl_file.fclose(v_output_fptr);
      END IF;
      o_error_message := '-20005, READ_ERROR exception raised';
    WHEN utl_file.write_error THEN
      IF utl_file.is_open(v_output_fptr) THEN
        utl_file.fclose(v_output_fptr);
      END IF;
      o_error_message := '-20006, WRITE_ERROR exception raised';
    WHEN utl_file.internal_error THEN
      IF utl_file.is_open(v_output_fptr) THEN
        utl_file.fclose(v_output_fptr);
      END IF;
      o_error_message := '-20007,INTERNAL_ERROR exception raised';
    WHEN OTHERS THEN
      IF utl_file.is_open(v_output_fptr) THEN
        utl_file.fclose(v_output_fptr);
      END IF;
    
      IF o_error_message IS NULL THEN
        o_error_message := substr(l_module || ' ' || SQLCODE || ' ' ||
                                  SQLERRM,
                                  1,
                                  2000);
      END IF;
      RETURN FALSE;
  END extract_plan;
  -- ============================================================

  FUNCTION create_index(o_error_message IN OUT VARCHAR2,
                        i_user          IN VARCHAR2,
                        i_tab_name      IN VARCHAR2,
                        i_index         IN VARCHAR2,
                        i_columns       IN VARCHAR2,
                        i_flg           IN VARCHAR2) RETURN BOOLEAN IS
  
    l_module VARCHAR2(64) := 'MD_CRE_PLAN_PKG.CREATE_INDEX';
  BEGIN
    IF i_flg = 'Y' THEN
      EXECUTE IMMEDIATE ' ANALYZE TABLE ' || i_tab_name ||
                        ' ESTIMATE STATISTICS ';
    END IF;
    EXECUTE IMMEDIATE 'create index ' || i_index || ' ON ' || i_tab_name || '(' ||
                      i_columns || ') ';
    dbms_stats.gather_index_stats(i_user, i_index);
  
    RETURN TRUE;
  EXCEPTION
    WHEN OTHERS THEN
      IF o_error_message IS NULL THEN
        o_error_message := substr(l_module || ' ' || SQLCODE || ' ' ||
                                  SQLERRM,
                                  1,
                                  2000);
      END IF;
      RETURN FALSE;
  END create_index;
  -- =========================================================

  FUNCTION get_tablespace(o_error_message IN OUT VARCHAR2) RETURN BOOLEAN IS
  
    l_module VARCHAR2(64) := 'MD_CRE_PLAN_PKG.GET_TABLESPACE';
    CURSOR c_tabspace IS
      SELECT tablespace_name
        FROM all_tables
       WHERE owner = USER
         AND table_name = 'MD_IMPORT_PLAN';
  BEGIN
    -- --------------------------------------
    -- Get the tablespace
    -- ----------------------------------
    FOR rec IN c_tabspace LOOP
      g_tablespace := rec.tablespace_name;
    END LOOP;
  
    RETURN TRUE;
  EXCEPTION
    WHEN OTHERS THEN
      IF o_error_message IS NULL THEN
        o_error_message := substr(l_module || ' ' || SQLCODE || ' ' ||
                                  SQLERRM,
                                  1,
                                  2000);
      END IF;
      RETURN FALSE;
  END get_tablespace;
  -- ==========================================================

  FUNCTION drop_table(o_error_message IN OUT VARCHAR2,
                      i_prefix        IN VARCHAR2) RETURN BOOLEAN IS
  
    l_module VARCHAR2(64) := 'MD_CRE_PLAN_PKG.DROP_TABLE';
    TYPE c_refcur IS REF CURSOR;
    c_rec      c_refcur;
    l_sql_stmt VARCHAR2(4000);
    l_tab      VARCHAR2(30);
  
  BEGIN
    l_sql_stmt := ' SELECT TNAME
                     FROM TAB
                    WHERE TNAME LIKE ''' || i_prefix ||
                  ''' ';
    OPEN c_rec FOR l_sql_stmt;
    LOOP
      FETCH c_rec
        INTO l_tab;
      EXIT WHEN c_rec%NOTFOUND;
      BEGIN
        EXECUTE IMMEDIATE 'DROP TABLE ' || l_tab;
      EXCEPTION
        WHEN OTHERS THEN
          NULL;
      END;
    END LOOP;
    CLOSE c_rec;
    RETURN TRUE;
  EXCEPTION
    WHEN OTHERS THEN
      IF o_error_message IS NULL THEN
        o_error_message := substr(l_module || ' ' || SQLCODE || ' ' ||
                                  SQLERRM,
                                  1,
                                  2000);
      END IF;
      RETURN FALSE;
  END drop_table;
  -- ==========================================================

  FUNCTION insert_mdo_plan(o_error_message IN OUT VARCHAR2,
                           i_tab_name      IN VARCHAR2) RETURN BOOLEAN IS
  
    l_module VARCHAR2(64) := 'MD_CRE_PLAN_PKG.INSERT_MDO_PLAN';
  
  BEGIN
    EXECUTE IMMEDIATE 'INSERT INTO MD_IMPORT_PLAN (MDO_PLAN_NM,
                                    MDO_PLAN_DESC,
                                    AUTO_EVAL_OPT_FLG,
                                    MERCH_TYPE,
                                    SEASON_CODE,
                                    DEPT,
                                    CLASS,
                                    GROUP_NO,
                                    MDO_UDA,
                                    MDO_VALUE,
                                    START_DT,
                                    END_DT,
                                    OBJECTIVE_CD,
                                    DECISION_GEO_LVL,
                                    DECISION_PROD_LVL,
                                    TARGET_INV_VALUE_TYPE,
                                    TARGET_INV_VALUE,
                                    INV_POOL_LVL_CD,
                                    SALVAGE_VALUE_TYPE,
                                    SALVAGE_VALUE,
                                    MAX_MARKDN_NUM,
                                    MIN_PERIODS_BETWEEN_MARKDN,
                                    MAX_DISC_PCT_OFF_REG_PRICE,
                                    MIN_DISC_PCT_FOR_INIT_MARKDN,
                                    MIN_DISC_PCT_FOR_NEXT_MARKDN,
                                    MAX_DISC_PCT_FOR_SINGLE_MARKDN,
                                    MARKDN_COST_AMT,
                                    MARKDN_UNIT_COST_AMT,
                                    ALLOWED_MARKDN_PERIODS,
                                    PRICE_VALUE_TYPE,
                                    PRICE_VALUE_LIST,
                                    PRICE_ENDING_LIST,
                                    FINAL_DISC_VALUE_TYPE,
                                    FINAL_DISC_VALUE,
                                    SELL_THROUGH_TYPE,
                                    PLAN_STATUS_CD,
                                    ACTIVE_PLAN_NM,
                                    ACTION_CD,
                                    STATUS,
                                    SOURCE,
                                    UPDATE_DT,
                                    FORCE_MARKDN_WEEK,
                                     --CR 124654 mdo upgrade 5.2
            geo_hier_assoc_cd  ,            
            prod_hier_assoc_cd  ,           
            inv_pool_prod_lvl    ,          
            inv_pool_geo_lvl      ,         
            max_future_markdn_num  ,        
            max_disc_pct_for_init_markdn,   
            max_disc_pct_for_next_markdn ,  
            force_markdn_min_depth_value  , 
            low_baseline_demand_disc_value ,
            scheduling_tag                 ,
            uniform_timing_num_markdn      ,
            uniform_timing_prod_lvl        ,
            uniform_timing_geo_lvl         ,
            allow_markdn_during_promo_cd   ,
            multi_obj_inv_weight           ,
            allow_markdn_below_cost_cd     ,
            allow_markdn_below_cost_prds)
      SELECT DISTINCT 
             SUBSTR(MDO_PLAN_NM,1, 100),
             SUBSTR(MDO_PLAN_DESC,1,100),
             AUTO_EVAL_OPT_FLG,
             MERCH_TYPE,
             SEASON_CODE,
             DEPT,
             CLASS,
             GROUP_NO,
             MDO_UDA,
             MDO_VALUE,
             START_DT,
             END_DT,
             OBJECTIVE_CD,
             DECISION_GEO_LVL,
             DECISION_PROD_LVL,
             TARGET_INV_VALUE_TYPE,
             TARGET_INV_VALUE,
             INV_POOL_LVL_CD,
             SALVAGE_VALUE_TYPE,
             SALVAGE_VALUE,
             MAX_MARKDN_NUM,
             MIN_PERIODS_BETWEEN_MARKDN,
             MAX_DISC_PCT_OFF_REG_PRICE,
             MIN_DISC_PCT_FOR_INIT_MARKDN,
             MIN_DISC_PCT_FOR_NEXT_MARKDN,
             MAX_DISC_PCT_FOR_SINGLE_MARKDN,
             MARKDN_COST_AMT,
             MARKDN_UNIT_COST_AMT,
             ALLOWED_MARKDN_PERIODS,
             PRICE_VALUE_TYPE,
             PRICE_VALUE_LIST,
             PRICE_ENDING_LIST,
             FINAL_DISC_VALUE_TYPE,
             FINAL_DISC_VALUE,
             SELL_THROUGH_TYPE,
             PLAN_STATUS_CD,
             ACTIVE_PLAN_NM,1 ACTION_CD,
             ''N'' STATUS,''RMS'' SOURCE,''' || g_date ||
                      ''' UPDATE_DT,
             FORCE_MARKDN_WEEK,
              --CR 124654 mdo upgrade 5.2
            geo_hier_assoc_cd  ,            
            prod_hier_assoc_cd  ,           
            inv_pool_prod_lvl    ,          
            inv_pool_geo_lvl      ,         
            max_future_markdn_num  ,        
            max_disc_pct_for_init_markdn,   
            max_disc_pct_for_next_markdn ,  
            force_markdn_min_depth_value  , 
            low_baseline_demand_disc_value ,
            scheduling_tag                 ,
            uniform_timing_num_markdn      ,
            uniform_timing_prod_lvl        ,
            uniform_timing_geo_lvl         ,
            allow_markdn_during_promo_cd   ,
            multi_obj_inv_weight           ,
            allow_markdn_below_cost_cd     ,
            allow_markdn_below_cost_prds
        FROM ' || i_tab_name;
    COMMIT;
  
    RETURN TRUE;
  EXCEPTION
    WHEN OTHERS THEN
      IF o_error_message IS NULL THEN
        o_error_message := substr(l_module || ' ' || SQLCODE || ' ' ||
                                  SQLERRM,
                                  1,
                                  2000);
      END IF;
      RETURN FALSE;
  END insert_mdo_plan;
  -- ============================================================

  FUNCTION insert_mdo_plan_mem(o_error_message IN OUT VARCHAR2,
                               i_tab_name      IN VARCHAR2) RETURN BOOLEAN IS
  
    l_module               VARCHAR2(64) := 'MD_CRE_PLAN_PKG.INSERT_MDO_PLAN_MEM';
    l_null_obj             VARCHAR2(1) := '!'; -- CR-118541
    l_clearance_store_flag VARCHAR2(1) := 'Y'; -- CR-118541
  
  BEGIN
    -- CR-118541 below store_attributes join made to avoided clearance store data to MDO plan members 
    EXECUTE IMMEDIATE 'INSERT INTO MD_IMPORT_PLAN_MEMBER (MDO_PLAN_NM,
             GEO_ID,
             PROD_ID,
             STYLE,
             COLOUR,
             STORE,
             ACTION_CD,
             STATUS,
             CLUSTER_GROUP_ID )
       SELECT DISTINCT MDO.MDO_PLAN_NM,
        MDO.GEO_ID,
        MDO.PROD_ID,
        MDO.STYLE,
        MDO.COLOUR,
        MDO.STORE,
        1 ACTION_ID,
        ''N'' STATUS,
        MDO.CLUSTER_GROUP_ID
        FROM ' || i_tab_name || ' MDO';
  
    COMMIT;
  
    RETURN TRUE;
  
  EXCEPTION
    WHEN OTHERS THEN
      IF o_error_message IS NULL THEN
        o_error_message := substr(l_module || ' ' || SQLCODE || ' ' ||
                                  SQLERRM,
                                  1,
                                  2000);
      END IF;
    
      RETURN FALSE;
  END insert_mdo_plan_mem;
  -- ======================================================

  --**** Public
  FUNCTION delete_full_price_member(o_error_message IN OUT VARCHAR2)
    RETURN BOOLEAN IS
  
    l_module VARCHAR2(64) := 'MD_CRE_PLAN_PKG.DELETE_FULL_PRICE_MEMBER';
  
  BEGIN
    IF drop_table(o_error_message, 'MD_PLN_GEO_FULL_STATUS') = FALSE THEN
      RAISE program_error;
    END IF;
    IF get_tablespace(o_error_message) = FALSE THEN
      RAISE program_error;
    END IF;
    IF set_date(o_error_message) = FALSE THEN
      RAISE program_error;
    END IF;
    -- --------------------------------
    -- Update status to completed (C)
    -- --------------------------------
    IF update_plan_status_compl(o_error_message) = FALSE THEN
      RAISE program_error;
    END IF;
    -- --------------------------------------
    -- Purge expired records from plan tables
    -- ---------------------------------------
    IF purge_mdo_plan(o_error_message) = FALSE THEN
      RAISE program_error;
    END IF;
    -- --------------------------------------
    -- Find full ticket C --> A
    -- --------------------------------------
    EXECUTE IMMEDIATE 'CREATE TABLE MD_PLN_GEO_FULL_STATUS' ||
                      ' tablespace ' || g_tablespace ||
                      '  NOLOGGING as
       SELECT geo_id,prod_id,style,colour,STORE,
              old_status,new_status
        FROM(
       SELECT DISTINCT geo_id,prod_id,style,colour,STORE,
              NVL(SUM(
              CASE
                WHEN old_status = ''' || active ||
                      ''' THEN
                  ' || active_no || '
                WHEN old_status = ''' || clearance ||
                      ''' THEN
                   ' || clearance_no || '
                END ),0) old_status ,
             NVL(SUM(
              CASE
                WHEN new_status = ''' || active ||
                      '''THEN
                  ' || active_no || '
                WHEN new_status = ''' || clearance ||
                      ''' THEN
                  ' || clearance_no || '
                END ),0) new_status
         FROM (
       SELECT geo_id,
              prod_id,
              style,
              colour,
              loc STORE,
              status old_status,
              NULL new_status
        FROM MD_STG_GEO_PROD_PREV
       WHERE status IN (''' || active || ''',''' ||
                      clearance || ''')
       UNION ALL
       SELECT geo_id,
              prod_id,
              style,
              colour,
              loc STORE,
              NULL old_status,
              status new_status
         FROM MD_STG_GEO_PROD_CURR
        WHERE status IN (''' || active || ''',''' ||
                      clearance || ''')
     )
        GROUP BY geo_id,prod_id,style,colour,STORE
     )  WHERE NEW_STATUS < OLD_STATUS ';
    -- ---------------------------------------------
    -- Delete records from temp table if exist in
    -- md_active_status_rm table
    -- ----------------------------------------------
    EXECUTE IMMEDIATE ' DELETE FROM MD_PLN_GEO_FULL_STATUS
           WHERE (STYLE,COLOUR,STORE)
              IN (SELECT STYLE,COLOUR,STORE
                    FROM MD_ACTIVE_STATUS_RM) ';
    COMMIT;
  
    -- ---------------------------------------------------
    -- Insert the records to active status table for lookup
    -- Farah
    -- -----------------------------------------------------
  
    EXECUTE IMMEDIATE ' INSERT INTO md_active_status_rm (GEO_ID,PROD_ID,STYLE,
                                         COLOUR,STORE,END_DT,
                                         UPDATE_DT)
      SELECT M.GEO_ID,M.PROD_ID,M.STYLE,
             M.COLOUR,M.STORE,P.END_DT,
             TO_DATE(''' || g_date_chr ||
                      ''',''MM/DD/YYYY'')
        FROM MD_IMPORT_PLAN_MEMBER M,
             MD_IMPORT_PLAN P,
             MD_PLN_GEO_FULL_STATUS G
       WHERE G.STYLE = M.STYLE
         AND G.COLOUR = M.COLOUR
         AND G.STORE = M.STORE
         AND M.MDO_PLAN_NM  = P.MDO_PLAN_NM
         AND M.STATUS = ''' || v_send || ''' ';
    COMMIT;
  
    -- ------------------------------------------------------
    -- Update action_cd to remove (2)
    -- Farah
    -- -----------------------------------------------------
    EXECUTE IMMEDIATE ' UPDATE md_import_plan_member
        SET ACTION_CD = ' || v_remove || ',
            STATUS = ''' || v_new || '''
       WHERE (STYLE,COLOUR,STORE)
          IN (SELECT RM.STYLE,RM.COLOUR,RM.STORE
                FROM MD_ACTIVE_STATUS_RM rm,
                     MD_IMPORT_PLAN_MEMBER m,
                     MD_IMPORT_PLAN p
               WHERE m.style = rm.style
                 AND m.colour = rm.colour
                 AND m.store = rm.store
                 AND m.mdo_plan_nm = p.mdo_plan_nm
                 AND m.action_cd <> ''' || v_remove || '''
                 AND p.status <> ''' || v_complete ||
                      ''' )';
    COMMIT;
  
    IF delete_excluded_member(o_error_message) = FALSE THEN
      RAISE program_error;
    END IF;
  
    RETURN TRUE;
  EXCEPTION
    WHEN OTHERS THEN
      IF o_error_message IS NULL THEN
        o_error_message := substr(l_module || ' ' || SQLCODE || ' ' ||
                                  SQLERRM,
                                  1,
                                  2000);
      END IF;
      RETURN FALSE;
  END delete_full_price_member;
  -- ==========================================================
  -- ------------------------------------------------------
  -- Delete style color that are set for exclusion
  -- -----------------------------------------------------
  FUNCTION delete_excluded_member(o_error_message IN OUT VARCHAR2)
    RETURN BOOLEAN IS
  
    l_module VARCHAR2(64) := 'MD_CRE_PLAN_PKG.DELETE_EXCLUDED_MEMBER';
    -- CR-118541 - added "or" condition to Mark Clearance stores status = 'DELETED - 2' in MDO_IMPORT_PLAN_MEMBER.
    -- for Clearance stores.   
  BEGIN
    EXECUTE IMMEDIATE ' UPDATE md_import_plan_member pm
        SET ACTION_CD = ' || v_remove || ',
            STATUS = ''' || v_new || '''
    WHERE (((pm.style) IN (SELECT m.style
                          FROM md_import_plan_member m
                              ,md_import_plan        p
                              ,rm_mdo_style_exclude  rme
                         WHERE rme.style = m.style
                           AND m.mdo_plan_nm = p.mdo_plan_nm
                           AND m.action_cd <> ''' ||
                      v_remove || '''
                 AND p.status <> ''' || v_complete || ''')
         AND EXISTS ( SELECT 1
                FROM md_import_plan_member m
                  ,md_stg_geo_prod_curr  c
                 WHERE m.geo_id = c.geo_id
                 AND m.prod_id = c.prod_id
                 AND c.status <> ''INACTIVE''
                 AND m.mdo_plan_nm = pm.mdo_plan_nm
                 AND m.style <> pm.style)
        ) OR ( pm.store IN (SELECT store
                       FROM store_attributes
                       WHERE nvl(clearance_store, ''N'') = ''Y'')
             AND action_cd <> ' || v_remove ||
                      ' and STATUS <> ''' || v_complete || ''')
        )';
    RETURN TRUE;
  EXCEPTION
    WHEN OTHERS THEN
      IF o_error_message IS NULL THEN
        o_error_message := substr(l_module || ' ' || SQLCODE || ' ' ||
                                  SQLERRM,
                                  1,
                                  2000);
      END IF;
      RETURN FALSE;
  END delete_excluded_member;
  -- ==========================================================
  FUNCTION update_mdo_plan_status(o_error_message IN OUT VARCHAR2,
                                  i_tab_name      IN VARCHAR2) RETURN BOOLEAN IS
  
    l_module VARCHAR2(64) := 'MD_CRE_PLAN_PKG.UPDATE_MDO_PLAN_STATUS';
  
    TYPE rowid_type IS TABLE OF ROWID INDEX BY BINARY_INTEGER;
    TYPE up_ref_cursor IS REF CURSOR;
  
    l_status_rec up_ref_cursor;
    l_sqlstmt    VARCHAR2(4000);
    l_rowid      rowid_type;
  
  BEGIN
    l_sqlstmt := 'SELECT rowid
                   FROM ' || i_tab_name || '
                  WHERE status = ''' || v_new || ''' ';
  
    OPEN l_status_rec FOR l_sqlstmt;
    LOOP
      FETCH l_status_rec BULK COLLECT
        INTO l_rowid LIMIT 3000;
      EXIT WHEN l_rowid.count = 0;
    
      FORALL indx IN l_rowid.first .. l_rowid.last EXECUTE IMMEDIATE
                                      ' UPDATE ' || i_tab_name || '
                SET STATUS = ''' ||
                                      v_send || '''
              WHERE ROWID = :P_ROWID '
                                      USING l_rowid(indx)
        ;
    
      COMMIT;
    
    END LOOP;
    CLOSE l_status_rec;
  
    RETURN TRUE;
  EXCEPTION
    WHEN OTHERS THEN
      IF o_error_message IS NULL THEN
        o_error_message := substr(l_module || ' ' || SQLCODE || ' ' ||
                                  SQLERRM,
                                  1,
                                  2000);
      END IF;
      RETURN FALSE;
  END update_mdo_plan_status;
  -- ====================================================

  FUNCTION update_plan_status_compl(o_error_message IN OUT VARCHAR2)
    RETURN BOOLEAN IS
    l_module VARCHAR2(64) := 'MD_CRE_PLAN_PKG.UPDATE_PLAN_STATUS_COMPL';
  
  BEGIN
    UPDATE md_import_plan
       SET status = v_complete, update_dt = g_date
     WHERE end_dt < to_date(g_date_chr, 'MM/DD/YYYY');
    COMMIT;
  
    UPDATE md_import_plan_member
       SET status = v_complete
     WHERE mdo_plan_nm IN
           (SELECT mdo_plan_nm FROM md_import_plan WHERE status = 'C')
       AND status != v_complete;
    COMMIT;
  
    RETURN TRUE;
  EXCEPTION
    WHEN OTHERS THEN
      IF o_error_message IS NULL THEN
        o_error_message := substr(l_module || ' ' || SQLCODE || ' ' ||
                                  SQLERRM,
                                  1,
                                  2000);
      END IF;
      RETURN FALSE;
  END update_plan_status_compl;
  -- ======================================================

  FUNCTION purge_mdo_plan(o_error_message IN OUT VARCHAR2) RETURN BOOLEAN IS
  
    l_module VARCHAR2(64) := 'MD_CRE_PLAN_PKG.PURGE_MDO_PLAN';
    l_purge  NUMBER := 45;
  
  BEGIN
    IF drop_table(o_error_message, 'MD_PLN_PURGE_PLAN') = FALSE THEN
      RAISE program_error;
    END IF;
    IF drop_table(o_error_message, 'MD_PLN_PURGE_PLAN_PRG') = FALSE THEN
      RAISE program_error;
    END IF;
    EXECUTE IMMEDIATE ' CREATE TABLE MD_PLN_PURGE_PLAN ' || ' tablespace ' ||
                      g_tablespace || '  NOLOGGING as
      SELECT MDO_PLAN_NM
        FROM MD_IMPORT_PLAN
       WHERE END_DT + ' || purge_day || ' < ' ||
                      ' TO_DATE(''' || g_date_chr ||
                      ''',''MM/DD/YYYY'')
         AND STATUS = ''' || v_complete || ''' ';
  
    EXECUTE IMMEDIATE 'INSERT INTO md_import_plan_member_PRG(
                     GEO_ID,PROD_ID,
                     MDO_PLAN_NM,
                     STYLE,COLOUR,STORE,
                     ACTION_CD,STATUS  )
              SELECT R.GEO_ID,R.PROD_ID,
                     R.MDO_PLAN_NM,
                     R.STYLE,R.COLOUR,R.STORE,
                     R.ACTION_CD,R.STATUS
                FROM MD_IMPORT_PLAN_MEMBER R,
                     MD_PLN_PURGE_PLAN P
               WHERE R.MDO_PLAN_NM = P.MDO_PLAN_NM ';
    COMMIT;
  
    EXECUTE IMMEDIATE ' DELETE FROM md_import_plan_member
         WHERE MDO_PLAN_NM IN (SELECT MDO_PLAN_NM
                                 FROM MD_PLN_PURGE_PLAN) ';
    COMMIT;
    EXECUTE IMMEDIATE 'INSERT INTO md_import_plan_PRG(
                    MDO_PLAN_NM,MDO_PLAN_DESC,
                    MERCH_TYPE,SEASON_CODE,
                    DEPT,CLASS,GROUP_NO,MDO_UDA,
                    MDO_VALUE,START_DT,END_DT,
                    ACTION_CD,STATUS,SOURCE )
             SELECT R.MDO_PLAN_NM,R.MDO_PLAN_DESC,
                    R.MERCH_TYPE,R.SEASON_CODE,
                    R.DEPT,R.CLASS,R.GROUP_NO,R.MDO_UDA,
                    R.MDO_VALUE,R.START_DT,R.END_DT,
                    R.ACTION_CD,R.STATUS,R.SOURCE
               FROM MD_IMPORT_PLAN R,
                    MD_PLN_PURGE_PLAN P
               WHERE R.MDO_PLAN_NM = P.MDO_PLAN_NM ';
    COMMIT;
  
    EXECUTE IMMEDIATE ' DELETE FROM md_import_plan
         WHERE MDO_PLAN_NM IN (SELECT MDO_PLAN_NM
                                 FROM MD_PLN_PURGE_PLAN) ';
    COMMIT;
  
    EXECUTE IMMEDIATE 'DELETE FROM md_active_status_rm
    WHERE (GEO_ID,PROD_ID) IN (SELECT GEO_ID,PROD_ID
                                 FROM MD_IMPORT_PLAN_MEMBER_PRG
                                WHERE STATUS = ''' ||
                      v_complete || ''') ';
    COMMIT;
  
    EXECUTE IMMEDIATE ' CREATE TABLE MD_PLN_PURGE_PLAN_PRG ' ||
                      ' tablespace ' || g_tablespace ||
                      '  NOLOGGING as
      SELECT MDO_PLAN_NM
        FROM MD_IMPORT_PLAN_PRG
       WHERE END_DT + ' || l_purge || ' <= ' ||
                      ' TO_DATE(''' || g_date_chr || ''',''MM/DD/YYYY'') ';
  
    EXECUTE IMMEDIATE ' DELETE FROM md_import_plan_prg
         WHERE MDO_PLAN_NM IN (SELECT MDO_PLAN_NM
                                 FROM MD_PLN_PURGE_PLAN_PRG) ';
    COMMIT;
  
    EXECUTE IMMEDIATE ' DELETE FROM md_import_plan_member_prg
         WHERE MDO_PLAN_NM IN (SELECT MDO_PLAN_NM
                                 FROM MD_PLN_PURGE_PLAN_PRG) ';
    COMMIT;
  
    RETURN TRUE;
  EXCEPTION
    WHEN OTHERS THEN
      IF o_error_message IS NULL THEN
        o_error_message := substr(l_module || ' ' || SQLCODE || ' ' ||
                                  SQLERRM,
                                  1,
                                  2000);
      END IF;
      RETURN FALSE;
  END purge_mdo_plan;
  -- ===========================================================

  FUNCTION brk_mdo_plan(o_error_message IN OUT VARCHAR2,
                        i_tab_name      IN VARCHAR2,
                        o_tab_name      IN VARCHAR2) RETURN BOOLEAN IS
  
    l_module VARCHAR2(64) := 'MD_CRE_PLAN_PKG.BRK_MDO_PLAN';
  BEGIN
    -- -----------------------------------------
    -- Get the GEO_ID for given prod_id  Farah
    -- ----------------------------------------
    EXECUTE IMMEDIATE ' CREATE TABLE ' || o_tab_name || '_1
       TABLESPACE ' || g_tablespace || '  NOLOGGING AS
     SELECT DISTINCT r.row_no,
            r.style_buckets,
            r.style_cnt,
            r.style,
            r.colour,
            r.chain_id,
            r.cluster_group_id,
            r.dept,
            r.mdo_value_desc,
            r.CLASS,
            r.group_no,
            r.merch_type,
            r.merch_type_uda,
            r.merch_type_value,
            r.season_code,
            r.season_uda,
            r.season_value,
            r.mdo_uda,
            r.mdo_value,
            r.MDO_PLAN_NM  MDO_PLAN_NM_F,
            r.MDO_PLAN_DESC,
            r.START_DT,
            r.END_DT,
            r.pcms_mkdn,
            M.GEO_ID,
            M.STORE,
            M.PROD_ID
       FROM ' || i_tab_name || ' R,
            MD_PLN_NEW_GEO_PROD M, RM_STORE_CLUSTER sc, RM_CLUSTER_GROUP_DETAIL gd
      WHERE r.style = m.style
        AND r.colour = m.colour 
        AND r.cluster_group_id = gd.cluster_group_id
        AND sc.store = m.store
        AND sc.cluster_value = gd.cluster_value ';
  
    -- ---------------------------------------=----------------
    -- Break the MDO plan if exceed the max allowed records Farah
    -- prod 1000
    -- prod-geo 150000
    -- ---------------------------------------------------------
    EXECUTE IMMEDIATE ' CREATE TABLE ' || o_tab_name || ' tablespace ' ||
                      g_tablespace || '  NOLOGGING as
     SELECT DISTINCT row_no,
            style_buckets,
            style_cnt,
            store_cnt,
            style,
            colour,
            chain_id,
            cluster_group_id,
            dept,
            mdo_value_desc,
            CLASS,
            group_no,
            merch_type,
            merch_type_uda,
            merch_type_value,
            season_code,
            season_uda,
            season_value,
            mdo_uda,
            mdo_value,
            MDO_PLAN_NM_F,
            MDO_PLAN_DESC,
            CASE
              WHEN STYLE_CNT <' || g_prod_num ||
                      ' AND
                   STORE_CNT <' || g_geo_prod_num ||
                      ' THEN
                   MDO_PLAN_NM_F
              WHEN style_cnt > ' || g_max_style ||
                      ' THEN
                   MDO_PLAN_NM_F||''_''||LPAD(style_buckets,2)
            END MDO_PLAN_NM,
            START_DT,
            END_DT,
            pcms_mkdn,
            GEO_ID,
            STORE,
            PROD_ID
   FROM(
     SELECT DISTINCT r.row_no,
            r.style_buckets,
            r.style_cnt,
            r.style,
            r.colour,
            r.chain_id,
            r.cluster_group_id,
            r.dept,
            mdo_value_desc,
            r.CLASS,
            group_no,
            r.merch_type,
            r.merch_type_uda,
            r.merch_type_value,
            r.season_code,
            r.season_uda,
            r.season_value,
            r.mdo_uda,
            r.mdo_value,
            r.MDO_PLAN_NM_F,
            r.MDO_PLAN_DESC,
            r.START_DT,
            r.END_DT,
            r.pcms_mkdn,
            r.GEO_ID,
            r.STORE,
            r.PROD_ID,
            geo_cnt.store_cnt
       FROM ' || o_tab_name || '_1 R
            INNER JOIN
            (SELECT COUNT(*) store_cnt, MDO_PLAN_NM_F
               FROM ' || o_tab_name || '_1
              GROUP BY MDO_PLAN_NM_F ) GEO_CNT
         ON R.MDO_PLAN_NM_F = GEO_CNT.MDO_PLAN_NM_F
   ) ';
  
    RETURN TRUE;
  EXCEPTION
    WHEN OTHERS THEN
      IF o_error_message IS NULL THEN
        o_error_message := substr(l_module || ' ' || SQLCODE || ' ' ||
                                  SQLERRM,
                                  1,
                                  2000);
      END IF;
      RETURN FALSE;
  END brk_mdo_plan;
  -- ======================================================

  FUNCTION override_plan(o_error_message IN OUT VARCHAR2,
                         i_tab_name      IN VARCHAR2,
                         o_tab_name      IN VARCHAR2) RETURN BOOLEAN IS
  
    l_module                VARCHAR2(64) := 'MD_CRE_PLAN_PKG.OVERRIDE_PLAN';
    v_recommend_delay_weeks NUMBER;
  
  BEGIN
  
    -- get no of weeks MDO to delay recommendation for plans with PCMS markdown    
    BEGIN
      SELECT numeric_value
        INTO v_recommend_delay_weeks
        FROM rm_system_globals
       WHERE variable_name = 'MDO_RECOMMEND_DELAY_WEEKS_PCMS';
    
    EXCEPTION
      WHEN OTHERS THEN
        o_error_message := 'variable RM_SYSTEM_GLOBALS.MDO_RECOMMEND_DELAY_WEEKS_PCMS not defined. error in procedure FIND_MDO_CANDIDATE.';
        RAISE program_error;
    END;
  
    -- ----------------------------------------------
    -- Get override parameters (most and) Farah
    -- ----------------------------------------------
    EXECUTE IMMEDIATE ' CREATE TABLE ' || o_tab_name || ' tablespace ' ||
                      g_tablespace || '  NOLOGGING as
    SELECT rank,RANK_COUNT,
            chain_id,
            cluster_group_id,
            dept,
            CLASS,
            group_no,
            merch_type,
            season_code,
            mdo_uda,
            mdo_value,
            MDO_PLAN_NM,
            MDO_PLAN_DESC,
            START_DT,
            END_DT,
            PCMS_MKDN,
            AUTO_EVAL_OPT_FLG,
            OBJECTIVE_CD,
            DECISION_GEO_LVL,
            DECISION_PROD_LVL,
            TARGET_INV_VALUE_TYPE,
            TARGET_INV_VALUE,
            INV_POOL_LVL_CD,
            SALVAGE_VALUE_TYPE,
            SALVAGE_VALUE,
            MAX_MARKDN_NUM,
            MIN_PERIODS_BETWEEN_MARKDN,
            MAX_DISC_PCT_OFF_REG_PRICE,
            MIN_DISC_PCT_FOR_INIT_MARKDN,
            MIN_DISC_PCT_FOR_NEXT_MARKDN,
            MAX_DISC_PCT_FOR_SINGLE_MARKDN,
            MARKDN_COST_AMT,
            MARKDN_UNIT_COST_AMT,
            ALLOWED_MARKDN_PERIODS,
            PRICE_VALUE_TYPE,
            PRICE_VALUE_LIST,
            PRICE_ENDING_LIST,
            FINAL_DISC_VALUE_TYPE,
            FINAL_DISC_VALUE,
            SELL_THROUGH_TYPE,
            PLAN_STATUS_CD,
            ACTIVE_PLAN_NM,
            FORCE_MARKDN_WEEK,
               --CR 124654 mdo upgrade 5.2
            geo_hier_assoc_cd  ,            
            prod_hier_assoc_cd  ,           
            inv_pool_prod_lvl    ,          
            inv_pool_geo_lvl      ,         
            max_future_markdn_num  ,        
            max_disc_pct_for_init_markdn,   
            max_disc_pct_for_next_markdn ,  
            force_markdn_min_depth_value  , 
            low_baseline_demand_disc_value ,
            scheduling_tag                 ,
            uniform_timing_num_markdn      ,
            uniform_timing_prod_lvl        ,
            uniform_timing_geo_lvl         ,
            allow_markdn_during_promo_cd   ,
            multi_obj_inv_weight           ,
            allow_markdn_below_cost_cd     ,
            allow_markdn_below_cost_prds
  
   FROM (
            SELECT DISTINCT
            p.rank,
            CC.RANK_COUNT,
            R.chain_id,
            R.cluster_group_id,
            R.dept,
            R.CLASS,
            R.group_no,
            R.merch_type,
            R.season_code,
            R.mdo_uda,
            R.mdo_value,
            R.MDO_PLAN_NM,
            R.MDO_PLAN_DESC,
            R.START_DT,
            R.END_DT,
            R.pcms_mkdn,
            p.AUTO_EVAL_OPT_FLG,
            p.OBJECTIVE_CD,
            p.DECISION_GEO_LVL,
            p.DECISION_PROD_LVL,
            p.TARGET_INV_VALUE_TYPE,
            p.TARGET_INV_VALUE,
            p.INV_POOL_LVL_CD,
            p.SALVAGE_VALUE_TYPE,
            p.SALVAGE_VALUE,
            p.MAX_MARKDN_NUM,
            p.MIN_PERIODS_BETWEEN_MARKDN,
            p.MAX_DISC_PCT_OFF_REG_PRICE,
            p.MIN_DISC_PCT_FOR_INIT_MARKDN,
            p.MIN_DISC_PCT_FOR_NEXT_MARKDN,
            p.MAX_DISC_PCT_FOR_SINGLE_MARKDN,
            p.MARKDN_COST_AMT,
            p.MARKDN_UNIT_COST_AMT,
            p.ALLOWED_MARKDN_PERIODS,
            p.PRICE_VALUE_TYPE,
            p.PRICE_VALUE_LIST,
            p.PRICE_ENDING_LIST,
            p.FINAL_DISC_VALUE_TYPE,
            p.FINAL_DISC_VALUE,
            ' || g_sell_through_type || ' SELL_THROUGH_TYPE,
            p.PLAN_STATUS_CD,
            p.ACTIVE_PLAN_NM,
            p.FORCE_MARKDN_WEEK,
             --CR 124654 mdo upgrade 5.2
            p.geo_hier_assoc_cd  ,            
            p.prod_hier_assoc_cd  ,           
            p.inv_pool_prod_lvl    ,          
            p.inv_pool_geo_lvl      ,         
            p.max_future_markdn_num  ,        
            p.max_disc_pct_for_init_markdn,   
            p.max_disc_pct_for_next_markdn ,  
            p.force_markdn_min_depth_value  , 
            p.low_baseline_demand_disc_value ,
            p.scheduling_tag                 ,
            p.uniform_timing_num_markdn      ,
            p.uniform_timing_prod_lvl        ,
            p.uniform_timing_geo_lvl         ,
            p.allow_markdn_during_promo_cd   ,
            p.multi_obj_inv_weight           ,
            p.allow_markdn_below_cost_cd     ,
            p.allow_markdn_below_cost_prds
       FROM  ' || i_tab_name || '  R,
             (SELECT DISTINCT rank_count, MDO_PLAN_NM,
                    RANK() OVER (PARTITION BY MDO_PLAN_NM
                    ORDER BY rank_count ) PLAN_RANK
               FROM (
             SELECT p.rank  rank_count,r.MDO_PLAN_NM
               FROM  ' || i_tab_name || ' r,
                     rm_mdo_plan_override P
               WHERE r.dept = NVL(p.dept,r.dept)
                 AND r.CLASS = NVL(p.CLASS,r.CLASS)
                 AND r.chain_id = NVL(p.chain_id,r.chain_id)
                 AND r.group_no = NVL(p.group_no,r.group_no)
                 AND r.season_code = NVL(p.season_code,r.season_code)
                 AND NVL(r.mdo_uda,0) = NVL(p.mdo_uda,NVL(r.mdo_uda,0))
                 AND NVL(r.mdo_value,0) = NVL(p.mdo_value,NVL(r.mdo_value,0))
             )
             ) CC , rm_mdo_plan_override P
      WHERE CC.MDO_PLAN_NM = R.MDO_PLAN_NM
        AND CC.PLAN_RANK = 1
        AND r.dept = NVL(p.dept,r.dept)
        AND r.CLASS = NVL(p.CLASS,r.CLASS)
        AND r.chain_id = NVL(p.chain_id,r.chain_id)
        AND r.group_no = NVL(p.group_no,r.group_no)
        AND r.season_code = NVL(p.season_code,r.season_code)
        AND NVL(r.mdo_uda,0) = NVL(p.mdo_uda,NVL(r.mdo_uda,0))
        AND NVL(r.mdo_value,0) = NVL(p.mdo_value,NVL(r.mdo_value,0))
        )
          WHERE RANK_COUNT = rank ';
  
    -- delay for pcms markdn
    EXECUTE IMMEDIATE 'update ' || o_tab_name || chr(10) ||
                      '   set ALLOWED_MARKDN_PERIODS = MD_GET_ALLOWED_MKDN_WEEKS_PCMS(group_no, start_dt, end_dt, ' ||
                      v_recommend_delay_weeks || ') ' || chr(10) ||
                      ' where pcms_mkdn = ''Y''';
  
    EXECUTE IMMEDIATE 'update ' || o_tab_name || chr(10) ||
                      '   set ALLOWED_MARKDN_PERIODS = MD_GET_FORCE_MARKDOWN_STRING(group_no, start_dt, end_dt, force_markdn_week) ' ||
                      chr(10) || ' where force_markdn_week is not null';
  
    EXECUTE IMMEDIATE ' CREATE TABLE ' || i_tab_name || 'MEM' ||
                      ' tablespace ' || g_tablespace || '  NOLOGGING as
      SELECT P.*
        FROM ' || i_tab_name || ' P, ' || o_tab_name || ' O
       WHERE P.MDO_PLAN_NM = O.MDO_PLAN_NM ';
  
    RETURN TRUE;
  EXCEPTION
    WHEN OTHERS THEN
      IF o_error_message IS NULL THEN
        o_error_message := substr(l_module || ' ' || SQLCODE || ' ' ||
                                  SQLERRM,
                                  1,
                                  2000);
      END IF;
      RETURN FALSE;
  END override_plan;
  -- ============================================

  FUNCTION count_mdo_plan(o_error_message IN OUT VARCHAR2,
                          i_tab_name      IN VARCHAR2) RETURN BOOLEAN IS
  
    l_module VARCHAR2(64) := 'MD_CRE_PLAN_PKG.COUNT_MDO_PLAN';
    v_count  NUMBER := 0;
  BEGIN
    -- -----------------------------------------------------
    -- insert count of records to md_interface_counts table
    -- TPR 89619 Farah
    -- -----------------------------------------------------
    IF i_tab_name = 'MD_IMPORT_PLAN' THEN
      SELECT COUNT(*)
        INTO v_count
        FROM md_import_plan
       WHERE status = v_new;
    
      INSERT INTO md_interface_counts
        (interface_type,
         interface_date,
         ins_count,
         upd_count,
         del_count,
         total_count)
      VALUES
        ('STG_MDO_IMPORT_PLAN', SYSDATE, v_count, 0, 0, v_count);
      COMMIT;
    
      v_count := 0;
      SELECT COUNT(*)
        INTO v_count
        FROM md_import_plan_member m
       WHERE m.status = v_new;
    
      INSERT INTO md_interface_counts
        (interface_type,
         interface_date,
         ins_count,
         upd_count,
         del_count,
         total_count)
      VALUES
        ('STG_MDO_IMPORT_PLAN_MEMBER', SYSDATE, v_count, 0, 0, v_count);
      COMMIT;
    
      --CR 124654 mdo upgrade 
    ELSIF i_tab_name = 'MD_IMPORT_PLAN_52' THEN
      v_count := 0;
      SELECT COUNT(*)
        INTO v_count
        FROM md_import_plan
       WHERE status = v_new;
    
      INSERT INTO md_interface_counts
        (interface_type,
         interface_date,
         ins_count,
         upd_count,
         del_count,
         total_count)
      VALUES
        ('STG_MDO_IMPORT_PLAN_52', SYSDATE, v_count, 0, 0, v_count);
      COMMIT;
    END IF;
  
    RETURN TRUE;
  EXCEPTION
    WHEN OTHERS THEN
      IF o_error_message IS NULL THEN
        o_error_message := substr(l_module || ' ' || SQLCODE || ' ' ||
                                  SQLERRM,
                                  1,
                                  2000);
      END IF;
      RETURN FALSE;
  END count_mdo_plan;
  -- ======================================================

  FUNCTION create_plan_params_tab(o_error_message IN OUT VARCHAR2)
    RETURN BOOLEAN IS
    l_module VARCHAR2(64) := 'MD_CRE_PLAN_PKG.CREATE_PLAN_PARAMS_TAB';
  
  BEGIN
    -- -----------------------------------------------------
    -- create MD_PLAN_PARAMETERS
    -- PPR 91065 Purnima
    -- -----------------------------------------------------
    IF drop_table(o_error_message, 'MD_PLAN_PARAMETERS_WORK') = FALSE THEN
      RAISE program_error;
    END IF;
  
    IF drop_table(o_error_message, 'MD_PLAN_PARAMETERS') = FALSE THEN
      RAISE program_error;
    END IF;
  
    -- add outdate 
    EXECUTE IMMEDIATE ' CREATE TABLE MD_PLAN_PARAMETERS_WORK as
     SELECT r.*, md_get_outdate (r.fiscal_month_outdate,r.fiscal_week_outdate,''' ||
                      g_date || ''') outdate
       FROM RM_MDO_PLAN_PARAMETERS r';
  
    EXECUTE IMMEDIATE ' CREATE TABLE MD_PLAN_PARAMETERS as
     SELECT season_code, 
            chain_id, 
            group_no, 
            cluster_group_id, 
            dept, 
            CLASS, 
            mdo_uda,
            mdo_value, 
            min_selling_week, 
            plan_duration_week, 
            rank, 
            outdate
       FROM MD_PLAN_PARAMETERS_WORK
      WHERE SEASON_CODE = ''SL''
      UNION ALL
    SELECT A.season_code, A.chain_id, A.group_no, A.cluster_group_id, A.dept, A.class, A.mdo_uda, A.mdo_value, r.min_selling_week, r.plan_duration_week, A.rank, A.outdate 
    FROM
     (SELECT season_code, 
             chain_id, 
             group_no, 
             cluster_group_id, 
             dept, 
             CLASS,  
             mdo_uda, 
             mdo_value, 
             rank, 
             MIN(outdate) outdate 
       FROM MD_PLAN_PARAMETERS_WORK
      WHERE SEASON_CODE != ''SL''
        AND ' || '''' || g_date || '''' ||
                      ' < OUTDATE
      GROUP BY season_code, chain_id, group_no, cluster_group_id, dept, CLASS, mdo_uda, mdo_value, rank)A, RM_MDO_PLAN_PARAMETERS r
  WHERE nvl(A.season_code,'' '') = nvl(r.season_code,'' '')
    AND nvl(A.chain_id,0) = nvl(r.chain_id,0)
    AND nvl(A.group_no,0) = nvl(r.group_no,0)
    AND nvl(A.dept,0) = nvl(r.dept,0)
    AND nvl(A.class,0) = nvl(r.class,0)
    AND nvl( A.mdo_uda,0) = nvl(r.mdo_uda,0)
    AND nvl(A.mdo_value,0) = nvl(r.mdo_value,0)
    AND nvl(A.cluster_group_id, 0) = nvl(r.cluster_group_id, 0)';
  
    IF drop_table(o_error_message, 'MD_PLAN_PARAMETERS_WORK') = FALSE THEN
      RAISE program_error;
    END IF;
  
    RETURN TRUE;
  
  EXCEPTION
    WHEN OTHERS THEN
      IF o_error_message IS NULL THEN
        o_error_message := substr(l_module || ' ' || SQLCODE || ' ' ||
                                  SQLERRM,
                                  1,
                                  2000);
      END IF;
    
      RETURN FALSE;
    
  END create_plan_params_tab;

  -- ======================================================

  FUNCTION create_plan_candidate_tab(o_error_message IN OUT VARCHAR2)
    RETURN BOOLEAN IS
    l_module VARCHAR2(64) := 'MD_CRE_PLAN_PKG.CREATE_PLAN_CANDIDATE_TAB';
  
  BEGIN
    -- ----------------------------------------------------------------------------------------
    -- create MD_PLAN_CANDIDATES table structure to hold info about possible plan candidates
    -- used to check missing plan parameters and plan overrides
    -- CR 87831 Purnima
    -- ---------------------------------------------------------------------------------------
    IF drop_table(o_error_message, 'MD_PLAN_CANDIDATES') = FALSE THEN
      RAISE program_error;
    END IF;
  
    EXECUTE IMMEDIATE ' CREATE TABLE MD_PLAN_CANDIDATES as
     SELECT cast('''' as varchar2(5)) MERCH_TYPE,
            SEASON_CODE,
            CHAIN_ID,
            GROUP_NO,
            CLUSTER_GROUP_ID,
            DEPT,
            CLASS,
            MDO_UDA,
            MDO_VALUE
       FROM RM_MDO_PLAN_PARAMETERS
      WHERE 1=2';
  
    RETURN TRUE;
  EXCEPTION
    WHEN OTHERS THEN
      IF o_error_message IS NULL THEN
        o_error_message := substr(l_module || ' ' || SQLCODE || ' ' ||
                                  SQLERRM,
                                  1,
                                  2000);
      END IF;
      RETURN FALSE;
    
  END create_plan_candidate_tab;
  -- ======================================================

  FUNCTION send_alert(p_ari_subject   IN VARCHAR2,
                      p_ari_message   IN VARCHAR2,
                      p_alert_code    NUMBER,
                      o_error_message IN OUT VARCHAR2) RETURN BOOLEAN IS
    l_module VARCHAR2(64) := 'MD_CRE_PLAN_PKG.SEND_ALERT';
    errm     VARCHAR2(100);
    ari_excpt EXCEPTION;
  BEGIN
    -- ----------------------------------------------------------------------------------------
    -- function to send ARI alert
    -- ---------------------------------------------------------------------------------------
    IF rm_issue_maint.create_ari_message(io_error_message => errm,
                                         i_alert_code     => p_alert_code,
                                         i_route_to       => 'G',
                                         i_router         => 0,
                                         i_alert_message  => substr(p_ari_message,
                                                                    1,
                                                                    995),
                                         i_alert_subject  => p_ari_subject) =
       FALSE THEN
      RAISE ari_excpt;
    ELSE
      COMMIT;
    END IF;
    RETURN TRUE;
  
  EXCEPTION
    WHEN ari_excpt THEN
      IF o_error_message IS NULL THEN
        o_error_message := substr(l_module || ' ' || SQLCODE || ' ' ||
                                  SQLERRM,
                                  1,
                                  2000);
      END IF;
      RETURN FALSE;
  END send_alert;
  -- ======================================================
  --**** Public
  FUNCTION check_missing_plan_param(o_error_message IN OUT VARCHAR2)
    RETURN BOOLEAN IS
  
    l_module       VARCHAR2(64) := 'MD_CRE_PLAN_PKG.CHECK_MISSING_PLAN_PARAM';
    v_ari_subject  VARCHAR2(100) := 'ARI Alert - Missing Plan Parameters';
    v_ari_message  CLOB := empty_clob();
    l_sql_stmt     VARCHAR2(4000);
    v_season_code  VARCHAR2(5);
    v_group_no     NUMBER;
    v_dept         NUMBER;
    v_class        NUMBER;
    v_mdo_uda      NUMBER;
    v_error_exists BOOLEAN := FALSE;
  
    v_output_path      VARCHAR2(50) := 'MDO_DATA_OUT_DIR';
    v_output_fptr      utl_file.file_type;
    v_output_file_name VARCHAR2(100) := 'missing_plan_parameters.html';
  
    TYPE l_refcur IS REF CURSOR;
    l_rec l_refcur;
  
  BEGIN
  
    IF utl_file.is_open(v_output_fptr) THEN
      utl_file.fclose(v_output_fptr);
    END IF;
  
    v_output_fptr := utl_file.fopen(v_output_path,
                                    v_output_file_name,
                                    'W',
                                    32767);
  
    IF drop_table(o_error_message, 'MD_MISSING_PLAN_PARAM') = FALSE THEN
      RAISE program_error;
    END IF;
  
    EXECUTE IMMEDIATE ' CREATE TABLE MD_MISSING_PLAN_PARAM as
    SELECT merch_type,
           season_code,
           chain_id,
           group_no,
           dept,
           class,
           mdo_uda,
           mdo_value
      FROM MD_PLAN_CANDIDATES
      MINUS
      SELECT r.merch_type,
             r.season_code,
             r.chain_id,
             r.group_no,
             r.dept,
             r.class,
             r.mdo_uda,
             r.mdo_value
        FROM MD_PLAN_CANDIDATES r, MD_PLAN_PARAMETERS p
       WHERE r.dept = NVL(p.dept,r.dept)
         AND r.CLASS = NVL(p.CLASS,r.CLASS)
         AND r.chain_id = NVL(p.chain_id,r.chain_id)
         AND r.group_no = NVL(p.group_no,r.group_no)
         AND r.season_code = NVL(p.season_code,r.season_code)
         AND NVL(r.mdo_uda,0) = NVL(p.mdo_uda,NVL(r.mdo_uda,0))
         AND NVL(r.mdo_value,0) = NVL(p.mdo_value,NVL(r.mdo_value,0))';
  
    l_sql_stmt := ' SELECT DISTINCT SEASON_CODE
          , GROUP_NO
          , DEPT
          , CLASS
          , MDO_UDA
                    FROM MD_MISSING_PLAN_PARAM ';
  
    v_ari_message := '<html>Plan parameter entries are missing for following:<br>';
    v_ari_message := v_ari_message ||
                     '<br><table cellspacing=6><tr><th>Season Code</th><th>Group No</th><th>Dept</th><th>Class</th><th>MDO UDA</th></tr>';
  
    OPEN l_rec FOR l_sql_stmt;
    LOOP
      FETCH l_rec
        INTO v_season_code, v_group_no, v_dept, v_class, v_mdo_uda;
      EXIT WHEN l_rec%NOTFOUND;
      IF l_rec%ROWCOUNT = 1 THEN
        -- PPR 103923
        v_ari_message := v_ari_message || '<tr><td>' || v_season_code ||
                         '</td>' || '<td>' || v_group_no || '</td>' ||
                         '<td>' || v_dept || '</td>' || '<td>' || v_class ||
                         '</td>' || '<td>' || v_mdo_uda || '</td>' ||
                         '</tr>';
      ELSE
        v_ari_message := '<tr><td>' || v_season_code || '</td>' || '<td>' ||
                         v_group_no || '</td>' || '<td>' || v_dept ||
                         '</td>' || '<td>' || v_class || '</td>' || '<td>' ||
                         v_mdo_uda || '</td>' || '</tr>';
      END IF;
      utl_file.put_line(v_output_fptr, v_ari_message);
    
    END LOOP;
  
    utl_file.fclose(v_output_fptr); -- PPR 103923
  
    -- v_ari_message := v_ari_message || '</table></html>';
  
    CLOSE l_rec;
  
    RETURN TRUE;
  
  EXCEPTION
    WHEN utl_file.invalid_path THEN
      IF utl_file.is_open(v_output_fptr) THEN
        utl_file.fclose(v_output_fptr);
      END IF;
      o_error_message := '-20001,INVALID PATH exception raised';
      RETURN FALSE;
    
    WHEN utl_file.invalid_mode THEN
      IF utl_file.is_open(v_output_fptr) THEN
        utl_file.fclose(v_output_fptr);
      END IF;
      o_error_message := '-20002,INVALID_MODE exception raised';
      RETURN FALSE;
    
    WHEN utl_file.invalid_filehandle THEN
      IF utl_file.is_open(v_output_fptr) THEN
        utl_file.fclose(v_output_fptr);
      END IF;
      o_error_message := '-20003,INVALID_FILEHANDLE exception raised';
      RETURN FALSE;
    
    WHEN utl_file.invalid_operation THEN
      IF utl_file.is_open(v_output_fptr) THEN
        utl_file.fclose(v_output_fptr);
      END IF;
      o_error_message := '-20004,INVALID_OPERATION exception raised';
      RETURN FALSE;
    
    WHEN utl_file.read_error THEN
      IF utl_file.is_open(v_output_fptr) THEN
        utl_file.fclose(v_output_fptr);
      END IF;
      o_error_message := '-20005, READ_ERROR exception raised';
      RETURN FALSE;
    
    WHEN utl_file.write_error THEN
      IF utl_file.is_open(v_output_fptr) THEN
        utl_file.fclose(v_output_fptr);
      END IF;
      o_error_message := '-20006, WRITE_ERROR exception raised';
      RETURN FALSE;
    
    WHEN utl_file.internal_error THEN
      IF utl_file.is_open(v_output_fptr) THEN
        utl_file.fclose(v_output_fptr);
      END IF;
      o_error_message := '-20007,INTERNAL_ERROR exception raised';
      RETURN FALSE;
    
    WHEN OTHERS THEN
      IF utl_file.is_open(v_output_fptr) THEN
        utl_file.fclose(v_output_fptr);
      END IF;
    
      IF o_error_message IS NULL THEN
        o_error_message := substr(SQLCODE || ' ' || SQLERRM, 1, 2000);
      END IF;
    
      RETURN FALSE;
    
  END check_missing_plan_param;
  -- ======================================================

  --**** Public
  FUNCTION check_missing_plan_override(o_error_message IN OUT VARCHAR2)
    RETURN BOOLEAN IS
    l_module      VARCHAR2(64) := 'MD_CRE_PLAN_PKG.CHECK_MISSING_PLAN_OVERRIDE';
    v_ari_subject VARCHAR2(100) := 'ARI Alert - Missing Plan Overrides';
    v_ari_message VARCHAR2(1000) := '<html>Plan override entries are missing for following:<br>';
    l_sql_stmt    VARCHAR2(4000);
    v_dept        NUMBER;
    TYPE l_refcur IS REF CURSOR;
    l_rec          l_refcur;
    v_error_exists BOOLEAN := FALSE;
  
  BEGIN
    IF drop_table(o_error_message, 'MD_MISSING_PLAN_OVERRIDE') = FALSE THEN
      RAISE program_error;
    END IF;
  
    EXECUTE IMMEDIATE ' CREATE TABLE MD_MISSING_PLAN_OVERRIDE as
    SELECT merch_type,
           season_code,
           chain_id,
           group_no,
           dept,
           class,
           mdo_uda,
           mdo_value
      FROM MD_PLAN_CANDIDATES
      MINUS
      SELECT r.merch_type,
             r.season_code,
             r.chain_id,
             r.group_no,
             r.dept,
             r.class,
             r.mdo_uda,
             r.mdo_value
        FROM MD_PLAN_CANDIDATES r, RM_MDO_PLAN_OVERRIDE p
       WHERE r.dept = NVL(p.dept,r.dept)
         AND r.CLASS = NVL(p.CLASS,r.CLASS)
         AND r.chain_id = NVL(p.chain_id,r.chain_id)
         AND r.group_no = NVL(p.group_no,r.group_no)
         AND r.season_code = NVL(p.season_code,r.season_code)
         AND NVL(r.mdo_uda,0) = NVL(p.mdo_uda,NVL(r.mdo_uda,0))
         AND NVL(r.mdo_value,0) = NVL(p.mdo_value,NVL(r.mdo_value,0))';
  
    l_sql_stmt := ' SELECT DISTINCT DEPT
                    FROM MD_MISSING_PLAN_OVERRIDE ';
  
    v_ari_message := v_ari_message || '<table><tr><th>Department</th></tr>';
    OPEN l_rec FOR l_sql_stmt;
    LOOP
      FETCH l_rec
        INTO v_dept;
      EXIT WHEN l_rec%NOTFOUND;
      v_ari_message := v_ari_message || '<tr><td>' || v_dept ||
                       '</td></tr>';
      IF length(v_ari_message) > 970 THEN
        EXIT;
      END IF;
      IF v_error_exists = FALSE THEN
        v_error_exists := TRUE;
      END IF;
    END LOOP;
    v_ari_message := v_ari_message || '</table></html>';
    CLOSE l_rec;
  
    IF v_error_exists = TRUE THEN
      IF send_alert(v_ari_subject, v_ari_message, 24, o_error_message) =
         FALSE THEN
        RAISE program_error;
      END IF;
    END IF;
  
    RETURN TRUE;
  EXCEPTION
    WHEN OTHERS THEN
      IF o_error_message IS NULL THEN
        o_error_message := substr(l_module || ' ' || SQLCODE || ' ' ||
                                  SQLERRM,
                                  1,
                                  2000);
      END IF;
      RETURN FALSE;
  END check_missing_plan_override;
  -- ===========================================================

END md_cre_plan_pkg;
/
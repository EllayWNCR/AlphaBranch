/****************************************************************
*002 cash-projection-update-SQL.sql
*
*Forecast run for 12 weeks: Jul 2 2023 - Sep 23 2023
*   week 27, 2023- week 38, 2023
*
*Run Jun 26 2023
*
*Baseline: May 28, 2022 - Jun 24, 2023

*Baseline for new terminals: Jun 11, 2023 - Jun 24, 2023
*
*
*Change Log: 
*12/10/20 Added BoA2 Non-AP BIN 
*12/10/20 Added Chime Non-AP BIN
*12/10/20 Modified $/wd calculation for Chime as it has a monthly cycle
*01/12/21 Added Arrangement limit to Non-MS terminals per Joshua Booth as he deletes PLACEMENT and PURCHASE units.
*01/12/21 Modified 9 week baseline to 4 week baseline with repeated weeks
*01/12/21 Modified baseline to impute missing data
*01/20/21 Modified Allocation to terminals to use a separate date variable to gather data to calculate 
*         weights. Allows for fine tuning during volatile periods. Had been using same variable as the 
*         dates for base data for new terminals. 
*01/20/21 Added code to build baseline from base data
*01/21/21 Added NULLIF to imputation to avoid outages reducing average values by including zeros. 	 
*02/05/21 Added new BINs: 
*               Bancorp 423223 non-AP, shows UI influence
*               Comerica 511558, 515549, 515478, 515101 UI BINs
*               USBank 446053, 446053611, 491288, 49128806, 49128808, 49128820 UI
*               BoA 511560 Non-AP UI added to existing BoA2 BIN group
*02/09/21 Added increased $/wd starting March 14, 2021 for UI BINs due to new FPUC payment of $400
*         starting then. 
*02/18/21 Corrected data pull for BoA2 Non-AP BIN. When pulling data to remove from 
*         baseline, new BIN 511560 was omitted, so was in forecast twice. Not much impact as 
*         this is a very small BIN (IA UI, $200K/wk)
*3/8/21   Change allocation for UI BIN groups to use current $/wd as Senate approved $300/wk through Sep 6.
*3/11/21  Change allocation for $/wd, ATM weights to use last 4 weeks to dilute effect of polar vortex
*             storm week of Feb 15. Need to use most recent data as several BIN groups $/wd have shifted in 
*             last month, so cannot use baseline time period for $/wd or allocation weights. 
*3/12/21  Modify baseline dates to improve forecast
*3/24/21  Added NULLIF to WDAmt imputation, was previously only on n_WD
*3/25/21  Added code to calculate average number of historical withdrawals and withdrawal amount from previously
*         six months by day of week for imputing forecasts for ATMs with no data in baseline period. These could
*         be down due to hardware problems, OOC - Waiting, BCP, no usage due to Covid. 
*3/26/21  Added code to count number of days ATM had withdrawals in six month historical period to avoid adding
*         more imputed data points than ATM has historically, i.e., don't change a sporadic activity ATM to about
*         daily activity ATM through imputation of missing data. 
*3/31/21  Added code to estimate SS stimulus 3 based on IRS announcement of 3/30/21 that payments for  non-filers
*         would be made 4/7/21. 
*         Also added code to estimate EIP debit card stimulus based on 5M cards mailed starting 3/19. Withdrawals
*         started 3/26/21. 
*4/22/21  Average Feb and Mar for ROM $/wd calculations. Feb is low due to winter storm Uri, March is high due to 
*         stimulus.
*5/21/21  Chime added 3 AP BINs as of 5/5/21: 4232230, 4985031, 4232231. Refactor code to add these to Chime, which
*         was previously forecast in two separate buckets: Stride (498503) and Bancorp (423223). 
*         Refactored code to define segment, as per MUDS code from Shree. Used to be based on BLAP, but BusinesLine is
*         no longer maintained. Now defined based on Arrangment and Program. 
*         Added code to estimate Child Tax Credit payment on July 15. 
*6/23/21  Update LMI code to used same LMI tables used by Child Tax Credit logic. 
*         Added second Child Tax Credit payment on August 13.
*7/27/21  Remove units from #terms1 that were deinstalled during baseline period. 
*9/27/21  Federal Pandemic UI programs expired 9/6/21, no renewal anticipated, nor additional stimulus packages
*         Replace Money Network EIP BIN w Money Network Payroll BIN group
*         Replace Comerica UI BIN group with Comdata Payroll BIN group
*         Replace US Bank Non-AP UI with ADP Payroll BIN group
*         Replace BoA2 UI with Payfare Payroll BIN group
*10/26/21 Added two BINS:
*         511563 for Comerica SS, 
*         421783 for Chime. Both are AP.
*         Removed extended BINs for Chime. 
*         Added BOM/ROM average wd amounts for Payfare as it has a monthly cycle. 
*         Added average wd amount increase for Fri/Sat for Money Network, ADP, Comdata based on previous forecast vs actual 
*             as average wd amounts appear to have a weekly cycle in addition to the monthly cycle.  
*         Added average wd amount increase for CTC for ADP, Comdata based on previous forecast vs actual as average wd
*             amounts had a substantial differential on day of and day after CTC payments. 
*11/15/21 Added 3 new Chime bins that were added to AP on 10/6/21: 400895, 447227, 486208. Little to no volume yet, but 
*             don't want to be surprised by high volume in the future. 
*         Extend forecast from 9 weeks to 12 weeks.
*12/20/21 Removed code for Child Tax Credit as all six advance payments have been made. 
*1/11/22  Added BIN 416187 for ADP, removed several AP BINs that have no activity since 2020. 
* 2/2/22  Replace US Bank UI with US Bank - Private Prepaid-Payroll. 
*         Replace BoA Non-AP UI with Skylight Financial Prepaid-Payroll. 
*         Replace Keybank UI with Varo. 
* 4/6/22  Merge Chime BIN groups and add Cash App BIN 440393 issued by Suttton Bank
*
* 3/22    Change imputation average dispense to weighted average
* 7/13    Added PNC Bank (AP) BIN to the list as an additional BIN group
*
*Last Modified Date:  7/18/2022
****************************************************************/

/*****************************************************************
Part I

Create transaction input for 003 CashProjection spreadsheet. 
******************************************************************/
IF OBJECT_ID('tempdb..#dates', 'U') IS NOT NULL
   drop table #dates;
create table #dates
(
	varname varchar(20) primary key,
	dt datetime
);

/* dates available in [WebReportsUser].[KYC_CASH_PROJ_2023_Finance_Data] */ 
-- 36 weeks days or less
Insert into #dates Select 'StartDate',  cast('2022-10-23' as datetime);
Insert into #dates Select 'EndDate',  cast('2023-06-24' as datetime);

--depends on how many weeks used in Setup tab:
Insert into #dates Select 'BaselineStart', cast('2023-05-28' as date);
Insert into #dates Select 'BaselineEnd', cast('2023-06-24' as date);

--depends on how many weeks used in Comerica tab:
Insert into #dates Select 'ComericaStart', cast('2023-04-02' as date);
Insert into #dates Select 'ComericaEnd', cast('2023-06-24' as date);

--2 weeks (different trend since it's new)
Insert into #dates Select 'NewBaseStart', cast('2023-06-11' as date);
Insert into #dates Select 'NewBaseEnd', cast('2023-06-24' as date);

Insert into #dates Select 'TxnCutoff', cast('2023-05-28' as date); -- to find terminal to forecast (Sunday @ 4 weeks before end of baseline)

-- 12 weeks
Insert into #dates Select 'FcstStart', cast('2023-07-02' as date);
Insert into #dates Select 'FcstEnd', cast('2023-09-23' as date);

/* Choose BOM from Jun, Apr, May*/

Insert into #dates Select 'BOM1Start', cast('2023-04-02' as date); -- 2nd week of Apr is the peak
Insert into #dates Select 'BOM1End', cast('2023-04-08' as date);
Insert into #dates Select 'BOM2Start', cast('2023-05-28' as date);
Insert into #dates Select 'BOM2End', cast('2023-06-03' as date);
Insert into #dates Select 'BOM3Start', cast('2023-04-30' as date);
Insert into #dates Select 'BOM3End', cast('2023-05-06' as date);
Insert into #dates Select 'ROMStart', cast('2023-06-04' as date);
Insert into #dates Select 'ROMEnd', cast('2023-06-24' as date);

/* Use last 4 weeks for allocating forecasts to ATMs and $/wd. 
   For non-cyclic BIN groups only. None at present */
Insert into #dates Select 'AllocStart', cast('2023-06-04' as date); 
Insert into #dates Select 'AllocEnd', cast('2023-06-24' as date);    

/* These are placeholders to build the baseline */
Insert into #dates Select 'ModelStart', cast('2023-04-09' as date);
Insert into #dates Select 'ModelEnd', cast('2023-07-01' as date);
		   
/*save dates to perminent table*/
IF OBJECT_ID('[SSRSReports].[WebReportsUser].[KYC_CASH_PROJ_DATES_JUL2]', 'U') IS NOT NULL
	drop table [SSRSReports].[WebReportsUser].[KYC_CASH_PROJ_DATES_JUL2]
	select * into [SSRSReports].[WebReportsUser].[KYC_CASH_PROJ_DATES_JUL2]
	from #dates
	;

select * from [SSRSReports].[WebReportsUser].[KYC_CASH_PROJ_DATES_JUL2];

IF OBJECT_ID('[SSRSReports].[WebReportsUser].[KYC_CASH_PROJ_DATES]', 'U') IS NOT NULL
	drop table [SSRSReports].[WebReportsUser].[KYC_CASH_PROJ_DATES]
	select * into [SSRSReports].[WebReportsUser].[KYC_CASH_PROJ_DATES]
	from #dates
	;

select * from [SSRSReports].[WebReportsUser].[KYC_CASH_PROJ_DATES];
/******************************************************************
Build references for Program & Arrangement
******************************************************************/
IF OBJECT_ID('tempdb..#rev_rec_lkp', 'U') IS NOT NULL
   drop table #rev_rec_lkp; 
select PGM, 
       ARR, 
	   case when TemplateName in ('ABS','ATM Placement Co','Kroger MS') then 'MS' 
	        else TemplateName 
	   end as TemplateName, 
	   ReportingGroup, 
	   RelationshipType,
	   count(*) as n_rec, 
	   count(distinct TemplateName) as n_temp
  into #rev_rec_lkp
  from Subledger_Sub.dbo.SL_BL_ARR_PGM
 where isActive = 1
   and TemplateName is not null
 group by PGM, ARR, case when TemplateName in ('ABS','ATM Placement Co','Kroger MS') then 'MS' else TemplateName end, 
       ReportingGroup, RelationshipType
 order by 7 desc;
--690

IF OBJECT_ID('tempdb..#rev_rec_lkp_inactive', 'U') IS NOT NULL
   drop table #rev_rec_lkp_inactive; 
select PGM, 
       ARR, 
	   case when TemplateName in ('ABS','ATM Placement Co','Kroger MS') then 'MS' 
	        else TemplateName 
	   end as TemplateName, 
	   ReportingGroup, 
	   RelationshipType,
	   count(*) as n_rec, 
	   count(distinct TemplateName) as n_temp
  into #rev_rec_lkp_inactive
  from Subledger_Sub.dbo.SL_BL_ARR_PGM
 where isActive = 0
   and TemplateName is not null
 group by PGM, ARR, case when TemplateName in ('ABS','ATM Placement Co','Kroger MS') then 'MS' else TemplateName end, 
       ReportingGroup, RelationshipType
 order by 7 desc;
--210

/* Check to make sure there are no duplicates by PGM and ARR.
   Must return 0 records. */
   
select *
  from #rev_rec_lkp
 where n_temp > 1;
--0 rows

select *
  from #rev_rec_lkp_inactive
 where n_temp > 1;
--0 rows
 

/*************************************************************
Get List of ALL ATMS
**************************************************************/
IF OBJECT_ID('tempdb..#ATM_ALL', 'U') IS NOT NULL
   drop table #ATM_ALL; 
select a.ATMInternalID,
	   a.TerminalID,
	   a.AUDFD1,
	   a.AUDFD2,
	   a.DateInstalled,
       a.DateDeinstalled,
       a.Zone,
	   a.Location,
	   a.ContactAddr1,
	   l.LocationAddress,
	   l.LocationCity,
	   l.LocationState as State,
	   l.LocationZip,
	   SUBSTRING(l.LocationZip,1,5) as Zip5,
       a.AUDFX2 as BL_ATM,
       a.Arrangement,
       ltrim(rtrim(a.AUDFX4)) as Program,
	   a.Status,
	   b.BusUnitName,
	   case 
	       when a.AUDFX2 like 'MEXICO' then 'Mexico'
	       when a.AUDFX2 like 'CANADA' then 'Canada'
		   when a.AUDFX2 like '%MS' then 'MS'
		   when a.AUDFX2 like 'MS%' then 'MS-1'
		   when rtrim(upper(a.AUDFX4)) like '% MS%' then 'MS'
	       else 'Oth' 
	   end as bkt, 
	   coalesce(act.RelationshipType, inact.RelationshipType) as RelationshipType, 
	   coalesce(act.ReportingGroup, inact.ReportingGroup) as ReportingGroup, 
	   coalesce(act.TemplateName, inact.TemplateName) as TemplateName
  into #ATM_ALL
  from ATMManagerM.dbo.ATM as a WITH (nolock)
       left Join ATMManagerM.dbo.TblBusinessUnit b WITH (nolock) 
	   on b.BusUnitId = a.BusUnitId
       left Join ATMManagerM.[dbo].[ISView_LocationDetail] l WITH (nolock) 
	   on a.ATMInternalID = l.ATMInternalID
	   	   left join #rev_rec_lkp act 
       on upper(ltrim(rtrim(a.AUDFX4))) = upper(ltrim(rtrim(act.PGM))) 
       and upper(ltrim(rtrim(a.Arrangement))) = upper(ltrim(rtrim(act.ARR)))
       left join #rev_rec_lkp_inactive inact
       on upper(ltrim(rtrim(a.AUDFX4))) = upper(ltrim(rtrim(inact.PGM))) 
       and upper(ltrim(rtrim(a.Arrangement))) = upper(ltrim(rtrim(inact.ARR)));

select count(*)
  from #ATM_ALL;
--246760

   
---check dups
select ATMInternalID, 
       count(*) as n_rec
  from #ATM_ALL
 group by ATMInternalID
having count(*) > 1;
--0 rows

/*************************************************************
Get a list of All ATMs that had a withdrawal transaction 
during the required time period
**************************************************************/
IF OBJECT_ID('tempdb..#atm_with_trans', 'U') IS NOT NULL
   drop table #atm_with_trans;
select a.ATMInternalID,
       b.TerminalID,
       b.Location,
       b.Status,
       b.State,
       b.Zip5 as Zip,
       b.DateInstalled,
       b.DateDeinstalled,
       b.Zone,
       b.BL_ATM as BusinessLine,
       b.Arrangement,
       b.Program,
	   b.AUDFD1, 
	   b.AUDFD2,
	   b.ReportingGroup,
	   b.RelationshipType,
	   b.bkt,
	   b.BusUnitName,
	   case 
		   when rtrim(upper(b.Program)) like '% IC' then 'IC'
		   when rtrim(upper(b.Program)) like '% MS' then 'MS'
		   when rtrim(upper(b.Program)) like '% ST' then 'ST'
		   else 'MISS' 
	   end as RevGrpProg,
	   CASE
		   WHEN ltrim(rtrim(b.BusUnitName))='MX' THEN 'Mexico'
		   WHEN ltrim(rtrim(b.BusUnitName))='CA' THEN 'Canada'
		   WHEN upper(ltrim(rtrim(b.State))) IN ('MB',
		       'NB',
		       'ON',
		       'QC',
		       'PE',
		       'BC',
		       'AB',
		       'SK',
		       'NL',
		       'NT',
		       'NS',
		       'NU',
		       'YT') THEN 'Canada'
		   WHEN ltrim(rtrim(b.BusUnitName))='US' and ltrim(rtrim(coalesce(b.TemplateName,'ST'))) in ('MS') 
                   and Arrangement in ('MERCHANT FUNDED','CASHASSIST','TURNKEY')   THEN 'US-MS-CashManaged'
		   WHEN ltrim(rtrim(b.BusUnitName))='US' and ltrim(rtrim(coalesce(b.TemplateName,'ST'))) in ('MS') THEN 'US-MS'
		   WHEN ltrim(rtrim(b.BusUnitName))='US' and ltrim(rtrim(coalesce(b.TemplateName,'ST'))) not in ('MS') THEN 'US-Non-MS'
	       ELSE 'Unknown'
	   END AS segment
  into #atm_with_trans
  from (select distinct ATMInternalID 
          from ATMManagerM.dbo.ATMTxnTotalsMonthly a with (nolock)
         where ATMInternalID is not null
           and (a.ATMYear*100+a.ATMMonth) >= (select year(dt) * 100 + month(dt) as yymm_st 
	   	                                     from #dates where varname = 'StartDate')
           and (a.ATMYear*100+a.ATMMonth) <= (select year(dt) * 100 + month(dt) as yymm_st 
		                                     from #dates where varname = 'EndDate')
           and ISOWithdrawTxns > 0
        )a
		/* changed left join with where b.ATMInternalID IS NOT NULL to inner join; same result, faster */
        inner join #ATM_ALL b 
	    on a.[ATMInternalID] = b.[ATMInternalID];
--101771

---NON-MS----

select Arrangement, 
       count(*) as n_ATMs
  from #atm_with_trans b
 where segment = 'US-Non-MS'
 group by Arrangement
 order by Arrangement;

/*
Arrangement		n_ATMs
CASHASSIST		103
MERCHANT FUNDED	22
PLACEMENT		215
PURCHASE		10301
TURNKEY			39391
*/


/* Per Joshua Booth, only care about Merchant Funded, Cashassist and Turnkey even for Non-MS. First thing 
   he does when he receives forecast is delete PLACEMENT and PURCHASE units. This has caused a difference 
   in our forecast vs actual numbers.   1/12/21 tc*/
/* Per Shree, leave in PLACEMENT and PURCHASE units so numbers match Daily MSA report. 2/8/21 tc */   

IF OBJECT_ID('tempdb..#terms_nonms', 'U') IS NOT NULL
   drop table #terms_nonms;
select *
  into #terms_nonms
  from #atm_with_trans 
 where segment = 'US-Non-MS';

--50007

----ATMs that are MS but are cash managed by CATM (Turnkey, CashAssist, Merchant Funded)----

select Arrangement, 
       count(*) as n_ATMs
  from #atm_with_trans 
 where segment in ('US-MS-CashManaged', 'US-MS')
 group by Arrangement
 order by Arrangement;

/*
Arrangement			n_ATMs
CASHASSIST			1012
MERCHANT FUNDED		987
PLACEMENT			256
PURCHASE			41755
TURNKEY				3692
*/

IF OBJECT_ID('tempdb..#terms_ms', 'U') IS NOT NULL
   drop table #terms_ms;
select *
  into #terms_ms
  from #atm_with_trans b
 where segment = 'US-MS-CashManaged'

--5604

IF OBJECT_ID('tempdb..#terms', 'U') IS NOT NULL
   drop table #terms;
select *
  into #terms
  from (select *
          from #terms_nonms

         union all

        select *
          from #terms_ms
       )x;

--55611

/* Last txn date before TxnCutoff, a month before forecast run; but status = Active*/
select *
  from #terms
 where AUDFD1 is not null
   and AUDFD1 < (select dt from #dates where varname = 'TxnCutoff')
   and Status = 'Active'
 order by AUDFD2;
--1184

select Status, 
       count(*) as n_rec,
	   cast(max(AUDFD1) as date) as MaxLastTxnDate
  from #terms
 where AUDFD1 is not null
   and AUDFD1 < (select dt from #dates where varname = 'TxnCutoff')
 group by Status;
 
/* TxnCutoff = start of 4 week weights period 

Status			n_rec	MaxLastTxnDate
Closed			1528	2023-02-03
Active/TmpDE	3		2023-01-10
NULL			96		2023-02-04
Active/Week		4		2023-01-08
Active/Mob		16		2022-12-21
Active/FROL		11		2023-01-25
Active/Event	33		2023-02-03
Active			1184	2023-02-04
Active/Sea		165		2023-01-30
*/

/*********************************************************************
How many are deinstalled during baseline?
*********************************************************************/

select Status, 
       count(*) as n_rec,
	   cast(max(AUDFD1) as date) as MaxLastTxnDate
  from #terms
 where AUDFD1 is not null
   and AUDFD1 >= (select dt from #dates where varname = 'BaselineStart')
   and AUDFD1 <= (select dt from #dates where varname = 'BaselineEnd')
   and upper(Status) = 'CLOSED'
 group by Status;
/* 
Status	n_rec	MaxLastTxnDate
Closed	545		2023-04-29
*/

select t.ATMInternalID, 
       t.TerminalID, 
       t.Status, 
	   t.AUDFD1 Last_txndate, 
	   t.DateDeinstalled, 
	   Memo
  from #terms t
       inner join ATMManagerM.dbo.ATM  a with (nolock)
	   on t.ATMInternalID = a.ATMInternalID
 where t.AUDFD1 is not null
   and t.AUDFD1 >= (select dt from #dates where varname = 'BaselineStart')
   and t.AUDFD1 <= (select dt from #dates where varname = 'BaselineEnd')
   and upper(t.Status) = 'CLOSED';
--545 terminals all w Closed status

/*********************************************************************
Get list of ATMs that are inactive: 
    last transaction date prior to BaselineEnd, 
	AND status is not 'Active', 
	AND (ATM.Memo includes 'Perm Deinstall' or status is 'Closed'). 
	
Note: This will miss ATMs deinstalled after the cutoff. 
*********************************************************************/
IF OBJECT_ID('tempdb..#inact', 'U') IS NOT NULL
   drop table #inact;
select *
  into #inact
  from
       (select c.Memo, 
	           b.Status,
	           case when c.Memo like '%PERM DEINSTALL%' or b.Status='Closed' then 1 
			        else 0 
			   end as ATM_inactive_ind,
	           b.ATMInternalID, 
	           b.AUDFD1, 
	           b.DateDeinstalled, 
		       b.Segment
          from #terms b
               inner join ATMManagerM.dbo.ATM as c WITH (nolock) 
			   on b.ATMInternalID = c.ATMInternalID
         where b.AUDFD1 is not null
           and b.AUDFD1 < (select dt from #dates where varname = 'BaselineEnd')
           and b.Status not in ('Active')
       )x
 where ATM_inactive_ind = 1;
--1618

select count(*) as n_inact
  from #inact;

/* Remove inactive/closed machines found above. */

delete from #terms
 where ATMInternalID in (select ATMInternalID from #inact);
 --1618

/* Remove ATMs that have status of 'Pending', 'Disaster', 'Active/FROL' as no way to correctly forecast. */

delete from #terms
 where coalesce(Status,'x') in ('Pending','Disaster','Active/FROL');
--14

/****************************************************************************************
Also remove ATMs that have had no txns since last couple weeks regardless of status.
These are likely shut down, no way to predict when they will start transacting again. 
Either way, we will be unable to correctly forecast these. 

****************************************************************************************/
IF OBJECT_ID('tempdb..#tempshut', 'U') IS NOT NULL
   drop table #tempshut;
select ATMInternalID
  into #tempshut
  from #terms
 where AUDFD1 < (select dt from #dates where varname = 'TxnCutoff');
--1703

delete from #terms
 where ATMInternalID in (select ATMInternalID from #tempshut);

select Status, 
       count(*) as n_rec
  from #terms
 group by Status;
/*
Status			n_rec
Closed			81
NULL			626
Active/Week		74
Active/Mon		1
Active/Mob		13
Active/Event	50
Active			51523
Active/Sea		110
*/

select *
  from #terms
 where AUDFD1 < (select dt from #dates where varname = 'TxnCutoff');
--0 rows

/*************************************************************
Get TID Groups for each TID and the user transactions 
tied to each group
**************************************************************/

IF OBJECT_ID('tempdb..#ap_tid_gid', 'U') IS NOT NULL
   drop table #ap_tid_gid;
SELECT ATM.ATMInternalID, 
       ATM.Status, 
	   ATM.AUDFD1, 
	   ATM.AUDFD2, 
	   ATM.Arrangement, 
	   ATM.Program AS RevProgram, 
	   ATM.State,
	   agx.ATMGroupInternalID, 
	   ISNULL(agx.DateStart, CAST('1905-01-01' AS datetime)) AS agx_DateStart, 
	   ISNULL(agx.DateEnd, CAST('2999-12-31' AS datetime)) AS agx_DateEnd,
	   g.GroupID AS TIDGroupID, 
	   g.GroupName AS TIDGroupName, 
	   g.GroupDesc AS TIDGroupDesc,
	   ugx.UserTxnID, 
	   ugx.DateStart AS ugx_DateStart, 
	   ugx.DateEnd AS ugx_DateEnd,
	   t.Title, 
	   LEFT(t.Title,30) AS Program,
	   REPLACE(REPLACE(b.SQLWhere,'{FIID:',''),'}','') AS fiid_group_code,
	   c.FIIDGroupID,
	   c.FIIDGroupName
  INTO #ap_tid_gid
  FROM  #atm_with_trans ATM 
        INNER JOIN ATMManagerM.dbo.ATMGroupXref agx WITH (NOLOCK) 
		ON ATM.ATMInternalID = agx.ATMInternalID
        INNER JOIN ATMManagerM.dbo.ATMGroup g WITH (NOLOCK) 
		ON g.GroupID = agx.ATMGroupInternalID
        INNER JOIN ATMManagerM_TWAddOn.dbo.T_UserTxnATMGroupXRef ugx WITH (NOLOCK) 
		ON ugx.ATMGroupID = agx.ATMGroupInternalID
        INNER JOIN ATMManagerM_TWAddOn.dbo.T_UserTxn t WITH (NOLOCK) 
		ON t.UserTxnID = ugx.UserTxnID
        INNER JOIN  ATMManagerM_TWAddOn.dbo.T_UserTxnSetup AS b WITH (NOLOCK) 
		ON t.UserTxnID = b.UserTxnID
        INNER JOIN ATMManagerM_TWAddOn.dbo.T_FIIDGroup AS c WITH (NOLOCK) 
		ON c.FIIDGroupCode = REPLACE(REPLACE(b.SQLWhere,'{FIID:',''),'}','') 
 WHERE ISNULL(agx.DateStart, CAST('1905-01-01' AS datetime)) <= (SELECT dt FROM #dates WHERE varname='EndDate')
   AND ISNULL(agx.DateEnd, CAST('2999-12-31' AS datetime)) >= (SELECT dt FROM #dates WHERE varname='StartDate')
   AND ISNULL(ugx.DateStart, CAST('1905-01-01' AS datetime)) <= (SELECT dt FROM #dates WHERE varname='EndDate')
   AND ISNULL(ugx.DateEnd, CAST('2999-12-31' AS datetime)) >= (SELECT dt FROM #dates WHERE varname='StartDate')
   AND (UPPER(t.Title) LIKE '%ALLPOINT%' OR UPPER(g.GroupName) LIKE '%ALLPOINT%')
   AND Title = 'Allpoint - Opt In';
--38474

select top(2) *
from #ap_tid_gid;

create index tmpAP1 on #ap_tid_gid (ATMInternalID);
create index tmpAP2 on #ap_tid_gid (agx_DateStart);
create index tmpAP3 on #ap_tid_gid (agx_DateEnd);
create index tmpAP4 on #ap_tid_gid (ATMInternalID, agx_DateStart, agx_DateEnd);

IF OBJECT_ID('tempdb..#ap_current', 'U') IS NOT NULL
   drop table #ap_current;
select *
  into #ap_current
  from #ap_tid_gid
 where agx_DateEnd = '2999-12-31 00:00:00.000';
--37380

IF OBJECT_ID('tempdb..#terms1', 'U') IS NOT NULL
   drop table #terms1;
select a.Segment,
	   a.ATMInternalID,
	   a.TerminalID,
	   a.Location,
	   a.Status,
	   b.ContactAddr1 as Address,
	   b.LocationCity as City,
	   b.State,
	   b.Zip5 as Zip,
	   a.DateInstalled,
	   a.DateDeinstalled,
	   a.Zone,
	   a.BusinessLine,
	   a.Arrangement,
	   a.Program,
	   case when Segment in ('US-MS-CashManaged') and lkp.RetailerType is null then 'Other-MS'
	        else coalesce(lkp.RetailerType,'Other') 
	   end as RetailerType,
	   a.AUDFD1,
	   a.AUDFD2,
	   a.RevGrpProg as RevGrp,
	   a.ReportingGroup,
       a.RelationshipType,
	   c.MSA_Name as CBSA,
	   d.Title as APGroup,
	   d.agx_DateEnd,
	   d.agx_DateStart
  into #terms1
  from #terms a
       left join #ATM_ALL b 
	   on a.ATMInternalID = b.ATMInternalID
       left join [SSRSReports].[WebReportsUser].[KYC_TEMP_ZIP2MSA] c 
	   on b.Zip5 = c.ZIP_CODE
       left join #ap_current d 
	   on a.ATMInternalID = d.ATMInternalID
       left join [SSRSReports].[WebReportsUser].[KYC_TMP_PROG_2_RET_LKP] lkp 
	   on a.Program = lkp.Program;
--52478

create index tmpAP1 on #terms1 (ATMInternalID);

/* Final Counts by Segment */

select Segment, count(*) as n_rec
  from #terms1
 group by Segment
having count(*) > 1;
/*
Segment				n_rec
US-MS-CashManaged	5336
US-Non-MS			47142
*/

select Segment, Arrangement, count(*) as n_rec
  from #terms1
 group by Segment, Arrangement
 order by Segment, Arrangement;


/*
Segment				Arrangement		n_rec
US-MS-CashManaged	CASHASSIST		822
US-MS-CashManaged	MERCHANT FUNDED	944
US-MS-CashManaged	TURNKEY			3570
US-Non-MS			CASHASSIST		92
US-Non-MS			MERCHANT FUNDED	21
US-Non-MS			PLACEMENT		170
US-Non-MS			PURCHASE		8968
US-Non-MS			TURNKEY			37891
*/


/* Save #terms1 into a persistent table in case connection breaks. Also, must use same #terms1 table to
   have stable forecast data for Comerica. If you regenerate #terms1, could have more active terminals, 
   pick up more transactions due to inner join w #terms1, have final forecast for Comerica that is slightly
   higher than what is on the Comerica tab in the spreadsheet.    */
--first save last forecast's terminals
select count(*) from [SSRSReports].[WebReportsUser].[KYC_CASH_PROJ_TERMS1]
--52392

IF OBJECT_ID('[SSRSReports].[WebReportsUser].[KYC_CASH_PROJ_TERMS1_JUN4]', 'U') IS NOT NULL
   drop table [SSRSReports].[WebReportsUser].[KYC_CASH_PROJ_TERMS1_JUN4];
select *
  into [SSRSReports].[WebReportsUser].[KYC_CASH_PROJ_TERMS1_JUN4]
  from [SSRSReports].[WebReportsUser].[KYC_CASH_PROJ_TERMS1];   

truncate table [SSRSReports].[WebReportsUser].[KYC_CASH_PROJ_TERMS1];

/* alter table TERMS1 due to changes in segment names and RevGrp logic adding longer name */
--alter table [SSRSReports].[WebReportsUser].[KYC_CASH_PROJ_TERMS1] alter column RevGrp varchar(4);
--alter table [SSRSReports].[WebReportsUser].[KYC_CASH_PROJ_TERMS1] alter column segment varchar(17);


insert into [SSRSReports].[WebReportsUser].[KYC_CASH_PROJ_TERMS1]
select *
  from #terms1;
  
select count(*) from #terms1;
--52463

--ALTER TABLE [SSRSReports].[WebReportsUser].[KYC_CASH_PROJ_TERMS1]
--ADD PRIMARY KEY (ATMInternalID);

/* Check dups */

select atminternalid, count(*)
  from [SSRSReports].[WebReportsUser].[KYC_CASH_PROJ_TERMS1]
 group by atminternalid
having count(*) > 1;
--0 rows

select count(*) from [SSRSReports].[WebReportsUser].[KYC_CASH_PROJ_TERMS1];
select top 100 * from [SSRSReports].[WebReportsUser].[KYC_CASH_PROJ_TERMS1];

/* Use the following to restore #terms1. */
/*
IF OBJECT_ID('tempdb..#terms1', 'U') IS NOT NULL
   drop table #terms1;

select *
  into #terms1
  from [SSRSReports].[WebReportsUser].[KYC_CASH_PROJ_TERMS1]
create index tmpAP1 on #terms1 (ATMInternalID);


*/ 
IF OBJECT_ID('tempdb..#terms1', 'U') IS NOT NULL
   drop table #terms1;

select *
  into #terms1
  from [SSRSReports].[WebReportsUser].[KYC_CASH_PROJ_TERMS1]
 
/*********************************************************************************************
Pull prepaid volume + Chime
**Why in two steps? Abhishek put Jan-Mar in one table, rest of year in a second table 
  to speed processing. 
*********************************************************************************************/
/* 
IF OBJECT_ID('tempdb..#pp_03', 'U') IS NOT NULL
   drop table #pp_03;
*/
/* Pre-Covid 19 */
/*
select b.APBinMatchBIN,
	   (year(b.SettlementDate) * 100 + month(b.SettlementDate)) as rep_mth,
	   cast(b.SettlementDate as Date) as SettlementDate,
	   sum(case when b.[txntypeid] = 1 then 1 else 0 end) as n_WD,
	   sum(case when b.[txntypeid] = 1 then amount else 0 end) as WDAmt
  into #pp_03
  from [SSRSReports].[WebReportsUser].[KYC_CASH_PROJ_2023_Finance_Data] b
       inner join #terms1 x 
	   on b.ATMInternalID = x.ATMInternalID
 where cast(b.SettlementDate as Date) <= '2020-03-31'
   and cast(b.SettlementDate as Date) >= '2020-01-01'
 group by  b.APBinMatchBIN, (year(b.SettlementDate) * 100 + month(b.SettlementDate)), cast(b.SettlementDate as Date);
*/

IF OBJECT_ID('tempdb..#pp_04', 'U') IS NOT NULL
   drop table #pp_04;
select b.APBinMatchBIN,
	   (year(b.SettlementDate) * 100 + month(b.SettlementDate)) as rep_mth,
	   cast(b.SettlementDate as Date) as SettlementDate,
	   sum(case when b.[txntypeid]=1 then 1 else 0 end) as n_WD,
	   sum(case when b.[txntypeid]=1 then amount else 0 end) as WDAmt
  into #pp_04
  from [SSRSReports].[WebReportsUser].[KYC_CASH_PROJ_2023_Finance_Data] b
       inner join [SSRSReports].[WebReportsUser].[KYC_CASH_PROJ_TERMS1] x 
	   on b.ATMInternalID = x.ATMInternalID
 group by b.APBinMatchBIN, (year(b.SettlementDate) * 100 + month(b.SettlementDate)), cast(b.SettlementDate as Date);
--71695

create index tmpAP1 on #pp_04 (APBinMatchBIN);

/* Moved all transactions into KYC_CASH_PROJ_2023_Finance_Data with Feb forecasting cycle 2/8/21 tc */
/*
IF OBJECT_ID('tempdb..#pp_05', 'U') IS NOT NULL 
   drop table #pp_05;
*/
/* Non-AP BINs */
/*
select cast(b.BankID as varchar(6)) as APBinMatchBIN, 
       (year(b.SettlementDate) * 100 + month(b.SettlementDate)) as rep_mth, 
	   cast(b.SettlementDate as Date) as SettlementDate, 
	   sum(case when b.txntypeid = 1 then 1 else 0 end) as n_WD, 
	   sum(case when b.txntypeid = 1 then amount else 0 end) as WDAmt
  into #pp_05
  from [SSRSReports].[WebReportsUser].[KYC_CASH_PROJ_2021_NonAPBIN_Finance_Data] b
       inner join #terms1 x 
	   on b.ATMInternalID = x.ATMInternalID
 where cast(b.SettlementDate as Date) >= (select dt from #dates where varname = 'StartDate')
   and cast(b.SettlementDate as Date) <= (select dt from #dates where varname = 'EndDate')
 group by b.BankID, (year(b.SettlementDate) * 100 + month(b.SettlementDate)), cast(b.SettlementDate as Date);
*/

---Govt Bins: Comerica SS, Stimulus, Unemp
/* 2/9/22 per Feb 2022 Allpoint team BIN-Issuer lookup file, 524913 is Prepaid-Payroll, not Prepaid-Govt */

IF OBJECT_ID('tempdb..#govt_bins', 'U') IS NOT NULL 
   drop table #govt_bins;
select *
  into #govt_bins
  from [SSRSReports].[WebReportsUser].[KYC_TEMP_BIN_LIST_TRIM]
 where cast(BIN as varchar(18)) in
(
418953,
463505,
511565,
517186,
524570,
--524913,
525699,
5115600,
44274390,
44277799,
49128801,
49128806,
49128807,
49128808,
49128810,
49128811,
49128813,
49128815,
49128818,
49128819,
49128820,
51919787,
52918801,
52918802,
52918804,
52918806,
414794800,
414794900,
414795800,
414795900,
414795926,
414796802,
442777754,
442777797,
442777854,
442777897,
446053511,
446053611,
511560056,
511560057,
511560058,
533248,
511563);
--41

/*************************************************************************
Write output for Govt & Payroll Sheet in CashProjection SS. 
*************************************************************************/
IF OBJECT_ID('tempdb..#ss_input', 'U') IS NOT NULL 
   drop table #ss_input;
select a.APBinMatchBIN, 
       case when b1.BIN is not null then 1 else 0 end as govt_bin_flag,
	   coalesce(b.Issuer, b0.FI) as Issuer,
	   a.rep_mth, 
	   a.SettlementDate, 
	   a.n_WD, 
	   a.WDAmt
  into #ss_input
  from (
/*       (select *
          from #pp_03

         union all
*/
        select *
          from #pp_04
/*		  
		 union all
		 
		select * 
		  from #pp_05
*/
       )a 
       left join [SSRSReports].[WebReportsUser].[KYC_TEMP_BIN_LIST_TRIM] b 
	   on cast(a.APBinMatchBIN as bigint) = cast(b.BIN as bigint)
	   left join [SSRSReports].[WebReportsUser].[KYC_TEMP_VCMC_BIN_LKP] b0
	   on cast(a.APBinMatchBIN as bigint) = cast(b0.BIN as bigint)
       left join #govt_bins b1 
	   on cast(a.APBinMatchBIN as bigint) = cast(b1.BIN as bigint);
--71695
	   
/* Hardcode the Issuer for BINs that are not AP. */

select distinct APBinMatchBIN 
  from #ss_input
 where Issuer IS NULL;
/*
APBinMatchBIN
442743
511560
*/


UPDATE #ss_input
   set Issuer = 'BoA Non-AP'
 where APBinMatchBIN in ('442743', '511560');
 
--413 row affected

/* Cash App virtual debit card*/
UPDATE #ss_input
   set Issuer = 'Sutton Bank'
 where APBinMatchBIN in ('440393');

select distinct Issuer
  from #ss_input
 where APBinMatchBIN = '440393'
--SUTTON BANK

select count(*)
from #ss_input
where APBINMatchBIN = '440393'
--245

/* Note: The following BINs are in VCMC_BIN_LKP. Only the two above BINs are not in any
         lookup table and must be hardcoded. 
UPDATE #ss_input
   set Issuer = 'Chime (Stride Bank)'
 where APBinMatchBIN = '498503';
UPDATE #ss_input
   set Issuer = 'Bancorp Bank'
 where APBinMatchBIN = '423223';
UPDATE #ss_input
   set Issuer = 'Comerica Non-AP'
 where APBinMatchBIN in ('511558', '515549', '515478', '515101');
UPDATE #ss_input
   set Issuer = 'US Bank Non-AP'
 where APBinMatchBIN in ('446053', '491288');
*/
 --- for Govt. Payroll sheet: 
 select *
   from #ss_input;
--72510 rows
   

IF OBJECT_ID('tempdb..#terms1', 'U') IS NULL 
   select *
   into #terms1
   from [SSRSReports].[WebReportsUser].[KYC_CASH_PROJ_TERMS1];

/* Verify spreadsheet input. */
/* Comerica - added BIN 511563 which is clearly SS by the dispense pattern, caused forecast errors on 10/1 (double payment) */
select sum(amount)
  from SSRSReports.WebReportsUser.KYC_CASH_PROJ_2023_Finance_Data a
       inner join #terms1 t
	   on a.ATMInternalID = t.ATMInternalID
 where SettlementDate >= (select dt from #dates where varname = 'StartDate')
   and SettlementDate <= (select dt from #dates where varname = 'EndDate')
   and APBinMatchBIN in ('533248', '511563');
--1172294578.00
/*
select sum(amount)
  from ATMManagerM_TW.dbo.T_TxnDetail a with (nolock)
       inner join #terms1 t
	   on a.ATMInternalID = t.ATMInternalID
 where SettlementDate >= (select dt from #dates where varname = 'StartDate')
   and SettlementDate <= (select dt from #dates where varname = 'EndDate')
   and Txn = 1
   and TxnTypeID = 1
   and ResponseCodeId = 1
   and BankID in ('533248', '511563');
--1099576614.00
*/
/* Varo Money */
select sum(amount)
  from SSRSReports.WebReportsUser.KYC_CASH_PROJ_2023_Finance_Data a
       inner join #terms1 t
	   on a.ATMInternalID = t.ATMInternalID
 where SettlementDate >= (select dt from #dates where varname = 'StartDate')
   and SettlementDate <= (select dt from #dates where varname = 'EndDate')
   and APBinMatchBIN in ('487917', '433419');
--292122785.00


  
/* US Bank - Private */
select sum(amount)
  from SSRSReports.WebReportsUser.KYC_CASH_PROJ_2023_Finance_Data a
       inner join #terms1 t
	   on a.ATMInternalID = t.ATMInternalID
 where SettlementDate >= (select dt from #dates where varname = 'StartDate')
   and SettlementDate <= (select dt from #dates where varname = 'EndDate')
   and APBinMatchBIN in ('406069', '408031', '411238', '417021', '426752', 
                         '428191', '431582', '441814', '443161', '478665', 
                         '479841', '487081', '511562', '516175', '517750', 
                         '524913', '531462', '4168600', '4440838', '41455700', 
                         '43073111', '45841500', '45841550', '49990101');
--1203156085.00

/* Payfare International Payroll */
select sum(amount)
  from SSRSReports.WebReportsUser.KYC_CASH_PROJ_2023_Finance_Data a
       inner join #terms1 t
	   on a.ATMInternalID = t.ATMInternalID
 where SettlementDate >= (select dt from #dates where varname = 'StartDate')
   and SettlementDate <= (select dt from #dates where varname = 'EndDate')
   and APBinMatchBIN in ('444607', '511757', '520737','53889628')
--666690605.00

   
/* Skylight Financial */
select SettlementDate,sum(amount),count(*)
  from SSRSReports.WebReportsUser.KYC_CASH_PROJ_2023_Finance_Data a
       inner join #terms1 t
	   on a.ATMInternalID = t.ATMInternalID
 where SettlementDate >= (select dt from #dates where varname = 'StartDate')
   and SettlementDate <= (select dt from #dates where varname = 'EndDate')
   and APBinMatchBIN in ('400619', '400620', '410194', '410195', '410196', 
                         '410197', '410808', '410809', '440810', '440813', 
                         '476972', '476973', '476974', '476975', '519325', 
                         '526284', '526285', '530083', '530383', '530389', 
                         '530680', '530690', '530767', '537664', '537697', 
                         '542495', '4315387', '4315388', '4315389', '40346203', 
                         '41434900', '41699200', '42530002', '42530003', '42530702', 
                         '42530703', '43153599', '43153699', '43153770', '45180500', 
                         '45180508', '45180509', '45180588', '45180590', '45180599', 
                         '48532000', '48532011', '48532060', '48532070', '48532081', 
                         '48532082', '48532088', '48532089', '48532090', '48532091', 
                         '48532092', '48532098', '48532099', '50134999', '50271599', 
                         '51331500', '53068400', '53762890', '58571099', '58664299')
	group by settlementdate
	order by settlementdate;
--316000646.00
   
/* Money Network Payroll */
select sum(amount)
  from SSRSReports.WebReportsUser.KYC_CASH_PROJ_2023_Finance_Data a
       inner join #terms1 t
	   on a.ATMInternalID = t.ATMInternalID
 where SettlementDate >= (select dt from #dates where varname = 'StartDate')
   and SettlementDate <= (select dt from #dates where varname = 'EndDate')
   and APBinMatchBIN in ('424015','435889','468271','472776','472777','475024',
                         '494321','494340','494341','519509','526262','530133',
                         '627391','627396','46321400','60119065');
--547321310.00
   
/* Cash App (SUTTON BANK) */
select sum(amount)
  from SSRSReports.WebReportsUser.KYC_CASH_PROJ_2023_Finance_Data a
       inner join #terms1 t
	   on a.ATMInternalID = t.ATMInternalID
 where SettlementDate >= (select dt from #dates where varname = 'StartDate')
   and SettlementDate <= (select dt from #dates where varname = 'EndDate')
   and APBinMatchBIN in ('440393');
--886695651.00
/*
select sum(amount)
  from SSRSReports.WebReportsUser.KYC_CASH_PROJ_2023_Finance_Data a
       inner join #terms1 t
	   on a.ATMInternalID = t.ATMInternalID
 where SettlementDate >= (select dt from #dates where varname = 'StartDate')
   and SettlementDate <= (select dt from #dates where varname = 'EndDate')
   and APBinMatchBIN in ('440393');
--799238137.00
 */
/* ADP Payroll BIN group */
select sum(amount)
  from SSRSReports.WebReportsUser.KYC_CASH_PROJ_2023_Finance_Data a
       inner join #terms1 t
	   on a.ATMInternalID = t.ATMInternalID
 where SettlementDate >= (select dt from #dates where varname = 'StartDate')
   and SettlementDate <= (select dt from #dates where varname = 'EndDate')
   and APBinMatchBIN in ('402018','402717','402718','411600','414346','416187','445785',
                         '451440','456628','467321','485340','522481','523680',
                         '524543','528197','528227','530327','41160001')
--1250971923.00

/*select sum(amount) as WDAmt2, settlementdate
into #adp_terms1
  from SSRSReports.WebReportsUser.KYC_CASH_PROJ_2023_Finance_Data a
       inner join #terms1 t
	   on a.ATMInternalID = t.ATMInternalID
 where SettlementDate >= (select dt from #dates where varname = 'StartDate')
   and SettlementDate <= (select dt from #dates where varname = 'EndDate')
   and APBinMatchBIN in ('402018','402717','402718','411600','414346','416187','445785',
                         '451440','456628','467321','485340','522481','523680',
                         '524543','528197','528227','530327','41160001')
group by settlementdate;

select sum(n_WD) as n_WD, sum(WDAmt) as WDAmt, SettlementDate into #adp_ssinput
from #ss_input
where SettlementDate >= (select dt from #dates where varname = 'StartDate')
   and SettlementDate <= (select dt from #dates where varname = 'EndDate')
   and APBinMatchBIN in ('402018','402717','402718','411600','414346','416187','445785',
                         '451440','456628','467321','485340','522481','523680',
                         '524543','528197','528227','530327','41160001')
group by SettlementDate;


select a.WDAmt-b.WDAmt2 as diff, a.SettlementDate
from #adp_ssinput a inner join #adp_terms1 b
on a.SettlementDate = b.settlementDate
where a.WDAmt-b.WDAmt2!=0
order by SettlementDate;


select sum(WDAmt) from #ss_input
where SettlementDate = '2022-08-31'
and APBinMatchBIN in ('402018','402717','402718','411600','414346','416187','445785',
                         '451440','456628','467321','485340','522481','523680',
                         '524543','528197','528227','530327','41160001')
	and govt_bin_flag = 0
	and Issuer = 'ADP'

select sum(WDAmt)
  from #ss_input
 where SettlementDate >= (select dt from #dates where varname = 'StartDate')
   and SettlementDate <= (select dt from #dates where varname = 'EndDate')
   and APBinMatchBIN in ('402018','402717','402718','411600','414346','416187','445785',
                         '451440','456628','467321','485340','522481','523680',
                         '524543','528197','528227','530327','41160001')
	and govt_bin_flag = 0
	and Issuer = 'ADP'
--1174828940.00

select sum(amount)
  from SSRSReports.WebReportsUser.KYC_CASH_PROJ_2023_Finance_Data a
       inner join #terms1 t
	   on a.ATMInternalID = t.ATMInternalID
 where SettlementDate >= (select dt from #dates where varname = 'StartDate')
   and SettlementDate <= (select dt from #dates where varname = 'EndDate')
   and APBinMatchBIN in ('402018','402717','402718','411600','414346','416187','445785',
                         '451440','456628','467321','485340','522481','523680',
                         '524543','528197','528227','530327','41160001');
--1235120504.00
*/

/* Comdata Payroll BIN group */
select sum(amount)
  from SSRSReports.WebReportsUser.KYC_CASH_PROJ_2023_Finance_Data a
       inner join #terms1 t
	   on a.ATMInternalID = t.ATMInternalID
 where SettlementDate >= (select dt from #dates where varname = 'StartDate')
   and SettlementDate <= (select dt from #dates where varname = 'EndDate')
   and APBinMatchBIN in ('502462','502790','511449','511516','519282','528847',
                         '548971','556736')
--423311525.00


/* Chime */
select sum(amount)
  from SSRSReports.WebReportsUser.KYC_CASH_PROJ_2023_Finance_Data a
       inner join #terms1 t
	   on a.ATMInternalID = t.ATMInternalID
 where SettlementDate >= (select dt from #dates where varname = 'StartDate')
   and SettlementDate <= (select dt from #dates where varname = 'EndDate')
   and APBinMatchBIN in ('498503', '423223', '421783', '400895', '447227', '486208');
--3734227291.00                                                                                                 


/* PNC Bank */
select sum(amount)
  from SSRSReports.WebReportsUser.KYC_CASH_PROJ_2023_Finance_Data a
       inner join #terms1 t
	   on a.ATMInternalID = t.ATMInternalID
 where SettlementDate >= (select dt from #dates where varname = 'StartDate')
   and SettlementDate <= (select dt from #dates where varname = 'EndDate')
   and APBinMatchBIN in ('400057','400123','403486','403487','403488','403489','403490','403491','403492','403493','403494',
						'403495','403496','403497','403968','403976','404982','404984','405218','407120','408109','410072',
						'422394','422997','424621','425704','425852','425914','431196','431640','432522','435760','438968',
						'439882','443040','443041','443042','443043','443044','443045','443046','443047','443048','443049',
						'443050','443051','443057','443060','443061','443062','443063','443064','443065','443066','443067',
						'443068','443069','443070','443071','443072','443600','443601','443603','445463','448596','448900',
						'448901','448903','448904','448909','448910','448911','448915','448920','448921','448928','448929',
						'448930','448931','448940','448941','448943','448944','448950','448951','448960','448961','448970',
						'448971','448980','448991','450468','450469','450470','463158','463404','463829','469083','471515',
						'471595','472201','473135','474397','475598','477762','479162','480423','480433','480704','480720',
						'481790','485705','485706','485707','485977','486511','486563','486688','487889','491870','500674',
						'500675','500676','500677','502409','503227','503823','529004','537946','540940','541359','541493',
						'541872','543107','543767','545848','545849','548200','548201','548210','548211','548220','548221',
						'548228','548229','548230','548231','548240','548241','548250','548251','548260','548261','553308',
						'556364','556365','556366','560236','560466','560470','564386','574023','585131','585689','586282',
						'588882');
--408,072,649

/*
select sum(amount)
  from ATMManagerM_TW.dbo.T_TxnDetail a with (nolock)
       inner join #terms1 t
	   on a.ATMInternalID = t.ATMInternalID
 where SettlementDate >= (select dt from #dates where varname = 'StartDate')
   and SettlementDate <= (select dt from #dates where varname = 'EndDate')
   and Txn = 1
   and TxnTypeID = 1
   and ResponseCodeId = 1
   and BankID in ('400057','400123','403486','403487','403488','403489','403490','403491','403492','403493','403494',
						'403495','403496','403497','403968','403976','404982','404984','405218','407120','408109','410072',
						'422394','422997','424621','425704','425852','425914','431196','431640','432522','435760','438968',
						'439882','443040','443041','443042','443043','443044','443045','443046','443047','443048','443049',
						'443050','443051','443057','443060','443061','443062','443063','443064','443065','443066','443067',
						'443068','443069','443070','443071','443072','443600','443601','443603','445463','448596','448900',
						'448901','448903','448904','448909','448910','448911','448915','448920','448921','448928','448929',
						'448930','448931','448940','448941','448943','448944','448950','448951','448960','448961','448970',
						'448971','448980','448991','450468','450469','450470','463158','463404','463829','469083','471515',
						'471595','472201','473135','474397','475598','477762','479162','480423','480433','480704','480720',
						'481790','485705','485706','485707','485977','486511','486563','486688','487889','491870','500674',
						'500675','500676','500677','502409','503227','503823','529004','537946','540940','541359','541493',
						'541872','543107','543767','545848','545849','548200','548201','548210','548211','548220','548221',
						'548228','548229','548230','548231','548240','548241','548250','548251','548260','548261','553308',
						'556364','556365','556366','560236','560466','560470','564386','574023','585131','585689','586282',
						'588882');

*/

/***********************************************************************
Part II

Allocate BIN group forecasts to the ATM level and create ATM level 
projection for all BINs and Summary of projections for distribution. 
***********************************************************************/

/***********************************************************************
Create Baseline: 

For established installs, build nine weeks of activity from four weeks in 
BaselineStart to BaselineEnd. 

For new installs (first transaction date after BaselineStart), use last
three weeks before forecast (NewBaseStart - NewBaseEnd), build nine weeks
of activity from these three weeks. 

Calculate the baseline first, then replicate the baseline to make 9 weeks. 

************************************************************************/

/* Use the following to restore #terms1. */

IF OBJECT_ID('tempdb..#terms1', 'U') IS NOT NULL 
   drop table #terms1;
	select *
	  into #terms1
	  from [SSRSReports].[WebReportsUser].[KYC_CASH_PROJ_TERMS1];

create index tmpAP1 on #terms1 (ATMInternalID);

select count(*) from #terms1
--52370

/* Restore #dates*/
IF OBJECT_ID('tempdb..#dates', 'U') IS NULL 
	select *
	into #dates
	from [SSRSReports].[WebReportsUser].[KYC_CASH_PROJ_DATES];

select * from #dates;

/***************************************************************
Check for reasonableness of baseline time period selection.  
***************************************************************/
/* **Total activity** on #terms1 units over baseline period +. */
select datepart(year, t.SettlementDate)*100 + datepart(week, t.SettlementDate) as year_week,
       sum(WithdrawTxns) as n_WD, 
	   sum(WithdrawAmt) as WDAmt
  from ATMManagerM.dbo.ATMTxnTotalsDaily as t WITH (NOLOCK)
       inner join #terms1 as b 
       on t.ATMInternalID = b.ATMInternalID
 where t.SettlementDate >= (select dt from #dates where varname = 'StartDate')
   and t.SettlementDate <= (select dt from #dates where varname = 'EndDate')
 group by datepart(year, t.SettlementDate)*100 + datepart(week, t.SettlementDate)
 order by datepart(year, t.SettlementDate)*100 + datepart(week, t.SettlementDate);

 
/*  Note: this is TOTAL dispense, not just baseline. Point is to make sure we don't use an outlier to 
          project near-term dispense without scaling. 
year_week	n_WD	WDAmt
202244	4978577	711747884.00
202245	5993479	939675618.87
202246	5291534	761613328.00
202247	4757986	694920920.00
202248	4548289	668314804.00
202249	5402360	868522042.00
202250	5189485	788432868.00
202251	4878567	724680020.00
202252	4974932	765482695.00
202253	4564772	721060815.00
202301	5133782	826514890.05
202302	4910596	715683370.00
202303	4746799	697855674.00
202304	4808080	709768923.26
202305	5728518	948102839.00
202306	5348174	804199362.50
202307	5198284	783815010.00
202308	5473890	886301815.00
202309	6277320	1082403953.00
202310	5508823	858644999.10
202311	5218610	797910485.00
202312	5033301	748686674.00
202313	5538726	875137008.00
202314	5779473	930029091.00
202315	5131976	762735564.00
202316	5122734	752529085.04
202317	5266506	796915762.00
202318	6152528	1012470472.00
202319	5449742	798539553.00
202320	5225766	762943052.00
202321	5286063	778908983.00
202322	5847271	945058079.00
202323	5553201	843384219.00
202324	5246207	771239491.00
202325	5185354	755929705.95
*/


/* Create table #new, with first transaction date > Start date of Baseline */

/*
IF OBJECT_ID('tempdb..#terms1', 'U') IS NULL
	select *
	into #terms1
	from [SSRSReports].[WebReportsUser].[KYC_CASH_PROJ_TERMS1]
*/

IF OBJECT_ID('tempdb..#new', 'U') IS NOT NULL
drop table #new 
select *
  into #new
  from #terms1
 where cast(AUDFD2 as date) > (select dt from #dates where varname = 'BaselineStart'); 
--381

create index tmpAP1 on #new (ATMInternalID);

select count(*)
  from #new;
 --196
   
IF OBJECT_ID('[SSRSReports].[WebReportsUser].[KYC_CASH_PROJ_#new]', 'U') IS NOT NULL 
   drop table [SSRSReports].[WebReportsUser].[KYC_CASH_PROJ_#new];
   select * 
   into [SSRSReports].[WebReportsUser].[KYC_CASH_PROJ_#new]
   from #new;
/* Base line for existing terminals that are not new */

IF OBJECT_ID('tempdb..#new', 'U') IS NOT NULL 
   drop table #new
select * 
   into #new
   from [SSRSReports].[WebReportsUser].[KYC_CASH_PROJ_#new];

IF OBJECT_ID('tempdb..#txn_base0', 'U') IS NOT NULL 
   drop table #txn_base0;
select t.ATMInternalID, 
       t.SettlementDate, 
	   t.WithdrawTxns, 
	   t.SurchargeTxns, 
	   t.WithdrawAmt
  into #txn_base0
  from [ATMManagerM].[dbo].[ATMTxnTotalsDaily] as t (nolock) 
       inner join #terms1 a on a.ATMInternalID = t.ATMInternalID
 where t.SettlementDate >= (select dt from #dates where varname = 'BaselineStart') 
   and t.SettlementDate <= (select dt from #dates where varname = 'BaselineEnd')
   and t.ATMInternalID not in (select ATMInternalID from #new);
--3153742
-- 5 mins 04/05/23
-- 6 mins 05/04/23
-- 8 mins 06/28/23

/* new terminals */

IF OBJECT_ID('tempdb..#txn_base2', 'U') IS NOT NULL 
   drop table #txn_base2;
select t.ATMInternalID, 
       t.SettlementDate, 
	   t.WithdrawTxns, 
	   t.SurchargeTxns, 
	   t.WithdrawAmt
  into #txn_base2
  from [ATMManagerM].[dbo].[ATMTxnTotalsDaily] as t (nolock) 
       inner join #new a on a.ATMInternalID = t.ATMInternalID
 where t.SettlementDate >= (select dt from #dates where varname = 'NewBaseStart') 
   and t.SettlementDate <= (select dt from #dates where varname = 'NewBaseEnd');


IF OBJECT_ID('tempdb..#txn_base', 'U') IS NOT NULL 
   drop table #txn_base;
select *
  into #txn_base 
  from (select *
          from #txn_base0

         union all

        select *
          from #txn_base2

       )x;

create index tmpAP3 on #txn_base (ATMInternalID);
create index tmpAP4 on #txn_base (SettlementDate);


select distinct SettlementDate
  from #txn_base;
--56

/* ATMTxnTotalsDaily has one row per ATM, ActivitDate, and SettlementDate. 
   At least 2 rows per Settlement Date as Activity typically settles on the same or next day, 
   sometimes 3 or 4, even 5. */


select ATMInternalID, 
       SettlementDate, 
	   count(*) as n_rec
  from #txn_base
 group by ATMInternalID, SettlementDate
having count(*) > 2;
--23504

/* What is the max number of ActivityDates for a SettlementDate in this sample? */
select max(n_rec)
from (select ATMInternalID, 
             SettlementDate, 
	         count(*) as n_rec
        from #txn_base
    group by ATMInternalID, SettlementDate
) counts
--5

select count(*) from #txn_base;
--3156722

IF OBJECT_ID('tempdb..#baseline', 'U') IS NOT NULL 
   drop table #baseline;
select ATMInternalID, 
       SettlementDate, 
	   sum(isnull(WithdrawTxns,0)) as n_WD, 
	   sum(isnull(WithdrawAmt,0)) as WDAmt
  into #baseline
  from #txn_base
 group by ATMInternalID, SettlementDate;
--3997156

create index tmpAP3 on #baseline (ATMInternalID);
create index tmpAP4 on #baseline (SettlementDate);


select *
  from #baseline
 where ATMInternalID = 264340
 order by SettlementDate;


select ATMInternalID, 
       SettlementDate, 
	   count(*) as n_rec
  from #baseline
 group by ATMInternalID, SettlementDate
having count(*) > 1;
--0

select SettlementDate, 
       sum(n_WD) as n_WD, 
	   sum(WDAmt) as WDAmt
  from #baseline
 group by SettlementDate
 order by SettlementDate;

select count(*) from #txn_base0;


select count(*) from #txn_base2;


select count(*) from #txn_base;


IF OBJECT_ID('[SSRSReports].[WebReportsUser].[KYC_CASH_PROJ_#baseline]', 'U') IS NOT NULL 
   drop table [SSRSReports].[WebReportsUser].[KYC_CASH_PROJ_#baseline];
   select * 
   into [SSRSReports].[WebReportsUser].[KYC_CASH_PROJ_#baseline]
   from #baseline;


IF OBJECT_ID('tempdb..#baseline', 'U') IS NOT NULL 
   drop table #baseline
select * 
   into #baseline
   from [SSRSReports].[WebReportsUser].[KYC_CASH_PROJ_#baseline]
   ;


/*************************************************************
Gather transactions during baseline for Comerica. These transactions
    will be removed from the baseline and will be replaced with the 
	forecast created in 003 CashProjection spreadsheet. 

Baseline: BaselineStart to BaselineEnd

For new installs (first transaction date after BaselineStart): 
NewBaseStart to NewBaseEnd

OK to use T_TxnDetail w/ BankID as no extended BINs sharing BankID
10/29/21 Added BankID 511563
**************************************************************/

/* established terminals baseline period */
IF OBJECT_ID('tempdb..#comerica0', 'U') IS NOT NULL 
   drop table #comerica0;
select t.ATMInternalID, 
       cast(t.SettlementDate as date) as SettlementDate, 
	   sum(case when t.txntypeid = 1 then 1 else 0 end) as n_WD, 
	   sum(amount) as WDAmt
  into #comerica0
  from ATMManagerM_TW.dbo.T_TxnDetail as t WITH (NOLOCK)
       inner join #terms1 as b 
       on t.ATMInternalID = b.ATMInternalID
 where t.SettlementDate >= (select dt from #dates where varname = 'BaselineStart') 
   and t.SettlementDate <= (select dt from #dates where varname = 'BaselineEnd')
   and t.TxnTypeID = 1            -- Withdrawal Transaction
   and t.ResponseCodeID = 1       -- Transaction Accepted
   and t.Txn = 1                  -- Is a Real Transaction
   and t.BankID in (533248, 511563)
   and t.ATMInternalID not in (select ATMInternalID from #new)
 group by t.ATMInternalID, cast(t.SettlementDate as date);

-- more than one hour 11/17/22
-- less than a minute 12/14/22
-- 6 mins 05/04/23


/* Dates for New Terminals */
IF OBJECT_ID('tempdb..#comerica2', 'U') IS NOT NULL 
   drop table #comerica2;
select t.ATMInternalID, 
       cast(t.SettlementDate as date) as SettlementDate, 
	   sum(case when t.txntypeid=1 then 1 else 0 end) as n_WD, 
	   sum(amount) as WDAmt
  into #comerica2
  from ATMManagerM_TW.dbo.T_TxnDetail as t WITH (NOLOCK)
       inner join #new as b 
       on t.ATMInternalID = b.ATMInternalID
 where t.SettlementDate >= (select dt from #dates where varname = 'NewBaseStart') 
   and t.SettlementDate <= (select dt from #dates where varname = 'NewBaseEnd')
   and t.TxnTypeID = 1
   and t.ResponseCodeID = 1
   and t.Txn = 1
   and t.BankID in (533248, 511563)
 group by t.ATMInternalID, cast(t.SettlementDate as date);
--74

IF OBJECT_ID('tempdb..#comerica', 'U') IS NOT NULL 
   drop table #comerica;
select *
  into #comerica 
  from (select *
          from #comerica0

         union all

        select *
          from #comerica2

       )x;
--307374

create index tmpAP3 on #comerica (ATMInternalID);
create index tmpAP4 on #comerica (SettlementDate);

select count(*) from #comerica0;


select count(*) from #comerica2;


select count(*) from #comerica;


select SettlementDate, sum(n_WD) as n_WD, sum(WDAmt) as WDAmt
  from #comerica
 group by SettlementDate
 order by SettlementDate;

select ATMInternalID, SettlementDate, count(*) as n_rec
  from #comerica
 group by ATMInternalID, SettlementDate
having count(*) > 1;
--0

IF OBJECT_ID('[SSRSReports].[WebReportsUser].[KYC_CASH_PROJ_#com]', 'U') IS NOT NULL 
   drop table [SSRSReports].[WebReportsUser].[KYC_CASH_PROJ_#com];
   select * 
   into [SSRSReports].[WebReportsUser].[KYC_CASH_PROJ_#com]
   from #comerica;
/*************************************************************
Gather transactions for baseline for Varo Money. These transactions
    will be removed from the baseline and will be replaced with the 
	forecast created in 003 CashProjection spreadsheet.

Baseline: BaselineStart to BaselineEnd 

For new installs (first transaction date after BaselineStart): 
NewBaseStart to NewBaseEnd

OK to use T_TxnDetail w/ BankID to pull history as there are no extended BINs
    sharing same BankID. 
**************************************************************/

IF OBJECT_ID('tempdb..#varo0', 'U') IS NOT NULL 
   drop table #varo0;
select t.ATMInternalID, 
       cast(t.SettlementDate as date) as SettlementDate, 
	   sum(case when t.txntypeid=1 then 1 else 0 end) as n_WD, 
	   sum(amount) as WDAmt
  into #varo0
  from ATMManagerM_TW.dbo.T_TxnDetail as t WITH (NOLOCK)
       inner join #terms1 as b 
       on t.ATMInternalID = b.ATMInternalID
 where t.SettlementDate >= (select dt from #dates where varname = 'BaselineStart')
   and t.SettlementDate <= (select dt from #dates where varname = 'BaselineEnd')
   and t.TxnTypeID = 1
   and t.ResponseCodeID = 1
   and t.Txn = 1
   and t.BankID in (487917, 433419)
   and t.ATMInternalID not in (select ATMInternalID from #new)
 group by t.ATMInternalID, cast(t.SettlementDate as date);
--22 mins 11/17/22
--17 mins 12/14/22
--5 mins 05/04/23


IF OBJECT_ID('tempdb..#varo2', 'U') IS NOT NULL 
   drop table #varo2;
select t.ATMInternalID, 
       cast(t.SettlementDate as date) as SettlementDate, 
	   sum(case when t.txntypeid=1 then 1 else 0 end) as n_WD, 
	   sum(amount) as WDAmt
  into #varo2
  from ATMManagerM_TW.dbo.T_TxnDetail as t WITH (NOLOCK)
       inner join #new as b 
       on t.ATMInternalID = b.ATMInternalID
 where t.SettlementDate >= (select dt from #dates where varname = 'NewBaseStart')
   and t.SettlementDate <= (select dt from #dates where varname = 'NewBaseEnd')
   and t.TxnTypeID = 1
   and t.ResponseCodeID = 1
   and t.Txn = 1
   and t.BankID in (487917, 433419)
 group by t.ATMInternalID, cast(t.SettlementDate as date);


IF OBJECT_ID('tempdb..#varo', 'U') IS NOT NULL 
   drop table #varo;
select *
  into #varo 
  from (select *
          from #varo0

         union all

        select *
          from #varo2

       )x;

create index tmpAP3 on #varo (ATMInternalID);
create index tmpAP4 on #varo (SettlementDate);

select count(*) from #varo0;

select count(*) from #varo2;


select count(*) from #varo;



select SettlementDate, sum(n_WD) as n_WD, sum(WDAmt) as WDAmt
  from #varo
 group by SettlementDate
 order by 1;

select ATMInternalID, SettlementDate, count(*) as n_rec
  from #varo
 group by ATMInternalID, SettlementDate
having count(*) > 1;
--0

IF OBJECT_ID('[SSRSReports].[WebReportsUser].[KYC_CASH_PROJ_#varo]', 'U') IS NOT NULL 
   drop table [SSRSReports].[WebReportsUser].[KYC_CASH_PROJ_#varo];
   select * 
   into [SSRSReports].[WebReportsUser].[KYC_CASH_PROJ_#varo]
   from #varo;
/***********************************************************************
Gather transactions for baseline for USBank-Private. These transactions
    will be removed from the baseline and will be replaced with the 
	forecast created in 003 CashProjection spreadsheet.

Baseline: BaselineStart to BaselineEnd 

For new installs (first transaction date after BaselineStart):
NewBaseStart to NewBaseEnd

2/9/21 tc Added extended BINs to USBank AP BIN group
2/11/22   Replaced US Bank - Govt UI BINs with US Bank - Private 
             payroll BINs
***********************************************************************/


IF OBJECT_ID('tempdb..#usbank0', 'U') IS NOT NULL 
   drop table #usbank0;
select b.ATMInternalID, 
       b.SettlementDate as SettlementDate,
	   sum(case when b.[txntypeid] = 1 then 1 else 0 end) as n_WD,
	   sum(case when b.[txntypeid] = 1 then amount else 0 end) as WDAmt
  into #usbank0
  from [SSRSReports].[WebReportsUser].[KYC_CASH_PROJ_2023_Finance_Data] b
       inner join #terms1 x 
	   on b.ATMInternalID = x.ATMInternalID
 where APBinMatchBIN in ('406069', '408031', '411238', '417021', '426752', 
                         '428191', '431582', '441814', '443161', '478665', 
                         '479841', '487081', '511562', '516175', '517750', 
                         '524913', '531462', '4168600', '4440838', '41455700', 
                         '43073111', '45841500', '45841550', '49990101')
   and b.SettlementDate >= (select dt from #dates where varname = 'BaselineStart')
   and b.SettlementDate <= (select dt from #dates where varname = 'BaselineEnd')
   and b.ATMInternalID not in (select ATMInternalID from #new)
 group by b.ATMInternalID, b.SettlementDate;

-- 05:38 03/08/23
-- 08:38 04/05/23
-- 1.5 min 05/04/23



IF OBJECT_ID('tempdb..#usbank2', 'U') IS NOT NULL 
   drop table #usbank2;
select b.ATMInternalID, 
       b.SettlementDate as SettlementDate,
	   sum(case when b.[txntypeid]=1 then 1 else 0 end) as n_WD,
	   sum(case when b.[txntypeid]=1 then amount else 0 end) as WDAmt
  into #usbank2
  from [SSRSReports].[WebReportsUser].[KYC_CASH_PROJ_2023_Finance_Data] b
       inner join #new x 
	   on b.ATMInternalID = x.ATMInternalID
 where APBinMatchBIN in ('406069', '408031', '411238', '417021', '426752', 
                         '428191', '431582', '441814', '443161', '478665', 
                         '479841', '487081', '511562', '516175', '517750', 
                         '524913', '531462', '4168600', '4440838', '41455700', 
                         '43073111', '45841500', '45841550', '49990101')
   and b.SettlementDate >= (select dt from #dates where varname = 'NewBaseStart')
   and b.SettlementDate <= (select dt from #dates where varname = 'NewBaseEnd')
 group by b.ATMInternalID, b.SettlementDate;
--70

IF OBJECT_ID('tempdb..#usbank', 'U') IS NOT NULL 
   drop table #usbank;
select *
  into #usbank 
  from (select *
          from #usbank0

         union all

        select *
          from #usbank2

       )x;

create index tmpAP3 on #usbank (ATMInternalID);
create index tmpAP4 on #usbank (SettlementDate);

select count(*) from #usbank0;

select count(*) from #usbank2;

select count(*) from #usbank;


select SettlementDate, sum(n_WD) as n_WD, sum(WDAmt) as WDAmt
  from #usbank
 group by SettlementDate
 order by SettlementDate;

select ATMInternalID, SettlementDate, count(*) as n_rec
  from #usbank
 group by ATMInternalID, SettlementDate
having count(*) > 1;
--0

IF OBJECT_ID('[SSRSReports].[WebReportsUser].[KYC_CASH_PROJ_#usb]', 'U') IS NOT NULL 
   drop table [SSRSReports].[WebReportsUser].[KYC_CASH_PROJ_#usb];
   select * 
   into [SSRSReports].[WebReportsUser].[KYC_CASH_PROJ_#usb]
   from #usbank;

/*******************************************************************************
Gather transactions for baseline for Skylight Financial Payroll. 
    These transactions will be removed from the baseline and will be replaced 
	with the forecast created in 003 CashProjection spreadsheet.

Baseline: BaselineStart to BaselineEnd 

For new installs (first transaction date after BaselineStart):
NewBaseStart to NewBaseEnd

Must pull transactions from KYC_CASH_PROJ_2023_Finance_Data as 
    there are extended AP BINs. 
*******************************************************************************/

IF OBJECT_ID('tempdb..#skylight0', 'U') IS NOT NULL 
   drop table #skylight0;
select b.ATMInternalID, 
       b.SettlementDate as SettlementDate,
	   sum(case when b.[txntypeid] = 1 then 1 else 0 end) as n_WD,
	   sum(case when b.[txntypeid] = 1 then amount else 0 end) as WDAmt
  into #skylight0
  from [SSRSReports].[WebReportsUser].[KYC_CASH_PROJ_2023_Finance_Data] b
       inner join #terms1 x 
	   on b.ATMInternalID = x.ATMInternalID
 where APBinMatchBIN in ('400619', '400620', '410194', '410195', '410196', 
                         '410197', '410808', '410809', '440810', '440813', 
                         '476972', '476973', '476974', '476975', '519325', 
                         '526284', '526285', '530083', '530383', '530389', 
                         '530680', '530690', '530767', '537664', '537697', 
                         '542495', '4315387', '4315388', '4315389', '40346203', 
                         '41434900', '41699200', '42530002', '42530003', '42530702', 
                         '42530703', '43153599', '43153699', '43153770', '45180500', 
                         '45180508', '45180509', '45180588', '45180590', '45180599', 
                         '48532000', '48532011', '48532060', '48532070', '48532081', 
                         '48532082', '48532088', '48532089', '48532090', '48532091', 
                         '48532092', '48532098', '48532099', '50134999', '50271599', 
                         '51331500', '53068400', '53762890', '58571099', '58664299')
   and b.SettlementDate >= (select dt from #dates where varname = 'BaselineStart')
   and b.SettlementDate <= (select dt from #dates where varname = 'BaselineEnd')
   and b.ATMInternalID not in (select ATMInternalID from #new)
 group by b.ATMInternalID, b.SettlementDate;


IF OBJECT_ID('tempdb..#skylight2', 'U') IS NOT NULL 
   drop table #skylight2;
select b.ATMInternalID, 
       b.SettlementDate as SettlementDate,
	   sum(case when b.[txntypeid]=1 then 1 else 0 end) as n_WD,
	   sum(case when b.[txntypeid]=1 then amount else 0 end) as WDAmt
  into #skylight2
  from [SSRSReports].[WebReportsUser].[KYC_CASH_PROJ_2023_Finance_Data] b
       inner join #new x 
	   on b.ATMInternalID = x.ATMInternalID
 where APBinMatchBIN in ('400619', '400620', '410194', '410195', '410196', 
                         '410197', '410808', '410809', '440810', '440813', 
                         '476972', '476973', '476974', '476975', '519325', 
                         '526284', '526285', '530083', '530383', '530389', 
                         '530680', '530690', '530767', '537664', '537697', 
                         '542495', '4315387', '4315388', '4315389', '40346203', 
                         '41434900', '41699200', '42530002', '42530003', '42530702', 
                         '42530703', '43153599', '43153699', '43153770', '45180500', 
                         '45180508', '45180509', '45180588', '45180590', '45180599', 
                         '48532000', '48532011', '48532060', '48532070', '48532081', 
                         '48532082', '48532088', '48532089', '48532090', '48532091', 
                         '48532092', '48532098', '48532099', '50134999', '50271599', 
                         '51331500', '53068400', '53762890', '58571099', '58664299')
   and b.SettlementDate >= (select dt from #dates where varname = 'NewBaseStart')
   and b.SettlementDate <= (select dt from #dates where varname = 'NewBaseEnd')
 group by b.ATMInternalID, b.SettlementDate;


IF OBJECT_ID('tempdb..#skylight', 'U') IS NOT NULL 
   drop table #skylight;
select *
  into #skylight 
  from (select *
          from #skylight0

         union all

        select *
          from #skylight2

       )x;

create index tmpAP3 on #skylight (ATMInternalID);
create index tmpAP4 on #skylight (SettlementDate);

select count(*) from #skylight0;


select count(*) from #skylight2;


select count(*) from #skylight;


select SettlementDate, sum(n_WD) as n_WD, sum(WDAmt) as WDAmt
  from #skylight
 group by SettlementDate
 order by SettlementDate;
 
select ATMInternalID, SettlementDate, count(*) as n_rec
  from #skylight
 group by ATMInternalID, SettlementDate
having count(*) > 1;
--0

IF OBJECT_ID('[SSRSReports].[WebReportsUser].[KYC_CASH_PROJ_#skf]', 'U') IS NOT NULL 
   drop table [SSRSReports].[WebReportsUser].[KYC_CASH_PROJ_#skf];
   select * 
   into [SSRSReports].[WebReportsUser].[KYC_CASH_PROJ_#skf]
   from #skylight;
/*************************************************************
Gather transactions for baseline for Payfare. These transactions
    will be removed from the baseline and will be replaced with the 
	forecast created in 003 CashProjection spreadsheet.

Baseline: BaselineStart to BaselineEnd 

For new installs (first transaction date after BaselineStart):
NewBaseStart to NewBaseEnd

AP BINs 444607, 511757, 520737
OK to use T_TxnDetail w/ BankID to pull history as there are no extended BINs
    sharing same BankID. 

10/1/21 Replaced BOA AP BIN group with Payfare
**************************************************************/

IF OBJECT_ID('tempdb..#payfare0', 'U') IS NOT NULL 
   drop table #payfare0;
select t.ATMInternalID, 
       cast(t.SettlementDate as date) as SettlementDate, 
	   sum(case when t.txntypeid=1 then 1 else 0 end) as n_WD, 
	   sum(amount) as WDAmt
  into #payfare0
  from ATMManagerM_TW.dbo.T_TxnDetail as t WITH (NOLOCK)
       inner join #terms1 as b 
       on t.ATMInternalID = b.ATMInternalID
 where t.SettlementDate >= (select dt from #dates where varname = 'BaselineStart')
   and t.SettlementDate <= (select dt from #dates where varname = 'BaselineEnd')
   and t.TxnTypeID = 1
   and t.ResponseCodeID = 1
   and t.Txn = 1
   and t.BankID in (444607, 511757, 520737,53889628)
   and t.ATMInternalID not in (select ATMInternalID from #new)
 group by t.ATMInternalID, cast(t.SettlementDate as date);

--01:20:09 07/27/22
--more than an hour 11/17/22
--7 mins 05/04/23

IF OBJECT_ID('tempdb..#payfare2', 'U') IS NOT NULL 
   drop table #payfare2;
select t.ATMInternalID, 
       cast(t.SettlementDate as date) as SettlementDate, 
	   sum(case when t.txntypeid=1 then 1 else 0 end) as n_WD, 
	   sum(amount) as WDAmt
  into #payfare2
  from ATMManagerM_TW.dbo.T_TxnDetail as t WITH (NOLOCK)
       inner join #new as b 
       on t.ATMInternalID = b.ATMInternalID
 where t.SettlementDate >= (select dt from #dates where varname = 'NewBaseStart')
   and t.SettlementDate <= (select dt from #dates where varname = 'NewBaseEnd')
   and t.TxnTypeID = 1
   and t.ResponseCodeID = 1
   and t.Txn = 1
   and t.BankID in (444607, 511757, 520737,53889628)
 group by t.ATMInternalID, cast(t.SettlementDate as date);
--48

IF OBJECT_ID('tempdb..#payfare', 'U') IS NOT NULL 
   drop table #payfare;
select *
  into #payfare 
  from (select *
          from #payfare0

         union all

        select *
          from #payfare2

       )x;


create index tmpAP3 on #payfare (ATMInternalID);
create index tmpAP4 on #payfare (SettlementDate);

select count(*) from #payfare0;


select count(*) from #payfare2;


select count(*) from #payfare;


select SettlementDate, sum(n_WD) as n_WD, sum(WDAmt) as WDAmt
  from #payfare
 group by SettlementDate
 order by SettlementDate;

select ATMInternalID, SettlementDate, count(*) as n_rec
  from #payfare
 group by ATMInternalID, SettlementDate
having count(*) > 1;
--0

IF OBJECT_ID('[SSRSReports].[WebReportsUser].[KYC_CASH_PROJ_#pf]', 'U') IS NOT NULL 
   drop table [SSRSReports].[WebReportsUser].[KYC_CASH_PROJ_#pf];
   select * 
   into [SSRSReports].[WebReportsUser].[KYC_CASH_PROJ_#pf]
   from #payfare;
/*************************************************************
Gather transactions for baseline for Money Network Payroll. 
    These transactions
    will be removed from the baseline and will be replaced with the 
	forecast created in 003 CashProjection spreadsheet.

Baseline: BaselineStart to BaselineEnd (9 weeks)
For new installs (first transaction date after BaselineStart):
NewBaseStart to NewBaseEnd

Couple extended BINs, so must use [SSRSReports].
	[WebReportsUser].[KYC_CASH_PROJ_2023_Finance_Data]
**************************************************************/

IF OBJECT_ID('tempdb..#mn0', 'U') IS NOT NULL 
   drop table #mn0;
select b.ATMInternalID, 
       b.SettlementDate as SettlementDate,
	   sum(case when b.[txntypeid] = 1 then 1 else 0 end) as n_WD,
	   sum(case when b.[txntypeid] = 1 then amount else 0 end) as WDAmt
  into #mn0
  from [SSRSReports].[WebReportsUser].[KYC_CASH_PROJ_2023_Finance_Data] b
       inner join #terms1 x 
	   on b.ATMInternalID = x.ATMInternalID
 where b.APBinMatchBIN in ('424015', '435889', '468271', '472776', '472777', '475024', '494321', '494340', '494341', '519509', 
                           '526262', '530133', '627391', '627396', '46321400', '60119065')
   and b.SettlementDate >= (select dt from #dates where varname = 'BaselineStart')
   and b.SettlementDate <= (select dt from #dates where varname = 'BaselineEnd')
   and b.ATMInternalID not in (select ATMInternalID from #new)
 group by b.ATMInternalID, b.SettlementDate;


IF OBJECT_ID('tempdb..#mn2', 'U') IS NOT NULL 
   drop table #mn2;
select b.ATMInternalID, 
       b.SettlementDate as SettlementDate,
	   sum(case when b.[txntypeid] = 1 then 1 else 0 end) as n_WD,
	   sum(case when b.[txntypeid] = 1 then amount else 0 end) as WDAmt
  into #mn2
  from [SSRSReports].[WebReportsUser].[KYC_CASH_PROJ_2023_Finance_Data] b
       inner join #new x 
	   on b.ATMInternalID = x.ATMInternalID
 where b.APBinMatchBIN in ('424015', '435889', '468271', '472776', '472777', '475024', '494321', '494340', '494341', '519509', 
                           '526262', '530133', '627391', '627396', '46321400', '60119065')
   and b.SettlementDate >= (select dt from #dates where varname = 'NewBaseStart')
   and b.SettlementDate <= (select dt from #dates where varname = 'NewBaseEnd')
 group by b.ATMInternalID, b.SettlementDate;


IF OBJECT_ID('tempdb..#mn', 'U') IS NOT NULL 
   drop table #mn;
select *
  into #mn 
  from (select *
          from #mn0

         union all

        select *
          from #mn2

       )x;


create index tmpAP3 on #mn (ATMInternalID);
create index tmpAP4 on #mn (SettlementDate);

select count(*) from #mn0;


select count(*) from #mn2;


select count(*) from #mn;



select SettlementDate, sum(n_WD) as n_WD, sum(WDAmt) as WDAmt
  from #mn
 group by SettlementDate
 order by SettlementDate;

select ATMInternalID, SettlementDate, count(*) as n_rec
  from #mn
 group by ATMInternalID, SettlementDate
having count(*) > 1;
--0

IF OBJECT_ID('[SSRSReports].[WebReportsUser].[KYC_CASH_PROJ_#mn]', 'U') IS NOT NULL 
   drop table [SSRSReports].[WebReportsUser].[KYC_CASH_PROJ_#mn];
   select * 
   into [SSRSReports].[WebReportsUser].[KYC_CASH_PROJ_#mn]
   from #mn;
/************************************************************************
Gather transactions for baseline for Cash App (SUTTON BANK). 
    These transactions will be removed from the baseline and will be 
	replaced with the forecast created in 003 CashProjection spreadsheet.

Baseline: BaselineStart to BaselineEnd (9 weeks)
For new installs (first transaction date after BaselineStart):
NewBaseStart to NewBaseend

4/6/22 Replace Chime-Stride with Cash App (SUTTON BANK). 
*************************************************************************/


IF OBJECT_ID('tempdb..#cashapp0', 'U') IS NOT NULL 
   drop table #cashapp0;
select b.ATMInternalID, 
       b.SettlementDate as SettlementDate,
	   sum(case when b.[txntypeid] = 1 then 1 else 0 end) as n_WD,
	   sum(case when b.[txntypeid] = 1 then amount else 0 end) as WDAmt
  into #cashapp0
  from [SSRSReports].[WebReportsUser].[KYC_CASH_PROJ_2023_Finance_Data] b
       inner join #terms1 x 
	   on b.ATMInternalID = x.ATMInternalID
 where b.APBinMatchBIN in ('440393')
   and b.SettlementDate >= (select dt from #dates where varname = 'BaselineStart')
   and b.SettlementDate <= (select dt from #dates where varname = 'BaselineEnd')
   and b.ATMInternalID not in (select ATMInternalID from #new)
 group by b.ATMInternalID, b.SettlementDate;



IF OBJECT_ID('tempdb..#cashapp2', 'U') IS NOT NULL 
   drop table #cashapp2;
select b.ATMInternalID, 
       b.SettlementDate as SettlementDate,
	   sum(case when b.[txntypeid] = 1 then 1 else 0 end) as n_WD,
	   sum(case when b.[txntypeid] = 1 then amount else 0 end) as WDAmt
  into #cashapp2
  from [SSRSReports].[WebReportsUser].[KYC_CASH_PROJ_2023_Finance_Data] b
       inner join #new x 
	   on b.ATMInternalID = x.ATMInternalID
 where b.APBinMatchBIN in ('440393')
   and b.SettlementDate >= (select dt from #dates where varname = 'NewBaseStart')
   and b.SettlementDate <= (select dt from #dates where varname = 'NewBaseEnd')
 group by b.ATMInternalID, b.SettlementDate;


IF OBJECT_ID('tempdb..#cashapp', 'U') IS NOT NULL 
   drop table #cashapp;
select *
  into #cashapp 
  from (select *
          from #cashapp0

         union all

        select *
          from #cashapp2

       )x;


create index tmpAP3 on #cashapp (ATMInternalID);
create index tmpAP4 on #cashapp (SettlementDate);

select count(*) from #cashapp0;


select count(*) from #cashapp2;


select count(*) from #cashapp;



select SettlementDate, sum(n_WD) as n_WD, sum(WDAmt) as WDAmt
  from #cashapp
 group by SettlementDate
 order by SettlementDate;

select ATMInternalID, SettlementDate, count(*) as n_rec
  from #cashapp
 group by ATMInternalID, SettlementDate
having count(*) > 1;
--0

IF OBJECT_ID('[SSRSReports].[WebReportsUser].[KYC_CASH_PROJ_#casha]', 'U') IS NOT NULL 
   drop table [SSRSReports].[WebReportsUser].[KYC_CASH_PROJ_#casha];
   select * 
   into [SSRSReports].[WebReportsUser].[KYC_CASH_PROJ_#casha]
   from #cashapp;
/********************************************************************************
Gather transactions for baseline for ADP Payroll. These 
    transactions will be removed from the baseline and will be replaced with the 
	forecast created in 003 CashProjection spreadsheet.

Baseline: BaselineStart to BaselineEnd 

For new installs (first transaction date after BaselineStart):
NewBaseStart to NewBaseEnd

Must pull transactions from KYC_CASH_PROJ_2023_Finance_Data as 
    there is an extended AP BIN. 
*********************************************************************************/

IF OBJECT_ID('tempdb..#adp0', 'U') IS NOT NULL 
   drop table #adp0;
select b.ATMInternalID, 
       b.SettlementDate as SettlementDate,
	   sum(case when b.[txntypeid] = 1 then 1 else 0 end) as n_WD,
	   sum(case when b.[txntypeid] = 1 then amount else 0 end) as WDAmt
  into #adp0
  from [SSRSReports].[WebReportsUser].[KYC_CASH_PROJ_2023_Finance_Data] b
       inner join #terms1 x 
	   on b.ATMInternalID = x.ATMInternalID
 where b.APBinMatchBIN in ('402018','402717','402718','411600','414346','416187','445785', '451440', '456628', 
                           '467321', '485340', '522481', '523680', '524543', '528197', '528227', '530327', '41160001')
   and b.SettlementDate >= (select dt from #dates where varname = 'BaselineStart')
   and b.SettlementDate <= (select dt from #dates where varname = 'BaselineEnd')
   and b.ATMInternalID not in (select ATMInternalID from #new)
 group by b.ATMInternalID, b.SettlementDate;



IF OBJECT_ID('tempdb..#adp2', 'U') IS NOT NULL 
   drop table #adp2;
select b.ATMInternalID, 
       b.SettlementDate as SettlementDate,
	   sum(case when b.[txntypeid]=1 then 1 else 0 end) as n_WD,
	   sum(case when b.[txntypeid]=1 then amount else 0 end) as WDAmt
  into #adp2
  from [SSRSReports].[WebReportsUser].[KYC_CASH_PROJ_2023_Finance_Data] b
       inner join #new x 
	   on b.ATMInternalID = x.ATMInternalID
 where b.APBinMatchBIN in ('402018','402717','402718','411600','414346','416187','445785', '451440', '456628', 
                           '467321', '485340', '522481', '523680', '524543', '528197', '528227', '530327', '41160001')
   and b.SettlementDate >= (select dt from #dates where varname = 'NewBaseStart')
   and b.SettlementDate <= (select dt from #dates where varname = 'NewBaseEnd')
 group by b.ATMInternalID, b.SettlementDate;


IF OBJECT_ID('tempdb..#adp', 'U') IS NOT NULL 
   drop table #adp;
select *
  into #adp 
  from (select *
          from #adp0

         union all

        select *
          from #adp2

       )x;


create index tmpAP3 on #adp (ATMInternalID);
create index tmpAP4 on #adp (SettlementDate);

select count(*) from #adp0;


select count(*) from #adp2;


select count(*) from #adp;



select SettlementDate, sum(n_WD) as n_WD, sum(WDAmt) as WDAmt
  from #adp
 group by SettlementDate
 order by SettlementDate;

select ATMInternalID, SettlementDate, count(*) as n_rec
  from #adp
 group by ATMInternalID, SettlementDate
having count(*) > 1;
--0

IF OBJECT_ID('[SSRSReports].[WebReportsUser].[KYC_CASH_PROJ_#adp]', 'U') IS NOT NULL 
   drop table [SSRSReports].[WebReportsUser].[KYC_CASH_PROJ_#adp];
   select * 
   into [SSRSReports].[WebReportsUser].[KYC_CASH_PROJ_#adp]
   from #adp;
/*************************************************************************************
Gather transactions for baseline for Comdata Payroll BINs. 
    These transactions will be removed from the baseline and will be replaced with the 
	forecast created in 003 CashProjection spreadsheet.

Baseline: BaselineStart to BaselineEnd 

For new installs (first transaction date after BaselineStart):
NewBaseStart to NewBaseEnd

No extended BINs, so can use T_TxnDetail

***************************************************************************************/

IF OBJECT_ID('tempdb..#comdata0', 'U') IS NOT NULL 
   drop table #comdata0;
select t.ATMInternalID, 
       cast(t.SettlementDate as date) as SettlementDate, 
	   sum(case when t.txntypeid=1 then 1 else 0 end) as n_WD, 
	   sum(amount) as WDAmt
  into #comdata0
  from ATMManagerM_TW.dbo.T_TxnDetail as t WITH (NOLOCK)
       inner join #terms1 as b 
       on t.ATMInternalID = b.ATMInternalID
 where t.SettlementDate >= (select dt from #dates where varname = 'BaselineStart')
   and t.SettlementDate <= (select dt from #dates where varname = 'BaselineEnd')
   and t.TxnTypeID = 1
   and t.ResponseCodeID = 1
   and t.Txn = 1
   and t.BankID in (502462, 502790, 511449, 511516, 519282, 528847, 548971, 556736)
   and t.ATMInternalID not in (select ATMInternalID from #new)
 group by t.ATMInternalID, cast(t.SettlementDate as date);

-- more than an hour 11/17/22
-- 7 mins 05/04/23

IF OBJECT_ID('tempdb..#comdata2', 'U') IS NOT NULL 
   drop table #comdata2;
select t.ATMInternalID, 
       cast(t.SettlementDate as date) as SettlementDate, 
	   sum(case when t.txntypeid=1 then 1 else 0 end) as n_WD, 
	   sum(amount) as WDAmt
  into #comdata2
  from ATMManagerM_TW.dbo.T_TxnDetail as t WITH (NOLOCK)
       inner join #new as b 
       on t.ATMInternalID = b.ATMInternalID
 where t.SettlementDate >= (select dt from #dates where varname = 'NewBaseStart')
   and t.SettlementDate <= (select dt from #dates where varname = 'NewBaseEnd')
   and t.TxnTypeID = 1
   and t.ResponseCodeID = 1
   and t.Txn = 1
   and t.BankID in (502462, 502790, 511449, 511516, 519282, 528847, 548971, 556736)
 group by t.ATMInternalID, cast(t.SettlementDate as date);



IF OBJECT_ID('tempdb..#comdata', 'U') IS NOT NULL 
   drop table #comdata;
select *
  into #comdata 
  from (select *
          from #comdata0

         union all

        select *
          from #comdata2

       )x;


create index tmpAP3 on #comdata (ATMInternalID);
create index tmpAP4 on #comdata (SettlementDate);

select count(*) from #comdata0;


select count(*) from #comdata2;


select count(*) from #comdata;



select SettlementDate, sum(n_WD) as n_WD, sum(WDAmt) as WDAmt
  from #comdata
 group by SettlementDate
 order by SettlementDate;

select ATMInternalID, SettlementDate, count(*) as n_rec
  from #comdata
 group by ATMInternalID, SettlementDate
having count(*) > 1;
--0

IF OBJECT_ID('[SSRSReports].[WebReportsUser].[KYC_CASH_PROJ_#comd]', 'U') IS NOT NULL 
   drop table [SSRSReports].[WebReportsUser].[KYC_CASH_PROJ_#comd];
   select * 
   into [SSRSReports].[WebReportsUser].[KYC_CASH_PROJ_#comd]
   from #comdata;
/**************************************************************************************
Gather transactions for baseline for Chime. Two extended BINs were converted 
    to Allpoint effective 5/5/21. These transactions will be removed from the baseline 
	and will be replaced with the forecast created in 003 CashProjection spreadsheet.

Baseline: BaselineStart to BaselineEnd 

For new installs (first transaction date after BaselineStart):
NewBaseStart to NewBaseEnd
10/29/21 Chime changed AP BINs, removed extended BINs and added 6-digit BINs. 
         Made those changes below. 
4/6/22   Merge Chime-Stride and Chime-Bancorp into Chime. 
***************************************************************************************/

IF OBJECT_ID('tempdb..#chime0', 'U') IS NOT NULL 
   drop table #chime0;
select b.ATMInternalID, 
       b.SettlementDate as SettlementDate,
	   sum(case when b.[txntypeid] = 1 then 1 else 0 end) as n_WD,
	   sum(case when b.[txntypeid] = 1 then amount else 0 end) as WDAmt
  into #chime0
  from [SSRSReports].[WebReportsUser].[KYC_CASH_PROJ_2023_Finance_Data] b
       inner join #terms1 x 
	   on b.ATMInternalID = x.ATMInternalID
 where b.APBinMatchBIN in ('498503', '423223', '421783', '400895', '447227', '486208')
   and b.SettlementDate >= (select dt from #dates where varname = 'BaselineStart')
   and b.SettlementDate <= (select dt from #dates where varname = 'BaselineEnd')
   and b.ATMInternalID not in (select ATMInternalID from #new)
 group by b.ATMInternalID, b.SettlementDate;

IF OBJECT_ID('tempdb..#chime2', 'U') IS NOT NULL 
   drop table #chime2;
select b.ATMInternalID, 
       b.SettlementDate as SettlementDate,
	   sum(case when b.[txntypeid]=1 then 1 else 0 end) as n_WD,
	   sum(case when b.[txntypeid]=1 then amount else 0 end) as WDAmt
  into #chime2
  from [SSRSReports].[WebReportsUser].[KYC_CASH_PROJ_2023_Finance_Data] b
       inner join #new x 
	   on b.ATMInternalID = x.ATMInternalID
 where b.APBinMatchBIN in ('498503', '423223', '421783', '400895', '447227', '486208')
   and b.SettlementDate >= (select dt from #dates where varname = 'NewBaseStart')
   and b.SettlementDate <= (select dt from #dates where varname = 'NewBaseEnd')
 group by b.ATMInternalID, b.SettlementDate;

IF OBJECT_ID('tempdb..#chime', 'U') IS NOT NULL 
   drop table #chime;
select *
  into #chime 
  from (select *
          from #chime0

         union all

        select *
          from #chime2

       )x;

create index tmpAP3 on #chime (ATMInternalID);
create index tmpAP4 on #chime (SettlementDate);

select count(*) from #chime0;

select count(*) from #chime2;

select count(*) from #chime;


select SettlementDate, sum(n_WD) as n_WD, sum(WDAmt) as WDAmt
  from #chime
 group by SettlementDate
 order by SettlementDate;

select ATMInternalID, SettlementDate, count(*) as n_rec
  from #chime
 group by ATMInternalID, SettlementDate
having count(*) > 1;
--0

IF OBJECT_ID('[SSRSReports].[WebReportsUser].[KYC_CASH_PROJ_#chime]', 'U') IS NOT NULL 
   drop table [SSRSReports].[WebReportsUser].[KYC_CASH_PROJ_#chime];
   select * 
   into [SSRSReports].[WebReportsUser].[KYC_CASH_PROJ_#chime]
   from #chime;

/************************************************************************
Gather transactions for baseline for PNC Bank. 
    These transactions will be removed from the baseline and will be 
	replaced with the forecast created in 003 CashProjection spreadsheet.

Baseline: BaselineStart to BaselineEnd (9 weeks)
For new installs (first transaction date after BaselineStart):
NewBaseStart to NewBaseend

7/27/22 Add PNC BINS. 
*************************************************************************/


IF OBJECT_ID('tempdb..#pnc0', 'U') IS NOT NULL 
   drop table #pnc0;
select b.ATMInternalID, 
       b.SettlementDate as SettlementDate,
	   sum(case when b.[txntypeid] = 1 then 1 else 0 end) as n_WD,
	   sum(case when b.[txntypeid] = 1 then amount else 0 end) as WDAmt
  into #pnc0
  from [SSRSReports].[WebReportsUser].[KYC_CASH_PROJ_2023_Finance_Data] b
       inner join #terms1 x 
	   on b.ATMInternalID = x.ATMInternalID
 where b.APBinMatchBIN in ('400057','400123','403486','403487','403488',
							'403489','403490','403491','403492','403493',
							'403494','403495','403496','403497','403968',
							'403976','404982','404984','405218','407120',
							'408109','410072','422394','422997','424621',
							'425704','425852','425914','431196','431640',
							'432522','435760','438968','439882','443040',
							'443041','443042','443043','443044','443045',
							'443046','443047','443048','443049','443050',
							'443051','443057','443060','443061','443062',
							'443063','443064','443065','443066','443067',
							'443068','443069','443070','443071','443072',
							'443600','443601','443603','445463','448596',
							'448900','448901','448903','448904','448909',
							'448910','448911','448915','448920','448921',
							'448928','448929','448930','448931','448940',
							'448941','448943','448944','448950','448951',
							'448960','448961','448970','448971','448980',
							'448991','450468','450469','450470','463158',
							'463404','463829','469083','471515','471595',
							'472201','473135','474397','475598','477762',
							'479162','480423','480433','480704','480720',
							'481790','485705','485706','485707','485977',
							'486511','486563','486688','487889','491870',
							'500674','500675','500676','500677','502409',
							'503227','503823','529004','537946','540940',
							'541359','541493','541872','543107','543767',
							'545848','545849','548200','548201','548210',
							'548211','548220','548221','548228','548229',
							'548230','548231','548240','548241','548250',
							'548251','548260','548261','553308','556364',
							'556365','556366','560236','560466','560470',
							'564386','574023','585131','585689','586282',
							'588882')
   and b.SettlementDate >= (select dt from #dates where varname = 'BaselineStart')
   and b.SettlementDate <= (select dt from #dates where varname = 'BaselineEnd')
   and b.ATMInternalID not in (select ATMInternalID from #new)
 group by b.ATMInternalID, b.SettlementDate;

-- 5 mins 04/05/23


IF OBJECT_ID('tempdb..#pnc2', 'U') IS NOT NULL 
   drop table #pnc2;
select b.ATMInternalID, 
       b.SettlementDate as SettlementDate,
	   sum(case when b.[txntypeid] = 1 then 1 else 0 end) as n_WD,
	   sum(case when b.[txntypeid] = 1 then amount else 0 end) as WDAmt
  into #pnc2
  from [SSRSReports].[WebReportsUser].[KYC_CASH_PROJ_2023_Finance_Data] b
       inner join #new x 
	   on b.ATMInternalID = x.ATMInternalID
 where b.APBinMatchBIN in ('400057','400123','403486','403487','403488',
							'403489','403490','403491','403492','403493',
							'403494','403495','403496','403497','403968',
							'403976','404982','404984','405218','407120',
							'408109','410072','422394','422997','424621',
							'425704','425852','425914','431196','431640',
							'432522','435760','438968','439882','443040',
							'443041','443042','443043','443044','443045',
							'443046','443047','443048','443049','443050',
							'443051','443057','443060','443061','443062',
							'443063','443064','443065','443066','443067',
							'443068','443069','443070','443071','443072',
							'443600','443601','443603','445463','448596',
							'448900','448901','448903','448904','448909',
							'448910','448911','448915','448920','448921',
							'448928','448929','448930','448931','448940',
							'448941','448943','448944','448950','448951',
							'448960','448961','448970','448971','448980',
							'448991','450468','450469','450470','463158',
							'463404','463829','469083','471515','471595',
							'472201','473135','474397','475598','477762',
							'479162','480423','480433','480704','480720',
							'481790','485705','485706','485707','485977',
							'486511','486563','486688','487889','491870',
							'500674','500675','500676','500677','502409',
							'503227','503823','529004','537946','540940',
							'541359','541493','541872','543107','543767',
							'545848','545849','548200','548201','548210',
							'548211','548220','548221','548228','548229',
							'548230','548231','548240','548241','548250',
							'548251','548260','548261','553308','556364',
							'556365','556366','560236','560466','560470',
							'564386','574023','585131','585689','586282',
							'588882')
   and b.SettlementDate >= (select dt from #dates where varname = 'NewBaseStart')
   and b.SettlementDate <= (select dt from #dates where varname = 'NewBaseEnd')
 group by b.ATMInternalID, b.SettlementDate;

IF OBJECT_ID('tempdb..#pnc', 'U') IS NOT NULL 
   drop table #pnc;
select *
  into #pnc 
  from (select *
          from #pnc0

         union all

        select *
          from #pnc2

       )x;

create index tmpAP3 on #pnc (ATMInternalID);
create index tmpAP4 on #pnc (SettlementDate);

select count(*) from #pnc0;

select count(*) from #pnc2;

select count(*) from #pnc;


select SettlementDate, sum(n_WD) as n_WD, sum(WDAmt) as WDAmt
  from #pnc
 group by SettlementDate
 order by SettlementDate;

select ATMInternalID, SettlementDate, count(*) as n_rec
  from #pnc
 group by ATMInternalID, SettlementDate
having count(*) > 1;
--0

IF OBJECT_ID('[SSRSReports].[WebReportsUser].[KYC_CASH_PROJ_#pnc]', 'U') IS NOT NULL 
   drop table [SSRSReports].[WebReportsUser].[KYC_CASH_PROJ_#pnc];
   select * 
   into [SSRSReports].[WebReportsUser].[KYC_CASH_PROJ_#pnc]
   from #pnc;

/*************************************************************
Create adjusted baseline:
    Total daily transactions, historical transactions for Comerica, Varo, 
	US Bank, Payfare, MN, Sky, CashApp, USBank2, Comerica UI, Chime,PNC 
	and the rest of the transactions 
	(total - comerica - varo - usbank - Payfare - mn - skylight - cashapp 
	       - usbank_notap - comerica_ui - chime - pnc ), 
	also called baseline. 

Baseline: BaselineStart to BaselineEnd 

For new installs (first transaction date after BaselineStart):
NewBaseStart to NewBaseEnd (3 weeks)
**************************************************************/
/* Look at distribution of transactions */

/*recover temporary tables*/
--terms1
IF OBJECT_ID('tempdb..#terms1', 'U') IS NOT NULL 
   drop table #terms1;
	select *
	  into #terms1
	  from [SSRSReports].[WebReportsUser].[KYC_CASH_PROJ_TERMS1];

create index tmpAP1 on #terms1 (ATMInternalID);

select count(*) from #terms1
--52370

--dates
IF OBJECT_ID('tempdb..#dates', 'U') IS NULL 
	select *
	into #dates
	from [SSRSReports].[WebReportsUser].[KYC_CASH_PROJ_DATES_JUL2];

select * from #dates;

--new terms
IF OBJECT_ID('tempdb..#new', 'U') IS NOT NULL 
   drop table #new;
   select * 
   into #new
   from [SSRSReports].[WebReportsUser].[KYC_CASH_PROJ_#new];

--baseline
IF OBJECT_ID('tempdb..#baseline', 'U') IS NULL 
   select * into #baseline
   from [SSRSReports].[WebReportsUser].[KYC_CASH_PROJ_#baseline]
   ;

--comerica:
IF OBJECT_ID('tempdb..#comerica', 'U') IS NULL 
   select * into #comerica
   from [SSRSReports].[WebReportsUser].[KYC_CASH_PROJ_#com]
   ;

--varo:
IF OBJECT_ID('tempdb..#varo', 'U') IS NULL 
   select * into #varo
   from [SSRSReports].[WebReportsUser].[KYC_CASH_PROJ_#varo]
   ;

--usbank
IF OBJECT_ID('tempdb..#usbank', 'U') IS NULL 
   select * into #usbank
   from [SSRSReports].[WebReportsUser].[KYC_CASH_PROJ_#usb]
   ;

--payfare
IF OBJECT_ID('tempdb..#payfare', 'U') IS NULL 
   select * into #payfare
   from [SSRSReports].[WebReportsUser].[KYC_CASH_PROJ_#pf]
   ;

--skylight
IF OBJECT_ID('tempdb..#skylight', 'U') IS NULL 
   select * into #skylight
   from [SSRSReports].[WebReportsUser].[KYC_CASH_PROJ_#skf]
   ;

--mn
IF OBJECT_ID('tempdb..#mn', 'U') IS NULL 
   select * into #mn
   from [SSRSReports].[WebReportsUser].[KYC_CASH_PROJ_#mn]
   ;

--cashapp
IF OBJECT_ID('tempdb..#cashapp', 'U') IS NULL 
   select * into #cashapp
   from [SSRSReports].[WebReportsUser].[KYC_CASH_PROJ_#casha]
   ;

--adp
IF OBJECT_ID('tempdb..#adp', 'U') IS NULL 
   select * into #adp
   from [SSRSReports].[WebReportsUser].[KYC_CASH_PROJ_#adp]
   ;

--comdata
IF OBJECT_ID('tempdb..#comdata', 'U') IS NULL 
   select * into #comdata
   from [SSRSReports].[WebReportsUser].[KYC_CASH_PROJ_#comd]
   ;

--chime
IF OBJECT_ID('tempdb..#chime', 'U') IS NULL 
   select * into #chime
   from [SSRSReports].[WebReportsUser].[KYC_CASH_PROJ_#chime]
   ;

--pnc
IF OBJECT_ID('tempdb..#pnc', 'U') IS NULL 
   select * into #pnc
   from [SSRSReports].[WebReportsUser].[KYC_CASH_PROJ_#pnc]
   ;

select settlementdate,
       count(*)
  from #baseline
 group by settlementdate
 order by settlementdate;

IF OBJECT_ID('tempdb..#baseline1', 'U') IS NOT NULL 
   drop table #baseline1;
select a.*, 
	   isnull(b.n_WD,0) as n_WD_Comerica,
	   isnull(b.WDAmt,0) as WDAmt_Comerica,

	   isnull(b1.n_WD,0) as n_WD_Varo,
	   isnull(b1.WDAmt,0) as WDAmt_Varo,

	   isnull(b2.n_WD,0) as n_WD_USBank,
	   isnull(b2.WDAmt,0) as WDAmt_USBank,
	   
	   isnull(b5.n_WD, 0) as n_WD_Sky,
	   isnull(b5.WDAmt, 0) as WDAmt_Sky,
	   
	   isnull(b3.n_WD,0) as n_WD_Payfare,
	   isnull(b3.WDAmt,0) as WDAmt_Payfare,

	   isnull(b4.n_WD,0) as n_WD_MN,
	   isnull(b4.WDAmt,0) as WDAmt_MN,

	   isnull(b6.n_WD, 0) as n_WD_CashApp,
	   isnull(b6.WDAmt, 0) as WDAmt_CashApp,
	   
	   isnull(b7.n_WD, 0) as n_WD_ADP,
	   isnull(b7.WDAmt, 0) as WDAmt_ADP,
	   
	   isnull(b8.n_WD, 0) as n_WD_Comdata,
	   isnull(b8.WDAmt, 0) as WDAmt_Comdata,
	   
	   isnull(b9.n_WD, 0) as n_WD_Chime,
	   isnull(b9.WDAmt, 0) as WDAmt_Chime,

	   isnull(b10.n_WD, 0) as n_WD_PNC,
	   isnull(b10.WDAmt, 0) as WDAmt_PNC


  into #baseline1
  from #baseline a

        left join #comerica b 
		on a.ATMInternalID = b.ATMInternalID 
		and a.SettlementDate = b.SettlementDate

        left join #varo b1 
		on a.ATMInternalID = b1.ATMInternalID 
		and a.SettlementDate = b1.SettlementDate

        left join #usbank b2 
		on a.ATMInternalID = b2.ATMInternalID 
		and a.SettlementDate = b2.SettlementDate

        left join #payfare b3 
		on a.ATMInternalID = b3.ATMInternalID 
		and a.SettlementDate = b3.SettlementDate

        left join #mn b4 
		on a.ATMInternalID = b4.ATMInternalID 
		and a.SettlementDate = b4.SettlementDate
		
		left join #skylight b5
		on a.ATMInternalID = b5.ATMInternalID
		and a.SettlementDate = b5.SettlementDate
		
		left join #cashapp b6
		on a.ATMInternalID = b6.ATMInternalID
		and a.SettlementDate = b6.SettlementDate
		
		left join #adp b7
		on a.ATMInternalID = b7.ATMInternalID
		and a.SettlementDate = b7.SettlementDate		
		
		left join #comdata b8
		on a.ATMInternalID = b8.ATMInternalID
		and a.SettlementDate = b8.SettlementDate
		
		left join #chime b9
		on a.ATMInternalID = b9.ATMInternalID
		and a.SettlementDate = b9.SettlementDate
		
		left join #pnc b10
		on a.ATMInternalID = b10.ATMInternalID
		and a.SettlementDate = b10.SettlementDate;


IF OBJECT_ID('tempdb..#base_adj', 'U') IS NOT NULL 
   drop table #base_adj;
select a.*, 
 	   a.n_WD - a.n_WD_Comerica - a.n_WD_Varo - a.n_WD_USBank - a.n_WD_Payfare - a.n_WD_MN - a.n_WD_Sky 
	          - a.n_WD_CashApp - a.n_WD_ADP - a.n_WD_Comdata - a.n_WD_Chime - a.n_WD_PNC as n_WD_Baseline,
 	   a.WDAmt - a.WDAmt_Comerica - a.WDAmt_Varo - a.WDAmt_USBank - a.WDAmt_Payfare - a.WDAmt_MN - a.WDAmt_Sky 
	          - a.WDAmt_CashApp - a.WDAmt_ADP - a.WDAmt_Comdata - a.WDAmt_Chime - a.WDAmt_PNC as WDAmt_Baseline
  into #base_adj
  from #baseline1 a;

/*
select sum(WDAmt) as n_WD, 
       sum(WDAmt_Comerica) as n_WD_Comerica, 
	   sum(WDAmt_Varo) as n_WD_Varo, 
	   sum(WDAmt_USBank) as n_WD_USBank, 
	   sum(WDAmt_Payfare) as n_WD_Payfare, 
	   sum(WDAmt_MN) as n_WD_MN, 
	   sum(WDAmt_Sky) as n_WD_Sky, 
	   sum(WDAmt_CashApp) as n_WD_CashApp, 
	   sum(WDAmt_ADP) as n_WD_ADP, 
	   sum(WDAmt_Comdata) as n_WD_Comdata, 
	   sum(WDAmt_Chime) as n_WD_Chime,
	   sum(WDAmt_Baseline) as n_WD_Baseline
from #base_adj
*/

select SettlementDate, 
       sum(n_WD_Baseline) as n_WD, 
	   sum(WDAmt_Baseline) as WDAmt
  from #base_adj
 group by SettlementDate
 order by 1;

/* Should not be any of these. Results here indicate a problem with the data. */
select * 
  from #base_adj
 where n_wd_baseline < 0;
--0 rows


/*
select ATMInternalID, 
       SettlementDate, 
	   ActivityTime, 
	   InternalID, 
	   BankID, 
	   Txn, 
	   TxnTypeID, 
	   ResponseCodeID, 
	   RejectCodeID, 
	   Amount
  from ATMManagerM_TW.dbo.T_TxnDetail with (nolock)
 where ATMInternalID = '328104'
   and SettlementDate = '2021-12-21 00:00:00.000'
   and amount < 0

ATMInternalID	SettlementDate			ActivityTime			InternalID	BankID	Txn	TxnTypeID	ResponseCodeID	RejectCodeID	Amount
328104	2021-12-21 00:00:00.000	2021-12-15 14:18:48.000	7918377973	427535	1	1	1	3	-134322.95
328104	2021-12-21 00:00:00.000	2021-12-15 14:18:48.000	7918377974	427535	1	1	1	3	-134322.96*/
/*
select * 
  from #base_adj
 where  ATMInternalID = '328104'
   and SettlementDate = '2021-12-21 00:00:00.000'; 

ATMInternalID	SettlementDate			n_WD	WDAmt		n_WD_Comerica	WDAmt_Comerica	n_WD_Varo	WDAmt_Varo	n_WD_USBank	WDAmt_USBank	n_WD_Sky	WDAmt_Sky	n_WD_Payfare	WDAmt_Payfare	n_WD_MN	WDAmt_MN	n_WD_CashApp	WDAmt_CashApp	n_WD_ADP	WDAmt_ADP	n_WD_Comdata	WDAmt_Comdata	n_WD_chime	WDAmt_chime	n_WD_Baseline	WDAmt_Baseline
328104			2021-12-21 00:00:00.000	53		-257025.91	0				0.00			0			0.00		0			0.00			0			0.00		1				20.00			0		0.00		0				0.00			0			0.00		0				0.00			0			0.00		52				-257045.91 
*/
/*
update #base_adj
   set wdamt_baseline = wdamt_baseline + 268645.91, 
       WDAmt = WDAmt + 268645.91
 where  ATMInternalID = '328104'
   and SettlementDate = '2021-12-21 00:00:00.000'; 
--1 row affected

select * 
  from #base_adj
 where  ATMInternalID = '328104'
   and SettlementDate = '2021-12-21 00:00:00.000'; 

ATMInternalID	SettlementDate			n_WD	WDAmt		n_WD_Comerica	WDAmt_Comerica	n_WD_Varo	WDAmt_Varo	n_WD_USBank	WDAmt_USBank	n_WD_Sky	WDAmt_Sky	n_WD_Payfare	WDAmt_Payfare	n_WD_MN	WDAmt_MN	n_WD_CashApp	WDAmt_CashApp	n_WD_ADP	WDAmt_ADP	n_WD_Comdata	WDAmt_Comdata	n_WD_Chime	WDAmt_Chime	n_WD_Baseline	WDAmt_Baseline
328104			2021-12-21 00:00:00.000	53		11620.00	0				0.00			0			0.00		0			0.00			0			0.00		1				20.00			0		0.00		0				0.00			0			0.00		0				0.00			0			0.00		52				11600.00
*/   
   
select * 
  from #base_adj
 where  wdamt_baseline < 0;
--11 rows, mostly baseline having small negative values (reversals)

update #base_adj
   set wdamt_baseline = -wdamt_baseline
 where wdamt_baseline < 0;


create index tmpAP3 on #base_adj (ATMInternalID);
create index tmpAP4 on #base_adj (SettlementDate);

select ATMInternalID, 
       SettlementDate, 
	   count(*) as n_rec
  from #base_adj
 group by ATMInternalID, SettlementDate
having count(*) > 1;
--0
  
/* save #base_adj in persistent table */

IF OBJECT_ID('SSRSReports.WebReportsUser.KYC_CASH_PROJ_#base_adj', 'U') IS NOT NULL 
   drop table SSRSReports.WebReportsUser.KYC_CASH_PROJ_#base_adj;
select *
  into SSRSReports.WebReportsUser.KYC_CASH_PROJ_#base_adj
  from #base_adj;


/* restore #base_adj 
IF OBJECT_ID('tempdb..#base_adj', 'U') IS NOT NULL 
   drop table #base_adj;
select *
  into #base_adj
  from SSRSReports.WebReportsUser.KYC_CASH_PROJ_#base_adj

create index tmpAP3 on #base_adj (ATMInternalID);
create index tmpAP4 on #base_adj (SettlementDate);
*/

/******************************************************************************************************
Baseline is not made up of sequential dates. Copy SettlementDate to BaseDate, then manipulate 
SettlementDate to build Baseline. BaseDate remains the original SettlementDate of the data. 
SettlementDate becomes the date we want it to represent in the baseline, which is the 9 week period
just before the Forecast period. 

We don't use the actual dispense data for each SettlementDate as that would require going back 9 weeks, 
and would pick up old dispense trends and anomalies such as stimulus activity, holiday activity, or tax 
season activity. Those data would not be a good baseline. We use recent data, picking weeks that are a 
good fit for those we are modeling. 
******************************************************************************************************/
/* Make a copy of #base_adj in case we need to start over. */

IF OBJECT_ID('tempdb..#base_adj', 'U') IS NOT NULL 
   drop table #base_adj;
select *
  into #base_adj
  from SSRSReports.WebReportsUser.KYC_CASH_PROJ_#base_adj;

create index tmpAP4 on #base_adj (SettlementDate);
create index tmpAP3 on #base_adj (ATMInternalID);

IF OBJECT_ID('tempdb..#base_adj_orig', 'U') IS NOT NULL 
   drop table #base_adj_orig;
select * 
  into #base_adj_orig
  from #base_adj;

select SettlementDate, 
       sum(n_WD_Baseline) as n_WD, 
	   sum(WDAmt_Baseline) as WDAmt, 
	   count(*) as n_rows
  from #base_adj_orig
 group by SettlementDate
 order by 1;

IF OBJECT_ID('tempdb..#base_adj', 'U') IS NOT NULL 
   drop table #base_adj;
select ATMInternalID, 
       SettlementDate, 
	   SettlementDate as BaseDate, 
	   n_WD, 
	   WDAmt, 
	   n_WD_Comerica, 
	   WDAmt_Comerica, 
	   n_WD_Varo, 
	   WDAmt_Varo, 	   
	   n_WD_USBank, 
	   WDAmt_USBank,
	   n_WD_Payfare, 
	   WDAmt_Payfare, 
	   n_WD_MN, 
	   WDAmt_MN, 
	   n_WD_Sky, 
	   WDAmt_Sky, 
	   n_WD_CashApp, 
	   WDAmt_CashApp, 
	   n_WD_ADP, 
	   WDAmt_ADP, 
	   n_WD_Comdata, 
	   WDAmt_Comdata, 
	   n_WD_Chime, 
	   WDAmt_Chime,
	   n_WD_PNC, 
	   WDAmt_PNC,
	   n_WD_Baseline, 
	   WDAmt_Baseline
  into #base_adj
  from #base_adj_orig;

select top 10 * from #base_adj_orig;
select top 10 * from #base_adj;

/* SettlementDate and BaseDate are the same for the moment. */ 
select SettlementDate,
       BaseDate,  
       sum(n_WD_Baseline) as n_WD, 
	   sum(WDAmt_Baseline) as WDAmt, 
	   count(*) as n_rows
  from #base_adj
 group by SettlementDate, BaseDate
 order by 1;

	   
/*****************************************************************************************************
Build Baseline from 154 days of established terminal data and 14 days of new terminal data. 

11/18/21 - changed baseline from 9 weeks to 12 weeks for new longer forecast horizon
*****************************************************************************************************/
/* First do new ATMs. There are 14 days of baseline data from 06/11/23 - 06/24/23. Change the SettlementDate
   values to 04/09/2023 - 04/22/2023 (1st two weeks of "ModelDate" in spreadsheet. Later we will duplicate 
   the data to fill in 04/22/2023 - 07/01/23, which will give us the full 12 week baseline period. */
select * from #dates;

UPDATE #base_adj
   SET SettlementDate = DATEADD(day, -63, BaseDate)
 WHERE BaseDate >= (select dt from #dates where varname = 'NewBaseStart')
   AND BaseDate <= (select dt from #dates where varname = 'NewBaseEnd')
   AND ATMInternalID in (select ATMInternalID from #new);
--1739 rows 

select distinct SettlementDate, BaseDate, 
       sum(n_wd_baseline) as n_wd, 
	   sum(wdamt_baseline) as wdamt, 
	   count(*) as n_rows
  from #base_adj
 where ATMInternalID in (select ATMInternalID from #new)
 group by SettlementDate, BaseDate
 order by SettlementDate;

/* Now do the established ATMs. There are  days of baseline data from 03/19/23 - 04/01/23. 
   These dates will be used to model other dates in the baseline. */ 
  
select distinct SettlementDate, BaseDate, 
       sum(n_wd_baseline) as n_wd, 
	   sum(wdamt_baseline) as wdamt, 
	   count(*) as n_rows
  from #base_adj
 where ATMInternalID not in (select ATMInternalID from #new)
 group by SettlementDate, BaseDate
 order by SettlementDate;


/* 

*/

/* First, delete dates that won't be used. */
/* week 45
DELETE FROM #base_adj
 WHERE BaseDate >= '2022-07-10'
   AND BaseDate <= '2022-07-16'
   AND ATMInternalID not in (select ATMInternalID from #new);
--340608

DELETE FROM #base_adj
 WHERE BaseDate >= '2022-07-24'
   AND BaseDate <= '2022-07-30'
   AND ATMInternalID not in (select ATMInternalID from #new);
--341594



DELETE FROM #base_adj
 WHERE BaseDate >= '2023-04-23'
   AND BaseDate <= '2023-05-06'
   AND ATMInternalID not in (select ATMInternalID from #new);
--6582242

select * from #dates;
*/
/*  
DELETE FROM #base_adj
 WHERE BaseDate >= '2022-02-27'
   AND BaseDate <= '2022-03-05'
   AND ATMInternalID not in (select ATMInternalID from #new);
--1365168

DELETE FROM #base_adj
 WHERE BaseDate >= '2022-03-13'
   AND BaseDate <= '2022-03-19'
   AND ATMInternalID not in (select ATMInternalID from #new);
--3022848
*/
/* Check if there are any dates we should delete*/


select BaseDate,count(*)
from #base_adj
group by BaseDate
order by BaseDate;

/* Next do updates, before adding any rows that could be affected. */
/* attempt 1:*/
IF OBJECT_ID('tempdb..#base_sche', 'U') IS NOT NULL 
   drop table #base_sche;
select *
into #base_sche
from SSRSReports.WebReportsUser.KYC_CASH_PROJ_INP_Base;

select * from #base_sche;
select count(*) from #base_adj;
--1357168

IF OBJECT_ID('tempdb..#base_adj2', 'U') IS NOT NULL 
   drop table #base_adj2;
select *
into #base_adj2
from (
	select b.ModelDate_reference as ModelDate,a.*
	from #base_adj a
		left join #base_sche b
		on a.BaseDate = b.BaseDate_Actuals_Date
	where ATMInternalID not in (select ATMInternalID from #new)
	) c
union
	(select BaseDate as ModelDate, * 
	from #base_adj
	WHERE BaseDate >= (select dt from #dates where varname = 'NewBaseStart')
	   AND BaseDate <= (select dt from #dates where varname = 'NewBaseEnd')
	   AND ATMInternalID in (select ATMInternalID from #new)
	  );

select count(*),SettlementDate,BaseDate
from (
select BaseDate as ModelDate, * 
	from #base_adj
	WHERE BaseDate >= (select dt from #dates where varname = 'NewBaseStart')
	   AND BaseDate <= (select dt from #dates where varname = 'NewBaseEnd')
	   AND ATMInternalID in (select ATMInternalID from #new)) a 
group by SettlementDate,BaseDate
order by SettlementDate,BaseDate;

select count(*) from #base_adj2;
--40689060

UPDATE #base_adj2
   SET SettlementDate = ModelDate
 WHERE ATMInternalID not in (select ATMInternalID from #new);

 select top 10 * from #base_adj2;


select count(*),SettlementDate,BaseDate
from #base_adj2
where ATMInternalID not in (select ATMInternalID from #new)
group by SettlementDate,BaseDate
order by SettlementDate,BaseDate;

/* check if there's any error*/
select count(*),SettlementDate,BaseDate
from #base_adj2
where ATMInternalID not in (select ATMInternalID from #new)
group by SettlementDate,BaseDate
order by SettlementDate,BaseDate;

select count(*) from #base_adj2;
--4067688

/* Save #base_adj into a persistent table in case we lose temp tables. */
IF OBJECT_ID('[SSRSReports].[WebReportsUser].[KYC_CASH_PROJ_BASE_ADJ]', 'U') IS NOT NULL 
    drop table [SSRSReports].[WebReportsUser].[KYC_CASH_PROJ_BASE_ADJ];
select ATMInternalID, 
       SettlementDate, 
	   BaseDate, 
	   n_WD, 
	   WDAmt, 
	   n_WD_Comerica, 
	   WDAmt_Comerica, 
	   n_WD_Varo, 
	   WDAmt_Varo, 	   
	   n_WD_USBank, 
	   WDAmt_USBank,
	   n_WD_Payfare, 
	   WDAmt_Payfare, 
	   n_WD_MN, 
	   WDAmt_MN, 
	   n_WD_Sky, 
	   WDAmt_Sky, 
	   n_WD_CashApp, 
	   WDAmt_CashApp, 
	   n_WD_ADP, 
	   WDAmt_ADP, 
	   n_WD_Comdata, 
	   WDAmt_Comdata, 
	   n_WD_Chime, 
	   WDAmt_Chime,
	   n_WD_PNC, 
	   WDAmt_PNC,
	   n_WD_Baseline, 
	   WDAmt_Baseline
  into [SSRSReports].[WebReportsUser].[KYC_CASH_PROJ_BASE_ADJ]
  from #base_adj2;

/* Check the SettlementDate*/

select SettlementDate,BaseDate,
       sum(n_WD_Baseline) as n_WD, 
	   sum(WDAmt_Baseline) as WDAmt
  from #base_adj2
 group by SettlementDate,BaseDate
 order by SettlementDate;

select SettlementDate,BaseDate,
       sum(n_WD_Baseline) as n_WD, 
	   sum(WDAmt_Baseline) as WDAmt
  from [SSRSReports].[WebReportsUser].[KYC_CASH_PROJ_BASE_ADJ]
 group by SettlementDate,BaseDate
 order by SettlementDate;

select count(*) from #base_adj2

/* To restore #base_adj from persistent table:

IF OBJECT_ID('tempdb..#base_adj', 'U') IS NOT NULL 
    drop table #base_adj;

select *
  into #base_adj
  from [SSRSReports].[WebReportsUser].[KYC_CASH_PROJ_BASE_ADJ];
  
create index tmpAP3 on #base_adj (ATMInternalID);
create index tmpAP4 on #base_adj (SettlementDate);
  
*/
/*
select SettlementDate,
       BaseDate,  
       sum(n_WD_Baseline) as n_WD, 
	   sum(WDAmt_Baseline) as WDAmt
  from #base_adj
 group by SettlementDate, BaseDate
 order by SettlementDate, BaseDate;
 */
select count(*)
from #base_adj;
--4061341


/*************************************************************
Part III

Allocate projections to the ATM level. 
*************************************************************/
/*************************************************************
IMPORT CASH PROJECTIONS for the BIN groups that we're 
forecasting. 

Convert the forecasts to float during import process.
**************************************************************/

IF OBJECT_ID('[SSRSReports].[WebReportsUser].[KYC_CASH_PROJ_INP_JUL2]', 'U') IS NULL 
	select *
		into [SSRSReports].[WebReportsUser].[KYC_CASH_PROJ_INP_JUL2]
		from [SSRSReports].[WebReportsUser].[KYC_CASH_PROJ_INP];

--IF OBJECT_ID('[SSRSReports].[WebReportsUser].[KYC_CASH_PROJ_INP]', 'U') IS NOT NULL
	--drop table [SSRSReports].[WebReportsUser].[KYC_CASH_PROJ_INP];

select *
  from [SSRSReports].[WebReportsUser].[KYC_CASH_PROJ_INP];

select count(*)
  from [SSRSReports].[WebReportsUser].[KYC_CASH_PROJ_INP];
--85

--Add FcstDate to baseline
/* Pull rows where FcstDate is less than equal last day of new forecast period */

IF OBJECT_ID('tempdb..#base_adj', 'U') IS NULL
	select *
	  into #base_adj
	  from [SSRSReports].[WebReportsUser].[KYC_CASH_PROJ_BASE_ADJ]

IF OBJECT_ID('tempdb..#base_adj', 'U') IS NOT NULL
drop table #base_adj;
	select *
	  into #base_adj
	  from [SSRSReports].[WebReportsUser].[KYC_CASH_PROJ_BASE_ADJ]


/* #dates*/

IF OBJECT_ID('tempdb..#dates', 'U') IS NULL
	select *
	  into #dates
	  from [SSRSReports].[WebReportsUser].[KYC_CASH_PROJ_DATES_JUL2];

IF OBJECT_ID('tempdb..#lkp1', 'U') IS NOT NULL 
   drop table #lkp1;
select FcstDate, 
       BaseDate
 into #lkp1
  from [SSRSReports].[WebReportsUser].[KYC_CASH_PROJ_INP]
 where cast(FcstDate as date) <= (select dt from #dates where varname = 'FcstEnd'); 

create index tmpAP3 on #lkp1 (BaseDate);

select count(*) as n_rec
  from #base_adj;
--1357168

IF OBJECT_ID('tempdb..#base_adj1', 'U') IS NOT NULL 
   drop table #base_adj1;
select cast(b.FcstDate as date) as ForecastDate, 
       a.*
  into #base_adj1
  from #base_adj a
       left join #lkp1 b 
	   on cast(a.SettlementDate as date) = cast(b.BaseDate as date);


select ForecastDate, 
       cast(SettlementDate as date) as SettlementDate, 
	   sum(n_WD_Baseline) as n_WD, 
	   sum(WDAmt_Baseline) as WDAmt
  from #base_adj1 a
--where a.ATMInternalID in (select ATMInternalID from #new)
 group by ForecastDate, SettlementDate
 order by 1;

select count(*) as n_rec
  from #base_adj1
--4061341

/******************************************************************************************
Insert baseline for new terminals for 3nd week - 12th week 
******************************************************************************************/
/* Note: We've already updated Settlement dates for new terminal transactions to baseline 
   date range. */
/* We've used two weeks of data for new terminals. Copy those to additional weeks.  */

/*restore #terms1, #new*/
IF OBJECT_ID('tempdb..#terms1', 'U') IS NULL
	select *
	into #terms1
	from [SSRSReports].[WebReportsUser].[KYC_CASH_PROJ_TERMS1]

IF OBJECT_ID('tempdb..#new', 'U') IS NULL 
	select *
	  into #new
	  from #terms1
	 where cast(AUDFD2 as date) > (select dt from #dates where varname = 'BaselineStart'); 



/* week 3, insert a copy of week 1 */
IF OBJECT_ID('tempdb..#week4to12_copy', 'U') IS NOT NULL 
   drop table #week4to12_copy;
select DATEADD(day, 14, ForecastDate) as ForecastDate,
       b.ATMInternalID,
       DATEADD(day, 14, SettlementDate) as SettlementDate,
	   BaseDate, 
		  n_WD, 
		  WDAmt, 
		  n_WD_Comerica, 
		  WDAmt_Comerica, 
		  n_WD_Varo, 
		  WDAmt_Varo, 	   
		  n_WD_USBank, 
		  WDAmt_USBank,
		  n_WD_Payfare, 
		  WDAmt_Payfare, 
		  n_WD_MN, 
		  WDAmt_MN, 
		  n_WD_Sky, 
		  WDAmt_Sky, 
		  n_WD_CashApp, 
		  WDAmt_CashApp, 
		  n_WD_ADP, 
		  WDAmt_ADP, 
		  n_WD_Comdata, 
		  WDAmt_Comdata, 
		  n_WD_Chime, 
		  WDAmt_Chime, 
		  n_WD_PNC, 
		  WDAmt_PNC, 
		  n_WD_Baseline, 
		  WDAmt_Baseline
  into #week4to12_copy
  from #base_adj1 b
       inner join #new n
	   on b.ATMInternalID = n.ATMInternalID
	   /*1st week of baseline for new terminals*/
 where SettlementDate >= (select dt  from #dates where varname = 'ModelStart')
   and SettlementDate <= (select dt + 6 from #dates where varname = 'ModelStart')
 order by ForecastDate;
--2570


/* week 4, insert a copy of week 2 */
insert into #week4to12_copy
select DATEADD(day, 14, ForecastDate) as ForecastDate,
       b.ATMInternalID,
       DATEADD(day, 14, SettlementDate) as SettlementDate,
	   BaseDate, 
		  n_WD, 
		  WDAmt, 
		  n_WD_Comerica, 
		  WDAmt_Comerica, 
		  n_WD_Varo, 
		  WDAmt_Varo, 	   
		  n_WD_USBank, 
		  WDAmt_USBank,
		  n_WD_Payfare, 
		  WDAmt_Payfare, 
		  n_WD_MN, 
		  WDAmt_MN, 
		  n_WD_Sky, 
		  WDAmt_Sky, 
		  n_WD_CashApp, 
		  WDAmt_CashApp, 
		  n_WD_ADP, 
		  WDAmt_ADP, 
		  n_WD_Comdata, 
		  WDAmt_Comdata, 
		  n_WD_Chime, 
		  WDAmt_Chime, 
		  n_WD_PNC, 
		  WDAmt_PNC, 
		  n_WD_Baseline, 
		  WDAmt_Baseline
  from #base_adj1 b
       inner join #new n
	   on b.ATMInternalID = n.ATMInternalID
	   /*2nd week of baseline for new terminals*/
 where SettlementDate >= (select dt + 7 from #dates where varname = 'ModelStart')
   and SettlementDate <= (select dt + 13 from #dates where varname = 'ModelStart')
 order by ForecastDate;
--2726

/* week 5, insert a copy of week 1  */
insert into #week4to12_copy
select DATEADD(day, 28, ForecastDate) as ForecastDate,
       b.ATMInternalID,
       DATEADD(day, 28, SettlementDate) as SettlementDate,
	   BaseDate, 
		  n_WD, 
		  WDAmt, 
		  n_WD_Comerica, 
		  WDAmt_Comerica, 
		  n_WD_Varo, 
		  WDAmt_Varo, 	   
		  n_WD_USBank, 
		  WDAmt_USBank,
		  n_WD_Payfare, 
		  WDAmt_Payfare, 
		  n_WD_MN, 
		  WDAmt_MN, 
		  n_WD_Sky, 
		  WDAmt_Sky, 
		  n_WD_CashApp, 
		  WDAmt_CashApp, 
		  n_WD_ADP, 
		  WDAmt_ADP, 
		  n_WD_Comdata, 
		  WDAmt_Comdata, 
		  n_WD_Chime, 
		  WDAmt_Chime, 
		  n_WD_PNC, 
		  WDAmt_PNC, 
		  n_WD_Baseline, 
		  WDAmt_Baseline
  from #base_adj1 b
	   inner join #new n 
	   on b.ATMInternalID = n.ATMInternalID
	   /*1st week of baseline for new terminals*/
 where SettlementDate >= (select dt  from #dates where varname = 'ModelStart')
   and SettlementDate <= (select dt + 6 from #dates where varname = 'ModelStart')
 order by ForecastDate;
--2570	
	
/* week 6, insert a copy of week 2 */
insert into #week4to12_copy
select DATEADD(day, 28, ForecastDate) as ForecastDate,
	   b.ATMInternalID,
	   DATEADD(day, 28, SettlementDate) as SettlementDate,
	   BaseDate, 
		  n_WD, 
		  WDAmt, 
		  n_WD_Comerica, 
		  WDAmt_Comerica, 
		  n_WD_Varo, 
		  WDAmt_Varo, 	   
		  n_WD_USBank, 
		  WDAmt_USBank,
		  n_WD_Payfare, 
		  WDAmt_Payfare, 
		  n_WD_MN, 
		  WDAmt_MN, 
		  n_WD_Sky, 
		  WDAmt_Sky, 
		  n_WD_CashApp, 
		  WDAmt_CashApp, 
		  n_WD_ADP, 
		  WDAmt_ADP, 
		  n_WD_Comdata, 
		  WDAmt_Comdata, 
		  n_WD_Chime, 
		  WDAmt_Chime, 
		  n_WD_PNC, 
		  WDAmt_PNC, 
		  n_WD_Baseline, 
		  WDAmt_Baseline
  from #base_adj1 b
	   inner join #new n
	   on b.ATMInternalID = n.ATMInternalID
	   /*2nd week of baseline for new terminals*/
 where SettlementDate >= (select dt + 7 from #dates where varname = 'ModelStart') 
   and SettlementDate <= (select dt + 13 from #dates where varname = 'ModelStart')
 order by ForecastDate;
--2726

/* week 7, insert a copy of week 1 */
insert into #week4to12_copy
select DATEADD(day, 42, ForecastDate) as ForecastDate,
       b.ATMInternalID,
       DATEADD(day, 42, SettlementDate) as SettlementDate,
	   BaseDate, 
 		  n_WD, 
		  WDAmt, 
		  n_WD_Comerica, 
		  WDAmt_Comerica, 
		  n_WD_Varo, 
		  WDAmt_Varo, 	   
		  n_WD_USBank, 
		  WDAmt_USBank,
		  n_WD_Payfare, 
		  WDAmt_Payfare, 
		  n_WD_MN, 
		  WDAmt_MN, 
		  n_WD_Sky, 
		  WDAmt_Sky, 
		  n_WD_CashApp, 
		  WDAmt_CashApp, 
		  n_WD_ADP, 
		  WDAmt_ADP, 
		  n_WD_Comdata, 
		  WDAmt_Comdata, 
		  n_WD_Chime, 
		  WDAmt_Chime, 
		  n_WD_PNC, 
		  WDAmt_PNC, 
		  n_WD_Baseline, 
		  WDAmt_Baseline
  from #base_adj1 b
	   inner join #new n
	   on b.ATMInternalID = n.ATMInternalID
	   /*1st week of baseline for new terminals*/
 where SettlementDate >= (select dt from #dates where varname = 'ModelStart') 
   and SettlementDate <= (select dt + 6 from #dates where varname = 'ModelStart')
 order by ForecastDate;
--2570
	
	
/* week 8, insert a copy of week 2  */
insert into #week4to12_copy
select DATEADD(day, 42, ForecastDate) as ForecastDate,
       b.ATMInternalID,
       DATEADD(day, 42, SettlementDate) as SettlementDate,
	   BaseDate, 
		  n_WD, 
		  WDAmt, 
		  n_WD_Comerica, 
		  WDAmt_Comerica, 
		  n_WD_Varo, 
		  WDAmt_Varo, 	   
		  n_WD_USBank, 
		  WDAmt_USBank,
		  n_WD_Payfare, 
		  WDAmt_Payfare, 
		  n_WD_MN, 
		  WDAmt_MN, 
		  n_WD_Sky, 
		  WDAmt_Sky, 
		  n_WD_CashApp, 
		  WDAmt_CashApp, 
		  n_WD_ADP, 
		  WDAmt_ADP, 
		  n_WD_Comdata, 
		  WDAmt_Comdata, 
		  n_WD_Chime, 
		  WDAmt_Chime, 
		  n_WD_PNC, 
		  WDAmt_PNC, 
		  n_WD_Baseline, 
		  WDAmt_Baseline
  from #base_adj1 b
	   inner join #new n
	   on b.ATMInternalID = n.ATMInternalID
	   /*2nd week of baseline for new terminals*/
 where SettlementDate >= (select dt + 7 from #dates where varname = 'ModelStart') 
   and SettlementDate <= (select dt + 13 from #dates where varname = 'ModelStart')
 order by ForecastDate;
--2726
	
/* week 9, insert a copy of week 1  */
insert into #week4to12_copy
select DATEADD(day, 56, ForecastDate) as ForecastDate,
       b.ATMInternalID,
       DATEADD(day, 56, SettlementDate) as SettlementDate,
	   BaseDate, 
		  n_WD, 
		  WDAmt, 
		  n_WD_Comerica, 
		  WDAmt_Comerica, 
		  n_WD_Varo, 
		  WDAmt_Varo, 	   
		  n_WD_USBank, 
		  WDAmt_USBank,
		  n_WD_Payfare, 
		  WDAmt_Payfare, 
		  n_WD_MN, 
		  WDAmt_MN, 
		  n_WD_Sky, 
		  WDAmt_Sky, 
		  n_WD_CashApp, 
		  WDAmt_CashApp, 
		  n_WD_ADP, 
		  WDAmt_ADP, 
		  n_WD_Comdata, 
		  WDAmt_Comdata, 
		  n_WD_Chime, 
		  WDAmt_Chime, 
		  n_WD_PNC, 
		  WDAmt_PNC, 
		  n_WD_Baseline, 
		  WDAmt_Baseline
  from #base_adj1 b
	   inner join #new n
	   on b.ATMInternalID = n.ATMInternalID
	   /*1st week of baseline for new terminals*/
 where SettlementDate >= (select dt from #dates where varname = 'ModelStart') 
   and SettlementDate <= (select dt + 6 from #dates where varname = 'ModelStart')
 order by ForecastDate;
--2570

/* week 10, insert a copy of week 1  */
insert into #week4to12_copy
select DATEADD(day, 63, ForecastDate) as ForecastDate,
       b.ATMInternalID,
       DATEADD(day, 63, SettlementDate) as SettlementDate,
	   BaseDate, 
		  n_WD, 
		  WDAmt, 
		  n_WD_Comerica, 
		  WDAmt_Comerica, 
		  n_WD_Varo, 
		  WDAmt_Varo, 	   
		  n_WD_USBank, 
		  WDAmt_USBank,
		  n_WD_Payfare, 
		  WDAmt_Payfare, 
		  n_WD_MN, 
		  WDAmt_MN, 
		  n_WD_Sky, 
		  WDAmt_Sky, 
		  n_WD_CashApp, 
		  WDAmt_CashApp, 
		  n_WD_ADP, 
		  WDAmt_ADP, 
		  n_WD_Comdata, 
		  WDAmt_Comdata, 
		  n_WD_Chime, 
		  WDAmt_Chime,
		  n_WD_PNC, 
		  WDAmt_PNC, 
		  n_WD_Baseline, 
		  WDAmt_Baseline
  from #base_adj1 b
	   inner join #new n
	   on b.ATMInternalID = n.ATMInternalID
	   /*1st week of baseline for new terminals*/
 where SettlementDate >= (select dt from #dates where varname = 'ModelStart') 
   and SettlementDate <= (select dt + 6 from #dates where varname = 'ModelStart')
 order by ForecastDate;
--2570

/* week 11, insert a copy of week 2  */
insert into #week4to12_copy
select DATEADD(day, 63, ForecastDate) as ForecastDate,
       b.ATMInternalID,
       DATEADD(day, 63, SettlementDate) as SettlementDate,
	   BaseDate, 
		  n_WD, 
		  WDAmt, 
		  n_WD_Comerica, 
		  WDAmt_Comerica, 
		  n_WD_Varo, 
		  WDAmt_Varo, 	   
		  n_WD_USBank, 
		  WDAmt_USBank,
		  n_WD_Payfare, 
		  WDAmt_Payfare, 
		  n_WD_MN, 
		  WDAmt_MN, 
		  n_WD_Sky, 
		  WDAmt_Sky, 
		  n_WD_CashApp, 
		  WDAmt_CashApp, 
		  n_WD_ADP, 
		  WDAmt_ADP, 
		  n_WD_Comdata, 
		  WDAmt_Comdata, 
		  n_WD_Chime, 
		  WDAmt_Chime, 
		  n_WD_PNC, 
		  WDAmt_PNC, 
		  n_WD_Baseline, 
		  WDAmt_Baseline
  from #base_adj1 b
	   inner join #new n
	   on b.ATMInternalID = n.ATMInternalID
	   /*1st week of baseline for new terminals*/
 where SettlementDate >= (select dt+ 7 from #dates where varname = 'ModelStart') 
   and SettlementDate <= (select dt + 13 from #dates where varname = 'ModelStart')
 order by ForecastDate;
--(2726 rows affected)


/* week 12, insert a copy of week 2  */
insert into #week4to12_copy
select DATEADD(day, 70, ForecastDate) as ForecastDate,
       b.ATMInternalID,
       DATEADD(day, 70, SettlementDate) as SettlementDate,
	   BaseDate, 
		  n_WD, 
		  WDAmt, 
		  n_WD_Comerica, 
		  WDAmt_Comerica, 
		  n_WD_Varo, 
		  WDAmt_Varo, 	   
		  n_WD_USBank, 
		  WDAmt_USBank,
		  n_WD_Payfare, 
		  WDAmt_Payfare, 
		  n_WD_MN, 
		  WDAmt_MN, 
		  n_WD_Sky, 
		  WDAmt_Sky, 
		  n_WD_CashApp, 
		  WDAmt_CashApp, 
		  n_WD_ADP, 
		  WDAmt_ADP, 
		  n_WD_Comdata, 
		  WDAmt_Comdata, 
		  n_WD_Chime, 
		  WDAmt_Chime, 
		  n_WD_PNC, 
		  WDAmt_PNC, 
		  n_WD_Baseline, 
		  WDAmt_Baseline
  from #base_adj1 b
	   inner join #new n
	   on b.ATMInternalID = n.ATMInternalID
	   /*1st week of baseline for new terminals*/
 where SettlementDate >= (select dt+ 7 from #dates where varname = 'ModelStart') 
   and SettlementDate <= (select dt + 13 from #dates where varname = 'ModelStart')
 order by ForecastDate;
--2726

select ForecastDate, 
       SettlementDate, 
	   sum(n_WD_Baseline) as n_WD, 
	   sum(WDAmt_Baseline) as WDAmt
  from #week4to12_copy 
 group by ForecastDate, SettlementDate
 order by ForecastDate; 


insert into #base_adj1
       select *
         from #week4to12_copy;
--31625

select sum(WDAmt) as WDAmt_Tot, 
       sum(WDAmt_Comerica) as WDAmt_Comerica,  
	   sum(WDAmt_Varo) as WDAmt_Varo, 
	   sum(WDAmt_USBank) as WDAmt_USBank, 
	   sum(WDAmt_Payfare) as WDAmt_Payfare, 
	   sum(WDAmt_MN) as WDAmt_MN, 
	   sum(WDAmt_Sky) as WDAmt_Sky,
	   sum(WDAmt_CashApp) as WDAmt_CashApp,
	   sum(WDAmt_ADP) as WDAmt_ADP, 
	   sum(WDAmt_Comdata) as WDAmt_Comdata, 
	   sum(WDAmt_Chime) as WDAmt_Chime, 
	   sum(WDAmt_PNC) as WDAmt_PNC,
	   sum(WDAmt_Baseline) as WDAmt_Baseline
  from #base_adj1;

/*
WDAmt_Tot	WDAmt_Comerica	WDAmt_Varo	WDAmt_USBank	WDAmt_Payfare	WDAmt_MN	WDAmt_Sky	WDAmt_CashApp	WDAmt_ADP	WDAmt_Comdata	WDAmt_Chime	WDAmt_PNC	WDAmt_Baseline
9948824609.85	441005703.00	88742820.00	428337225.00	253806885.00	186391020.00	108371775.00	307285278.00	438473346.00	153025830.00	1339906347.00	153626901.00	6049856399.85*/

IF OBJECT_ID('[SSRSReports].[WebReportsUser].[KYC_CASH_PROJ_BASE_ADJ1]', 'U') IS NOT NULL
    drop table [SSRSReports].[WebReportsUser].[KYC_CASH_PROJ_BASE_ADJ1];
select *
  into [SSRSReports].[WebReportsUser].[KYC_CASH_PROJ_BASE_ADJ1]
  from #base_adj1;

select ForecastDate, 
       SettlementDate, 
	   sum(n_WD_Baseline) as n_WD, 
	   sum(WDAmt_Baseline) as WDAmt
  from [SSRSReports].[WebReportsUser].[KYC_CASH_PROJ_BASE_ADJ1] 
 group by ForecastDate, SettlementDate
 order by ForecastDate; 

/* restore #base_adj1 
IF OBJECT_ID('tempdb..#base_adj1', 'U') IS NOT NULL
    drop table #base_adj1;
select *
  into #base_adj1
  from [SSRSReports].[WebReportsUser].[KYC_CASH_PROJ_BASE_ADJ1];
--4113006
*/

/* Get initial values */
select datepart(year, SettlementDate)* 100 + datepart(week, SettlementDate) as week, 
       sum(n_WD_Baseline) as n_WD, 
	   sum(WDAmt_Baseline) as WDAmt
  from #base_adj1
 group by datepart(year, SettlementDate)* 100 + datepart(week, SettlementDate)
 order by datepart(year, SettlementDate)* 100 + datepart(week, SettlementDate);

 /* if any scaling > 1
 week	n_WD	WDAmt
202315	3614358	541555855.00
202316	3546815	513953863.00
202317	3431886	485131520.00
202318	3400845	475977561.95
202319	3614358	541555855.00
202320	3546815	513953863.00
202321	3431886	485131520.00
202322	3400845	475977561.95
202323	3614358	541555855.00
202324	3545852	513815458.00
202325	3432849	485269925.00
202326	3400845	475977561.95*/


update #base_adj1
   set n_WD_Baseline = cast(round(b.Scaling * n_WD_Baseline,0) as int), 
       WDAmt_Baseline = cast(round(b.Scaling * WDAmt_Baseline,0) as int)
	from #base_adj1 a
	left join #base_sche b
	on a.ForecastDate = b.Date
 where ATMInternalID not in (select ATMInternalID from #new);

/* Check overall results */
select datepart(year, SettlementDate)* 100 + datepart(week, SettlementDate) as week, 
       sum(n_WD_Baseline) as n_WD, 
	   sum(WDAmt_Baseline) as WDAmt
  from #base_adj1
 group by datepart(year, SettlementDate)* 100 + datepart(week, SettlementDate)
 order by datepart(year, SettlementDate)* 100 + datepart(week, SettlementDate);

 /*End of Scaling */

/*
week	n_WD	WDAmt
202315	3798843	571953986.00
202316	3727666	542792170.00
202317	3604655	512356973.00
202318	3571617	502680100.00
202319	3839843	578802282.00
202320	3668551	536309873.00
202321	3547516	506237969.00
202322	3514961	496678781.00
202323	3781581	571555850.00
202324	3583541	525438674.00
202325	3468366	496243071.00
202326	3435877	486740287.00
*/

/* Save Baseline into KYC_CASH_PROJ_Baseline */
IF OBJECT_ID('[SSRSReports].[WebReportsUser].[KYC_CASH_PROJ_BASELINE]','U') IS NOT NULL
    drop table [SSRSReports].[WebReportsUser].[KYC_CASH_PROJ_BASELINE];
	select *
	  into [SSRSReports].[WebReportsUser].[KYC_CASH_PROJ_BASELINE]
	  from #base_adj1;

select count(*) from [SSRSReports].[WebReportsUser].[KYC_CASH_PROJ_BASELINE];


create index tmpAP3 on [SSRSReports].[WebReportsUser].[KYC_CASH_PROJ_BASELINE] (ATMInternalID);
create index tmpAP4 on [SSRSReports].[WebReportsUser].[KYC_CASH_PROJ_BASELINE] (SettlementDate);
create index tmpAP5 on [SSRSReports].[WebReportsUser].[KYC_CASH_PROJ_BASELINE] (ForecastDate);

select ForecastDate, 
       SettlementDate, 
       sum(n_WD_Baseline) as n_WD, 
	   sum(WDAmt_Baseline) as WDAmt
  from [SSRSReports].[WebReportsUser].[KYC_CASH_PROJ_BASELINE] a
 group by ForecastDate, SettlementDate
 order by 1;
  
select ForecastDate, 
       SettlementDate, 
       sum(n_WD_Baseline) as n_WD, 
	   sum(WDAmt_Baseline) as WDAmt
  from #base_adj1 a
 group by ForecastDate, SettlementDate
 order by 1;
  
IF OBJECT_ID('tempdb..#base_data', 'U') IS NOT NULL 
   drop table #base_data;
select ForecastDate, 
       ATMInternalID, 
       SettlementDate, 
	   n_WD_Baseline, 
	   WDAmt_Baseline
  into #base_data
  from [SSRSReports].[WebReportsUser].[KYC_CASH_PROJ_BASELINE];

select top(10) *
from #base_data
order by ForecastDate;


/***********************************************************************************
Check Baseline weekly dispense. 
***********************************************************************************/
/*restore #dates, terms1*/

IF OBJECT_ID('tempdb..#dates', 'U') IS NULL
	select *
	into #dates
	from [SSRSReports].[WebReportsUser].[KYC_CASH_PROJ_DATES]

IF OBJECT_ID('tempdb..#terms1', 'U') IS NULL
	select *
	into #terms1
	from [SSRSReports].[WebReportsUser].[KYC_CASH_PROJ_TERMS1]

IF OBJECT_ID('tempdb..#new', 'U') IS NULL 
	select *
	  into #new
	  from #terms1
	 where cast(AUDFD2 as date) > (select dt from #dates where varname = 'BaselineStart'); 


select datepart(year, SettlementDate)* 100 + datepart(week, SettlementDate) as week, 
       sum(n_WD_Baseline) as n_wd, 
	   sum(WDAmt_Baseline) as WDAmt
  from [SSRSReports].[WebReportsUser].[KYC_CASH_PROJ_BASELINE] b
       inner join [SSRSReports].[WebReportsUser].[KYC_CASH_PROJ_TERMS1] t
	   on b.ATMInternalID = t.ATMInternalID
 --where t.segment = 'Non-MS'
 group by datepart(year, SettlementDate)* 100 + datepart(week, SettlementDate)
 order by datepart(year, SettlementDate)* 100 + datepart(week, SettlementDate);

/*
week	n_wd	WDAmt
week	n_wd	WDAmt
202315	3806651	574009367.00
202316	3735019	544742843.00
202317	3611604	514199214.00
202318	3578335	504487935.00
202319	3841445	579418644.00
202320	3654092	534481876.00
202321	3533682	504512418.00
202322	3501211	494986545.00
202323	3806651	574009367.00
202324	3577284	524077538.00
202325	3462537	494958257.00
202326	3429996	485480189.00
*/

/***********************************************************************************
Create Projections

Use last four full weeks of transactions (AllocStart - AllocEnd) to 
determine proportion of transactions per day of week for each ATM in a 
BIN group or baseline. 
This will be multiplied by projected total number of withdrawals per day
per BIN group to determine projected withdrawals for each ATM for each day. 

Note: Some ATMs do not have transactions every day of week during this 
period, so will get proportions of zero for some days of week. 

Also note: During volatile periods, it is critical to get the absolutely 
most recent data to allocate projections. 

Also use last four full weeks of transactions to determine average
dispense per withdrawal in this period. This is multiplied by the projected
number of withdrawals each day for each ATM to project withdrawal amount per 
day for each ATM. 

12/10/20 - Increase $/WD by half the difference between recent value and 
           value at end of FPUC program. 
12/10/20 - Calculate Chime Beginning of Month $/WD and Rest of Month $/WD
           as they are different. 
2/9/21   - Calculate min of: 
            - Average $/WD during FPUCCalcStart - FPUCCalcEnd period (FPUC #1)
			- Average $/WD from last three full weeks PLUS one-third of the 
			      difference of the average $/WD from the last three weeks minus
				  the average $/WD from the PreFPUC2Start - PreFPUC2End period
				  This represents the additional $/WD that was seen when the 
				  extra $300 federal pandemic unemployment was paid in January. 
				  Add one third of this value to the existing average $/WD to 
				  project the new average $/WD when the FPUC is raised to $400
				  on March 14, 2021. 
		    - Do not go over the amount that was seen during the first FPUC in 2020. 
		 - Changed weights from last three weeks of history to four as some ATMs
		      had minimal history for calculating weights with three weeks. 
3/9/21 - Use recent $/WD as FPUC program will continue at $300/wk through Sep 6. 
6/1/21 - Use recent $/WD. FPUC program continuing through Sep 6, however many states
             have announced they will pull out early. Wait to predict drop until we
			 see how the drop in dispense data and can quantify it. Don't want to 
			 predict too much of a drop. 
10/1/21 - Federal pandemic unemployment programs expired 9/6/21. Three UI groups
             are left in the forecast. Use the last two weeks to forecast their
			 volume and average dipense to remove any impact from the federal programs. 
10/29/21 - Go back to 4 weeks for weights for all forecast groups. 
           Add BIN 511563 for Comerica and 421783 for Chime.
11/18/21 - Add BINs 486208, 400895, 447227 to Chime. They were added to AP on 10/6/21. 
           Little to no volume to date. 
2/11/22 - Replace Keybank with Varo Money as Keybank has dropped and Varo is growing. 
          Replace US Bank - Govt with US Bank - Private Prepaid-Payroll. 
		  Replace BoA Non-AP UI with Skylight Financial Prepaid-Payroll
4/6/22 -  Add Cash App (SUTTON BANK) bin 440393, combine all Chime BINs in one group. 

*************************************************************************************/
/*restore #dates, terms1*/
--mark1
IF OBJECT_ID('tempdb..#dates', 'U') IS NULL
	select *
	into #dates
	from [SSRSReports].[WebReportsUser].[KYC_CASH_PROJ_DATES]

IF OBJECT_ID('tempdb..#terms1', 'U') IS NULL
	select *
	into #terms1
	from [SSRSReports].[WebReportsUser].[KYC_CASH_PROJ_TERMS1]

IF OBJECT_ID('tempdb..#new', 'U') IS NULL 
	select *
	  into #new
	  from #terms1
	 where cast(AUDFD2 as date) > (select dt from #dates where varname = 'BaselineStart'); 

IF OBJECT_ID('tempdb..#BOM_ROM_List', 'U') IS NOT NULL
   drop table #BOM_ROM_List;
create table #BOM_ROM_List
(
	issuer varchar(20) primary key,
	BOM float,
	ROM float
);
select * from #BOM_ROM_List;

/*************************************************************
Varo Projection: 
Forecast Period - FcstStart to FcstEnd
**************************************************************/

/* Pull Varo forecasted number of withdrawals. */
IF OBJECT_ID('tempdb..#fcst', 'U') IS NOT NULL 
   drop table #fcst;
select cast(FcstDate as date) as ForecastDate, 
       sum(Varo) as n_WD
  into #fcst
  from [SSRSReports].[WebReportsUser].[KYC_CASH_PROJ_INP]
 group by cast(FcstDate as date)
 order by 1;

/* Use Last 4 weeks of withdrawal transactions available, AllocStart to AllocEnd, to 
   create weights for ATMs. */
IF OBJECT_ID('tempdb..#varo_wt', 'U') IS NOT NULL 
   drop table #varo_wt;
select t.ATMInternalID, 
       cast(t.SettlementDate as date) as SettlementDate, 
	   sum(case when t.txntypeid = 1 then 1 else 0 end) as n_WD, 
	   sum(amount) as WDAmt
  into #varo_wt
  from ATMManagerM_TW.dbo.T_TxnDetail as t WITH (NOLOCK)
       inner join #terms1 as b 
       on t.ATMInternalID = b.ATMInternalID
 where t.SettlementDate >= (select dt from #dates where varname = 'AllocStart') 
   and t.SettlementDate <= (select dt from #dates where varname = 'AllocEnd')
   and t.TxnTypeID = 1
   and t.ResponseCodeID = 1
   and t.Txn = 1
   and t.BankID in (487917, 433419)
   and t.ATMInternalID in (select ATMInternalID from #terms1) -- changes execution plan, much faster
 group by t.ATMInternalID, cast(t.SettlementDate as date);
--145431

/* How many ATMs w Varo transactinos? */
select count(distinct ATMInternalID)
  from #varo_wt;
--29565  

select count(*)
  from #varo_wt;
--145431  

create index tmpAP3 on #varo_wt (ATMInternalID);
create index tmpAP4 on #varo_wt (SettlementDate);

IF OBJECT_ID('tempdb..#wt_bau1', 'U') IS NOT NULL 
   drop table #wt_bau1;
select a.*, 
       DATEPART(dw, SettlementDate) as WkDay
  into #wt_bau1
  from #varo_wt a;

select SettlementDate, 
       sum(n_WD) as totwd
  from #wt_bau1
 group by SettlementDate
 order by 1;


IF OBJECT_ID('tempdb..#test2', 'U') IS NOT NULL 
   drop table #test2;
select ATMInternalID, 
       WkDay, 
       sum(n_WD) as n_WD, 
	   sum(WDAmt) as WDAmt
  into #test2
  from #wt_bau1
 group by ATMInternalID, WkDay;

select *
  from #test2
  order by ATMInternalID, WkDay;

IF OBJECT_ID('tempdb..#test3', 'U') IS NOT NULL 
   drop table #test3;
select WkDay, 
       sum(n_WD) as n_WDTot, 
	   sum(WDAmt) as WDAmtTot
  into #test3
  from #wt_bau1
 group by WkDay;

select *
  from #test3
 order by WkDay;

/* Calculate weights for each ATM for each day of week, equal to the proportion of withdrawals for 
   that ATM for that day of week to the total withdrawals for Varo for that day of week. */

IF OBJECT_ID('tempdb..#allocwt_base', 'U') IS NOT NULL 
   drop table #allocwt_base;
select a.*, 
       b.n_WDTot, 
	   b.WDAmtTot, 
	   case when b.n_WDTot > 0 then (cast(n_WD as float) / cast(b.n_WDTot as float))
            else 0 end as wt_wd, 
	   case when b.WDAmtTot > 0 then (cast(WDAmt as float) / cast(b.WDAmtTot as float))
            else 0 end as wt_wdamt
  into #allocwt_base
  from #test2 a
       left join #test3 b 
	   on a.WkDay = b.WkDay;

select *
  from #allocwt_base
 where ATMInternalID = 163994
 order by WkDay;

select ATMInternalID, 
       WkDay, 
	   count(*) as n_rec
  from #allocwt_base
 group by ATMInternalID, WkDay
having count(*) > 1;
--0

select WkDay, 
       sum(wt_wd), 
	   sum(wt_wdamt)
  from #allocwt_base
 group by WkDay
 order by WkDay;


/* Create table for Varo by ATM ID and forecast date, with total number of withdrawals for 
   Varo BINs on forecast date, the weight for the forecast date's day of week, and projected number of 
   withdrawals for that ATM calculated as forecasted total number of Varo withdrawals
   for forecast date times the weight for the forecast date's day of week. */

IF OBJECT_ID('tempdb..#proj_n_wd', 'U') IS NOT NULL 
   drop table #proj_n_wd;
select x.*, 
       isnull(z.wt_wd,0) as wt_wd,
	   x.Totn_WD * isnull(z.wt_wd,0) as n_WD
  into #proj_n_wd
  from
        /* Cross join list of ATMs in subquery with list of forecast dates and forecasted total 
		   number of withdrawals for Varo BINs for that date. */
       (select a.ATMInternalID, 
	           b.ForecastDate, 
		       b.n_WD as Totn_WD, 
		       DATEPART(dw, b.ForecastDate) as WkDay, 
			   DATEPART(week, b.ForecastDate) as WkNum
        from
            /* list of ATMs with Varo withdrawal transactions */
			(select distinct ATMInternalID
               from #varo_wt
              where n_WD > 0
            )a
        cross join #fcst b 
        )x
left join #allocwt_base z on
    x.ATMInternalID = z.ATMInternalID and
    x.WkDay = z.WkDay;

select *
  from #proj_n_wd
 where ATMInternalID=163994
 order by ForecastDate;


select ForecastDate, 
         sum(n_WD) as n_WD
    from #proj_n_wd
group by ForecastDate
order by 1;

/********************************************************************************************************
Varo has a cyclic pattern to average dispense per withdrawal as it is higher at the beginning of the 
      month and lower the rest of the month. Calculate two values to use during these times. The BOM 
	  value is calculated as the average of the last two weeks including the first of the month. The 
	  ROM value is calculated as the average of the last three continguous weeks that do not include the 
	  first of the month. 
*********************************************************************************************************/
/***********************************************************************************************
Find Beginning of Month $/WD average as it is higher than the rest of the month. 
***********************************************************************************************/
/* Collect Beginning of Month (week containing the 1st) withdrawal transactions. */
IF OBJECT_ID('tempdb..#varo_bom_wt', 'U') IS NOT NULL 
   drop table #varo_bom_wt;
select b.ATMInternalID, 
	   sum(case when b.[txntypeid] = 1 then 1 else 0 end) as n_WD,
	   sum(case when b.[txntypeid] = 1 then amount else 0 end) as WDAmt
  into #varo_bom_wt
  from [SSRSReports].[WebReportsUser].[KYC_CASH_PROJ_2023_Finance_Data] b
       inner join #terms1 x 
	   on b.ATMInternalID = x.ATMInternalID
 where b.APBinMatchBIN in ('487917', '433419')
   and b.SettlementDate >= (select dt from #dates where varname = 'BOM1Start') 
   and b.SettlementDate <= (select dt from #dates where varname = 'BOM1End')
 group by b.ATMInternalID;
--20101

insert into #varo_bom_wt
select b.ATMInternalID, 
	   sum(case when b.[txntypeid] = 1 then 1 else 0 end) as n_WD,
	   sum(case when b.[txntypeid] = 1 then amount else 0 end) as WDAmt
  from [SSRSReports].[WebReportsUser].[KYC_CASH_PROJ_2023_Finance_Data] b
       inner join #terms1 x 
	   on b.ATMInternalID = x.ATMInternalID
 where b.APBinMatchBIN in ('487917', '433419') 
   and b.SettlementDate >= (select dt from #dates where varname = 'BOM2Start') 
   and b.SettlementDate <= (select dt from #dates where varname = 'BOM2End')
 group by b.ATMInternalID;
--20178
 
insert into #varo_bom_wt
select b.ATMInternalID, 
	   sum(case when b.[txntypeid] = 1 then 1 else 0 end) as n_WD,
	   sum(case when b.[txntypeid] = 1 then amount else 0 end) as WDAmt
  from [SSRSReports].[WebReportsUser].[KYC_CASH_PROJ_2023_Finance_Data] b
       inner join #terms1 x 
	   on b.ATMInternalID = x.ATMInternalID
 where b.APBinMatchBIN in ('487917', '433419')
   and b.SettlementDate >= (select dt from #dates where varname = 'BOM3Start') 
   and b.SettlementDate <= (select dt from #dates where varname = 'BOM3End')
 group by b.ATMInternalID;
--19450

select count(*) from #varo_bom_wt;
--59729

/* Sum rows over ATMInternalID where there were rows from multiple BOM queries for one ATM. */
IF OBJECT_ID('tempdb..#varo_bom_wt_total', 'U') IS NOT NULL 
   drop table #varo_bom_wt_total; 
select ATMInternalID, 
	   sum(n_WD) as n_WD, 
	   sum(WDAmt) as WDAmt
  into #varo_bom_wt_total	   
  from #varo_bom_wt
 group by ATMInternalID; 
 
select ATMInternalID 
  from #varo_bom_wt_total
 group by ATMInternalID
having count(*) > 1;
--0

/* Calculate average dispense per withdrawal for BOM period. */

IF OBJECT_ID('tempdb..#varo_bom_avg', 'U') IS NOT NULL 
   drop table #varo_bom_avg; 
select ATMInternalID, 
       n_WD, 
	   WDAmt,
	   (cast(WDAmt as float) / cast(n_WD as float)) as AvgWDAmt
  into #varo_bom_avg
  from (select *
          from #varo_bom_wt_total
       )x;

select *
  from #varo_bom_avg;

/***********************************************************************************************
Find Rest of Month $/WD average as it is lower than the beginning of the month. Need to use 
    dates that do not include the first week of the month.  
***********************************************************************************************/
/* Collect varo Rest of Month (weeks not containing the 1st) withdrawal transactions. */
IF OBJECT_ID('tempdb..#varo_rom_wt', 'U') IS NOT NULL 
   drop table #varo_rom_wt; 
select b.ATMInternalID, 
	   sum(case when b.[txntypeid] = 1 then 1 else 0 end) as n_WD,
	   sum(case when b.[txntypeid] = 1 then amount else 0 end) as WDAmt
  into #varo_rom_wt
  from [SSRSReports].[WebReportsUser].[KYC_CASH_PROJ_2023_Finance_Data] b
       inner join #terms1 x 
	   on b.ATMInternalID = x.ATMInternalID
 where b.APBinMatchBIN in ('487917', '433419')
   and b.SettlementDate >= (select dt from #dates where varname = 'ROMStart') 
   and b.SettlementDate <= (select dt from #dates where varname = 'ROMEnd')
 group by b.ATMInternalID;

 
select ATMInternalID 
  from #varo_rom_wt
 group by ATMInternalID
having count(*) > 1;
--0

select ATMInternalID, 
	   n_WD, 
	   WDAmt
  from #varo_rom_wt
 order by ATMInternalID; 
 
/* Calculate total withdrawals and withdrawal amount by ATM, for tranactions in the period
   on active terminals. */

/* Calculate average withdrawal amount by ATM within this period. */
IF OBJECT_ID('tempdb..#varo_rom_avg', 'U') IS NOT NULL 
   drop table #varo_rom_avg; 
select ATMInternalID, 
       n_WD, 
	   WDAmt,
	   (cast(WDAmt as float) / cast(n_WD as float)) as AvgWDAmt
  into #varo_rom_avg
  from (select *
          from #varo_rom_wt
       )x;
	   
select top 1000 *
  from #proj_n_wd;

select avg(AvgWDAmt)
  from #varo_bom_avg;
--149.628472284259

select avg(AvgWDAmt)
  from #varo_rom_avg; 
--139.750058646564

/*insert BOM/ROM avgs into #BOM_ROM_List
*/

Insert into #BOM_ROM_List Select 'varo',
	(select avg(AvgWDAmt)
		from #varo_bom_avg),
	(select avg(AvgWDAmt)
		from #varo_rom_avg);

select * from #BOM_ROM_List;
/* Project daily withdrawal amount by ATM by multiplying projected number of withdrawals by average 
   withdrawal amount over the three week period. */
   
/* **NOTE**: Update defaults for bom, rom from avg(AvgWDAmt) from bom, rom tables. 
             **Update a.WkNum list for BOM weeks in forecast period.
			 ** For Jun5 forecasting, week 32,36,40,45 are BOM*/

IF OBJECT_ID('tempdb..#proj_varo_fin', 'U') IS NOT NULL 
   drop table #proj_varo_fin; 
select a.*, 
       case when a.WkNum in (9,13,18,22,26,31,35,40,44,48) 
	        then 
			/* Some ATMs have BOM AvgWDAmt that are less than ROM. If so, use ROM all month. */
			     case when isnull(b.AvgWDAmt,
					(select BOM from #BOM_ROM_List where issuer = 'varo')) > isnull(r.AvgWDAmt,
						(select ROM from #BOM_ROM_List where issuer = 'varo')) 
				      then isnull(b.AvgWDAmt,
						(select BOM from #BOM_ROM_List where issuer = 'varo')) 
					  else isnull(r.AvgWDAmt,
						(select ROM from #BOM_ROM_List where issuer = 'varo'))
				 end
            else case when a.WkDay = 5 then isnull(r.AvgWDAmt,
				(select ROM from #BOM_ROM_List where issuer = 'varo')) + 18.0
			          when a.WkDay = 6 then isnull(b.AvgWDAmt,
						(select ROM from #BOM_ROM_List where issuer = 'varo')) + 10.0
					  else isnull(r.AvgWDAmt,
						(select ROM from #BOM_ROM_List where issuer = 'varo'))
				end
       end as AvgWDAmt, 
	   case when a.WkNum in (9,13,18,22,26,31,35,40,44,48) 
	        then 
			     case when isnull(b.AvgWDAmt,
					(select BOM from #BOM_ROM_List where issuer = 'varo')) > isnull(r.AvgWDAmt,
					(select ROM from #BOM_ROM_List where issuer = 'varo')) 
				      then a.n_WD * isnull(b.AvgWDAmt,
						(select BOM from #BOM_ROM_List where issuer = 'varo'))
					  else a.n_WD * isnull(r.AvgWDAmt,
						(select ROM from #BOM_ROM_List where issuer = 'varo'))
				 end
            else case when a.WkDay = 5 then a.n_WD * (isnull(r.AvgWDAmt,
				(select ROM from #BOM_ROM_List where issuer = 'varo') + 18.0))
			          when a.WkDay = 6 then a.n_WD * (isnull(b.AvgWDAmt,
						(select ROM from #BOM_ROM_List where issuer = 'varo')) + 10.0)
				      else a.n_WD * isnull(r.AvgWDAmt,
						(select ROM from #BOM_ROM_List where issuer = 'varo'))
				 end
       end as WDAmt
  into #proj_varo_fin
  from #proj_n_wd a
       left join #varo_rom_avg r 
	   on a.ATMInternalID = r.ATMInternalID
	   left join #varo_bom_avg b
	   on a.ATMInternalID = b.ATMInternalID;


select *
  from #varo_rom_avg;

select ForecastDate, sum(n_WD) as n_WD, sum(WDAmt) as WDAmt
  from #proj_varo_fin
 group by ForecastDate
 order by 1;
 
IF OBJECT_ID('SSRSReports.WebReportsUser.KYC_CASH_PROJ_#proj_varo_fin', 'U') IS NOT NULL 
   drop table SSRSReports.WebReportsUser.KYC_CASH_PROJ_#proj_varo_fin; 
select * 
  into SSRSReports.WebReportsUser.KYC_CASH_PROJ_#proj_varo_fin
  from #proj_varo_fin;


/* restore #proj_varo_fin 
IF OBJECT_ID('tempdb..#proj_varo_fin', 'U') IS NOT NULL 
   drop table #proj_varo_fin; 
select * 
  into #proj_varo_fin
  from SSRSReports.WebReportsUser.KYC_CASH_PROJ_#proj_varo_fin;
--2431380
*/

select ForecastDate, sum(n_WD) as n_WD, sum(WDAmt) as WDAmt
  from SSRSReports.WebReportsUser.KYC_CASH_PROJ_#proj_varo_fin
where ForecastDate is not NULL
 group by ForecastDate
 order by 1;


select --SettlementDate, 
       count(*) as n_WD, 
	   sum(amount) as WDAmt, 
	   sum(amount)/count(*) as AvgWDAmt
  from SSRSReports.WebReportsUser.KYC_CASH_PROJ_2023_Finance_Data f
       inner join #terms1 t
	   on f.ATMInternalID = t.ATMInternalID
 where f.APBinMatchBIN in ('487917', '433419')
    and APBinMatch = 1
    and SettlementDate >= (select dt from #dates where varname = 'AllocStart')
	and SettlementDate <= (select dt from #dates where varname = 'AllocEnd');

/* This is the total transactions and overall AvgWdAmt for the period as a whole. 
n_WD	WDAmt	AvgWDAmt
143581	20838810.00	145.1362
*/

IF OBJECT_ID('SSRSReports.WebReportsUser.KYC_CASH_PROJ_#BOM_ROM_List', 'U') IS NOT NULL 
   drop table SSRSReports.WebReportsUser.KYC_CASH_PROJ_#BOM_ROM_List; 
select * 
  into SSRSReports.WebReportsUser.KYC_CASH_PROJ_#BOM_ROM_List
  from #BOM_ROM_List;

select * from #BOM_ROM_List;
/*************************************************************
US Bank Projection: FcstStart to FcstEnd
2/9/21 tc added several BINs to US Bank: 446053611, 49128806, 
          49128808,49128820
2/11/22 replaced US Bank UI BINs with US Bank - Private 
           payroll BINs
**************************************************************/
IF OBJECT_ID('tempdb..#dates', 'U') IS NULL
	select *
	into #dates
	from [SSRSReports].[WebReportsUser].[KYC_CASH_PROJ_DATES_JUL2]

IF OBJECT_ID('tempdb..#terms1', 'U') IS NULL
	select *
	into #terms1
	from [SSRSReports].[WebReportsUser].[KYC_CASH_PROJ_TERMS1]

IF OBJECT_ID('tempdb..#new', 'U') IS NULL 
	select *
	  into #new
	  from #terms1
	 where cast(AUDFD2 as date) > (select dt from #dates where varname = 'BaselineStart'); 

IF OBJECT_ID('tempdb..#BOM_ROM_List', 'U') IS NULL
	create table #BOM_ROM_List
	(
		issuer varchar(20) primary key,
		BOM float,
		ROM float
	);
select * from #BOM_ROM_List;
-----------
select *
  from [SSRSReports].[WebReportsUser].[KYC_CASH_PROJ_INP];

IF OBJECT_ID('tempdb..#fcst', 'U') IS NOT NULL 
   drop table #fcst;
/* Pull US Bank forecast of number of withdrawals. */
select cast(FcstDate as date) as ForecastDate, 
       sum(USBank) as n_WD
  into #fcst
  from [SSRSReports].[WebReportsUser].[KYC_CASH_PROJ_INP]
 group by cast(FcstDate as date)
 order by 1;

select *
  from #fcst;


/* Use Last 4 weeks of data available, AllocStart to AllocEnd, to create weights for ATMs.*/
/* scale it down, much faster*/
IF OBJECT_ID('tempdb..#usb_pre', 'U') IS NOT NULL 
   drop table #usb_pre;
select *
into #usb_pre
from  [SSRSReports].[WebReportsUser].[KYC_CASH_PROJ_2023_Finance_Data]
where APBinMatchBIN in ('406069', '408031', '411238', '417021', '426752', 
                         '428191', '431582', '441814', '443161', '478665', 
                         '479841', '487081', '511562', '516175', '517750', 
                         '524913', '531462', '4168600', '4440838', '41455700', 
                         '43073111', '45841500', '45841550', '49990101')
   and cast(SettlementDate as Date) >= (select dt from #dates where varname = 'AllocStart')
   and cast(SettlementDate as Date) <= (select dt from #dates where varname = 'AllocEnd');

IF OBJECT_ID('tempdb..#usbank_wt', 'U') IS NOT NULL 
   drop table #usbank_wt;
select b.ATMInternalID, cast(b.SettlementDate as date) as SettlementDate,
	   sum(case when b.[txntypeid] = 1 then 1 else 0 end) as n_WD,
	   sum(case when b.[txntypeid] = 1 then amount else 0 end) as WDAmt
  into #usbank_wt
  from #usb_pre b
       inner join #terms1 x 
	   on b.ATMInternalID = x.ATMInternalID
 where b.ATMInternalID IN (select ATMInternalID from #terms1)
 group by b.ATMInternalID, cast(b.SettlementDate as date);
--246004
 /*
IF OBJECT_ID('tempdb..#usbank_wt', 'U') IS NOT NULL 
   drop table #usbank_wt;
select b.ATMInternalID, cast(b.SettlementDate as date) as SettlementDate,
	   sum(case when b.[txntypeid] = 1 then 1 else 0 end) as n_WD,
	   sum(case when b.[txntypeid] = 1 then amount else 0 end) as WDAmt
  into #usbank_wt
  from [SSRSReports].[WebReportsUser].[KYC_CASH_PROJ_2023_Finance_Data] b
       inner join #terms1 x 
	   on b.ATMInternalID = x.ATMInternalID
 where APBinMatchBIN in ('406069', '408031', '411238', '417021', '426752', 
                         '428191', '431582', '441814', '443161', '478665', 
                         '479841', '487081', '511562', '516175', '517750', 
                         '524913', '531462', '4168600', '4440838', '41455700', 
                         '43073111', '45841500', '45841550', '49990101')
   and cast(b.SettlementDate as Date) >= (select dt from #dates where varname = 'AllocStart')
   and cast(b.SettlementDate as Date) <= (select dt from #dates where varname = 'AllocEnd')
   and b.ATMInternalID IN (select ATMInternalID from #terms1)
 group by b.ATMInternalID, cast(b.SettlementDate as date);*/
 --238351
 -- more than an hour 11/17/22

create index tmpAP3 on #usbank_wt (ATMInternalID);
create index tmpAP4 on #usbank_wt (SettlementDate);


select count(distinct ATMInternalID)
  from #usbank_wt;
--35996

select SettlementDate, sum(n_WD) as n_WD
  from #usbank_wt
 group by SettlementDate
 order by SettlementDate;

IF OBJECT_ID('tempdb..#wt_bau1', 'U') IS NOT NULL 
   drop table #wt_bau1;
select a.*, DATEPART(dw, SettlementDate) as WkDay
  into #wt_bau1
  from #usbank_wt a;

select SettlementDate, sum(n_WD) as totwd
  from #wt_bau1
 group by SettlementDate
 order by 1;

IF OBJECT_ID('tempdb..#test2', 'U') IS NOT NULL 
   drop table #test2;
/* Calculate total number of withdrawals and withdrawal amount by ATM and day of week. */
select ATMInternalID, WkDay, sum(n_WD) as n_WD, sum(WDAmt) as WDAmt
  into #test2
  from #wt_bau1
 group by ATMInternalID, WkDay;

select *
  from #test2;

IF OBJECT_ID('tempdb..#test3', 'U') IS NOT NULL 
   drop table #test3;
/* Calculate total number of withdrawals and withdrawal amount by day of week only. */
select WkDay, sum(n_WD) as n_WDTot, sum(WDAmt) as WDAmtTot
  into #test3
  from #wt_bau1
 group by WkDay;

select *
  from #test3
 order by WkDay;

IF OBJECT_ID('tempdb..#allocwt_base', 'U') IS NOT NULL 
   drop table #allocwt_base;
/* Calculate proportion of withdrawals for each ATM for each day of week to the total US Bank withdrawals 
   for that day of week. Also calculate the proportion of withdrawal amount for each ATM for each day of 
   week to the total US Bank withdrawal amount for each day of the week. */
select a.*, 
       b.n_WDTot, 
	   b.WDAmtTot, 
	   case when b.n_WDTot > 0 then (cast(n_WD as float) / cast(b.n_WDTot as float)) 
	        else 0 end as wt_wd, 
	   case when b.WDAmtTot > 0 then (cast(WDAmt as float) / cast(b.WDAmtTot as float)) 
	        else 0 end as wt_wdamt
  into #allocwt_base
  from #test2 a
       left join #test3 b 
	   on a.WkDay = b.WkDay;



select ATMInternalID, WkDay, count(*) as n_rec
  from #allocwt_base
 group by ATMInternalID, WkDay
having count(*) > 1;
--0

select WkDay, sum(wt_wd), sum(wt_wdamt)
  from #allocwt_base
 group by WkDay
 order by WkDay;

IF OBJECT_ID('tempdb..#proj_n_wd', 'U') IS NOT NULL 
   drop table #proj_n_wd;
/* Create table for US Bank by ATM ID and forecast date, with total number of withdrawals for 
   US Bank BINs on forecast date, the weight for the forecast date's day of week, and projected number of 
   withdrawals for that ATM calculated as forecasted total number of US Bank withdrawals
   for forecast date times the weight for the forecast date's day of week. */
select x.*, isnull(z.wt_wd,0) as wt_wd,
       x.Totn_WD * isnull(z.wt_wd,0) as n_WD
  into #proj_n_wd
        /* Cross join list of ATMs with forecast date table to get one row for each ATM for 
		   each day to be forecasted, with the total number of US Bank withdrawals forecasted
		   for that day and the day of the week. */
  from (select a.ATMInternalID, 
               b.ForecastDate, 
			   b.n_WD as Totn_WD, 
			   DATEPART(dw, b.ForecastDate) as WkDay, 
			   DATEPART(week, b.ForecastDate) as WkNum
			   /* create list of ATM IDs with US Bank withdrawal transactions */
          from (select distinct ATMInternalID
                  from #usbank_wt
                 where n_WD > 0
               )a
               cross join #fcst b 
       )x
       left join #allocwt_base z 
	   on x.ATMInternalID = z.ATMInternalID 
	       and x.WkDay = z.WkDay;

select ForecastDate, sum(n_WD) as n_WD
  from #proj_n_wd
 group by ForecastDate
 order by 1;


/********************************************************************************************************
US Bank has a cyclic pattern to average dispense per withdrawal as it is higher at the beginning of the 
      month and lower the rest of the month. Calculate two values to use during these times. The BOM 
	  value is calculated as the average of the last two weeks including the first of the month. The 
	  ROM value is calculated as the average of the last three continguous weeks that do not include the 
	  first of the month. 
*********************************************************************************************************/
/***********************************************************************************************
Find Beginning of Month $/WD average as it is higher than the rest of the month. 
***********************************************************************************************/
/* Collect Beginning of Month (week containing the 1st) withdrawal transactions. */
IF OBJECT_ID('tempdb..#usb_bom_wt', 'U') IS NOT NULL 
   drop table #usb_bom_wt;
select b.ATMInternalID, 
	   sum(case when b.[txntypeid] = 1 then 1 else 0 end) as n_WD,
	   sum(case when b.[txntypeid] = 1 then amount else 0 end) as WDAmt
  into #usb_bom_wt
  from [SSRSReports].[WebReportsUser].[KYC_CASH_PROJ_2023_Finance_Data] b
       inner join #terms1 x 
	   on b.ATMInternalID = x.ATMInternalID
 where APBinMatchBIN in ('406069', '408031', '411238', '417021', '426752', 
                         '428191', '431582', '441814', '443161', '478665', 
                         '479841', '487081', '511562', '516175', '517750', 
                         '524913', '531462', '4168600', '4440838', '41455700', 
                         '43073111', '45841500', '45841550', '49990101')
   and b.SettlementDate >= (select dt from #dates where varname = 'BOM1Start') 
   and b.SettlementDate <= (select dt from #dates where varname = 'BOM1End')
 group by b.ATMInternalID;
--25089

insert into #usb_bom_wt
select b.ATMInternalID, 
	   sum(case when b.[txntypeid] = 1 then 1 else 0 end) as n_WD,
	   sum(case when b.[txntypeid] = 1 then amount else 0 end) as WDAmt
  from [SSRSReports].[WebReportsUser].[KYC_CASH_PROJ_2023_Finance_Data] b
       inner join #terms1 x 
	   on b.ATMInternalID = x.ATMInternalID
 where APBinMatchBIN in ('406069', '408031', '411238', '417021', '426752', 
                         '428191', '431582', '441814', '443161', '478665', 
                         '479841', '487081', '511562', '516175', '517750', 
                         '524913', '531462', '4168600', '4440838', '41455700', 
                         '43073111', '45841500', '45841550', '49990101')
   and b.SettlementDate >= (select dt from #dates where varname = 'BOM2Start') 
   and b.SettlementDate <= (select dt from #dates where varname = 'BOM2End')
 group by b.ATMInternalID;
--24955
 
insert into #usb_bom_wt
select b.ATMInternalID, 
	   sum(case when b.[txntypeid] = 1 then 1 else 0 end) as n_WD,
	   sum(case when b.[txntypeid] = 1 then amount else 0 end) as WDAmt
  from [SSRSReports].[WebReportsUser].[KYC_CASH_PROJ_2023_Finance_Data] b
       inner join #terms1 x 
	   on b.ATMInternalID = x.ATMInternalID
 where APBinMatchBIN in ('406069', '408031', '411238', '417021', '426752', 
                         '428191', '431582', '441814', '443161', '478665', 
                         '479841', '487081', '511562', '516175', '517750', 
                         '524913', '531462', '4168600', '4440838', '41455700', 
                         '43073111', '45841500', '45841550', '49990101')
   and b.SettlementDate >= (select dt from #dates where varname = 'BOM3Start') 
   and b.SettlementDate <= (select dt from #dates where varname = 'BOM3End')
 group by b.ATMInternalID;
--24922

select count(*) from #usb_bom_wt;
--74966

/* Sum rows over ATMInternalID where there were rows from multiple BOM queries for one ATM. */
IF OBJECT_ID('tempdb..#usb_bom_wt_total', 'U') IS NOT NULL 
   drop table #usb_bom_wt_total; 
select ATMInternalID, 
	   sum(n_WD) as n_WD, 
	   sum(WDAmt) as WDAmt
  into #usb_bom_wt_total	   
  from #usb_bom_wt
 group by ATMInternalID; 
 
select ATMInternalID 
  from #usb_bom_wt_total
 group by ATMInternalID
having count(*) > 1;
--0

/* Calculate average dispense per withdrawal for BOM period. */

IF OBJECT_ID('tempdb..#usb_bom_avg', 'U') IS NOT NULL 
   drop table #usb_bom_avg; 
select ATMInternalID, 
       n_WD, 
	   WDAmt,
	   (cast(WDAmt as float) / cast(n_WD as float)) as AvgWDAmt
  into #usb_bom_avg
  from (select *
          from #usb_bom_wt_total
       )x;

select *
  from #usb_bom_avg;

/***********************************************************************************************
Find Rest of Month $/WD average as it is lower than the beginning of the month. Need to use 
    dates that do not include the first week of the month.  
***********************************************************************************************/
/* Collect usb Rest of Month (weeks not containing the 1st) withdrawal transactions. */
IF OBJECT_ID('tempdb..#usb_rom_wt', 'U') IS NOT NULL 
   drop table #usb_rom_wt; 
select b.ATMInternalID, 
	   sum(case when b.[txntypeid] = 1 then 1 else 0 end) as n_WD,
	   sum(case when b.[txntypeid] = 1 then amount else 0 end) as WDAmt
  into #usb_rom_wt
  from [SSRSReports].[WebReportsUser].[KYC_CASH_PROJ_2023_Finance_Data] b
       inner join #terms1 x 
	   on b.ATMInternalID = x.ATMInternalID
 where APBinMatchBIN in ('406069', '408031', '411238', '417021', '426752', 
                         '428191', '431582', '441814', '443161', '478665', 
                         '479841', '487081', '511562', '516175', '517750', 
                         '524913', '531462', '4168600', '4440838', '41455700', 
                         '43073111', '45841500', '45841550', '49990101')
   and b.SettlementDate >= (select dt from #dates where varname = 'ROMStart') 
   and b.SettlementDate <= (select dt from #dates where varname = 'ROMEnd')
 group by b.ATMInternalID;

select ATMInternalID 
  from #usb_rom_wt
 group by ATMInternalID
having count(*) > 1;
--0

select ATMInternalID, 
	   n_WD, 
	   WDAmt
  from #usb_rom_wt
 order by ATMInternalID; 
 
/* Calculate total withdrawals and withdrawal amount by ATM, for tranactions in the period
   on active terminals. */

/* Calculate average withdrawal amount by ATM within this period. */
IF OBJECT_ID('tempdb..#usb_rom_avg', 'U') IS NOT NULL 
   drop table #usb_rom_avg; 
select ATMInternalID, 
       n_WD, 
	   WDAmt,
	   (cast(WDAmt as float) / cast(n_WD as float)) as AvgWDAmt
  into #usb_rom_avg
  from (select *
          from #usb_rom_wt
       )x;

select top 1000 *
  from #proj_n_wd;

select avg(AvgWDAmt)
  from #usb_bom_avg;
--198.863729479999
  
select avg(AvgWDAmt)
  from #usb_rom_avg; 
--194.596267029683

Insert into #BOM_ROM_List Select 'usb',
	(select avg(AvgWDAmt)
		from #usb_bom_avg),
	(select avg(AvgWDAmt)
		from #usb_rom_avg);

select * from #BOM_ROM_List;

IF OBJECT_ID('SSRSReports.WebReportsUser.KYC_CASH_PROJ_#BOM_ROM_List', 'U') IS NOT NULL 
   drop table SSRSReports.WebReportsUser.KYC_CASH_PROJ_#BOM_ROM_List; 
select * 
  into SSRSReports.WebReportsUser.KYC_CASH_PROJ_#BOM_ROM_List
  from #BOM_ROM_List;
/* Project daily withdrawal amount by ATM by multiplying projected number of withdrawals by average 
   withdrawal amount over the three week period. */
   
/* **NOTE**: Update defaults for bom, rom from avg(AvgWDAmt) from bom, rom tables. 
             **Update a.WkNum list for BOM weeks in forecast period. 
			 
  4/8/22:   Last month had shortfall every Friday and Saturday during ROM of around $20/txn. Add a bump. 
            Friday is WkDay = 6, Saturday is WkDay = 7.*/

IF OBJECT_ID('tempdb..#proj_usbank_fin', 'U') IS NOT NULL 
   drop table #proj_usbank_fin; 
select a.*, 
       case when a.WkNum in (9,13,18,22,26,31,35,40,44,48) 
	        then 
			/* Some ATMs have BOM AvgWDAmt that are less than ROM. If so, use ROM all month. */
			     case when isnull(b.AvgWDAmt,
					(select BOM from #BOM_ROM_List where issuer = 'usb') ) > isnull(r.AvgWDAmt,
						(select ROM from #BOM_ROM_List where issuer = 'usb') )
				      then isnull(b.AvgWDAmt,
						(select BOM from #BOM_ROM_List where issuer = 'usb') )
					  else isnull(r.AvgWDAmt,
						(select ROM from #BOM_ROM_List where issuer = 'usb'))
				 end
            else case when a.WkDay = 6 then isnull(r.AvgWDAmt,
				(select ROM from #BOM_ROM_List where issuer = 'usb')) + 20.0
			          when a.WkDay = 7 then isnull(b.AvgWDAmt,
						(select ROM from #BOM_ROM_List where issuer = 'usb')) + 20.0
					  else isnull(r.AvgWDAmt,
						(select ROM from #BOM_ROM_List where issuer = 'usb'))
				 end
       end as AvgWDAmt, 
	   case when a.WkNum in (9,13,18,22,26,31,35,40,44,48) 
	        then 
			     case when isnull(b.AvgWDAmt,
					(select BOM from #BOM_ROM_List where issuer = 'usb')) > isnull(r.AvgWDAmt,
						(select ROM from #BOM_ROM_List where issuer = 'usb') )
				      then a.n_WD * isnull(b.AvgWDAmt,
						(select BOM from #BOM_ROM_List where issuer = 'usb') )
					  else a.n_WD * isnull(r.AvgWDAmt,
						(select ROM from #BOM_ROM_List where issuer = 'usb'))
				 end
            else case when a.WkDay = 6 then a.n_WD * (isnull(r.AvgWDAmt,
				(select ROM from #BOM_ROM_List where issuer = 'usb')) + 20.0)
			          when a.WkDay = 7 then a.n_WD * (isnull(b.AvgWDAmt,
						(select ROM from #BOM_ROM_List where issuer = 'usb')) + 20.0)
				      else a.n_WD * isnull(r.AvgWDAmt,
						(select ROM from #BOM_ROM_List where issuer = 'usb'))
				 end
       end as WDAmt
  into #proj_usbank_fin
  from #proj_n_wd a
       left join #usb_rom_avg r 
	   on a.ATMInternalID = r.ATMInternalID
	   left join #usb_bom_avg b
	   on a.ATMInternalID = b.ATMInternalID;

 select ForecastDate, sum(n_WD) as n_WD, sum(WDAmt) as WDAmt
  from #proj_usbank_fin
where ForecastDate is not NULL
 group by ForecastDate
 order by 1;
  
IF OBJECT_ID('SSRSReports.WebReportsUser.KYC_CASH_PROJ_#proj_usbank_fin', 'U') IS NOT NULL 
   drop table SSRSReports.WebReportsUser.KYC_CASH_PROJ_#proj_usbank_fin; 
select * 
  into SSRSReports.WebReportsUser.KYC_CASH_PROJ_#proj_usbank_fin
  from #proj_usbank_fin
--3059660

/* restore #proj_usbank_fin

IF OBJECT_ID('tempdb..#proj_usbank_fin', 'U') IS NOT NULL 
   drop table #proj_usbank_fin; 
select * 
  into #proj_usbank_fin
  from SSRSReports.WebReportsUser.KYC_CASH_PROJ_#proj_usbank_fin;
--3030972
*/


select --SettlementDate, 
       count(*) as n_WD, 
	   sum(amount) as WDAmt, 
	   sum(amount)/count(*) as AvgWDAmt
  from SSRSReports.WebReportsUser.KYC_CASH_PROJ_2023_Finance_Data f
       inner join #terms1 t
	   on f.ATMInternalID = t.ATMInternalID
 where APBinMatchBIN in ('406069', '408031', '411238', '417021', '426752', 
                         '428191', '431582', '441814', '443161', '478665', 
                         '479841', '487081', '511562', '516175', '517750', 
                         '524913', '531462', '4168600', '4440838', '41455700', 
                         '43073111', '45841500', '45841550', '49990101')
    and APBinMatch = 1
    and SettlementDate >= (select dt from #dates where varname = 'AllocStart')
	and SettlementDate <= (select dt from #dates where varname = 'AllocEnd');

/* Total across the allocation period for the entire BIN group. 
n_WD	WDAmt	AvgWDAmt
457842	106141690.00	231.8303
*/



/*************************************************************
Skylight Projection: FcstStart to FcstEnd
Non-AP BIN (442743)
2/10/21 tc  Added BIN 511560 (IA UI)
2/11/22 Replaced BoA non-AP UI with Skylight Financial Payroll
**************************************************************/

IF OBJECT_ID('tempdb..#dates', 'U') IS NULL
	select *
	into #dates
	from [SSRSReports].[WebReportsUser].[KYC_CASH_PROJ_DATES_JUL2]

IF OBJECT_ID('tempdb..#terms1', 'U') IS NULL
	select *
	into #terms1
	from [SSRSReports].[WebReportsUser].[KYC_CASH_PROJ_TERMS1]

IF OBJECT_ID('tempdb..#new', 'U') IS NULL 
	select *
	  into #new
	  from #terms1
	 where cast(AUDFD2 as date) > (select dt from #dates where varname = 'BaselineStart'); 

IF OBJECT_ID('tempdb..#BOM_ROM_List', 'U') IS NULL

	create table #BOM_ROM_List
	(
		issuer varchar(20) primary key,
		BOM float,
		ROM float
	);
select * from #BOM_ROM_List;

/* Pull Skylight forecast of number of withdrawals. */
IF OBJECT_ID('tempdb..#fcst', 'U') IS NOT NULL 
   drop table #fcst;
select cast(FcstDate as date) as ForecastDate, 
       sum(Skylight) as n_WD
  into #fcst
  from [SSRSReports].[WebReportsUser].[KYC_CASH_PROJ_INP]
 group by cast(FcstDate as date)
 order by 1;

select *
  from #fcst;

/* Use Last 4 weeks of data available, AllocStart to AllocEnd, to create weights for ATMs. */
IF OBJECT_ID('tempdb..#skylight_wt', 'U') IS NOT NULL 
   drop table #skylight_wt;
select b.ATMInternalID, cast(b.SettlementDate as date) as SettlementDate,
	   sum(case when b.[txntypeid] = 1 then 1 else 0 end) as n_WD,
	   sum(case when b.[txntypeid] = 1 then amount else 0 end) as WDAmt
  into #skylight_wt
  from [SSRSReports].[WebReportsUser].[KYC_CASH_PROJ_2023_Finance_Data] b
       inner join #terms1 x 
	   on b.ATMInternalID = x.ATMInternalID
 where APBinMatchBIN in ('400619', '400620', '410194', '410195', '410196', 
                         '410197', '410808', '410809', '440810', '440813', 
                         '476972', '476973', '476974', '476975', '519325', 
                         '526284', '526285', '530083', '530383', '530389', 
                         '530680', '530690', '530767', '537664', '537697', 
                         '542495', '4315387', '4315388', '4315389', '40346203', 
                         '41434900', '41699200', '42530002', '42530003', '42530702', 
                         '42530703', '43153599', '43153699', '43153770', '45180500', 
                         '45180508', '45180509', '45180588', '45180590', '45180599', 
                         '48532000', '48532011', '48532060', '48532070', '48532081', 
                         '48532082', '48532088', '48532089', '48532090', '48532091', 
                         '48532092', '48532098', '48532099', '50134999', '50271599', 
                         '51331500', '53068400', '53762890', '58571099', '58664299')
   and cast(b.SettlementDate as Date) >= (select dt from #dates where varname = 'AllocStart')
   and cast(b.SettlementDate as Date) <= (select dt from #dates where varname = 'AllocEnd')
 group by b.ATMInternalID, cast(b.SettlementDate as date);
-- 106963
create index tmpAP3 on #skylight_wt (ATMInternalID);
create index tmpAP4 on #skylight_wt (SettlementDate);

/* How many ATMs in #skylight_wt? These are the units that will have projected dispense for Skylight.  */
select count(distinct ATMInternalID)
  from #skylight_wt;
--24592

select SettlementDate, sum(n_WD) as n_WD
  from #skylight_wt
 group by SettlementDate
 order by 1;

IF OBJECT_ID('tempdb..#wt_bau1', 'U') IS NOT NULL 
   drop table #wt_bau1;
select a.*, DATEPART(dw, SettlementDate) as WkDay
  into #wt_bau1
  from #skylight_wt a;

select SettlementDate, sum(n_WD) as totwd
  from #wt_bau1
 group by SettlementDate
 order by 1;

/* Calculate total number of withdrawals and withdrawal amounts by ATM and day of week for the 4 week period. */
IF OBJECT_ID('tempdb..#test2', 'U') IS NOT NULL 
   drop table #test2;
select ATMInternalID, 
       WkDay, 
	   sum(n_WD) as n_WD, 
	   sum(WDAmt) as WDAmt
  into #test2
  from #wt_bau1
 group by ATMInternalID, WkDay;

select *
from #test2;

/* Calculate total number of withdrawals and withdrawal amounts by day of week for the two week period. */
IF OBJECT_ID('tempdb..#test3', 'U') IS NOT NULL 
   drop table #test3;
select WkDay, 
       sum(n_WD) as n_WDTot, 
	   sum(WDAmt) as WDAmtTot
into #test3
from #wt_bau1
group by WkDay;

select *
  from #test3
 order by WkDay;

/* Calculate weights for each ATM for each day of week. Weights are proportion of number of withdrawals for 
   an ATM for a day of week to the total number of Skylight withdrawals for that day of week during the 
   period; and proportion of withdrawal amount for an ATM for a day of week to the total withdrawal amount for 
   Skylight on that day of week during the period. */
IF OBJECT_ID('tempdb..#allocwt_base', 'U') IS NOT NULL 
   drop table #allocwt_base;
select a.*, 
       b.n_WDTot, 
	   b.WDAmtTot, 
	   (cast(n_WD as float) / cast(b.n_WDTot as float) ) as wt_wd, 
	   (cast(WDAmt as float) / cast(b.WDAmtTot as float) ) as wt_wdamt
  into #allocwt_base
  from #test2 a
       left join #test3 b on a.WkDay = b.WkDay;

select *
  from #allocwt_base
 where ATMInternalID = 158148
 order by WkDay;

select ATMInternalID, WkDay, count(*) as n_rec
  from #allocwt_base
 group by ATMInternalID, WkDay
having count(*) > 1;
--0

select WkDay, sum(wt_wd), sum(wt_wdamt)
  from #allocwt_base
 group by WkDay
 order by WkDay;

/* Create table for Skylight by ATM ID and forecast date, with total number of withdrawals for 
   Skylight BINs on forecast date, the weight for the forecast date's day of week, and projected number of 
   withdrawals for that ATM calculated as forecasted total number of Skylight withdrawals
   for forecast date times the weight for the forecast date's day of week. */
IF OBJECT_ID('tempdb..#proj_n_wd', 'U') IS NOT NULL 
   drop table #proj_n_wd;
select x.*, isnull(z.wt_wd,0) as wt_wd,
	   x.Totn_WD * isnull(z.wt_wd,0) as n_WD
  into #proj_n_wd
       /* Cross join list of ATMs with list of forecast dates, total projected Skylight withdrawal counts by
	      date, and the day of week by forecast date. */

  from (select a.ATMInternalID, 
               b.ForecastDate, 
			   b.n_WD as Totn_WD, 
			   DATEPART(dw, b.ForecastDate) as WkDay, 
			   DATEPART(week, b.ForecastDate) as WkNum
			   /* Create list of ATMs with Skylight withdrawal transactions. */

          from (select distinct ATMInternalID
                  from #skylight_wt
                 where n_WD > 0
               )a
               cross join #fcst b 
       )x
       left join #allocwt_base z 
	   on x.ATMInternalID = z.ATMInternalID 
	       and x.WkDay = z.WkDay;

select ForecastDate, sum(n_WD) as n_WD
  from #proj_n_wd
 group by ForecastDate
 order by 1;

/********************************************************************************************************
Skylight has a cyclic pattern to average dispense per withdrawal as it is higher at the beginning of the 
      month and lower the rest of the month. Calculate two values to use during these times. The BOM 
	  value is calculated as the average of the last two weeks including the first of the month. The 
	  ROM value is calculated as the average of the last three continguous weeks that do not include the 
	  first of the month. 
*********************************************************************************************************/
/***********************************************************************************************
Find Beginning of Month $/WD average as it is higher than the rest of the month. 
***********************************************************************************************/
/* Collect Beginning of Month (week containing the 1st) withdrawal transactions. */
IF OBJECT_ID('tempdb..#skylight_bom_wt', 'U') IS NOT NULL 
   drop table #skylight_bom_wt;
select b.ATMInternalID, 
	   sum(case when b.[txntypeid] = 1 then 1 else 0 end) as n_WD,
	   sum(case when b.[txntypeid] = 1 then amount else 0 end) as WDAmt
  into #skylight_bom_wt
  from [SSRSReports].[WebReportsUser].[KYC_CASH_PROJ_2023_Finance_Data] b
       inner join #terms1 x 
	   on b.ATMInternalID = x.ATMInternalID
 where APBinMatchBIN in ('400619', '400620', '410194', '410195', '410196', 
                         '410197', '410808', '410809', '440810', '440813', 
                         '476972', '476973', '476974', '476975', '519325', 
                         '526284', '526285', '530083', '530383', '530389', 
                         '530680', '530690', '530767', '537664', '537697', 
                         '542495', '4315387', '4315388', '4315389', '40346203', 
                         '41434900', '41699200', '42530002', '42530003', '42530702', 
                         '42530703', '43153599', '43153699', '43153770', '45180500', 
                         '45180508', '45180509', '45180588', '45180590', '45180599', 
                         '48532000', '48532011', '48532060', '48532070', '48532081', 
                         '48532082', '48532088', '48532089', '48532090', '48532091', 
                         '48532092', '48532098', '48532099', '50134999', '50271599', 
                         '51331500', '53068400', '53762890', '58571099', '58664299')
   and b.SettlementDate >= (select dt from #dates where varname = 'BOM1Start') 
   and b.SettlementDate <= (select dt from #dates where varname = 'BOM1End')
 group by b.ATMInternalID;
--15343

insert into #skylight_bom_wt
select b.ATMInternalID, 
	   sum(case when b.[txntypeid] = 1 then 1 else 0 end) as n_WD,
	   sum(case when b.[txntypeid] = 1 then amount else 0 end) as WDAmt
  from [SSRSReports].[WebReportsUser].[KYC_CASH_PROJ_2023_Finance_Data] b
       inner join #terms1 x 
	   on b.ATMInternalID = x.ATMInternalID
 where APBinMatchBIN in ('400619', '400620', '410194', '410195', '410196', 
                         '410197', '410808', '410809', '440810', '440813', 
                         '476972', '476973', '476974', '476975', '519325', 
                         '526284', '526285', '530083', '530383', '530389', 
                         '530680', '530690', '530767', '537664', '537697', 
                         '542495', '4315387', '4315388', '4315389', '40346203', 
                         '41434900', '41699200', '42530002', '42530003', '42530702', 
                         '42530703', '43153599', '43153699', '43153770', '45180500', 
                         '45180508', '45180509', '45180588', '45180590', '45180599', 
                         '48532000', '48532011', '48532060', '48532070', '48532081', 
                         '48532082', '48532088', '48532089', '48532090', '48532091', 
                         '48532092', '48532098', '48532099', '50134999', '50271599', 
                         '51331500', '53068400', '53762890', '58571099', '58664299')  
   and b.SettlementDate >= (select dt from #dates where varname = 'BOM2Start') 
   and b.SettlementDate <= (select dt from #dates where varname = 'BOM2End')
 group by b.ATMInternalID;
--14582


insert into #skylight_bom_wt
select b.ATMInternalID, 
	   sum(case when b.[txntypeid] = 1 then 1 else 0 end) as n_WD,
	   sum(case when b.[txntypeid] = 1 then amount else 0 end) as WDAmt
  from [SSRSReports].[WebReportsUser].[KYC_CASH_PROJ_2023_Finance_Data] b
       inner join #terms1 x 
	   on b.ATMInternalID = x.ATMInternalID
 where APBinMatchBIN in ('400619', '400620', '410194', '410195', '410196', 
                         '410197', '410808', '410809', '440810', '440813', 
                         '476972', '476973', '476974', '476975', '519325', 
                         '526284', '526285', '530083', '530383', '530389', 
                         '530680', '530690', '530767', '537664', '537697', 
                         '542495', '4315387', '4315388', '4315389', '40346203', 
                         '41434900', '41699200', '42530002', '42530003', '42530702', 
                         '42530703', '43153599', '43153699', '43153770', '45180500', 
                         '45180508', '45180509', '45180588', '45180590', '45180599', 
                         '48532000', '48532011', '48532060', '48532070', '48532081', 
                         '48532082', '48532088', '48532089', '48532090', '48532091', 
                         '48532092', '48532098', '48532099', '50134999', '50271599', 
                         '51331500', '53068400', '53762890', '58571099', '58664299')
   and b.SettlementDate >= (select dt from #dates where varname = 'BOM3Start') 
   and b.SettlementDate <= (select dt from #dates where varname = 'BOM3End')
 group by b.ATMInternalID;
--14994

select count(*) from #skylight_bom_wt;
--44837

/* Sum rows over ATMInternalID where there were rows from multiple BOM queries for one ATM. */
IF OBJECT_ID('tempdb..#skylight_bom_wt_total', 'U') IS NOT NULL 
   drop table #skylight_bom_wt_total; 
select ATMInternalID, 
	   sum(n_WD) as n_WD, 
	   sum(WDAmt) as WDAmt
  into #skylight_bom_wt_total	   
  from #skylight_bom_wt
 group by ATMInternalID; 
 
select ATMInternalID 
  from #skylight_bom_wt_total
 group by ATMInternalID
having count(*) > 1;
--0

/* Calculate average dispense per withdrawal for BOM period. */

IF OBJECT_ID('tempdb..#skylight_bom_avg', 'U') IS NOT NULL 
   drop table #skylight_bom_avg; 
select ATMInternalID, 
       n_WD, 
	   WDAmt,
	   (cast(WDAmt as float) / cast(n_WD as float)) as AvgWDAmt
  into #skylight_bom_avg
  from (select *
          from #skylight_bom_wt_total
       )x;

select *
  from #skylight_bom_avg;

/***********************************************************************************************
Find Rest of Month $/WD average as it is lower than the beginning of the month. Need to use 
    dates that do not include the first week of the month.  
***********************************************************************************************/
/* Collect Skylight Rest of Month (weeks not containing the 1st) withdrawal transactions. */
IF OBJECT_ID('tempdb..#skylight_rom_wt', 'U') IS NOT NULL 
   drop table #skylight_rom_wt; 
select b.ATMInternalID, 
	   sum(case when b.[txntypeid] = 1 then 1 else 0 end) as n_WD,
	   sum(case when b.[txntypeid] = 1 then amount else 0 end) as WDAmt
  into #skylight_rom_wt
  from [SSRSReports].[WebReportsUser].[KYC_CASH_PROJ_2023_Finance_Data] b
       inner join #terms1 x 
	   on b.ATMInternalID = x.ATMInternalID
 where APBinMatchBIN in ('400619', '400620', '410194', '410195', '410196', 
                         '410197', '410808', '410809', '440810', '440813', 
                         '476972', '476973', '476974', '476975', '519325', 
                         '526284', '526285', '530083', '530383', '530389', 
                         '530680', '530690', '530767', '537664', '537697', 
                         '542495', '4315387', '4315388', '4315389', '40346203', 
                         '41434900', '41699200', '42530002', '42530003', '42530702', 
                         '42530703', '43153599', '43153699', '43153770', '45180500', 
                         '45180508', '45180509', '45180588', '45180590', '45180599', 
                         '48532000', '48532011', '48532060', '48532070', '48532081', 
                         '48532082', '48532088', '48532089', '48532090', '48532091', 
                         '48532092', '48532098', '48532099', '50134999', '50271599', 
                         '51331500', '53068400', '53762890', '58571099', '58664299')
   and b.SettlementDate >= (select dt from #dates where varname = 'ROMStart') 
   and b.SettlementDate <= (select dt from #dates where varname = 'ROMEnd')
 group by b.ATMInternalID;

 
select ATMInternalID 
  from #skylight_rom_wt
 group by ATMInternalID
having count(*) > 1;
--0

select ATMInternalID, 
	   n_WD, 
	   WDAmt
  from #skylight_rom_wt
 order by ATMInternalID; 
 
/* Calculate total withdrawals and withdrawal amount by ATM, for tranactions in the period
   on active terminals. */

/* Calculate average withdrawal amount by ATM within this period. */
IF OBJECT_ID('tempdb..#skylight_rom_avg', 'U') IS NOT NULL 
   drop table #skylight_rom_avg; 
select ATMInternalID, 
       n_WD, 
	   WDAmt,
	   (cast(WDAmt as float) / cast(n_WD as float)) as AvgWDAmt
  into #skylight_rom_avg
  from (select *
          from #skylight_rom_wt
       )x;

select top 1000 *
  from #proj_n_wd;

select avg(AvgWDAmt)
  from #skylight_bom_avg;
--185.166535266749

select avg(AvgWDAmt)
  from #skylight_rom_avg; 
--179.212613118635

Insert into #BOM_ROM_List Select 'skylight',
	(select avg(AvgWDAmt)
		from #skylight_bom_avg),
	(select avg(AvgWDAmt)
		from #skylight_rom_avg);

select * from #BOM_ROM_List;
/* Project daily withdrawal amount by ATM by multiplying projected number of withdrawals by average 
   withdrawal amount over the three week period. */
   
/* **NOTE**: Update defaults for bom, rom from avg(AvgWDAmt) from bom, rom tables. 
             **Update a.WkNum list for BOM weeks in forecast period. */

IF OBJECT_ID('tempdb..#proj_skylight_fin', 'U') IS NOT NULL 
   drop table #proj_skylight_fin; 
select a.*, 
       case when a.WkNum in (9,13,18,22,26,31,35,40,44,48)  
	        then 
			/* Some ATMs have BOM AvgWDAmt that are less than ROM. If so, use ROM all month. */
			     case when isnull(b.AvgWDAmt,(select BOM from #BOM_ROM_List where issuer = 'skylight')) > isnull(r.AvgWDAmt,(select ROM from #BOM_ROM_List where issuer = 'skylight') )
				      then isnull(b.AvgWDAmt,(select BOM from #BOM_ROM_List where issuer = 'skylight') )
					  else isnull(r.AvgWDAmt,(select ROM from #BOM_ROM_List where issuer = 'skylight'))
				 end
            else isnull(r.AvgWDAmt,(select ROM from #BOM_ROM_List where issuer = 'skylight'))
       end as AvgWDAmt, 
	   case when a.WkNum in (9,13,18,22,26,31,35,40,44,48)  
	        then 
			     case when isnull(b.AvgWDAmt,(select BOM from #BOM_ROM_List where issuer = 'skylight')) > isnull(r.AvgWDAmt,(select ROM from #BOM_ROM_List where issuer = 'skylight') )
				      then a.n_WD * isnull(b.AvgWDAmt,(select BOM from #BOM_ROM_List where issuer = 'skylight') )
					  else a.n_WD * isnull(r.AvgWDAmt,(select ROM from #BOM_ROM_List where issuer = 'skylight'))
				 end
            else a.n_WD * isnull(r.AvgWDAmt,(select ROM from #BOM_ROM_List where issuer = 'skylight'))
       end as WDAmt
  into #proj_skylight_fin
  from #proj_n_wd a
       left join #skylight_rom_avg r 
	   on a.ATMInternalID = r.ATMInternalID
	   left join #skylight_bom_avg b
	   on a.ATMInternalID = b.ATMInternalID;
--2090320

select ForecastDate, 
       sum(n_WD) as n_WD, 
	   sum(WDAmt) as WDAmt
  from #proj_skylight_fin
where ForecastDate is not null
 group by ForecastDate
 order by 1;
 

IF OBJECT_ID('SSRSReports.WebReportsUser.KYC_CASH_PROJ_#proj_skylight_fin', 'U') IS NOT NULL 
   drop table SSRSReports.WebReportsUser.KYC_CASH_PROJ_#proj_skylight_fin; 
select * 
  into SSRSReports.WebReportsUser.KYC_CASH_PROJ_#proj_skylight_fin
  from #proj_skylight_fin;
--2090320

IF OBJECT_ID('SSRSReports.WebReportsUser.KYC_CASH_PROJ_#BOM_ROM_List', 'U') IS NOT NULL 
   drop table SSRSReports.WebReportsUser.KYC_CASH_PROJ_#BOM_ROM_List; 
select * 
  into SSRSReports.WebReportsUser.KYC_CASH_PROJ_#BOM_ROM_List
  from #BOM_ROM_List;


/* restore #proj_skylight_fin

IF OBJECT_ID('tempdb..#proj_skylight_fin', 'U') IS NOT NULL 
   drop table #proj_skylight_fin; 
select * 
  into #proj_skylight_fin
  from SSRSReports.WebReportsUser.KYC_CASH_PROJ_#proj_skylight_fin
--2277996
*/

select --SettlementDate, 
       count(*) as n_WD, 
	   sum(amount) as WDAmt, 
	   sum(amount)/count(*) as AvgWDAmt
  from SSRSReports.WebReportsUser.KYC_CASH_PROJ_2023_Finance_Data f
       inner join #terms1 t
	   on f.ATMInternalID = t.ATMInternalID
 where APBinMatchBIN in ('400619', '400620', '410194', '410195', '410196', 
                         '410197', '410808', '410809', '440810', '440813', 
                         '476972', '476973', '476974', '476975', '519325', 
                         '526284', '526285', '530083', '530383', '530389', 
                         '530680', '530690', '530767', '537664', '537697', 
                         '542495', '4315387', '4315388', '4315389', '40346203', 
                         '41434900', '41699200', '42530002', '42530003', '42530702', 
                         '42530703', '43153599', '43153699', '43153770', '45180500', 
                         '45180508', '45180509', '45180588', '45180590', '45180599', 
                         '48532000', '48532011', '48532060', '48532070', '48532081', 
                         '48532082', '48532088', '48532089', '48532090', '48532091', 
                         '48532092', '48532098', '48532099', '50134999', '50271599', 
                         '51331500', '53068400', '53762890', '58571099', '58664299')
    and SettlementDate >= (select dt from #dates where varname = 'AllocStart')
	and SettlementDate <= (select dt from #dates where varname = 'AllocEnd');

/* Total and average $/wd of all Skylight transactions during the allocation period. 
n_WD	WDAmt	AvgWDAmt
130933	26686695.00	203.8194
*/

/*************************************************************
Payfare Projection: FcstStart to FcstEnd

**************************************************************/

select *
  from [SSRSReports].[WebReportsUser].[KYC_CASH_PROJ_INP];

IF OBJECT_ID('tempdb..#fcst', 'U') IS NOT NULL 
   drop table #fcst;
/* Pull Payfare forecast of number of withdrawals. */
select cast(FcstDate as date) as ForecastDate, 
       sum(Payfare) as n_WD
  into #fcst
  from [SSRSReports].[WebReportsUser].[KYC_CASH_PROJ_INP]
 group by cast(FcstDate as date)
 order by cast(FcstDate as date);

select *
  from #fcst;


/* Use Last 4 weeks of data available, AllocStart to AllocEnd, to create weights for ATMs. */

IF OBJECT_ID('tempdb..#payfare_wt', 'U') IS NOT NULL 
   drop table #payfare_wt;
select b.ATMInternalID, cast(b.SettlementDate as date) as SettlementDate,
	   sum(case when b.[txntypeid] = 1 then 1 else 0 end) as n_WD,
	   sum(case when b.[txntypeid] = 1 then amount else 0 end) as WDAmt
  into #payfare_wt
  from [SSRSReports].[WebReportsUser].[KYC_CASH_PROJ_2023_Finance_Data] b
       inner join #terms1 x 
	   on b.ATMInternalID = x.ATMInternalID
 where b.APBinMatchBIN in ('444607', '511757', '520737','53889628')
   and cast(b.SettlementDate as Date) >= (select dt from #dates where varname = 'AllocStart')
   and cast(b.SettlementDate as Date) <= (select dt from #dates where varname = 'AllocEnd')
 group by b.ATMInternalID, cast(b.SettlementDate as date);

create index tmpAP3 on #payfare_wt (ATMInternalID);
create index tmpAP4 on #payfare_wt (SettlementDate);

select top 1000 *
  from #payfare_wt;

/* How many ATMs with Payfare activity? These will be the ATMs projected with Payfare activity in the forecast. */
select count(distinct ATMInternalID)
  from #payfare_wt;
--33229

select SettlementDate, sum(n_WD) as n_WD
  from #payfare_wt
 group by SettlementDate
 order by SettlementDate;

IF OBJECT_ID('tempdb..#wt_bau1', 'U') IS NOT NULL 
   drop table #wt_bau1;
select a.*, DATEPART(dw, SettlementDate) as WkDay
  into #wt_bau1
  from #payfare_wt a;

select SettlementDate, sum(n_WD) as totwd
  from #wt_bau1
 group by SettlementDate
 order by SettlementDate;

IF OBJECT_ID('tempdb..#test2', 'U') IS NOT NULL 
   drop table #test2;
/* Calculate total number of withdrawals and withdrawal amounts by ATM and day of week for the 4 week period. */
select ATMInternalID, 
       WkDay, 
	   sum(n_WD) as n_WD, 
	   sum(WDAmt) as WDAmt
  into #test2
  from #wt_bau1
 group by ATMInternalID, WkDay;

select *
  from #test2;

IF OBJECT_ID('tempdb..#test3', 'U') IS NOT NULL 
   drop table #test3;
/* Calculate total number of withdrawals and withdrawal amounts by day of week for the four week period. */
select WkDay, 
       sum(n_WD) as n_WDTot, 
	   sum(WDAmt) as WDAmtTot
into #test3
from #wt_bau1
group by WkDay;

select *
  from #test3
 order by WkDay;


IF OBJECT_ID('tempdb..#allocwt_base', 'U') IS NOT NULL 
   drop table #allocwt_base;
/* Calculate weights for each ATM for each day of week. Weights are proportion of number of withdrawals for 
   an ATM for a day of week to the total number of Payfare withdrawals for that day of week during the four week
   period; and proportion of withdrawal amount for an ATM for a day of week to the total withdrawal amount for 
   Payfare on that day of week during the four week period. */
select a.*, 
       b.n_WDTot, 
	   b.WDAmtTot, 
	   case when b.n_WDTot > 0 then (cast(n_WD as float) / cast(b.n_WDTot as float))
	        else 0 end as wt_wd, 
	   case when b.WDAmtTot > 0 then (cast(WDAmt as float) / cast(b.WDAmtTot as float))
	        else 0 end as wt_wdamt
  into #allocwt_base
  from #test2 a
       left join #test3 b on a.WkDay = b.WkDay;

select *
  from #allocwt_base
 where ATMInternalID = 301474
 order by WkDay;

select ATMInternalID, WkDay, count(*) as n_rec
  from #allocwt_base
 group by ATMInternalID, WkDay
having count(*) > 1;
--0

select WkDay, sum(wt_wd), sum(wt_wdamt)
  from #allocwt_base
 group by WkDay
 order by WkDay;

IF OBJECT_ID('tempdb..#proj_n_wd', 'U') IS NOT NULL 
   drop table #proj_n_wd;
/* Create table for Payfare by ATM ID and forecast date, with total number of withdrawals for 
   Payfare BINs on forecast date, the weight for the forecast date's day of week, and projected number of 
   withdrawals for that ATM calculated as forecasted total number of Payfare withdrawals
   for forecast date times the weight for the forecast date's day of week. */
select x.*, isnull(z.wt_wd,0) as wt_wd,
	   x.Totn_WD * isnull(z.wt_wd,0) as n_WD
  into #proj_n_wd
       /* Cross join list of ATMs with list of forecast dates, total projected Payfare withdrawal counts by
	      date, and the day of week by forecast date. */
  from (select a.ATMInternalID, 
               b.ForecastDate, 
			   b.n_WD as Totn_WD, 
			   DATEPART(dw, b.ForecastDate) as WkDay, 
			   DATEPART(week, b.ForecastDate) as WkNum
			   /* Create list of ATMs with Payfare withdrawal transactions. */
          from (select distinct ATMInternalID
                  from #payfare_wt
                 where n_WD > 0
                 --and cast(SettlementDate as date)>='2020-08-01'
               )a
               cross join #fcst b
       )x
       left join #allocwt_base z 
	   on x.ATMInternalID = z.ATMInternalID 
	       and x.WkDay = z.WkDay;

select ForecastDate, sum(n_WD) as n_WD
  from #proj_n_wd
 group by ForecastDate
 order by 1;

/********************************************************************************************************
Payfare has a cyclic pattern to average dispense per withdrawal as it is higher at the beginning of the 
      month and lower the rest of the month. Calculate two values to use during these times. The BOM 
	  value is calculated as the average of the last two weeks including the first of the month. The 
	  ROM value is calculated as the average of the last three continguous weeks that do not include the 
	  first of the month. 
*********************************************************************************************************/
/***********************************************************************************************
Find Beginning of Month $/WD average as it is higher than the rest of the month. 
***********************************************************************************************/
/* Collect Beginning of Month (week containing the 1st) withdrawal transactions. */
IF OBJECT_ID('tempdb..#payfare_bom_wt', 'U') IS NOT NULL 
   drop table #payfare_bom_wt;
select b.ATMInternalID, 
	   sum(case when b.[txntypeid] = 1 then 1 else 0 end) as n_WD,
	   sum(case when b.[txntypeid] = 1 then amount else 0 end) as WDAmt
  into #payfare_bom_wt
  from [SSRSReports].[WebReportsUser].[KYC_CASH_PROJ_2023_Finance_Data] b
       inner join #terms1 x 
	   on b.ATMInternalID = x.ATMInternalID
 where b.APBinMatchBIN in ('444607', '511757', '520737','53889628')
   and b.SettlementDate >= (select dt from #dates where varname = 'BOM1Start') 
   and b.SettlementDate <= (select dt from #dates where varname = 'BOM1End')
 group by b.ATMInternalID;
--23227

insert into #payfare_bom_wt
select b.ATMInternalID, 
	   sum(case when b.[txntypeid] = 1 then 1 else 0 end) as n_WD,
	   sum(case when b.[txntypeid] = 1 then amount else 0 end) as WDAmt
  from [SSRSReports].[WebReportsUser].[KYC_CASH_PROJ_2023_Finance_Data] b
       inner join #terms1 x 
	   on b.ATMInternalID = x.ATMInternalID
 where b.APBinMatchBIN in ('444607', '511757', '520737','53889628')   
   and b.SettlementDate >= (select dt from #dates where varname = 'BOM2Start') 
   and b.SettlementDate <= (select dt from #dates where varname = 'BOM2End')
 group by b.ATMInternalID;
--23174
 
insert into #payfare_bom_wt
select b.ATMInternalID, 
	   sum(case when b.[txntypeid] = 1 then 1 else 0 end) as n_WD,
	   sum(case when b.[txntypeid] = 1 then amount else 0 end) as WDAmt
  from [SSRSReports].[WebReportsUser].[KYC_CASH_PROJ_2023_Finance_Data] b
       inner join #terms1 x 
	   on b.ATMInternalID = x.ATMInternalID
 where b.APBinMatchBIN in ('444607', '511757', '520737','53889628')
   and b.SettlementDate >= (select dt from #dates where varname = 'BOM3Start') 
   and b.SettlementDate <= (select dt from #dates where varname = 'BOM3End')
 group by b.ATMInternalID;
--23778

select count(*) from #payfare_bom_wt;
--70603

/* Sum rows over ATMInternalID where there were rows from multiple BOM queries for one ATM. */
IF OBJECT_ID('tempdb..#payfare_bom_wt_total', 'U') IS NOT NULL 
   drop table #payfare_bom_wt_total; 
select ATMInternalID, 
	   sum(n_WD) as n_WD, 
	   sum(WDAmt) as WDAmt
  into #payfare_bom_wt_total	   
  from #payfare_bom_wt
 group by ATMInternalID; 
 
select ATMInternalID 
  from #payfare_bom_wt_total
 group by ATMInternalID
having count(*) > 1;
--0

/* Calculate average dispense per withdrawal for BOM period. */

IF OBJECT_ID('tempdb..#payfare_bom_avg', 'U') IS NOT NULL 
   drop table #payfare_bom_avg; 
select ATMInternalID, 
       n_WD, 
	   WDAmt,
	   (cast(WDAmt as float) / cast(n_WD as float)) as AvgWDAmt
  into #payfare_bom_avg
  from (select *
          from #payfare_bom_wt_total
       )x;

select *
  from #payfare_bom_avg;

/***********************************************************************************************
Find Rest of Month $/WD average as it is lower than the beginning of the month. Need to use 
    dates that do not include the first week of the month.  
***********************************************************************************************/
/* Collect Payfare Rest of Month (weeks not containing the 1st) withdrawal transactions. */
IF OBJECT_ID('tempdb..#payfare_rom_wt', 'U') IS NOT NULL 
   drop table #payfare_rom_wt; 
select b.ATMInternalID, 
	   sum(case when b.[txntypeid] = 1 then 1 else 0 end) as n_WD,
	   sum(case when b.[txntypeid] = 1 then amount else 0 end) as WDAmt
  into #payfare_rom_wt
  from [SSRSReports].[WebReportsUser].[KYC_CASH_PROJ_2023_Finance_Data] b
       inner join #terms1 x 
	   on b.ATMInternalID = x.ATMInternalID
 where b.APBinMatchBIN in ('444607', '511757', '520737','53889628')
   and b.SettlementDate >= (select dt from #dates where varname = 'ROMStart') 
   and b.SettlementDate <= (select dt from #dates where varname = 'ROMEnd')
 group by b.ATMInternalID;

 
select ATMInternalID 
  from #payfare_rom_wt
 group by ATMInternalID
having count(*) > 1;
--0

select ATMInternalID, 
	   n_WD, 
	   WDAmt
  from #payfare_rom_wt
 order by ATMInternalID; 
 
/* Calculate total withdrawals and withdrawal amount by ATM, for tranactions in the period
   on active terminals. */

/* Calculate average withdrawal amount by ATM within this period. */
IF OBJECT_ID('tempdb..#payfare_rom_avg', 'U') IS NOT NULL 
   drop table #payfare_rom_avg; 
select ATMInternalID, 
       n_WD, 
	   WDAmt,
	   (cast(WDAmt as float) / cast(n_WD as float)) as AvgWDAmt
  into #payfare_rom_avg
  from (select *
          from #payfare_rom_wt
       )x;

select top 1000 *
  from #proj_n_wd;

select avg(AvgWDAmt)
  from #payfare_bom_avg;
--105.183801942099
select avg(AvgWDAmt)
  from #payfare_rom_avg; 
--97.3905470226562

Insert into #BOM_ROM_List Select 'payfare',
	(select avg(AvgWDAmt)
		from #payfare_bom_avg),
	(select avg(AvgWDAmt)
		from #payfare_rom_avg);

select * from #BOM_ROM_List;

/* Project daily withdrawal amount by ATM by multiplying projected number of withdrawals by average 
   withdrawal amount over the three week period. */
   
/* **NOTE**: Update defaults for bom, rom from avg(AvgWDAmt) from bom, rom tables. 
             **Update a.WkNum list for BOM weeks in forecast period. */

IF OBJECT_ID('tempdb..#proj_payfare_fin', 'U') IS NOT NULL 
   drop table #proj_payfare_fin; 
select a.*, 
       case when a.WkNum in (9,13,18,22,26,31,35,40,44,48) 
	        then 
			/* Some ATMs have BOM AvgWDAmt that are less than ROM. If so, use ROM all month. */
			     case when isnull(b.AvgWDAmt,(select BOM from #BOM_ROM_List where issuer = 'payfare')) > isnull(r.AvgWDAmt,(select ROM from #BOM_ROM_List where issuer = 'payfare')) 
				      then isnull(b.AvgWDAmt,(select BOM from #BOM_ROM_List where issuer = 'payfare') )
					  else isnull(r.AvgWDAmt,(select ROM from #BOM_ROM_List where issuer = 'payfare'))
				 end
            else isnull(r.AvgWDAmt,(select ROM from #BOM_ROM_List where issuer = 'payfare'))
       end as AvgWDAmt, 
	   case when a.WkNum in (9,13,18,22,26,31,35,40,44,48) 
	        then 
			     case when isnull(b.AvgWDAmt,(select BOM from #BOM_ROM_List where issuer = 'payfare')) > isnull(r.AvgWDAmt,(select ROM from #BOM_ROM_List where issuer = 'payfare') )
				      then a.n_WD * isnull(b.AvgWDAmt,(select BOM from #BOM_ROM_List where issuer = 'payfare') )
					  else a.n_WD * isnull(r.AvgWDAmt,(select ROM from #BOM_ROM_List where issuer = 'payfare'))
				 end
            else a.n_WD * isnull(r.AvgWDAmt,(select ROM from #BOM_ROM_List where issuer = 'payfare'))
       end as WDAmt
  into #proj_payfare_fin
  from #proj_n_wd a
       left join #payfare_rom_avg r 
	   on a.ATMInternalID = r.ATMInternalID
	   left join #payfare_bom_avg b
	   on a.ATMInternalID = b.ATMInternalID;


select ForecastDate, 
       sum(n_WD) as n_WD, 
	   sum(WDAmt) as WDAmt
  from #proj_payfare_fin
where ForecastDate is not null
 group by ForecastDate
 order by ForecastDate;

IF OBJECT_ID('SSRSReports.WebReportsUser.KYC_CASH_PROJ_#proj_payfare_fin', 'U') IS NOT NULL 
   drop table SSRSReports.WebReportsUser.KYC_CASH_PROJ_#proj_payfare_fin;
select * 
  into SSRSReports.WebReportsUser.KYC_CASH_PROJ_#proj_payfare_fin
  from #proj_payfare_fin;
--2824465

/* restore #proj_payfare_fin

IF OBJECT_ID('tempdb..#proj_payfare_fin', 'U') IS NOT NULL 
   drop table #proj_payfare_fin;
select * 
  into #proj_payfare_fin
  from SSRSReports.WebReportsUser.KYC_CASH_PROJ_#proj_payfare_fin;
--2679348
*/



select --SettlementDate, 
       count(*) as n_WD, 
	   sum(amount) as WDAmt, 
	   sum(amount)/count(*) as AvgWDAmt
  from SSRSReports.WebReportsUser.KYC_CASH_PROJ_2023_Finance_Data f
       inner join #terms1 t
	   on f.ATMInternalID = t.ATMInternalID
 where f.APBinMatchBIN in ('444607', '511757', '520737','53889628')
    and APBinMatch = 1
    and SettlementDate >= (select dt from #dates where varname = 'AllocStart')
	and SettlementDate <= (select dt from #dates where varname = 'AllocEnd');

/* Total transactions over allocation period for entire BIN, average $/wd over entire BIN. 
n_WD	WDAmt	    AvgWDAmt
561222	62268515.00	110.9516
*/



/********************************************************************
MN Projection: FcstStart to FcstEnd

10/1/21 Updated MN from EIP BIN to Payroll BIN group

11/1/21  Note: Previous forecast was short on every Fri, Sat by about 
         $25/wd. Bump up forecast for Fri & Sat. 

*********************************************************************/
select *
  from [SSRSReports].[WebReportsUser].[KYC_CASH_PROJ_INP];

IF OBJECT_ID('tempdb..#fcst', 'U') IS NOT NULL 
   drop table #fcst;	
/* Pull MN forecast for number of withdrawals. */
select cast(FcstDate as date) as ForecastDate, 
       sum(MN) as n_WD
  into #fcst
  from [SSRSReports].[WebReportsUser].[KYC_CASH_PROJ_INP]
 group by cast(FcstDate as date)
 order by 1;

select *
from #fcst;


/* Use last 4 weeks of activity to create weights for transactions. */

IF OBJECT_ID('tempdb..#mn_wt', 'U') IS NOT NULL 
   drop table #mn_wt;	
select b.ATMInternalID, 
       cast(b.SettlementDate as date) as SettlementDate,
	   sum(case when b.[txntypeid] = 1 then 1 else 0 end) as n_WD,
	   sum(case when b.[txntypeid] = 1 then amount else 0 end) as WDAmt
  into #mn_wt
  from [SSRSReports].[WebReportsUser].[KYC_CASH_PROJ_2023_Finance_Data] b
       inner join #terms1 x 
	   on b.ATMInternalID = x.ATMInternalID
 where b.APBinMatchBIN in ('424015', '435889', '468271', '472776', '472777', '475024', '494321', '494340', '494341', 
                           '519509', '526262', '530133', '627391', '627396', '46321400', '60119065')
   and cast(b.SettlementDate as Date) >= (select dt from #dates where varname = 'AllocStart')
   and cast(b.SettlementDate as Date) <= (select dt from #dates where varname = 'AllocEnd')
 group by b.ATMInternalID, cast(b.SettlementDate as date);

/* How many ATMs saw MN activity? These are the ATMs that will have projected
   activity in the forecast. */
select count(distinct ATMInternalID)
  from #mn_wt;
--30341

create index tmpAP3 on #mn_wt (ATMInternalID);
create index tmpAP4 on #mn_wt (SettlementDate);

IF OBJECT_ID('tempdb..#wt_bau1', 'U') IS NOT NULL 
   drop table #wt_bau1;	
select a.*, 
       DATEPART(dw, SettlementDate) as WkDay
  into #wt_bau1
  from #mn_wt a;

select SettlementDate, sum(n_WD) as totwd
  from #wt_bau1
 group by SettlementDate
 order by 1;

IF OBJECT_ID('tempdb..#test2', 'U') IS NOT NULL 
   drop table #test2;	
/* Calculate total number of withdrawals and withdrawal amount by ATM and day of week. */
select ATMInternalID, 
       WkDay, 
	   sum(n_WD) as n_WD, 
	   sum(WDAmt) as WDAmt
  into #test2
  from #wt_bau1
 group by ATMInternalID, WkDay;

select *
  from #test2;

IF OBJECT_ID('tempdb..#test3', 'U') IS NOT NULL 
   drop table #test3;
/* Calculate total number of withdrawals and withdrawal amount by day of week only. */
select WkDay, 
       sum(n_WD) as n_WDTot, 
	   sum(WDAmt) as WDAmtTot
  into #test3
  from #wt_bau1
 group by WkDay;

select *
  from #test3
 order by WkDay;


IF OBJECT_ID('tempdb..#allocwt_base', 'U') IS NOT NULL 
   drop table #allocwt_base;
/* Calculate proportion of number of withdrawals for each ATM for each day of week to the total number of 
   withdrawals for MN for that day of week; and proportion of withdrawal amount for each ATM for each day of 
   week to the total withdrawal amount for MN for that day of week for the four week period. */
select a.*, 
       b.n_WDTot, 
	   b.WDAmtTot, 
	   case when b.n_WDTot > 0 then (cast(n_WD as float) / cast(b.n_WDTot as float))
	        else 0 end as wt_wd, 
	   case when b.WDAmtTot > 0 then (cast(WDAmt as float) / cast(b.WDAmtTot as float))
	        else 0 end as wt_wdamt
  into #allocwt_base
  from #test2 a
       left join #test3 b on a.WkDay=b.WkDay;

select *
  from #allocwt_base
 where ATMInternalID = 135172
 order by WkDay;

select ATMInternalID, WkDay, count(*) as n_rec
  from #allocwt_base
 group by ATMInternalID, WkDay
having count(*) > 1;
--0

select WkDay, sum(wt_wd), sum(wt_wdamt)
  from #allocwt_base
 group by WkDay
 order by WkDay;

IF OBJECT_ID('tempdb..#proj_n_wd', 'U') IS NOT NULL 
   drop table #proj_n_wd;
/* Create table for MN by ATM ID and forecast date, with total number of withdrawals for 
   MN BINs on forecast date, the weight for the forecast date's day of week, and projected number of 
   withdrawals for that ATM calculated as forecasted total number of MN withdrawals
   for forecast date times the weight for the forecast date's day of week. */
select x.*, 
       isnull(z.wt_wd,0) as wt_wd,
	   x.Totn_WD * isnull(z.wt_wd,0) as n_WD
  into #proj_n_wd
       /* Cross join list of ATMs with list of forecast dates, total withdrawals per forecast date, and 
	      day of week of forecast date. */
  from (select a.ATMInternalID, 
               b.ForecastDate, 
			   b.n_WD as Totn_WD, 
			   DATEPART(dw, b.ForecastDate) as WkDay, 
			   DATEPART(week, b.ForecastDate) as WkNum
			   /* Create list of ATMs with MN withdrawal transactions. */
          from (select distinct ATMInternalID
                  from #mn_wt
                 where n_WD > 0
                 --and cast(SettlementDate as date)>='2020-08-01'
               )a
               cross join #fcst b 
       )x
       left join #allocwt_base z 
	   on x.ATMInternalID = z.ATMInternalID 
	       and x.WkDay = z.WkDay;

select ForecastDate, sum(n_WD) as n_WD
  from #proj_n_wd
 group by ForecastDate
 order by 1;
 
/********************************************************************************************************
MN has a cyclic pattern to average dispense per withdrawal as it is higher at the beginning of the 
      month and lower the rest of the month. Calculate two values to use during these times. The BOM 
	  value is calculated as the average of the last two weeks including the first of the month. The 
	  ROM value is calculated as the average of the last three continguous weeks that do not include the 
	  first of the month. 
*********************************************************************************************************/
/***********************************************************************************************
Find Beginning of Month $/WD average as it is higher than the rest of the month. 
***********************************************************************************************/
/* Collect Beginning of Month (week containing the 1st) withdrawal transactions. */
IF OBJECT_ID('tempdb..#mn_bom_wt', 'U') IS NOT NULL 
   drop table #mn_bom_wt;
select b.ATMInternalID, 
	   sum(case when b.[txntypeid] = 1 then 1 else 0 end) as n_WD,
	   sum(case when b.[txntypeid] = 1 then amount else 0 end) as WDAmt
  into #mn_bom_wt
  from [SSRSReports].[WebReportsUser].[KYC_CASH_PROJ_2023_Finance_Data] b
       inner join #terms1 x 
	   on b.ATMInternalID = x.ATMInternalID
 where b.APBinMatchBIN in ('424015', '435889', '468271', '472776', '472777', '475024', '494321', '494340', '494341', 
                           '519509', '526262', '530133', '627391', '627396', '46321400', '60119065')
   and b.SettlementDate >= (select dt from #dates where varname = 'BOM1Start') 
   and b.SettlementDate <= (select dt from #dates where varname = 'BOM1End')
 group by b.ATMInternalID;
--19719

insert into #mn_bom_wt
select b.ATMInternalID, 
	   sum(case when b.[txntypeid] = 1 then 1 else 0 end) as n_WD,
	   sum(case when b.[txntypeid] = 1 then amount else 0 end) as WDAmt
  from [SSRSReports].[WebReportsUser].[KYC_CASH_PROJ_2023_Finance_Data] b
       inner join #terms1 x 
	   on b.ATMInternalID = x.ATMInternalID
 where b.APBinMatchBIN in ('424015', '435889', '468271', '472776', '472777', '475024', '494321', '494340', '494341', 
                           '519509', '526262', '530133', '627391', '627396', '46321400', '60119065')
   and b.SettlementDate >= (select dt from #dates where varname = 'BOM2Start') 
   and b.SettlementDate <= (select dt from #dates where varname = 'BOM2End')
 group by b.ATMInternalID;
--20026

insert into #mn_bom_wt
select b.ATMInternalID, 
	   sum(case when b.[txntypeid] = 1 then 1 else 0 end) as n_WD,
	   sum(case when b.[txntypeid] = 1 then amount else 0 end) as WDAmt
  from [SSRSReports].[WebReportsUser].[KYC_CASH_PROJ_2023_Finance_Data] b
       inner join #terms1 x 
	   on b.ATMInternalID = x.ATMInternalID
 where b.APBinMatchBIN in ('424015', '435889', '468271', '472776', '472777', '475024', '494321', '494340', '494341', 
                           '519509', '526262', '530133', '627391', '627396', '46321400', '60119065')
   and b.SettlementDate >= (select dt from #dates where varname = 'BOM3Start') 
   and b.SettlementDate <= (select dt from #dates where varname = 'BOM3End')
 group by b.ATMInternalID;
--20185

select count(*) from #mn_bom_wt;
--60414

/* Sum rows over ATMInternalID where there were rows from multiple BOM queries for one ATM. */
IF OBJECT_ID('tempdb..#mn_bom_wt_total', 'U') IS NOT NULL 
   drop table #mn_bom_wt_total; 
select ATMInternalID, 
	   sum(n_WD) as n_WD, 
	   sum(WDAmt) as WDAmt
  into #mn_bom_wt_total	   
  from #mn_bom_wt
 group by ATMInternalID; 
 
select ATMInternalID 
  from #mn_bom_wt_total
 group by ATMInternalID
having count(*) > 1;
--0

/* Calculate average dispense per withdrawal for BOM period. */

IF OBJECT_ID('tempdb..#mn_bom_avg', 'U') IS NOT NULL 
   drop table #mn_bom_avg; 
select ATMInternalID, 
       n_WD, 
	   WDAmt,
	   (cast(WDAmt as float) / cast(n_WD as float)) as AvgWDAmt
  into #mn_bom_avg
  from (select *
          from #mn_bom_wt_total
       )x;

select *
  from #mn_bom_avg;

/***********************************************************************************************
Find Rest of Month $/WD average as it is lower than the beginning of the month. Need to use 
    dates that do not include the first week of the month.  
***********************************************************************************************/
/* Collect MN Rest of Month (weeks not containing the 1st) withdrawal transactions. */
IF OBJECT_ID('tempdb..#mn_rom_wt', 'U') IS NOT NULL 
   drop table #mn_rom_wt; 
select b.ATMInternalID, 
	   sum(case when b.[txntypeid] = 1 then 1 else 0 end) as n_WD,
	   sum(case when b.[txntypeid] = 1 then amount else 0 end) as WDAmt
  into #mn_rom_wt
  from [SSRSReports].[WebReportsUser].[KYC_CASH_PROJ_2023_Finance_Data] b
       inner join #terms1 x 
	   on b.ATMInternalID = x.ATMInternalID
 where b.APBinMatchBIN in ('424015', '435889', '468271', '472776', '472777', '475024', '494321', '494340', '494341', 
                           '519509', '526262', '530133', '627391', '627396', '46321400', '60119065')
   and b.SettlementDate >= (select dt from #dates where varname = 'ROMStart') 
   and b.SettlementDate <= (select dt from #dates where varname = 'ROMEnd')
 group by b.ATMInternalID;

 
select ATMInternalID 
  from #mn_rom_wt
 group by ATMInternalID
having count(*) > 1;
--0

select ATMInternalID, 
	   n_WD, 
	   WDAmt
  from #mn_rom_wt
 order by ATMInternalID; 
 
/* Calculate total withdrawals and withdrawal amount by ATM, for tranactions in the period
   on active terminals. */

/* Calculate average withdrawal amount by ATM within this period. */
IF OBJECT_ID('tempdb..#mn_rom_avg', 'U') IS NOT NULL 
   drop table #mn_rom_avg; 
select ATMInternalID, 
       n_WD, 
	   WDAmt,
	   (cast(WDAmt as float) / cast(n_WD as float)) as AvgWDAmt
  into #mn_rom_avg
  from (select *
          from #mn_rom_wt
       )x;

select top 1000 *
  from #proj_n_wd;

select avg(AvgWDAmt)
  from #mn_bom_avg;
--185.465359437365
  
select avg(AvgWDAmt)
  from #mn_rom_avg; 
--177.97737516767

Insert into #BOM_ROM_List Select 'mn',
	(select avg(AvgWDAmt)
		from #mn_bom_avg),
	(select avg(AvgWDAmt)
		from #mn_rom_avg);

select * from #BOM_ROM_List;
/* Project daily withdrawal amount by ATM by multiplying projected number of withdrawals by average 
   withdrawal amount over the three week period. */
   
/* **NOTE**: Update defaults for bom, rom from avg(AvgWDAmt) from bom, rom tables. 
             **Update a.WkNum list for BOM weeks in forecast period. 
			 
   11/1/21:  Money Network Payroll has about $25 higher withdrawal on Fridays and $10 higher on Saturdays in the 
             last forecast period. Friday is WkDay = 6, Saturday is WkDay = 7. Bump up the withdrawal
			 amount for Friday and Saturday. 
   
   12/17/21: Forecast was close to actuals last month except for Thanksgiving weekend. Keep the Fri/Sat bump as is. 
   2/12/22:  Forecast was low every Sat. Increase Sat bump to $45
   3/11/22:  Forecast was high every Sat. Decrease Sat bump to $25
   4/8/22:   Forecast was low every Sat. Increase Sat bump to $45 
   7/27/22:   Forecast was high every Sat. Decrease Sat bump to $25
   8/25/22:   Forecast was high every Sat. Remove Sat bump*/


IF OBJECT_ID('tempdb..#proj_mn_fin', 'U') IS NOT NULL 
   drop table #proj_mn_fin; 
select a.*, 
       case when a.WkNum in (9,13,18,22,26,31,35,40,44,48) 
	        then 
			/* Some ATMs have BOM AvgWDAmt that are less than ROM. If so, use ROM all month. */
			     case when isnull(b.AvgWDAmt,(select BOM from #BOM_ROM_List where issuer = 'mn')) > isnull(r.AvgWDAmt,(select ROM from #BOM_ROM_List where issuer = 'mn') )
				      then isnull(b.AvgWDAmt,(select BOM from #BOM_ROM_List where issuer = 'mn') )
					  else isnull(r.AvgWDAmt,(select ROM from #BOM_ROM_List where issuer = 'mn'))
				 end
            else  isnull(r.AvgWDAmt,(select ROM from #BOM_ROM_List where issuer = 'mn') )
       end as AvgWDAmt, 
	   case when a.WkNum in (9,13,18,22,26,31,35,40,44,48) 
	        then 
			     case when isnull(b.AvgWDAmt,(select BOM from #BOM_ROM_List where issuer = 'mn')) > isnull(r.AvgWDAmt,(select ROM from #BOM_ROM_List where issuer = 'mn') )
				      then  a.n_WD * isnull(b.AvgWDAmt,(select BOM from #BOM_ROM_List where issuer = 'mn') )
					  else  a.n_WD * isnull(r.AvgWDAmt,(select ROM from #BOM_ROM_List where issuer = 'mn') )
				 end
            else  a.n_WD * isnull(r.AvgWDAmt,(select ROM from #BOM_ROM_List where issuer = 'mn') )
       end as WDAmt
  into #proj_mn_fin
  from #proj_n_wd a
       left join #mn_rom_avg r 
	   on a.ATMInternalID = r.ATMInternalID
	   left join #mn_bom_avg b
	   on a.ATMInternalID = b.ATMInternalID;

select top(10) *,a.WkDay
from #proj_n_wd a;


select ForecastDate, 
       sum(n_WD) as n_WD, 
	   sum(WDAmt) as WDAmt
  from #proj_mn_fin
where ForecastDate is not null
 group by ForecastDate
 order by ForecastDate;

IF OBJECT_ID('SSRSReports.WebReportsUser.KYC_CASH_PROJ_#proj_mn_fin', 'U') IS NOT NULL 
   drop table SSRSReports.WebReportsUser.KYC_CASH_PROJ_#proj_mn_fin;
select * 
  into SSRSReports.WebReportsUser.KYC_CASH_PROJ_#proj_mn_fin
  from #proj_mn_fin;
--2578985
/* restore #proj_mn_fin

IF OBJECT_ID('tempdb..#proj_mn_fin', 'U') IS NOT NULL 
   drop table #proj_mn_fin;
select * 
  into #proj_mn_fin
  from SSRSReports.WebReportsUser.KYC_CASH_PROJ_#proj_mn_fin;
--2626092
*/

IF OBJECT_ID('SSRSReports.WebReportsUser.KYC_CASH_PROJ_#BOM_ROM_List', 'U') IS NOT NULL 
   drop table SSRSReports.WebReportsUser.KYC_CASH_PROJ_#BOM_ROM_List; 
select * 
  into SSRSReports.WebReportsUser.KYC_CASH_PROJ_#BOM_ROM_List
  from #BOM_ROM_List;


select --SettlementDate, 
       count(*) as n_WD, 
	   sum(amount) as WDAmt, 
	   sum(amount)/count(*) as AvgWDAmt
  from SSRSReports.WebReportsUser.KYC_CASH_PROJ_2023_Finance_Data f
       inner join #terms1 t
	   on f.ATMInternalID = t.ATMInternalID
 where f.APBinMatchBIN in ('424015', '435889', '468271', '472776', '472777', '475024', '494321', '494340', '494341', 
                           '519509', '526262', '530133', '627391', '627396', '46321400', '60119065')
    and APBinMatch = 1
    and SettlementDate >= (select dt from #dates where varname = 'AllocStart')
	and SettlementDate <= (select dt from #dates where varname = 'AllocEnd');

/* Total transactions over allocation period for entire BIN, average $/wd over entire BIN. 
n_WD	WDAmt	AvgWDAmt
236087	45903730.00	194.4356
*/

/*************************************************************
ADP Projection: FcstStart to FcstEnd
BINs ('402018','402717','402718','411600','414346','416187','445785', 451440, 456628, 467321, 485340, 
      522481, 523680, 524543, 528197, 528227, 530327, 41160001)
**************************************************************/
select *
  from [SSRSReports].[WebReportsUser].[KYC_CASH_PROJ_INP];

/* Pull ADP forecast of number of withdrawals. */
IF OBJECT_ID('tempdb..#fcst', 'U') IS NOT NULL 
   drop table #fcst;
select cast(FcstDate as date) as ForecastDate, 
       sum(ADP) as n_WD
  into #fcst
  from [SSRSReports].[WebReportsUser].[KYC_CASH_PROJ_INP]
 group by cast(FcstDate as date)
 order by 1;

select *
  from #fcst;

/* Use Last 4 weeks of data available, AllocStart to AllocEnd, to create weights for ATMs. */
IF OBJECT_ID('tempdb..#adp_wt', 'U') IS NOT NULL 
   drop table #adp_wt;
select b.ATMInternalID, cast(b.SettlementDate as date) as SettlementDate,
	   sum(case when b.[txntypeid] = 1 then 1 else 0 end) as n_WD,
	   sum(case when b.[txntypeid] = 1 then amount else 0 end) as WDAmt
  into #adp_wt
  from [SSRSReports].[WebReportsUser].[KYC_CASH_PROJ_2023_Finance_Data] b
       inner join #terms1 x 
	   on b.ATMInternalID = x.ATMInternalID
 where b.APBinMatchBIN in ('402018','402717','402718','411600','414346','416187','445785', '451440', '456628', '467321', '485340', 
                           '522481', '523680', '524543', '528197', '528227', '530327', '41160001')
   and cast(b.SettlementDate as Date) >= (select dt from #dates where varname = 'AllocStart')
   and cast(b.SettlementDate as Date) <= (select dt from #dates where varname = 'AllocEnd')
 group by b.ATMInternalID, cast(b.SettlementDate as date);

create index tmpAP3 on #adp_wt (ATMInternalID);
create index tmpAP4 on #adp_wt (SettlementDate);

/* How many ATMs in #adp_wt? These are the units that will have projected dispense. */
select count(distinct ATMInternalID)
  from #adp_wt;
--40321

select SettlementDate, sum(n_WD) as n_WD
  from #adp_wt
 group by SettlementDate
 order by 1;

IF OBJECT_ID('tempdb..#wt_bau1', 'U') IS NOT NULL 
   drop table #wt_bau1;
select a.*, DATEPART(dw, SettlementDate) as WkDay
  into #wt_bau1
  from #adp_wt a;

select SettlementDate, sum(n_WD) as totwd
  from #wt_bau1
 group by SettlementDate
 order by 1;

/* Calculate total number of withdrawals and withdrawal amounts by ATM and day of week for the 4 week period. */
IF OBJECT_ID('tempdb..#test2', 'U') IS NOT NULL 
   drop table #test2;
select ATMInternalID, 
       WkDay, 
	   sum(n_WD) as n_WD, 
	   sum(WDAmt) as WDAmt
  into #test2
  from #wt_bau1
 group by ATMInternalID, WkDay;

select *
from #test2;

/* Calculate total number of withdrawals and withdrawal amounts by day of week for the four week period. */
IF OBJECT_ID('tempdb..#test3', 'U') IS NOT NULL 
   drop table #test3;
select WkDay, 
       sum(n_WD) as n_WDTot, 
	   sum(WDAmt) as WDAmtTot
into #test3
from #wt_bau1
group by WkDay;

select *
  from #test3
 order by WkDay;

/* Calculate weights for each ATM for each day of week. Weights are proportion of number of withdrawals for 
   an ATM for a day of week to the total number of ADP withdrawals for that day of week during the four week
   period; and proportion of withdrawal amount for an ATM for a day of week to the total withdrawal amount for 
   ADP on that day of week during the four week period. */
IF OBJECT_ID('tempdb..#allocwt_base', 'U') IS NOT NULL 
   drop table #allocwt_base;
select a.*, 
       b.n_WDTot, 
	   b.WDAmtTot, 
	   (cast(n_WD as float) / cast(b.n_WDTot as float) ) as wt_wd, 
	   (cast(WDAmt as float) / cast(b.WDAmtTot as float) ) as wt_wdamt
  into #allocwt_base
  from #test2 a
       left join #test3 b on a.WkDay = b.WkDay;

select *
  from #allocwt_base
 where ATMInternalID = 255785
 order by WkDay;

select ATMInternalID, WkDay, count(*) as n_rec
  from #allocwt_base
 group by ATMInternalID, WkDay
having count(*) > 1;
--0

select WkDay, sum(wt_wd), sum(wt_wdamt)
  from #allocwt_base
 group by WkDay
 order by WkDay;

/* Create table for ADP by ATM ID and forecast date, with total number of withdrawals for 
   ADP BINs on forecast date, the weight for the forecast date's day of week, and projected number of 
   withdrawals for that ATM calculated as forecasted total number of ADP withdrawals
   for forecast date times the weight for the forecast date's day of week. */
IF OBJECT_ID('tempdb..#proj_n_wd', 'U') IS NOT NULL 
   drop table #proj_n_wd;
select x.*, isnull(z.wt_wd,0) as wt_wd,
	   x.Totn_WD * isnull(z.wt_wd,0) as n_WD
  into #proj_n_wd
       /* Cross join list of ATMs with list of forecast dates, total projected ADP withdrawal counts by
	      date, and the day of week by forecast date. */

  from (select a.ATMInternalID, 
               b.ForecastDate, 
			   b.n_WD as Totn_WD, 
			   DATEPART(dw, b.ForecastDate) as WkDay, 
			   DATEPART(week, b.ForecastDate) as WkNum
			   /* Create list of ATMs with ADP withdrawal transactions. */

          from (select distinct ATMInternalID
                  from #adp_wt
                 where n_WD > 0
                 --and cast(SettlementDate as date)>='2020-08-01'
               )a
               cross join #fcst b 
       )x
       left join #allocwt_base z 
	   on x.ATMInternalID = z.ATMInternalID 
	       and x.WkDay = z.WkDay;

select ForecastDate, sum(n_WD) as n_WD
  from #proj_n_wd
 group by ForecastDate
 order by 1;
 
select ForecastDate, 
       max(Totn_WD) as Totn_WD, 
       max(WkDay) as WkDay, 
	   max(WkNum) as WkNum, 
	   sum(wt_wd) as Wt, 
	   sum(n_WD) as WD 
  from #proj_n_wd
 group by ForecastDate
 order by ForecastDate

/***********************************************************************************************
ADP has a monthly cycle for average withdrawal amount. Use BOM and ROM to project amount. 

Find Beginning of Month $/WD average as it is higher than the rest of the month. 
***********************************************************************************************/
  
/* Collect ADP Beginning of Month (week containing the 1st) withdrawal transactions. */
IF OBJECT_ID('tempdb..#adp_bom_wt', 'U') IS NOT NULL 
   drop table #adp_bom_wt;
select b.ATMInternalID,
	   sum(case when b.[txntypeid] = 1 then 1 else 0 end) as n_WD,
	   sum(case when b.[txntypeid] = 1 then amount else 0 end) as WDAmt
  into #adp_bom_wt
  from [SSRSReports].[WebReportsUser].[KYC_CASH_PROJ_2023_Finance_Data] b
       inner join #terms1 x 
	   on b.ATMInternalID = x.ATMInternalID
 where b.SettlementDate >= (select dt from #dates where varname = 'BOM1Start') 
   and b.SettlementDate <= (select dt from #dates where varname = 'BOM1End')
   and b.APBinMatchBIN in ('402018','402717','402718','411600','414346','416187','445785', '451440', '456628', '467321', '485340', 
                           '522481', '523680', '524543', '528197', '528227', '530327', '41160001')
 group by b.ATMInternalID;
--29938
 
 insert into #adp_bom_wt
 select b.ATMInternalID,
	   sum(case when b.[txntypeid] = 1 then 1 else 0 end) as n_WD,
	   sum(case when b.[txntypeid] = 1 then amount else 0 end) as WDAmt
  from [SSRSReports].[WebReportsUser].[KYC_CASH_PROJ_2023_Finance_Data] b
       inner join #terms1 x 
	   on b.ATMInternalID = x.ATMInternalID
 where b.SettlementDate >= (select dt from #dates where varname = 'BOM2Start') 
   and b.SettlementDate <= (select dt from #dates where varname = 'BOM2End')
   and b.APBinMatchBIN in ('402018','402717','402718','411600','414346','416187','445785', '451440', '456628', '467321', '485340', 
                           '522481', '523680', '524543', '528197', '528227', '530327', '41160001')
 group by b.ATMInternalID;
--30140 
 
 
 insert into #adp_bom_wt
 select b.ATMInternalID,
	   sum(case when b.[txntypeid] = 1 then 1 else 0 end) as n_WD,
	   sum(case when b.[txntypeid] = 1 then amount else 0 end) as WDAmt
  from [SSRSReports].[WebReportsUser].[KYC_CASH_PROJ_2023_Finance_Data] b
       inner join #terms1 x 
	   on b.ATMInternalID = x.ATMInternalID
 where b.SettlementDate >= (select dt from #dates where varname = 'BOM3Start') 
   and b.SettlementDate <= (select dt from #dates where varname = 'BOM3End')
   and b.APBinMatchBIN in ('402018','402717','402718','411600','414346','416187','445785', '451440', '456628', '467321', '485340', 
                           '522481', '523680', '524543', '528197', '528227', '530327', '41160001')
 group by b.ATMInternalID;
--30349

select count(*) from #adp_bom_wt;
--90427

/* Sum rows over ATMInternalID where there were rows from multiple BOM queries for one ATM. */
IF OBJECT_ID('tempdb..#adp_bom_wt_total', 'U') IS NOT NULL 
   drop table #adp_bom_wt_total; 
select ATMInternalID, 
	   sum(n_WD) as n_WD, 
	   sum(WDAmt) as WDAmt
  into #adp_bom_wt_total	   
  from #adp_bom_wt
 group by ATMInternalID; 
 
select ATMInternalID 
  from #adp_bom_wt_total
 group by ATMInternalID
having count(*) > 1;
--0

/* Calculate average dispense per withdrawal for BOM period. */

IF OBJECT_ID('tempdb..#adp_bom_avg', 'U') IS NOT NULL 
   drop table #adp_bom_avg; 
select ATMInternalID, 
       n_WD, 
	   WDAmt,
	   (cast(WDAmt as float) / cast(n_WD as float)) as AvgWDAmt
  into #adp_bom_avg
  from (select *
          from #adp_bom_wt_total
       )x;

select *
  from #adp_bom_avg;

/***********************************************************************************************
Find Rest of Month $/WD average as it is lower than the beginning of the month. Need to use 
    dates that do not include the first week of the month. 
	Average February and April as Feb is low (until the outage) and Mar is too high but Apr is 
	coming back down. 
***********************************************************************************************/

/* Collect ADP Rest of Month (weeks not containing the 1st) withdrawal transactions. */

IF OBJECT_ID('tempdb..#adp_rom_wt', 'U') IS NOT NULL 
   drop table #adp_rom_wt; 
select b.ATMInternalID,
	   sum(case when b.[txntypeid] = 1 then 1 else 0 end) as n_WD,
	   sum(case when b.[txntypeid] = 1 then amount else 0 end) as WDAmt
  into #adp_rom_wt
  from [SSRSReports].[WebReportsUser].[KYC_CASH_PROJ_2023_Finance_Data] b
       inner join #terms1 x 
	   on b.ATMInternalID = x.ATMInternalID
 where b.SettlementDate >= (select dt from #dates where varname = 'ROMStart') 
   and b.SettlementDate <= (select dt from #dates where varname = 'ROMEnd')
   and b.APBinMatchBIN in ('402018','402717','402718','411600','414346','416187','445785', '451440', '456628', '467321', '485340', 
                           '522481', '523680', '524543', '528197', '528227', '530327', '41160001')
 group by b.ATMInternalID;
--38207
 
select ATMInternalID 
  from #adp_rom_wt
 group by ATMInternalID
having count(*) > 1;
--0

select ATMInternalID, 
	   n_WD, 
	   WDAmt
  from #adp_rom_wt
 order by ATMInternalID; 

/* Calculate total withdrawals and withdrawal amount by ATM, for tranactions on active terminals 
   in the period. */

/* Calculate average withdrawal amount by ATM within this period. */
IF OBJECT_ID('tempdb..#adp_rom_avg', 'U') IS NOT NULL 
   drop table #adp_rom_avg; 
select ATMInternalID, 
       n_WD, 
	   WDAmt,
	   (cast(WDAmt as float) / cast(n_WD as float)) as AvgWDAmt
  into #adp_rom_avg
  from (select *
          from #adp_rom_wt
       )x;

select top 1000 *
  from #proj_n_wd;
  

select avg(AvgWDAmt)
  from #adp_bom_avg;
--179.152510121647
  
select avg(AvgWDAmt)
  from #adp_rom_avg; 
--172.659940211545

Insert into #BOM_ROM_List Select 'adp',
	(select avg(AvgWDAmt)
		from #adp_bom_avg),
	(select avg(AvgWDAmt)
		from #adp_rom_avg);

select * from #BOM_ROM_List;

IF OBJECT_ID('SSRSReports.WebReportsUser.KYC_CASH_PROJ_#BOM_ROM_List', 'U') IS NOT NULL 
   drop table SSRSReports.WebReportsUser.KYC_CASH_PROJ_#BOM_ROM_List; 
select * 
  into SSRSReports.WebReportsUser.KYC_CASH_PROJ_#BOM_ROM_List
  from #BOM_ROM_List;
/* Project daily withdrawal amount by ATM by multiplying projected number of withdrawals by average 
   withdrawal amount over the three week period. */
   
/* **NOTE**: Update defaults for bom, rom from avg(AvgWDAmt) from bom, rom tables. 

             **Update a.WkNum list for BOM weeks in forecast period. 
	
  11/1/21 Note: ADP has a higher withdrawal average on Fridays in the last forecast period. Add $18
                per withdrawal on Friday. 
				ADP also had a higher withdrawal average on the CTC payment day (30) and the following day (18). 
				
  12/17/21: Last month ADP forecast was over on Friday after Thanksgiving and on Friday 12/3, but under on Friday 12/10. 
            Leave the Friday bump in the forecast. 
  2/12/22:  Last month had shortfall every Saturday of around $50/txn. Add a bump for Saturday. 
            Friday is WkDay = 6, Saturday is WkDay = 7.
  3/11/22:  Sat bump is too high, drop it by $25
  8/24/22:  drop the bumps, new: add $8 on Fri and $10 on Sat*/


IF OBJECT_ID('tempdb..#proj_adp_fin', 'U') IS NOT NULL 
   drop table #proj_adp_fin; 
select a.*, 
       case when a.WkNum in (9,13,18,22,26,31,35,40,44,48) 
            then 
			/* Some ATMs have BOM AvgWDAmt that are less than ROM. If so, use ROM all month. */
			     case when isnull(b.AvgWDAmt,(select BOM from #BOM_ROM_List where issuer = 'adp')) > isnull(r.AvgWDAmt,(select ROM from #BOM_ROM_List where issuer = 'adp')) 
				      then case when a.WkDay = 6 then isnull(b.AvgWDAmt,(select BOM from #BOM_ROM_List where issuer = 'adp')) + 15.0
					            when a.WkDay = 7 then isnull(b.AvgWDAmt,(select BOM from #BOM_ROM_List where issuer = 'adp')) + 10.0
					            else isnull(b.AvgWDAmt,(select BOM from #BOM_ROM_List where issuer = 'adp') )
						   end
					  else case when a.WkDay = 6 then isnull(r.AvgWDAmt,(select ROM from #BOM_ROM_List where issuer = 'adp')) + 15.0
					            when a.WkDay = 7 then isnull(b.AvgWDAmt,(select ROM from #BOM_ROM_List where issuer = 'adp')) + 10.0
					            else isnull(r.AvgWDAmt,(select ROM from #BOM_ROM_List where issuer = 'adp') )
						   end
				 end
            else case when a.WkDay = 6 then isnull(r.AvgWDAmt,(select ROM from #BOM_ROM_List where issuer = 'adp')) + 15.0
			          when a.WkDay = 7 then isnull(b.AvgWDAmt,(select ROM from #BOM_ROM_List where issuer = 'adp')) + 10.0
					  else isnull(r.AvgWDAmt,(select ROM from #BOM_ROM_List where issuer = 'adp'))
				 end
       end as AvgWDAmt, 
	   case when a.WkNum in (9,13,18,22,26,31,35,40,44,48) 
	        then 
			     case when isnull(b.AvgWDAmt,(select BOM from #BOM_ROM_List where issuer = 'adp')) > isnull(r.AvgWDAmt,(select ROM from #BOM_ROM_List where issuer = 'adp') )
				      then case when a.WkDay = 6 then a.n_WD * (isnull(b.AvgWDAmt,(select BOM from #BOM_ROM_List where issuer = 'adp')) + 15.0)
					            when a.WkDay = 7 then a.n_WD * (isnull(b.AvgWDAmt,(select BOM from #BOM_ROM_List where issuer = 'adp')) + 10.0)
					            else a.n_WD * isnull(b.AvgWDAmt,(select BOM from #BOM_ROM_List where issuer = 'adp'))
						   end
					  else case when a.WkDay = 6 then a.n_WD * (isnull(r.AvgWDAmt,(select ROM from #BOM_ROM_List where issuer = 'adp')) + 15.0)
					            when a.WkDay = 7 then a.n_WD * (isnull(b.AvgWDAmt,(select ROM from #BOM_ROM_List where issuer = 'adp')) + 10.0)
					            else a.n_WD * isnull(r.AvgWDAmt,(select ROM from #BOM_ROM_List where issuer = 'adp'))
						   end
				 end
            else case when a.WkDay = 6 then a.n_WD * (isnull(r.AvgWDAmt,(select ROM from #BOM_ROM_List where issuer = 'adp')) + 15.0)
			          when a.WkDay = 7 then a.n_WD * (isnull(b.AvgWDAmt,(select ROM from #BOM_ROM_List where issuer = 'adp')) + 10.0)
				      else a.n_WD * isnull(r.AvgWDAmt,(select ROM from #BOM_ROM_List where issuer = 'adp'))
				 end
       end as WDAmt
  into #proj_adp_fin
  from #proj_n_wd a
       left join #adp_rom_avg r 
	   on a.ATMInternalID = r.ATMInternalID
	   left join #adp_bom_avg b
	   on a.ATMInternalID = b.ATMInternalID;


select ForecastDate, sum(n_WD) as n_WD, sum(WDAmt) as WDAmt
  from #proj_adp_fin
where ForecastDate is not null
 group by ForecastDate
 order by 1;
 
IF OBJECT_ID('SSRSReports.WebReportsUser.KYC_CASH_PROJ_#proj_adp_fin', 'U') IS NOT NULL   
    drop table SSRSReports.WebReportsUser.KYC_CASH_PROJ_#proj_adp_fin;
select *
  into SSRSReports.WebReportsUser.KYC_CASH_PROJ_#proj_adp_fin
  from #proj_adp_fin;
--3427285

/* restore #proj_adp_fin
IF OBJECT_ID('tempdb..#proj_adp_fin', 'U') IS NOT NULL   
    drop table #proj_adp_fin;
select * 
  into #proj_adp_fin
  from SSRSReports.WebReportsUser.KYC_CASH_PROJ_#proj_adp_fin
--3398472
*/

select --SettlementDate, 
       count(*) as n_WD, 
	   sum(amount) as WDAmt, 
	   sum(amount)/count(*) as AvgWDAmt
  from SSRSReports.WebReportsUser.KYC_CASH_PROJ_2023_Finance_Data f
       inner join #terms1 t
	   on f.ATMInternalID = t.ATMInternalID
 where APBinMatchBIN in ('402018','402717','402718','411600','414346','416187','445785', '451440', '456628', '467321', '485340', 
                         '522481', '523680', '524543', '528197', '528227', '530327', '41160001')
   and SettlementDate >= (select dt from #dates where varname = 'AllocStart')
   and SettlementDate <= (select dt from #dates where varname = 'AllocEnd');
   
/* Total transactions and overall $/wd for entire BIN group during allocation period. 
n_WD	WDAmt			AvgWDAmt
557407	107659767.00	193.1439
*/

/*************************************************************
Comdata Projection: FcstStart to FcstEnd
**************************************************************/
select *
  from [SSRSReports].[WebReportsUser].[KYC_CASH_PROJ_INP];

/* Pull Comdata UI forecast of number of withdrawals. */
IF OBJECT_ID('tempdb..#fcst', 'U') IS NOT NULL 
   drop table #fcst;
select cast(FcstDate as date) as ForecastDate, 
       sum(Comdata) as n_WD
  into #fcst
  from [SSRSReports].[WebReportsUser].[KYC_CASH_PROJ_INP]
 group by cast(FcstDate as date)
 order by 1;

select *
  from #fcst;


/* Use Last 4 weeks of data available, AllocStart to AllocEnd, to create weights for ATMs. */
IF OBJECT_ID('tempdb..#comdata_wt', 'U') IS NOT NULL 
   drop table #comdata_wt;
select b.ATMInternalID, cast(b.SettlementDate as date) as SettlementDate,
	   sum(case when b.[txntypeid] = 1 then 1 else 0 end) as n_WD,
	   sum(case when b.[txntypeid] = 1 then amount else 0 end) as WDAmt
  into #comdata_wt
  from [SSRSReports].[WebReportsUser].[KYC_CASH_PROJ_2023_Finance_Data] b
       inner join #terms1 x 
	   on b.ATMInternalID = x.ATMInternalID
 where b.APBinMatchBIN in ('502462', '502790', '511449', '511516', '519282', '528847', '548971', '556736')
   and cast(b.SettlementDate as Date) >= (select dt from #dates where varname = 'AllocStart')
   and cast(b.SettlementDate as Date) <= (select dt from #dates where varname = 'AllocEnd')
 group by b.ATMInternalID, cast(b.SettlementDate as date);

create index tmpAP3 on #comdata_wt (ATMInternalID);
create index tmpAP4 on #comdata_wt (SettlementDate);

/* How many ATMs in #comdata_wt? These are the units that will have projected dispense for Comdata. */
select count(distinct ATMInternalID)
  from #comdata_wt;
--25383


select SettlementDate, sum(n_WD) as n_WD
  from #comdata_wt
 group by SettlementDate
 order by 1;

IF OBJECT_ID('tempdb..#wt_bau1', 'U') IS NOT NULL 
   drop table #wt_bau1;
select a.*, DATEPART(dw, SettlementDate) as WkDay
  into #wt_bau1
  from #comdata_wt a;

select SettlementDate, sum(n_WD) as totwd
  from #wt_bau1
 group by SettlementDate
 order by 1;

/* Calculate total number of withdrawals and withdrawal amounts by ATM and day of week for the 4 week period. */
IF OBJECT_ID('tempdb..#test2', 'U') IS NOT NULL 
   drop table #test2;
select ATMInternalID, 
       WkDay, 
	   sum(n_WD) as n_WD, 
	   sum(WDAmt) as WDAmt
  into #test2
  from #wt_bau1
 group by ATMInternalID, WkDay;

select *
from #test2;

/* Calculate total number of withdrawals and withdrawal amounts by day of week for the four week period. */
IF OBJECT_ID('tempdb..#test3', 'U') IS NOT NULL 
   drop table #test3;
select WkDay, 
       sum(n_WD) as n_WDTot, 
	   sum(WDAmt) as WDAmtTot
into #test3
from #wt_bau1
group by WkDay;

select *
  from #test3
 order by WkDay;

/* Calculate weights for each ATM for each day of week. Weights are proportion of number of withdrawals for 
   an ATM for a day of week to the total number of Comerica UI withdrawals for that day of week during the four week
   period; and proportion of withdrawal amount for an ATM for a day of week to the total withdrawal amount for 
   Comdata on that day of week during the four week period. */
IF OBJECT_ID('tempdb..#allocwt_base', 'U') IS NOT NULL 
   drop table #allocwt_base;
select a.*, 
       b.n_WDTot, 
	   b.WDAmtTot, 
	   (cast(n_WD as float) / cast(b.n_WDTot as float) ) as wt_wd, 
	   (cast(WDAmt as float) / cast(b.WDAmtTot as float) ) as wt_wdamt
  into #allocwt_base
  from #test2 a
       left join #test3 b on a.WkDay = b.WkDay;

select *
  from #allocwt_base
 where ATMInternalID = 2399
 order by WkDay;

select ATMInternalID, WkDay, count(*) as n_rec
  from #allocwt_base
 group by ATMInternalID, WkDay
having count(*) > 1;
--0

select WkDay, sum(wt_wd), sum(wt_wdamt)
  from #allocwt_base
 group by WkDay
 order by WkDay;

/* Create table for Comdata by ATM ID and forecast date, with total number of withdrawals for 
   Comdata BINs on forecast date, the weight for the forecast date's day of week, and projected number of 
   withdrawals for that ATM calculated as forecasted total number of Comdata withdrawals
   for forecast date times the weight for the forecast date's day of week. */
IF OBJECT_ID('tempdb..#proj_n_wd', 'U') IS NOT NULL 
   drop table #proj_n_wd;
select x.*, isnull(z.wt_wd,0) as wt_wd,
	   x.Totn_WD * isnull(z.wt_wd,0) as n_WD
  into #proj_n_wd
       /* Cross join list of ATMs with list of forecast dates, total projected Comerica UI withdrawal counts by
	      date, and the day of week by forecast date. */

  from (select a.ATMInternalID, 
               b.ForecastDate, 
			   b.n_WD as Totn_WD, 
			   DATEPART(dw, b.ForecastDate) as WkDay, 
			   DATEPART(week, b.ForecastDate) as WkNum			   
			   /* Create list of ATMs with Comerica UI withdrawal transactions. */

          from (select distinct ATMInternalID
                  from #comdata_wt
                 where n_WD > 0
                 --and cast(SettlementDate as date)>='2020-08-01'
               )a
               cross join #fcst b 
       )x
       left join #allocwt_base z 
	   on x.ATMInternalID = z.ATMInternalID 
	       and x.WkDay = z.WkDay;

select ForecastDate, sum(n_WD) as n_WD
  from #proj_n_wd
 group by ForecastDate
 order by 1;

/***********************************************************************************************
Calculate average withdrawal amount. Comdata has a monthly cycle, so calculate BOM and ROM. 
***********************************************************************************************/
/***********************************************************************************************
Find Beginning of Month $/WD average as it is higher than the rest of the month. 
***********************************************************************************************/


/* Collect Comdata Beginning of Month (week containing the 1st) withdrawal transactions. */
IF OBJECT_ID('tempdb..#comdata_bom_wt', 'U') IS NOT NULL 
   drop table #comdata_bom_wt;
select b.ATMInternalID,
	   sum(case when b.[txntypeid] = 1 then 1 else 0 end) as n_WD,
	   sum(case when b.[txntypeid] = 1 then amount else 0 end) as WDAmt
  into #comdata_bom_wt
  from [SSRSReports].[WebReportsUser].[KYC_CASH_PROJ_2023_Finance_Data] b
       inner join #terms1 x 
	   on b.ATMInternalID = x.ATMInternalID
 where b.SettlementDate >= (select dt from #dates where varname = 'BOM1Start') 
   and b.SettlementDate <= (select dt from #dates where varname = 'BOM1End')
   and b.APBinMatchBIN in ('502462', '502790', '511449', '511516', '519282', '528847', '548971', '556736')
 group by b.ATMInternalID;
--14548


 insert into #comdata_bom_wt
 select b.ATMInternalID,
	   sum(case when b.[txntypeid] = 1 then 1 else 0 end) as n_WD,
	   sum(case when b.[txntypeid] = 1 then amount else 0 end) as WDAmt
  from [SSRSReports].[WebReportsUser].[KYC_CASH_PROJ_2023_Finance_Data] b
       inner join #terms1 x 
	   on b.ATMInternalID = x.ATMInternalID
 where b.SettlementDate >= (select dt from #dates where varname = 'BOM2Start') 
   and b.SettlementDate <= (select dt from #dates where varname = 'BOM2End')
   and b.APBinMatchBIN in ('502462', '502790', '511449', '511516', '519282', '528847', '548971', '556736')
 group by b.ATMInternalID;
--15094

 
 insert into #comdata_bom_wt
 select b.ATMInternalID,
	   sum(case when b.[txntypeid] = 1 then 1 else 0 end) as n_WD,
	   sum(case when b.[txntypeid] = 1 then amount else 0 end) as WDAmt
  from [SSRSReports].[WebReportsUser].[KYC_CASH_PROJ_2023_Finance_Data] b
       inner join #terms1 x 
	   on b.ATMInternalID = x.ATMInternalID
 where b.SettlementDate >= (select dt from #dates where varname = 'BOM3Start') 
   and b.SettlementDate <= (select dt from #dates where varname = 'BOM3End')
   and b.APBinMatchBIN in ('502462', '502790', '511449', '511516', '519282', '528847', '548971', '556736')
 group by b.ATMInternalID;
--15459


select count(*) from #comdata_bom_wt;
--45101

/* Sum rows over ATMInternalID where there were rows from multiple BOM queries for one ATM. */
IF OBJECT_ID('tempdb..#comdata_bom_wt_total', 'U') IS NOT NULL 
   drop table #comdata_bom_wt_total; 
select ATMInternalID, 
	   sum(n_WD) as n_WD, 
	   sum(WDAmt) as WDAmt
  into #comdata_bom_wt_total	   
  from #comdata_bom_wt
 group by ATMInternalID; 
 
select ATMInternalID 
  from #comdata_bom_wt_total
 group by ATMInternalID
having count(*) > 1;
--0

/* Calculate average dispense per withdrawal for BOM period. */

IF OBJECT_ID('tempdb..#comdata_bom_avg', 'U') IS NOT NULL 
   drop table #comdata_bom_avg; 
select ATMInternalID, 
       n_WD, 
	   WDAmt,
	   (cast(WDAmt as float) / cast(n_WD as float)) as AvgWDAmt
  into #comdata_bom_avg
  from (select *
          from #comdata_bom_wt_total
       )x;

select *
  from #comdata_bom_avg;

/***********************************************************************************************
Find Rest of Month $/WD average as it is lower than the beginning of the month. Need to use 
    dates that do not include the first week of the month. 
***********************************************************************************************/

/* Collect Comdata Rest of Month (weeks not containing the 1st) withdrawal transactions. */

IF OBJECT_ID('tempdb..#comdata_rom_wt', 'U') IS NOT NULL 
   drop table #comdata_rom_wt; 
select b.ATMInternalID,
	   sum(case when b.[txntypeid] = 1 then 1 else 0 end) as n_WD,
	   sum(case when b.[txntypeid] = 1 then amount else 0 end) as WDAmt
  into #comdata_rom_wt
  from [SSRSReports].[WebReportsUser].[KYC_CASH_PROJ_2023_Finance_Data] b
       inner join #terms1 x 
	   on b.ATMInternalID = x.ATMInternalID
 where b.SettlementDate >= (select dt from #dates where varname = 'ROMStart') 
   and b.SettlementDate <= (select dt from #dates where varname = 'ROMEnd')
   and b.APBinMatchBIN in ('502462', '502790', '511449', '511516', '519282', '528847', '548971', '556736')
 group by b.ATMInternalID;
--23145
 
select ATMInternalID 
  from #comdata_rom_wt
 group by ATMInternalID
having count(*) > 1;
--0

select ATMInternalID, 
	   n_WD, 
	   WDAmt
  from #comdata_rom_wt
 order by ATMInternalID; 

/* Calculate total withdrawals and withdrawal amount by ATM, for tranactions on active terminals 
   in the period. */

/* Calculate average withdrawal amount by ATM within this three week period. */
IF OBJECT_ID('tempdb..#comdata_rom_avg', 'U') IS NOT NULL 
   drop table #comdata_rom_avg; 
select ATMInternalID, 
       n_WD, 
	   WDAmt,
	   (cast(WDAmt as float) / cast(n_WD as float)) as AvgWDAmt
  into #comdata_rom_avg
  from (select *
          from #comdata_rom_wt
       )x;

select top 1000 *
  from #proj_n_wd;
  

select avg(AvgWDAmt)
  from #comdata_bom_avg;
--201.711242848871
select avg(AvgWDAmt)
  from #comdata_rom_avg; 
--197.57146600453

Insert into #BOM_ROM_List Select 'comdata',
	(select avg(AvgWDAmt)
		from #comdata_bom_avg),
	(select avg(AvgWDAmt)
		from #comdata_rom_avg);

select * from #BOM_ROM_List;

IF OBJECT_ID('SSRSReports.WebReportsUser.KYC_CASH_PROJ_#BOM_ROM_List', 'U') IS NOT NULL 
   drop table SSRSReports.WebReportsUser.KYC_CASH_PROJ_#BOM_ROM_List; 
select * 
  into SSRSReports.WebReportsUser.KYC_CASH_PROJ_#BOM_ROM_List
  from #BOM_ROM_List;

/* Project daily withdrawal amount by ATM by multiplying projected number of withdrawals by average 
   withdrawal amount over the three week period. */
   
/* **NOTE**: Update defaults for bom, rom from avg(AvgWDAmt) from bom, rom tables. 

             **Update a.WkNum list for BOM weeks in forecast period. 
    11-1-21  Comdata has a higher average withdrawal amount on Fridays, and had a higher average withdrawal 
	         amount on the day of and the day after the CTC payment. Add to the projected withdrawal 
             amount on those days. 
			 
	12/17/21 Comdata forecast was low Thanksgiving and the day before, and fri and sat 12/10 & 12/11. Leave the 
	         bump on Fridays as it was fine for two out of three weekends in the last period. 
			 
	2/12/22  Comdata low on Saturdays by about $50. Add a Sat bump.
	3/11/22  Overcorrected Sat, reduce bump by $30 to $20
	8/24/22  Remove bumps for Fri/Sat on the 1st week of every month*/

IF OBJECT_ID('tempdb..#proj_comdata_fin', 'U') IS NOT NULL 
   drop table #proj_comdata_fin; 
select a.*, 
       case when a.WkNum in (9,13,18,22,26,31,35,40,44,48) 
	        then 
			/* Some ATMs have BOM AvgWDAmt that are less than ROM. If so, use ROM all month. */
			     case when isnull(b.AvgWDAmt,(select BOM from #BOM_ROM_List where issuer = 'comdata') ) > isnull(r.AvgWDAmt,(select ROM from #BOM_ROM_List where issuer = 'comdata') ) 
				      then isnull(b.AvgWDAmt,(select BOM from #BOM_ROM_List where issuer = 'comdata') )
					  else isnull(r.AvgWDAmt,(select ROM from #BOM_ROM_List where issuer = 'comdata') )
				 end
            else case when a.WkDay = 6 then isnull(r.AvgWDAmt,(select ROM from #BOM_ROM_List where issuer = 'comdata') ) + 22.0
			          when a.WkDay = 7 then isnull(r.AvgWDAmt,(select ROM from #BOM_ROM_List where issuer = 'comdata') ) + 20.0
					  else isnull(r.AvgWDAmt,(select ROM from #BOM_ROM_List where issuer = 'comdata') )
				 end
       end as AvgWDAmt, 
	   case when a.WkNum in (9,13,18,22,26,31,35,40,44,48)  
	        then 
			     case when isnull(b.AvgWDAmt,(select BOM from #BOM_ROM_List where issuer = 'comdata') ) > isnull(r.AvgWDAmt,(select ROM from #BOM_ROM_List where issuer = 'comdata') ) 
				      then a.n_WD * isnull(b.AvgWDAmt,(select BOM from #BOM_ROM_List where issuer = 'comdata') )
					  else a.n_WD * isnull(b.AvgWDAmt,(select ROM from #BOM_ROM_List where issuer = 'comdata') )
				 end
            else case when a.WkDay = 6 then a.n_WD * (isnull(r.AvgWDAmt,(select ROM from #BOM_ROM_List where issuer = 'comdata') ) + 22.0)
			          when a.WkDay = 7 then a.n_WD * (isnull(r.AvgWDAmt,(select ROM from #BOM_ROM_List where issuer = 'comdata') ) + 20.0)
					  else a.n_WD * isnull(r.AvgWDAmt,(select ROM from #BOM_ROM_List where issuer = 'comdata') )
				 end
       end as WDAmt
  into #proj_comdata_fin
  from #proj_n_wd a
       left join #comdata_rom_avg r 
	   on a.ATMInternalID = r.ATMInternalID
	   left join #comdata_bom_avg b
	   on a.ATMInternalID = b.ATMInternalID;

select ForecastDate, sum(n_WD) as n_WD, sum(WDAmt) as WDAmt
  from #proj_comdata_fin
where ForecastDate is not null
 group by ForecastDate
 order by 1;
  
IF OBJECT_ID('SSRSReports.WebReportsUser.KYC_CASH_PROJ_#proj_comdata_fin', 'U') IS NOT NULL 
   drop table SSRSReports.WebReportsUser.KYC_CASH_PROJ_#proj_comdata_fin;
select * 
  into SSRSReports.WebReportsUser.KYC_CASH_PROJ_#proj_comdata_fin
  from #proj_comdata_fin;

/* restore #proj_comdata_fin
IF OBJECT_ID('tempdb..#proj_comdata_fin', 'U') IS NOT NULL 
   drop table #proj_comdata_fin;
select * 
  into #proj_comdata_fin
  from SSRSReports.WebReportsUser.KYC_CASH_PROJ_#proj_comdata_fin;
--2104368
*/

select --SettlementDate, 
       count(*) as n_WD, 
	   sum(amount) as WDAmt, 
	   sum(amount)/count(*) as AvgWDAmt
  from SSRSReports.WebReportsUser.KYC_CASH_PROJ_2023_Finance_Data f
       inner join #terms1 t
	   on f.ATMInternalID = t.ATMInternalID
  where APBinMatchBIN in ('502462', '502790', '511449', '511516', '519282', '528847', '548971', '556736')
    and SettlementDate >= (select dt from #dates where varname = 'AllocStart')
	and SettlementDate <= (select dt from #dates where varname = 'AllocEnd');
	
/* Total transactions and $/wd for entire Comerica UI BIN group during allocation period. 
       n_WD and WDAmt just over half of last forecast run. This BIN group is mostly
	   states that dropped federal pandemic UI programs early. 
n_WD	WDAmt	AvgWDAmt
181457	38024000.00	209.5482
*/

/******************************************************************************
Cash App Projection: FcstStart to FcstEnd

4/6/22 Replace Chime-Stride with Cash App
******************************************************************************/
IF OBJECT_ID('tempdb..#dates', 'U') IS NULL
	select *
	into #dates
	from [SSRSReports].[WebReportsUser].[KYC_CASH_PROJ_DATES_JUL2]

IF OBJECT_ID('tempdb..#terms1', 'U') IS NULL
	select *
	into #terms1
	from [SSRSReports].[WebReportsUser].[KYC_CASH_PROJ_TERMS1]

IF OBJECT_ID('tempdb..#new', 'U') IS NULL 
	select *
	  into #new
	  from #terms1
	 where cast(AUDFD2 as date) > (select dt from #dates where varname = 'BaselineStart'); 

IF OBJECT_ID('tempdb..#BOM_ROM_List', 'U') IS NULL

	create table #BOM_ROM_List
	(
		issuer varchar(20) primary key,
		BOM float,
		ROM float
	);
select * from #BOM_ROM_List;

select *
  from [SSRSReports].[WebReportsUser].[KYC_CASH_PROJ_INP];

/* Pull Cash App forecast of number of withdrawals. */
IF OBJECT_ID('tempdb..#fcst', 'U') IS NOT NULL 
   drop table #fcst;
select cast(FcstDate as date) as ForecastDate, 
       sum(CashApp) as n_WD
  into #fcst
  from [SSRSReports].[WebReportsUser].[KYC_CASH_PROJ_INP]
 group by cast(FcstDate as date)
 order by 1;

select *
  from #fcst;

/* Use most recent 4 weeks of data to create day of week weights for ATM transactions, and create
   list of ATMs onto which to project dispense.  */

IF OBJECT_ID('tempdb..#cashapp_wt', 'U') IS NOT NULL 
   drop table #cashapp_wt;
select b.ATMInternalID, 
       b.SettlementDate as SettlementDate,
	   sum(case when b.[txntypeid] = 1 then 1 else 0 end) as n_WD,
	   sum(case when b.[txntypeid] = 1 then amount else 0 end) as WDAmt
  into #cashapp_wt
  from [SSRSReports].[WebReportsUser].[KYC_CASH_PROJ_2023_Finance_Data] b
       inner join #terms1 x 
	   on b.ATMInternalID = x.ATMInternalID
 where b.SettlementDate >= (select dt from #dates where varname = 'AllocStart') 
   and b.SettlementDate <= (select dt from #dates where varname = 'AllocEnd')
   and b.APBinMatchBIN in ('440393')
 group by b.ATMInternalID, b.SettlementDate;

create index tmpAP3 on #cashapp_wt (ATMInternalID);
create index tmpAP4 on #cashapp_wt (SettlementDate);

/* How many ATMs in #cashapp_wt? These are the ATMs that will have projected dispense.
       Up 9000 from last run. */
select count(distinct ATMInternalID)
  from #cashapp_wt;
--44656 

select SettlementDate, sum(n_WD) as n_WD
  from #cashapp_wt
 group by SettlementDate
 order by 1;

IF OBJECT_ID('tempdb..#wt_bau1', 'U') IS NOT NULL 
   drop table #wt_bau1;
select a.*, DATEPART(dw, SettlementDate) as WkDay
  into #wt_bau1
  from #cashapp_wt a;

select SettlementDate, sum(n_WD) as totwd
  from #wt_bau1
 group by SettlementDate
 order by 1;
 
/* Calculate total number of withdrawals and withdrawal amounts by ATM and day of week for the 4 week period. */
IF OBJECT_ID('tempdb..#test2', 'U') IS NOT NULL 
   drop table #test2;
select ATMInternalID, 
       WkDay, 
	   sum(n_WD) as n_WD, 
	   sum(WDAmt) as WDAmt
  into #test2
  from #wt_bau1
 group by ATMInternalID, WkDay;

select *
from #test2;

/* Calculate total number of withdrawals and withdrawal amounts by day of week for the four week period. */
IF OBJECT_ID('tempdb..#test3', 'U') IS NOT NULL 
   drop table #test3;
select WkDay, 
       sum(n_WD) as n_WDTot, 
	   sum(WDAmt) as WDAmtTot
into #test3
from #wt_bau1
group by WkDay;

select *
  from #test3
 order by WkDay;

/* Calculate weights for each ATM for each day of week. Weights are proportion of number of withdrawals for 
   an ATM for a day of week to the total number of Cash App withdrawals for that day of week during the four week
   period; and proportion of withdrawal amount for an ATM for a day of week to the total withdrawal amount for 
   Cash App on that day of week during the four week period. */
IF OBJECT_ID('tempdb..#allocwt_base', 'U') IS NOT NULL 
   drop table #allocwt_base;
select a.*, 
       b.n_WDTot, 
	   b.WDAmtTot, 
	   (cast(n_WD as float) / cast(b.n_WDTot as float) ) as wt_wd, 
	   (cast(WDAmt as float) / cast(b.WDAmtTot as float) ) as wt_wdamt
  into #allocwt_base
  from #test2 a
       left join #test3 b on a.WkDay = b.WkDay;

select *
  from #allocwt_base
 where ATMInternalID = 149126
 order by WkDay;

select ATMInternalID, WkDay, count(*) as n_rec
  from #allocwt_base
 group by ATMInternalID, WkDay
having count(*) > 1;
--0

select WkDay, sum(wt_wd), sum(wt_wdamt)
  from #allocwt_base
 group by WkDay
 order by WkDay;

/* Create table for Cash App by ATM ID and forecast date, with total number of withdrawals for 
   Cash App BINs on forecast date, the weight for the forecast date's day of week, and projected number of 
   withdrawals for that ATM calculated as forecasted total number of Cash App withdrawals
   for forecast date times the weight for the forecast date's day of week. */
IF OBJECT_ID('tempdb..#proj_n_wd', 'U') IS NOT NULL 
   drop table #proj_n_wd;
select x.*, isnull(z.wt_wd,0) as wt_wd,
	   x.Totn_WD * isnull(z.wt_wd,0) as n_WD
  into #proj_n_wd
       /* Cross join list of ATMs with list of forecast dates, total projected Cash App withdrawal counts by
	      date, and the day of week by forecast date. */

  from (select a.ATMInternalID, 
               b.ForecastDate, 
			   b.n_WD as Totn_WD, 
			   DATEPART(dw, b.ForecastDate) as WkDay, 
			   DATEPART(week, b.ForecastDate) as WkNum
			   /* Create list of ATMs with Cash App withdrawal transactions. */

          from (select distinct ATMInternalID
                  from #cashapp_wt
                 where n_WD > 0
                 --and cast(SettlementDate as date)>='2020-08-01'
               )a
               cross join #fcst b 
       )x
       left join #allocwt_base z 
	   on x.ATMInternalID = z.ATMInternalID 
	       and x.WkDay = z.WkDay;

select ForecastDate, sum(n_WD) as n_WD
  from #proj_n_wd
 group by ForecastDate
 order by 1;


/********************************************************************************************************
Cash App has a cyclic pattern to average dispense per withdrawal as it is higher at the beginning of the 
      month and lower the rest of the month. Calculate two values to use during these times. The BOM 
	  value is calculated as the average of the last two weeks including the first of the month. The 
	  ROM value is calculated as the average of the last three continguous weeks that do not include the 
	  first of the month. 
	  As ROM for March is high due to stimulus as ROM for February is low due to winter storm Uri, 
	  average the two for ROM values. 
*********************************************************************************************************/
/***********************************************************************************************
Find Beginning of Month $/WD average as it is higher than the rest of the month. 
***********************************************************************************************/
  
/* Collect Cash App Beginning of Month (week containing the 1st) withdrawal transactions. */
IF OBJECT_ID('tempdb..#cashapp_bom_wt', 'U') IS NOT NULL 
   drop table #cashapp_bom_wt;
select b.ATMInternalID,
	   sum(case when b.[txntypeid] = 1 then 1 else 0 end) as n_WD,
	   sum(case when b.[txntypeid] = 1 then amount else 0 end) as WDAmt
  into #cashapp_bom_wt
  from [SSRSReports].[WebReportsUser].[KYC_CASH_PROJ_2023_Finance_Data] b
       inner join #terms1 x 
	   on b.ATMInternalID = x.ATMInternalID
 where b.SettlementDate >= (select dt from #dates where varname = 'BOM1Start') 
   and b.SettlementDate <= (select dt from #dates where varname = 'BOM1End')
   and b.APBinMatchBIN in ('440393')
 group by b.ATMInternalID;
--32330

 insert into #cashapp_bom_wt
 select b.ATMInternalID,
	   sum(case when b.[txntypeid] = 1 then 1 else 0 end) as n_WD,
	   sum(case when b.[txntypeid] = 1 then amount else 0 end) as WDAmt
  from [SSRSReports].[WebReportsUser].[KYC_CASH_PROJ_2023_Finance_Data] b
       inner join #terms1 x 
	   on b.ATMInternalID = x.ATMInternalID
 where b.SettlementDate >= (select dt from #dates where varname = 'BOM2Start') 
   and b.SettlementDate <= (select dt from #dates where varname = 'BOM2End')
   and b.APBinMatchBIN in ('440393')
 group by b.ATMInternalID;
--32863

 insert into #cashapp_bom_wt
 select b.ATMInternalID,
	   sum(case when b.[txntypeid] = 1 then 1 else 0 end) as n_WD,
	   sum(case when b.[txntypeid] = 1 then amount else 0 end) as WDAmt
  from [SSRSReports].[WebReportsUser].[KYC_CASH_PROJ_2023_Finance_Data] b
       inner join #terms1 x 
	   on b.ATMInternalID = x.ATMInternalID
 where b.SettlementDate >= (select dt from #dates where varname = 'BOM3Start') 
   and b.SettlementDate <= (select dt from #dates where varname = 'BOM3End')
   and b.APBinMatchBIN in ('440393')
 group by b.ATMInternalID;
--33646


select count(*) from #cashapp_bom_wt;
--98839

/* Sum rows over ATMInternalID where there were rows from multiple BOM queries for one ATM. */
IF OBJECT_ID('tempdb..#cashapp_bom_wt_total', 'U') IS NOT NULL 
   drop table #cashapp_bom_wt_total; 
select ATMInternalID, 
	   sum(n_WD) as n_WD, 
	   sum(WDAmt) as WDAmt
  into #cashapp_bom_wt_total	   
  from #cashapp_bom_wt
 group by ATMInternalID; 
 
select ATMInternalID 
  from #cashapp_bom_wt_total
 group by ATMInternalID
having count(*) > 1;
--0

/* Calculate average dispense per withdrawal for BOM period. */

IF OBJECT_ID('tempdb..#cashapp_bom_avg', 'U') IS NOT NULL 
   drop table #cashapp_bom_avg; 
select ATMInternalID, 
       n_WD, 
	   WDAmt,
	   (cast(WDAmt as float) / cast(n_WD as float)) as AvgWDAmt
  into #cashapp_bom_avg
  from (select *
          from #cashapp_bom_wt_total
       )x;

select *
  from #cashapp_bom_avg;

/***********************************************************************************************
Find Rest of Month $/WD average as it is lower than the beginning of the month. Need to use 
    dates that do not include the first week of the month. 
	Average February and April as Feb is low (until the outage) and Mar is too high but Apr is 
	coming back down. 
***********************************************************************************************/

/* Collect Cash App Rest of Month (weeks not containing the 1st) withdrawal transactions. */

IF OBJECT_ID('tempdb..#cashapp_rom_wt', 'U') IS NOT NULL 
   drop table #cashapp_rom_wt; 
select b.ATMInternalID,
	   sum(case when b.[txntypeid] = 1 then 1 else 0 end) as n_WD,
	   sum(case when b.[txntypeid] = 1 then amount else 0 end) as WDAmt
  into #cashapp_rom_wt
  from [SSRSReports].[WebReportsUser].[KYC_CASH_PROJ_2023_Finance_Data] b
       inner join #terms1 x 
	   on b.ATMInternalID = x.ATMInternalID
 where b.SettlementDate >= (select dt from #dates where varname = 'ROMStart') 
   and b.SettlementDate <= (select dt from #dates where varname = 'ROMEnd')
   and b.APBinMatchBIN in ('440393')
 group by b.ATMInternalID;
--42034
 
select ATMInternalID 
  from #cashapp_rom_wt
 group by ATMInternalID
having count(*) > 1;
--0

select ATMInternalID, 
	   n_WD, 
	   WDAmt
  from #cashapp_rom_wt
 order by ATMInternalID; 

/* Calculate total withdrawals and withdrawal amount by ATM, for tranactions on active terminals 
   in the period. */

/* Calculate average withdrawal amount by ATM within this period. */
IF OBJECT_ID('tempdb..#cashapp_rom_avg', 'U') IS NOT NULL 
   drop table #cashapp_rom_avg; 
select ATMInternalID, 
       n_WD, 
	   WDAmt,
	   (cast(WDAmt as float) / cast(n_WD as float)) as AvgWDAmt
  into #cashapp_rom_avg
  from (select *
          from #cashapp_rom_wt
       )x;

select top 1000 *
  from #proj_n_wd;
  
/* Note: BOM avg and ROM avg are pretty close to last cycle. */
select avg(AvgWDAmt)
  from #cashapp_bom_avg;
--138.403278383257

select avg(AvgWDAmt)
  from #cashapp_rom_avg; 
--131.386323376162

Insert into #BOM_ROM_List Select 'cashapp',
	(select avg(AvgWDAmt)
		from #cashapp_bom_avg),
	(select avg(AvgWDAmt)
		from #cashapp_rom_avg);

select * from #BOM_ROM_List;

IF OBJECT_ID('SSRSReports.WebReportsUser.KYC_CASH_PROJ_#BOM_ROM_List', 'U') IS NOT NULL 
   drop table SSRSReports.WebReportsUser.KYC_CASH_PROJ_#BOM_ROM_List; 
select * 
  into SSRSReports.WebReportsUser.KYC_CASH_PROJ_#BOM_ROM_List
  from #BOM_ROM_List;
/* Project daily withdrawal amount by ATM by multiplying projected number of withdrawals by average 
   withdrawal amount over the three week period. */
   
/* **NOTE**: Update defaults for bom, rom from avg(AvgWDAmt) from bom, rom tables. 

             **Update a.WkNum list for BOM weeks in forecast period. */
/* 8/24/22 Add a $10 bump on Fri (ROM) */

IF OBJECT_ID('tempdb..#proj_cashapp_fin', 'U') IS NOT NULL 
   drop table #proj_cashapp_fin; 
select a.*, 
       case when a.WkNum in (9,13,18,22,26,31,35,40,44,48) 
	        then 
			     case when isnull(b.AvgWDAmt,(select BOM from #BOM_ROM_List where issuer = 'cashapp') ) > isnull(r.AvgWDAmt,(select ROM from #BOM_ROM_List where issuer = 'cashapp') ) 
				      then isnull(b.AvgWDAmt,(select BOM from #BOM_ROM_List where issuer = 'cashapp') ) 
					  else isnull(r.AvgWDAmt,(select ROM from #BOM_ROM_List where issuer = 'cashapp') ) 
				 end
            else case when a.WkDay = 6 then isnull(r.AvgWDAmt,(select ROM from #BOM_ROM_List where issuer = 'cashapp') )+ 10.0
					  else isnull(r.AvgWDAmt,(select ROM from #BOM_ROM_List where issuer = 'cashapp') ) 
				end
       end as AvgWDAmt, 
	   case when a.WkNum in (9,13,18,22,26,31,35,40,44,48)  
	        then 
			     case when isnull(b.AvgWDAmt,132.28) > isnull(r.AvgWDAmt,(select BOM from #BOM_ROM_List where issuer = 'cashapp') ) 
				      then a.n_WD * isnull(b.AvgWDAmt,(select BOM from #BOM_ROM_List where issuer = 'cashapp') ) 
					  else a.n_WD * isnull(r.AvgWDAmt,(select ROM from #BOM_ROM_List where issuer = 'cashapp') ) 
				 end
            else case when a.WkDay = 6 then a.n_WD * (isnull(r.AvgWDAmt,(select ROM from #BOM_ROM_List where issuer = 'cashapp') )+ 10.0)
			     else a.n_WD * isnull(r.AvgWDAmt,(select ROM from #BOM_ROM_List where issuer = 'cashapp') ) 
				 end 
       end as WDAmt
  into #proj_cashapp_fin
  from #proj_n_wd a
       left join #cashapp_rom_avg r 
	   on a.ATMInternalID = r.ATMInternalID
	   left join #cashapp_bom_avg b
	   on a.ATMInternalID = b.ATMInternalID;

select ForecastDate, sum(n_WD) as n_WD, sum(WDAmt) as WDAmt
  from #proj_cashapp_fin
where ForecastDate is not null
 group by ForecastDate
 order by 1;

IF OBJECT_ID('SSRSReports.WebReportsUser.KYC_CASH_PROJ_#proj_cashapp_fin', 'U') IS NOT NULL 
   drop table SSRSReports.WebReportsUser.KYC_CASH_PROJ_#proj_cashapp_fin; 
select *
  into SSRSReports.WebReportsUser.KYC_CASH_PROJ_#proj_cashapp_fin
  from #proj_cashapp_fin;
--3795760

/* restore #proj_cashapp_fin
IF OBJECT_ID('tempdb..#proj_cashapp_fin', 'U') IS NOT NULL 
   drop table #proj_cashapp_fin; 
select *
  into #proj_cashapp_fin
  from SSRSReports.WebReportsUser.KYC_CASH_PROJ_#proj_cashapp_fin;
--3251388
*/

select --SettlementDate, 
       count(*) as n_WD, 
	   sum(amount) as WDAmt, 
	   sum(amount)/count(*) as AvgWDAmt
  from SSRSReports.WebReportsUser.KYC_CASH_PROJ_2023_Finance_Data f
       inner join #terms1 t
	   on f.ATMInternalID = t.ATMInternalID
 where APBinMatchBIN in ('440393')
   and SettlementDate >= (select dt from #dates where varname = 'AllocStart')
   and SettlementDate <= (select dt from #dates where varname = 'AllocEnd');
   
/* Total transactions and average $/wd for Cash App over allocation period. Transactions
      and average withdrawal amount up slightly, in line with recent trend.  
n_WD	WDAmt	AvgWDAmt
574436	75789971.00	131.938
*/

 
/**************************************************************************************
Chime Projection: FcstStart to FcstEnd

2/10/21 tc  Added Bancorp BIN 423223
6/1/21  tc  Chime-Bancorp added two AP extended BINs effective 5/5/21: 4232230, 4232231
11/1/21 tc  On 9/1/21, Chime removed extended BINs from AP and enrolled 3 6-digit BINS
            in AP: 498503 (Chime-Stride BIN group), and 423223 & 421783 (Bancorp BIN group)
			Remove extended BINs and add 421783 to this group. 
11/19/21 tc Added three BINs that were added to AP on 10/6/21. Little to no volume yet, 
            but don't want to get caught by surprise in the future, so adding now. 
			486208, 400895, 447227
4/6/22 tc   Merge all Chime bins into one group, rename Chime
**************************************************************************************/
IF OBJECT_ID('tempdb..#dates', 'U') IS NULL
	select *
	into #dates
	from [SSRSReports].[WebReportsUser].[KYC_CASH_PROJ_DATES_JUL2]

IF OBJECT_ID('tempdb..#terms1', 'U') IS NULL
	select *
	into #terms1
	from [SSRSReports].[WebReportsUser].[KYC_CASH_PROJ_TERMS1]

IF OBJECT_ID('tempdb..#new', 'U') IS NULL 
	select *
	  into #new
	  from #terms1
	 where cast(AUDFD2 as date) > (select dt from #dates where varname = 'BaselineStart'); 

IF OBJECT_ID('tempdb..#BOM_ROM_List', 'U') IS NULL

	create table #BOM_ROM_List
	(
		issuer varchar(20) primary key,
		BOM float,
		ROM float
	);
select * from #BOM_ROM_List;


select *
  from [SSRSReports].[WebReportsUser].[KYC_CASH_PROJ_INP];

/* Pull Chime forecast of number of withdrawals. */
IF OBJECT_ID('tempdb..#fcst', 'U') IS NOT NULL 
   drop table #fcst;
select cast(FcstDate as date) as ForecastDate, sum(Chime) as n_WD
  into #fcst
  from [SSRSReports].[WebReportsUser].[KYC_CASH_PROJ_INP]
 group by cast(FcstDate as date)
 order by 1;

select *
  from #fcst;

/* Use most recent 4 weeks of data to create day of week weights for ATM transactions, and create
   list of ATMs onto which to project dispense.  */
IF OBJECT_ID('tempdb..#chime_wt', 'U') IS NOT NULL 
   drop table #chime_wt;
select b.ATMInternalID, 
       cast(b.SettlementDate as date) as SettlementDate,
	   sum(case when b.[txntypeid] = 1 then 1 else 0 end) as n_WD,
	   sum(case when b.[txntypeid] = 1 then amount else 0 end) as WDAmt
  into #chime_wt
  from [SSRSReports].[WebReportsUser].[KYC_CASH_PROJ_2023_Finance_Data] b
       inner join #terms1 x 
	   on b.ATMInternalID = x.ATMInternalID
 where b.APBinMatchBIN in ('498503', '423223', '421783', '400895', '447227', '486208')
   and b.SettlementDate >= (select dt from #dates where varname = 'AllocStart') 
   and b.SettlementDate <= (select dt from #dates where varname = 'AllocEnd')
 group by b.ATMInternalID, cast(b.SettlementDate as date);


create index tmpAP3 on #chime_wt (ATMInternalID);
create index tmpAP4 on #chime_wt (SettlementDate);

/* How many ATMs in #chime_wt? These are the ATMs that will have projected dispense. 
       Up 5000 from last forecast. */
select count(distinct ATMInternalID)
  from #chime_wt;
--47446

select SettlementDate, sum(n_WD) as n_WD
  from #chime_wt
 group by SettlementDate
 order by 1;

IF OBJECT_ID('tempdb..#wt_bau1', 'U') IS NOT NULL 
   drop table #wt_bau1;
select a.*, DATEPART(dw, SettlementDate) as WkDay
  into #wt_bau1
  from #chime_wt a;

select SettlementDate, sum(n_WD) as totwd
  from #wt_bau1
 group by SettlementDate
 order by 1;
 
/* Calculate total number of withdrawals and withdrawal amounts by ATM and day of week for the 4 week period. */
IF OBJECT_ID('tempdb..#test2', 'U') IS NOT NULL 
   drop table #test2;
select ATMInternalID, 
       WkDay, 
	   sum(n_WD) as n_WD, 
	   sum(WDAmt) as WDAmt
  into #test2
  from #wt_bau1
 group by ATMInternalID, WkDay;

select *
from #test2;

/* Calculate total number of withdrawals and withdrawal amounts by day of week for the four week period. */
IF OBJECT_ID('tempdb..#test3', 'U') IS NOT NULL 
   drop table #test3;
select WkDay, 
       sum(n_WD) as n_WDTot, 
	   sum(WDAmt) as WDAmtTot
into #test3
from #wt_bau1
group by WkDay;

select *
  from #test3
 order by WkDay;

/* Calculate weights for each ATM for each day of week. Weights are proportion of number of withdrawals for 
   an ATM for a day of week to the total number of Chime withdrawals for that day of week during the four week
   period; and proportion of withdrawal amount for an ATM for a day of week to the total withdrawal amount for 
   Chime on that day of week during the four week period. */
IF OBJECT_ID('tempdb..#allocwt_base', 'U') IS NOT NULL 
   drop table #allocwt_base;
select a.*, 
       b.n_WDTot, 
	   b.WDAmtTot, 
	   (cast(n_WD as float) / cast(b.n_WDTot as float) ) as wt_wd, 
	   (cast(WDAmt as float) / cast(b.WDAmtTot as float) ) as wt_wdamt
  into #allocwt_base
  from #test2 a
       left join #test3 b on a.WkDay = b.WkDay;

select *
  from #allocwt_base
 where ATMInternalID = 149126
 order by WkDay;

select ATMInternalID, WkDay, count(*) as n_rec
  from #allocwt_base
 group by ATMInternalID, WkDay
having count(*) > 1;
--0

select WkDay, sum(wt_wd), sum(wt_wdamt)
  from #allocwt_base
 group by WkDay
 order by WkDay;

/* Create table for Chime by ATM ID and forecast date, with total number of withdrawals for 
   Chime BINs on forecast date, the weight for the forecast date's day of week, and projected number of 
   withdrawals for that ATM calculated as forecasted total number of Chime withdrawals
   for forecast date times the weight for the forecast date's day of week. */
IF OBJECT_ID('tempdb..#proj_n_wd', 'U') IS NOT NULL 
   drop table #proj_n_wd;
select x.*, isnull(z.wt_wd,0) as wt_wd,
	   x.Totn_WD * isnull(z.wt_wd,0) as n_WD
  into #proj_n_wd
       /* Cross join list of ATMs with list of forecast dates, total projected Chime withdrawal counts by
	      date, and the day of week by forecast date. */

  from (select a.ATMInternalID, 
               b.ForecastDate, 
			   b.n_WD as Totn_WD, 
			   DATEPART(dw, b.ForecastDate) as WkDay, 
			   DATEPART(week, b.ForecastDate) as WkNum
			   /* Create list of ATMs with Chime withdrawal transactions. */

          from (select distinct ATMInternalID
                  from #chime_wt
                 where n_WD > 0
               )a
               cross join #fcst b 
       )x
       left join #allocwt_base z 
	   on x.ATMInternalID = z.ATMInternalID 
	       and x.WkDay = z.WkDay;

select ForecastDate, sum(n_WD) as n_WD
  from #proj_n_wd
 group by ForecastDate
 order by 1;


/********************************************************************************************************
Chime has a cyclic pattern to average dispense per withdrawal as it is higher at the beginning of the 
      month and lower the rest of the month. Calculate two values to use during these times. The BOM 
	  value is calculated as the average of the last two weeks including the first of the month. The 
	  ROM value is calculated as the average of the last three continguous weeks that do not include the 
	  first of the month. 
*********************************************************************************************************/
/***********************************************************************************************
Find Beginning of Month $/WD average as it is higher than the rest of the month. 
***********************************************************************************************/
/* Collect Chime Beginning of Month (week containing the 1st) withdrawal transactions. */
IF OBJECT_ID('tempdb..#chime_bom_wt', 'U') IS NOT NULL 
   drop table #chime_bom_wt;
select b.ATMInternalID, 
	   sum(case when b.[txntypeid] = 1 then 1 else 0 end) as n_WD,
	   sum(case when b.[txntypeid] = 1 then amount else 0 end) as WDAmt
  into #chime_bom_wt
  from [SSRSReports].[WebReportsUser].[KYC_CASH_PROJ_2023_Finance_Data] b
       inner join #terms1 x 
	   on b.ATMInternalID = x.ATMInternalID
 where b.APBinMatchBIN in ('498503', '423223', '421783', '400895', '447227', '486208')
   and b.SettlementDate >= (select dt from #dates where varname = 'BOM1Start') 
   and b.SettlementDate <= (select dt from #dates where varname = 'BOM1End')
 group by b.ATMInternalID;
--40164

insert into #chime_bom_wt
select b.ATMInternalID, 
	   sum(case when b.[txntypeid] = 1 then 1 else 0 end) as n_WD,
	   sum(case when b.[txntypeid] = 1 then amount else 0 end) as WDAmt
  from [SSRSReports].[WebReportsUser].[KYC_CASH_PROJ_2023_Finance_Data] b
       inner join #terms1 x 
	   on b.ATMInternalID = x.ATMInternalID
 where b.APBinMatchBIN in ('498503', '423223', '421783', '400895', '447227', '486208')
   and b.SettlementDate >= (select dt from #dates where varname = 'BOM2Start') 
   and b.SettlementDate <= (select dt from #dates where varname = 'BOM2End')
 group by b.ATMInternalID;
--40495

insert into #chime_bom_wt
select b.ATMInternalID, 
	   sum(case when b.[txntypeid] = 1 then 1 else 0 end) as n_WD,
	   sum(case when b.[txntypeid] = 1 then amount else 0 end) as WDAmt
  from [SSRSReports].[WebReportsUser].[KYC_CASH_PROJ_2023_Finance_Data] b
       inner join #terms1 x 
	   on b.ATMInternalID = x.ATMInternalID
 where b.APBinMatchBIN in ('498503', '423223', '421783', '400895', '447227', '486208')
   and b.SettlementDate >= (select dt from #dates where varname = 'BOM3Start') 
   and b.SettlementDate <= (select dt from #dates where varname = 'BOM3End')
 group by b.ATMInternalID;
--40918

select count(*) from #chime_bom_wt;
--121577

/* Sum rows over ATMInternalID where there were rows from multiple BOM queries for one ATM. */
IF OBJECT_ID('tempdb..#chime_bom_wt_total', 'U') IS NOT NULL 
   drop table #chime_bom_wt_total; 
select ATMInternalID, 
	   sum(n_WD) as n_WD, 
	   sum(WDAmt) as WDAmt
  into #chime_bom_wt_total	   
  from #chime_bom_wt
 group by ATMInternalID; 
 
select ATMInternalID 
  from #chime_bom_wt_total
 group by ATMInternalID
having count(*) > 1;
--0

/* Calculate average dispense per withdrawal for BOM period. */

IF OBJECT_ID('tempdb..#chime_bom_avg', 'U') IS NOT NULL 
   drop table #chime_bom_avg; 
select ATMInternalID, 
       n_WD, 
	   WDAmt,
	   (cast(WDAmt as float) / cast(n_WD as float)) as AvgWDAmt
  into #chime_bom_avg
  from (select *
          from #chime_bom_wt_total
       )x;

select *
  from #chime_bom_avg;

/***********************************************************************************************
Find Rest of Month $/WD average as it is lower than the beginning of the month. Need to use 
    dates that do not include the first week of the month. 
	Average February and April as Feb is low (until the outage) and Mar is too high but Apr is 
	coming back down. 
***********************************************************************************************/
/* Collect Chime Rest of Month (weeks not containing the 1st) withdrawal transactions. */
IF OBJECT_ID('tempdb..#chime_rom_wt', 'U') IS NOT NULL 
   drop table #chime_rom_wt; 
select b.ATMInternalID, 
	   sum(case when b.[txntypeid] = 1 then 1 else 0 end) as n_WD,
	   sum(case when b.[txntypeid] = 1 then amount else 0 end) as WDAmt
  into #chime_rom_wt
  from [SSRSReports].[WebReportsUser].[KYC_CASH_PROJ_2023_Finance_Data] b
       inner join #terms1 x 
	   on b.ATMInternalID = x.ATMInternalID
 where b.APBinMatchBIN in ('498503', '423223', '421783', '400895', '447227', '486208')
   and b.SettlementDate >= (select dt from #dates where varname = 'ROMStart') 
   and b.SettlementDate <= (select dt from #dates where varname = 'ROMEnd')
 group by b.ATMInternalID;

 
select ATMInternalID 
  from #chime_rom_wt
 group by ATMInternalID
having count(*) > 1;
--0

select ATMInternalID, 
	   n_WD, 
	   WDAmt
  from #chime_rom_wt
 order by ATMInternalID; 
 
/* Calculate total withdrawals and withdrawal amount by ATM, for tranactions in the three week period
   on active terminals. */

/* Calculate average withdrawal amount by ATM within this three week period. */
IF OBJECT_ID('tempdb..#chime_rom_avg', 'U') IS NOT NULL 
   drop table #chime_rom_avg; 
select ATMInternalID, 
       n_WD, 
	   WDAmt,
	   (cast(WDAmt as float) / cast(n_WD as float)) as AvgWDAmt
  into #chime_rom_avg
  from (select *
          from #chime_rom_wt
       )x;

select top 1000 *
  from #proj_n_wd;

/* Nearly unchanged from last cycle. */  
select avg(AvgWDAmt)
  from #chime_bom_avg;
--155.088757716899

select avg(AvgWDAmt)
  from #chime_rom_avg; 
--143.072781055537

Insert into #BOM_ROM_List Select 'chime',
	(select avg(AvgWDAmt)
		from #chime_bom_avg),
	(select avg(AvgWDAmt)
		from #chime_rom_avg);

select * from #BOM_ROM_List;

IF OBJECT_ID('SSRSReports.WebReportsUser.KYC_CASH_PROJ_#BOM_ROM_List', 'U') IS NOT NULL 
   drop table SSRSReports.WebReportsUser.KYC_CASH_PROJ_#BOM_ROM_List; 
select * 
  into SSRSReports.WebReportsUser.KYC_CASH_PROJ_#BOM_ROM_List
  from #BOM_ROM_List;
/* Project daily withdrawal amount by ATM by multiplying projected number of withdrawals by average 
   withdrawal amount over the three week period. */
   
/* **NOTE**: Update defaults for bom, rom from avg(AvgWDAmt) from bom, rom tables. 
             **Update a.WkNum list for BOM weeks in forecast period. */

/* 8/24/22 -- add $10 bump on Fri/Sat for all weeks */

IF OBJECT_ID('tempdb..#proj_chime_fin', 'U') IS NOT NULL 
   drop table #proj_chime_fin; 
select a.*, 
       case when a.WkNum in (9,13,18,22,26,31,35,40,44,48) 
            then 
			/* Some ATMs have BOM AvgWDAmt that are less than ROM. If so, use ROM all month. */
			     case when isnull(b.AvgWDAmt,(select BOM from #BOM_ROM_List where issuer = 'chime') ) > isnull(r.AvgWDAmt,(select ROM from #BOM_ROM_List where issuer = 'chime') ) 
				      then case when a.WkDay = 5 then isnull(b.AvgWDAmt,(select BOM from #BOM_ROM_List where issuer = 'chime') ) + 20.0
								when a.WkDay = 6 then isnull(b.AvgWDAmt,(select BOM from #BOM_ROM_List where issuer = 'chime') ) + 10.0
					            when a.WkDay = 7 then isnull(b.AvgWDAmt,(select BOM from #BOM_ROM_List where issuer = 'chime') ) + 10.0
					            else isnull(b.AvgWDAmt,(select BOM from #BOM_ROM_List where issuer = 'chime') ) 
						   end
					  else case when a.WkDay = 5 then isnull(r.AvgWDAmt,(select ROM from #BOM_ROM_List where issuer = 'chime') ) + 20.0
								when a.WkDay = 6 then isnull(r.AvgWDAmt,(select ROM from #BOM_ROM_List where issuer = 'chime') ) + 10.0
					            when a.WkDay = 7 then isnull(b.AvgWDAmt,(select ROM from #BOM_ROM_List where issuer = 'chime') ) + 10.0
					            else isnull(r.AvgWDAmt,(select ROM from #BOM_ROM_List where issuer = 'chime') ) 
						   end
				 end
            else case when a.WkDay = 5 then isnull(r.AvgWDAmt,(select ROM from #BOM_ROM_List where issuer = 'chime') ) + 20.0
					  when a.WkDay = 6 then isnull(r.AvgWDAmt,(select ROM from #BOM_ROM_List where issuer = 'chime') ) + 10.0
			          when a.WkDay = 7 then isnull(b.AvgWDAmt,(select ROM from #BOM_ROM_List where issuer = 'chime') ) + 10.0
					  else isnull(r.AvgWDAmt,(select ROM from #BOM_ROM_List where issuer = 'chime') )
				 end
       end as AvgWDAmt, 
	   case when a.WkNum in (9,13,18,22,26,31,35,40,44,48) 
	        then 
			     case when isnull(b.AvgWDAmt,(select BOM from #BOM_ROM_List where issuer = 'chime') ) > isnull(r.AvgWDAmt,(select ROM from #BOM_ROM_List where issuer = 'chime') ) 
				      then case when a.WkDay = 5 then a.n_WD * (isnull(b.AvgWDAmt,(select BOM from #BOM_ROM_List where issuer = 'chime') ) + 20.0)
								when a.WkDay = 6 then a.n_WD * (isnull(b.AvgWDAmt,(select BOM from #BOM_ROM_List where issuer = 'chime') ) + 10.0)
					            when a.WkDay = 7 then a.n_WD * (isnull(b.AvgWDAmt,(select BOM from #BOM_ROM_List where issuer = 'chime') ) + 10.0)
					            else a.n_WD * isnull(b.AvgWDAmt,(select BOM from #BOM_ROM_List where issuer = 'chime') )
						   end
					  else case when a.WkDay = 5 then a.n_WD * (isnull(r.AvgWDAmt,(select ROM from #BOM_ROM_List where issuer = 'chime') ) + 20.0)
								when a.WkDay = 6 then a.n_WD * (isnull(r.AvgWDAmt,(select ROM from #BOM_ROM_List where issuer = 'chime') ) + 10.0)
					            when a.WkDay = 7 then a.n_WD * (isnull(b.AvgWDAmt,(select ROM from #BOM_ROM_List where issuer = 'chime') ) + 10.0)
					            else a.n_WD * isnull(r.AvgWDAmt,(select ROM from #BOM_ROM_List where issuer = 'chime') )
						   end
				 end
            else case when a.WkDay = 5 then a.n_WD * (isnull(r.AvgWDAmt,(select ROM from #BOM_ROM_List where issuer = 'chime') ) + 20.0)
					  when a.WkDay = 6 then a.n_WD * (isnull(r.AvgWDAmt,(select ROM from #BOM_ROM_List where issuer = 'chime') ) + 10.0)
			          when a.WkDay = 7 then a.n_WD * (isnull(b.AvgWDAmt,(select ROM from #BOM_ROM_List where issuer = 'chime') ) + 10.0)
				      else a.n_WD * isnull(r.AvgWDAmt,(select ROM from #BOM_ROM_List where issuer = 'chime') )
				 end
       end as WDAmt
  into #proj_chime_fin
  from #proj_n_wd a
       left join #chime_rom_avg r 
	   on a.ATMInternalID = r.ATMInternalID
	   left join #chime_bom_avg b
	   on a.ATMInternalID = b.ATMInternalID;

select ForecastDate, 
       sum(n_WD) as n_WD, 
	   sum(WDAmt) as WDAmt
  from #proj_chime_fin
where ForecastDate is not null
 group by ForecastDate
 order by 1;
 
IF OBJECT_ID('SSRSReports.WebReportsUser.KYC_CASH_PROJ_#proj_chime_fin', 'U') IS NOT NULL 
   drop table SSRSReports.WebReportsUser.KYC_CASH_PROJ_#proj_chime_fin; 
select * 
  into SSRSReports.WebReportsUser.KYC_CASH_PROJ_#proj_chime_fin
  from #proj_chime_fin;
--4032910

/* restore #proj_chime_fin
IF OBJECT_ID('tempdb..#proj_chime_fin', 'U') IS NOT NULL 
   drop table #proj_chime_fin; 
select * 
  into #proj_chime_fin
  from SSRSReports.WebReportsUser.KYC_CASH_PROJ_#proj_chime_fin;
--3788148
*/

select --SettlementDate, 
       count(*) as n_WD, 
	   sum(amount) as WDAmt, 
	   sum(amount)/count(*) as AvgWDAmt
  from SSRSReports.WebReportsUser.KYC_CASH_PROJ_2023_Finance_Data f
       inner join #terms1 t
	   on f.ATMInternalID = t.ATMInternalID
 where f.APBinMatchBIN in ('498503', '423223', '421783', '400895', '447227', '486208')
   and SettlementDate >= (select dt from #dates where varname = 'AllocStart')
   and SettlementDate <= (select dt from #dates where varname = 'AllocEnd');
   
/* Total transactions, average $/wd for all of Chime BIN during allocation period.
n_WD	WDAmt	AvgWDAmt
2150719	321545687.00	149.5061
*/


/*************************************************************
PNC Bank Projection: FcstStart to FcstEnd
7/27/22 Add BINS ('400057','400123','403486','403487','403488','403489','403490','403491','403492','403493','403494',
						'403495','403496','403497','403968','403976','404982','404984','405218','407120','408109','410072',
						'422394','422997','424621','425704','425852','425914','431196','431640','432522','435760','438968',
						'439882','443040','443041','443042','443043','443044','443045','443046','443047','443048','443049',
						'443050','443051','443057','443060','443061','443062','443063','443064','443065','443066','443067',
						'443068','443069','443070','443071','443072','443600','443601','443603','445463','448596','448900',
						'448901','448903','448904','448909','448910','448911','448915','448920','448921','448928','448929',
						'448930','448931','448940','448941','448943','448944','448950','448951','448960','448961','448970',
						'448971','448980','448991','450468','450469','450470','463158','463404','463829','469083','471515',
						'471595','472201','473135','474397','475598','477762','479162','480423','480433','480704','480720',
						'481790','485705','485706','485707','485977','486511','486563','486688','487889','491870','500674',
						'500675','500676','500677','502409','503227','503823','529004','537946','540940','541359','541493',
						'541872','543107','543767','545848','545849','548200','548201','548210','548211','548220','548221',
						'548228','548229','548230','548231','548240','548241','548250','548251','548260','548261','553308',
						'556364','556365','556366','560236','560466','560470','564386','574023','585131','585689','586282',
						'588882')
**************************************************************/
IF OBJECT_ID('tempdb..#dates', 'U') IS NULL
	select *
	into #dates
	from [SSRSReports].[WebReportsUser].[KYC_CASH_PROJ_DATES_JUL2]

IF OBJECT_ID('tempdb..#terms1', 'U') IS NULL
	select *
	into #terms1
	from [SSRSReports].[WebReportsUser].[KYC_CASH_PROJ_TERMS1]

IF OBJECT_ID('tempdb..#new', 'U') IS NULL 
	select *
	  into #new
	  from #terms1
	 where cast(AUDFD2 as date) > (select dt from #dates where varname = 'BaselineStart'); 

IF OBJECT_ID('tempdb..#BOM_ROM_List', 'U') IS NULL

	create table #BOM_ROM_List
	(
		issuer varchar(20) primary key,
		BOM float,
		ROM float
	);
select * from #BOM_ROM_List;

select *
  from [SSRSReports].[WebReportsUser].[KYC_CASH_PROJ_INP];
/* Pull PNC Bank forecast of number of withdrawals. */
IF OBJECT_ID('tempdb..#fcst', 'U') IS NOT NULL 
   drop table #fcst;

select cast(FcstDate as date) as ForecastDate, 
       sum(PNC) as n_WD
  into #fcst
  from [SSRSReports].[WebReportsUser].[KYC_CASH_PROJ_INP]
 group by cast(FcstDate as date)
 order by 1;

IF OBJECT_ID('tempdb..#pncbank_wt', 'U') IS NOT NULL 
   drop table #pncbank_wt;
select b.ATMInternalID, cast(b.SettlementDate as date) as SettlementDate,
	   sum(case when b.[txntypeid] = 1 then 1 else 0 end) as n_WD,
	   sum(case when b.[txntypeid] = 1 then amount else 0 end) as WDAmt
  into #pncbank_wt
  from [SSRSReports].[WebReportsUser].[KYC_CASH_PROJ_2023_Finance_Data] b
       inner join #terms1 x 
	   on b.ATMInternalID = x.ATMInternalID
 where APBinMatchBIN in ('400057','400123','403486','403487','403488','403489','403490','403491','403492','403493','403494',
						'403495','403496','403497','403968','403976','404982','404984','405218','407120','408109','410072',
						'422394','422997','424621','425704','425852','425914','431196','431640','432522','435760','438968',
						'439882','443040','443041','443042','443043','443044','443045','443046','443047','443048','443049',
						'443050','443051','443057','443060','443061','443062','443063','443064','443065','443066','443067',
						'443068','443069','443070','443071','443072','443600','443601','443603','445463','448596','448900',
						'448901','448903','448904','448909','448910','448911','448915','448920','448921','448928','448929',
						'448930','448931','448940','448941','448943','448944','448950','448951','448960','448961','448970',
						'448971','448980','448991','450468','450469','450470','463158','463404','463829','469083','471515',
						'471595','472201','473135','474397','475598','477762','479162','480423','480433','480704','480720',
						'481790','485705','485706','485707','485977','486511','486563','486688','487889','491870','500674',
						'500675','500676','500677','502409','503227','503823','529004','537946','540940','541359','541493',
						'541872','543107','543767','545848','545849','548200','548201','548210','548211','548220','548221',
						'548228','548229','548230','548231','548240','548241','548250','548251','548260','548261','553308',
						'556364','556365','556366','560236','560466','560470','564386','574023','585131','585689','586282',
						'588882')
   and cast(b.SettlementDate as Date) >= (select dt from #dates where varname = 'AllocStart')
   and cast(b.SettlementDate as Date) <= (select dt from #dates where varname = 'AllocEnd')
 group by b.ATMInternalID, cast(b.SettlementDate as date);
 --208345

create index tmpAP3 on #pncbank_wt (ATMInternalID);
create index tmpAP4 on #pncbank_wt (SettlementDate);

select count(distinct ATMInternalID)
  from #pncbank_wt;
--35024

select SettlementDate, sum(n_WD) as n_WD
  from #pncbank_wt
 group by SettlementDate
 order by SettlementDate;

IF OBJECT_ID('tempdb..#wt_bau1', 'U') IS NOT NULL 
   drop table #wt_bau1;
select a.*, DATEPART(dw, SettlementDate) as WkDay
  into #wt_bau1
  from #pncbank_wt a;

select SettlementDate, sum(n_WD) as totwd
  from #wt_bau1
 group by SettlementDate
 order by 1;

IF OBJECT_ID('tempdb..#test2', 'U') IS NOT NULL 
   drop table #test2;
/* Calculate total number of withdrawals and withdrawal amount by ATM and day of week. */
select ATMInternalID, WkDay, sum(n_WD) as n_WD, sum(WDAmt) as WDAmt
  into #test2
  from #wt_bau1
 group by ATMInternalID, WkDay;

 select *
  from #test2;

IF OBJECT_ID('tempdb..#test3', 'U') IS NOT NULL 
   drop table #test3;
/* Calculate total number of withdrawals and withdrawal amount by day of week only. */
select WkDay, sum(n_WD) as n_WDTot, sum(WDAmt) as WDAmtTot
  into #test3
  from #wt_bau1
 group by WkDay;

select *
  from #test3
 order by WkDay;

 IF OBJECT_ID('tempdb..#allocwt_base', 'U') IS NOT NULL 
   drop table #allocwt_base;
/* Calculate proportion of withdrawals for each ATM for each day of week to the total PNC Bank withdrawals 
   for that day of week. Also calculate the proportion of withdrawal amount for each ATM for each day of 
   week to the total PNC Bank withdrawal amount for each day of the week. */

select a.*, 
       b.n_WDTot, 
	   b.WDAmtTot, 
	   case when b.n_WDTot > 0 then (cast(n_WD as float) / cast(b.n_WDTot as float)) 
	        else 0 end as wt_wd, 
	   case when b.WDAmtTot > 0 then (cast(WDAmt as float) / cast(b.WDAmtTot as float)) 
	        else 0 end as wt_wdamt
  into #allocwt_base
  from #test2 a
       left join #test3 b 
	   on a.WkDay = b.WkDay;

select ATMInternalID, WkDay, count(*) as n_rec
  from #allocwt_base
 group by ATMInternalID, WkDay
having count(*) > 1;
--0

select WkDay, sum(wt_wd), sum(wt_wdamt)
  from #allocwt_base
 group by WkDay
 order by WkDay;

IF OBJECT_ID('tempdb..#proj_n_wd', 'U') IS NOT NULL 
   drop table #proj_n_wd;

/* Create table for PNC Bank by ATM ID and forecast date, with total number of withdrawals for 
   PNC Bank BINs on forecast date, the weight for the forecast date's day of week, and projected number of 
   withdrawals for that ATM calculated as forecasted total number of PNC Bank withdrawals
   for forecast date times the weight for the forecast date's day of week. */
select x.*, isnull(z.wt_wd,0) as wt_wd,
       x.Totn_WD * isnull(z.wt_wd,0) as n_WD
  into #proj_n_wd
        /* Cross join list of ATMs with forecast date table to get one row for each ATM for 
		   each day to be forecasted, with the total number of PNC Bank withdrawals forecasted
		   for that day and the day of the week. */
  from (select a.ATMInternalID, 
               b.ForecastDate, 
			   b.n_WD as Totn_WD, 
			   DATEPART(dw, b.ForecastDate) as WkDay, 
			   DATEPART(week, b.ForecastDate) as WkNum
			   /* create list of ATM IDs with PNC Bank withdrawal transactions */
          from (select distinct ATMInternalID
                  from #pncbank_wt
                 where n_WD > 0
               )a
               cross join #fcst b 
       )x
       left join #allocwt_base z 
	   on x.ATMInternalID = z.ATMInternalID 
	       and x.WkDay = z.WkDay;

select ForecastDate, sum(n_WD) as n_WD
  from #proj_n_wd
 group by ForecastDate
 order by 1;

 /********************************************************************************************************
PNC Bank has a cyclic pattern to average dispense per withdrawal as it is higher at the beginning of the 
      month and lower the rest of the month. Calculate two values to use during these times. The BOM 
	  value is calculated as the average of the last two weeks including the first of the month. The 
	  ROM value is calculated as the average of the last three continguous weeks that do not include the 
	  first of the month. 
*********************************************************************************************************/
/***********************************************************************************************
Find Beginning of Month $/WD average as it is higher than the rest of the month. 
***********************************************************************************************/
/* Collect Beginning of Month (week containing the 1st) withdrawal transactions. */
IF OBJECT_ID('tempdb..#pncb_bom_wt', 'U') IS NOT NULL 
   drop table #pncb_bom_wt;
select b.ATMInternalID, 
	   sum(case when b.[txntypeid] = 1 then 1 else 0 end) as n_WD,
	   sum(case when b.[txntypeid] = 1 then amount else 0 end) as WDAmt
  into #pncb_bom_wt
  from [SSRSReports].[WebReportsUser].[KYC_CASH_PROJ_2023_Finance_Data] b
       inner join #terms1 x 
	   on b.ATMInternalID = x.ATMInternalID
 where APBinMatchBIN in ('400057','400123','403486','403487','403488','403489','403490','403491','403492','403493','403494',
						'403495','403496','403497','403968','403976','404982','404984','405218','407120','408109','410072',
						'422394','422997','424621','425704','425852','425914','431196','431640','432522','435760','438968',
						'439882','443040','443041','443042','443043','443044','443045','443046','443047','443048','443049',
						'443050','443051','443057','443060','443061','443062','443063','443064','443065','443066','443067',
						'443068','443069','443070','443071','443072','443600','443601','443603','445463','448596','448900',
						'448901','448903','448904','448909','448910','448911','448915','448920','448921','448928','448929',
						'448930','448931','448940','448941','448943','448944','448950','448951','448960','448961','448970',
						'448971','448980','448991','450468','450469','450470','463158','463404','463829','469083','471515',
						'471595','472201','473135','474397','475598','477762','479162','480423','480433','480704','480720',
						'481790','485705','485706','485707','485977','486511','486563','486688','487889','491870','500674',
						'500675','500676','500677','502409','503227','503823','529004','537946','540940','541359','541493',
						'541872','543107','543767','545848','545849','548200','548201','548210','548211','548220','548221',
						'548228','548229','548230','548231','548240','548241','548250','548251','548260','548261','553308',
						'556364','556365','556366','560236','560466','560470','564386','574023','585131','585689','586282',
						'588882')
   and b.SettlementDate >= (select dt from #dates where varname = 'BOM1Start') 
   and b.SettlementDate <= (select dt from #dates where varname = 'BOM1End')
 group by b.ATMInternalID;
--20032

insert into #pncb_bom_wt
select b.ATMInternalID, 
	   sum(case when b.[txntypeid] = 1 then 1 else 0 end) as n_WD,
	   sum(case when b.[txntypeid] = 1 then amount else 0 end) as WDAmt
  from [SSRSReports].[WebReportsUser].[KYC_CASH_PROJ_2023_Finance_Data] b
       inner join #terms1 x 
	   on b.ATMInternalID = x.ATMInternalID
 where APBinMatchBIN in ('400057','400123','403486','403487','403488','403489','403490','403491','403492','403493','403494',
						'403495','403496','403497','403968','403976','404982','404984','405218','407120','408109','410072',
						'422394','422997','424621','425704','425852','425914','431196','431640','432522','435760','438968',
						'439882','443040','443041','443042','443043','443044','443045','443046','443047','443048','443049',
						'443050','443051','443057','443060','443061','443062','443063','443064','443065','443066','443067',
						'443068','443069','443070','443071','443072','443600','443601','443603','445463','448596','448900',
						'448901','448903','448904','448909','448910','448911','448915','448920','448921','448928','448929',
						'448930','448931','448940','448941','448943','448944','448950','448951','448960','448961','448970',
						'448971','448980','448991','450468','450469','450470','463158','463404','463829','469083','471515',
						'471595','472201','473135','474397','475598','477762','479162','480423','480433','480704','480720',
						'481790','485705','485706','485707','485977','486511','486563','486688','487889','491870','500674',
						'500675','500676','500677','502409','503227','503823','529004','537946','540940','541359','541493',
						'541872','543107','543767','545848','545849','548200','548201','548210','548211','548220','548221',
						'548228','548229','548230','548231','548240','548241','548250','548251','548260','548261','553308',
						'556364','556365','556366','560236','560466','560470','564386','574023','585131','585689','586282',
						'588882')
   and b.SettlementDate >= (select dt from #dates where varname = 'BOM2Start') 
   and b.SettlementDate <= (select dt from #dates where varname = 'BOM2End')
 group by b.ATMInternalID;
--20265
 
insert into #pncb_bom_wt
select b.ATMInternalID, 
	   sum(case when b.[txntypeid] = 1 then 1 else 0 end) as n_WD,
	   sum(case when b.[txntypeid] = 1 then amount else 0 end) as WDAmt
  from [SSRSReports].[WebReportsUser].[KYC_CASH_PROJ_2023_Finance_Data] b
       inner join #terms1 x 
	   on b.ATMInternalID = x.ATMInternalID
 where APBinMatchBIN in ('400057','400123','403486','403487','403488','403489','403490','403491','403492','403493','403494',
						'403495','403496','403497','403968','403976','404982','404984','405218','407120','408109','410072',
						'422394','422997','424621','425704','425852','425914','431196','431640','432522','435760','438968',
						'439882','443040','443041','443042','443043','443044','443045','443046','443047','443048','443049',
						'443050','443051','443057','443060','443061','443062','443063','443064','443065','443066','443067',
						'443068','443069','443070','443071','443072','443600','443601','443603','445463','448596','448900',
						'448901','448903','448904','448909','448910','448911','448915','448920','448921','448928','448929',
						'448930','448931','448940','448941','448943','448944','448950','448951','448960','448961','448970',
						'448971','448980','448991','450468','450469','450470','463158','463404','463829','469083','471515',
						'471595','472201','473135','474397','475598','477762','479162','480423','480433','480704','480720',
						'481790','485705','485706','485707','485977','486511','486563','486688','487889','491870','500674',
						'500675','500676','500677','502409','503227','503823','529004','537946','540940','541359','541493',
						'541872','543107','543767','545848','545849','548200','548201','548210','548211','548220','548221',
						'548228','548229','548230','548231','548240','548241','548250','548251','548260','548261','553308',
						'556364','556365','556366','560236','560466','560470','564386','574023','585131','585689','586282',
						'588882')
   and b.SettlementDate >= (select dt from #dates where varname = 'BOM3Start') 
   and b.SettlementDate <= (select dt from #dates where varname = 'BOM3End')
 group by b.ATMInternalID;
--22105

select count(*) from #pncb_bom_wt;
--62402

/* Sum rows over ATMInternalID where there were rows from multiple BOM queries for one ATM. */
IF OBJECT_ID('tempdb..#pncb_bom_wt_total', 'U') IS NOT NULL 
   drop table #pncb_bom_wt_total; 
select ATMInternalID, 
	   sum(n_WD) as n_WD, 
	   sum(WDAmt) as WDAmt
  into #pncb_bom_wt_total	   
  from #pncb_bom_wt
 group by ATMInternalID; 
 
select ATMInternalID 
  from #pncb_bom_wt_total
 group by ATMInternalID
having count(*) > 1;
--0

/* Calculate average dispense per withdrawal for BOM period. */

IF OBJECT_ID('tempdb..#pncb_bom_avg', 'U') IS NOT NULL 
   drop table #pncb_bom_avg; 
select ATMInternalID, 
       n_WD, 
	   WDAmt,
	   (cast(WDAmt as float) / cast(n_WD as float)) as AvgWDAmt
  into #pncb_bom_avg
  from (select *
          from #pncb_bom_wt_total
       )x;

select *
  from #pncb_bom_avg;

/***********************************************************************************************
Find Rest of Month $/WD average as it is lower than the beginning of the month. Need to use 
    dates that do not include the first week of the month.  
***********************************************************************************************/
/* Collect pncb Rest of Month (weeks not containing the 1st) withdrawal transactions. */
IF OBJECT_ID('tempdb..#pncb_rom_wt', 'U') IS NOT NULL 
   drop table #pncb_rom_wt; 
select b.ATMInternalID, 
	   sum(case when b.[txntypeid] = 1 then 1 else 0 end) as n_WD,
	   sum(case when b.[txntypeid] = 1 then amount else 0 end) as WDAmt
  into #pncb_rom_wt
  from [SSRSReports].[WebReportsUser].[KYC_CASH_PROJ_2023_Finance_Data] b
       inner join #terms1 x 
	   on b.ATMInternalID = x.ATMInternalID
 where APBinMatchBIN in ('400057','400123','403486','403487','403488','403489','403490','403491','403492','403493','403494',
						'403495','403496','403497','403968','403976','404982','404984','405218','407120','408109','410072',
						'422394','422997','424621','425704','425852','425914','431196','431640','432522','435760','438968',
						'439882','443040','443041','443042','443043','443044','443045','443046','443047','443048','443049',
						'443050','443051','443057','443060','443061','443062','443063','443064','443065','443066','443067',
						'443068','443069','443070','443071','443072','443600','443601','443603','445463','448596','448900',
						'448901','448903','448904','448909','448910','448911','448915','448920','448921','448928','448929',
						'448930','448931','448940','448941','448943','448944','448950','448951','448960','448961','448970',
						'448971','448980','448991','450468','450469','450470','463158','463404','463829','469083','471515',
						'471595','472201','473135','474397','475598','477762','479162','480423','480433','480704','480720',
						'481790','485705','485706','485707','485977','486511','486563','486688','487889','491870','500674',
						'500675','500676','500677','502409','503227','503823','529004','537946','540940','541359','541493',
						'541872','543107','543767','545848','545849','548200','548201','548210','548211','548220','548221',
						'548228','548229','548230','548231','548240','548241','548250','548251','548260','548261','553308',
						'556364','556365','556366','560236','560466','560470','564386','574023','585131','585689','586282',
						'588882')
   and b.SettlementDate >= (select dt from #dates where varname = 'ROMStart') 
   and b.SettlementDate <= (select dt from #dates where varname = 'ROMEnd')
 group by b.ATMInternalID;

 select ATMInternalID 
  from #pncb_rom_wt
 group by ATMInternalID
having count(*) > 1;
--0

select ATMInternalID, 
	   n_WD, 
	   WDAmt
  from #pncb_rom_wt
 order by ATMInternalID; 


/* Calculate total withdrawals and withdrawal amount by ATM, for tranactions in the period
   on active terminals. */

/* Calculate average withdrawal amount by ATM within this period. */
IF OBJECT_ID('tempdb..#pncb_rom_avg', 'U') IS NOT NULL 
   drop table #pncb_rom_avg; 
select ATMInternalID, 
       n_WD, 
	   WDAmt,
	   (cast(WDAmt as float) / cast(n_WD as float)) as AvgWDAmt
  into #pncb_rom_avg
  from (select *
          from #pncb_rom_wt
       )x;

select top 1000 *
  from #proj_n_wd;

select avg(AvgWDAmt)
  from #pncb_bom_avg;
--138.389006130286
  
select avg(AvgWDAmt)
  from #pncb_rom_avg; 
--134.217318686431

Insert into #BOM_ROM_List Select 'pncb',
	(select avg(AvgWDAmt)
		from #pncb_bom_avg),
	(select avg(AvgWDAmt)
		from #pncb_rom_avg);

select * from #BOM_ROM_List;

IF OBJECT_ID('SSRSReports.WebReportsUser.KYC_CASH_PROJ_#BOM_ROM_List', 'U') IS NOT NULL 
   drop table SSRSReports.WebReportsUser.KYC_CASH_PROJ_#BOM_ROM_List; 
select * 
  into SSRSReports.WebReportsUser.KYC_CASH_PROJ_#BOM_ROM_List
  from #BOM_ROM_List;
/* Project daily withdrawal amount by ATM by multiplying projected number of withdrawals by average 
   withdrawal amount over the three week period. */
   
/* **NOTE**: Update defaults for bom, rom from avg(AvgWDAmt) from bom, rom tables. 
             **Update a.WkNum list for BOM weeks in forecast period. 
*/

IF OBJECT_ID('tempdb..#proj_pncbank_fin', 'U') IS NOT NULL 
   drop table #proj_pncbank_fin; 
select a.*, 
       case when a.WkNum in (9,13,18,22,26,31,35,40,44,48) 
	        then 
			/* Some ATMs have BOM AvgWDAmt that are less than ROM. If so, use ROM all month. */
			     case when isnull(b.AvgWDAmt,(select BOM from #BOM_ROM_List where issuer = 'pncb') ) > isnull(r.AvgWDAmt,(select ROM from #BOM_ROM_List where issuer = 'pncb') ) 
				      then isnull(b.AvgWDAmt,(select BOM from #BOM_ROM_List where issuer = 'pncb') ) 
					  else isnull(r.AvgWDAmt,(select ROM from #BOM_ROM_List where issuer = 'pncb') )
				 end
            else isnull(r.AvgWDAmt,(select ROM from #BOM_ROM_List where issuer = 'pncb') )
       end as AvgWDAmt, 
	   case when a.WkNum in (9,13,18,22,26,31,35,40,44,48) 
	        then 
			     case when isnull(b.AvgWDAmt,(select BOM from #BOM_ROM_List where issuer = 'pncb') ) > isnull(r.AvgWDAmt,(select ROM from #BOM_ROM_List where issuer = 'pncb') ) 
				      then a.n_WD * isnull(b.AvgWDAmt,(select BOM from #BOM_ROM_List where issuer = 'pncb') ) 
					  else a.n_WD * isnull(r.AvgWDAmt,(select ROM from #BOM_ROM_List where issuer = 'pncb') )
				 end
            else a.n_WD * isnull(r.AvgWDAmt,(select ROM from #BOM_ROM_List where issuer = 'pncb') )
       end as WDAmt
  into #proj_pncbank_fin
  from #proj_n_wd a
       left join #pncb_rom_avg r 
	   on a.ATMInternalID = r.ATMInternalID
	   left join #pncb_bom_avg b
	   on a.ATMInternalID = b.ATMInternalID;



select ForecastDate, sum(n_WD) as n_WD, sum(WDAmt) as WDAmt
  from #proj_pncbank_fin
where ForecastDate is not null
 group by ForecastDate
 order by 1;
  
IF OBJECT_ID('SSRSReports.WebReportsUser.KYC_CASH_PROJ_#proj_pncbank_fin', 'U') IS NOT NULL 
   drop table SSRSReports.WebReportsUser.KYC_CASH_PROJ_#proj_pncbank_fin; 
select * 
  into SSRSReports.WebReportsUser.KYC_CASH_PROJ_#proj_pncbank_fin
  from #proj_pncbank_fin
--2977040

/* restore #proj_pncbank_fin

IF OBJECT_ID('tempdb..#proj_pncbank_fin', 'U') IS NOT NULL 
   drop table #proj_pncbank_fin; 
select * 
  into #proj_pncbank_fin
  from SSRSReports.WebReportsUser.KYC_CASH_PROJ_#proj_pncbank_fin;
--3030972
*/


select --SettlementDate, 
       count(*) as n_WD, 
	   sum(amount) as WDAmt, 
	   sum(amount)/count(*) as AvgWDAmt
  from SSRSReports.WebReportsUser.KYC_CASH_PROJ_2023_Finance_Data f
       inner join #terms1 t
	   on f.ATMInternalID = t.ATMInternalID
 where APBinMatchBIN in ('400057','400123','403486','403487','403488','403489','403490','403491','403492','403493','403494',
						'403495','403496','403497','403968','403976','404982','404984','405218','407120','408109','410072',
						'422394','422997','424621','425704','425852','425914','431196','431640','432522','435760','438968',
						'439882','443040','443041','443042','443043','443044','443045','443046','443047','443048','443049',
						'443050','443051','443057','443060','443061','443062','443063','443064','443065','443066','443067',
						'443068','443069','443070','443071','443072','443600','443601','443603','445463','448596','448900',
						'448901','448903','448904','448909','448910','448911','448915','448920','448921','448928','448929',
						'448930','448931','448940','448941','448943','448944','448950','448951','448960','448961','448970',
						'448971','448980','448991','450468','450469','450470','463158','463404','463829','469083','471515',
						'471595','472201','473135','474397','475598','477762','479162','480423','480433','480704','480720',
						'481790','485705','485706','485707','485977','486511','486563','486688','487889','491870','500674',
						'500675','500676','500677','502409','503227','503823','529004','537946','540940','541359','541493',
						'541872','543107','543767','545848','545849','548200','548201','548210','548211','548220','548221',
						'548228','548229','548230','548231','548240','548241','548250','548251','548260','548261','553308',
						'556364','556365','556366','560236','560466','560470','564386','574023','585131','585689','586282',
						'588882')
    and APBinMatch = 1
    and SettlementDate >= (select dt from #dates where varname = 'AllocStart')
	and SettlementDate <= (select dt from #dates where varname = 'AllocEnd');

/* Total across the allocation period for the entire BIN group. 
n_WD	WDAmt	AvgWDAmt
287497	37808420.00	131.5089
*/


/*************************************************************
Comerica Projection
*************************************************************/
--mark3

/* Pull date range for Comerica that spans historical data used to create projection. Sum transactions
   by ATM and settlement date. */
IF OBJECT_ID('tempdb..#comerica_act', 'U') IS NOT NULL 
   drop table #comerica_act; 
select t.ATMInternalID, 
       cast(t.SettlementDate as date) as SettlementDate, 
	   sum(case when t.txntypeid = 1 then 1 else 0 end) as n_WD, 
	   sum(amount) as WDAmt
  into #comerica_act
  from ATMManagerM_TW.dbo.T_TxnDetail as t WITH (NOLOCK)
       inner join #terms1 as b 
       on t.ATMInternalID = b.ATMInternalID 
 where t.SettlementDate >= (select dt from #dates where varname = 'ComericaStart')
   and t.SettlementDate <= (select dt from #dates where varname = 'ComericaEnd')
   and t.TxnTypeID = 1
   and t.ResponseCodeID = 1
   and t.Txn = 1
   and t.BankID in (533248, 511563)
   and t.ATMInternalID IN (select ATMInternalID from #terms1)  -- changes execution plan, much faster
 group by t.ATMInternalID, cast(t.SettlementDate as date);
--770771

/*updated Jun 29 2023*/
select top 10 * from #comerica_act;

IF OBJECT_ID('tempdb..#comerica_sche', 'U') IS NOT NULL 
   drop table #comerica_sche; 
select *
into #comerica_sche
from SSRSReports.WebReportsUser.KYC_CASH_PROJ_INP_ComHis;

select top 10 * from #comerica_sche;

IF OBJECT_ID('tempdb..#comerica_proj', 'U') IS NOT NULL 
   drop table #comerica_proj; 
select a.*,b.Forecast_Date as ForecastDate
into #comerica_proj
from #comerica_act a
right join #comerica_sche b
on a.SettlementDate = b.Actuals_from
order by ForecastDate;

select top 10 * from #comerica_proj;

update #comerica_proj
set WDAmt = WDAmt * 1.087
where year(SettlementDate) = 2022;

/* old method
IF OBJECT_ID('tempdb..#comerica_proj', 'U') IS NOT NULL 
   drop table #comerica_proj; 
select ATMinternalid,
       case	   	   	  	
		   when cast(SettlementDate as date)='2023-04-02' then cast('2023-07-02' as date)
		   when cast(SettlementDate as date)='2023-04-03' then cast('2023-07-03' as date)
		   when cast(SettlementDate as date)='2023-04-04' then cast('2023-07-04' as date)
		   when cast(SettlementDate as date)='2023-04-05' then cast('2023-07-05' as date)
	       when cast(SettlementDate as date)='2023-04-06' then cast('2023-07-06' as date)
		   when cast(SettlementDate as date)='2023-04-07' then cast('2023-07-07' as date)
		   when cast(SettlementDate as date)='2023-04-08' then cast('2023-07-08' as date)

		   when cast(SettlementDate as date)='2023-04-09' then cast('2023-07-09' as date)
		   when cast(SettlementDate as date)='2023-04-10' then cast('2023-07-10' as date)
		   when cast(SettlementDate as date)='2023-04-11' then cast('2023-07-11' as date)
		   when cast(SettlementDate as date)='2023-04-12' then cast('2023-07-12' as date)
		   when cast(SettlementDate as date)='2023-04-13' then cast('2023-07-13' as date)
		   when cast(SettlementDate as date)='2023-04-14' then cast('2023-07-14' as date)
		   when cast(SettlementDate as date)='2023-04-15' then cast('2023-07-15' as date)

	       when cast(SettlementDate as date)='2023-04-16' then cast('2023-07-16' as date)
		   when cast(SettlementDate as date)='2023-04-17' then cast('2023-07-17' as date)
		   when cast(SettlementDate as date)='2023-04-18' then cast('2023-07-18' as date)
           when cast(SettlementDate as date)='2023-04-19' then cast('2023-07-19' as date)
		   when cast(SettlementDate as date)='2023-04-20' then cast('2023-07-20' as date)
		   when cast(SettlementDate as date)='2023-04-21' then cast('2023-07-21' as date)
		   when cast(SettlementDate as date)='2023-04-22' then cast('2023-07-22' as date)

	       when cast(SettlementDate as date)='2023-04-23' then cast('2023-07-23' as date)
		   when cast(SettlementDate as date)='2023-04-24' then cast('2023-07-24' as date)
		   when cast(SettlementDate as date)='2023-04-25' then cast('2023-07-25' as date)
           when cast(SettlementDate as date)='2023-04-26' then cast('2023-07-26' as date)
		   when cast(SettlementDate as date)='2023-04-27' then cast('2023-07-27' as date)
		   when cast(SettlementDate as date)='2023-04-28' then cast('2023-07-28' as date)
		   when cast(SettlementDate as date)='2023-04-29' then cast('2023-07-29' as date)

		   when cast(SettlementDate as date)='2023-04-30' then cast('2023-07-30' as date)
           --when cast(SettlementDate as date)='2023-04-30' then cast('2023-07-31' as date)
		   when cast(SettlementDate as date)='2023-05-01' then cast('2023-08-01' as date)
		   when cast(SettlementDate as date)='2023-05-02' then cast('2023-08-02' as date)
		   when cast(SettlementDate as date)='2023-05-03' then cast('2023-08-03' as date)
		   when cast(SettlementDate as date)='2023-05-04' then cast('2023-08-04' as date)
		   when cast(SettlementDate as date)='2023-05-05' then cast('2023-08-05' as date)

	       when cast(SettlementDate as date)='2023-05-06' then cast('2023-08-06' as date)
		   when cast(SettlementDate as date)='2023-05-07' then cast('2023-08-07' as date)
		   when cast(SettlementDate as date)='2023-05-08' then cast('2023-08-08' as date)
		   when cast(SettlementDate as date)='2023-05-10' then cast('2023-08-09' as date)
		   when cast(SettlementDate as date)='2023-05-11' then cast('2023-08-10' as date)
		   when cast(SettlementDate as date)='2023-05-12' then cast('2023-08-11' as date)
		   when cast(SettlementDate as date)='2023-05-13' then cast('2023-08-12' as date)

		   when cast(SettlementDate as date)='2023-05-14' then cast('2023-08-13' as date)
		   when cast(SettlementDate as date)='2023-05-15' then cast('2023-08-14' as date)
		   when cast(SettlementDate as date)='2023-05-16' then cast('2023-08-15' as date)
	       when cast(SettlementDate as date)='2023-05-17' then cast('2023-08-16' as date)
		   when cast(SettlementDate as date)='2023-05-18' then cast('2023-08-17' as date)
		   when cast(SettlementDate as date)='2023-05-19' then cast('2023-08-18' as date)
           when cast(SettlementDate as date)='2023-05-20' then cast('2023-08-19' as date)

		   when cast(SettlementDate as date)='2023-05-21' then cast('2023-08-20' as date)
		   when cast(SettlementDate as date)='2023-05-22' then cast('2023-08-21' as date)
		   when cast(SettlementDate as date)='2023-05-23' then cast('2023-08-22' as date)
	       when cast(SettlementDate as date)='2023-05-24' then cast('2023-08-23' as date)
		   when cast(SettlementDate as date)='2023-05-25' then cast('2023-08-24' as date)
		   when cast(SettlementDate as date)='2023-05-26' then cast('2023-08-25' as date)
           when cast(SettlementDate as date)='2023-05-27' then cast('2023-08-26' as date)

		   when cast(SettlementDate as date)='2023-05-28' then cast('2023-08-27' as date)
		   when cast(SettlementDate as date)='2023-05-29' then cast('2023-08-28' as date)
		   when cast(SettlementDate as date)='2023-05-30' then cast('2023-08-29' as date)
           when cast(SettlementDate as date)='2023-05-31' then cast('2023-08-30' as date)
		   --when cast(SettlementDate as date)='2023-05-31' then cast('2023-08-31' as date)
		   when cast(SettlementDate as date)='2023-06-02' then cast('2023-09-01' as date)
		   when cast(SettlementDate as date)='2023-06-03' then cast('2023-09-02' as date)

		   when cast(SettlementDate as date)='2023-06-04' then cast('2023-09-03' as date)
		   when cast(SettlementDate as date)='2023-06-05' then cast('2023-09-04' as date)
	       when cast(SettlementDate as date)='2023-06-06' then cast('2023-09-05' as date)
		   when cast(SettlementDate as date)='2023-06-07' then cast('2023-09-06' as date)
		   when cast(SettlementDate as date)='2023-06-08' then cast('2023-09-07' as date)
		   when cast(SettlementDate as date)='2023-06-09' then cast('2023-09-08' as date)
		   when cast(SettlementDate as date)='2023-06-10' then cast('2023-09-09' as date)

		   when cast(SettlementDate as date)='2023-06-11' then cast('2023-09-10' as date)
		   when cast(SettlementDate as date)='2023-06-12' then cast('2023-09-11' as date)
		   when cast(SettlementDate as date)='2023-06-13' then cast('2023-09-12' as date)
		   when cast(SettlementDate as date)='2023-06-14' then cast('2023-09-13' as date)
		   when cast(SettlementDate as date)='2023-06-15' then cast('2023-09-14' as date)
	       when cast(SettlementDate as date)='2023-06-16' then cast('2023-09-15' as date)
		   when cast(SettlementDate as date)='2023-06-17' then cast('2023-09-16' as date)

		   when cast(SettlementDate as date)='2023-06-18' then cast('2023-09-17' as date)
           when cast(SettlementDate as date)='2023-06-19' then cast('2023-09-18' as date)
		   when cast(SettlementDate as date)='2023-06-20' then cast('2023-09-19' as date)
		   when cast(SettlementDate as date)='2023-06-21' then cast('2023-09-20' as date)
		   when cast(SettlementDate as date)='2023-06-22' then cast('2023-09-21' as date)
	       when cast(SettlementDate as date)='2023-06-23' then cast('2023-09-22' as date)
		   when cast(SettlementDate as date)='2023-06-24' then cast('2023-09-23' as date)


	   else null end as Forecastdate,

	   n_WD,
	   case when year(SettlementDate) = 2022 then WDAmt * 1.087
	        else WDAmt
	   end as WDAmt
  into #comerica_proj
  from #comerica_act;*/


/* Can't catch two instances of same date in one case statement, so get second one now. 
insert into #comerica_proj
select ATMinternalid,
       case 
		   when cast(SettlementDate as date)='2023-04-30' then cast('2023-07-31' as date)
		   when cast(SettlementDate as date)='2023-05-31' then cast('2023-08-31' as date)
           else null end as Forecastdate,
       n_WD,
	   case when year(SettlementDate) = 2022 then WDAmt * 1.087
	        else WDAmt
	   end as WDAmt
  from #comerica_act;*/

--update this only for this forecast

update #comerica_proj
set WDAmt = WDAmt*1.2,n_WD = n_WD*1.2
where (Forecastdate = '2023-09-01' or
Forecastdate =  '2023-09-02');

select count(*), Forecastdate,sum(n_WD),sum(WDAmt)
from #comerica_proj
group by Forecastdate
order by Forecastdate;


select Forecastdate,count(*) as count, sum(n_WD) as n_WD,sum(WDAmt) as WDAmt
from #comerica_proj
group by Forecastdate
order by Forecastdate;


/* Save only those rows that are part of the forecast. */
IF OBJECT_ID('tempdb..#comerica_proj_fin', 'U') IS NOT NULL 
   drop table #comerica_proj_fin; 
select ATMInternalID as ATMinternalid,ForecastDate,n_WD,WDAmt
  into #comerica_proj_fin
  from #comerica_proj
 where forecastdate is not null;
 
IF OBJECT_ID('SSRSReports.WebReportsUser.KYC_CASH_PROJ_#comerica_proj_fin', 'U') IS NOT NULL 
   drop table SSRSReports.WebReportsUser.KYC_CASH_PROJ_#comerica_proj_fin; 
select * 
  into SSRSReports.WebReportsUser.KYC_CASH_PROJ_#comerica_proj_fin
  from #comerica_proj_fin;

/* restore #comerica_proj_fin
IF OBJECT_ID('tempdb..#comerica_proj_fin', 'U') IS NOT NULL 
   drop table #comerica_proj_fin; 
select * 
  into #comerica_proj_fin
  from SSRSReports.WebReportsUser.KYC_CASH_PROJ_#comerica_proj_fin;
--746686
*/


select forecastdate, 
       sum(n_WD) as n_WD, 
	   Sum(WDAmt) as WDAmt
  from #comerica_proj_fin
 group by forecastdate
 order by forecastdate;

select forecastdate, 
       sum(n_WD) as n_WD, 
	   Sum(WDAmt) as WDAmt
  from SSRSReports.WebReportsUser.KYC_CASH_PROJ_#comerica_proj_fin
 group by forecastdate
 order by forecastdate;

/***************************************************************
combine baseline and incremental
***************************************************************/
/*restore base_date*/

IF OBJECT_ID('tempdb..#base_data','U') IS NULL
	select * 
	into #base_data
	from [SSRSReports].[WebReportsUser].[KYC_CASH_PROJ_BASELINE];

/*restore #proj_varo_fin*/

IF OBJECT_ID('tempdb..#proj_varo_fin','U') IS NULL
	select * 
	into #proj_varo_fin
	from [SSRSReports].[WebReportsUser].[KYC_CASH_PROJ_#proj_varo_fin];

/*restore #proj_usbank_fin*/

IF OBJECT_ID('tempdb..#proj_usbank_fin','U') IS NULL
	select * 
	into #proj_usbank_fin
	from [SSRSReports].[WebReportsUser].[KYC_CASH_PROJ_#proj_usbank_fin];

/*restore #proj_usbank_fin*/

IF OBJECT_ID('tempdb..#proj_payfare_fin','U') IS NULL
	select * 
	into #proj_payfare_fin
	from [SSRSReports].[WebReportsUser].[KYC_CASH_PROJ_#proj_payfare_fin];

/*restore #comerica_proj_fin*/

IF OBJECT_ID('tempdb..#comerica_proj_fin','U') IS NULL
	select * 
	into #comerica_proj_fin
	from [SSRSReports].[WebReportsUser].[KYC_CASH_PROJ_#comerica_proj_fin];

/*restore #proj_adp_fin*/

IF OBJECT_ID('tempdb..#proj_adp_fin','U') IS NULL
	select * 
	into #proj_adp_fin
	from [SSRSReports].[WebReportsUser].[KYC_CASH_PROJ_#proj_adp_fin];

/*restore #proj_cashapp_fin*/

IF OBJECT_ID('tempdb..#proj_cashapp_fin','U') IS NULL
	select * 
	into #proj_cashapp_fin
	from [SSRSReports].[WebReportsUser].[KYC_CASH_PROJ_#proj_cashapp_fin];

/*restore #proj_chime_fin*/

IF OBJECT_ID('tempdb..#proj_chime_fin','U') IS NULL
	select * 
	into #proj_chime_fin
	from [SSRSReports].[WebReportsUser].[KYC_CASH_PROJ_#proj_chime_fin];

/*restore #proj_mn_fin*/

IF OBJECT_ID('tempdb..#proj_mn_fin','U') IS NULL
	select * 
	into #proj_mn_fin
	from [SSRSReports].[WebReportsUser].[KYC_CASH_PROJ_#proj_mn_fin];

/*restore #proj_mn_fin*/

IF OBJECT_ID('tempdb..#proj_skylight_fin','U') IS NULL
	select * 
	into #proj_skylight_fin
	from [SSRSReports].[WebReportsUser].[KYC_CASH_PROJ_#proj_skylight_fin];

/*restore #proj_comdata_fin*/

IF OBJECT_ID('tempdb..#proj_comdata_fin','U') IS NULL
	select * 
	into #proj_comdata_fin
	from [SSRSReports].[WebReportsUser].[KYC_CASH_PROJ_#proj_comdata_fin];


/*restore #proj_pncbank_fin*/

IF OBJECT_ID('tempdb..#proj_pncbank_fin','U') IS NULL
	select * 
	into #proj_pncbank_fin
	from [SSRSReports].[WebReportsUser].[KYC_CASH_PROJ_#proj_pncbank_fin];


/* Add LMI indicator for each ATM. */
IF OBJECT_ID('tempdb..#atms_fin', 'U') IS NOT NULL 
   drop table #atms_fin; 
select * 
  into #atms_fin
  from SSRSReports.[WebReportsUser].[KYC_CASH_PROJ_TERMS1];

ALTER TABLE #atms_fin
ADD LMI integer;

UPDATE #atms_fin
   set LMI = b.LMI
  from #atms_fin as a
                  /* Create list of ATMs from #atms_fin with LMI indicator. */
       inner join (select a.ATMInternalID, 
	                      b.LMI
	                      /* Create list of ATM IDs from #atms_fin. */
                     from (select ATMInternalID
                             from #atms_fin
                          )a
			              left join SSRSReports.[WebReportsUser].[KYC_LMI_PROJ_LocationData] l
			              on cast(a.ATMInternalID as char) = l.ATMInternalID 
			              and l.Type in ('CATM-Non-MS', 'CATM-MS-Other')
			              left join [SSRSReports].[WebReportsUser].[KYC_LMI_PROJ_PUMA_CT_ALL_MAP] b
			              on cast(l.Tract_FIPS_CODE as bigint) = cast(b.Tract_FIPS_CODE as bigint)
                  ) as b
       on a.ATMInternalID = b.ATMInternalID;



select LMI, count(*) as n_rec
  from #atms_fin
 group by LMI;

create index tmpAP3 on #atms_fin (ATMInternalID);


/* Create shell : all ATMs for all dates. */

/* Get all BIN groups forecasted in spreadsheet. */
IF OBJECT_ID('tempdb..#fcst', 'U') IS NOT NULL 
   drop table #fcst; 
select cast(FcstDate as date) as ForecastDate
  into #fcst
  from [SSRSReports].[WebReportsUser].[KYC_CASH_PROJ_INP]
 group by cast(FcstDate as date)
 order by 1;

/* Add week number and day of week to forecast data. */
IF OBJECT_ID('tempdb..#fcst_dates', 'U') IS NOT NULL 
   drop table #fcst_dates; 
select b.*,  
       DATEPART(wk, b.ForecastDate) as Wk, 
	   DATEPART(dw, b.ForecastDate) as WkDay
  into #fcst_dates
  from #fcst b;

/* Cross join forecast data (dates and forecast daily total amounts) with list of terminals in #terms1 and 
   store result in #shell. */
IF OBJECT_ID('tempdb..#shell', 'U') IS NOT NULL 
   drop table #shell; 
select a.ATMInternalID, 
       b.ForecastDate, 
	   b.Wk, 
	   b.WkDay
  into #shell
  from (select distinct ATMInternalID
          from SSRSReports.WebReportsUser.KYC_CASH_PROJ_TERMS1
       )a
       cross join #fcst_dates b;


/* Add ATM level to #shell; new forecasts for BIN groups, historical data (BaselineStart to 
   BaselineEnd) for Baseline. */
IF OBJECT_ID('tempdb..#all_fcst', 'U') IS NOT NULL 
   drop table #all_fcst; 
select a.*, 
	
	   cast(isnull(base.n_WD_Baseline,0) as float) as n_WD_Baseline,
	   cast(isnull(base.WDAmt_Baseline,0) as float) as WDAmt_Baseline,

	   cast(isnull(com.n_WD,0) as float) as n_WD_Comerica,
	   cast(isnull(com.WDAmt,0) as float) as WDAmt_Comerica,

       cast(isnull(var.n_WD,0) as float) as n_WD_Varo,
	   cast(isnull(var.WDAmt,0) as float) as WDAmt_Varo,

       cast(isnull(usb.n_WD,0) as float) as n_WD_USBank,
	   cast(isnull(usb.WDAmt,0) as float) as WDAmt_USBank,

	   cast(isnull(payfare.n_WD,0) as float) as n_WD_Payfare,
	   cast(isnull(payfare.WDAmt,0) as float) as WDAmt_Payfare,

	   cast(isnull(mn.n_WD,0) as float) as n_WD_MN,
	   cast(isnull(mn.WDAmt,0) as float) as WDAmt_MN,
	   
	   cast(isnull(sky.n_WD,0) as float) as n_WD_Sky, 
	   cast(isnull(sky.WDAmt,0) as float) as WDAmt_Sky,
	   
	   cast(isnull(cashapp.n_WD,0) as float) as n_WD_CashApp, 
	   cast(isnull(cashapp.WDAmt,0) as float) as WDAmt_CashApp,
	   
	   cast(isnull(adp.n_WD,0) as float) as n_WD_ADP, 
	   cast(isnull(adp.WDAmt,0) as float) as WDAmt_ADP,
	   
	   cast(isnull(comdata.n_WD,0) as float) as n_WD_Comdata, 
	   cast(isnull(comdata.WDAmt,0) as float) as WDAmt_Comdata,
	   
	   cast(isnull(chime.n_WD,0) as float) as n_WD_Chime, 
	   cast(isnull(chime.WDAmt,0) as float) as WDAmt_Chime,

	   cast(isnull(pncb.n_WD,0) as float) as n_WD_PNCBank, 
	   cast(isnull(pncb.WDAmt,0) as float) as WDAmt_PNCBank
	   
  into #all_fcst
  from #shell a

       left join #base_data base 
	   on a.ATMInternalID = base.ATMInternalID 
	       and cast(a.ForecastDate as date) = cast(base.ForecastDate as date)

       left join #comerica_proj_fin com 
	   on a.ATMInternalID = com.ATMInternalID 
	       and cast(a.ForecastDate as date) = cast(com.ForecastDate as date)

       left join #proj_varo_fin var 
	   on a.ATMInternalID = var.ATMInternalID 
	       and cast(a.ForecastDate as date) = cast(var.ForecastDate as date)

       left join #proj_usbank_fin usb 
	   on a.ATMInternalID = usb.ATMInternalID 
	       and cast(a.ForecastDate as date) = cast(usb.ForecastDate as date)

       left join #proj_payfare_fin payfare 
	   on a.ATMInternalID = payfare.ATMInternalID 
	       and cast(a.ForecastDate as date) = cast(payfare.ForecastDate as date)

       left join #proj_mn_fin mn 
	   on a.ATMInternalID = mn.ATMInternalID 
	       and cast(a.ForecastDate as date) = cast(mn.ForecastDate as date)
		   
	   left join #proj_skylight_fin sky
	   on a.ATMInternalID = sky.ATMInternalID 
	       and cast(a.ForecastDate as date) = cast(sky.ForecastDate as date)

	   left join #proj_cashapp_fin cashapp
	   on a.ATMInternalID = cashapp.ATMInternalID 
	       and cast(a.ForecastDate as date) = cast(cashapp.ForecastDate as date)

	   left join #proj_adp_fin adp
	   on a.ATMInternalID = adp.ATMInternalID 
	       and cast(a.ForecastDate as date) = cast(adp.ForecastDate as date)

	   left join #proj_comdata_fin comdata
	   on a.ATMInternalID = comdata.ATMInternalID 
	       and cast(a.ForecastDate as date) = cast(comdata.ForecastDate as date)
		 
	   left join #proj_chime_fin chime
	   on a.ATMInternalID = chime.ATMInternalID 
	   and cast(a.ForecastDate as date) = cast(chime.ForecastDate as date)
	   
	   left join #proj_pncbank_fin pncb
	   on a.ATMInternalID = pncb.ATMInternalID 
	   and cast(a.ForecastDate as date) = cast(pncb.ForecastDate as date);
		   
		   
create index tmpAP4 on #all_fcst (ATMInternalID);
create index tmpAP5 on #all_fcst (ForecastDate);


/*select top(10) *
from #all_fcst;*/

/* Reverse the sign on any negative Baseline forecasts. These are typically from reversals. */
update #all_fcst
   set WDAmt_Baseline = WDAmt_Baseline * -1.0
 where WDAmt_Baseline < 0;
 --0 rows updated, done already, before extending baseline 

select *
  from #all_fcst 
 where n_WD_MN is null or WDAmt_MN is null or n_WD_MN < 0 or WDAmt_MN < 0
    or n_WD_Comerica is null or WDAmt_Comerica is null or n_WD_Comerica < 0 or WDAmt_Comerica < 0
	or n_WD_Varo is null or WDAmt_Varo is null or n_WD_Varo < 0 or WDAmt_Varo < 0
	or n_WD_USBank is null or WDAmt_USBank is null or n_WD_USBank < 0 or WDAmt_USBank < 0
	or n_WD_Payfare is null or WDAmt_Payfare is null or n_WD_Payfare < 0 or WDAmt_Payfare < 0
	or n_WD_Sky is null or WDAmt_Sky is null or n_WD_Sky < 0 or WDAmt_Sky < 0
	or n_WD_CashApp is null or WDAmt_CashApp is null or n_WD_CashApp < 0 or WDAmt_CashApp < 0
    or n_WD_ADP is null or WDAmt_ADP is null or n_WD_ADP < 0 or WDAmt_ADP < 0
	or n_WD_Comdata is null or WDAmt_Comdata is null or n_WD_Comdata < 0 or WDAmt_Comdata < 0
	or n_WD_Chime is null or WDAmt_Chime is null or n_WD_Chime < 0 or WDAmt_Chime < 0
	or n_WD_PNCBank is null or WDAmt_PNCBank is null or n_WD_PNCBank < 0 or WDAmt_PNCBank < 0;
--0 rows => some Comerica reversals w negative WDAmt

/* Calculate total projected withdrawals and withdrawal amount and round them to the nearest integer. 
   Wonder how this compares to our baseline total for corresponding day? Should be same for ATMs with 
   no transactions in 10 BIN groups we pulled out. */
IF OBJECT_ID('tempdb..#all_fcst1', 'U') IS NOT NULL 
   drop table #all_fcst1; 
select x.*,
	   round(x.n_WD_Proj,0) as n_WD_Proj_Fin,
	   round(x.WDAmt_Proj,0) as WDAmt_Proj_Fin
  into #all_fcst1
  from (select a.*, 
               a.n_WD_Baseline + a.n_WD_Comerica + a.n_WD_Varo + a.n_WD_USBank + a.n_WD_Payfare + a.n_WD_MN
			   + a.n_WD_Sky + a.n_WD_CashApp + a.n_WD_ADP + a.n_WD_Comdata + a.n_WD_Chime +a.n_WD_PNCBank as n_WD_Proj,
			   
	           a.WDAmt_Baseline + a.WDAmt_Comerica + a.WDAmt_Varo + a.WDAmt_USBank + a.WDAmt_Payfare + a.WDAmt_MN
			   + a.WDAmt_Sky + a.WDAmt_CashApp + a.WDAmt_ADP + a.WDAmt_Comdata + a.WDAmt_Chime +a.WDAmt_PNCBank as WDAmt_Proj

          from #all_fcst a
       )x;

create index tmpAP4 on #all_fcst1 (ATMInternalID);
create index tmpAP5 on #all_fcst1 (ForecastDate);

select ForecastDate, 
       sum(WDAmt_Baseline) as WDAmt_Baseline, 
	   sum(WDAmt_Comerica) as WDAmt_Comerica, 
	   sum(WDAmt_Varo) as WDAmt_Varo, 
       sum(WDAmt_USBank) as WDAmt_USBank, 
	   sum(WDAmt_Payfare) as WDAmt_Payfare, 
	   sum(WDAmt_MN) as WDAmt_MN, 
	   sum(WDAmt_Sky) as WDAmt_Sky, 
	   sum(WDAmt_CashApp) as WDAmt_CashApp, 
	   sum(WDAmt_ADP) as WDAmt_ADP, 
	   sum(WDAmt_Comdata) as WDAmt_Comdata,  
	   sum(WDAmt_Chime) as WDAmt_Chime,
	   sum(WDAmt_PNCBank) as WDAmt_PNCBank,
       sum(WDAmt_Proj) as WDAmt_Proj, 
	   sum(WDAmt_Proj_Fin) as WDAmt_Proj_Fin
  from #all_fcst1 f
       left join ATMManagerM.dbo.ATM a
	   on f.ATMInternalID = a.ATMInternalID
 where a.Arrangement in ('TURNKEY', 'CASHASSIST', 'MERCHANT FUNDED')
 group by ForecastDate
 order by 1;

select ForecastDate, 
	   sum(n_WD_Baseline) as n_WD_Baseline, 
	   sum(n_WD_Comerica) as n_WD_Comerica, 
	   sum(n_WD_Varo) as n_WD_Varo, 
	   sum(n_WD_USBank) as n_WD_USBank, 
	   sum(n_WD_Payfare) as n_WD_Payfare, 
	   sum(n_WD_MN) as n_WD_MN, 
	   sum(n_WD_Sky) as n_WD_Sky, 
	   sum(n_WD_CashApp) as n_WD_CashApp,
	   sum(n_WD_ADP) as n_WD_ADP,
	   sum(n_WD_Comdata) as n_WD_Comdata,
	   sum(n_WD_Chime) as n_WD_Chime,
	   sum(n_WD_PNCBank) as n_WD_PNCBank,
	   sum(n_WD_Proj) as n_WD_Proj, 
	   sum(n_WD_Proj_Fin) as n_WD_Proj_Fin
  from #all_fcst1 f
       left join ATMManagerM.dbo.ATM a
	   on f.ATMInternalID = a.ATMInternalID
 where a.Arrangement in ('TURNKEY', 'CASHASSIST', 'MERCHANT FUNDED')
 group by ForecastDate
 order by 1;
 

/* Save forecast before imputation. */
IF OBJECT_ID('[SSRSReports].[WebReportsUser].[KYC_CASH_PROJ_ALL_FCST1]','U') IS NOT NULL
    drop table [SSRSReports].[WebReportsUser].[KYC_CASH_PROJ_ALL_FCST1]
select * 
    into [SSRSReports].[WebReportsUser].[KYC_CASH_PROJ_ALL_FCST1]
	from #all_fcst1
	where ForecastDate is not null;


/* Restore data to #all_fcst1 from [SSRSReports].[WebReportsUser].[KYC_CASH_PROJ_ALL_FCST1] 
IF OBJECT_ID('tempdb..#all_fcst1','U') IS NOT NULL
    drop table #all_fcst1
select * 
    into #all_fcst1
	from [SSRSReports].[WebReportsUser].[KYC_CASH_PROJ_ALL_FCST1];
*/

/********************************************************************************************
Save forecast before imputation to compare with afterward
********************************************************************************************/
IF OBJECT_ID('tempdb..#before_impute','U') IS NOT NULL
    drop table #before_impute
select ForecastDate, 
       sum(n_WD_Proj_Fin) as totWD, 
	   sum(WDAmt_Proj_Fin) as totWDAmt
  into #before_impute
  from #all_fcst1
 group by ForecastDate;

/* This calculation is done in monthly satefy stock report:
	Calculate average historical daily volumes by ATM and day of week to impute zero and low 
   values. Low values are often due to site or hardware issues or out of cash for part of a day. 
   Averages are calculated by day of week to capture weekly seasonality and availability 
   differences (e.g., some may be closed on weekends if in an office building). 
   ATMs that are transacting daily will have 26 n_txns/day of week in the 6 month period
   used to calculate averages. */
-- update Jun 13:


IF OBJECT_ID('tempdb..#atm_historical_avgs','U') IS NOT NULL
    drop table #atm_historical_avgs
select * 
into #atm_historical_avgs
from SSRSReports.WebReportsUser.KYC_CASH_PROJ_ATM_AVGS;

select top 10 * from SSRSReports.WebReportsUser.KYC_CASH_PROJ_ATM_AVGS
order by ATMInternalID,DayOfWeek;



/******************************************************************************************************
Impute missing data with average values. Only impute where ATM has transactions on 75% of availaiibility (s) for 
that day of week in the last 26 weeks to avoid creating a high volume forecast for a low volume 
transaction ATM. 

1/21/21  Added NULLIF to avoid outages reducing average values by including zeros. 
3/24/21  Added NULLIF to WDAmt. Had previously only been on n_WD. 	
3/29/21  Modified to use day of week average and check limit so don't change a sporadic withdrawal
         ATM into a daily withdrawal ATM through imputing "missing" data.  
		 
		 
Should we be using 6 month averages? Look at ATMInternalID 155297, looks like downward trend in usage, 
     6 month average gives it a high forecast. 
******************************************************************************************************/

/* Check for missing data and impute with averages. */


/* Check for ATMs with zero projected withdrawals. We have already weeded out closed ATMs, 
   so these most likely had extended outages during the baseline time period. Impute their
   forecast from 6 months of historical patterns. */

select f.ATMInternalID, 
       Status, 
	   AUDFD1, 
	   DateInstalled, 
	   DateDeinstalled, 
       sum(n_WD_Proj_Fin) as totWD, 
	   sum(WDAmt_Proj_Fin) as totAmt
  from #all_fcst1 f
       left join ATMManagerM.dbo.ATM a
	   on f.ATMInternalID = a.ATMInternalID
 group by f.ATMInternalID, Status, AUDFD1, DateInstalled, DateDeinstalled
having sum(n_WD_Proj_Fin) = 0 or sum(WDAmt_Proj_Fin) = 0
 order by Status, AUDFD1;
/*  18 ATMs have no projected withdrawals. 
        This number is much lower since we excluded terminals that are deinstalled during baseline period.  
		Most are active, last transaction during baseline period. */

/* First, check for zeros. */
select a.ATMInternalID, 
       a.ForecastDate, 
	   datepart(weekday, a.ForecastDate) as DayOfWeek,
       a.n_WD_Proj_Fin, 
       h.avg_daily_n_wd, 
	   a.WDAmt_Proj_Fin, 
       h.avg_daily_wdamt,
	   h.avg_daily_availability
  from #all_fcst1 a
       left join #atm_historical_avgs h
		on a.ATMInternalID = h.ATMInternalID
		and datepart(weekday, a.ForecastDate) = h.DayOfWeek
  where a.n_WD_Proj_Fin = 0 or a.WDAmt_Proj_Fin = 0
  order by a.ATMInternalID, datepart(weekday, ForecastDate), ForecastDate;
--381478 rows with zeros out of 4455530, 8.6%. Some are the above ATMs with no projected withdrawals. 

select count(*) from #all_fcst1;
--4406892
--
/* Update n_WD to the average daily value for that ATM for that day of week IF n_WD is < 35% of that average daily
      value AND the ATM has availiability more than 75%. 
	  This will avoid adding activity on a day the ATM is closed to business and foreasting daily activity 
	  for an ATM with sporadic withdrawals. 
   Also update the n_WD_Baseline for the Summary worksheet in the forecast spreadsheet. 
   06/01/23 take holiday seasons, tax seasons out, now 3 mths history*/
UPDATE #all_fcst1
   SET n_WD_Proj_Fin = h.avg_daily_n_wd, 
       n_WD_Baseline = cast(round((h.avg_daily_n_wd 
                       - a.n_WD_Comerica - a.n_WD_Varo - a.n_WD_USBank - a.n_WD_Payfare - a.n_WD_MN
			           - a.n_WD_Sky - a.n_WD_CashApp - a.n_WD_ADP - a.n_WD_Comdata - a.n_WD_Chime - a.n_WD_PNCBank),0) as int)
  from #all_fcst1 a
       inner join #atm_historical_avgs h
		on a.ATMInternalID = h.ATMInternalID
		and datepart(weekday, a.ForecastDate) = h.DayOfWeek
  where a.n_WD_Proj_Fin < 0.35*h.avg_daily_n_wd
    and h.avg_daily_availability >= 0.75;
-- (308202 rows affected) 

/* Update n_WD to the average daily value for that ATM for that day of week IF n_WD is >150% of that average daily
      value AND the ATM has availiability more than 75%. 
	  This will avoid adding activity on a day the ATM is closed to business and foreasting daily activity 
	  for an ATM with sporadic withdrawals. 
   Also update the n_WD_Baseline for the Summary worksheet in the forecast spreadsheet. 
-- 06/01/23 take holiday seasons, tax seasons out, now 3 mths history*/
UPDATE #all_fcst1
   SET n_WD_Proj_Fin = h.avg_daily_n_wd, 
       n_WD_Baseline = cast(round((h.avg_daily_n_wd 
                       - a.n_WD_Comerica - a.n_WD_Varo - a.n_WD_USBank - a.n_WD_Payfare - a.n_WD_MN
			           - a.n_WD_Sky - a.n_WD_CashApp - a.n_WD_ADP - a.n_WD_Comdata - a.n_WD_Chime - a.n_WD_PNCBank),0) as int)
  from #all_fcst1 a
       inner join #atm_historical_avgs h
		on a.ATMInternalID = h.ATMInternalID
		and datepart(weekday, a.ForecastDate) = h.DayOfWeek
  where a.n_WD_Proj_Fin > 1.5*h.avg_daily_n_wd
    and h.avg_daily_availability >= 0.75;
-- (435615 rows affected) 


/* Update WDAmt to the average daily value for that ATM for that day of week IF WDAmt is < 35% of that average daily
      value AND the ATM has txns on that day of week at least 20 times in the last 6 month period (almost 77%). 
   Also update the WDAmt_Baseline value for reporting in the Summary worksheet of the forecast spreadsheet. */
UPDATE #all_fcst1
   SET WDAmt_Proj_Fin = h.avg_daily_wdamt, 
   	   WDAmt_Baseline = cast(round((h.avg_daily_wdamt
                        - a.WDAmt_Comerica - a.WDAmt_Varo - a.WDAmt_USBank - a.WDAmt_Payfare - a.WDAmt_MN
			            - a.WDAmt_Sky - a.WDAmt_CashApp - a.WDAmt_ADP - a.WDAmt_Comdata - a.WDAmt_Chime - a.WDAmt_PNCBank),0) as int)
  from #all_fcst1 a
       inner join #atm_historical_avgs h 
		on a.ATMInternalID = h.ATMInternalID
		and datepart(weekday, a.ForecastDate) = h.DayOfWeek
  where a.WDAmt_Proj_Fin < 0.35*h.avg_daily_wdamt
    and h.avg_daily_availability >= 0.75;
--(377494 rows affected)

/* Update WDAmt to the average daily value for that ATM for that day of week IF WDAmt is > 150% of that average daily
      value AND the ATM has availability more than 75%. 
   Also update the WDAmt_Baseline value for reporting in the Summary worksheet of the forecast spreadsheet. */
UPDATE #all_fcst1
   SET WDAmt_Proj_Fin = h.avg_daily_wdamt, 
   	   WDAmt_Baseline = cast(round((h.avg_daily_wdamt
                        - a.WDAmt_Comerica - a.WDAmt_Varo - a.WDAmt_USBank - a.WDAmt_Payfare - a.WDAmt_MN
			            - a.WDAmt_Sky - a.WDAmt_CashApp - a.WDAmt_ADP - a.WDAmt_Comdata - a.WDAmt_Chime - a.WDAmt_PNCBank),0) as int)
  from #all_fcst1 a
       inner join #atm_historical_avgs h 
		on a.ATMInternalID = h.ATMInternalID
		and datepart(weekday, a.ForecastDate) = h.DayOfWeek
  where a.WDAmt_Proj_Fin >1.5*h.avg_daily_wdamt
    and h.avg_daily_availability >= 0.75;
--(530737 rows affected)

/* Check for zeros again. */
select a.ATMInternalID, 
       a.ForecastDate, 
	   datepart(weekday, a.ForecastDate) as DayOfWeek,
       a.n_WD_Proj_Fin, 
       h.avg_daily_n_wd, 
	   a.WDAmt_Proj_Fin, 
       h.avg_daily_wdamt, 
	   h.avg_daily_availability
  from #all_fcst1 a
       left join #atm_historical_avgs h
		on a.ATMInternalID = h.ATMInternalID
		and datepart(weekday, a.ForecastDate) = h.DayOfWeek
  where a.n_WD_Proj_Fin = 0 or a.WDAmt_Proj_Fin = 0
  order by a.ATMInternalID, datepart(weekday, ForecastDate), ForecastDate;
--250429

/* 3 of the (18) ATMs with zero forecast had enough activity
       to impute a forecast. */
select count(*)
  from (select ATMInternalID
          from #all_fcst1
         group by ATMInternalID
        having sum(isnull(n_WD_Proj_Fin,0)) = 0 or sum(isnull(WDAmt_Proj_Fin,0)) = 0) a;
--15

/********************************************************************************************
Save forecast after imputation to compare with beforehand
********************************************************************************************/
IF OBJECT_ID('tempdb..#after_impute','U') IS NOT NULL
    drop table #after_impute;
select ForecastDate, 
       sum(n_WD_Proj_Fin) as totWD, 
	   sum(WDAmt_Proj_Fin) as totWDAmt
  into #after_impute
  from #all_fcst1
 group by ForecastDate;  

/* How much did imputation change forecast? */

select b.ForecastDate, 
       a.totWD - b.totWD as Delta_n_WD, 
	   a.totWDAmt - b.totWDAmt as Delta_WDAmt
  from #before_impute b
       inner join #after_impute a
	   on b.ForecastDate = a.ForecastDate
 order by ForecastDate;

/* List of ATMs with higher/lower totals after imputation by descending amount of difference. */
select a.ATMInternalID,  
       sum(b.n_WD_Proj_Fin) as n_wd_before, 
	   sum(a.n_WD_Proj_Fin) as n_wd_after, 
       sum(b.WDAmt_Proj_Fin) as wdamt_before,
	   sum(a.WDAmt_Proj_Fin) as wdamt_after, 
	   sum(a.WDAmt_Proj_Fin) - sum(b.WDAmt_Proj_Fin) as wdamt_diff
	   --(sum(a.WDAmt_Proj_Fin) - sum(b.WDAmt_Proj_Fin))/sum(b.WDAmt_Proj_Fin) as wdamt_pctdiff
  from #all_fcst1 a
       inner join [SSRSReports].[WebReportsUser].[KYC_CASH_PROJ_ALL_FCST1]  b
	   on a.ATMInternalID = b.ATMInternalID
	   and a.ForecastDate = b.ForecastDate
	   inner join ATMManagerM.dbo.ATM m
	   on a.ATMInternalID = m.ATMInternalID
 where m.Arrangement in ('CASHASSIST', 'TURNKEY', 'MERCHANT FUNDED')
 group by a.ATMInternalID
having sum(a.WDAmt_Proj_Fin) - sum(b.WDAmt_Proj_Fin) <> 0
 order by 6 desc;
--42286

-- check ATM avg WDAmt for ATM with high difference
select *
from #atm_historical_avgs
where ATMInternalID = 130299;

/* List of ATMs with over 100% increase from imputation */
select a.ATMInternalID,  
       sum(b.n_WD_Proj_Fin) as n_wd_before, 
	   sum(a.n_WD_Proj_Fin) as n_wd_after, 
       sum(b.WDAmt_Proj_Fin) as wdamt_before,
	   sum(a.WDAmt_Proj_Fin) as wdamt_after, 
	   sum(a.WDAmt_Proj_Fin) - sum(b.WDAmt_Proj_Fin) as wdamt_diff, 
	   round((sum(a.WDAmt_Proj_Fin) - sum(b.WDAmt_Proj_Fin))*100/sum(b.WDAmt_Proj_Fin),0) as wdamt_pctdiff
  from #all_fcst1 a
       inner join [SSRSReports].[WebReportsUser].[KYC_CASH_PROJ_ALL_FCST1]  b
	   on a.ATMInternalID = b.ATMInternalID
	   and a.ForecastDate = b.ForecastDate
	   inner join ATMManagerM.dbo.ATM m
	   on a.ATMInternalID = m.ATMInternalID
 where m.Arrangement in ('CASHASSIST', 'TURNKEY', 'MERCHANT FUNDED')
 group by a.ATMInternalID
having round((sum(a.WDAmt_Proj_Fin) - sum(b.WDAmt_Proj_Fin))*100/(sum(b.WDAmt_Proj_Fin)+1),0) > 100
 order by 7 desc;

--Most of those checked had a large gap in activity during baseline period. Some have resumed higher
--    activity but some have not. 

/* Compare individual ATM forecasts before/after imputation */
select b.ForecastDate, 
       h.DayOfWeek, 
	   h.avg_daily_availability, 
       b.n_WD_Proj_Fin as n_wd_before,
	   a.n_WD_Proj_Fin as n_wd_after, 
	   h.avg_daily_n_wd, 
	   b.WDAmt_Proj_Fin as wdamt_before, 
	   a.WDAmt_Proj_Fin as wdamt_after, 
	   h.avg_daily_wdamt
  from #all_fcst1 a
       inner join [SSRSReports].[WebReportsUser].[KYC_CASH_PROJ_ALL_FCST1]  b
	   on a.ATMInternalID = b.ATMInternalID
	   and a.ForecastDate = b.ForecastDate
	   left join #atm_historical_avgs h
		on a.ATMInternalID = h.ATMInternalID
		and datepart(weekday, a.ForecastDate) = h.DayOfWeek
 where b.ATMInternalID = 317508
 order by b.ForecastDate;  
 
/******************************************************************************************
Modify projection for high error terminals 
******************************************************************************************/
/*Before

select ATMInternalID,ForecastDate,
	sum(n_WD_Baseline) as Baseline, 
	   sum(n_WD_Comerica) as Comerica, 
	   sum(n_WD_Varo) as Varo, 
	   sum(n_WD_USBank) as USBank, 
	   sum(n_WD_Sky) as Sky, 
	   sum(n_WD_MN) as MN, 
	   sum(n_WD_Payfare) as Payfare, 
	   sum(n_WD_CashApp) as CashApp, 
	   sum(n_WD_ADP) as ADP, 
	   sum(n_WD_Comdata) as Comdata, 
	   sum(n_WD_Chime) as Chime,
	   sum(n_WD_PNCBank) as PNCBank
from #all_fcst1
where ATMInternalID = '9083'
group by ATMInternalID,ForecastDate;

UPDATE a
	SET a.n_WD_Baseline = a.n_WD_Baseline+b.Mutiplier*a.n_WD_Baseline,
	a.WDAmt_Baseline = a.WDAmt_Baseline+b.Mutiplier*a.WDAmt_Baseline,
	a.n_WD_Comerica = a.n_WD_Comerica+b.Mutiplier*a.n_WD_Comerica,
	a.WDAmt_Comerica = a.WDAmt_Comerica+b.Mutiplier*a.WDAmt_Comerica,
	a.n_WD_Varo = a.n_WD_Varo+b.Mutiplier*a.n_WD_Varo,
	a.WDAmt_Varo = a.WDAmt_Varo+b.Mutiplier*a.WDAmt_Varo,
	a.n_WD_USBank = a.n_WD_USBank+b.Mutiplier*a.n_WD_USBank,
	a.WDAmt_USBank = a.WDAmt_USBank+b.Mutiplier*a.WDAmt_USBank,
	a.n_WD_Payfare = a.n_WD_Payfare+b.Mutiplier*a.n_WD_Payfare,
	a.WDAmt_Payfare = a.WDAmt_Payfare+b.Mutiplier*a.WDAmt_Payfare,
	a.n_WD_MN = a.n_WD_MN+b.Mutiplier*a.n_WD_MN,
	a.WDAmt_MN = a.WDAmt_MN+b.Mutiplier*a.WDAmt_MN,
	a.n_WD_Sky = a.n_WD_Sky+b.Mutiplier*a.n_WD_Sky,
	a.WDAmt_Sky = a.WDAmt_Sky+b.Mutiplier*a.WDAmt_Sky,
	a.n_WD_CashApp = a.n_WD_CashApp+b.Mutiplier*a.n_WD_CashApp,
	a.WDAmt_CashApp = a.WDAmt_CashApp+b.Mutiplier*a.WDAmt_CashApp,
	a.n_WD_ADP = a.n_WD_ADP+b.Mutiplier*a.n_WD_ADP,
	a.WDAmt_ADP = a.WDAmt_ADP+b.Mutiplier*a.WDAmt_ADP,
	a.n_WD_Comdata= a.n_WD_Comdata+b.Mutiplier*a.n_WD_Comdata,
	a.WDAmt_Comdata = a.WDAmt_Comdata+b.Mutiplier*a.WDAmt_Comdata,
	a.n_WD_Chime = a.n_WD_Chime+b.Mutiplier*a.n_WD_Chime,
	a.WDAmt_Chime = a.WDAmt_Chime+b.Mutiplier*a.WDAmt_Chime,
	a.n_WD_PNCBank = a.n_WD_PNCBank+b.Mutiplier*a.n_WD_PNCBank,
	a.WDAmt_PNCBank = a.WDAmt_PNCBank+b.Mutiplier*a.WDAmt_PNCBank,
	a.n_WD_Proj = a.n_WD_Proj+b.Mutiplier*a.n_WD_Proj,
	a.WDAmt_Proj = a.WDAmt_Proj+b.Mutiplier*a.WDAmt_Proj,
	a.n_WD_Proj_Fin= a.n_WD_Proj_Fin+b.Mutiplier*a.n_WD_Proj_Fin,
	a.WDAmt_Proj_Fin = a.WDAmt_Proj_Fin+b.Mutiplier*a.WDAmt_Proj_Fin
		
	FROM #all_fcst1 a
	inner join [SSRSReports].[WebReportsUser].[Urgent_Action] b
	on a.ATMInternalID = b.ATMInternalID;

/*After*/
select ATMInternalID,ForecastDate,
	sum(n_WD_Baseline) as Baseline, 
	   sum(n_WD_Comerica) as Comerica, 
	   sum(n_WD_Varo) as Varo, 
	   sum(n_WD_USBank) as USBank, 
	   sum(n_WD_Sky) as Sky, 
	   sum(n_WD_MN) as MN, 
	   sum(n_WD_Payfare) as Payfare, 
	   sum(n_WD_CashApp) as CashApp, 
	   sum(n_WD_ADP) as ADP, 
	   sum(n_WD_Comdata) as Comdata, 
	   sum(n_WD_Chime) as Chime,
	   sum(n_WD_PNCBank) as PNCBank
from #all_fcst1
where ATMInternalID = '9083'
group by ATMInternalID,ForecastDate;*/
/******************************************************************************************
Forecast is done, save for monitoring, prepare data for forecast spreadsheet. 
******************************************************************************************/

/* Save Forecast for metrics */
IF OBJECT_ID('[SSRSReports].[WebReportsUser].[KYC_CASH_PROJ_JUL2_RAW]','U') is not null
	drop table [SSRSReports].[WebReportsUser].[KYC_CASH_PROJ_JUL2_RAW]
select *
  into [SSRSReports].[WebReportsUser].[KYC_CASH_PROJ_JUL2_RAW]
  from #all_fcst1
  where ForecastDate is not null;

select count(*)
  from  #all_fcst1
  where ForecastDate is not null;

create index tmpAP4 on [SSRSReports].[WebReportsUser].[KYC_CASH_PROJ_JUL2_RAW] (ATMInternalID);
create index tmpAP5 on [SSRSReports].[WebReportsUser].[KYC_CASH_PROJ_JUL2_RAW] (ForecastDate);

/*recover table #all_fcst1*/
IF OBJECT_ID('tempdb..#all_fcst1','U') is not null
	drop table #all_fcst1
select * into #all_fcst1
  from [SSRSReports].[WebReportsUser].[KYC_CASH_PROJ_JUL2_RAW]
  where ForecastDate is not null;

select Wk, 
	   sum(WDAmt_Baseline) as Baseline, 
	   sum(WDAmt_Comerica) as Comerica,
       sum(WDAmt_Varo) as Varo, 
	   sum(WDAmt_USBank) as USBank, 
	   sum(WDAmt_Payfare) as Payfare, 
	   sum(WDAmt_MN) as MN, 
	   sum(WDAmt_Sky) as Sky,
	   sum(WDAmt_CashApp) as CashApp,
	   sum(WDAmt_ADP) as ADP, 
	   sum(WDAmt_Comdata) as Comdata, 
	   sum(WDAmt_Chime) as Chime,
	   sum(WDAmt_PNCBank) as PNCBank,
	   sum(WDAmt_Proj) as Proj_BeforeImpute,
	   sum(WDAmt_Proj_Fin) as Proj   
   from #all_fcst1
 group by Wk
 order by 1;
 
 
select Wk, 
	   sum(WDAmt_Baseline) as Baseline, 
	   sum(WDAmt_Comerica) as Comerica,
       sum(WDAmt_Varo) as Varo, 
	   sum(WDAmt_USBank) as USBank, 
	   sum(WDAmt_Payfare) as Payfare, 
	   sum(WDAmt_MN) as MN, 
	   sum(WDAmt_Sky) as Sky,
	   sum(WDAmt_CashApp) as CashApp,
	   sum(WDAmt_ADP) as ADP, 
	   sum(WDAmt_Comdata) as Comdata, 
	   sum(WDAmt_Chime) as Chime,
	   sum(WDAmt_PNCBank) as PNCBank,
	   sum(WDAmt_Proj) as Proj_BeforeImpute,
	   sum(WDAmt_Proj_Fin) as Proj   
   from #all_fcst1 f
        inner join #terms1 t
		on f.ATMInternalID = t.ATMInternalID
 where t.Arrangement in ('CASHASSIST', 'TURNKEY', 'MERCHANT FUNDED')
  group by Wk
 order by 1;

select top 1000 * 
  from #all_fcst1

/* update Jun 20 2023*/
select top 10 * from #all_fcst1;

IF OBJECT_ID('tempdb..#all_fcst11','U') is not null
	drop table #all_fcst11;
SELECT ATMInternalID as ATMID, replace(CONVERT(NVARCHAR, [ForecastDate], 112),2023,'n_WD_') as ForecastDate, 
							 n_WD_Proj_Fin
into #all_fcst11
FROM #all_fcst1;


-- pivot table for n_WD:
IF OBJECT_ID('tempdb..##all_fcst2','U') is not null
	drop table ##all_fcst2;

DECLARE @cols NVARCHAR(MAX)

SELECT @cols = COALESCE(@cols + ',[' + CONVERT(NVARCHAR, [ForecastDate], 112) + ']',
                        '[' + CONVERT(NVARCHAR, [ForecastDate], 112) + ']')
				   FROM (SELECT DISTINCT [ForecastDate] FROM #all_fcst1) PV
				  ORDER BY [ForecastDate]
				  
set @cols = replace(@cols,2023,'n_WD_')
print @cols
DECLARE @query NVARCHAR(MAX)

SET @query = '
              SELECT *
			  into ##all_fcst2
			    FROM (SELECT ATMID as ATMID, 
				             ForecastDate, 
							 n_WD_Proj_Fin
				        FROM #all_fcst11) x
			   PIVOT (SUM(n_WD_Proj_Fin)
			          FOR [ForecastDate] IN (' + @cols + ')
					 )p
			   ORDER BY ATMID
			 '
EXEC SP_EXECUTESQL @query;

select top 10 * from ##all_fcst2;

-- pivot table for WDAmt:
IF OBJECT_ID('tempdb..#all_fcst11','U') is not null
	drop table #all_fcst11;
SELECT ATMInternalID, replace(CONVERT(NVARCHAR, [ForecastDate], 112),2023,'WDAmt_') as ForecastDate, 
							 WDAmt_Proj_Fin
into #all_fcst11
FROM #all_fcst1;

IF OBJECT_ID('tempdb..##all_fcst3','U') is not null
	drop table ##all_fcst3;

DECLARE @cols NVARCHAR(MAX)

SELECT @cols = COALESCE(@cols + ',[' + CONVERT(NVARCHAR, [ForecastDate], 112) + ']',
                        '[' + CONVERT(NVARCHAR, [ForecastDate], 112) + ']')
				   FROM (SELECT DISTINCT [ForecastDate] FROM #all_fcst1) PV
				  ORDER BY [ForecastDate]

set @cols = replace(@cols,2023,'WDAmt_')
print @cols

DECLARE @query NVARCHAR(MAX)

SET @query = '
              SELECT *
			  into ##all_fcst3
			    FROM (SELECT ATMInternalID, 
				             ForecastDate, 
							 WDAmt_Proj_Fin
				        FROM #all_fcst11) x
			   PIVOT (SUM(WDAmt_Proj_Fin)
			          FOR [ForecastDate] IN (' + @cols + ')
					 )p
			   ORDER BY ATMInternalID
			 '
EXEC SP_EXECUTESQL @query;

select top 10 * from SSRSReports.WebReportsUser.##all_fcst3;

-- merge 2 tables:
IF OBJECT_ID('tempdb..#all_fcst_fin', 'U') IS NOT NULL 
   drop table #all_fcst_fin; 
select a.*, b.*
into #all_fcst_fin
from ##all_fcst2 a
left join ##all_fcst3 b
on a.ATMID = b.ATMInternalID
order by a.ATMID;

Alter table #all_fcst_fin
drop column ATMInternalID;

select top 10 * from #all_fcst_fin;

select top(2) *
from #all_fcst_fin;

/*
ATMID	n_WD_0702	n_WD_0703	n_WD_0704	n_WD_0705	n_WD_0706	n_WD_0707	n_WD_0708	n_WD_0709	n_WD_0710	n_WD_0711	n_WD_0712	n_WD_0713	n_WD_0714	n_WD_0715	n_WD_0716	n_WD_0717	n_WD_0718	n_WD_0719	n_WD_0720	n_WD_0721	n_WD_0722	n_WD_0723	n_WD_0724	n_WD_0725	n_WD_0726	n_WD_0727	n_WD_0728	n_WD_0729	n_WD_0730	n_WD_0731	n_WD_0801	n_WD_0802	n_WD_0803	n_WD_0804	n_WD_0805	n_WD_0806	n_WD_0807	n_WD_0808	n_WD_0809	n_WD_0810	n_WD_0811	n_WD_0812	n_WD_0813	n_WD_0814	n_WD_0815	n_WD_0816	n_WD_0817	n_WD_0818	n_WD_0819	n_WD_0820	n_WD_0821	n_WD_0822	n_WD_0823	n_WD_0824	n_WD_0825	n_WD_0826	n_WD_0827	n_WD_0828	n_WD_0829	n_WD_0830	n_WD_0831	n_WD_0901	n_WD_0902	n_WD_0903	n_WD_0904	n_WD_0905	n_WD_0906	n_WD_0907	n_WD_0908	n_WD_0909	n_WD_0910	n_WD_0911	n_WD_0912	n_WD_0913	n_WD_0914	n_WD_0915	n_WD_0916	n_WD_0917	n_WD_0918	n_WD_0919	n_WD_0920	n_WD_0921	n_WD_0922	n_WD_0923	WDAmt_0604	WDAmt_0605	WDAmt_0606	WDAmt_0607	WDAmt_0608	WDAmt_0609	WDAmt_0610	WDAmt_0611	WDAmt_0612	WDAmt_0613	WDAmt_0614	WDAmt_0615	WDAmt_0616	WDAmt_0617	WDAmt_0618	WDAmt_0619	WDAmt_0620	WDAmt_0621	WDAmt_0622	WDAmt_0623	WDAmt_0624	WDAmt_0625	WDAmt_0626	WDAmt_0627	WDAmt_0628	WDAmt_0629	WDAmt_0630	WDAmt_0701	WDAmt_0702	WDAmt_0703	WDAmt_0704	WDAmt_0705	WDAmt_0706	WDAmt_0707	WDAmt_0708	WDAmt_0709	WDAmt_0710	WDAmt_0711	WDAmt_0712	WDAmt_0713	WDAmt_0714	WDAmt_0715	WDAmt_0716	WDAmt_0717	WDAmt_0718	WDAmt_0719	WDAmt_0720	WDAmt_0721	WDAmt_0722	WDAmt_0723	WDAmt_0724	WDAmt_0725	WDAmt_0726	WDAmt_0727	WDAmt_0728	WDAmt_0729	WDAmt_0730	WDAmt_0731	WDAmt_0801	WDAmt_0802	WDAmt_0803	WDAmt_0804	WDAmt_0805	WDAmt_0806	WDAmt_0807	WDAmt_0808	WDAmt_0809	WDAmt_0810	WDAmt_0811	WDAmt_0812	WDAmt_0813	WDAmt_0814	WDAmt_0815	WDAmt_0816	WDAmt_0817	WDAmt_0818	WDAmt_0819	WDAmt_0820	WDAmt_0821	WDAmt_0822	WDAmt_0823	WDAmt_0824	WDAmt_0825	WDAmt_0826	WDAmt_0827	WDAmt_0828	WDAmt_0829	WDAmt_0830	WDAmt_0831	WDAmt_0901	WDAmt_0902	WDAmt_0903	WDAmt_0904	WDAmt_0905	WDAmt_0906	WDAmt_0907	WDAmt_0908	WDAmt_0909	WDAmt_0910	WDAmt_0911	WDAmt_0912	WDAmt_0913	WDAmt_0914	WDAmt_0915	WDAmt_0916	WDAmt_0917	WDAmt_0918	WDAmt_0919	WDAmt_0920	WDAmt_0921	WDAmt_0922	WDAmt_0923
4961509	3	3	2	2	4	2	1	3	3	2	2	4	2	1	3	3	2	2	4	2	1	3	3	2	2	4	2	1	3	3	2	2	4	2	1	3	3	2	2	4	2	1	3	3	2	2	4	2	1	3	3	2	2	4	2	1	3	3	2	2	4	2	1	3	3	2	2	4	2	1	3	3	2	2	4	2	1	3	3	2	2	4	2	1	0	0	0	0	0	0	0	0	0	0	0	0	0	0	0	0	0	0	0	0	0	0	0	0	0	0	0	0	545	840	533	327	1080	410	170	545	840	533	327	1080	410	170	545	840	533	327	1080	410	170	545	840	533	327	1484	410	170	545	840	533	327	1080	410	170	545	840	533	327	1080	410	170	545	840	533	327	1080	410	170	545	840	533	327	1456	410	170	545	840	533	327	1080	410	170	545	840	533	327	1080	410	170	545	840	533	327	1080	410	170	545	840	533	327	1428	410	170
310336	37	38	48	65	21	73	77	46	42	52	45	50	73	81	57	26	48	42	40	84	84	42	49	36	59	54	73	81	37	38	47	67	25	73	78	46	42	52	45	49	73	81	56	25	47	43	40	82	82	42	48	35	58	54	73	81	37	38	47	66	21	73	79	46	43	50	44	48	73	81	55	24	46	42	39	83	81	41	47	35	57	52	73	81	0	0	0	0	0	0	0	0	0	0	0	0	0	0	0	0	0	0	0	0	0	0	0	0	0	0	0	0	9082	9489	11439	12511	6654	19386	22374	10666	10146	9250	14239	12969	19386	20503	13909	6299	13467	11342	13901	23030	25030	10815	11533	8044	15649	13711	19386	20503	9169	9738	10934	12511	8605	19386	22582	10666	9985	9250	14020	12728	19386	20503	13650	5626	13229	11771	13643	22613	24582	10617	11329	7915	15382	13575	19386	20503	9088	9661	10852	12511	6827	19386	23547	10666	10569	13714	13779	12486	19386	20503	13394	5533	12999	11965	13383	23700	24142	10419	11126	7787	15114	13199	19386	20503 
*/
--Most of these have a partial projected withdrawal from very low activity, < 0.5 so it rounds down to 0. Some have zero due to no activity. 
IF OBJECT_ID('tempdb..#to_del', 'U') IS NOT NULL 
   drop table #to_del; 
select ATMInternalID, sum(n_WD_Proj_Fin) as totWD, sum(WDAmt_Proj_Fin) as totAmt
  into #to_del
  from #all_fcst1
 group by ATMInternalID
having sum(n_WD_Proj_Fin) = 0;
--15


select *
  from #to_del;
/*
ATMInternalID	totWD	totAmt
136709	0	0
5001107	0	124
4990413	0	191
4963346	0	0
5001389	0	0
4974666	0	123
4999581	0	0
5000704	0	0
167217	0	555
138473	0	1234
250886	0	0
214467	0	481
150512	0	472
9877	0	0
191675	0	0
11988	0	2016
299843	0	0
9133	0	175
9783	0	0
295499	0	0
297801	0	0
4995014	0	0
4978761	0	177
4998017	0	0
261676	0	0
4960011	0	384
286306	0	0
4999440	0	0
303539	0	0
4998004	0	0
4986958	0	0
4969460	0	0
4999490	0	400
308784	0	0
4980418	0	0
187282	0	0
198689	0	617
151250	0	384
154476	0	0
4990378	0	0
310439	0	0
321889	0	0
278369	0	0
159074	0	1205
178948	0	0
4992322	0	0
251194	0	0
185767	0	0
5001414	0	0
4979445	0	281
4967426	0	437
100156	0	0
4987969	0	0
151975	0	0
292821	0	0
219830	0	0
199181	0	0
267408	0	0
4982700	0	0
4997997	0	0
216291	0	0
2622	0	0
133771	0	876
4967019	0	0
189409	0	0
5001765	0	0
4959481	0	0
9700	0	336
38583	0	386
136676	0	0
*/
  

select d.ATMInternalID, 
       d.totWD, 
	   d.totAmt, 
	   t.AUDFD1
  from #to_del d
       inner join #terms1 t
	   on d.ATMInternalID = t.ATMInternalID
 order by t.AUDFD1 desc;
/* most of these have last txn date one week ago or prior 
       likely little to no activity during baseline 
ATMInternalID	totWD	totAmt	AUDFD1
9133	0	175	2023-05-28 00:00:00.000
150512	0	472	2023-05-28 00:00:00.000
2622	0	0	2023-05-28 00:00:00.000
154476	0	0	2023-05-28 00:00:00.000
138473	0	1234	2023-05-28 00:00:00.000
11988	0	2016	2023-05-28 00:00:00.000
9877	0	0	2023-05-28 00:00:00.000
133771	0	876	2023-05-28 00:00:00.000
151975	0	0	2023-05-28 00:00:00.000
9700	0	336	2023-05-28 00:00:00.000
9783	0	0	2023-05-28 00:00:00.000
136676	0	0	2023-05-28 00:00:00.000
136709	0	0	2023-05-28 00:00:00.000
151250	0	384	2023-05-28 00:00:00.000
189409	0	0	2023-05-28 00:00:00.000
178948	0	0	2023-05-28 00:00:00.000
187282	0	0	2023-05-28 00:00:00.000
159074	0	1205	2023-05-28 00:00:00.000
167217	0	555	2023-05-28 00:00:00.000
198689	0	617	2023-05-28 00:00:00.000
303539	0	0	2023-05-28 00:00:00.000
292821	0	0	2023-05-28 00:00:00.000
310439	0	0	2023-05-28 00:00:00.000
278369	0	0	2023-05-28 00:00:00.000
299843	0	0	2023-05-28 00:00:00.000
308784	0	0	2023-05-28 00:00:00.000
4959481	0	0	2023-05-28 00:00:00.000
4960011	0	384	2023-05-28 00:00:00.000
250886	0	0	2023-05-28 00:00:00.000
251194	0	0	2023-05-28 00:00:00.000
214467	0	481	2023-05-28 00:00:00.000
219830	0	0	2023-05-28 00:00:00.000
297801	0	0	2023-05-28 00:00:00.000
321889	0	0	2023-05-28 00:00:00.000
4997997	0	0	2023-05-28 00:00:00.000
4998004	0	0	2023-05-28 00:00:00.000
4987969	0	0	2023-05-28 00:00:00.000
4982700	0	0	2023-05-28 00:00:00.000
4992322	0	0	2023-05-28 00:00:00.000
5001765	0	0	2023-05-28 00:00:00.000
4969460	0	0	2023-05-28 00:00:00.000
4979445	0	281	2023-05-28 00:00:00.000
4980418	0	0	2023-05-28 00:00:00.000
4974666	0	123	2023-05-27 00:00:00.000
4978761	0	177	2023-05-27 00:00:00.000
261676	0	0	2023-05-27 00:00:00.000
191675	0	0	2023-05-27 00:00:00.000
199181	0	0	2023-05-27 00:00:00.000
38583	0	386	2023-05-27 00:00:00.000
267408	0	0	2023-05-26 00:00:00.000
295499	0	0	2023-05-26 00:00:00.000
4990378	0	0	2023-05-26 00:00:00.000
4986958	0	0	2023-05-26 00:00:00.000
4999581	0	0	2023-05-26 00:00:00.000
4967019	0	0	2023-05-25 00:00:00.000
216291	0	0	2023-05-25 00:00:00.000
100156	0	0	2023-05-22 00:00:00.000
185767	0	0	2023-05-21 00:00:00.000
5001107	0	124	2023-05-20 00:00:00.000
4998017	0	0	2023-05-13 00:00:00.000
5001414	0	0	2023-05-12 00:00:00.000
4990413	0	191	2023-05-09 00:00:00.000
5001389	0	0	2023-05-07 00:00:00.000
5000704	0	0	2023-05-05 00:00:00.000
4963346	0	0	2023-05-05 00:00:00.000
4995014	0	0	2023-05-04 00:00:00.000
286306	0	0	2023-05-01 00:00:00.000
4967426	0	437	2023-04-30 00:00:00.000
4999490	0	400	2023-04-30 00:00:00.000
4999440	0	0	NULL
*/

select top 1000 *
  from #all_fcst_fin

create index tmpAP4 on #all_fcst_fin (ATMID);
create index tmpAP4 on #to_del (ATMInternalID);

/* Final Output for Projections sheet */
select a.Segment, a.TerminalID, a.Arrangement, a.Program, a.RetailerType, 
       a.Location, a.Address, a.City, a.State, a.Zip, isnull(a.CBSA,'Other') as CBSA, 
	   case when a.LMI = 1 then 'LMI' 
			when a.LMI = 0 then 'Non-LMI' 
			when a.LMI is NULL then NULL
			else 'Unknown' 
	   end as LMI_Ind,
	   case when a.APGroup is not null then 1 
	        else 0 
	   end as Allpoint_Ind,
	   b.*
  from #atms_fin a
       left join #all_fcst_fin b 
	   on a.ATMInternalID = b.ATMID
 where a.ATMInternalID not in (select ATMInternalID from #to_del)
 order by a.TerminalID;
 
/* Check totals */
select sum(n_WD_Proj_Fin) as n_WD_Tot, 
       sum(WDAmt_Proj_Fin) as WDAmt_Tot
  from #atms_fin a
       left join #all_fcst1 b 
       on a.ATMInternalID = b.ATMInternalID
 where a.ATMInternalID not in (select ATMInternalID from #to_del);
/*
Note: n_WD_Proj_Fin is created from a imputed and rounded value, so total 
      may not be identical to sum of individual BIN group values. 
n_WD_Tot	WDAmt_Tot
66422638	10054153502
*/

select 
       sum(n_WD_Baseline) as Baseline, 
	   sum(n_WD_Comerica) as Comerica, 
	   sum(n_WD_Varo) as Varo, 
	   sum(n_WD_USBank) as USBank, 
	   sum(n_WD_Sky) as Sky, 
	   sum(n_WD_MN) as MN, 
	   sum(n_WD_Payfare) as Payfare, 
	   sum(n_WD_CashApp) as CashApp, 
	   sum(n_WD_ADP) as ADP, 
	   sum(n_WD_Comdata) as Comdata, 
	   sum(n_WD_Chime) as Chime,
	   sum(n_WD_PNCBank) as PNCBank,
       sum(n_WD_Proj_Fin) as total_rounded_and_imputed, 
	   sum(n_WD_Proj) as total_unrounded_and_unimputed, 
	   sum(n_WD_Baseline) + sum(n_WD_Comerica) + sum(n_WD_Varo) + sum(n_WD_USBank) + sum(n_WD_Sky) + sum(n_WD_MN) + 
	       sum(n_WD_Payfare) + sum(n_WD_CashApp) + sum(n_WD_ADP) + sum(n_WD_Comdata) + sum(n_WD_Chime)+ sum(n_WD_PNCBank) as Tot_sum_unrounded_but_imputed
  from #all_fcst1
   where ATMInternalID not in (select ATMInternalID from #to_del);

 

select forecastdate, 
       sum(n_WD_Proj_Fin) as n_WD, 
	   Sum(WDAmt_Proj_Fin) as WDAmt
  from #all_fcst1
   where ATMInternalID not in (select ATMInternalID from #to_del)
   and forecastdate is not null
 group by forecastdate
 order by forecastdate;

/*
forecastdate	n_WD	WDAmt
2023-07-02	744554	104215142
2023-07-03	607075	86868103
2023-07-04	613995	91237409
2023-07-05	718244	107551493
2023-07-06	899498	141354612
2023-07-07	1063816	174125745
2023-07-08	1109648	175585579
2023-07-09	760498	105969251
2023-07-10	575406	82580492
2023-07-11	618671	90074175
2023-07-12	684177	100951357
2023-07-13	831774	128196055
2023-07-14	994003	159448810
2023-07-15	1065254	166002593
2023-07-16	737045	101437293
2023-07-17	548233	77464550
2023-07-18	592014	84962576
2023-07-19	674713	98914800
2023-07-20	838744	128901329
2023-07-21	999262	160372290
2023-07-22	1061845	165461193
2023-07-23	736083	101473089
2023-07-24	546339	77183123
2023-07-25	583409	83841266
2023-07-26	672204	99110998
2023-07-27	842737	128499653
2023-07-28	987545	157957191
2023-07-29	1049204	163686160
2023-07-30	736488	104877450
2023-07-31	557620	80469627
2023-08-01	631883	93976471
2023-08-02	736236	111706444
2023-08-03	938019	148255622
2023-08-04	1107551	183377691
2023-08-05	1137368	180061555
2023-08-06	767544	107028194
2023-08-07	578626	83037758
2023-08-08	619839	90526927
2023-08-09	687187	101429940
2023-08-10	837764	129383283
2023-08-11	1000432	160626948
2023-08-12	1067442	166596493
2023-08-13	731052	101012952
2023-08-14	543774	77128003
2023-08-15	588134	84609196
2023-08-16	670584	98511539
2023-08-17	834160	128431042
2023-08-18	993214	159782198
2023-08-19	1054920	164741495
2023-08-20	729976	100851457
2023-08-21	541816	76797005
2023-08-22	578717	83384188
2023-08-23	666608	98390281
2023-08-24	835715	127605321
2023-08-25	979941	157048754
2023-08-26	1040679	162879053
2023-08-27	736604	104883115
2023-08-28	557602	80435848
2023-08-29	572209	85738236
2023-08-30	706067	107534491
2023-08-31	900089	144587543
2023-09-01	1115613	182921311
2023-09-02	1155948	181840995
2023-09-03	772205	107688044
2023-09-04	587930	84596853
2023-09-05	627350	91913845
2023-09-06	687326	101293078
2023-09-07	836864	129301841
2023-09-08	998524	160630867
2023-09-09	1064062	166329572
2023-09-10	727947	100651997
2023-09-11	542215	77035106
2023-09-12	586924	84530818
2023-09-13	669771	98521563
2023-09-14	833271	128568991
2023-09-15	990725	159573256
2023-09-16	1050020	164362395
2023-09-17	726216	100452264
2023-09-18	540076	76526211
2023-09-19	576381	83154055
2023-09-20	665427	98484561
2023-09-21	834956	127594381
2023-09-22	976406	156756362
2023-09-23	1034631	162292689
*/


select forecastdate, 
       sum(n_WD_Proj_Fin) as n_WD, 
	   Sum(WDAmt_Proj_Fin) as WDAmt
  from #all_fcst1 f
       left join #terms1 t
	   on f.ATMInternalID = t.ATMInternalID
   where f.ATMInternalID not in (select ATMInternalID from #to_del)
     and t.Arrangement in ('TURNKEY', 'CASHASSIST', 'MERCHANT FUNDED')
 group by forecastdate
 order by forecastdate;


/*---------------summary sheet Data -----------------*/

select forecastdate,
       sum(n_WD_Baseline) as n_WD,
       Sum(WDAmt_Baseline) as WDAmt
  from  #all_fcst1
   where ATMInternalID not in (select ATMInternalID from #to_del)
   and forecastdate is not null
 group by forecastdate
 order by forecastdate;


/* Comerica Output */
select forecastdate, 
       sum(n_WD_Comerica) as n_WD, 
	   Sum(WDAmt_Comerica) as WDAmt
  from #all_fcst1
   where ATMInternalID not in (select ATMInternalID from #to_del)
   and forecastdate is not null
 group by forecastdate
 order by forecastdate;

/* Varo Output */
select forecastdate, 
       sum(n_WD_Varo) as n_WD, 
	   Sum(WDAmt_Varo) as WDAmt
  from #all_fcst1
   where ATMInternalID not in (select ATMInternalID from #to_del)
   and forecastdate is not null
 group by forecastdate
 order by forecastdate;

/* US Bank Output */
select forecastdate, 
       sum(n_WD_USBank) as n_WD, 
	   Sum(WDAmt_USBank) as WDAmt
  from #all_fcst1
   where ATMInternalID not in (select ATMInternalID from #to_del)
   and forecastdate is not null
 group by forecastdate
 order by forecastdate;
 
/* Skylight Financial Output */
select forecastdate, 
       sum(n_WD_Sky) as n_WD, 
	   Sum(WDAmt_Sky) as WDAmt
  from #all_fcst1
   where ATMInternalID not in (select ATMInternalID from #to_del)
   and forecastdate is not null
 group by forecastdate
 order by forecastdate;

/* MN Output */
select forecastdate, 
       sum(n_WD_MN) as n_WD, 
	   Sum(WDAmt_MN) as WDAmt
  from #all_fcst1
   where ATMInternalID not in (select ATMInternalID from #to_del)
   and forecastdate is not null
 group by forecastdate
 order by forecastdate;

/* Payfare Output */
select forecastdate, 
       sum(n_WD_Payfare) as n_WD, 
	   Sum(WDAmt_Payfare) as WDAmt
  from #all_fcst1
   where ATMInternalID not in (select ATMInternalID from #to_del)
   and forecastdate is not null
 group by forecastdate
 order by forecastdate;

/* CashApp Output */
select forecastdate, 
       sum(n_WD_CashApp) as n_WD, 
	   Sum(WDAmt_CashApp) as WDAmt
  from #all_fcst1
   where ATMInternalID not in (select ATMInternalID from #to_del)
   and forecastdate is not null
 group by forecastdate
 order by forecastdate;
 
/* ADP Output */
select forecastdate, 
       sum(n_WD_ADP) as n_WD, 
	   Sum(WDAmt_ADP) as WDAmt
  from #all_fcst1
   where ATMInternalID not in (select ATMInternalID from #to_del)
   and forecastdate is not null
 group by forecastdate
 order by forecastdate;
 
/* Comdata Output */
select forecastdate, 
       sum(n_WD_Comdata) as n_WD, 
	   Sum(WDAmt_Comdata) as WDAmt
  from #all_fcst1
   where ATMInternalID not in (select ATMInternalID from #to_del)
   and forecastdate is not null
 group by forecastdate
 order by forecastdate;
 
/* Chime Output */
select forecastdate, 
       sum(n_WD_Chime) as n_WD, 
	   Sum(WDAmt_Chime) as WDAmt
  from #all_fcst1
   where ATMInternalID not in (select ATMInternalID from #to_del)
   and forecastdate is not null
 group by forecastdate
 order by forecastdate;

  
/* PNC Output */
select forecastdate, 
       sum(n_WD_PNCBank) as n_WD, 
	   Sum(WDAmt_PNCBank) as WDAmt
  from #all_fcst1
   where ATMInternalID not in (select ATMInternalID from #to_del)
   and forecastdate is not null
 group by forecastdate
 order by forecastdate;


select forecastdate, 
       sum(n_WD_Proj_Fin) as total_rounded_and_imputed, 
	   sum(n_WD_Proj) as total_unrounded_and_unimputed, 
	   sum(n_WD_Baseline) + sum(n_WD_Comerica) + sum(n_WD_Varo) + sum(n_WD_USBank) + sum(n_WD_Sky) + sum(n_WD_MN) + 
	   sum(n_WD_Payfare) + sum(n_WD_CashApp) + sum(n_WD_ADP) + sum(n_WD_Comdata) + sum(n_WD_Chime)+ sum(n_WD_PNCBank) as Tot_sum_unrounded_but_imputed
  from #all_fcst1
   where ATMInternalID not in (select ATMInternalID from #to_del)
   and forecastdate is not null
 group by forecastdate
 order by forecastdate;

/* Total*/
 select sum(WDAmt_Proj_Fin) as total_rounded_and_imputed, 
	   sum(WDAmt_Proj) as total_unrounded_and_unimputed, 
	   sum(WDAmt_Baseline) + sum(WDAmt_Comerica) + sum(WDAmt_Varo) + sum(WDAmt_USBank) + sum(WDAmt_Sky) + sum(WDAmt_MN) + 
	   sum(WDAmt_Payfare) + sum(WDAmt_CashApp) + sum(WDAmt_ADP) + sum(WDAmt_Comdata) + sum(WDAmt_Chime)+ sum(WDAmt_PNCBank) as Tot_sum_unrounded_but_imputed
  from #all_fcst1
   where ATMInternalID not in (select ATMInternalID from #to_del)
   and forecastdate is not null;

/*
total_rounded_and_imputed	total_unrounded_and_unimputed	Tot_sum_unrounded_but_imputed
10054153502					10447446478.6309				10054152391.6309
*/


/* By Forecastdate*/
 select ForecastDate ,sum(WDAmt_Proj_Fin) as total_rounded_and_imputed, 
	   sum(WDAmt_Proj) as total_unrounded_and_unimputed, 
	   sum(WDAmt_Baseline) + sum(WDAmt_Comerica) + sum(WDAmt_Varo) + sum(WDAmt_USBank) + sum(WDAmt_Sky) + sum(WDAmt_MN) + 
	   sum(WDAmt_Payfare) + sum(WDAmt_CashApp) + sum(WDAmt_ADP) + sum(WDAmt_Comdata) + sum(WDAmt_Chime)+ sum(WDAmt_PNCBank) as Tot_sum_unrounded_but_imputed
  from #all_fcst1
   where ATMInternalID not in (select ATMInternalID from #to_del)
   and forecastdate is not null
  group by ForecastDate
  order by ForecastDate;
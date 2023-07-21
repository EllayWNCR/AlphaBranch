/***************************************************************************************************************************
*001 BIN_PULL_Historical_Data_v5.sql
*
*Forecast run for 12 weeks: Jul 4 2023 - Sep 23 2023
*   week 27, 2023- week 38, 2023
*
*Run Jun 26 2023
*
*Baseline: May 28, 2022 - Jun 24, 2023

*Baseline for new terminals: Jun 11, 2023 - Jun 24, 2023
*
* 2/4/21   Refactored code for Non-AP BINs to use APBinMatchBIN where APBinMatch = 0 instead of BankID
*              as this will allow forecasting of AP BankIDs without pulling extended AP BINs sharing the 
*              same BankID. 
* 5/20/21  Refactored code for RelationshipType, ReportingGroup, TemplateName. They had been obtained by joining on AUDFL6, 
*              which is no longer maintained. They are now defined through joining on Program and Arrangement. 
*          Updated [SSRSReports].[WebReportsUser].[KYC_TEMP_BIN_LIST_TRIM] to add new AP BINs for Chime, 
*              which had several extended BINs activated in Allpoint on 5/5/21. 4232230, 4985031, 4232231
*              show up in txns since 5/5/21. 
*          Replaced MS_IND with segment, defined as in MUDS from code from Shree. 
*          Moved join to ATMManagerM_TW.dbo.FIIDLookup into #txn table load per Charles Willis tuning suggestion. 
*          Changed load of #txn from one large result set to loop on one settlement date at a time per Charles Willis 
*              tuning suggestion. 
* 6/23/21  Changed load of #txn back to one large load due to some discrepancies in data last month: InternalIDs and 
*              few Bancorp and Stride transactions were off. 
* 8/31/21  One file was loaded in to CORE twice with data for 8/28/21. [KYC_CASH_PROJ_2021_Finance_Data] has incorrect data 
*              for 8/28/21. Delete and reload just this one date. 
* 10/27/21 Updated [SSRSReports].[WebReportsUser].[KYC_TEMP_BIN_LIST_TRIM] for changes to Chime AP BINs. 
* 01/10/22 Updated [SSRSReports].[WebReportsUser].[KYC_TEMP_BIN_LIST_TRIM] for changes to various AP BINs: Added new BIN for ADP, 
*          removed several after verifying they have no recent transactions. 
* 2/2/22   Updated [SSRSReports].[WebReportsUser].[KYC_TEMP_BIN_LIST_TRIM], added BINs for US Bank-Private, Varo Money, change issuer
*          for some BINs labeled NetSpend to Skylight Financial per Feb 2022 BIN-Issuer manual file from Allpoint team. 
* 4/6/22   Add BIN 440393 to non-AP BIN list - Cash App
* 7/13/22  Add 166 more BINs to AP BIN list - PNC Bank
*
*Last Modified Date:  04/03/2023
*Last Modified By:    Ella Wang
*
* 8.5 hrs to run 4/23/21 immediately after server reboot
* 48 hrs end of May with loop on one date at a time, but execution plan was turned on
* 2.5 hrs to run 6/23/21!!!
* ~3 hrs to run 8/26/21
******************************************************************************************************************************/

IF OBJECT_ID('tempdb..#dates', 'U') IS NOT NULL
   drop table #dates;
create table #dates
(
	varname varchar(20) primary key,
	dt datetime
);

Insert into #dates Select 'StartDate',  cast('2022-10-23' as datetime);
Insert into #dates Select 'EndDate', Dateadd(DAY, -2, dateadd(week, datediff(week, 0,getdate()),0));
--Insert into #dates Select 'EndDate',  cast('2023-06-24' as datetime);

select * from #dates;
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
-- 0 rows

select *
  from #rev_rec_lkp_inactive
 where n_temp > 1;
-- 0 rows

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
       a.AUDFX4 as Program,
	   a.Status,
	   b.BusUnitName,
	   case 
   		   when a.AUDFX2 like 'MEXICO' then 'Mexico'
		   when a.AUDFX2 like 'CANADA' then 'Canada'
		   when a.AUDFX2 like '%MS' then 'MS'
		   when a.AUDFX2 like 'MS%' then 'MS-1'
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
--247524

	   
---check dups
select ATMInternalID, 
       count(*) as n_rec
  from #ATM_ALL
 group by ATMInternalID
having count(*) > 1;
-- 0 rows

/*************************************************************
Get a list of All ATM Internal IDs that had a transaction 
during the required time period
**************************************************************/
/* this runs faser since pulling terminals by month*/

IF OBJECT_ID('tempdb..#atm_with_trans', 'U') IS NOT NULL
   drop table #atm_with_trans;
select a.ATMInternalID,
	   b.zip5,
	   b.AUDFD1, 
	   b.AUDFD2, 
	   b.Program, 
	   b.Status, 
	   b.Arrangement, 
	   b.BL_ATM,
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
		   WHEN ltrim(rtrim(b.BusUnitName))='US' and ltrim(rtrim(coalesce(b.TemplateName,'ST'))) in ('MS') THEN 'US-MS'
		   WHEN ltrim(rtrim(b.BusUnitName))='US' and ltrim(rtrim(coalesce(b.TemplateName,'ST'))) not in ('MS') THEN 'US-Non-MS'
	       ELSE 'Unknown'
	   END AS segment
  into #atm_with_trans
  from (select distinct ATMInternalID
          from ATMManagerM.dbo.ATMTxnTotalsMonthly a WITH (nolock)
         where ATMInternalID is not null
           and (a.ATMYear * 100 + a.ATMMonth) >= (select year(dt) * 100 + month(dt) as yymm_st from #dates where varname='StartDate')
           and (a.ATMYear * 100 + a.ATMMonth) <= (select year(dt) * 100 + month(dt) as yymm_st from #dates where varname='EndDate')
       )a
       left join #ATM_ALL b 
	   on a.[ATMInternalID] = b.[ATMInternalID];

select count(*)
  from #atm_with_trans;
--102471

create index tmpAP1 on #atm_with_trans (ATMInternalID);

select top(1) *
from ATMManagerM.dbo.ATMTxnTotalsMonthly a WITH (nolock);



/*************************************************************
Pull Updated AP Bin List 
Note: This list is trimmed to BINs germane to forecasting, it 
      is not a full list. Using a full list would result in a
	  very large Finance_Data table and is not necessary for 
	  forecasting. 
10/27/21 add 421783 to [SSRSReports].[WebReportsUser].[KYC_TEMP_BIN_LIST_TRIM]
         make sure all AP bins being forecast separately are in 
		 [SSRSReports].[WebReportsUser].[KYC_TEMP_BIN_LIST_TRIM]
		 Update KYC_TEMP_BIN_LIST_TRIM for bin changes for Chime
		 made on 9/1/2021. 
1/10/22  Added 416187 to ADP, removed several BINs that are 
         no longer Allpoint and have no transactions since 2020. 
2/2/22   Added US Bank - Private Prepaid-Payroll BIN list, Varo
         Money BIN list, changed Issuer on 5 BINs from NetSpend to 
		 Skylight Financial to match Allpoint team BIN-Issuer 
		 lookup. 

7/13/22  Added PNC Bank BIN list
05/02/23 Added new Payfare BIN to list
**************************************************************/
/* These bins were added to Allpoint as of 9/1/21 */
/*
INSERT INTO [SSRSReports].[WebReportsUser].[KYC_TEMP_BIN_LIST_TRIM]
VALUES ('421783', 'Chime', 'Fintech'), 
       ('498503', 'Chime', 'Fintech'), 
	   ('423223', 'Chime', 'Fintech');
	*/
/* These bins were removed from Allpoint as of 9/1/21 */
/*
DELETE FROM [SSRSReports].[WebReportsUser].[KYC_TEMP_BIN_LIST_TRIM]
WHERE bin in ('4985031', '4232230', '4232231', '4217832', '4217833', '4217834' );
*/

/* Add rest of Chime BINs from November allpoint_bin_fi_lookup.csv from Allpoint team. These BINs 
   do not have significant volume yet, but don't want to miss them taking off in the future. */  
/* These bins were added to Allpoint as of 10/6/21 */

/*
INSERT INTO [SSRSReports].[WebReportsUser].[KYC_TEMP_BIN_LIST_TRIM]
VALUES ('400895', 'Chime', 'Fintech'), 
       ('447227', 'Chime', 'Fintech'), 
	   ('486208', 'Chime', 'Fintech');
*/
	   
/* Remove BINs that are no longer Allpoint 1/10/2022, most recent txns are 2020. */
/*
DELETE FROM [SSRSReports].[WebReportsUser].[KYC_TEMP_BIN_LIST_TRIM]
 WHERE BIN IN ('409747004', -- removed 6/2/21
               '409747005', -- removed 6/2/21
			   '430234003', -- removed 8/4/21
			   '430234004', -- removed 8/4/21
			   '494635', -- removed 1/6/21 
			   '515267', -- removed 11/3/21
			   '515310',  -- removed 11/3/21
			   '474629'); -- removed 5/6/2020
			   
			   
INSERT INTO [SSRSReports].[WebReportsUser].[KYC_TEMP_BIN_LIST_TRIM]
VALUES ('416187', 'ADP', 'Prepaid-Payroll') --added 9/1/21
*/


/* Add US Bank - Private Prepaid-Payroll BINs. 
   2/2/22 */
/*   
INSERT INTO [SSRSReports].[WebReportsUser].[KYC_TEMP_BIN_LIST_TRIM]
VALUES ('406069', 'US Bank - Private', 'Prepaid-Payroll'), 
       ('408031', 'US Bank - Private', 'Prepaid-Payroll'), 
	   ('411238', 'US Bank - Private', 'Prepaid-Payroll'), 
	   ('417021', 'US Bank - Private', 'Prepaid-Payroll'), 
       ('426752', 'US Bank - Private', 'Prepaid-Payroll'), 
	   ('428191', 'US Bank - Private', 'Prepaid-Payroll'), 
	   ('431582', 'US Bank - Private', 'Prepaid-Payroll'), 
       ('441814', 'US Bank - Private', 'Prepaid-Payroll'), 
	   ('443161', 'US Bank - Private', 'Prepaid-Payroll'), 
	   ('478665', 'US Bank - Private', 'Prepaid-Payroll'), 
       ('479841', 'US Bank - Private', 'Prepaid-Payroll'), 
	   ('487081', 'US Bank - Private', 'Prepaid-Payroll'), 
	   ('511562', 'US Bank - Private', 'Prepaid-Payroll'), 
       ('516175', 'US Bank - Private', 'Prepaid-Payroll'), 
	   ('517750', 'US Bank - Private', 'Prepaid-Payroll'), 
	   ('524913', 'US Bank - Private', 'Prepaid-Payroll'), 
       ('531462', 'US Bank - Private', 'Prepaid-Payroll'), 
	   ('4168600', 'US Bank - Private', 'Prepaid-Payroll'), 
	   ('4440838', 'US Bank - Private', 'Prepaid-Payroll'), 
       ('41455700', 'US Bank - Private', 'Prepaid-Payroll'), 
	   ('45841500', 'US Bank - Private', 'Prepaid-Payroll'), 
	   ('45841550', 'US Bank - Private', 'Prepaid-Payroll'), 
       ('43073111', 'US Bank - Private', 'Prepaid-Payroll'), 
	   ('487917', 'Varo Money', 'Fintech'), 
	   ('433419', 'Varo Money', 'Fintech')
	   ;
*/	
/* 2/9/22 per Feb 2022 Allpoint team BIN-Issuer lookup file, 524913 is Prepaid-Payroll, not Prepaid-Govt */
/*
DELETE FROM [SSRSReports].[WebReportsUser].[KYC_TEMP_BIN_LIST_TRIM]
 WHERE BIN = '524913'
   AND ISSUER = 'US Bank - Government'
   AND BIN_TYPE = 'Prepaid-Govt';
*/
/* Following BINs were listed as NetSpend in KYC_TEMP_BIN_LIST_TRIM, but are Skylight Financial in the 
       latest Allpoing BIN-Issuer lookup file from the Allpoint team. */
	   /*
UPDATE [SSRSReports].[WebReportsUser].[KYC_TEMP_BIN_LIST_TRIM]
SET ISSUER = 'Skylight Financial'
WHERE BIN IN ('40346203', '42530002', '42530003', '42530702', '42530703');
*/	   
       
/* Allpoint file shows two other BINs for Comerica Prepaid-Govt, but they have low/no volume and 
   don't match pattern of SS/SSI. Keep an eye on these: 515090, 515140 */

/* Add US Bank - Private Prepaid-Payroll BINs. 
   7/13/22 */
/*   
INSERT INTO [SSRSReports].[WebReportsUser].[KYC_TEMP_BIN_LIST_TRIM]
VALUES ('400057','PNC Bank','Bank'),
		('400123','PNC Bank','Bank'),
		('403486','PNC Bank','Bank'),
		('403487','PNC Bank','Bank'),
		('403488','PNC Bank','Bank'),
		('403489','PNC Bank','Bank'),
		('403490','PNC Bank','Bank'),
		('403491','PNC Bank','Bank'),
		('403492','PNC Bank','Bank'),
		('403493','PNC Bank','Bank'),
		('403494','PNC Bank','Bank'),
		('403495','PNC Bank','Bank'),
		('403496','PNC Bank','Bank'),
		('403497','PNC Bank','Bank'),
		('403968','PNC Bank','Bank'),
		('403976','PNC Bank','Bank'),
		('404982','PNC Bank','Bank'),
		('404984','PNC Bank','Bank'),
		('405218','PNC Bank','Bank'),
		('407120','PNC Bank','Bank'),
		('408109','PNC Bank','Bank'),
		('410072','PNC Bank','Bank'),
		('422394','PNC Bank','Bank'),
		('422997','PNC Bank','Bank'),
		('424621','PNC Bank','Bank'),
		('425704','PNC Bank','Bank'),
		('425852','PNC Bank','Bank'),
		('425914','PNC Bank','Bank'),
		('431196','PNC Bank','Bank'),
		('431640','PNC Bank','Bank'),
		('432522','PNC Bank','Bank'),
		('435760','PNC Bank','Bank'),
		('438968','PNC Bank','Bank'),
		('439882','PNC Bank','Bank'),
		('443040','PNC Bank','Bank'),
		('443041','PNC Bank','Bank'),
		('443042','PNC Bank','Bank'),
		('443043','PNC Bank','Bank'),
		('443044','PNC Bank','Bank'),
		('443045','PNC Bank','Bank'),
		('443046','PNC Bank','Bank'),
		('443047','PNC Bank','Bank'),
		('443048','PNC Bank','Bank'),
		('443049','PNC Bank','Bank'),
		('443050','PNC Bank','Bank'),
		('443051','PNC Bank','Bank'),
		('443057','PNC Bank','Bank'),
		('443060','PNC Bank','Bank'),
		('443061','PNC Bank','Bank'),
		('443062','PNC Bank','Bank'),
		('443063','PNC Bank','Bank'),
		('443064','PNC Bank','Bank'),
		('443065','PNC Bank','Bank'),
		('443066','PNC Bank','Bank'),
		('443067','PNC Bank','Bank'),
		('443068','PNC Bank','Bank'),
		('443069','PNC Bank','Bank'),
		('443070','PNC Bank','Bank'),
		('443071','PNC Bank','Bank'),
		('443072','PNC Bank','Bank'),
		('443600','PNC Bank','Bank'),
		('443601','PNC Bank','Bank'),
		('443603','PNC Bank','Bank'),
		('445463','PNC Bank','Bank'),
		('448596','PNC Bank','Bank'),
		('448900','PNC Bank','Bank'),
		('448901','PNC Bank','Bank'),
		('448903','PNC Bank','Bank'),
		('448904','PNC Bank','Bank'),
		('448909','PNC Bank','Bank'),
		('448910','PNC Bank','Bank'),
		('448911','PNC Bank','Bank'),
		('448915','PNC Bank','Bank'),
		('448920','PNC Bank','Bank'),
		('448921','PNC Bank','Bank'),
		('448928','PNC Bank','Bank'),
		('448929','PNC Bank','Bank'),
		('448930','PNC Bank','Bank'),
		('448931','PNC Bank','Bank'),
		('448940','PNC Bank','Bank'),
		('448941','PNC Bank','Bank'),
		('448943','PNC Bank','Bank'),
		('448944','PNC Bank','Bank'),
		('448950','PNC Bank','Bank'),
		('448951','PNC Bank','Bank'),
		('448960','PNC Bank','Bank'),
		('448961','PNC Bank','Bank'),
		('448970','PNC Bank','Bank'),
		('448971','PNC Bank','Bank'),
		('448980','PNC Bank','Bank'),
		('448991','PNC Bank','Bank'),
		('450468','PNC Bank','Bank'),
		('450469','PNC Bank','Bank'),
		('450470','PNC Bank','Bank'),
		('463158','PNC Bank','Bank'),
		('463404','PNC Bank','Bank'),
		('463829','PNC Bank','Bank'),
		('469083','PNC Bank','Bank'),
		('471515','PNC Bank','Bank'),
		('471595','PNC Bank','Bank'),
		('472201','PNC Bank','Bank'),
		('473135','PNC Bank','Bank'),
		('474397','PNC Bank','Bank'),
		('475598','PNC Bank','Bank'),
		('477762','PNC Bank','Bank'),
		('479162','PNC Bank','Bank'),
		('480423','PNC Bank','Bank'),
		('480433','PNC Bank','Bank'),
		('480704','PNC Bank','Bank'),
		('480720','PNC Bank','Bank'),
		('481790','PNC Bank','Bank'),
		('485705','PNC Bank','Bank'),
		('485706','PNC Bank','Bank'),
		('485707','PNC Bank','Bank'),
		('485977','PNC Bank','Bank'),
		('486511','PNC Bank','Bank'),
		('486563','PNC Bank','Bank'),
		('486688','PNC Bank','Bank'),
		('487889','PNC Bank','Bank'),
		('491870','PNC Bank','Bank'),
		('500674','PNC Bank','Bank'),
		('500675','PNC Bank','Bank'),
		('500676','PNC Bank','Bank'),
		('500677','PNC Bank','Bank'),
		('502409','PNC Bank','Bank'),
		('503227','PNC Bank','Bank'),
		('503823','PNC Bank','Bank'),
		('529004','PNC Bank','Bank'),
		('537946','PNC Bank','Bank'),
		('540940','PNC Bank','Bank'),
		('541359','PNC Bank','Bank'),
		('541493','PNC Bank','Bank'),
		('541872','PNC Bank','Bank'),
		('543107','PNC Bank','Bank'),
		('543767','PNC Bank','Bank'),
		('545848','PNC Bank','Bank'),
		('545849','PNC Bank','Bank'),
		('548200','PNC Bank','Bank'),
		('548201','PNC Bank','Bank'),
		('548210','PNC Bank','Bank'),
		('548211','PNC Bank','Bank'),
		('548220','PNC Bank','Bank'),
		('548221','PNC Bank','Bank'),
		('548228','PNC Bank','Bank'),
		('548229','PNC Bank','Bank'),
		('548230','PNC Bank','Bank'),
		('548231','PNC Bank','Bank'),
		('548240','PNC Bank','Bank'),
		('548241','PNC Bank','Bank'),
		('548250','PNC Bank','Bank'),
		('548251','PNC Bank','Bank'),
		('548260','PNC Bank','Bank'),
		('548261','PNC Bank','Bank'),
		('553308','PNC Bank','Bank'),
		('556364','PNC Bank','Bank'),
		('556365','PNC Bank','Bank'),
		('556366','PNC Bank','Bank'),
		('560236','PNC Bank','Bank'),
		('560466','PNC Bank','Bank'),
		('560470','PNC Bank','Bank'),
		('564386','PNC Bank','Bank'),
		('574023','PNC Bank','Bank'),
		('585131','PNC Bank','Bank'),
		('585689','PNC Bank','Bank'),
		('586282','PNC Bank','Bank'),
		('588882','PNC Bank','Bank')
	   ;

-- Add new BIN for Payfare Internation(started Feb 2023) to BIN list:

INSERT INTO [SSRSReports].[WebReportsUser].[KYC_TEMP_BIN_LIST_TRIM]
VALUES ('53889628','Payfare International','Prepaid-Payroll');

Update [SSRSReports].[WebReportsUser].[KYC_TEMP_BIN_LIST_TRIM] 
set bin_type = 'Prepaid-Payroll'
where issuer = 'Payfare International'
and bin = 444607;

-- Update [SSRSReports].[WebReportsUser].[KYC_TEMP_BIN_LIST_TRIM] if needed:

Update [SSRSReports].[WebReportsUser].[KYC_TEMP_BIN_LIST_TRIM]
set bin_type = 'Bank'
where issuer in ('544927'
				'553680'
				'544928'
				'559439'
				);

Update [SSRSReports].[WebReportsUser].[KYC_TEMP_BIN_LIST_TRIM]
set bin_type = 'CU'
where issuer = '487391';

Update [SSRSReports].[WebReportsUser].[KYC_TEMP_BIN_LIST_TRIM]
set bin_type = 'Fintech'
where issuer in ('407216'
				'422060'
				'465201'
				'485310'
				'499967'
				'511541'
				'514067'
				'515554'
				'526876'
				'539739'
				'541976'
				'555600'
				'555753'
				'410881'
				'422059'
				'49435901'
				'511913'
				'522090'
				'533196'
				'534774'
				'544854'
				'554885'
				'555457'
				'5554570'
				);


Update [SSRSReports].[WebReportsUser].[KYC_TEMP_BIN_LIST_TRIM]
set bin_type = 'Prepaid-Other'
where issuer in ('485245'
				'414077'
				'449733'
				'46733907'
				'485280'
				'511122'
				'548917609');
*/	

IF OBJECT_ID('tempdb..#cmb_bin_list', 'U') IS NOT NULL
   drop table #cmb_bin_list;
select cast(FIIDTo as varchar(18)) as BIN, 
       FIIDHash
  into #cmb_bin_list
  from ATMManagerM_TW.dbo.T_FIID 
 where cast(FIIDTo as varchar(18)) in (select cast(BIN as varchar(18)) 
                                         from [SSRSReports].[WebReportsUser].[KYC_TEMP_BIN_LIST_TRIM]);
--627

/*************************************************************
Pull all transactions on atms with transactions
**************************************************************/

/* Due to very slow Core response times, change query from returning one large result set to 
       looping through dates and querying one day at a time, adding to temp table. Per Charles 
	   Willis, this is faster in the long run. 
	   
	   5/24/21 - took over 24 hours, not faster (unless Core is much slower than last month. 
	   Also, some anomalies in InternalID, Bancorp and Stride txns. Go back to full set processing
	   next month. */
	   
--cw: create table to load data into, looping thru settlement date
/*CREATE TABLE #txn 
    (InternalID bigint, 
	 zip5 char(5), 
	 program varchar(100), 
	 segment varchar(9), 
	 txntypeid int, 
	 settlementdate datetime,
	 activitydate datetime,	
	 BankID int, 
	 P_NetworkCode varchar(100), 
	 pan varchar(19), 
	 surcharge money, 
	 interchange money, 
	 interchangecalc money, 
	 txn bit, 
	 ATMInternalID int, 
	 Amount money, 
	 fiidfirst6digits binary(64), 
	 fiidfirst7digits binary(64), 
	 fiidfirst8digits binary(64), 
	 fiidfirst9digits binary(64), 
	 fiidfirst10digits binary(64), 
	 fiidfirst11digits binary(64), 
	 fiidfirst12digits binary(64), 
	 FIIDFirst16AndMoreDigits binary(64));

--cw: date variables
declare @LoopDate datetime
declare @EndDate datetime

Select @LoopDate = dt from #dates where varname = 'StartDate';
Select @EndDate = dt from #dates where varname = 'EndDate';

WHILE @EndDate >= @LoopDate
BEGIN
*/	
--	insert into #txn
IF OBJECT_ID('tempdb..#txn', 'U') IS NOT NULL
   drop table #txn;

declare @StartDate datetime
declare @EndDate datetime
Select @StartDate = dt from #dates where varname = 'StartDate';
Select @EndDate = dt from #dates where varname = 'EndDate';
	select t.internalid,
		   b.zip5,
		   b.program,
		   b.segment,
		   t.txntypeid, 
		   t.settlementdate,
		   t.ActivityDate,
		   t.BankID,
		   t.P_NetworkCode,
		   t.pan,                            
		   t.surcharge, 
		   t.interchange,
		   t.interchangecalc,
		   t.txn, 
		   t.ATMInternalID,
		   t.amount, 
		   f.FIIDFirst6Digits, 
		   f.FIIDFirst7Digits, 
		   f.FIIDFirst8Digits, 
		   f.FIIDFirst9Digits,
		   f.FIIDFirst10Digits, 
		   f.FIIDFirst11Digits, 
		   f.FIIDFirst12Digits, 
		   F.FIIDFirst16AndMoreDigits
	  into #txn
	  from ATMManagerM_TW.dbo.T_TxnDetail as t WITH (NOLOCK)
		   inner join #atm_with_trans as b 
			 on t.ATMInternalID = b.ATMInternalID
		   inner join ATMManagerM_TW.dbo.FIIDLookup as f with(Nolock) 
			 on t.InternalID = f.TWInternalID
	 where t.SettlementDate >= @StartDate
	   and t.SettlementDate <= @EndDate
	   and t.TxnTypeID = 1         -- Withdrawal Txn
	   and t.ResponseCodeID = 1    -- Txn Accepted
	   and t.Txn = 1               -- Is a Txn
--started 6/23/21 @ 12:37
--completed when checked at 2:16pm, run time 1:34:04 per SSMS
--7/26/21 started 4:20pm, run time 1:30:48 per SSMS
--8/26/21 run time 1:32:02 per SSMS
--9/27/21 run time 1:43:32 per SSMS, 269,945,526 rows
--10/25/21 run time 4:20:50 per SSMS, 297858389 rows, started ~ 7:00 pm
--11/15/21 run time 2:08:15, started ~ 10:45am
--12/13/21 run time 1:19:22
--1/10/22 run time 1:33:47 
--2/7/22 run time 1:33:20
--3/1/22 run time 2:13:31
--3/7/22 run time 2:55:58
--4/4/22 run time 1:59:38
--4/6/22 run time 1:30:12 
--5/6/22 run time 1:11:21
--5/23/22 run time 1:08:14
--6/21/22 run time 1:07:30
--7/18/22 run time 1:14:25
--8/22/22 run time 1:19:27
--9/21/22 run time 1:13:11
--10/17/22 run time 1:11:11
--11/15/22 run time 2:24:19
--12/11/22 run time 1:16:22
--02/04/23 run time 1:34:16
--04/0123 run time 
--253833793
/*
    Select @LoopDate = DateAdd(day,1,@LoopDate)
	
END
*/
--28 hrs 5/21/21-5/22/21

select top 1 * from #txn;

IF OBJECT_ID('SSRSReports.WebReportsUser.KYC_CASH_PROJ_#txn', 'U') IS NOT NULL
   drop table SSRSReports.WebReportsUser.KYC_CASH_PROJ_#txn;
select * 
  into SSRSReports.WebReportsUser.KYC_CASH_PROJ_#txn
  from #txn;
--17:48 run time 6/23/21
--18:16 run time 7/26/21
--26:34 run time 8/26/21
--26:57 run time 9/27/21
--26:52 run time 10/26/21
--23:55 run time 11/15/21
--19:15 run time 12/13/21
--19:20 run time 1/10/22
--24:33 run time 2/7/22
--31:04 run time 3/1/22
--25:32 run time 3/7/22
--15:41 run time 4/4/22
--11:28 run time 4/6/22
--9:15 run time 5/23/22
--11:52 run time 6/21/22
--9:31 run time 7/18/22
--10:31 run time 8/22/22
--11:10 run time 9/21/22
--10:16 run time 10/17/22
--13:03 run time 12/12/22
--21:43 run time 02/07/23


create index tmpAP1 on #txn (ATMInternalID);
create index tmpAP3 on #txn (SettlementDate);
create index tmpAP4 on #txn (ATMInternalID, SettlementDate);
--5:45 run time 6/23/21
--4:44 run time 7/26/21
--13:56 run time 8/26/21
--12:03 run time 9/27/21
--? run time 10/26/21
--20:30 run time 11/15/21
--5:23 run time 12/13/21
--6:27 run time 1/10/22
--13:50 run time 2/7/22
--9:59 run time 3/1/22
--19:42 run time 3/7/22
--11:00 run time 4/4/22
--7:47 run time 4/6/22
--6:10 run time 5/6/22
--5:10 run time 5/23/22
--6:30 run time 6/21/22
--7:36 run time 8/22/22
--7:56 run time 9/21/22
--7:27 run time 10/17/22
--8:59 run time 12/12/22
--6:32 run time 02/07/23

/*
IF OBJECT_ID('tempdb..#txn', 'U') IS NOT NULL
   drop table #txn;
select * 
  into #txn
  from SSRSReports.WebReportsUser.KYC_CASH_PROJ_#txn;
  */
/**********************************************************************************************
Match AP BINs on transactions

Note: This extended BIN matching does not take Allpoint BIN effective dates into consideration 
      due to run time of the query. As a result, all historical txns will be included in 
	  whatever BINs are currently Allpoint, even before those BINs were moved to Allpoint. 
***********************************************************************************************/
IF OBJECT_ID('tempdb..#aptrxn', 'U') IS NOT NULL
   drop table #aptrxn;
select t.internalid,
	   t.zip5,
	   t.program,
	   t.segment,
       t.txntypeid, 
       t.settlementdate,
	   t.ActivityDate,
	   t.BankID,
	   t.P_NetworkCode,
       t.pan,                            
       t.surcharge, 
       t.interchange,
       t.interchangecalc, 
       t.ATMInternalID,
       t.amount,
	   case when ISNULL(t.Surcharge,0) > 0 then 'SC' 
	        else 'SCF' 
	   end as SCvSCF,
	   case 
   		    when b12.FIIDHash is not null then 1
		    when b11.FIIDHash is not null then 1
		    when b10.FIIDHash is not null then 1
		    when b9.FIIDHash is not null then 1
		    when b8.FIIDHash is not null then 1
		    when b7.FIIDHash is not null then 1
		    when b6.FIIDHash is not null then 1
	        else 0 
		end as APBinMatch,
	    case 
  		     when b12.FIIDHash is not null then 12
		     when b11.FIIDHash is not null then 11
		     when b10.FIIDHash is not null then 10
		     when b9.FIIDHash is not null then 9
		     when b8.FIIDHash is not null then 8
		     when b7.FIIDHash is not null then 7
		     when b6.FIIDHash is not null then 6
	         else 0 
		end as APBinMatchLen,
	    case 
		     when b12.FIIDHash is not null then cast(b12.BIN as varchar(18))
		     when b11.FIIDHash is not null then cast(b11.BIN as varchar(18))
		     when b10.FIIDHash is not null then cast(b10.BIN as varchar(18))
		     when b9.FIIDHash is not null then cast(b9.BIN as varchar(18))
		     when b8.FIIDHash is not null then cast(b8.BIN as varchar(18))
		     when b7.FIIDHash is not null then cast(b7.BIN as varchar(18))
		     when b6.FIIDHash is not null then cast(b6.BIN as varchar(18))
	         else cast(t.BankID as varchar(18)) 
		end as APBinMatchBIN,
	    case when FIIDFirst16AndMoreDigits is null then 1 
		     else 0 
	    end as Hash16NullInd,
	    FIIDFirst16AndMoreDigits as hash16
  into #aptrxn
  FROM SSRSReports.WebReportsUser.KYC_CASH_PROJ_#txn t
       left JOIN #cmb_bin_list b6 WITH (NOLOCK) ON fiidfirst6digits = b6.FIIDHash --and t.SettlementDate between b6.DateStart and b6.DateEnd
       left JOIN #cmb_bin_list b7 WITH (NOLOCK) ON fiidfirst7digits = b7.FIIDHash --and t.SettlementDate between b7.DateStart and b7.DateEnd
       left JOIN #cmb_bin_list b8 WITH (NOLOCK) ON fiidfirst8digits = b8.FIIDHash --and t.SettlementDate between b8.DateStart and b8.DateEnd
       left JOIN #cmb_bin_list b9 WITH (NOLOCK) ON fiidfirst9digits = b9.FIIDHash --and t.SettlementDate between b9.DateStart and b9.DateEnd
       left JOIN #cmb_bin_list b10 WITH (NOLOCK) ON fiidfirst10digits = b10.FIIDHash --and t.SettlementDate between b10.DateStart and b10.DateEnd
       left JOIN #cmb_bin_list b11 WITH (NOLOCK) ON fiidfirst11digits = b11.FIIDHash --and t.SettlementDate between b11.DateStart and b11.DateEnd
       left JOIN #cmb_bin_list b12 WITH (NOLOCK) ON fiidfirst12digits = b12.FIIDHash --and t.SettlementDate between b12.DateStart and b12.DateEnd
--26:46 run time 6/23/21
--24:48 run time 7/26/21
--32:26 run time 8/26/21
--28:03 run time 9/27/21
--52:57 run time 10/26/21
--34:24 run time 10/27/21
--36:34 run time 11/15/21
--27:22 run time 12/13/21
--27:57 run time 1/10/22
--27:26 run time 2/7/22
--55:38 run time 3/1/22
--27:58 run time 3/7/22
--27:51 run time 4/4/22
--27:35 run time 4/6/22
--28:55 run time 5/6/22
--26:52 run time 5/23/22
--29:00 run time 6/21/22
--37:00 run time 8/22/22
--33:39 run time 9/21/22
--35:39 run time 10/17/22
--30:45 run time 12/12/22
--42:36 run time 02/07/23

create index tmpAP1 on #aptrxn (APBinMatch);
create index tmpAP2 on #aptrxn (APBinMatchBIN);
--8:18 run time 6/23/21
--9:38 run time 7/26/21
--9:33 run time 8/26/21
--13:03 run time 9/27/21
--15:24 run time 10/26/21
--14:38 run time 11/15/21
--11:37 run time 12/13/21
--13:29 run time 1/10/22
--2/7/22 dropped connection, had to restore SSRSReports.WebReportsUser.KYC_CASH_PROJ_#txn and do extended matching over again
--??? run time 2/7/22 2nd try
--38:48 run time 3/1/22
--9:27 run time 3/7/22
--10:02 run time 4/4/22
--8:41 run time 4/6/22
--8:44 run time 5/6/22
--8:02 run time 5/23/22
--7:54 run time 6/21/22
--9:57 run time 8/22/22
--9:58 run time 9/21/22
--10:58 run time 10/17/22
--8:34 run time 12/12/22
--9:48 run time 02/07/23

select top 1 * from #aptrxn;
/*************************************************************
FINAL Output
**************************************************************/

/* First, AP BINs with extended BIN matching */

 IF OBJECT_ID('SSRSReports.WebReportsUser.KYC_CASH_PROJ_2023_Finance_Data', 'U') IS NOT NULL
   drop table [SSRSReports].[WebReportsUser].[KYC_CASH_PROJ_2023_Finance_Data];
select *
  into [SSRSReports].[WebReportsUser].[KYC_CASH_PROJ_2023_Finance_Data]
  from #aptrxn 
 where APBinMatch = 1;
-- 58416723, 5:09 run time 
--72192486, 6:04 run time 8/26/21
--67335199, 5:40 run time 9/27/21
--74054853, 6:30 run time 10/26/21
--74156773, 6:13 run time 10/27/21
--71979271, 6:05 run time 11/15/21
--55461205, 4:37 run time 12/13/21
--62131872, 5:14 run time 1/10/22
--68188069, 2:00 run time 2/7/22
--66306476, 4:24 run time 3/1/22
--69110399, 2:42 run time 3/7/22
--68819362, 1:53 run time 4/4/22
--70814584, 2:32 run time 4/6/22
--68326936, 3:49 run time 5/23/22
--69483957, 1:57 run time 6/21/22
--74471620, 2:23 run time 7/18/22
--77994799, 2:09 run time 8/22/22
--79817496, 2:35 run time 9/21/22
--81340466, 3:29 run time 10/17/22
--82023046, 2:29 run time 12/12/22
--82811444, 3:35 run time 02/07/23


IF OBJECT_ID('SSRSReports.WebReportsUser.KYC_CASH_PROJ_2023_#aptrxn_0', 'U') IS NOT NULL
   drop table [SSRSReports].[WebReportsUser].[KYC_CASH_PROJ_2023_#aptrxn_0];
select *
  into [SSRSReports].[WebReportsUser].[KYC_CASH_PROJ_2023_#aptrxn_0]
  from #aptrxn 
 where APBinMatch = 0;
--168531517

select min(SettlementDate) as min, 
       max(SettlementDate) as max
  from [SSRSReports].[WebReportsUser].[KYC_CASH_PROJ_2023_Finance_Data];
/*
min						max
2022-10-23 00:00:00.000	2023-06-24 00:00:00.000
*/
 
/* since did not update the table in core
*/
select min(SettlementDate), 
       max(SettlementDate)
  from #aptrxn;
/* 
min						max
2022-10-23 00:00:00.000	2023-06-24 00:00:00.000
*/

 
select SettlementDate, 
       count(*)
  from #aptrxn
 where APBinMatch = 1
 group by SettlementDate
 order by SettlementDate;
--245 rows


select count(*) 
  from [SSRSReports].[WebReportsUser].[KYC_CASH_PROJ_2023_Finance_Data];
--86681938                                                                                                                                                                                                                                                                                                                                                             

  
/* Next, non-AP BINs: BoA, Chime, Bancorp, Comerica UI, US Bank, Cash App
   Note: Chime has several 7-digit BINs that were AP effective 5/5/21, including:
         4232230, 4985031, 4232231. There are only two 7 digit BINs under 423223 and both are AP. There
		 are also only two extended BINs under 498503 and both are AP. 
		 Prior to 5/5/21, all txns are in 6 digit non-AP BINs. 5/5/21 and after, all txns are in 
		 extended AP BINs. 
   Note: Chime closed extended BINs and enrolled 6-digit BINs in AP as of 9/1/2021 */

insert into [SSRSReports].[WebReportsUser].[KYC_CASH_PROJ_2023_Finance_Data]
select *
  from #aptrxn
 where APBinMatchBIN in (442743, 511560, 498503, 423223, 421783, 511558, 515549, 515478, 515101, 446053, 491288, 440393)
   and APBinMatch = 0;

   /*
select distinct APBinMatchBIN,APBinMatch
from [SSRSReports].[WebReportsUser].[KYC_CASH_PROJ_2023_Finance_Data]
where APBinMatchBIN in (442743, 511560, 498503, 423223, 421783, 511558, 515549, 515478, 515101, 446053, 491288, 440393)
   and APBinMatch = 0
   */

create index tmpAP1 on [SSRSReports].[WebReportsUser].[KYC_CASH_PROJ_2023_Finance_Data] (SettlementDate);
create index tmpAP2 on [SSRSReports].[WebReportsUser].[KYC_CASH_PROJ_2023_Finance_Data] (ATMInternalID, SettlementDate);

select count(*) 
  from [SSRSReports].[WebReportsUser].[KYC_CASH_PROJ_2023_Finance_Data];
--97939469


select SettlementDate, 
       count(*)
  from [SSRSReports].[WebReportsUser].[KYC_CASH_PROJ_2023_Finance_Data]
 group by SettlementDate
 order by SettlementDate;
--245 rows

/* Update non-AP BIN list to pick up txns for 421783 before it was added to AP on 9/1/21. */ 
select SettlementDate, 
       count(*)
  from [SSRSReports].[WebReportsUser].[KYC_CASH_PROJ_2023_#aptrxn_0]
 where APBinMatchBIN in (442743, 511560, 498503, 423223, 421783, 511558, 515549, 515478, 515101, 446053, 491288, 440393)
   and APBinMatch = 0
 group by SettlementDate
 order by SettlementDate;
--245 rows

/* check for duplicate internalids (happened with loop in May) */
select internalid, count(*)
from [SSRSReports].[WebReportsUser].[KYC_CASH_PROJ_2023_Finance_Data]
group by internalid
having count(*) > 1;
--0

select count(*)
from [SSRSReports].[WebReportsUser].[KYC_CASH_PROJ_2023_Finance_Data];
-- 97939469

/*
select *
  from [SSRSReports].[WebReportsUser].[KYC_CASH_PROJ_2023_Finance_Data]
 where APBinMatchBIN in (442743, 511560, 498503, 423223, 421783, 511558, 515549, 515478, 515101, 446053, 491288, 440393)
   and APBinMatch = 0;*/

--3 hr 35 mins run time 06/26/23
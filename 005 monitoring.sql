/****************************************************************
*005 monitoring.sql
*
*Daily and Cumulative forecast vs actuals for last forecast
*Run 06/26/2023. 
*
*Last Modified:    06/26/2023

****************************************************************/
/****************************************************************

Forecast period 07/02/22 - 09/23/22 (12 weeks)
[SSRSReports].[WebReportsUser].[KYC_CASH_PROJ_TERMS1_JUN4]



Note: Some terminals included in the ATMS/TERMS1 table weren't in forecast 
due to #to_del (see below). They were not in forecast file 
sent to Operations as the forecast was all zeros, perhaps due to inactivity
in the Baseline period used for the forecast. Do not include these ATMs in the 
actual data queries. 

select ATMInternalID, 
       sum(n_WD_Proj_Fin) as totWD, 
	   sum(WDAmt_Proj_Fin) as totAmt
  into #to_del
  from #all_fcst1
 group by ATMInternalID
having sum(n_WD_Proj_Fin) = 0;

or for [SSRSReports].[WebReportsUser].[KYC_CASH_PROJ_FEB13_RAW]:

select ATMInternalID, 
       sum(n_WD_Proj_Fin) as totWD, 
	   sum(WDAmt_Proj_Fin) as totAmt
  into #to_del
  from #all_fcst1
 group by ATMInternalID
having sum(n_WD_Proj_Tot) = 0;

as n_WD_Proj_Tot was added for the Child Tax Credit calculation. 
********************************************************************/

/************ Get list of ATMs  ******/
/* For the lists coming from RAW projections tables, make sure to 
   only take those with non-zero projections, as we do when loading
   projections into the spreadsheet. */
IF OBJECT_ID('tempdb..#dates', 'U') IS NOT NULL
   drop table #dates;
create table #dates
(
	varname varchar(20) primary key,
	dt datetime
);
Insert into #dates Select 'LastFcstStart', cast('2023-06-04' as date);--Start of last forecast period
Insert into #dates Select 'LastFcstEnd', cast('2023-08-26' as date);--start + 12 weeks(84 days)
Insert into #dates Select 'BaselineEnd', cast('2023-06-24' as date);--this is the closet past sat. to current date that data is available to use; usually 8 days before the FcstStart
Insert into #dates Select 'FcstStart', cast('2023-07-02' as date); --Start of this forecast period, last forecast start + 4 weeks
Insert into #dates Select 'FcstEnd', cast('2023-09-23' as date);--End of this forecast period, last forecast end + 4 weeks
select * from #dates;

IF OBJECT_ID('tempdb..#cashproj','U') IS NOT NULL
   drop table #cashproj;
select *
  into #cashproj
  from [SSRSReports].[WebReportsUser].[KYC_CASH_PROJ_JUN4_RAW];

IF OBJECT_ID('tempdb..#terms1','U') IS NOT NULL
   drop table #terms1;
select *
  into #terms1
  from SSRSReports.WebReportsUser.KYC_CASH_PROJ_TERMS1_JUN4;

IF OBJECT_ID('tempdb..#terms_all','U') IS NOT NULL
   drop table #terms_all;
select distinct ATMInternalID
  into #terms_all
  from [SSRSReports].[WebReportsUser].[KYC_CASH_PROJ_JUN4_RAW]
 group by ATMInternalID
having sum(n_WD_Proj_Fin) > 0;
--52544
create index tmpAP1 on #terms_all (ATMInternalID);

/*
IF OBJECT_ID('tempdb..#before_impute','U') IS NOT NULL
   drop table #before_impute;
select ATMInternalID, sum(n_WD_before) as n_WD_before,sum(WDAmt_before) as WDAmt_before
into #before_impute
from
(select ATMInternalID, n_WD_Proj_Fin as n_WD_before,WDAmt_Proj_Fin as WDAmt_before
from [SSRSReports].[WebReportsUser].[KYC_CASH_PROJ_ALL_FCST1]
where ForecastDate between (select dt from #dates where varname = 'LastFcstStart') and (select dt from #dates where varname = 'BaselineEnd')) a
group by ATMInternalID;

create index tmpAP1 on #before_impute (ATMInternalID);

select top 1 * from #before_impute;*/
/* Get segment counts. */
/* Note: changed segment definitions in May 2 forecast to match finance. Used to be based on BLAP, now just on 
         arrangement and program. */

select segment, 
       count(*) as n_ATMs
  from #terms1 t
 where (select sum(n_wd_proj_fin) from #cashproj
         where ATMInternalID = t.ATMInternalID) > 0
   and Arrangement in ('TURNKEY', 'CASHASSIST', 'MERCHANT FUNDED')
 group by segment
 order by segment;
/*
segment				n_ATMs
US-MS-CashManaged	5334
US-Non-MS			37974
*/


/********************************************************************************************************
Prepare data for forecast vs actual plots
********************************************************************************************************/

/* Forecast */

select a.forecastdate,
       t.segment,
       sum(a.n_WD_Proj_Fin) as n_WD_fcst,
	   sum(a.WDAmt_Proj_Fin) as WDAmt_fcst
  from #cashproj a
       inner join #terms_all b
       on a.atminternalid = b.atminternalid
	   inner join #terms1 t
	   on a.ATMInternalID = t.ATMInternalID
	   and Arrangement in ('TURNKEY', 'CASHASSIST', 'MERCHANT FUNDED')
 group by segment, forecastdate
 order by segment, forecastdate;

 
/* Build a table by ATM with latest forecast data. */ 

IF OBJECT_ID('SSRSReports.WebReportsUser.KYC_CASH_PROJ_MONITOR_ATMS', 'U') IS NOT NULL
    drop table SSRSReports.WebReportsUser.KYC_CASH_PROJ_MONITOR_ATMS;
select d.ATMInternalID, 
       ForecastDate, 
       n_WD_Proj_Fin, 
	   WDAmt_Proj_Fin
  into SSRSReports.WebReportsUser.KYC_CASH_PROJ_MONITOR_ATMS 
  from #cashproj d
       inner join #terms_all t
	   on d.ATMInternalID = t.ATMInternalID
	   inner join #terms1 o
	   on d.ATMInternalID = o.ATMInternalID
	   and Arrangement in ('TURNKEY', 'CASHASSIST', 'MERCHANT FUNDED')
	   ;
--3641820



/********************************** Actuals *********************************************/

/* Pull transactions by ATM and date. One row per combination so we can join with 
   forecast. */
   
IF OBJECT_ID('tempdb..#txn_all','U') IS NOT NULL
   drop table #txn_all;
select t.ATMInternalID, 
       cast(t.SettlementDate as date) as SettlementDate, 
	   sum(t.WithdrawTxns) as WithdrawTxns, 
	   sum(t.WithdrawAmt) as WithdrawAmt
  into #txn_all
  from [ATMManagerM].[dbo].[ATMTxnTotalsDaily] as t (nolock) 
       inner join #terms_all a 
	   on t.ATMInternalID = a.ATMInternalID
	   inner join #terms1 o
	   on t.ATMInternalID = o.ATMInternalID
	   and Arrangement in ('TURNKEY', 'CASHASSIST', 'MERCHANT FUNDED')
 where SettlementDate between (select dt from #dates where varname = 'LastFcstStart') and (select dt from #dates where varname = 'LastFcstEnd')
 and WithdrawTxns is not NULL
 group by t.ATMInternalID, t.SettlementDate;
--855958

create index tmpAP1 on #txn_all (ATMInternalID);
create index tmpAP2 on #txn_all (SettlementDate);


/* Combine adjusted forecast and actuals in one table for analysis. */
IF OBJECT_ID('tempdb..#fcst_act','U') IS NOT NULL
   drop table #fcst_act;
select f.*, 
       a.WithdrawTxns as n_WD_Act, 
	   a.WithdrawAmt as WDAmt_Act
  into #fcst_act
  from SSRSReports.WebReportsUser.KYC_CASH_PROJ_MONITOR_ATMS f
	   left join #txn_all a
       on f.ATMInternalID = a.ATMInternalID
	   and f.ForecastDate = a.SettlementDate
 where SettlementDate between (select dt from #dates where varname = 'LastFcstStart') and (select dt from #dates where varname = 'BaselineEnd');
--3641820

select top 1 * from #fcst_act;
	   
/* Aggregate values by date for plotting. */

select *, 
       n_WD_Proj - n_WD_Act as n_WD_Error, 
	   WDAmt_Proj - WDAmt_Act as WDAmt_Error, 
--	   WDAmt_Proj_Adj - WDAmt_Act as WDAmt_Adj_Error,
	   (n_WD_Proj - n_WD_Act)*1.0/n_WD_Act as n_WD_Pct_Error, 
	   (WDAmt_Proj - WDAmt_Act)/WDAmt_Act as WDAmt_Pct_Error
--	   (WDAmt_Proj_Adj - WDAmt_Act)/WDAmt_Act as WDAmt_Adj_Pct_Error
  from (select cast(a.ForecastDate as date) as SettlementDate,
			   t.segment,
			   sum(a.n_WD_Proj_Fin) as n_WD_Proj, 
			   sum(a.WDAmt_Proj_Fin) as WDAmt_Proj, 
			   Sum(n_WD_Act) as n_WD_Act,
			   Sum(WDAmt_Act) as WDAmt_Act
		  from #fcst_act a
			   inner join #terms1 t
			   on a.ATMInternalID = t.ATMInternalID
	           and Arrangement in ('TURNKEY', 'CASHASSIST', 'MERCHANT FUNDED')
		 where ForecastDate between (select dt from #dates where varname = 'LastFcstStart') and (select dt from #dates where varname = 'BaselineEnd')
		 group by t.segment, a.ForecastDate) sums
 where SettlementDate <= (select dt from #dates where varname = 'BaselineEnd')
 and WDAmt_Act>0
 order by segment, SettlementDate;

select * from #dates;

/* Terminal daily projections where actuals were greater than forecast. */
--363011

select *, 
       n_WD_Proj - n_WD_Act as n_WD_Error, 
	   WDAmt_Proj - WDAmt_Act as WDAmt_Error, 
	   case when n_WD_Act > 0 then (n_WD_Proj - n_WD_Act)*1.0/n_WD_Act else null end as n_WD_Pct_Error, 
	   case when WDAmt_Act > 0 then (WDAmt_Proj - WDAmt_Act)/WDAmt_Act else null end as WDAmt_Pct_Error
  from (select cast(a.ForecastDate as date) as SettlementDate,
			   t.ATMInternalID,
			   sum(a.n_WD_Proj_Fin) as n_WD_Proj, 
			   sum(a.WDAmt_Proj_Fin) as WDAmt_Proj, 
			   Sum(n_WD_Act) as n_WD_Act,
			   Sum(WDAmt_Act) as WDAmt_Act
		  from #fcst_act a
			   inner join #terms1 t
			   on a.ATMInternalID = t.ATMInternalID
	           and Arrangement in ('TURNKEY', 'CASHASSIST', 'MERCHANT FUNDED')
		 where ForecastDate between (select dt from #dates where varname = 'LastFcstStart') and (select dt from #dates where varname = 'LastFcstEnd')
		 group by t.ATMInternalID, a.ForecastDate) sums
 where SettlementDate <= (select dt from #dates where varname = 'LastFcstEnd')
 and (WDAmt_Proj - WDAmt_Act) > 0
 order by ATMInternalID, SettlementDate;

/* Terminal daily projects and error for every day. */
IF OBJECT_ID('tempdb..#terminal_daily_error','U') IS NOT NULL
   drop table #terminal_daily_error;
select *, 
       n_WD_Proj - n_WD_Act as n_WD_Error, 
	   WDAmt_Proj - WDAmt_Act  as WDAmt_Error, 
	   case when n_WD_Act > 0 THEN (n_WD_Proj - n_WD_Act)*1.0/n_WD_Act ELSE NULL END as n_WD_Pct_Error, 
	   case WHEN WDAmt_Act > 0 THEN (WDAmt_Proj - WDAmt_Act)/WDAmt_Act ELSE NULL END as WDAmt_Pct_Error
  into #terminal_daily_error
  from (select cast(a.ForecastDate as date) as SettlementDate,
			   t.ATMInternalID,
			   sum(a.n_WD_Proj_Fin) as n_WD_Proj, 
			   sum(a.WDAmt_Proj_Fin) as WDAmt_Proj, 
			   Sum(n_WD_Act) as n_WD_Act,
			   Sum(WDAmt_Act) as WDAmt_Act
		  from #fcst_act a
			   inner join #terms1 t
			   on a.ATMInternalID = t.ATMInternalID
	           and Arrangement in ('TURNKEY', 'CASHASSIST', 'MERCHANT FUNDED')
		 where ForecastDate between (select dt from #dates where varname = 'LastFcstStart') and (select dt from #dates where varname = 'LastFcstEnd')
		 group by t.ATMInternalID, a.ForecastDate) sums
 where SettlementDate <= (select dt from #dates where varname = 'LastFcstEnd')
 order by ATMInternalID, SettlementDate;


/* Terminal daily projects and error for every day with Terminal info. */
IF OBJECT_ID('tempdb..#terminal_daily_error2','U') IS NOT NULL
   drop table #terminal_daily_error2;
 select a.ATMInternalID, a.TerminalID,a.Arrangement, a.Program, a.RetailerType,
	b.SettlementDate,b.WDAmt_Act, b.WDAmt_Proj,b.WDAmt_Error
	 into #terminal_daily_error2
	 from #terms1 a
	 inner join #terminal_daily_error b
	 on a.ATMInternalID = b.ATMInternalID;

IF OBJECT_ID('tempdb..#terminal_error3','U') IS NOT NULL
   drop table #terminal_error3;
select a.*, 
	case when WDAmt_Act <>0 then WDAmt_Error/WDAmt_Act 
	else 1
	end as WDAmt_Error_Perc
into #terminal_error3
from
	(select ATMInternalID,TerminalID,Arrangement,Program,RetailerType,
		sum(WDAmt_Act) as WDAmt_Act,sum(WDAmt_Proj) as WDAmt_Proj,sum(WDAmt_Error) as WDAmt_Error
	from #terminal_daily_error2
	group by ATMInternalID,TerminalID,Arrangement,Program,RetailerType) a
order by a.ATMInternalID;

select * from #terminal_error3
 /*Pivot table by ATMInternal ID, SettlementDate */

DECLARE @cols NVARCHAR(MAX)

SELECT @cols = COALESCE(@cols + ',[' + CONVERT(NVARCHAR, [SettlementDate], 101) + ']',
                        '[' + CONVERT(NVARCHAR, [SettlementDate], 101) + ']')
				   FROM (SELECT DISTINCT [SettlementDate] FROM #terminal_daily_error2) PV
				  ORDER BY [SettlementDate]
				  
DECLARE @query NVARCHAR(MAX)

SET @query = '
              SELECT *
			    FROM (SELECT ATMInternalID, 
				             SettlementDate, 
							 WDAmt_Error
				        FROM #terminal_daily_error2) x
			   PIVOT (SUM(WDAmt_Error)
			          FOR [SettlementDate] IN (' + @cols + ')
					 )p
			   ORDER BY ATMInternalID
			 '
EXEC SP_EXECUTESQL @query
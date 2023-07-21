--- Availability per terminal per day in a given period (6 months from last forecast)
IF OBJECT_ID('tempdb..#dates', 'U') IS NOT NULL
   drop table #dates;
create table #dates (varname varchar(20) primary key,dt datetime);
Insert into #dates Select 'LastFcstStart', cast('2023-07-02' as date);--Start of last forecast period
Insert into #dates Select 'LastFcstEnd', cast('2023-07-04' as date);--start + 3 or 4 weeks(21 or 28 days)
Insert into #dates Select 'BaselineEnd', cast('2023-07-01' as date);--one day before fcst start
Insert into #dates Select 'HistoryStart', cast('2022-11-20' as date);--26 weeks before last fcst start
select * from #dates;


IF OBJECT_ID('tempdb..#cashproj','U') IS NOT NULL
   drop table #cashproj;
select *
  into #cashproj
  from [SSRSReports].[WebReportsUser].[KYC_CASH_PROJ_JUL2_RAW];

IF OBJECT_ID('tempdb..#terms1','U') IS NOT NULL
   drop table #terms1;
select *
  into #terms1
  from SSRSReports.WebReportsUser.KYC_CASH_PROJ_TERMS1;

IF OBJECT_ID('tempdb..#terms_all','U') IS NOT NULL
   drop table #terms_all;
select distinct ATMInternalID
  into #terms_all
  from [SSRSReports].[WebReportsUser].[KYC_CASH_PROJ_JUL2_RAW]
 group by ATMInternalID
having sum(n_WD_Proj_Fin) > 0;
--52544
create index tmpAP1 on #terms_all (ATMInternalID);

IF OBJECT_ID('tempdb..#fcst', 'U') IS NOT NULL
    drop table #fcst;
select d.ATMInternalID, 
       ForecastDate, 
       n_WD_Proj_Fin, 
	   WDAmt_Proj_Fin
  into #fcst
  from #cashproj d
       inner join #terms_all t
	   on d.ATMInternalID = t.ATMInternalID
	   inner join #terms1 o
	   on d.ATMInternalID = o.ATMInternalID
	   and Arrangement in ('TURNKEY', 'CASHASSIST', 'MERCHANT FUNDED')
where ForecastDate between (select dt from #dates where varname = 'LastFcstStart') and (select dt from #dates where varname = 'LastFcstEnd');

select top 16 * from #fcst
order by ATMInternalID, ForecastDate;

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

select top 10 * from #txn_all;



IF OBJECT_ID('tempdb..#tmp', 'U') IS NOT NULL
   drop table #tmp;
select distinct ltrim(rtrim(upper(device_id))) as device_id
into #tmp
from SSRSReports.[WebReportsUser].[OpsPLMetrics_V1] b;

create index tmpAP3 on #tmp (device_id);

--drop table #devicelink;
IF OBJECT_ID('tempdb..#devicelink', 'U') IS NOT NULL
   drop table #devicelink;
select b.device_id, loc.TerminalID, loc1.UserKeyATM, 
	case 
		when loc.TerminalID is not null then loc.ATMInternalID
		when loc1.UserKeyATM is not null then loc1.ATMInternalID
	else null end as ATMInternalID,
	coalesce(loc.ATMStatus, loc1.ATMStatus) as ATMStatus,
	coalesce(loc.DateDeinstalled, loc1.DateDeinstalled) as DateDeinstalled,
	coalesce(loc.BusUnitName, loc1.BusUnitName) as BusUnitName,
	loc2.DateStart,--updated 04/12/23
	loc2.DateEnd--updated 04/12/23
into #devicelink
from
#tmp b
left join [SSRSReports].[WebReportsUser].[OpsPLATMMaster] loc on
loc.TerminalID=b.device_id
	
left join [SSRSReports].[WebReportsUser].[OpsPLATMMaster] loc1 on
loc1.UserKeyATM=b.device_id

--upadted on 04/12/23
left join [ATMManagerM].[dbo].[ATMProcTIDXref] loc2 on
b.device_id = ltrim(rtrim(upper(loc2.ProcTermID)))

where loc.TerminalID is not null or loc1.TerminalID is not null

create index tmpAP1 on #devicelink (device_id);
create index tmpAP2 on #devicelink (ATMInternalID);
create index tmpAP3 on #devicelink (TerminalID);
create index tmpAP4 on #devicelink (UserKeyATM);

IF OBJECT_ID('tempdb..#pl', 'U') IS NOT NULL 
	drop table #pl
select t.*, 
	lnk.ATMInternalID,
	case 
		when lnk.TerminalID is not null then lnk.TerminalID
		when lnk.UserKeyATM is not null then lnk.UserKeyATM
	else null end as TerminalID,
	lnk.ATMStatus,
	lnk.DateStart,--updated 04/12/23
	lnk.DateEnd --updated 04/12/23
	--case 
		--when t.impact_date >= lnk.DateStart and t.impact_date < lnk.DateEnd then 'Active'--updated 04/13/23
		--when t.impact_date >= lnk.DateStart and lnk.DateEnd is NULL then 'Active'--updated 04/13/23
	--else 'Inactive'
	--end as Date_Active
into #pl
from SSRSReports.[WebReportsUser].[OpsPLMetrics_V1] t
inner join #devicelink lnk on
ltrim(rtrim(upper(t.device_id)))=lnk.device_id
inner join SSRSReports.WebReportsUser.KYC_CASH_PROJ_TERMS1_MAY7 z
on lnk.ATMInternalID = z.ATMInternalID
where lnk.BusUnitName='US'
and lnk.ATMInternalID is not null
and (impact_date >= (select dt from #dates where varname = 'HistoryStart') and impact_date <= '2022-11-19')
		   or (impact_date >= '2023-03-19' and impact_date <= (select dt from #dates where varname = 'BaselineEnd'));

select top 10 * from #pl;
select min(impact_date) from #pl;


IF OBJECT_ID('tempdb..#history', 'U') IS NOT NULL 
	drop table #history
select f.ATMInternalID, 
               SettlementDate, 
			   datepart(weekday, SettlementDate) as DayOfWeek,        
	           sum(WithdrawTxns) as n_WD, 
	           sum(WithdrawAmt) as WDAmt,
			   avg(NULLIF(Availability,0)) as daily_availability
into #history
          from ATMManagerM.dbo.ATMTxnTotalsDaily f WITH (NOLOCK) 
				inner join 
					(select ATMInternalID,impact_date,
					(Peripheral_Down_s + Receipt_Printer_Down_s+Available_s)/Total_Prime_Seconds as Availability
					from #pl) b
				on f.ATMInternalID = b.ATMInternalID
				and f.SettlementDate = b.impact_date
--			   inner join #terms1 t
--			   on f.ATMInternalID = t.ATMInternalID
		 where f.ATMInternalID in (select ATMInternalID from SSRSReports.WebReportsUser.KYC_CASH_PROJ_TERMS1_MAY7)
		   and (impact_date >= (select dt from #dates where varname = 'HistoryStart') and impact_date <= '2022-11-19')
		   or (impact_date >= '2023-03-19' and impact_date <= (select dt from #dates where varname = 'BaselineEnd'))
		 group by f.ATMInternalID, SettlementDate;

-- store it the renewed data:
select min(SettlementDate) from #history;
	
IF OBJECT_ID('tempdb..#history2','U') IS NOT NULL
    drop table #history2
select *,avg(daily_availability) over(partition by ATMInternalID) as avg_daily_availability,
STDEV(daily_availability) over(partition by ATMInternalID) as std_daily_availability
into #history2
from #history
order by ATMInternalID,SettlementDate;

select top 10 * from #history2;

/*
-- create table:
select *
into SSRSReports.WebReportsUser.KYC_CASH_PROJ_ATM_AVG_HISTORY
from #history2;
*/
select top 10 * from SSRSReports.WebReportsUser.KYC_CASH_PROJ_ATM_AVG_HISTORY;

IF OBJECT_ID('SSRSReports.WebReportsUser.KYC_CASH_PROJ_ATM_AVG_HISTORY','U') IS NOT NULL
	delete from SSRSReports.WebReportsUser.KYC_CASH_PROJ_ATM_AVG_HISTORY
	where SettlementDate >= (select dt from #dates where varname = 'HistoryStart');

Insert into SSRSReports.WebReportsUser.KYC_CASH_PROJ_ATM_AVG_HISTORY
select *
from #history2;

select top 100 * from SSRSReports.WebReportsUser.KYC_CASH_PROJ_ATM_AVG_HISTORY
order by ATMInternalID,SettlementDate;

IF OBJECT_ID('tempdb..#atm_historical_avgs','U') IS NOT NULL
    drop table #atm_historical_avgs
select ATMInternalID, 
       DayOfWeek, 
	    /* Use NULLIF(  ,0) to replace zeros with NULLS so the 0s don't dilute the average.*/
	   cast(round(avg(NULLIF(n_WD,0)),0) as int) as avg_daily_n_wd, 
	   cast(round(STDEV(NULLIF(n_WD,0)),0) as int) as std_daily_n_wd, 
	   cast(round(avg(NULLIF(WDAmt,0)),0) as int) as avg_daily_wdamt, 
	   cast(round(STDEV(NULLIF(WDAmt,0)),0) as int) as std_daily_wdamt, 
	   avg(avg_daily_availability) as avg_daily_availability
  into #atm_historical_avgs	   
from #history2 history
where daily_availability between avg_daily_availability-2*std_daily_availability and avg_daily_availability+2*std_daily_availability -- 95.4% coverage without outliers
 group by ATMInternalID, DayOfWeek;

 select * from #atm_historical_avgs
 order by ATMInternalID, DayOfWeek;

select min(avg_daily_availability) from #atm_historical_avgs;
 
 IF OBJECT_ID('SSRSReports.WebReportsUser.KYC_CASH_PROJ_ATM_AVGS','U') IS NOT NULL
    drop table SSRSReports.WebReportsUser.KYC_CASH_PROJ_ATM_AVGS
select * 
	into SSRSReports.WebReportsUser.KYC_CASH_PROJ_ATM_AVGS
from #atm_historical_avgs;

/*--------------------------------------------------------------------*/
/* -----------------------PART II------------------------*/
/*--------------------------------------------------------------------*/
-- compare to forecast
/* Combine adjusted forecast and actuals in one table for analysis. */

IF OBJECT_ID('tempdb..#fcst_act_his','U') IS NOT NULL
   drop table #fcst_act_his;
select f.*, h.DayOfWeek,
       a.WithdrawTxns as n_WD_Act, 
	   a.WithdrawAmt as WDAmt_Act,
	   h.avg_daily_n_wd,
	   h.avg_daily_wdamt,
	   h.std_daily_n_wd,
	   h.std_daily_wdamt,
	   cast(round(avg_daily_n_wd - 1.96*std_daily_n_wd,0) as int) as lower_n_WD_CI,
	   cast(round(avg_daily_wdamt + 1.96*std_daily_n_wd,0) as int) as upper_n_WD_CI,
	   round(avg_daily_n_wd - 1.645*std_daily_wdamt,0) as lower_WDA_CI,
	   round(std_daily_wdamt + 1.645*std_daily_wdamt,0) as upper_WDA_CI
  into #fcst_act_his
  from #fcst f
	   left join #txn_all a
       on f.ATMInternalID = a.ATMInternalID
	   and f.ForecastDate = a.SettlementDate
	   left join #atm_historical_avgs h
	   on h.ATMInternalID = f.ATMInternalID
	   and h.DayOfWeek = datepart(weekday, f.ForecastDate)
where SettlementDate between (select dt from #dates where varname = 'LastFcstStart') and (select dt from #dates where varname = 'LastFcstEnd')
and DayOfWeek is not null
and f.ATMInternalID is not null;

select top 10 * from #fcst_act_his;

-- store the history error to permanent table:
	IF OBJECT_ID('tempdb..#fcst_act_his2','U') IS NOT NULL
	   drop table #fcst_act_his2;
	select ATMInternalID,ForecastDate,
			DayOfWeek,
			WDAmt_Proj_Fin,
			WDAmt_Act,
			avg_daily_wdamt,
			std_daily_wdamt
	into #fcst_act_his2
	from #fcst_act_his
	order by ATMInternalID, ForecastDate;

	select top 10 * from #fcst_act_his2;

/*
-- create table:
select * 
into SSRSReports.WebReportsUser.KYC_CASH_PROJ_ATM_HISTORY_ERROR
from #fcst_act_his2;*/
select top 10 * from SSRSReports.WebReportsUser.KYC_CASH_PROJ_ATM_HISTORY_ERROR;
select min(ForecastDate) from SSRSReports.WebReportsUser.KYC_CASH_PROJ_ATM_HISTORY_ERROR;
select max(ForecastDate) from SSRSReports.WebReportsUser.KYC_CASH_PROJ_ATM_HISTORY_ERROR;
select min(ForecastDate) from #fcst_act_his2;

IF OBJECT_ID('SSRSReports.WebReportsUser.KYC_CASH_PROJ_ATM_HISTORY_ERROR','U') IS NOT NULL
	delete from SSRSReports.WebReportsUser.KYC_CASH_PROJ_ATM_HISTORY_ERROR
	where ForecastDate >= (select dt from #dates where varname = 'LastFcstStart');

Insert into SSRSReports.WebReportsUser.KYC_CASH_PROJ_ATM_HISTORY_ERROR
select *
from #fcst_act_his2;
/*
-- By ATMID by Day of Week:
select ATMInternalID, DateName(Weekday, ForecastDate) as WeekDay,DayOfWeek,
	--avg(n_WD_Proj_Fin) as n_WD_Proj_Fin,
	--avg(n_WD_Act) as n_WD_Act, avg(avg_daily_n_wd) as avg_daily_n_wd,
	avg(WDAmt_Proj_Fin) as WDAmt_Proj_Fin,
	avg(WDAmt_Act) as WDAmt_Act,
	avg(avg_daily_wdamt) as avg_daily_wdamt,
	avg(std_daily_wdamt) as std_daily_wdamt
from #fcst_act_his
group by ATMInternalID,DateName(Weekday, ForecastDate),DayOfWeek
order by ATMInternalID,DayOfWeek;

select ATMInternalID,DayOfWeek,
		--avg(n_WD_Proj_Fin) as n_WD_Proj_Fin,
		avg(WDAmt_Proj_Fin) as WDAmt_Proj_Fin,
		--avg(avg_daily_n_wd) as avg_n_wd,
		avg(avg_daily_wdamt) as avg_wdamt,
		--avg(NULLIF((n_WD_Proj_Fin-avg_daily_n_wd)/avg_daily_n_wd,1)) as expected_n_WD_error_perc,
		avg(std_daily_wdamt) as std_daily_wdamt
	from #fcst_act_his 
	group by ATMInternalID,DayOfWeek
	order by ATMInternalID,DayOfWeek;*/

IF OBJECT_ID('tempdb..#sum1','U') IS NOT NULL
   drop table #sum1;
select a.ATMInternalID,
		--avg(n_WD_Proj_Fin) as n_WD_Proj_Fin,
		avg(a.WDAmt_Proj_Fin) as WDAmt_Proj_Fin,
		--avg(avg_n_wd) as avg_n_wd,
		avg(a.WDAmt_Act) as WDAmt_Act,
		avg(a.avg_wdamt) as avg_wdamt,
		avg(a.std_daily_wdamt) as std_daily_wdamt,
--		NULLIF(avg(std_daily_wdamt)/avg(avg_wdamt),0) as std_daily_wdamt_perc
--		NULLIF(avg(WDAmt_Proj_Fin)/avg(WDAmt_Act) -1,0) as recent_error_rate,
--		case when (avg(WDAmt_Act) >=avg(avg_wdamt)-avg(std_daily_wdamt) 
--			and avg(WDAmt_Act) <=avg(avg_wdamt)-avg(std_daily_wdamt)) 
--			then NULLIF(avg(WDAmt_Proj_Fin)/avg(WDAmt_Act) -1,0)
--			else NULLIF(avg(WDAmt_Proj_Fin)/avg(avg_wdamt) -1,0)
--		end as adj_error_rate
		avg(c.WDAmt_Proj_Fin)  as WDAmt_Proj_His,
		avg(c.WDAmt_Act) as WDAmt_Act_His--,
		--nullif((avg(c.WDAmt_Proj_Fin)- avg(c.WDAmt_Act))/avg(c.WDAmt_Act),0) as avg_error_rate_his
into #sum1
from (
		select ATMInternalID,DayOfWeek,
			avg(WDAmt_Proj_Fin) as WDAmt_Proj_Fin,
			avg(WDAmt_Act) as WDAmt_Act,
			avg(avg_daily_wdamt) as avg_wdamt,
			avg(std_daily_wdamt) as std_daily_wdamt
		from #fcst_act_his2
		group by ATMInternalID,DayOfWeek) a
	left join 
	(select ATMInternalID,DayOfWeek,
				avg(WDAmt_Proj_Fin) as WDAmt_Proj_Fin,
				avg(WDAmt_Act) as WDAmt_Act
			from SSRSReports.WebReportsUser.KYC_CASH_PROJ_ATM_HISTORY_ERROR
			group by ATMInternalID,DayOfWeek ) c
	on a. ATMInternalID = c.ATMInternalID
group by a.ATMInternalID
order by a.ATMInternalID;


select * from #sum1;
-- output:
select ATMInternalID, WDAmt_Proj_Fin,WDAmt_Act,avg_wdamt,std_daily_wdamt from #sum1;

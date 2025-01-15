


declare @maxDistance as int  , @empId as int ,@fromDate varchar(10) , @toDate varchar(10) , @fromDate1 varchar(10) , @toDate1 varchar(10)

set @empId = -1 
set @maxDistance=300
set @fromDate1='1403/08/01'
set @toDate1 = '1403/08/30'
-- بدست اوردن روز قبل و روز بعد بازه تاریخی 
set @fromDate = (select [per].[CalcYesterdayShamsi](@fromDate1))
set @toDate  = ( select [per].[CalcTomorrowShamsi]( @toDate1 ))


-- استخراج فرم کارها برای این تاریخ
create table #myFormWork(
	Id int,
	EmpIdRef varchar(10),
	Stime varchar(10),
	EndTime varchar(10),
	EzafeKAr varchar(10),
	Dsc varchar(1000),
	FormDate varchar(10),
	Distance int,
	prjCode varchar(20),
	Tomorrow varchar(10),
	YesterDay varchar(10),
	CityName  varchar(40),
	HarkatHamanRoz bit,
	Mission int,
	IsMission bit
)
insert into   #myFormWork(Id , EmpIdRef , Stime , EndTime , EzafeKAr , Dsc , FormDate , Distance , prjCode , CityName  , HarkatHamanRoz, Tomorrow , YesterDay , Mission , IsMission)
select  w.Srl , w.Srl_Pm_Ashkhas  
,CASE WHEN LEN(RIGHT(BeginWorkSat, CHARINDEX(':', REVERSE(BeginWorkSat)) - 1)) = 1 THEN LEFT(BeginWorkSat, CHARINDEX(':', BeginWorkSat)) + '0' + RIGHT(BeginWorkSat, CHARINDEX(':', REVERSE(BeginWorkSat)) - 1) ELSE BeginWorkSat END AS BeginWorkSat
,CASE WHEN LEN(RIGHT(EndWorkSat, CHARINDEX(':', REVERSE(EndWorkSat)) - 1)) = 1 THEN LEFT(EndWorkSat, CHARINDEX(':', EndWorkSat)) + '0' + RIGHT(EndWorkSat, CHARINDEX(':', REVERSE(EndWorkSat)) - 1) ELSE EndWorkSat END AS EndWorkSat
,CASE WHEN LEN(RIGHT(EzafeKAr, CHARINDEX(':', REVERSE(EzafeKAr)) - 1)) = 1 THEN LEFT(EzafeKAr, CHARINDEX(':', EzafeKAr)) + '0' + RIGHT(EzafeKAr, CHARINDEX(':', REVERSE(EzafeKAr)) - 1) ELSE EzafeKAr END AS EzafeKAr
, w.WorkFormDis    , w.WorkFormTarikh  , d.Distance , w.Srl_HazineCode   
 , p.Name as CityName ,w.HarkatHamanRoz as HarkatHamanRoz ,   (select [per].[CalcTomorrowShamsi](w.WorkFormTarikh)) as Tomorrow ,(select [per].[CalcYesterdayShamsi](w.WorkFormTarikh)) as YesterDay , 1 , case when d.distance >= 50 then 1 else 0 end
from per.WorkForm as w
join per.pm_Distance as d
on d.Srl_Post1 = w.Srl_Pm_Post_From and d.Srl_Post2 = w.Srl_Pm_Post_To
join  per.Pm_post as p
on p.Srl = w.Srl_Pm_Post_To
where  w.WorkFormTarikh between @fromDate and @toDate and (Srl_Pm_Ashkhas=@empId or @empId=-1)
order by WorkFormTarikh



-- بدست آوردن روزهایی که فرم کار پر کرده به همراه ماکس فاصله و مین ساعت شروع و تاریخ فردا و دیروز

;WITH AggregatedData AS ( SELECT EmpIdRef, YesterDay, MAX(Distance) AS distance, FormDate, Tomorrow,
SUM( ISNULL( CAST(SUBSTRING(ezafekar, 0, CHARINDEX(':', ezafekar)) AS INT) * 60 + CAST(SUBSTRING(ezafekar, CHARINDEX(':', ezafekar) + 1, LEN(ezafekar)) AS INT), 0) ) AS SumEzafe_FormWork,
MAX(CAST(HarkatHamanRoz AS TINYINT)) AS HarkatHamanRoz,
max(CAST(replace(EndTime, ':','') as int)) as EndTimeMax ,
min( CAST(replace(REPLACE(STime , ':','') , '/','') as int)) as STimeMin  
FROM #myFormWork GROUP BY EmpIdRef, YesterDay, FormDate, Tomorrow ) SELECT  EmpIdRef, YesterDay, distance as maxDistance, FormDate, 
Tomorrow, SumEzafe_FormWork, HarkatHamanRoz , EndTimeMax , STimeMin , 1 as HasFormWork , 0 as IsMission  into #DistanceTbl FROM AggregatedData ORDER BY FormDate;

update #DistanceTbl set IsMission = 1 where maxDistance >= 50


 -------------------------------------------------------------------------------
-- ایجاد جدول بدست امده برای روزهای بعداز فرم کارو تشخیص اینکه ایا فردا امده شرکت یا ن
select  dt.* , 
case when (maxDistance >= @maxDistance) then 1
	 when EndTimeMax >= 1600 and maxDistance>=140 then 1
	 else 0 end as CanBackToday,
case when dt.maxDistance>=@maxDistance then 1  when (dt.maxDistance>=140 and dt.maxDistance<@maxDistance) then 0.5 else 0 end as TMission  into #TomorrowTbl1
from  #DistanceTbl as dt
left join #myFormWork as f
on dt.EmpIdRef=f.EmpIdRef and dt.Tomorrow=f.FormDate
where f.FormDate is null 

-- ایجاد جدول بدست امده برای روزهای قبل از فرم کار و تشخیص ساعت شروع قبل از هشت و مسافت بالای صدوچهل
select   dt.* , case when dt.HarkatHamanRoz = 0 then 1 else 0 end as OnDestination  , 0.5 as YMission   into #YesterDayTbl
from  #DistanceTbl as dt
left join #myFormWork as f
on dt.EmpIdRef=f.EmpIdRef and dt.YesterDay=f.FormDate
where f.FormDate is null and dt.STimeMin<=800 and dt.maxDistance>=140

delete from #DistanceTbl where IsMission=0

select 
	d.EmpIdRef
	,p.PersonalCode
	,p.Name
	,p.Family
	,d.FormDate
	,s.ShamsiDayName
	,d.maxDistance
	,RIGHT('0' + CAST(CAST(d.STimeMin / 100 AS VARCHAR(2)) AS VARCHAR(2)), 2) + ':' + RIGHT('0' + CAST(CAST(d.STimeMin % 100 AS VARCHAR(2)) AS VARCHAR(2)), 2) as StartTimeMin
	,RIGHT('0' + CAST(CAST(d.EndTimeMax / 100 AS VARCHAR(2)) AS VARCHAR(2)), 2) + ':' + RIGHT('0' + CAST(CAST(d.EndTimeMax % 100 AS VARCHAR(2)) AS VARCHAR(2)), 2) as EndTimeMax
	,d.HarkatHamanRoz
	,(1 + ISNULL(YMission,0) + ISNULL(TMission , 0)) as SumOfMission
	into #MissionCalced
	from #DistanceTbl as d
left join #YesterDayTbl as y
on y.FormDate = d.FormDate and y.EmpIdRef=d.EmpIdRef
left join #TomorrowTbl1 as t
on t.FormDate = d.FormDate and t.EmpIdRef=d.EmpIdRef
left join per.ShamsiCallender as s
on s.ShamsiDate=d.FormDate
left join per.Employee as p
on p.Id = d.EmpIdRef
where d.FormDate between @fromDate1 and @toDate1 
order by EmpIdRef , d.FormDate


-----------------------------------------------------------------------------------
SELECT DISTINCT   Srl_Pm_Ashkhas,WorkFormTarikh ,pf.ostan AS FOstan,pt.ostan  AS TOstan, CAST('' AS VARCHAR(200) ) PostFrom,CAST('' AS VARCHAR(200) ) PostTo  INTO #m  
FROM per.WorkForm wf JOIN  
  per.Pm_PostOstanDetailes as pf   on pf.Srl = wf.Srl_Pm_Post_from  JOIN   
  per.Pm_PostOstanDetailes as pt   on pt.Srl = wf.Srl_Pm_Post_to
WHERE wf.WorkFormTarikh   between @fromDate and @toDate  AND ( pt.Srl_Pm_Ostan IN (4,5)  OR pf.Srl_Pm_Ostan IN (4,5))    



UPDATE m SET  postFrom =w.Srl_Pm_Post_From,PostTo=w.Srl_Pm_Post_To  FROM #m m 
JOIN per.WorkForm w 
ON w.WorkFormTarikh =m.WorkFormTarikh AND w.Srl_Pm_Ashkhas = m.Srl_Pm_Ashkhas

SELECT * FROM  #MissionCalced s  LEFT JOIN  #m m   ON s.EmpIdRef=m.Srl_Pm_Ashkhas  AND s.FormDate COLLATE SQL_Latin1_General_CP1256_CI_AS = m.WorkFormTarikh COLLATE SQL_Latin1_General_CP1256_CI_AS


drop table #myFormWork
drop table #DistanceTbl
drop table #TomorrowTbl1
drop table #YesterDayTbl
drop table #m
drop table #MissionCalced


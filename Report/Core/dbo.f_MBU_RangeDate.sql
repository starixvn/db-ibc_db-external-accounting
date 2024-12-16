/*<info serverAlias="DBAGE-bodb02,DBACC-bodb02" selecters="wsv_xnap,wsv_nap,wsv_alp,wsv_alpv" isFunction="1" isNested="0"></info>*/
ALTER FUNCTION dbo.f_MBU_RangeDate(@FromDate SMALLDATETIME, @ToDate SMALLDATETIME, @BalanceUpDay SMALLDATETIME, @MoveBetsDay SMALLDATETIME)
/*  
	Created: 20241216@Bobby 
	Task : Credit - MBU Date Range selection
	DB: DBAGE/bodb02  
  
	Revisions:
		- 20241216@Bobby: Initialize SP [Redmine: #215182]

	Param's Explanation:
		- RangeType: MBU routine [1:active, 2:_14, 3:bk]
*/
RETURNS TABLE
AS 
RETURN(
	SELECT rd.FromDate,rd.ToDate,rd.RangeType
	FROM (VALUES(@FromDate, @ToDate, @BalanceUpDay, @MoveBetsDay)) AS t(FromDate,ToDate, BU, MB)
	OUTER APPLY (
		VALUES
			(IIF(ToDate > MB, IIF(FromDate<=MB, DATEADD(DAY, 1, MB), FromDate), NULL), IIF(ToDate > MB, ToDate, NULL),1),
			(IIF(FromDate <= MB AND ToDate >= BU, IIF(FromDate <= BU, BU, FromDate), NULL), IIF(ToDate >= MB, MB, ToDate),2),
			(IIF(FromDate < BU, FromDate, NULL), IIF(ToDate >= BU, DATEADD(DAY, -1, BU), ToDate), 3)
	) AS rd(FromDate,ToDate,RangeType)
	WHERE t.FromDate <= t.ToDate
		AND rd.FromDate IS NOT NULL
)
GO

/*<info serverAlias="DBAGE-bodb02" executers="bodbExtAccNet" isFunction="0" isNested="0"></info>*/
CREATE PROCEDURE [dbo].[EAS_Rpt_OandaExchangeRate]
	@FromDate SMALLDATETIME
	,@ToDate SMALLDATETIME
	,@GroupName	VARCHAR(50)
AS
/*  
	Created: 20231204@Lewis  
	Task: Ext NAP - Report Oanda Exchange Rate from customers in the group
	DB: DBAGE.bodb02  
  
	Revisions:
		- 20231204@Lewis: Initialize SP [Redmine: #196959]
*/

;WITH cte_wld AS
	(
		SELECT @FromDate AS winlostdate
		UNION ALL
		SELECT DATEADD(DD, 1, winlostdate) 
		FROM cte_wld
		WHERE winlostdate < @ToDate
	),cte_CurrencyList AS
	(
		SELECT DISTINCT 
			wld.winlostdate
			,ci.currency AS CurrencyId
			,e.currency AS CurrencyName
		FROM Acc_CustGroup cg WITH (NOLOCK)
		INNER JOIN custInfo ci WITH (NOLOCK) ON cg.custid = ci.custid
		INNER JOIN Exchange e WITH (NOLOCK) ON ci.currency = e.ExchangeId
		CROSS APPLY cte_wld wld
		WHERE cg.GroupName = @GroupName
	)
	SELECT 
		A.ExchangeDate
		,B.CurrencyId
		,B.CurrencyName
		,CASE WHEN A.ExchangeId = 67 THEN Myr.Code ELSE A.Code END AS CurrencyCode --HKK - ExchangeId 67 --> get MYR - ExchangeId 2
		,CASE WHEN A.ExchangeId = 67 THEN Myr.MYR ELSE A.MYR END AS 'MYR/Unit'
		,CASE WHEN A.ExchangeId = 67 THEN Myr.CNY ELSE A.CNY END AS 'CNY/Unit'
		,CASE WHEN A.ExchangeId = 67 THEN Myr.THB ELSE A.THB END AS 'THB/Unit'
		,CASE WHEN A.ExchangeId = 67 THEN Myr.IDR ELSE A.IDR END AS 'IDR/Unit'
	FROM ExchangeDailyOanda A WITH (NOLOCK)
	CROSS APPLY (
					SELECT *
					FROM ExchangeDailyOanda EDO WITH (NOLOCK)
					WHERE EDO.ExchangeId = 2 
						AND EDO.ExchangeDate = A.ExchangeDate
				) Myr
	INNER JOIN cte_CurrencyList B
		ON A.ExchangeId = B.CurrencyId
		AND A.ExchangeDate = B.winlostdate
	OPTION (MAXRECURSION 0);




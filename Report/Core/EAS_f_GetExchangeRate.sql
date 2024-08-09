/*<info serverAlias="DBAGE-bodb02,DBBOF-bodb02" selecters="wsv_xnap" isFunction="1" isNested="0"></info>*/
ALTER FUNCTION EAS_f_GetExchangeRate
(
	@FromDate SMALLDATETIME
	,@ToDate SMALLDATETIME
	,@GroupName	VARCHAR(50)
	,@BaseCurrency INT
)
/*  
	Created: 20231204@Lewis 
	Task : Ext NAP - Get exchange rate by Base Currency
	DB: DBAGE/bodb02  
  
	Revisions:
		- 20231204@Lewis: Initialize SP [Redmine: #196959]
		- 20240718@Bobby: Implement match winloss reports [RedmineID : #205355]

	Param's Explanation:
		@BaseCurrency:  0 unchecked
						1 MYR
						2 CNY
						3 THB
						4 IDR
*/
RETURNS TABLE 
AS
RETURN 
(
	WITH cte_wld AS
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
		,CASE WHEN A.ExchangeId = 67 THEN Aa.Code ELSE A.Code END AS Code
		,CASE 
			WHEN @BaseCurrency = 1 AND A.ExchangeId = 67 THEN Aa.MYR --HKK - ExchangeId 67 --> get MYR - ExchangeId 2
			WHEN @BaseCurrency = 1 THEN A.MYR
			WHEN @BaseCurrency = 2 AND A.ExchangeId = 67 THEN Aa.CNY
			WHEN @BaseCurrency = 2 THEN A.CNY
			WHEN @BaseCurrency = 3 AND A.ExchangeId = 67 THEN Aa.THB
			WHEN @BaseCurrency = 3 THEN A.THB
			WHEN @BaseCurrency = 4 AND A.ExchangeId = 67 THEN Aa.IDR
			WHEN @BaseCurrency = 4 THEN A.IDR
			WHEN @BaseCurrency = 0 THEN 1
		END AS Rate
	FROM ExchangeDailyOanda A WITH (NOLOCK)
	CROSS APPLY (
					SELECT *
					FROM ExchangeDailyOanda EDO WITH (NOLOCK)
					WHERE EDO.ExchangeId = 2 
						AND EDO.ExchangeDate = A.ExchangeDate
				) Aa
	INNER JOIN cte_CurrencyList B
		ON A.ExchangeId = B.CurrencyId
		AND A.ExchangeDate = B.winlostdate 
)
GO



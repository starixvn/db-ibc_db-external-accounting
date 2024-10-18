/*<info serverAlias="DBAGE-bodb02,DBBOF-bodb02" selecters="wsv_xnap" isFunction="1" isNested="0"></info>*/
ALTER FUNCTION EAS_f_GetDailyExchangeRate
(
	@FromDate SMALLDATETIME
	,@ToDate SMALLDATETIME
	,@GroupName	VARCHAR(50)
	,@CurrencyCode VARCHAR(5)
)
/*  
	Created: 205355@Bobby 
	Task : Ext NAP - Get exchange rate by Base Currency
	DB: DBAGE/bodb02  
  
	Revisions:
		- 20240718@Bobby: Initialize SP [Redmine: #205355]

	Param's Explanation:
		@CurrencyCode:  MYR|CNY|THB|IDR
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
	),
	cte_CurrencyList AS
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
		,A.Code
		,CASE 
			WHEN @CurrencyCode = 'MYR' THEN A.MYR
			WHEN @CurrencyCode = 'CNY' THEN A.CNY
			WHEN @CurrencyCode = 'THB' THEN A.THB
			WHEN @CurrencyCode = 'IDR' THEN A.IDR
			ELSE 1
		END AS Rate
	FROM dbo.ExchangeDailyOanda A WITH (NOLOCK)
	INNER JOIN cte_CurrencyList B
		ON A.ExchangeId = B.CurrencyId
		AND A.ExchangeDate = B.winlostdate 
)
GO

/*<info serverAlias="DBAGE-bodb02" executers="wsv_xnap" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[EAS_GetCurrencyList]
	@GroupName	VARCHAR(50) = ''
AS
/*  
	Created: 20231204@Lewis  
	Task: Ext NAP - Get all currencies from customers in the group
	DB: DBAGE.bodb02  
  
	Revisions:
		- 20231204@Lewis: Initialize SP [Redmine: #196959]
		- 20240718@Bobby: Implement match winloss reports [RedmineID : #205355]
*/

BEGIN
	SET NOCOUNT ON;

	SELECT DISTINCT 
		e.ExchangeId	AS CurrencyId
		,e.currency		AS CurrencyName
	FROM dbo.Acc_CustGroup cg WITH (NOLOCK)
		INNER JOIN dbo.custInfo ci WITH (NOLOCK) ON cg.custid = ci.custid
		INNER JOIN dbo.Exchange e WITH (NOLOCK)	ON ci.Currency = e.ExchangeId
		WHERE cg.GroupName = @GroupName
	ORDER BY e.Currency
END









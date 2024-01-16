/*<info serverAlias="DBAGE-bodb02" executers="bodbExtAccNet" isFunction="0" isNested="0"></info>*/
CREATE PROCEDURE [dbo].[EAS_GetCurrencyList]
	@GroupName	VARCHAR(50)
AS
/*  
	Created: 20231204@Lewis  
	Task: Ext NAP - Get all currencies from customers in the group
	DB: DBAGE.bodb02  
  
	Revisions:
		- 20231204@Lewis: Initialize SP [Redmine: #196959]
*/



IF ISNULL(@GroupName,'') <> ''
BEGIN
	IF EXISTS (SELECT TOP 1 1 FROM Acc_CustGroup WITH (NOLOCK) WHERE GroupName = @GroupName)
	BEGIN
		CREATE TABLE #tmp_cust (custid INT, CurrencyId INT)
	
		INSERT INTO #tmp_cust (custid,CurrencyId)
		SELECT cg.CustID,ci.currency
		FROM Acc_CustGroup cg WITH (NOLOCK)
		INNER JOIN custInfo ci WITH (NOLOCK) ON cg.custid = ci.custid
		WHERE cg.GroupName = @GroupName

		SELECT DISTINCT 
			c.CurrencyId
			,e.currency AS CurrencyName
		FROM #tmp_cust c
		INNER JOIN Exchange e WITH (NOLOCK)
			ON c.CurrencyId = e.ExchangeId
		ORDER BY CurrencyName

		DROP TABLE #tmp_cust
	END	
END








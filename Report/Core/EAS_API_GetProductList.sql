/*<info serverAlias="DBAGE-bodb02" executers="wsv_xnap" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[EAS_API_GetProductList]
	@SiteName	VARCHAR(30) = 'yOther',
	@Currency	INT = 20
AS

/*  
	Created: 20240624@Bobby  
	Task: Ext NAP - Get all enabled products
	DB: DBAGE.bodb02  
  
	Revisions:
		- 20240624@Bobby: Initialize SP [Redmine: #206055]
		- 20250326@Bobby: 3rdProduct-Integration [RedmineID: #221188]
*/

BEGIN
	SET NOCOUNT ON;

	DROP TABLE IF EXISTS #ProductList;
	CREATE TABLE #ProductList (
		 ProductID TINYINT PRIMARY KEY
		,ProductName VARCHAR(50)
		,IsHidden BIT
		,EndOfSupportDate DATE
		,OrderNo INT
		,[Type] TINYINT
	);

	----Check testing environment
	DECLARE @isTest BIT = 0
	SELECT  @isTest = dbo.f_CheckSPVersion(@@PROCID);

	-- TODO: Call Age_GetOfferedProductBySiteCurrency
	INSERT INTO #ProductList
	EXEC [dbo].[Age_GetOfferedProductBySiteCurrency] @Site = @SiteName,	@Currency = @Currency, @SettingStatus = @isTest;


	--TODO: Merge product code & check IsHidden
	SELECT t.ProductID
		   ,t.ProductName
		   ,p.ProductPrefix AS ProductCode
	FROM #ProductList t	
	INNER JOIN dbo.Products p WITH (NOLOCK) ON p.ProductID = t.ProductID
	WHERE t.IsHidden = 0
	ORDER BY t.OrderNo ASC
	
END
GO
/*<info serverAlias="DBAGE-bodb02" executers="wsv_xnap" isFunction="0" isNested="0"></info>*/
CREATE PROCEDURE [dbo].[EAS_GetProductList]
	@GroupName	VARCHAR(50) = NULL,
	@Products	NVARCHAR(MAX) = ''
AS

/*  
	Created: 20191106@Percy  
	Task: Ext NAP - Get all enabled products
	DB: DBAGE.bodb02  
  
	Revisions:
		- 20191106@Percy: Initialize SP [Redmine: #118699]
		- 20200922@Danny: re-order products and filter by @GroupId [Redmine : #141832]
		- 20201224@Malcolm: re-order products and filter by @GroupId [Redmine : #142459]
		- 20240226@Lewis: add condition for productlist - RealGroup vs TestGroup [Redmine : #199912]
		- 20240729@Lewis: Scale Out DBCust - Remove Linked Server [Redmine : #206895]
	Description:
		- Environment : 0 - PROD
						1 - UAT
*/

BEGIN
	SET NOCOUNT ON

	DROP TABLE IF EXISTS #ProductList
	CREATE TABLE #ProductList (
		ProductID INT 
		,ProductName VARCHAR(50)
		,OrderNo INT
		,Type INT
	)

	INSERT INTO #ProductList (ProductID,ProductName,OrderNo,Type)
	SELECT
			CAST(ISNULL(gp.GroupProductId, p.ProductID) AS INT) AS ProductID
		   ,p.ProductName
		   ,ISNULL(p.OrderNo,0) AS OrderNo
		   ,CASE WHEN p.CasinoType = 1 THEN 53
				 WHEN p.CasinoType = 2 THEN 41
				 ELSE 0 END AS Type
	FROM dbo.Products p WITH (NOLOCK)
	LEFT JOIN dbo.f_GroupProduct() gp ON p.ProductID = gp.ProductId AND gp.ProductId <> gp.GroupProductId
	WHERE p.GroupType = 0 AND gp.ProductId IS NULL
		AND (
				p.ProductID IN (SELECT value FROM string_split(@Products,','))
				OR 
				ISNULL(@Products,'') =''
			)
		AND p.Enabled = 1
		AND Environment = CASE WHEN @GroupName IN ('ACCUUS','ACCTEST') THEN Environment
							   ELSE 0 END
	
	SELECT ProductID
			,ProductName
			,OrderNo
			,Type
	FROM #ProductList
	ORDER BY OrderNo, Type

	SET NOCOUNT OFF
END
GO
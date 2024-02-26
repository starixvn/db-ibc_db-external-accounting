/*<info serverAlias="DBAGE-bodb02" executers="wsv_xnap" isFunction="0" isNested="0"></info>*/
CREATE PROCEDURE [dbo].[EAS_GetProductList]
	@GroupID	INT = NULL
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
	Description:
		- Environment : 0 - PROD
						1 - UAT
*/

BEGIN
	SET NOCOUNT ON

	DECLARE @GroupName VARCHAR(100)

	SELECT @GroupName = GroupName FROM DBPOL.NAP_UserControl.dbo.eaGroup WITH (NOLOCK) WHERE GroupID = @GroupID

	SELECT
			CAST(ISNULL(gp.GroupProductId, p.ProductID) AS INT) AS ProductID
		   ,p.ProductName
		   ,ISNULL(p.OrderNo,0) AS OrderNo
		   ,CASE WHEN p.CasinoType = 1 THEN 53
				 WHEN p.CasinoType = 2 THEN 41
				 ELSE 0 END AS [Type]
	INTO #ProductList	
	FROM dbo.Products p WITH (NOLOCK)
	LEFT JOIN dbo.f_GroupProduct() gp ON p.ProductID = gp.ProductId AND gp.ProductId <> gp.GroupProductId
	WHERE p.GroupType = 0 AND gp.ProductId IS NULL
		AND p.Enabled = 1
		AND Environment = CASE WHEN @GroupName NOT IN ('ACCUUS','ACCTEST') THEN 0
							   ELSE Environment END
	ORDER BY [Type],OrderNo


	IF @GroupID IS NULL
		SELECT	 ProductID, ProductName, OrderNo, [Type]	
		FROM 	 #ProductList
		ORDER BY OrderNo, Type
	ELSE
		BEGIN
			CREATE TABLE #tmpProducts
			(
				ProductID INT 
			)
			DECLARE @Query NVARCHAR(MAX)='SELECT ProductId FROM OPENQUERY (DBPOL,''select ProductId from NAP_UserControl.dbo.eaGroupConfiguration WITH(NOLOCK) WHERE IsShow = 1 AND GroupId =' 
											+ CAST(@GroupID AS VARCHAR(5)) + ''')'

			INSERT INTO #tmpProducts EXECUTE (@Query)

			SELECT		p.ProductID, p.ProductName, p.OrderNo, p.[Type]	 
			FROM		#ProductList p
			INNER JOIN	#tmpProducts  t ON p.ProductID = t.ProductID
			ORDER BY p.OrderNo, p.Type
			DROP TABLE #tmpProducts
		END

		
		DROP TABLE #ProductList

	SET NOCOUNT OFF
END
GO
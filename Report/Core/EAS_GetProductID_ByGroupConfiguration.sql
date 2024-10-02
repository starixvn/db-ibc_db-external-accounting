/*<info serverAlias="DBPOL-NAP_UserControl" executers="wsv_xnap" isFunction="0" isNested="0"></info>*/
CREATE PROCEDURE [dbo].[EAS_GetProductID_ByGroupConfiguration]
	@GroupID	INT = NULL, 
	@Products	NVARCHAR(MAX) = NULL OUTPUT
AS

/*  
	Created: 20240730@Lewis
	Task: Ext NAP - Get all productid by groupconfiguration
	DB: DBPOL.NAP_UserControl  
  
	Revisions:
		- 20240729@Lewis: Scale Out DBCust - Remove Linked Server [Redmine : #206895]

	Description:
*/

BEGIN
	SET NOCOUNT ON


	DROP TABLE IF EXISTS #ProductList
	CREATE TABLE #ProductList (
		ProductID INT  
		,GroupID INT
		,IsShow BIT
	)

	INSERT INTO #ProductList (ProductId,GroupId,IsShow)
	SELECT ProductId,GroupId,IsShow
	FROM eaGroupConfiguration egc WITH (NOLOCK)
	WHERE egc.GroupId = @GroupID
		AND egc.IsShow = 1

	SELECT @Products = STRING_AGG(CAST(ProductId AS VARCHAR(MAX)),',')
	FROM #ProductList

	SET NOCOUNT OFF
END
GO
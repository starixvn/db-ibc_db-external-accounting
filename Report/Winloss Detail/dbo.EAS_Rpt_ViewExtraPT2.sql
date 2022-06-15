/*<info serverAlias="DBCUST-CUSTDB" executers="bodbExtAccNet" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE EAS_Rpt_ViewExtraPT2
(
	@GroupName VARCHAR(50) = ''
)
AS
/*
	Created by: Sol
	Date: 20200721
	Task : view extra PT in winloss detail report
	DB: DBCUST/CustDB
	Revisions:
		- 20200721@Sol: View Extra PT - Redmine: [#136320]
		- 20200928@Danny: Merge Virtual Sport and Virtual Sport 2 - Redmine: [#141832]
		- 20220615@Danny: Use explicit temporary table  [RemineID: #174035]
*/
BEGIN
	
	SET NOCOUNT ON;

	DECLARE @currDate DATETIME = CAST(GETDATE() AS DATE) 

	CREATE TABLE #f_GroupProduct(ProductId TINYINT, GroupProductId TINYINT)
	INSERT INTO #f_GroupProduct(ProductId, GroupProductId)
	SELECT ProductId,GroupProductId 
	FROM OPENQUERY (DBAGE,'select ProductId, GroupProductId from bodb02.dbo.f_GroupProduct()')

	;WITH rs AS 
	(
		SELECT		agepp.ProductID, agepp.ExtraPT 
		FROM		Acc_GroupExtraPT2_Product agepp WITH(NOLOCK)
		LEFT JOIN	#f_GroupProduct gp ON agepp.ProductID = gp.ProductId AND gp.ProductId <> gp.GroupProductId
		WHERE		@currDate BETWEEN agepp.FromDate AND agepp.ToDate
					AND gp.ProductId IS NULL
					AND agepp.Sporttype = 0 AND agepp.SubProduct = ''
					AND agepp.GroupName = @GroupName
	)
	SELECT ProductID, ExtraPT 
	FROM rs 
	UNION
	SELECT		agepp.ProductID, agepp.ExtraPT 
	FROM		Acc_GroupExtraPT_Product agepp WITH(NOLOCK)
	LEFT JOIN	#f_GroupProduct gp ON agepp.ProductID = gp.ProductId AND gp.ProductId <> gp.GroupProductId
	WHERE		 @currDate BETWEEN agepp.FromDate AND agepp.ToDate
				AND agepp.Sporttype = 0 AND agepp.SubProduct = ''
				AND gp.ProductId IS NULL
				AND agepp.GroupName = @GroupName
				AND NOT EXISTS (SELECT 1 FROM rs WHERE rs.ProductID = agepp.ProductID)
	ORDER BY ExtraPT

	DROP TABLE #f_GroupProduct

END
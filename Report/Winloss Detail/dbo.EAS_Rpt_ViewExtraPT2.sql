/*<info serverAlias="DBCUST-CUSTDB" executers="bodbExtAccNet" isFunction="0" isNested="0"></info>*/
CREATE PROCEDURE EAS_Rpt_ViewExtraPT2
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
*/
BEGIN
	
	SET NOCOUNT ON;

	DECLARE @currDate DATE = CAST(GETDATE() AS DATE) 

	IF @GroupName = 'ACCYEN789' OR @GroupName = 'ACCYEN889' OR @GroupName = 'ACCUT'
	BEGIN
		;WITH rs AS 
		(
			SELECT DISTINCT agepp.ProductID, agepp.ExtraPT 
			FROM Acc_GroupExtraPT2_Product agepp WITH(NOLOCK)
			WHERE @currDate BETWEEN agepp.FromDate AND agepp.ToDate
				AND agepp.Sporttype = 0 AND agepp.SubProduct = ''
				AND agepp.GroupName = @GroupName
		)
		SELECT ProductID, ExtraPT 
		FROM rs 
		UNION
		SELECT  agepp.ProductID, agepp.ExtraPT 
		FROM Acc_GroupExtraPT_Product agepp WITH(NOLOCK)
		WHERE @currDate BETWEEN agepp.FromDate AND agepp.ToDate
			AND agepp.Sporttype = 0 AND agepp.SubProduct = ''
			AND agepp.GroupName = @GroupName
			AND agepp.ProductID <> 1 ---- sportbook
		ORDER BY ExtraPT
	END
	ELSE 
	BEGIN 
		SELECT NULL AS ProductID, NULL AS ExtraPT
	END

END
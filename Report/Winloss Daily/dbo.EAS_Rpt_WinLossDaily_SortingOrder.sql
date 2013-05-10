ALTER PROCEDURE [dbo].[EAS_Rpt_WinLossDaily_SortingOrder]
	@GroupName varchar(50)
AS
/*
	Created by: Dan
	Date: 2012-12-05
	Task: get exceptional sorting for Daily WinLoss 
	DB: DBEAS/bodb_EAS
	Original: 
	Revisions:	

	Param's Explanation:		
		
*/
BEGIN
	SET NOCOUNT ON
	
	IF @GroupName='ACCTHAI'
		SELECT	1517030 as CustId --'BT' 
		UNION ALL
		SELECT	1518494 as CustId--'BT30' 
		UNION ALL
		SELECT	1523261 as CustId--'B1T' 
		UNION ALL
		SELECT	2516393 as CustId--'BT77' 
		UNION ALL
		SELECT	1528410 as CustId--'B2T' 
		UNION ALL
		SELECT	1517391 as CustId-- 'BTN1'
		UNION ALL
		SELECT	1517662 as CustId--'SMT' 
		
END

GO
GRANT EXECUTE ON [dbo].[EAS_Rpt_WinLossDaily_SortingOrder] TO [bodbExtAccNet]
GO
GRANT VIEW DEFINITION ON [dbo].[EAS_Rpt_WinLossDaily_SortingOrder] TO [vnteam]
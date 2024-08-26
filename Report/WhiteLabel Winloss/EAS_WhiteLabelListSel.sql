/*<info serverAlias="DBAGE-bodb02" executers="wsv_xnap" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].EAS_WhiteLabelListSel
	@GroupName		VARCHAR(50) = 'ACCINDO'
AS
/*
    Created: 
    Task : 
    DB: DBAGE/bodb02
   
	Revisions:
        - 20240826@Danny: White Label winloss report - [Redmine: #209633]

		EXEC EAS_WhiteLabelListSel @GroupName = 'ACCTHAI'
			
*/

BEGIN
	SET NOCOUNT ON;

	DROP TABLE IF EXISTS #tmpSuperList
	CREATE TABLE #tmpSuperList (custID INT PRIMARY KEY)

	INSERT INTO #tmpSuperList(CustID)
	SELECT custID 
	FROM bodb02.dbo.Acc_CustGroup WITH(NOLOCK)
	WHERE GroupName = @GroupName

	SELECT wl.CustID, WhiteLabel
	FROM WhiteLabelInfo  wl WITH(NOLOCK)
	INNER JOIN custInfo ci WITH(NOLOCK) ON wl.CustID = ci.custid --AND ci.roleid = 2
	INNER JOIN #tmpSuperList tmp ON ci.srecommend = tmp.custID

	SET NOCOUNT OFF;
END
GO
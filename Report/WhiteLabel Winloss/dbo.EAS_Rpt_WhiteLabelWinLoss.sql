/*<info serverAlias="DBAGE-bodb02" executers="wsv_xnap" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[EAS_Rpt_WhiteLabelWinLoss] 	
	@GroupName		VARCHAR(50) = 'ACCINDO',
	@FromDate		SMALLDATETIME,
	@ToDate			SMALLDATETIME,
	@UserName		NVARCHAR(50) = '',
	@WhiteLabelList VARCHAR(MAX) = ''
AS
/*
	 DB: DBAGE/bodb02
   
	Revisions:
        - 20240826@Danny: White Label winloss report - [Redmine: #209633]

	EXEC EAS_Rpt_WhiteLabelWinLoss 
			@GroupName		= 'ACCTHAI',
			@UserName		= '',
			@FromDate 		= '2024-07-01',
			@ToDate 		= '2024-07-31',
			@WhiteLabelList = '1559361,24982078,8167319'
*/
BEGIN
	SET NOCOUNT ON
	DECLARE @FDate	SMALLDATETIME,
			@TDate	SMALLDATETIME

	SELECT	@FDate = @FromDate, @TDate = @ToDate

	DROP TABLE IF EXISTS #tmpSuperList
	CREATE TABLE #tmpSuperList (custID INT PRIMARY KEY)

	INSERT INTO #tmpSuperList(CustID)
	SELECT custID 
	FROM bodb02.dbo.Acc_CustGroup WITH(NOLOCK)
	WHERE GroupName = @GroupName

	DECLARE @UserName_CustId INT, @UserName_RoleID TINYINT
	IF @Username <> ''
	BEGIN
		SELECT @UserName_CustId = ISNULL(Custid, -1), @UserName_RoleID = RoleID
		FROM  bodb02.dbo.Customer WITH (NOLOCK) WHERE username = @UserName
	END
	ELSE				
	BEGIN
		SET @UserName_CustId = 0
	END

	DROP TABLE IF EXISTS #WhiteLabelList
	CREATE TABLE #WhiteLabelList (custID INT, WhiteLabel NVARCHAR(50))

	INSERT INTO #WhiteLabelList (custID, WhiteLabel)
	SELECT wl.custID, wl.WhiteLabel
	FROM  WhiteLabelInfo wl WITH(NOLOCK)
	INNER JOIN CustInfo ci WITH(NOLOCK) ON wl.CustID = ci.custid
	INNER JOIN #tmpSuperList ts ON ci.srecommend = ts.custID
	WHERE wl.CustID IN (SELECT CAST(value AS INT) FROM STRING_SPLIT (@WhiteLabelList,','))
	AND ( @UserName_CustId = 0 
				OR (  ci.SRecommend = @UserName_CustId AND  @UserName_RoleID = 4)
				OR (  ci.MRecommend = @UserName_CustId AND  @UserName_RoleID = 3)
				OR (  ci.Recommend = @UserName_CustId AND  @UserName_RoleID = 2)
		)

	SELECT	w.WinlostDate, 
			cs.username AS Super,
			cm.username AS Master,   
			wlb.WhiteLabel AS WhiteLabelName,
			cr.username AS Agent,
			SUM( CASE WHEN TypeID = 0 THEN  WinLoss ELSE 0 END) AS MemberWinloss,
			SUM( CASE WHEN TypeID IN (2,3,4,5,6) THEN  WinLoss ELSE 0 END) AS Promotion
	FROM   WhiteLabelWinloss w WITH(NOLOCK)
	INNER JOIN #WhiteLabelList wlb ON w.CustID = wlb.custID
	LEFT JOIN bodb02.dbo.Customer cs WITH(NOLOCK) ON w.MRecommend = cs.CustID
	LEFT JOIN bodb02.dbo.Customer cm WITH(NOLOCK) ON w.MRecommend = cm.CustID
	LEFT JOIN bodb02.dbo.Customer cr WITH(NOLOCK) ON w.Recommend = cr.CustID
	WHERE  w.WinlostDate BETWEEN @FDate AND @TDate AND w.TypeId NOT IN (1,5)
	GROUP BY w.WinlostDate, cs.username, cm.username, cr.username, wlb.WhiteLabel
	ORDER BY  w.WinlostDate, cs.username, cm.username, cr.username


END

GO
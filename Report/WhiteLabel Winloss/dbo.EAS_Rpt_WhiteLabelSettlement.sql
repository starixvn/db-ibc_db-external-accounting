/*<info serverAlias="DBAGE-bodb02" executers="wsv_xnap" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[EAS_Rpt_WhiteLabelSettlement] 	
	@GroupName		VARCHAR(50) = 'ACCTHAI',
	@FromDate		SMALLDATETIME,
	@ToDate			SMALLDATETIME,
	@UserName		NVARCHAR(50) = '',
	@WhiteLabelList VARCHAR(MAX) = ''
AS
/*
	 DB: DBAGE/bodb02
   
	Revisions:
        - 20240826@Danny: White Label settlement report - [Redmine: #209633]

	EXEC EAS_Rpt_WhiteLabelSettlement 
			@GroupName		= 'ACCTHAI',
			@UserName		= '',
			@FromDate 		= '2024-01-01',
			@ToDate 		= '2024-07-31',
			@WhiteLabelList = '1559361,24982078,8167319'
*/
BEGIN
	SET NOCOUNT ON
	DECLARE @FDate	SMALLDATETIME,
			@TDate	SMALLDATETIME

	SELECT	@FDate = DATEADD(DAY,1,EOMONTH(@FromDate,-1))
	SELECT  @TDate = CASE WHEN  EOMONTH(@ToDate) >= EOMONTH(GETDATE()) THEN DATEADD(MONTH, DATEDIFF(MONTH, -1, GETDATE())-1, -1) ELSE EOMONTH(@ToDate) END


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
	CREATE TABLE #WhiteLabelList (custID INT, WhiteLabel NVARCHAR(50), LaunchedDate SMALLDATETIME)

	INSERT INTO #WhiteLabelList (custID, WhiteLabel, LaunchedDate)
	SELECT wl.custID, wl.WhiteLabel, wl.LaunchedDate
	FROM  WhiteLabelInfo wl WITH(NOLOCK)
	INNER JOIN CustInfo ci WITH(NOLOCK) ON wl.CustID = ci.custid
	INNER JOIN #tmpSuperList ts ON ci.srecommend = ts.custID
	WHERE wl.CustID IN (SELECT CAST(value AS INT) FROM STRING_SPLIT (@WhiteLabelList,','))
	AND ( @UserName_CustId = 0 
				OR (  ci.SRecommend = @UserName_CustId AND  @UserName_RoleID = 4)
				OR (  ci.MRecommend = @UserName_CustId AND  @UserName_RoleID = 3)
				OR (  ci.Recommend = @UserName_CustId AND  @UserName_RoleID = 2)
		)

	/*GET earning setting*/
	DROP TABLE IF EXISTS #tmpWhiteLabelSetting
	CREATE TABLE #tmpWhiteLabelSetting (
		CustID			INT,
		WhiteLabel		NVARCHAR(50),
		Recommend		INT,
		Mrecommend		INT,
		Srecommend		INT,
		LaunchedDate	SMALLDATETIME,
		AgentRate		SMALLMONEY,
		MasterRate		SMALLMONEY,
		SuperRate		SMALLMONEY,
		HeadlineRate	SMALLMONEY,
		FromDate		DATETIME,
		ToDate			DATETIME
	)

	INSERT INTO #tmpWhiteLabelSetting (
		CustID,
		WhiteLabel,
		Recommend,
		Mrecommend,
		Srecommend,
		LaunchedDate,
		AgentRate,
		MasterRate,
		SuperRate,
		HeadlineRate,
		FromDate,
		ToDate
	)
	SELECT	ws.CustID, 
			wl.WhiteLabel,
			ci.Recommend,
			ci.Mrecommend,
			ci.srecommend,
			wi.LaunchedDate, 
			ws.AgentRate  /100., 
			ws.MasterRate /100., 
			ws.SuperRate /100., 
			ws.HeadlineRate /100., 
			ws.FromDate, 
			ws.ToDate
	FROM WhiteLabelSetting ws WITH(NOLOCK)
	INNER JOIN #WhiteLabelList wl ON ws.CustID = wl.custID
	INNER JOIN WhiteLabelInfo wi WITH(NOLOCK) ON ws.CustID = wi.CustID 
	INNER JOIN custInfo ci WITH(NOLOCK) ON ws.CustID = ci.custid 

	/*GET reset carried forward setting*/

	/* Calculate Accum. Carried Foward before date range input */
	DROP TABLE IF EXISTS #tmpWLList 
	CREATE TABLE #tmpWLList (
		CustID			INT,
		LaunchedDate	SMALLDATETIME
	)

	INSERT INTO #tmpWLList (CustID, LaunchedDate)
	SELECT DISTINCT CustID, LaunchedDate
	FROM #tmpWhiteLabelSetting

	DROP TABLE IF EXISTS #tmpCustWLByMonth 
	CREATE TABLE #tmpCustWLByMonth (
		CustID				INT,
		EndOfMonth			SMALLDATETIME,
		MemberWL			MONEY,
		Promotion			MONEY,
		PromotionShare		MONEY,
		LossCarryforward	MONEY,
		rn INT
	)

	;WITH t AS
	(
		SELECT  tw.CustID,  
				EOMONTH (w.WinlostDate)  EndOfMonth, 
				SUM(CASE WHEN w.TypeId = 0 THEN Winloss ELSE 0 END ) MemberWL,
				SUM(CASE WHEN w.TypeId IN (2,3,4,5,6) THEN Winloss ELSE 0 END ) Promotion,
				SUM(CASE WHEN w.TypeId = 1 THEN Winloss 
						 WHEN w.TypeID = 5 THEN -Winloss * 0.3 ELSE 0 END ) PromotionShare
		FROM	WhiteLabelWinloss w WITH(NOLOCK)
		INNER JOIN #tmpWLList tw ON w.CustID = tw.CustID 
		WHERE w.WinlostDate <= @TDate AND w.WinlostDate >= tw.LaunchedDate
		GROUP BY tw.CustID, EOMONTH (w.WinlostDate)
	)
	INSERT INTO #tmpCustWLByMonth 
	(
		CustID,
		EndOfMonth,
		MemberWL,
		Promotion,
		PromotionShare,
		rn
	)SELECT CustID, EndOfMonth, MemberWL, Promotion, PromotionShare, ROW_NUMBER() OVER (PARTITION BY CustID ORDER BY EndOfMonth ASC) rn
	FROM t

	; WITH u AS
	(
		SELECT t.CustID, t.EndOfMonth, t.MemberWL, t.Promotion, t.PromotionShare, ISNULL(t.LossCarryforward,0) LossCarryforward , t.rn from  #tmpCustWLByMonth t WHERE rn = 1
		UNION ALL
		SELECT t.CustID, 
			   t.EndOfMonth,
			   t.MemberWL, 
			   t.Promotion, 
			   t.PromotionShare, 
			   CASE WHEN  (u.LossCarryforward - u.MemberWL) > 0  OR x.CustID IS NOT NULL THEN 0 ELSE u.LossCarryforward - u.MemberWL END, t.rn  from #tmpCustWLByMonth t
		INNER JOIN u ON t.rn - 1  = u.rn AND u.CustID = t.CustID
		OUTER APPLY ( SELECT wr.CustID FROM WhiteLabelResetLossCarryForward wr WITH(NOLOCK) WHERE t.CustID = wr.CustID AND t.EndOfMonth = EOMONTH(wr.YearMonth) AND wr.IsDisabled = 0 ) x
	)	UPDATE t
		SET t.LossCarryforward = ISNULL(u.LossCarryforward,0)
		FROM  #tmpCustWLByMonth t
		LEFT JOIN u  ON t.CustID = u.CustID AND t.rn = u.rn
		--WHERE t.rn > 1

	; WITH t AS
	(
	SELECT FORMAT(t.EndOfMonth,'MM/yyyy') "Month", 
		  tls.WhiteLabel AS WhiteLabel, 
		  t.CustID,
		  cr.username AS Agent,
		  cm.username AS Master,
		  cs.username AS Super,
		  t.LossCarryforward,
		  t.MemberWL,
		  t.Promotion AS MemberPromotion,
		  t.LossCarryforward - t.MemberWL AS WhiteLabelNetWinloss,
		  - CASE WHEN  t.LossCarryforward - t.MemberWL < 0 THEN 0 ELSE  
			CASE WHEN tls.CustID = tls.Recommend THEN (t.LossCarryforward - t.MemberWL) * (1 - tls.AgentRate) END 
		  END WhiteLabelFee,
		  t.PromotionShare AS WhiteLabelPromotionShare,
		  t.Promotion +  t.PromotionShare AS WhiteLabelPromotionSettlement,
		  CASE WHEN  t.LossCarryforward - t.MemberWL < 0 THEN 0 ELSE (t.LossCarryforward - t.MemberWL) * tls.MasterRate END MasterEarning,
		  CASE WHEN  t.LossCarryforward - t.MemberWL < 0 THEN 0 ELSE (t.LossCarryforward - t.MemberWL) * tls.SuperRate END SuperEarning,
		  CASE WHEN  t.LossCarryforward - t.MemberWL < 0 THEN 0 ELSE (t.LossCarryforward - t.MemberWL) * tls.HeadlineRate END HeadlineEarning,
		  CASE WHEN  t.LossCarryforward - t.MemberWL < 0 THEN 0 ELSE (t.LossCarryforward - t.MemberWL) * (1 - tls.AgentRate -tls.MasterRate -tls.SuperRate-  tls.HeadlineRate) END CompanyIncome

	FROM #tmpCustWLByMonth t
	INNER JOIN #tmpWhiteLabelSetting tls ON t.CustID = tls.CustID AND t.EndOfMonth BETWEEN tls.FromDate and tls.Todate
	LEFT JOIN bodb02.dbo.Customer cs WITH(NOLOCK) ON tls.SRecommend = cs.CustID
	LEFT JOIN bodb02.dbo.Customer cm WITH(NOLOCK) ON tls.MRecommend = cm.CustID
	LEFT JOIN bodb02.dbo.Customer cr WITH(NOLOCK) ON tls.Recommend = cr.CustID
	WHERE t.EndOfMonth BETWEEN @FDate AND @TDate
	)
	SELECT  "Month",
			WhiteLabel,
			Agent,
			Master,
			Super,
			LossCarryforward,
			MemberWL,
			MemberPromotion,
			WhiteLabelNetWinloss,
			WhiteLabelFee,
			- t.MemberWL + WhiteLabelFee AS WhiteLabelIncome,
			WhiteLabelPromotionShare,
			WhiteLabelPromotionSettlement,
			WhiteLabelFee + WhiteLabelPromotionSettlement AS WhiteLabelTotal,
			MasterEarning,
			SuperEarning,
			HeadlineEarning,
			CompanyIncome,
			-WhiteLabelPromotionSettlement AS CompanyPromotionShare,
			CompanyIncome -WhiteLabelPromotionSettlement CompanyTotal
	FROM	t
	ORDER BY  "Month", Super, Master, WhiteLabel

END

GO
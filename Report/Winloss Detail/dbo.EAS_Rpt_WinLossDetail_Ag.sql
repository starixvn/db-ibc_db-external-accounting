/*<info serverAlias="DBAGE-bodb02" executers="wsv_xnap" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[EAS_Rpt_WinLossDetail_Ag]
	@CustID			INT,--recommend
	@memberID		INT = NULL,
	@FromDate		SMALLDATETIME,
	@ToDate			SMALLDATETIME,
	@ProductIds		VARCHAR(MAX) = '',
	@ProductDetails NVARCHAR(MAX) = 'All',
	@MoveBetsDay	SMALLDATETIME,
	@BalanceUpDay	SMALLDATETIME,
	@PageSize		INT = 0,
	@PageIndex		INT = 0,
	@TotalRows		INT = 0 OUTPUT
AS
/*
Created by: Scott
Date: 2012-11-15
Task : Member Winloss Detail
DB: DBAGE/bodb02
Original SP: [Age_Rpt_WinLossDetail_Ag]
Revisions:
	- 20130121@Dan: Move sp from DB053/bodb02 to DBEAS/bodb_EAS, add linked server DBSUM for bodb_Summary
	- 20140305@Patrick: Add more Keno product(sport:202, bettype between 1501 and 1599)
	- 20150528@Sophia: Apply Gold Deluxe and Sport bettype Matrix [Redmine: #36775]
	- 20150907@Winnie: Add CB [Redmine: #43099]
	- 20151217@Percy: Add Cockfighting [Redmine: #48836]
	- 20160107@Percy: Include new bettype range of the new RNG Casino [Redmine: #48286]
	- 20160215@Percy: Support new product AllBet [Redmine: #50922]
	- 20160225@Sophia: Add new column TurnoverNoDraw [Redmine: #51427]
	- 20160414@Victor: Support new product Voidbridge [Redmine: #55468]
	- 20160809@Percy: Modify Net Turnover for Allbet [RedmineID: #61876]
	- 20160915@Johnson: Integrate NG2 [RedmineSPU: #30]
	- 20161028@Percy: Support Fishing World [RedmineID: #65735]
	- 20170622@Percy: Combine Betradar Virtual Sports with Virtual Sports [RedmineID: #78340]
	- 20170703@Percy: Support Keno Lottery [RedmineID: #78068]
	- 20170830@Percy:
		1. Integrate Lucky 3 [RedmineID: #76770]
		2. Change list of @show[ProductCode] to @ProductIDs - apply all new products
	- 20180913@Percy: Bullfighting - Add data into TurnoverNoDraw column [RedmineID: #101288]
	- 20180914@Percy: Poker Games - Modify GrossComm [RedmineID: #101550]
	- 20181031@Helen: DB052 Indexes Revolution [RedmineID: 103572]
	- 20190418@Kan: DB053/bodb02 Migration, Move sp from DBEAS/bodb_EAS to DB053/bodb02 [Redmine: #111865]
	- 20190826@Percy: Remove inactive products [RedmineID: #118699]
	- 20200410@Sophia: Add BBIN, Sexy Gaming, SA Gaming [RedmineId: #131358]
	- 20200422@Sophia: Add IBCBet Live Casino [RedmineId: #130693]
	- 20200601@Sophia: Add ION [RedmineId: #132325]
	- 20200909@Malcolm: Report Enhancement for Jackpot Product [RedmineID : #139575]
	- 20200915@Malcolm: Add WM Live Casino [Redmine : #131584]
	- 20201201@Malcolm : Add Gold Diamond Gaming [Redmine : #144110]
	- 20201210@Malcolm: Add Big Gaming [RedmineId : #142459]
	- 20210310@Malcolm: Add Pragmatic Live Casino [RedmineId : #133717]
	- 20210617@Sol: changed how to calc net turn over - [RedmineId : #156653]
	- 20211122@Percy: Enhance gross comm formula [RedmineID: #164479]
	- 20220208@Danny: Separate Saba Sport Performance [Redmine: #167177]
	- 20221208@Eddie: Add New SABA ESports PinGoal [RedmineID: #181383]
	- 20221229@Bobby: Enhance GrossComm figure [RedmineID: #182155]
	- 20230630@Lewis: Add Saba Tennis [RedmineID: #190459]
	- 20240125@Lewis: Show Archived User [RedmineID: #199410]
	- 20240306@Lewis: Add Virtual Ice Hockey [RedmineID: #201129]
	- 20240515@Lewis: Add SABA Kabaddi [RedmineID: #203763]
	- 20240617@Lewis: Use bettrans_compact [RedmineID: #206610]
    - 20240918@Lewis: Rebate Retention - Reward [RedmineId: #208503]
	- 20241216@Bobby: Enhance MBU date range [RedmineID: #213507]
	
	Param's Explanation:
	 @ProductDetails:		
		N'<ROOT>
                <ProductDetail ProductId="32" Sporttype="248" Bettype="0" LeagueGroupId="0" TicketType="0"/>
                <ProductDetail ProductId="32" Sporttype="248" Bettype="4297" LeagueGroupId="0" TicketType="0"/>
                <ProductDetail ProductId="32" Sporttype="248" Bettype="4298" LeagueGroupId="0" TicketType="0"/>
                <ProductDetail ProductId="45" Sporttype="243" Bettype="0" LeagueGroupId="0" TicketType="0"/>
                <ProductDetail ProductId="45" Sporttype="243" Bettype="3150" LeagueGroupId="0" TicketType="0"/>
                <ProductDetail ProductId="36" Sporttype="247" Bettype="0" LeagueGroupId="0" TicketType="0"/>
                <ProductDetail ProductId="36" Sporttype="247" Bettype="4599" LeagueGroupId="0" TicketType="0"/>
                <ProductDetail ProductId="36" Sporttype="247" Bettype="4600" LeagueGroupId="0" TicketType="0"/>
                <ProductDetail ProductId="21" Sporttype="211" Bettype="0" LeagueGroupId="0" TicketType="0"/>
                <ProductDetail ProductId="21" Sporttype="211" Bettype="2499" LeagueGroupId="0" TicketType="0"/>
                <ProductDetail ProductId="1" Sporttype="0" Bettype="0" LeagueGroupId="0" TicketType="0"/>
                <ProductDetail ProductId="1" Sporttype="0" Bettype="0" LeagueGroupId="0" TicketType="1"/>
                <ProductDetail ProductId="1" Sporttype="1" Bettype="0" LeagueGroupId="42" TicketType="0"/>
                <ProductDetail ProductId="1" Sporttype="1" Bettype="0" LeagueGroupId="74" TicketType="0"/>
                <ProductDetail ProductId="1" Sporttype="1" Bettype="0" LeagueGroupId="108" TicketType="0"/>
                <ProductDetail ProductId="1" Sporttype="2" Bettype="0" LeagueGroupId="42" TicketType="0"/>
                <ProductDetail ProductId="1" Sporttype="50" Bettype="0" LeagueGroupId="42" TicketType="0"/>
                <ProductDetail ProductId="1" Sporttype="1" Bettype="0" LeagueGroupId="113" TicketType="0"/>
                <ProductDetail ProductId="1" Sporttype="2" Bettype="0" LeagueGroupId="122" TicketType="0"/>
            </ROOT>'
	
*/
BEGIN
	SET NOCOUNT ON

	DECLARE @RowStart	INT, 
			@RowEnd		INT, 
			@FDate		SMALLDATETIME,
			@TDate      SMALLDATETIME,
			@__ProductDetails XML;

	SELECT @FDate = @FromDate, @TDate = @ToDate

	SELECT @PageIndex = @PageIndex - 1, @RowStart = @PageSize * @PageIndex + 1, @RowEnd = @RowStart + @PageSize - 1

	DECLARE @ExistingProductDetails TABLE (ProductId INT,Sporttype INT,Bettype INT, LeagueGroupID SMALLINT, TicketType TINYINT)
	
	DECLARE @AgWinLossDetails TABLE(
		CustID INT, 
		TurnOver		DECIMAL(24,4), 
		TurnoverNoDraw	DECIMAL(24,4), 
		GrossComm		DECIMAL(24,4), 
		MemberWinLost	DECIMAL(24,4), 
		PlayerComm		DECIMAL(24,4), 
		MemberTotal		DECIMAL(24,4), 
		AgWinLost		DECIMAL(24,4), 
		AgComm			DECIMAL(24,4), 
		AgTotal			DECIMAL(24,4), 
		Company			DECIMAL(24,4),
		RewardAmount	DECIMAL(24,4)
		INDEX CIX_AgWinLossDetails CLUSTERED (CustID)
	);

	DECLARE @GrossComm TABLE (winlostdate SMALLDATETIME, CustId INT, TurnoverNoDraw DECIMAL(24,4), GrossComm DECIMAL(24,4))

	SELECT @ProductIds = bodb02.dbo.f_AddRelatedProducts(@ProductIds)
	SELECT @__ProductDetails = CONVERT(XML, @ProductDetails)

	INSERT INTO @ExistingProductDetails(ProductId,Sporttype,Bettype,LeagueGroupID,TicketType)
	SELECT ProductId,Sporttype,Bettype,LeagueGroupID,TicketType
	FROM dbo.f_ProductDetail_ConditionSel(@ProductDetails, @__ProductDetails)

	DECLARE @SeparateSabaSport_Cutoff SMALLDATETIME 

	SELECT @SeparateSabaSport_Cutoff = CutoffDate
	FROM dbo.f_GetCutoffDate()
	WHERE TypeName = 'SabaSport'

	DECLARE @TmpCondSumWL TABLE(sporttype INT, bettype INT,	LeagueGroupID SMALLINT, TicketType TINYINT)

	IF @FromDate <= @MoveBetsDay
	BEGIN
		INSERT INTO @TmpCondSumWL(SportType, BetType, LeagueGroupID, TicketType) 
		SELECT f.SportType, f.BetType, f.LeagueGroupID, f.TicketType
		FROM dbo.f_SumWinloss_ConditionSel(@ProductIds) f
			LEFT JOIN @ExistingProductDetails e ON f.ProductID = e.ProductId 
		WHERE e.ProductId IS NULL OR (e.Bettype = f.BetType AND e.Sporttype = f.SportType AND e.TicketType = f.TicketType AND e.LeagueGroupID = f.LeagueGroupID AND e.ProductID = f.ProductId)
	END

	----Get Sport Bettype Matrix------
	DECLARE @isTest BIT = 0
	SELECT  @isTest = dbo.f_CheckSPVersion(@@PROCID);

	DROP TABLE IF EXISTS #tmpSportBettype;
	CREATE TABLE #tmpSportBettype (ProductID INT, BetType SMALLINT, RefTable TINYINT, LeagueGroupID SMALLINT, TicketType TINYINT, SportType INT);

	INSERT INTO #tmpSportBettype
	SELECT ISNULL(p.GroupProductId, f.ProductID) AS ProductID, f.BetType, f.RefTable, ISNULL(e.LeagueGroupID,0) AS LeagueGroupID, ISNULL(e.TicketType,0) AS TicketType, ISNULL(SportType,0) AS SportType
	FROM dbo.f_SportBettypeMatrixByProduct_Sel(@ProductIds, @IsTest) f
		LEFT JOIN dbo.f_GroupProduct() p ON f.ProductID = p.ProductId
		LEFT JOIN @ExistingProductDetails e ON e.ProductId = f.ProductID 
	WHERE EXISTS(
		SELECT 1
		WHERE e.ProductId IS NULL 
			OR (e.Bettype = f.BetType 
				OR (
					e.Bettype = 0  AND  (e.ProductId = 1 OR  f.BetType NOT IN (SELECT g.Bettype FROM f_GetProductDetail() g WHERE g.ProductId <> 1) )
				)
			)
		)		

	DECLARE @srecommend INT,
		@mrecommend INT

	DROP TABLE IF EXISTS #downlineList;
	CREATE TABLE #downlineList(custid INT PRIMARY KEY, srecommend INT, mrecommend INT, UserName VARCHAR(30), CurrencyId INT, CurrencyName NVARCHAR(15), CurrencyCode NVARCHAR(5));

	IF @memberID IS NULL
	BEGIN
		INSERT INTO #downlineList(custid, srecommend, mrecommend,UserName, CurrencyId, CurrencyName, CurrencyCode)
		SELECT ci.custid, ci.srecommend, ci.mrecommend, ci.UserName, ci.Currency, ex.Currency, ex.Code
		FROM dbo.custinfo ci WITH(NOLOCK)
		INNER JOIN dbo.Exchange ex WITH(NOLOCK) ON ex.ExchangeId = ci.Currency
		WHERE ci.recommend = @CustID
			AND ci.RoleId = 1
	END
	ELSE 
	BEGIN
		INSERT INTO #downlineList(custid, srecommend, mrecommend,UserName, CurrencyId, CurrencyName, CurrencyCode)
		SELECT ci.custid, ci.srecommend, ci.mrecommend, ci.UserName, ci.Currency, ex.Currency, ex.Code
		FROM dbo.custinfo ci WITH(NOLOCK)
		INNER JOIN dbo.Exchange ex WITH(NOLOCK) ON ex.ExchangeId = ci.Currency
		WHERE ci.recommend = @CustID
			AND ci.RoleId = 1
			AND ci.custid = @memberID
	END

	SELECT TOP(1)
		@srecommend = srecommend
		,@mrecommend = mrecommend
	FROM #downlineList;

	--TODO: bettrans_compact
	SELECT @FDate = FromDate, @TDate = ToDate
	FROM (VALUES(@FromDate)) AS t (CheckDate)
	OUTER APPLY (
		SELECT * FROM dbo.f_MBU_RangeDate(CheckDate, @ToDate, @BalanceUpDay, @MoveBetsDay)
		WHERE RangeType = 1
	) AS fc

	IF @FDate IS NOT NULL
	BEGIN
				
		INSERT @AgWinLossDetails (CustID , TurnOver , TurnoverNoDraw , GrossComm , MemberWinLost , 
									PlayerComm , MemberTotal , AgWinLost , AgComm , AgTotal , 
									Company )
		SELECT b.custid
			,SUM(b.turnover)
			,SUM(b.TurnoverNoDraw)
			,SUM(b.GrossComm)
			,SUM(b.winlost)
			,SUM(b.playercomm)
			,SUM(b.winlost+b.playercomm)
			,SUM(b.awinlost)
			,SUM(b.comm-b.playercomm)
			,SUM(b.awinlost+b.comm-b.playercomm)
			,-(ISNULL(SUM(awinlost), 0) + ISNULL(SUM(comm), 0) + ISNULL(SUM(winlost), 0)) --Company
		FROM bodb_AGE.dbo.bettrans_compact b WITH(NOLOCK)
			INNER JOIN #downlineList dl ON dl.custid = b.custid
			INNER JOIN #tmpSportBettype s ON b.bettype = s.bettype 
				AND (s.ProductID <> 1 OR (s.ProductID = 1 AND b.sporttype = s.SportType AND b.LeagueGroupID = s.LeagueGroupID AND b.TicketType = s.TicketType))
		WHERE b.winlostdate between @FDate and @TDate 
		GROUP BY b.custid

		-- bettransRnG
		INSERT INTO @GrossComm (CustId, TurnoverNoDraw, GrossComm)
		SELECT b.CustId
			,SUM(CASE WHEN cont.ContributionBettype IS NULL THEN b.BetStake ELSE 0 END) AS TurnoverNoDraw
			,SUM(b.BetStake * b.discount) AS GrossComm
		FROM dbo.bettransRnG b WITH(NOLOCK)
			INNER JOIN #downlineList dl ON dl.custid = b.custid
			INNER JOIN (
							SELECT	ISNULL(p.GroupProductId, f.ProductID) AS ProductID, f.BetType
							FROM dbo.f_SportBettypeMatrixByProduct_Sel(@ProductIds, @IsTest) f
								LEFT JOIN dbo.f_GroupProduct() p ON f.ProductID = p.ProductId
								LEFT JOIN @ExistingProductDetails e ON e.ProductId = f.ProductID 
							WHERE EXISTS(SELECT 1
											WHERE e.ProductId IS NULL 
											OR 
												(
													e.Bettype = f.BetType 
															OR (
														e.Bettype = 0  AND  (e.ProductId = 1 OR  f.BetType NOT IN (SELECT g.Bettype FROM f_GetProductDetail() g WHERE g.ProductId <> 1) )
														)
												)
										)
								AND f.RefTable = 1
							) s ON b.gameID = s.Bettype
			OUTER APPLY 
			(
				SELECT f.Bettype AS ContributionBettype
				FROM dbo.f_BettypePrizeGroup() f
				WHERE f.BettypeGroup = 'Contribution'
					AND f.Bettype = b.gameID
			) cont
		WHERE winlostdate BETWEEN @FDate AND @TDate
			AND statusID IN (111, 112, 113) 
			AND recommend = @CustID
		GROUP BY b.CustId
				
		-- bettransLC
		INSERT INTO @GrossComm (CustId, TurnoverNoDraw, GrossComm)
		SELECT b.CustId
			,SUM(CASE WHEN cont.ContributionBettype IS NULL THEN b.NetStake ELSE 0 END) AS TurnoverNoDraw
			,SUM(b.NetStake * b.discount) AS GrossComm
		FROM dbo.bettransLC b WITH(NOLOCK)
			INNER JOIN #downlineList dl ON dl.custid = b.custid
			INNER JOIN (
							SELECT	ISNULL(p.GroupProductId, f.ProductID) AS ProductID, f.BetType
							FROM dbo.f_SportBettypeMatrixByProduct_Sel(@ProductIds, @IsTest) f
								LEFT JOIN dbo.f_GroupProduct() p ON f.ProductID = p.ProductId
								LEFT JOIN @ExistingProductDetails e ON e.ProductId = f.ProductID 
							WHERE EXISTS(SELECT 1
											WHERE e.ProductId IS NULL 
											OR 
												(
													e.Bettype = f.BetType 
																OR (
															e.Bettype = 0  AND  (e.ProductId = 1 OR  f.BetType NOT IN (SELECT g.Bettype FROM f_GetProductDetail() g WHERE g.ProductId <> 1) )
														)
												)
										)
								AND f.RefTable = 2
							) s ON b.gameID = s.Bettype
			OUTER APPLY 
			(
				SELECT f.Bettype AS ContributionBettype
				FROM dbo.f_BettypePrizeGroup() f
				WHERE f.BettypeGroup = 'Contribution'
					AND f.Bettype = b.gameID
			) cont
		WHERE winlostdate BETWEEN @FDate AND @TDate
			AND statusID IN (111, 112, 113) 
			AND recommend = @CustID
		GROUP BY b.CustId

		IF EXISTS (SELECT 1 FROM @GrossComm)
		BEGIN
			UPDATE t
			SET t.TurnoverNoDraw = ISNULL(t.TurnoverNoDraw, 0) + ISNULL(c.TurnoverNoDraw, 0)
				,t.GrossComm = ISNULL(t.GrossComm, 0) + ISNULL(c.GrossComm, 0)
			FROM @AgWinLossDetails t
				INNER JOIN (
					SELECT CustId, SUM(GrossComm) AS GrossComm, SUM(TurnoverNoDraw) AS TurnoverNoDraw FROM @GrossComm GROUP BY CustId
				) c ON t.CustId = c.CustId
		END
	END
			

	--TODO: sum_winloss
	SELECT @FDate = FromDate, @TDate = ToDate
	FROM (VALUES(@FromDate)) AS t (CheckDate)
	OUTER APPLY (
		SELECT * FROM dbo.f_MBU_RangeDate(CheckDate, @ToDate, @BalanceUpDay, @MoveBetsDay)
		WHERE RangeType = 2
	) AS fc

	IF @FDate IS NOT NULL
	BEGIN
		INSERT INTO @AgWinLossDetails (CustID , TurnOver , TurnoverNoDraw , GrossComm , MemberWinLost , 
									PlayerComm , MemberTotal , AgWinLost , AgComm , AgTotal , 
									Company )
		SELECT
			dl.CustID,			
			SUM(ABS(TurnOver)) AS TurnOver,
			SUM(ABS(TunroverNoDraw)) AS TurnoverNoDraw,
			SUM(grosscomm) AS GrossComm,
			SUM(winlost), --MemberWinlost
			SUM(playercomm), -- PlayerComm
			ISNULL(SUM(winlost), 0) + ISNULL(SUM(playercomm), 0), --MemberTotal
			SUM(awinlost), -- AgWinlost
			SUM(comm-playercomm), --AgComm
			ISNULL(SUM(awinlost), 0) + ISNULL(SUM(comm-playercomm), 0), --AgTotal
			-ISNULL(SUM(winlost+awinlost+comm), 0) --Company
		FROM bodb02.dbo.sum_winloss b WITH (NOLOCK) 
			INNER JOIN #downlineList dl ON dl.custid = b.custid
			INNER JOIN @TmpCondSumWL t 
				ON b.sporttype = t.sporttype 
				AND b.bettype = t.bettype 
				AND ISNULL(b.leagueGroupID,0) = t.LeagueGroupID
				AND ISNULL(b.ticketType,0) = t.TicketType
		WHERE
				b.winlostdate BETWEEN @FDate and @TDate	
				AND b.srecommend=@srecommend
				AND b.mrecommend=@mrecommend
				AND b.recommend=@CustID
				AND b.RoleID=1
		GROUP BY dl.CustID			
			
	END

	--TODO: Sum_WinLoss_Old
	SELECT @FDate = FromDate, @TDate = ToDate
	FROM (VALUES(@FromDate)) AS t (CheckDate)
	OUTER APPLY (
		SELECT * FROM dbo.f_MBU_RangeDate(CheckDate, @ToDate, @BalanceUpDay, @MoveBetsDay)
		WHERE RangeType = 3
	) AS fc

	IF @FDate IS NOT NULL
	BEGIN
		
		INSERT INTO @AgWinLossDetails (CustID , TurnOver , TurnoverNoDraw , GrossComm , MemberWinLost , 
											PlayerComm , MemberTotal , AgWinLost , AgComm , AgTotal , 
											Company )
		SELECT
			dl.CustID,			
			SUM(ABS(TurnOver)) as TurnOver,
			SUM(ABS(TunroverNoDraw)) as TurnoverNoDraw,
			SUM(grosscomm) as GrossComm,
			SUM(winlost), --MemberWinlost
			SUM(playercomm), -- PlayerComm
			ISNULL(SUM(winlost), 0) + ISNULL(SUM(playercomm), 0), --MemberTotal
			SUM(awinlost), -- AgWinlost
			SUM(comm-playercomm), --AgComm
			ISNULL(SUM(awinlost), 0) + ISNULL(SUM(comm-playercomm), 0), --AgTotal
			-ISNULL(SUM(winlost+awinlost+comm), 0) --Company
		FROM bodb_Summary.dbo.Sum_WinLoss_Old b WITH(NOLOCK) 
			LEFT JOIN #downlineList dl ON dl.custid = b.custid
			INNER JOIN @TmpCondSumWL t 
				ON b.sporttype = t.sporttype 
				AND b.bettype = t.bettype 
				AND ISNULL(b.leagueGroupID,0) = t.LeagueGroupID 
				AND ISNULL(b.ticketType,0) = t.TicketType
		WHERE
			b.winlostdate BETWEEN @FDate and @TDate	
			AND b.srecommend=@srecommend
			AND b.mrecommend=@mrecommend
			AND b.recommend=@CustID
			AND b.RoleID=1
			AND (@memberID IS NULL OR (@memberID > 0 AND dl.custid > 0)) -- Archived members
		GROUP BY dl.CustID
	END


	--TODO: SabaWalletTicket
	SELECT @FDate = @FromDate, @TDate = @ToDate

	INSERT INTO @AgWinLossDetails(CustID, RewardAmount)
	SELECT dl.CustID, SUM(Amount)
	FROM dbo.SabaWalletTicket b WITH (NOLOCK)
	INNER JOIN #downlineList dl ON dl.custid = b.custid
	WHERE b.WinlostDate BETWEEN @FDate AND @TDate
		AND b.WalletID = 2
	GROUP BY dl.CustID

	--TODO: Result
	IF ((@PageSize <= 0) AND (@PageIndex <= 0))
	BEGIN

		SELECT
			c.CustID, 
			c.UserName,  
			SUM(TurnOver) AS TurnOver,
			SUM(TurnoverNoDraw) AS TurnoverNoDraw,
			SUM(GrossComm) AS GrossComm,
			SUM(MemberWinLost) AS MemberWinlost,
			SUM(PlayerComm) AS PlayerComm,
			SUM(MemberTotal) AS MemberTotal,
			SUM(AgWinlost) AS AgWinlost,
			SUM(AgComm) AS AgComm,
			SUM(AgTotal) AS AgTotal,
			SUM(Company) AS Company,
			SUM(RewardAmount) AS RewardAmount,
			c.CurrencyCode AS RewardCurrency
		FROM @AgWinLossDetails w 
		LEFT JOIN #downlineList c ON w.CustID = c.CustID 
		GROUP BY c.CustID, c.UserName, c.CurrencyCode
		ORDER BY IIF(c.Username IS NULL,1,0),c.Username;

		RETURN
	END

	IF @TotalRows = 0  
	BEGIN  
		SELECT @TotalRows = COUNT(DISTINCT CustID)
		FROM @AgWinLossDetails
	END


	SELECT wl.*
	FROM
		(
		SELECT
			c.CustID, 
			c.UserName,  
			SUM(TurnOver) AS TurnOver,
			SUM(TurnoverNoDraw) AS TurnoverNoDraw,
			SUM(GrossComm) AS GrossComm,
			SUM(MemberWinLost) AS MemberWinlost,
			SUM(PlayerComm) AS PlayerComm,
			SUM(MemberTotal) AS MemberTotal,
			SUM(AgWinlost) AS AgWinlost,
			SUM(AgComm) AS AgComm,
			SUM(AgTotal) AS AgTotal,
			SUM(Company) AS Company,
			SUM(RewardAmount) AS RewardAmount,
			c.CurrencyCode AS RewardCurrency,
			ROW_NUMBER() OVER (ORDER BY IIF(c.Username IS NULL,1,0),c.UserName) as RowNum	
		FROM @AgWinLossDetails w 
			LEFT JOIN #downlineList c ON w.CustID = c.CustID 
		GROUP BY c.CustID, c.UserName, c.CurrencyCode
		) wl
	WHERE wl.RowNum between @RowStart and @RowEnd;

END	
GO
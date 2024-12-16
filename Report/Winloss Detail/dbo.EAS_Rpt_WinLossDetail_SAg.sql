/*<info serverAlias="DBAGE-bodb02" executers="wsv_xnap" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[EAS_Rpt_WinLossDetail_SAg]
	@custid			INT,--srecommend
	@masterid		INT = NULL,
	@FromDate		SMALLDATETIME,
	@ToDate			SMALLDATETIME,
	@ProductIds		VARCHAR(MAX) = '',
	@ProductDetails NVARCHAR(MAX) = 'All',
	@MoveBetsDay	SMALLDATETIME,
	@BalanceUpDay	SMALLDATETIME,
	@PageSize		INT = 0,
	@PageIndex		INT = 0,
	@TotalRows		INT = 0 OUTPUT
WITH RECOMPILE
AS

/*
	Created by: Dan
	Date: 2012-11-12
	Task : Master Winloss Detail
	DB: DBAGE/bodb02
	Original SP: [Age_Rpt_WinLossDetail_SAg]
	Revisions:
		- 20130121@Dan: Move sp from DB053/bodb02 to DBEAS/bodb_EAS, add linked server DBSUM for bodb_Summary
		- 20140305@Patrick: Add more Keno product(sport:202, bettype between 1501 and 1599)
		- 20150507@Lukas: avoid join remoted table by using local temp table
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
		- 20241216@Bobby: Enahnce MBU & Base Currency [RedmineID: #213507]
	
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

	DECLARE @RowStart INT, @RowEnd INT, @FDate SMALLDATETIME, @TDate SMALLDATETIME, @__ProductDetails XML;

	SELECT @FDate = @FromDate, @TDate = @ToDate

	SELECT @PageIndex = @PageIndex - 1, @RowStart = @PageSize * @PageIndex + 1, @RowEnd = @RowStart + @PageSize - 1

	DECLARE @ExistingProductDetails TABLE (ProductId INT,Sporttype INT,Bettype INT, LeagueGroupID SMALLINT, TicketType TINYINT)

	DECLARE @SAgWinLossDetails TABLE(
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
		MAgWinLost		DECIMAL(24,4), 
		MAgComm			DECIMAL(24,4), 
		MAgTotal		DECIMAL(24,4), 
		SAgWinLost		DECIMAL(24,4), 
		SAgComm			DECIMAL(24,4), 
		SAgTotal		DECIMAL(24,4), 
		Company			DECIMAL(24,4),
		RewardAmount MONEY
		INDEX CIX_CustID CLUSTERED (CustID)
	);
	DECLARE @GrossComm TABLE (CustId INT, TurnoverNoDraw DECIMAL(24,4), GrossComm DECIMAL(24,4));

	SELECT @ProductIds = bodb02.dbo.f_AddRelatedProducts(@ProductIds)
	SELECT @__ProductDetails = CONVERT(XML, @ProductDetails)
	
	INSERT INTO @ExistingProductDetails(ProductId,Sporttype,Bettype,LeagueGroupID,TicketType)
	SELECT ProductId,Sporttype,Bettype,LeagueGroupID,TicketType
	FROM dbo.f_ProductDetail_ConditionSel(@ProductDetails, @__ProductDetails)

	DECLARE @SeparateSabaSport_Cutoff SMALLDATETIME 

	SELECT @SeparateSabaSport_Cutoff = CutoffDate
	FROM dbo.f_GetCutoffDate()
	WHERE TypeName = 'SabaSport'
		
	DECLARE @TmpCondSumWL TABLE(sporttype INT, bettype INT,	LeagueGroupID	SMALLINT, TicketType TINYINT)

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
	SELECT  @isTest = dbo.f_CheckSPVersion(@@PROCID)

	DROP TABLE IF EXISTS #tmpSportBettype;
	CREATE TABLE #tmpSportBettype (ProductID INT, BetType SMALLINT, RefTable TINYINT, LeagueGroupID SMALLINT, TicketType TINYINT, SportType INT);

	INSERT INTO #tmpSportBettype
	SELECT	ISNULL(p.GroupProductId, f.ProductID) AS ProductID, f.BetType, f.RefTable, ISNULL(e.LeagueGroupID,0) AS LeagueGroupID, ISNULL(e.TicketType,0) AS TicketType, ISNULL(SportType,0) AS SportType
	FROM dbo.f_SportBettypeMatrixByProduct_Sel(@ProductIds, @IsTest) f
		LEFT JOIN dbo.f_GroupProduct() p ON f.ProductID = p.ProductId
		LEFT JOIN @ExistingProductDetails e ON e.ProductId = f.ProductID 
	WHERE EXISTS(
			SELECT 1
			WHERE e.ProductId IS NULL 
			OR 
			(
				e.Bettype = f.BetType 
					OR (
					e.Bettype = 0  AND  (e.ProductId = 1 OR  f.BetType NOT IN (SELECT g.Bettype FROM f_GetProductDetail() g WHERE g.ProductId <> 1) )
					)
			)
		)

	DROP TABLE IF EXISTS #downlineList;
	CREATE TABLE #downlineList(custid INT PRIMARY KEY, mrecommend INT, recommend INT, UserName VARCHAR(30), roleid TINYINT, CurrencyId INT, CurrencyName NVARCHAR(15), CurrencyCode NVARCHAR(5));

	IF @masterid IS NULL
	BEGIN
		;WITH CTE_Downline_AIO AS(
			SELECT ci.custid
			FROM dbo.custinfo ci WITH(NOLOCK)
			WHERE ci.srecommend = @CustID
				AND ci.RoleId = 3

		)
		INSERT INTO #downlineList(custid, mrecommend, recommend, UserName, CurrencyId, RoleId, CurrencyName, CurrencyCode)
		SELECT ci.custid, ci.mrecommend, ci.recommend, ci.UserName, ci.Currency, ci.roleid, ex.Currency, ex.Code
		FROM dbo.custinfo ci WITH(NOLOCK)
			INNER JOIN CTE_Downline_AIO dl ON dl.custid = ci.custid
			INNER JOIN dbo.Exchange ex WITH(NOLOCK) ON ex.ExchangeId = ci.Currency
		
	END
	ELSE 
	BEGIN
		INSERT INTO #downlineList(custid, mrecommend, recommend, UserName, RoleId, CurrencyId, CurrencyName, CurrencyCode)
		SELECT ci.custid, ci.mrecommend, ci.recommend, ci.UserName, ci.RoleId, ci.Currency, ex.Currency, ex.Code
		FROM dbo.custinfo ci WITH(NOLOCK)
		INNER JOIN dbo.Exchange ex WITH(NOLOCK) ON ex.ExchangeId = ci.Currency
		WHERE ci.srecommend = @CustID
			AND ci.RoleId = 3
			AND ci.custid = @masterid
	END

	--TODO: bettrans_compact
	SELECT @FDate = FromDate, @TDate = ToDate
	FROM (VALUES(@FromDate)) AS t (CheckDate)
	OUTER APPLY (
		SELECT * FROM dbo.f_MBU_RangeDate(CheckDate, @ToDate, @BalanceUpDay, @MoveBetsDay)
		WHERE RangeType = 1
	) AS fc

	IF @FDate IS NOT NULL
	BEGIN 
		
		INSERT @SAgWinLossDetails (CustID , TurnOver , TurnoverNoDraw , GrossComm , MemberWinLost , 
									PlayerComm , MemberTotal , AgWinLost , AgComm , AgTotal , 
									MAgWinLost , MAgComm , MAgTotal , SAgWinLost , SAgComm , SAgTotal , Company )
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
			,SUM(b.mwinlost)
			,SUM(b.acomm-b.comm)
			,SUM(b.mwinlost+b.acomm-b.comm)
			,SUM(b.swinlost)
			,SUM(b.scomm-b.acomm)
			,SUM(b.swinlost+b.scomm-b.acomm)
			,-(ISNULL(SUM(swinlost), 0) + ISNULL(SUM(awinlost), 0) + ISNULL(SUM(mwinlost), 0) + ISNULL(SUM(scomm), 0) + ISNULL(SUM(winlost), 0)) --Company
		FROM bodb_AGE.dbo.bettrans_compact b WITH(NOLOCK)
			INNER JOIN #downlineList dl ON dl.custid = b.custid
			INNER JOIN #tmpSportBettype s ON b.bettype = s.bettype 
				AND (s.ProductID <> 1 OR (s.ProductID = 1 AND b.sporttype = s.SportType AND b.LeagueGroupID = s.LeagueGroupID AND b.TicketType = s.TicketType))
		WHERE b.winlostdate between @FDate and @TDate 
		GROUP BY b.custid

		-- bettransRnG
		INSERT INTO @GrossComm (CustId, TurnoverNoDraw, GrossComm)
		SELECT dl.CustId
			,SUM(CASE WHEN cont.ContributionBettype IS NULL THEN b.BetStake ELSE 0 END) AS TurnoverNoDraw
			,SUM(b.BetStake * b.sdiscount) AS GrossComm
		FROM dbo.bettransRnG b WITH(NOLOCK)
			INNER JOIN #downlineList dl ON dl.custid = IIF(b.mrecommend=-4, b.custid, b.mrecommend)
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
			AND srecommend = @custid
		GROUP BY dl.custid
				
		-- bettransLC
		INSERT INTO @GrossComm (CustId, TurnoverNoDraw, GrossComm)
		SELECT dl.CustId
			,SUM(CASE WHEN cont.ContributionBettype IS NULL THEN b.NetStake ELSE 0 END) AS TurnoverNoDraw
			,SUM(b.NetStake * b.sdiscount) AS GrossComm
		FROM dbo.bettransLC b WITH(NOLOCK)
			INNER JOIN #downlineList dl ON dl.custid = IIF(b.mrecommend=-4, b.custid, b.mrecommend)
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
			AND srecommend = @custid
		GROUP BY dl.custid
				
		IF EXISTS (SELECT 1 FROM @GrossComm)
		BEGIN
			UPDATE t
			SET t.TurnoverNoDraw = ISNULL(t.TurnoverNoDraw, 0) + ISNULL(c.TurnoverNoDraw, 0)
				,t.GrossComm = ISNULL(t.GrossComm, 0) + ISNULL(c.GrossComm, 0)
			FROM @SAgWinLossDetails t
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
			INSERT INTO @SAgWinLossDetails (CustID , TurnOver , TurnoverNoDraw , GrossComm , MemberWinLost , 
										PlayerComm , MemberTotal , AgWinLost , AgComm , AgTotal , 
										MAgWinLost , MAgComm , MAgTotal , SAgWinLost , SAgComm , SAgTotal , Company )
			SELECT
				dl.CustID,			
				SUM(ABS(TurnOver)) as TurnOver,
				SUM(ABS(TunroverNoDraw)) as TurnoverNoDraw,
				SUM(grosscomm) as GrossComm,
				SUM(winlost), --MemberWinlost
				SUM(playercomm), -- PlayerComm
				ISNULL(SUM(winlost), 0) + ISNULL(SUM(playercomm), 0), --MemberTotal
				SUM(awinlost), -- AgWinlost
				ISNULL(SUM(comm-playercomm),0), --AgComm
				ISNULL(SUM(awinlost+comm-playercomm), 0), --AgTotal		
				SUM(mwinlost), -- MAgWinlost
				SUM(acomm)-SUM(comm), --MAgComm
				ISNULL(SUM(mwinlost), 0) + ISNULL(SUM(acomm), 0)-SUM(comm), --MAgTotal
				SUM(swinlost), -- SAgWinlost
				ISNULL(SUM(scomm),0) -ISNULL(SUM(acomm),0), --SAgComm
				ISNULL(SUM(swinlost), 0) + ISNULL(SUM(scomm), 0)-SUM(acomm), --SAgTotal
				-(ISNULL(SUM(swinlost), 0) + ISNULL(SUM(awinlost), 0) + ISNULL(SUM(mwinlost), 0) + ISNULL(SUM(scomm), 0) + ISNULL(SUM(winlost), 0)) --Company					
			FROM bodb02.dbo.sum_winloss b WITH (NOLOCK) 
				INNER JOIN #downlineList dl ON  dl.mrecommend = b.mrecommend AND dl.recommend = b.recommend AND dl.custid = b.custid
				INNER JOIN @TmpCondSumWL t 	ON b.sporttype = t.sporttype 
					AND b.bettype = t.bettype 
					AND ISNULL(b.leagueGroupID,0) = t.LeagueGroupID 
					AND ISNULL(b.ticketType,0) = t.TicketType
			WHERE b.winlostdate BETWEEN @FDate AND @TDate			
				AND b.SRecommend = @custid
				AND b.RoleID IN (3, 1)
			GROUP BY dl.CustID
	END

	--TODO: sum_winloss_old
	SELECT @FDate = FromDate, @TDate = ToDate
	FROM (VALUES(@FromDate)) AS t (CheckDate)
	OUTER APPLY (
		SELECT * FROM dbo.f_MBU_RangeDate(CheckDate, @ToDate, @BalanceUpDay, @MoveBetsDay)
		WHERE RangeType = 3
	) AS fc

	IF @FDate IS NOT NULL
	BEGIN 
						
		INSERT INTO @SAgWinLossDetails (CustID , TurnOver , TurnoverNoDraw , GrossComm , MemberWinLost , 
											PlayerComm , MemberTotal , AgWinLost , AgComm , AgTotal , 
											MAgWinLost , MAgComm , MAgTotal , SAgWinLost , SAgComm , SAgTotal , Company )
		SELECT
			b.CustID,			
			SUM(ABS(TurnOver)) as TurnOver,
			SUM(ABS(TunroverNoDraw)) as TurnoverNoDraw,
			SUM(grosscomm) as GrossComm,
			SUM(winlost), --MemberWinlost
			SUM(playercomm), -- PlayerComm
			ISNULL(SUM(winlost), 0) + ISNULL(SUM(playercomm), 0), --MemberTotal
			SUM(awinlost), -- AgWinlost
			ISNULL(SUM(comm-playercomm),0), --AgComm
			ISNULL(SUM(awinlost+comm-playercomm), 0), --AgTotal		
			SUM(mwinlost), -- MAgWinlost
			SUM(acomm)-SUM(comm), --MAgComm
			ISNULL(SUM(mwinlost), 0) + ISNULL(SUM(acomm), 0)-SUM(comm), --MAgTotal
			SUM(swinlost), -- SAgWinlost
			ISNULL(SUM(scomm),0) -ISNULL(SUM(acomm),0), --SAgComm
			ISNULL(SUM(swinlost), 0) + ISNULL(SUM(scomm), 0)-SUM(acomm), --SAgTotal
			-(ISNULL(SUM(swinlost), 0) + ISNULL(SUM(awinlost), 0) + ISNULL(SUM(mwinlost), 0) + ISNULL(SUM(scomm), 0) + ISNULL(SUM(winlost), 0)) --Company								
		FROM bodb_Summary.dbo.Sum_WinLoss_Old b WITH(NOLOCK)
			LEFT JOIN #downlineList dl ON  dl.mrecommend = b.mrecommend AND dl.recommend = b.recommend AND dl.custid = b.custid
			INNER JOIN @TmpCondSumWL t 
				ON b.sporttype = t.sporttype 
				AND b.bettype = t.bettype 
				AND b.leagueGroupID = t.LeagueGroupID 
				AND b.ticketType = t.TicketType
		WHERE b.winlostdate BETWEEN @FDate AND @TDate		
			AND b.SRecommend = @custid
			AND b.RoleID IN (3, 1)
			AND (
				dl.custid > 0 OR 
				b.mrecommend = b.custid -- normal archived master
			)
		GROUP BY b.CustID
	END	


	--TODO: SabaWalletTicket	
	SELECT @FDate = @FromDate, @TDate = @ToDate

	INSERT INTO @SAgWinLossDetails(CustID,RewardAmount)
	SELECT  dl.custid, SUM(b.Amount)
	FROM dbo.SabaWalletTicket b WITH (NOLOCK)
	INNER JOIN #downlineList dl ON  dl.custid = b.Mrecommend AND dl.roleid = 3
	WHERE b.WinlostDate BETWEEN @FDate AND @TDate
		AND b.WalletID = 2
	GROUP BY dl.custid
	UNION ALL
	SELECT  dl.custid, SUM(b.Amount)
	FROM dbo.SabaWalletTicket b WITH (NOLOCK)
	INNER JOIN #downlineList dl ON  dl.custid = b.custid AND dl.roleid = 1
	WHERE b.WinlostDate BETWEEN @FDate AND @TDate
		AND b.WalletID = 2
	GROUP BY dl.custid
	

	--TODO: Result
	IF ((@PageSize <= 0) AND (@PageIndex <= 0))
	BEGIN
	    
		SELECT
			w.CustID, 
			dl.UserName, dl.roleId,
			SUM(TurnOver) AS TurnOver,
			SUM(TurnoverNoDraw) AS TurnoverNoDraw,
			SUM(GrossComm) AS GrossComm,
			SUM(MemberWinLost) AS MemberWinlost,
			SUM(PlayerComm) AS PlayerComm,
			SUM(MemberTotal) AS MemberTotal,
			SUM(AgWinlost) AS AgWinlost,
			SUM(AgComm) AS AgComm,
			SUM(AgTotal) AS AgTotal,
			SUM(MAgWinlost) AS MAgWinlost,
			SUM(MAgComm) AS MAgComm,
			SUM(MAgTotal) AS MAgTotal,
			SUM(SAgWinlost) AS SAgWinlost,
			SUM(SAgComm) AS SAgComm,
			SUM(SAgTotal) AS SAgTotal,
			SUM(Company) AS Company,
			SUM(RewardAmount) AS RewardAmount,
			dl.CurrencyCode AS RewardCurrency
		FROM @SAgWinLossDetails w 
		LEFT JOIN #downlineList dl ON dl.CustID = w.CustID
		GROUP BY w.CustID, dl.UserName, dl.CurrencyCode,dl.roleId
		ORDER BY IIF(dl.Username IS NULL,1,0), dl.Username;
		
		RETURN
	END


	IF @TotalRows = 0  
	BEGIN  
		SELECT @TotalRows = COUNT(DISTINCT CustID) 
		FROM @SAgWinLossDetails
	END

	SELECT wl.*
	FROM
		(
		SELECT
			w.CustID, 
			dl.UserName, dl.roleId,
			SUM(TurnOver) AS TurnOver,
			SUM(TurnoverNoDraw) AS TurnoverNoDraw,
			SUM(GrossComm) AS GrossComm,
			SUM(MemberWinLost) AS MemberWinlost,
			SUM(PlayerComm) AS PlayerComm,
			SUM(MemberTotal) AS MemberTotal,
			SUM(AgWinlost) AS AgWinlost,
			SUM(AgComm) AS AgComm,
			SUM(AgTotal) AS AgTotal,
			SUM(MAgWinlost) AS MAgWinlost,
			SUM(MAgComm) AS MAgComm,
			SUM(MAgTotal) AS MAgTotal,
			SUM(SAgWinlost) AS SAgWinlost,
			SUM(SAgComm) AS SAgComm,
			SUM(SAgTotal) AS SAgTotal,
			SUM(Company) AS Company,
			SUM(RewardAmount) AS RewardAmount,
			dl.CurrencyCode AS RewardCurrency,
			ROW_NUMBER() OVER(ORDER BY IIF(dl.Username IS NULL,1,0),dl.UserName) AS RowNum	    
		FROM @SAgWinLossDetails w 
			LEFT JOIN #downlineList dl ON dl.custid = w.CustID
		GROUP BY w.CustID, dl.UserName, dl.CurrencyCode, dl.roleId
	) wl
	WHERE wl.RowNum between @RowStart and @RowEnd;
END	
GO
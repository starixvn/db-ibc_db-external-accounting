/*<info serverAlias="DBAGE-bodb02" executers="wsv_xnap" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[EAS_Rpt_WinLossDetail_MAg]
	@custid			INT,--mrecommend
	@Agentid		INT = NULL,
	@FromDate		SMALLDATETIME,
	@ToDate			SMALLDATETIME,
	@ProductIds		VARCHAR(MAX) = '',
	@ProductDetails NVARCHAR(MAX) = 'All',
	@MoveBetsDay	SMALLDATETIME,
	@BalanceUpDay	SMALLDATETIME,
	@PageSize		INT = 0,
	@PageIndex		INT = 0,
	@TotalRows		INT = 0 OUTPUT,
	@MemberId		INT = NULL
AS
/*
Created by: Scott
Date: 2012-11-13
Task : Agent Winloss Detail
DB: DBAGE/bodb02
Original SP: [Age_Rpt_WinLossDetail_MAg_New]
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
	- 20161020@Francis: Enhance SP and avoid pagesplit by prompting index seek on bettrans [Redmine: #65042]
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
	- 20241216@Bobby: Enhance MBU & Base Currency [RedmineID: #213507]
	- 20241226@Bobby: Super/Master Direct Members [RedmineID: #211969]
	- 20250716@Virgil: Apply Agency Cash Service - Report changes [RedmineID: #232418]
	
	Param's Explanation:
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

	DECLARE @RowStart INT, @RowEnd INT, @FDate SMALLDATETIME, @TDate SMALLDATETIME, @__ProductDetails XML, @RangeType TINYINT;

	SELECT @FDate = @FromDate, @TDate = @ToDate

	SELECT @PageIndex = @PageIndex - 1, @RowStart = @PageSize * @PageIndex + 1, @RowEnd = @RowStart + @PageSize - 1

	DECLARE @ExistingProductDetails TABLE (ProductId INT,Sporttype INT,Bettype INT, LeagueGroupID SMALLINT, TicketType TINYINT)
	DECLARE @MAgWinLossDetails TABLE(
		CustID			INT, 
		TurnOver		DECIMAL(24,4), 
		TurnoverNoDraw	DECIMAL(24,4), 
		GrossComm		DECIMAL(24,4), 
		MemberWinLost	DECIMAL(24,4), 
		PlayerComm		DECIMAL(24,4), 
		AgWinLost		DECIMAL(24,4), 
		AgComm			DECIMAL(24,4), 
		MAgWinLost		DECIMAL(24,4), 
		MAgComm			DECIMAL(24,4), 
		Acomm			DECIMAL(24,4),
		RewardAmount	DECIMAL(24,4)
	)

	DECLARE @GrossComm TABLE (winlostdate SMALLDATETIME,CustId INT, TurnoverNoDraw DECIMAL(24,4), GrossComm DECIMAL(24,4))

	SELECT @ProductIds = bodb02.dbo.f_AddRelatedProducts(@ProductIds)
	SELECT @__ProductDetails = CONVERT(XML, @ProductDetails)

	INSERT INTO @ExistingProductDetails(ProductId,Sporttype,Bettype,LeagueGroupID,TicketType)
	SELECT ProductId,Sporttype,Bettype,LeagueGroupID,TicketType
	FROM dbo.f_ProductDetail_ConditionSel(@ProductDetails, @__ProductDetails)

	DECLARE @SeparateSabaSport_Cutoff SMALLDATETIME 

	SELECT @SeparateSabaSport_Cutoff = CutoffDate
	FROM dbo.f_GetCutoffDate()
	WHERE TypeName = 'SabaSport'

	DECLARE @TmpCondSumWL TABLE(ProductID TINYINT, sporttype INT, bettype INT,	LeagueGroupID SMALLINT, TicketType TINYINT)

	IF @FromDate <= @MoveBetsDay
	BEGIN
		INSERT INTO @TmpCondSumWL(ProductID, SportType, BetType, LeagueGroupID, TicketType) 
		SELECT f.ProductID, f.SportType, f.BetType, f.LeagueGroupID, f.TicketType
		FROM dbo.f_SumWinloss_ConditionSel(@ProductIds) f
			LEFT JOIN @ExistingProductDetails e ON f.ProductID = e.ProductId 
		WHERE e.ProductId IS NULL OR (e.Bettype = f.BetType AND e.Sporttype = f.SportType AND e.TicketType = f.TicketType AND e.LeagueGroupID = f.LeagueGroupID AND e.ProductID = f.ProductId)
	END

	----Get Sport Bettype Matrix------
	DECLARE @isTest BIT = 0
	SELECT  @isTest = dbo.f_CheckSPVersion(@@PROCID)

	DROP TABLE IF EXISTS #tmpSportBettype;
	SELECT	ISNULL(p.GroupProductId, f.ProductID) AS ProductID, f.BetType, f.RefTable, ISNULL(e.LeagueGroupID,0) AS LeagueGroupID, ISNULL(e.TicketType,0) AS TicketType, ISNULL(SportType,0) AS SportType
	INTO #tmpSportBettype
	FROM dbo.f_SportBettypeMatrixByProduct_Sel(@ProductIds, @IsTest) f
		LEFT JOIN dbo.f_GroupProduct() p ON f.ProductID = p.ProductId
		LEFT JOIN @ExistingProductDetails e ON e.ProductId = f.ProductID 
	WHERE EXISTS(
		SELECT 1
		WHERE e.ProductId IS NULL 
			OR (
				e.Bettype = f.BetType 
				OR (
					e.Bettype = 0  AND  (e.ProductId = 1 OR  f.BetType NOT IN (SELECT g.Bettype FROM f_GetProductDetail() g WHERE g.ProductId <> 1) )
				)
			)
		)		

	--TODO: Get downlines
	DECLARE @downlineList TABLE(custid INT PRIMARY KEY, srecommend INT, recommend INT, UserName VARCHAR(30), roleid TINYINT, CurrencyId INT, CurrencyName NVARCHAR(15), CurrencyCode NVARCHAR(5));

	INSERT INTO @downlineList(custid, srecommend, recommend, UserName, CurrencyId, RoleId, CurrencyName, CurrencyCode)
	SELECT ci.custid, ci.srecommend, ci.recommend, ci.UserName, ci.Currency, ci.roleid, ex.Currency, ex.Code
	FROM (VALUES(@Agentid)) AS t (AgentId)
	OUTER APPLY (
		SELECT ci.custid
		FROM dbo.custinfo ci WITH(NOLOCK)
		WHERE ci.mrecommend = @CustID
			AND ci.RoleId = 2
			AND t.Agentid IS NULL

		UNION ALL
		SELECT ci.custid
		FROM dbo.custinfo ci WITH(NOLOCK)
		WHERE ci.mrecommend = @CustID
			AND ci.RoleId = 1
			AND ci.recommend = -3
			AND t.Agentid IS NULL
		UNION ALL
		SELECT ci.custid
		FROM dbo.custinfo ci WITH(NOLOCK)
		WHERE ci.mrecommend = @CustID
			AND ci.RoleId = 2
			AND ci.custid = t.AgentId
	) AS dl
	INNER JOIN dbo.Customer ci WITH(NOLOCK) ON ci.custid = dl.custid
	INNER JOIN dbo.Exchange ex WITH(NOLOCK) ON ex.ExchangeId = ci.Currency
	WHERE (
			@memberId IS NULL OR 
			@memberId = dl.custid --> search Direct Member
		)
		
	--TODO: Compile downline vs range time
	DROP TABLE IF EXISTS #tmpDownline;
	CREATE TABLE #tmpDownline (RangeType TINYINT, winlostdate SMALLDATETIME, srecommend INT, mrecommend INT, recommend INT, roleid TINYINT, custid INT 
		PRIMARY KEY (RangeType, custid, winlostdate));

	--TODO: bettrans_compact
	SET @RangeType = 1;
	SELECT @FDate = FromDate, @TDate = ToDate
	FROM (VALUES(@FromDate)) AS t (CheckDate)
	OUTER APPLY (
		SELECT * FROM dbo.f_MBU_RangeDate(CheckDate, @ToDate, @BalanceUpDay, @MoveBetsDay)
		WHERE RangeType = @RangeType
	) AS fc

	IF @FDate IS NOT NULL
	BEGIN

		INSERT @MAgWinLossDetails (CustID, TurnOver, TurnoverNoDraw, GrossComm, MemberWinLost, 
									PlayerComm, AgWinLost, AgComm,  
									MAgWinLost, MAgComm, Acomm )
		SELECT b.custid
			,SUM(b.turnover)
			,SUM(b.TurnoverNoDraw)
			,SUM(b.GrossComm)
			,SUM(b.winlost)
			,SUM(b.playercomm)
			,SUM(b.awinlost)
			,SUM(b.comm-b.playercomm)
			,SUM(b.mwinlost)
			,SUM(b.acomm-b.comm)
			,SUM(b.acomm)
		FROM bodb_AGE.dbo.bettrans_compact b WITH(NOLOCK)
			INNER JOIN @downlineList dl ON dl.custid = b.custid
			INNER JOIN #tmpSportBettype s ON b.bettype = s.bettype 
				AND (s.ProductID <> 1 OR (s.ProductID = 1 AND b.sporttype = s.SportType AND b.LeagueGroupID = s.LeagueGroupID AND b.TicketType = s.TicketType))
		
		WHERE b.winlostdate BETWEEN @FDate AND @TDate
		GROUP BY b.custid

		-- bettransRnG
		INSERT INTO @GrossComm (CustId, TurnoverNoDraw, GrossComm)
		SELECT dl.CustId
			,SUM(CASE WHEN cont.ContributionBettype IS NULL THEN b.BetStake ELSE 0 END) AS TurnoverNoDraw
			,SUM(b.BetStake * b.adiscount) AS GrossComm
		FROM dbo.bettransRnG b WITH(NOLOCK)
			INNER JOIN @downlineList dl ON dl.custid = IIF(b.recommend=-3, b.custid, b.recommend)
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
			AND b.mrecommend = @custid
		GROUP BY dl.custid
			
		-- bettransLC
		INSERT INTO @GrossComm (CustId, TurnoverNoDraw, GrossComm)
		SELECT dl.CustId
			,SUM(CASE WHEN cont.ContributionBettype IS NULL THEN b.NetStake ELSE 0 END) AS TurnoverNoDraw
			,SUM(b.NetStake * b.adiscount) AS GrossComm
		FROM dbo.bettransLC b WITH(NOLOCK)
			INNER JOIN @downlineList dl ON dl.custid = IIF(b.recommend=-3, b.custid, b.recommend)
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
			AND b.mrecommend = @custid
		GROUP BY dl.custid

		IF EXISTS (SELECT 1 FROM @GrossComm)
		BEGIN
			UPDATE t
			SET t.TurnoverNoDraw = ISNULL(t.TurnoverNoDraw, 0) + ISNULL(c.TurnoverNoDraw, 0)
				,t.GrossComm = ISNULL(t.GrossComm, 0) + ISNULL(c.GrossComm, 0)
			FROM @MAgWinLossDetails t
				INNER JOIN (
					SELECT CustId, SUM(GrossComm) AS GrossComm, SUM(TurnoverNoDraw) AS TurnoverNoDraw FROM @GrossComm GROUP BY CustId
				) c ON t.CustId = c.CustId
		END
			
	END

	--TODO: sum_winloss
	SET @RangeType = 2
	SELECT @FDate = FromDate, @TDate = ToDate
	FROM (VALUES(@FromDate)) AS t (CheckDate)
	OUTER APPLY (
		SELECT * FROM dbo.f_MBU_RangeDate(CheckDate, @ToDate, @BalanceUpDay, @MoveBetsDay)
		WHERE RangeType = @RangeType
	) AS fc

	IF @FDate IS NOT NULL
	BEGIN
		WITH CTE_Winlostdate AS (
			SELECT @FDate AS Winlostdate
			UNION ALL
			SELECT DATEADD(DAY, 1, Winlostdate)
			FROM CTE_Winlostdate
			WHERE Winlostdate < @TDate
		)
		INSERT INTO #tmpDownline
		SELECT @RangeType, wld.winlostdate, dl.srecommend,  @custid AS mrecommend, dl.recommend, dl.roleid, dl.custid
		FROM CTE_Winlostdate wld
		CROSS JOIN @downlineList dl;

		INSERT INTO @MAgWinLossDetails (CustID, TurnOver, TurnoverNoDraw, GrossComm, MemberWinLost, 
									PlayerComm, AgWinLost, AgComm,  
									MAgWinLost, MAgComm, Acomm )
		SELECT
			dl.CustID,			
			SUM(ABS(TurnOver)) as TurnOver,
			SUM(ABS(TunroverNoDraw)) as TurnoverNoDraw,
			SUM(grosscomm) as GrossComm,
			SUM(winlost), --MemberWinlost
			SUM(playercomm), -- PlayerComm
			SUM(awinlost), -- AgWinlost
			SUM(ISNULL(comm,0)-ISNULL(playercomm,0)), --AgComm
			SUM(mwinlost), -- MAgWinlost
			SUM(ISNULL(acomm,0)-ISNULL(comm,0)), --MAgComm
			SUM(ISNULL(acomm,0))		
		FROM dbo.sum_winloss b WITH (NOLOCK) 
			INNER JOIN #tmpDownline dl ON dl.winlostdate = b.winlostdate
				AND dl.srecommend = b.srecommend
				AND dl.mrecommend = b.mrecommend
				AND dl.recommend = b.recommend
				AND dl.roleid = b.roleid
				AND dl.custid = b.custid
			INNER JOIN @TmpCondSumWL t ON b.sporttype = t.sporttype 
				AND b.bettype = t.bettype 
				AND b.leagueGroupID = t.LeagueGroupID 
				AND b.ticketType = t.TicketType
		WHERE dl.RangeType = @RangeType
		GROUP BY dl.CustID
	END

	-- Cash Service Billing 
	IF ',' + @ProductIDs + ',' LIKE '%,111,%'
	BEGIN
		SELECT @FDate = fc.FromDate, @TDate = fc.ToDate
		FROM (VALUES(@FromDate)) AS t (CheckDate)
		OUTER APPLY (
			SELECT 
				MIN(FromDate) AS FromDate,
				MAX(ToDate) AS ToDate
			FROM dbo.f_MBU_RangeDate(CheckDate, @ToDate, @BalanceUpDay, @MoveBetsDay)
			WHERE RangeType IN (1,2)
		) AS fc
		
		INSERT INTO @MAgWinLossDetails (CustID, TurnOver, TurnoverNoDraw, GrossComm, MemberWinLost, 
									PlayerComm, AgWinLost, AgComm,  
									MAgWinLost, MAgComm, Acomm )
		SELECT tr.CustID,			
			0 as TurnOver,
			0 as TurnoverNoDraw,
			0 as GrossComm,
			0 as MemberWinLost, 
			0 as PlayerComm,
			SUM(WinLost-Actual_Stake) AS AgWinlost,
			0 as AgComm,
			0 as MAgWinLost,
			0 as MAgComm,
			0 as Acomm		
		FROM dbo.Transfer tr (NOLOCK)
		INNER JOIN @downlineList dl 
			ON dl.srecommend = tr.srecommend
			AND dl.recommend = tr.recommend
			AND dl.custid = tr.custid
		INNER JOIN #tmpSportBettype s 
			ON tr.bettype = s.bettype 
			AND s.Bettype IN (31003,31004,31005)
		WHERE tr.winlostdate BETWEEN @FDate AND @TDate
		GROUP BY tr.CustId;
	END

	--TODO: sum_winloss_old
	SET @RangeType = 3;
	SELECT @FDate = FromDate, @TDate = ToDate
	FROM (VALUES(@FromDate)) AS t (CheckDate)
	OUTER APPLY (
		SELECT * FROM dbo.f_MBU_RangeDate(CheckDate, @ToDate, @BalanceUpDay, @MoveBetsDay)
		WHERE RangeType = @RangeType
	) AS fc

	IF @FDate IS NOT NULL
	BEGIN
		WITH CTE_Winlostdate AS (
			SELECT @FDate AS Winlostdate
			UNION ALL
			SELECT DATEADD(DAY, 1, Winlostdate)
			FROM CTE_Winlostdate
			WHERE Winlostdate < @TDate
		)
		INSERT INTO #tmpDownline
		SELECT @RangeType, wld.winlostdate, dl.srecommend,  @custid AS mrecommend, dl.recommend, dl.roleid, dl.custid
		FROM CTE_Winlostdate wld
		CROSS JOIN @downlineList dl
		OPTION (MAXRECURSION 0);

		INSERT INTO @MAgWinLossDetails (CustID, TurnOver, TurnoverNoDraw, GrossComm, MemberWinLost, 
											PlayerComm,  AgWinLost, AgComm,  
											MAgWinLost, MAgComm, Acomm )
		SELECT
			dl.CustID,
			SUM(ABS(TurnOver)) as TurnOver,
			SUM(ABS(TunroverNoDraw)) as TurnoverNoDraw,
			SUM(grosscomm) as GrossComm,
			SUM(IIF(t.ProductID = 111, 0, winlost)), --MemberWinlost
			SUM(playercomm), -- PlayerComm
			SUM(IIF(t.ProductID = 111, winlost, awinlost)), -- AgWinlost
			SUM(ISNULL(comm,0)-ISNULL(playercomm,0)), --AgComm
			SUM(mwinlost), -- MAgWinlost
			SUM(ISNULL(acomm,0)-ISNULL(comm,0)), --MAgComm
			SUM(ISNULL(acomm,0))
		FROM bodb_Summary.dbo.Sum_WinLoss_Old b WITH(NOLOCK) 
			INNER JOIN #tmpDownline dl ON dl.winlostdate = b.winlostdate
				AND dl.srecommend = b.srecommend
				AND dl.mrecommend = b.mrecommend
				AND dl.recommend = b.recommend
				AND dl.roleid = b.roleid
				AND dl.custid = b.custid
			INNER JOIN @TmpCondSumWL t 
				ON b.sporttype = t.sporttype 
				AND b.bettype = t.bettype 
				AND b.leagueGroupID = t.LeagueGroupID 
				AND b.ticketType = t.TicketType
		WHERE dl.RangeType = @RangeType
		GROUP BY dl.CustID
	END

	--TODO: SabaWalletTicket
	SELECT @FDate = @FromDate, @TDate = @ToDate

	INSERT INTO @MAgWinLossDetails (CustID,RewardAmount)
	SELECT dl.custid,SUM(b.Amount)
	FROM dbo.SabaWalletTicket b WITH (NOLOCK)
		INNER JOIN @downlineList dl ON dl.custid = b.Recommend AND dl.roleid = 2
	WHERE b.WinlostDate BETWEEN @FDate AND @TDate
		AND b.WalletID = 2
		AND b.Mrecommend = @custid
	GROUP BY dl.custid

	UNION ALL
	SELECT dl.custid,SUM(b.Amount)
	FROM dbo.SabaWalletTicket b WITH (NOLOCK)
		INNER JOIN @downlineList dl ON dl.custid = b.custid AND dl.roleid = 1
	WHERE b.WinlostDate BETWEEN @FDate AND @TDate
		AND b.WalletID = 2
		AND b.Mrecommend = @custid
	GROUP BY dl.custid

	--TODO: Result
	IF ((@PageSize <= 0) AND (@PageIndex <= 0))
	BEGIN
		SELECT
			c.CustID, 
			c.UserName, c.RoleId,
			SUM(TurnOver) as TurnOver,
			SUM(TurnoverNoDraw) as TurnoverNoDraw,
			SUM(GrossComm) as GrossComm,
			SUM(MemberWinLost) as MemberWinlost,
			SUM(PlayerComm) as PlayerComm,
			SUM(MemberWinLost+PlayerComm) as MemberTotal,
			SUM(AgWinlost) as AgWinlost,
			SUM(AgComm) as AgComm,
			SUM(AgWinlost+AgComm) as AgTotal,
			SUM(MAgWinlost) as MAgWinlost,
			SUM(MAgComm) as MAgComm,
			SUM(MAgWinlost+MAgComm) as MAgTotal,
			-SUM(MAgWinLost+AgWinLost+Acomm+MemberWinLost) as Company,
			SUM(RewardAmount) AS RewardAmount,
			c.CurrencyCode AS RewardCurrency
		FROM @MAgWinLossDetails w 
			LEFT JOIN @downlineList c 
				ON w.CustID = c.CustID 
		GROUP BY c.CustID, c.UserName, c.CurrencyCode, c.RoleId
		ORDER BY IIF(c.Username IS NULL,1,0),c.Username;

		RETURN
	END

	IF @TotalRows = 0  
	BEGIN  
		SELECT @TotalRows = COUNT(DISTINCT CustID) 
		FROM @MAgWinLossDetails
	END

	SELECT wl.*
	FROM
		(
			SELECT
				c.CustID, 
				c.UserName, c.RoleId, 
				SUM(TurnOver) AS TurnOver,
				SUM(GrossComm) AS GrossComm,
				SUM(MemberWinLost) AS MemberWinlost,
				SUM(PlayerComm) AS PlayerComm,
				SUM(MemberWinLost+PlayerComm) as MemberTotal,
				SUM(AgWinlost) as AgWinlost,
				SUM(AgComm) as AgComm,
				SUM(AgWinlost+AgComm) as AgTotal,
				SUM(MAgWinlost) as MAgWinlost,
				SUM(MAgComm) as MAgComm,
				SUM(MAgWinlost+MAgComm) as MAgTotal,
				-SUM(MAgWinLost+AgWinLost+Acomm+MemberWinLost) as Company,
				SUM(RewardAmount) AS RewardAmount,
				c.CurrencyCode AS RewardCurrency,
				ROW_NUMBER() OVER (ORDER BY IIF(c.Username IS NULL,1,0),c.UserName) AS RowNum
			FROM @MAgWinLossDetails w 
				LEFT JOIN @downlineList c 
					ON w.CustID = c.CustID 
			GROUP BY c.CustID, c.UserName, c.CurrencyCode, c.RoleId
		) wl	    
	WHERE wl.RowNum BETWEEN @RowStart AND @RowEnd;
END	
GO
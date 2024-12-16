/*<info serverAlias="DBAGE-bodb02" executers="wsv_xnap" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[EAS_Rpt_WinLossDetail_Com] 	
	@GroupName		VARCHAR(50) = 'ACCTHAI',--ACCTHAI or ACCINDO
	@custid			INT = NULL,	
	@FromDate		SMALLDATETIME,
	@ToDate			SMALLDATETIME,
	@ProductIds		VARCHAR(MAX) = '',
	@ProductDetails NVARCHAR(MAX) = 'All',
	@MoveBetsDay	SMALLDATETIME,
	@BalanceUpDay	SMALLDATETIME
AS
/*
	Created by: Dan
	Date: 2012-10-29
	Task : Super Winloss Detail
	DB: DBAGE/bodb02
	Original: Acc_Rpt_WinLossDetail_ComEx
	Revisions:
		- 20130121@Dan: Move sp from DB053/bodb02 to DBEAS/bodb_EAS, call to bodb_AGE for Acc_CustGroup, add linked server DBSUM for bodb_Summary
		- 20140305@Patrick: Add more Keno product(sport:202, bettype between 1501 and 1599)
		- 20140321@Lukas: seperate P2P product to enhance performance
		- 20140420@Francis: revise SP to use temporary table instead of variable table to improve performance
		- 20150502@Lukas: Revise SP to insert into Temporary table (#Sum_WinLoss_Old) of a remote table (DBSUM.bodb_Summary.dbo.Sum_WinLoss_Old) to enhance performance (HotFix #35279)
		- 20150528@Sophia: Apply Gold Deluxe and Sport bettype Matrix [Redmine: #36775]
		- 20150907@Winnie: Add CB [Redmine: #43099]
		- 20151217@Percy: Add Cockfighting [Redmine: #48836]
		- 20160107@Percy: Include new bettype range of the new RNG Casino [Redmine: #48286]
		- 20160215@Percy: Support new product AllBet [Redmine: #50922]
		- 20160225@Sophia: Add new column TurnoverNoDraw [Redmine: #51427]
		- 20160414@Victor: Support new product Voidbridge [Redmine: #55468]
		- 20160809@Percy: Modify Net Turnover for Allbet [RedmineID: #61876]
		- 20160824@Sophia: Enhance Performance (work around for hotfix) [Redmine: #62941]
		- 20160915@Johnson: Integrate NG2 [RedmineSPU: #30]
		- 20161028@Percy: Support Fishing World [RedmineID: #65735]
		- 20161001@Daniel: Change to REASDPAST when get from bettrans due to pagesplit
		- 20161020@Francis: Avoid pagesplit by prompting index seek on bettrans [Redmine: #65042]
		- 20170622@Percy: Combine Betradar Virtual Sports with Virtual Sports [RedmineID: #78340]
		- 20170703@Percy: Support Keno Lottery [RedmineID: #78068]
		- 20170830@Percy:
			1. Integrate Lucky 3 [RedmineID: #76770]
			2. Change list of @show[ProductCode] to @ProductIDs - apply all new products
		- 20171002@Percy: Hotfix - Duplicated data due to duplicated bettype [RedmineID: #84167]
		- 20180913@Percy: Bullfighting - Add data into TurnoverNoDraw column [RedmineID: #101288]
		- 20180914@Percy: Poker Games - Modify GrossComm [RedmineID: #101550]
		- 20181122@Elodie: DB053/bodb_Age Migration [Redmine:#104770]
		- 20190418@Kan: DB053/bodb02 Migration, Move sp from DBEAS/bodb_EAS to DB053/bodb02 [Redmine: #111865]
		- 20190826@Percy: Remove inactive products [RedmineID: #118699]
		- 20200410@Sophia: Add BBIN, Sexy Gaming, SA Gaming [RedmineId: #131358]
		- 20200422@Sophia: Add IBCBet Live Casino [RedmineId: #130693]
		- 20200601@Sophia: Add ION [RedmineId: #132325]
		- 20200708@Sol: Add new columns to the report for Extra PT - Redmine: [#136320]
		- 20200826@Sol: Add new column to the report for Extra PT - Redmine: [#140389]
		- 20200828@Sol: enhance sp to prevent deadlock, increase maxdop to use parallelism - Redmine: [#140531]
		- 20200909@Malcolm: Report Enhancement for Jackpot Product [RedmineID : #139575]
		- 20200915@Malcolm: Add WM Live Casino [Redmine : #131584]
		- 20201201@Malcolm : Add Gold Diamond Gaming [Redmine : #144110]
		- 20201210@Malcolm: Add Big Gaming [RedmineId : #142459]
		- 20201230@Danny : Enhance peformance [Redmine : #147836]
		- 20210310@Malcolm: Add Pragmatic Live Casino [RedmineId : #133717]
		- 20210617@Sol: changed how to calc net turn over - [RedmineId : #156653]
		- 20211122@Percy: Enhance gross comm formula [RedmineID: #164479]
		- 20211215@Percy: Exclude stake of contribution bettypes from Net TO [RedmineID: #166116]
		- 20220106@Evan: Add SG Jackpot - [Redmine: #166685]	
		- 20220208@Danny: Separate Saba Sport Performance [Redmine: #167177]
		- 20221208@Eddie: Add New SABA ESports PinGoal [RedmineID: #181383]
		- 20221222@Bobby: Fix GrossComm on WinLossDetail_Com report [RedmineID: #181912]
		- 20221229@Bobby: Enhance GrossComm figure [RedmineID: #182155]
		- 20230630@Lewis: Add Saba Tennis [RedmineID: #190459]
		- 20240125@Lewis: Show Archived User [RedmineID: #199410]
		- 20240306@Lewis: Add Virtual Ice Hockey [RedmineID: #201129]
		- 20240515@Lewis: Add SABA Kabaddi [RedmineID: #203763]
		- 20240617@Sophia: Bettrans_compact [redmine: 206610]
		- 20240624@Lewis: cte_superBet => Bettrans_compact [redmine: 206610]
	    - 20240918@Lewis: Rebate Retention - Reward [RedmineId: #208503]
		- 20241216@Bobby: Enhance MBU & Base Currency [RedmineID: #213507]
	
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
	SET NOCOUNT ON;

	DROP TABLE IF EXISTS #tmpSuperList;
	CREATE TABLE #tmpSuperList (custID INT PRIMARY KEY)

	DECLARE @ExistingProductDetails TABLE (ProductId INT,Sporttype INT,Bettype INT, LeagueGroupID SMALLINT, TicketType TINYINT)
	DECLARE @FDate SMALLDATETIME, @TDate SMALLDATETIME, @__ProductDetails XML;


	INSERT INTO #tmpSuperList(CustID)
	SELECT cg.custID
	FROM dbo.Acc_CustGroup cg WITH(NOLOCK)
	WHERE (@custid IS NULL OR cg.custid = @custid)
		AND cg.GroupName = @GroupName

	DROP TABLE IF EXISTS #ComWinLossDetails;
	CREATE TABLE #ComWinLossDetails 
	(
		CustID			INT, 
		Turnover		DECIMAL(24,4), 
		TurnoverNoDraw	DECIMAL(24,4), 
		GrossComm		DECIMAL(24,4), 
		MemberWinLost	DECIMAL(24,4), 
		PlayerComm		DECIMAL(24,4), 
		AgWinLost		DECIMAL(24,4), 
		AgComm			DECIMAL(24,4), 
		MAgWinLost		DECIMAL(24,4), 
		MAgComm			DECIMAL(24,4), 
		SAgWinLost		DECIMAL(24,4), 
		SAgComm			DECIMAL(24,4), 
		SComm			DECIMAL(24,4), 
		ExtraWinloss	DECIMAL(24,4), 
		ExtraComm		DECIMAL(24,4), 
		RewardAmount	DECIMAL(24,4)
	)

	DROP TABLE IF EXISTS #TmpCondSumWL;
	CREATE TABLE #TmpCondSumWL (sporttype INT, bettype INT, LeagueGroupID SMALLINT, TicketType TINYINT)--, PRIMARY KEY NONCLUSTERED (Bettype ASC, sporttype ASC))

	SELECT @ProductIds = bodb02.dbo.f_AddRelatedProducts(@ProductIds)
	SELECT @__ProductDetails = CONVERT(XML, @ProductDetails)
	INSERT INTO @ExistingProductDetails(ProductId,Sporttype,Bettype,LeagueGroupID,TicketType)

	SELECT ProductId,Sporttype,Bettype,LeagueGroupID,TicketType
	FROM dbo.f_ProductDetail_ConditionSel(@ProductDetails, @__ProductDetails)

	DECLARE @SeparateSabaSport_Cutoff SMALLDATETIME 

	SELECT @SeparateSabaSport_Cutoff = CutoffDate
	FROM dbo.f_GetCutoffDate()
	WHERE TypeName = 'SabaSport'

	----Get Sport Bettype Matrix------
	DECLARE @isTest BIT = 0
	SELECT  @isTest = dbo.f_CheckSPVersion(@@PROCID)

	DROP TABLE IF EXISTS #SportBettype;
	CREATE TABLE #SportBettype (ProductID INT, Bettype INT, RefTable TINYINT, sporttype SMALLINT, LeagueGroupID SMALLINT, TicketType TINYINT ,PRIMARY KEY NONCLUSTERED (Bettype ASC, ProductID ASC, sporttype ASC, LeagueGroupID ASC, TicketType ASC))

	IF @FromDate <= @MoveBetsDay
	BEGIN
		INSERT INTO #TmpCondSumWL(SportType, BetType, LeagueGroupID, TicketType) 
		SELECT f.SportType, f.BetType, f.LeagueGroupID, f.TicketType
		FROM dbo.f_SumWinloss_ConditionSel(@ProductIds) f
			LEFT JOIN @ExistingProductDetails e ON f.ProductID = e.ProductId 
		WHERE e.ProductId IS NULL OR (e.Bettype = f.BetType AND e.Sporttype = f.SportType AND e.TicketType = f.TicketType AND e.LeagueGroupID = f.LeagueGroupID AND e.ProductID = f.ProductId)
	END

	INSERT INTO #SportBettype (ProductId, BetType, RefTable, LeagueGroupID, TicketType, sporttype)
	SELECT ISNULL(p.GroupProductId, f.ProductID), f.BetType, f.RefTable, ISNULL(e.LeagueGroupID,0) AS LeagueGroupID, ISNULL(e.TicketType,0) AS TicketType, ISNULL(SportType,0) AS SportType
	FROM dbo.f_SportBettypeMatrixByProduct_Sel(@ProductIds, @IsTest) f
		LEFT JOIN bodb02.dbo.f_GroupProduct() p ON P.ProductId = f.ProductID
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

	--TODO: bettrans_compact
	SELECT @FDate = FromDate, @TDate = ToDate
	FROM (VALUES(@FromDate)) AS t (CheckDate)
	OUTER APPLY (
		SELECT * FROM dbo.f_MBU_RangeDate(CheckDate, @ToDate, @BalanceUpDay, @MoveBetsDay)
		WHERE RangeType = 1
	) AS fc
	
	IF @FDate IS NOT NULL
	BEGIN 
		
		DROP TABLE IF EXISTS #ComWinLossDetails_bettrans;
		CREATE TABLE #ComWinLossDetails_bettrans 
		(
			SRecommend		INT, 
			bettype			INT, 
			stake			DECIMAL(24,4), 
			GrossComm		DECIMAL(24,4)
		)
					 
		INSERT INTO #ComWinLossDetails 	(
				CustID, Turnover, TurnoverNoDraw, GrossComm, MemberWinLost, PlayerComm, AgWinLost, AgComm, 
				MAgWinLost, MAgComm, SAgWinLost, SAgComm, ExtraWinloss, ExtraComm, SComm  
			)
		SELECT
			b.CustID
			,SUM(b.Turnover) AS Turnover
			,SUM(TurnoverNoDraw) AS TurnoverNoDraw
			,SUM(GrossComm) AS GrossComm
			,SUM(winlost)
			,SUM(playercomm)
			,SUM(awinlost)
			,SUM(comm-playercomm)
			,SUM(mwinlost)
			,SUM(acomm-comm)
			,SUM(swinlost)
			,SUM(scomm-acomm)
			,SUM(extraWinloss)
			,SUM(extraComm)
			,SUM(scomm)
		FROM bodb_AGE.dbo.bettrans_compact b WITH(NOLOCK)	
			INNER JOIN #tmpSuperList ts ON ts.custid = b.custid  
			INNER JOIN #SportBettype sl ON  sl.bettype = b.bettype
				AND (sl.ProductID <> 1 OR (sl.ProductID = 1 AND b.sporttype = sl.SportType AND b.LeagueGroupID = sl.LeagueGroupID AND b.TicketType = sl.TicketType))

		WHERE b.winlostdate BETWEEN @FDate AND @TDate
		GROUP BY b.CustID

		DELETE #ComWinLossDetails_bettrans;

		IF EXISTS (SELECT 1 FROM #SportBettype WHERE RefTable = 1) -- bettransRnG
		BEGIN
			INSERT INTO #ComWinLossDetails_bettrans (SRecommend, bettype, stake, GrossComm) -- use stake for Net Stake
			SELECT b.srecommend, b.gameID, SUM(b.BetStake), SUM(b.BetStake * b.sdiscount)
			FROM dbo.bettransRnG b WITH (NOLOCK)
			WHERE b.winlostdate BETWEEN @FDate AND @TDate 
				AND b.srecommend IN (SELECT custID FROM #tmpSuperList) 
				and b.statusID IN (111, 112, 113)
			GROUP BY b.srecommend, b.gameID
		END

		IF EXISTS (SELECT 1 FROM #SportBettype WHERE RefTable = 2) -- bettransLC
		BEGIN
			INSERT INTO #ComWinLossDetails_bettrans (SRecommend, bettype, stake, GrossComm) -- use stake for Net Stake
			SELECT b.srecommend, b.gameID, SUM(b.NetStake), SUM(b.NetStake * b.sdiscount)
			FROM dbo.bettransLC b WITH (NOLOCK)
			WHERE b.winlostdate BETWEEN @FDate AND @TDate 
				AND b.srecommend IN (SELECT custID FROM #tmpSuperList) 
				and b.statusID IN (111, 112, 113)
			GROUP BY b.srecommend, b.gameID
		END

		IF EXISTS (SELECT 1 FROM #ComWinLossDetails_bettrans)
		BEGIN
			UPDATE t
			SET t.TurnoverNoDraw = ISNULL(t.TurnoverNoDraw, 0) + ISNULL(c.TurnoverNoDraw, 0)
				,t.GrossComm = ISNULL(t.GrossComm, 0) + ISNULL(c.GrossComm, 0)
			FROM #ComWinLossDetails t
				INNER JOIN (
					SELECT b.srecommend, SUM(b.GrossComm) AS GrossComm, SUM(CASE WHEN cont.ContributionBettype IS NULL THEN b.stake ELSE 0 END) AS TurnoverNoDraw
					FROM #ComWinLossDetails_bettrans b
						INNER JOIN #SportBettype s ON b.bettype = s.Bettype AND s.RefTable IN (1, 2)
						OUTER APPLY 
						(
							SELECT f.Bettype AS ContributionBettype
							FROM dbo.f_BettypePrizeGroup() f
							WHERE f.BettypeGroup = 'Contribution'
								AND f.Bettype = b.bettype
						) cont
					GROUP BY b.srecommend
				) c ON t.CustId = c.srecommend
		END
		
	END
   
	DECLARE @winlostdateTable TABLE (winlostdate SMALLDATETIME, custid INT)
	--TODO: sum_winloss
	SELECT @FDate = FromDate, @TDate = ToDate
	FROM (VALUES(@FromDate)) AS t (CheckDate)
	OUTER APPLY (
		SELECT * FROM dbo.f_MBU_RangeDate(CheckDate, @ToDate, @BalanceUpDay, @MoveBetsDay)
		WHERE RangeType = 2
	) AS fc

	IF @FDate IS NOT NULL
	BEGIN
		
		DELETE @winlostdateTable;

		;WITH CTE_Winlostdate (winlostdate ) AS
		(
			SELECT @FDate AS winlostdate
			UNION ALL
			SELECT DATEADD(DAY, 1, winlostdate)
			FROM CTE_Winlostdate
			WHERE winlostdate < @TDate
		)
		INSERT INTO @winlostdateTable(winlostdate, custid)
		SELECT cte.winlostdate, ts.custid
		FROM CTE_Winlostdate cte
		CROSS JOIN #tmpSuperList ts
		OPTION (MAXRECURSION 0);

		INSERT INTO #ComWinLossDetails(
				CustID, Turnover, TurnoverNoDraw, GrossComm, MemberWinLost, PlayerComm, AgWinLost, AgComm, 
				MAgWinLost, MAgComm, SAgWinLost, SAgComm, ExtraWinloss, ExtraComm, SComm
			)
		SELECT
			ts.CustID,			
			SUM(TurnOver), -- TurnOver
			SUM(TunroverNoDraw) as TurnoverNoDraw,
			SUM(grosscomm) as GrossComm,
			SUM(winlost), --MemberWinlost
			SUM(playercomm), -- PlayerComm
			SUM(awinlost), -- AgWinlost
			SUM(ISNULL(comm,0)-ISNULL(playercomm,0)), --AgComm
			SUM(mwinlost), -- MAgWinlost
			SUM(ISNULL(acomm,0)-ISNULL(comm,0)), --MAgComm
			SUM(swinlost), -- SAgWinlost
			SUM(ISNULL(scomm,0)-ISNULL(acomm,0)), --SAgComm
			SUM(ISNULL(b.ExtraWinloss,0)) AS ExtraWinloss,
			SUM(ISNULL(b.ExtraComm,0)) AS ExtraComm,
			SUM(Scomm)
		FROM dbo.sum_winloss b WITH (NOLOCK)
			INNER JOIN @winlostdateTable ts ON b.srecommend = ts.custID AND b.winlostdate = ts.winlostdate
			INNER JOIN #TmpCondSumWL t ON b.sporttype = t.sporttype 
				AND b.bettype = t.bettype 
				AND b.leagueGroupID = t.LeagueGroupID 
				AND b.ticketType = t.TicketType
		WHERE b.mrecommend = 0
			AND b.recommend = 0
			AND b.RoleID = 4
		GROUP BY ts.CustID
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
		
		DELETE @winlostdateTable;

		;WITH CTE_Winlostdate (winlostdate ) AS
		(
			SELECT @FDate AS winlostdate
			UNION ALL
			SELECT DATEADD(DAY, 1, winlostdate)
			FROM CTE_Winlostdate
			WHERE winlostdate < @TDate
		)
		INSERT INTO @winlostdateTable(winlostdate, custid)
		SELECT cte.winlostdate, ts.custid
		FROM CTE_Winlostdate cte
		CROSS JOIN #tmpSuperList ts
		OPTION (MAXRECURSION 0);

		INSERT INTO #ComWinLossDetails(
				CustID, Turnover, TurnoverNoDraw, GrossComm, MemberWinLost, PlayerComm, AgWinLost, AgComm, 
				MAgWinLost, MAgComm, SAgWinLost, SAgComm, ExtraWinloss, ExtraComm, SComm 
			)
		SELECT
			ts.CustID,			
			SUM(TurnOver), -- TurnOver
			SUM(TunroverNoDraw) as TurnoverNoDraw,
			SUM(grosscomm) as GrossComm,
			SUM(winlost), --MemberWinlost
			SUM(playercomm), -- PlayerComm
			SUM(awinlost), -- AgWinlost
			SUM(ISNULL(comm,0)-ISNULL(playercomm,0)), --AgComm
			SUM(mwinlost), -- MAgWinlost
			SUM(ISNULL(acomm,0)-ISNULL(comm,0)), --MAgComm
			SUM(swinlost), -- SAgWinlost
			SUM(ISNULL(scomm,0)-ISNULL(acomm,0)), --SAgComm
			SUM(ISNULL(b.ExtraWinloss,0)) AS ExtraWinloss,
			SUM(ISNULL(b.ExtraComm,0)) AS ExtraComm,
			SUM(scomm)
		FROM  bodb_Summary.dbo.Sum_WinLoss_Old b WITH(NOLOCK) 
			INNER JOIN @winlostdateTable ts ON b.winlostdate = ts.winlostdate
				AND b.srecommend = ts.custID 
			INNER JOIN #TmpCondSumWL t ON b.sporttype = t.sporttype 
				AND b.bettype = t.bettype 
				AND b.leagueGroupID = t.LeagueGroupID 
				AND b.ticketType = t.TicketType
		WHERE b.mrecommend = 0
			AND b.recommend = 0
			AND b.roleid = 4
		GROUP BY ts.CustID
	END	

	--TODO: SabaWalletTicket
	SELECT @FDate = @FromDate, @TDate = @ToDate

	INSERT INTO #ComWinLossDetails(CustID, RewardAmount)
	SELECT b.Srecommend, SUM(b.Amount)
	FROM SabaWalletTicket b WITH (NOLOCK)
	INNER JOIN #tmpSuperList s 
		ON b.Srecommend = s.custID
	WHERE b.WinlostDate BETWEEN @FDate AND @TDate
		AND b.WalletID = 2
	GROUP BY b.Srecommend

	--TODO: Result
	SELECT
		w.CustID, 
		c.UserName,  
		SUM(TurnOver) as Turnover,
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
		SUM(SAgWinlost) as SAgWinlost,
		SUM(SAgComm) as SAgComm,
		SUM(SAgWinlost+SAgComm) as SAgTotal,
		SUM(ExtraWinloss) AS ExtraWinloss,
		SUM(ExtraComm) AS ExtraComm,
		SUM(ExtraWinloss + ExtraComm) AS ExtraTotal,
		-SUM(SAgWinlost+MAgWinLost+AgWinLost+SComm+MemberWinLost) AS Company,
		-SUM(SAgWinlost+MAgWinLost+AgWinLost+SComm+MemberWinLost+ExtraWinloss+ExtraComm) AS CompanyAfterExtraPT,
		ISNULL(SUM(w.RewardAmount),0) AS RewardAmount,
		e.Code AS RewardCurrency
	FROM #ComWinLossDetails w 
		LEFT JOIN bodb02.dbo.custinfo c WITH(NOLOCK) 
			ON w.CustID = c.CustID 
		LEFT JOIN Exchange e WITH (NOLOCK)
			ON c.currency = e.ExchangeId
	GROUP BY w.CustID, c.UserName, e.Code
	ORDER BY IIF(c.Username IS NULL,1,0),c.Username;

END
GO
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
	@TotalRows		INT = 0 OUTPUT
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
	- 20240619@Lewis: deploy ver _xtest to keep original - bettrans [RedmineID: #206610]
	
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

	DECLARE @RowStart int, @RowEnd int, @iDoc INT, @FDate SMALLDATETIME, @TDate SMALLDATETIME, @__ProductDetails XML;

	SELECT @FDate = @FromDate, @TDate = @ToDate

	SELECT @PageIndex = @PageIndex - 1, @RowStart = @PageSize * @PageIndex + 1, @RowEnd = @RowStart + @PageSize - 1

	DECLARE @ExistingProductDetails TABLE (ProductId INT,Sporttype INT,Bettype INT, LeagueGroupID SMALLINT, TicketType TINYINT)
	DECLARE @MAgWinLossDetails TABLE(CustID int, TurnOver money, TurnoverNoDraw MONEY, GrossComm money, MemberWinLost money, 
		PlayerComm money, MemberTotal money, AgWinLost money, AgComm money, AgTotal money, 
		MAgWinLost money, MAgComm money, MAgTotal money, Company money)
	DECLARE @GrossComm TABLE (CustId INT, TurnoverNoDraw MONEY, GrossComm MONEY)

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
	
	IF @Todate >= @BalanceUpDay
	BEGIN 
		IF @ToDate > @MoveBetsDay
		BEGIN
			IF @MoveBetsDay > @FromDate
				SELECT @FDate = DATEADD(DD, 1, @MoveBetsDay)

			IF @Agentid IS NULL
			BEGIN
				; WITH cte_bettrans AS 
				(
					SELECT  
						Recommend,
						SUM(ABS(b.stake)) stake,
						SUM(CASE
								WHEN s.RefTable IN (1, 2) THEN 0 -- bettransRnG/bettransLC
								WHEN s.ProductId = 47 THEN b.oddsspread -- BBIN
								WHEN s.ProductId = 1 AND b.statusId = 111 THEN 0 -- SB draw
								WHEN s.ProductId = 1 AND b.StatusId IN (112, 113) AND b.modds IN (-0.25, 0.25) THEN ABS(b.stake)/2 -- SB half won/lose
								ELSE ABS(b.stake)
							END) AS TurnoverNoDraw,
						SUM(CASE
								WHEN s.RefTable IN (1, 2) THEN 0
								WHEN apositiontaking + mpositiontaking = 1 THEN 0
								ELSE acomm/(1 - apositiontaking - mpositiontaking)
							END) AS GrossComm,
						SUM(winlost) winlost,
						SUM(actual_stake) actual_stake,
						SUM(playercomm) playercomm,
						SUM(acomm) acomm,
						SUM(comm) comm,
						SUM(scomm) scomm,
						SUM(swinlost) swinlost,
						SUM(mwinlost) mwinlost,
						SUM(awinlost) awinlost
					FROM	bodb02.dbo.bettrans b WITH (NOLOCK)--, INDEX = CIX_recommend_matchid_bettype)
						LEFT JOIN dbo.match m WITH(NOLOCK) ON b.matchid = m.matchid AND m.eventdate = b.winlostdate AND m.sporttype IN (1,2,50,43,5,4,47)
						LEFT JOIN (
							SELECT LeagueGroupID, leagueid
							FROM dbo.League l WITH(NOLOCK) WHERE l.LeagueGroupID IN (42,74,108,113,122,151)
						) AS l  ON m.leagueid = l.leagueid
						OUTER APPLY (
							SELECT CASE WHEN ( 
										(l.LeagueGroupID IN (42,74,108,113) AND m.sporttype = 1 ) 
										 OR (l.LeagueGroupID IN (122, 42) AND m.sporttype = 2 )
										 OR (l.LeagueGroupID = 42 AND m.sporttype = 50)
										 OR (l.LeagueGroupID = 42 AND m.sporttype = 5) --SabaTennis
										 OR (l.LeagueGroupID = 42 AND m.sporttype = 4) --Virtual Ice Hockey
										 OR (l.LeagueGroupID = 42 AND m.sporttype = 47) --SABA Kabaddi
										 OR (l.LeagueGroupID = 151 AND m.sporttype = 43)
									  ) AND b.betdaqid <> -2 AND b.winlostdate >= @SeparateSabaSport_Cutoff THEN m.sporttype
							ELSE 0 END  sporttype, 
							CASE WHEN ( 
										(l.LeagueGroupID IN (42,74,108,113) AND m.sporttype = 1 ) 
											OR (l.LeagueGroupID IN (122, 42) AND m.sporttype = 2 )
											OR (l.LeagueGroupID = 42 AND m.sporttype = 50)
											OR (l.LeagueGroupID = 42 AND m.sporttype = 5) --SabaTennis
											OR (l.LeagueGroupID = 42 AND m.sporttype = 4) --Virtual Ice Hockey
											OR (l.LeagueGroupID = 42 AND m.sporttype = 47) --SABA Kabaddi
											OR (l.LeagueGroupID = 151 AND m.sporttype = 43)
										) AND b.betdaqid <> -2 AND b.winlostdate >= @SeparateSabaSport_Cutoff THEN l.LeagueGroupID
							ELSE 0 END LeagueGroupID,
							CASE WHEN b.betdaqid = -2 THEN 1 ELSE 0 END TicketType
						) AS et
						INNER JOIN #tmpSportBettype s ON b.bettype = s.bettype 
							AND (s.ProductID <> 1 OR (s.ProductID = 1 AND et.sporttype = s.SportType AND et.LeagueGroupID = s.LeagueGroupID AND et.TicketType = s.TicketType))
					WHERE	 winlostdate BETWEEN @FDate AND @TDate
						AND b.statusID IN (111,112,113)
						AND b.mrecommend = @custid
					GROUP BY Recommend
				)
				INSERT INTO @MAgWinLossDetails
				SELECT
					Recommend,			
					sum(ABS(b.stake)) as TurnOver, 
					SUM(TurnoverNoDraw) AS TurnoverNoDraw,
					SUM(GrossComm) AS GrossComm,
					sum(winlost-actual_stake), --MemberWinlost
					sum(playercomm), -- PlayerComm
					isnull(sum(winlost-actual_stake), 0) + isnull(sum(playercomm), 0), --MemberTotal
					sum(awinlost), -- AgWinlost
					isnull(sum(comm-playercomm), 0), --AgComm
					isnull(sum(awinlost), 0) + isnull(sum(comm-playercomm), 0), --AgTotal
					sum(mwinlost), -- MAgWinlost
					sum(acomm)-sum(comm), --MAgComm
					isnull(sum(mwinlost), 0) + isnull(sum(acomm), 0)-sum(comm), --MAgTotal
					-(isnull(sum(awinlost), 0) + isnull(sum(mwinlost), 0) + isnull(sum(acomm), 0) + isnull(sum(winlost-actual_stake), 0))--Company				
				FROM cte_bettrans b
				GROUP BY Recommend

				-- bettransRnG
				INSERT INTO @GrossComm (CustId, TurnoverNoDraw, GrossComm)
				SELECT b.recommend AS CustId
					,SUM(CASE WHEN cont.ContributionBettype IS NULL THEN b.BetStake ELSE 0 END) AS TurnoverNoDraw
					,SUM(b.BetStake * b.adiscount) AS GrossComm
				FROM dbo.bettransRnG b WITH(NOLOCK)
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
				GROUP BY b.recommend
			
				-- bettransLC
				INSERT INTO @GrossComm (CustId, TurnoverNoDraw, GrossComm)
				SELECT b.recommend AS CustId
					,SUM(CASE WHEN cont.ContributionBettype IS NULL THEN b.NetStake ELSE 0 END) AS TurnoverNoDraw
					,SUM(b.NetStake * b.adiscount) AS GrossComm
				FROM dbo.bettransLC b WITH(NOLOCK)
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
				GROUP BY b.recommend

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
			ELSE
			BEGIN
				; WITH cte_bettrans AS 
				(
					SELECT  
						Recommend,
						SUM(ABS(b.stake)) stake,
						SUM(CASE
								WHEN s.RefTable IN (1, 2) THEN 0 -- bettransRnG/bettransLC
								WHEN s.ProductId = 47 THEN b.oddsspread -- BBIN
								WHEN s.ProductId = 1 AND b.statusId = 111 THEN 0 -- SB draw
								WHEN s.ProductId = 1 AND b.StatusId IN (112, 113) AND b.modds IN (-0.25, 0.25) THEN ABS(b.stake)/2 -- SB half won/lose
								ELSE ABS(b.stake)
							END) AS TurnoverNoDraw,
						SUM(CASE
								WHEN s.RefTable IN (1, 2) THEN 0
								WHEN apositiontaking + mpositiontaking = 1 THEN 0
								ELSE acomm/(1 - apositiontaking - mpositiontaking)
							END) AS GrossComm,
						SUM(winlost) winlost,
						SUM(actual_stake) actual_stake,
						SUM(playercomm) playercomm,
						SUM(acomm) acomm,
						SUM(comm) comm,
						SUM(scomm) scomm,
						SUM(swinlost) swinlost,
						SUM(mwinlost) mwinlost,
						SUM(awinlost) awinlost
					FROM	bodb02.dbo.bettrans b WITH (NOLOCK)--, INDEX = CIX_recommend_matchid_bettype)
						LEFT JOIN dbo.match m WITH(NOLOCK) ON b.matchid = m.matchid AND m.eventdate = b.winlostdate AND m.sporttype IN (1,2,50,43,5,4,47)
						LEFT JOIN (
							SELECT LeagueGroupID, leagueid
							FROM dbo.League l WITH(NOLOCK) WHERE l.LeagueGroupID IN (42,74,108,113,122,151)
						) AS l  ON m.leagueid = l.leagueid
						OUTER APPLY (
							SELECT CASE WHEN ( 
										(l.LeagueGroupID IN (42,74,108,113) AND m.sporttype = 1 ) 
										 OR (l.LeagueGroupID IN (122, 42) AND m.sporttype = 2 )
										 OR (l.LeagueGroupID = 42 AND m.sporttype = 50)
										 OR (l.LeagueGroupID = 42 AND m.sporttype = 5) --SabaTennis
										 OR (l.LeagueGroupID = 42 AND m.sporttype = 4) --Virtual Ice Hockey
										 OR (l.LeagueGroupID = 42 AND m.sporttype = 47) --SABA Kabaddi
										 OR (l.LeagueGroupID = 151 AND m.sporttype = 43)
									  ) AND b.betdaqid <> -2 AND b.winlostdate >= @SeparateSabaSport_Cutoff THEN m.sporttype
							ELSE 0 END  sporttype, 
							CASE WHEN ( 
										(l.LeagueGroupID IN (42,74,108,113) AND m.sporttype = 1 ) 
											OR (l.LeagueGroupID IN (122, 42) AND m.sporttype = 2 )
											OR (l.LeagueGroupID = 42 AND m.sporttype = 50)
											OR (l.LeagueGroupID = 42 AND m.sporttype = 5) --SabaTennis
											OR (l.LeagueGroupID = 42 AND m.sporttype = 4) --Virtual Ice Hockey
											OR (l.LeagueGroupID = 42 AND m.sporttype = 47) --SABA Kabaddi
											OR (l.LeagueGroupID = 151 AND m.sporttype = 43)
										) AND b.betdaqid <> -2 AND b.winlostdate >= @SeparateSabaSport_Cutoff THEN l.LeagueGroupID
							ELSE 0 END LeagueGroupID,
							CASE WHEN b.betdaqid = -2 THEN 1 ELSE 0 END TicketType
						) AS et
						INNER JOIN #tmpSportBettype s ON b.bettype = s.bettype 
							AND (s.ProductID <> 1 OR (s.ProductID = 1 AND et.sporttype = s.SportType AND et.LeagueGroupID = s.LeagueGroupID AND et.TicketType = s.TicketType))
					WHERE winlostdate BETWEEN @FDate AND @TDate
						AND b.statusID IN (111,112,113)
						AND b.recommend = @Agentid
					GROUP BY Recommend
				)
				INSERT INTO @MAgWinLossDetails
				SELECT
					Recommend,			
					sum(ABS(b.stake)) as TurnOver, 
					SUM(TurnoverNoDraw) AS TurnoverNoDraw,
					SUM(GrossComm) AS GrossComm,
					sum(winlost-actual_stake), --MemberWinlost
					sum(playercomm), -- PlayerComm
					isnull(sum(winlost-actual_stake), 0) + isnull(sum(playercomm), 0), --MemberTotal
					sum(awinlost), -- AgWinlost
					isnull(sum(comm-playercomm), 0), --AgComm
					isnull(sum(awinlost), 0) + isnull(sum(comm-playercomm), 0), --AgTotal
					sum(mwinlost), -- MAgWinlost
					sum(acomm)-sum(comm), --MAgComm
					isnull(sum(mwinlost), 0) + isnull(sum(acomm), 0)-sum(comm), --MAgTotal
					-(isnull(sum(awinlost), 0) + isnull(sum(mwinlost), 0) + isnull(sum(acomm), 0) + isnull(sum(winlost-actual_stake), 0))--Company				
				FROM cte_bettrans b 
				GROUP BY Recommend

				-- bettransRnG
				INSERT INTO @GrossComm (CustId, TurnoverNoDraw, GrossComm)
				SELECT b.recommend AS CustId
					,SUM(CASE WHEN cont.ContributionBettype IS NULL THEN b.BetStake ELSE 0 END) AS TurnoverNoDraw
					,SUM(b.BetStake * b.adiscount) AS GrossComm
				FROM dbo.bettransRnG b WITH(NOLOCK)
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
					AND b.recommend = @Agentid
				GROUP BY b.recommend
			
				-- bettransLC
				INSERT INTO @GrossComm (CustId, TurnoverNoDraw, GrossComm)
				SELECT b.recommend AS CustId
					,SUM(CASE WHEN cont.ContributionBettype IS NULL THEN b.NetStake ELSE 0 END) AS TurnoverNoDraw
					,SUM(b.NetStake * b.adiscount) AS GrossComm
				FROM dbo.bettransLC b WITH(NOLOCK)
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
					AND b.recommend = @Agentid
				GROUP BY b.recommend

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
		END
		
		SELECT @FDate = @FromDate

		IF @BalanceUpDay > @FromDate
			SELECT @FDate = @BalanceUpDay
		
		IF @FromDate <= @MoveBetsDay
		BEGIN
			IF @ToDate > @MoveBetsDay
				SELECT @TDate = @MoveBetsDay

			IF @Agentid IS NULL
			BEGIN
				INSERT INTO @MAgWinLossDetails
				SELECT
					CustID,			
					sum(ABS(TurnOver)) as TurnOver,
					SUM(ABS(TunroverNoDraw)) as TurnoverNoDraw,
					sum(grosscomm) as GrossComm,
					sum(winlost), --MemberWinlost
					sum(playercomm), -- PlayerComm
					isnull(sum(winlost), 0) + isnull(sum(playercomm), 0), --MemberTotal
					sum(awinlost), -- AgWinlost
					isnull(sum(comm-playercomm), 0), --AgComm
					isnull(sum(awinlost), 0) + isnull(sum(comm-playercomm), 0), --AgTotal
					sum(mwinlost), -- MAgWinlost
					sum(acomm)-sum(comm), --MAgComm
					isnull(sum(mwinlost), 0) + isnull(sum(acomm), 0)-sum(comm), --MAgTotal
					-(isnull(sum(awinlost), 0) + isnull(sum(mwinlost), 0) + isnull(sum(acomm), 0) + isnull(sum(winlost), 0))--Company				
				FROM
					bodb02.dbo.sum_winloss b WITH (NOLOCK) INNER JOIN @TmpCondSumWL t ON b.sporttype = t.sporttype AND b.bettype = t.bettype AND ISNULL(b.leagueGroupID,0) = t.LeagueGroupID AND ISNULL(b.ticketType,0) = t.TicketType
				WHERE winlostdate between @FDate and @TDate			
						AND MRecommend=@custid 
						AND RoleID=2
				GROUP BY CustID		
			END
			ELSE
			BEGIN
				INSERT INTO @MAgWinLossDetails
				SELECT
					CustID,			
					sum(ABS(TurnOver)) as TurnOver,
					SUM(ABS(TunroverNoDraw)) as TurnoverNoDraw,
					sum(grosscomm) as GrossComm,
					sum(winlost), --MemberWinlost
					sum(playercomm), -- PlayerComm
					isnull(sum(winlost), 0) + isnull(sum(playercomm), 0), --MemberTotal
					sum(awinlost), -- AgWinlost
					isnull(sum(comm-playercomm), 0), --AgComm
					isnull(sum(awinlost), 0) + isnull(sum(comm-playercomm), 0), --AgTotal
					sum(mwinlost), -- MAgWinlost
					sum(acomm)-sum(comm), --MAgComm
					isnull(sum(mwinlost), 0) + isnull(sum(acomm), 0)-sum(comm), --MAgTotal
					-(isnull(sum(awinlost), 0) + isnull(sum(mwinlost), 0) + isnull(sum(acomm), 0) + isnull(sum(winlost), 0))--Company				
				FROM
					bodb02.dbo.sum_winloss b WITH (NOLOCK) INNER JOIN @TmpCondSumWL t ON b.sporttype = t.sporttype AND b.bettype = t.bettype AND ISNULL(b.leagueGroupID,0) = t.LeagueGroupID AND ISNULL(b.ticketType,0) = t.TicketType
				WHERE winlostdate between @FDate and @TDate			
					AND b.recommend = @Agentid
					AND RoleID=2
				GROUP BY CustID
			END
		END
		
		
	END

	IF @FromDate < @BalanceUpDay 
	BEGIN
		SELECT @FDate = @FromDate

		IF @ToDate >= DATEADD(dd, -1, @BalanceUpDay)
			SELECT @TDate = DATEADD(dd, -1, @BalanceUpDay)
		
		INSERT INTO @MAgWinLossDetails
		SELECT
			CustID,			
			sum(ABS(TurnOver)) as TurnOver,
			SUM(ABS(TunroverNoDraw)) as TurnoverNoDraw,
			sum(grosscomm) as GrossComm,
			sum(winlost), --MemberWinlost
			sum(playercomm), -- PlayerComm
			isnull(sum(winlost), 0) + isnull(sum(playercomm), 0), --MemberTotal
			sum(awinlost), -- AgWinlost
			isnull(sum(comm-playercomm), 0), --AgComm
			isnull(sum(awinlost), 0) + isnull(sum(comm-playercomm), 0), --AgTotal
			sum(mwinlost), -- MAgWinlost
			sum(acomm)-sum(comm), --MAgComm
			isnull(sum(mwinlost), 0) + isnull(sum(acomm), 0)-sum(comm), --MAgTotal
			-(isnull(sum(awinlost), 0) + isnull(sum(mwinlost), 0) + isnull(sum(acomm), 0) + isnull(sum(winlost), 0))--Company				
		FROM
			bodb_Summary.dbo.Sum_WinLoss_Old b WITH(NOLOCK) INNER JOIN @TmpCondSumWL t ON b.sporttype = t.sporttype AND b.bettype = t.bettype AND ISNULL(b.leagueGroupID,0) = t.LeagueGroupID AND ISNULL(b.ticketType,0) = t.TicketType
		WHERE
			winlostdate between @FDate and @TDate			
			and MRecommend=@custid
			AND (@Agentid is null or b.recommend = @Agentid)
			and RoleID=2
		GROUP BY CustID

	END	


	IF ((@PageSize <= 0) AND (@PageIndex <= 0))
	BEGIN

		SELECT
			c.CustID, 
			c.UserName,  
			sum(TurnOver) as TurnOver,
			SUM(TurnoverNoDraw) as TurnoverNoDraw,
			sum(GrossComm) as GrossComm,
			sum(MemberWinLost) as MemberWinlost,
			sum(PlayerComm) as PlayerComm,
			sum(MemberTotal) as MemberTotal,
			sum(AgWinlost) as AgWinlost,
			sum(AgComm) as AgComm,
			sum(AgTotal) as AgTotal,
			sum(MAgWinlost) as MAgWinlost,
			sum(MAgComm) as MAgComm,
			sum(MAgTotal) as MAgTotal,
			sum(Company) as Company	
		FROM @MAgWinLossDetails w LEFT JOIN bodb02.dbo.Customer c WITH(NOLOCK) ON w.CustID = c.CustID 
		Group by c.CustID, c.UserName
		ORDER BY IIF(c.Username IS NULL,1,0),c.Username;


		RETURN
	END


	IF @TotalRows = 0  
	BEGIN  
		SELECT @TotalRows = count(tmp.CustID)
		FROM 
		(
			SELECT CustID
			FROM @MAgWinLossDetails
			Group by CustID
		) tmp
	 
	END

	SELECT wl.*
	FROM
		(
			SELECT
				c.CustID, 
				c.UserName,  
				sum(TurnOver) as TurnOver,
				sum(GrossComm) as GrossComm,
				sum(MemberWinLost) as MemberWinlost,
				sum(PlayerComm) as PlayerComm,
				sum(MemberTotal) as MemberTotal,
				sum(AgWinlost) as AgWinlost,
				sum(AgComm) as AgComm,
				sum(AgTotal) as AgTotal,
				sum(MAgWinlost) as MAgWinlost,
				sum(MAgComm) as MAgComm,
				sum(MAgTotal) as MAgTotal,
				sum(Company) as Company,
				ROW_NUMBER() over (order by IIF(c.Username IS NULL,1,0),c.UserName) as RowNum
			FROM @MAgWinLossDetails w LEFT JOIN bodb02.dbo.Customer c WITH(NOLOCK) ON w.CustID = c.CustID 
			Group by c.CustID, c.UserName
		) wl
	    
	WHERE wl.RowNum BETWEEN @RowStart AND @RowEnd;
END	
GO
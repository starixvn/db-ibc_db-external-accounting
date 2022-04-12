/*<info serverAlias="DBAGE-bodb02" executers="bodbExtAccNet" isFunction="0" isNested="0"></info>*/
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
	
	Param's Explanation:
	  @ProductDetails:		
		<ROOT>
				<ProductDetail ProductId = "32" Sporttype = "248" Bettype = "0" LeagueGroupID = "0" TicketType = "0"/>
				<ProductDetail ProductId = "32" Sporttype = "248" Bettype = "4298" LeagueGroupID = "0" TicketType = "0"/>
				<ProductDetail ProductId = "1" Sporttype = "0" Bettype = "0" LeagueGroupID = "0" TicketType = "0"/>
				<ProductDetail ProductId = "1" Sporttype = "1" Bettype = "0" LeagueGroupID = "42,74" TicketType = "0"/>
				<ProductDetail ProductId = "1" Sporttype = "1" Bettype = "0" LeagueGroupID = "113" TicketType = "0"/>
				<ProductDetail ProductId = "1" Sporttype = "2" Bettype = "0" LeagueGroupID = "42,74" TicketType = "0"/>
				<ProductDetail ProductId = "1" Sporttype = "2" Bettype = "0" LeagueGroupID = "113" TicketType = "0"/>
		</ROOT>	
*/
BEGIN
	SET NOCOUNT ON

	DECLARE @RowStart int, @RowEnd int, @iDoc INT, @FDate SMALLDATETIME, @TDate SMALLDATETIME, @__ProductDetails XML;

	SELECT @FDate = @FromDate, @TDate = @ToDate

	SELECT @PageIndex = @PageIndex - 1, @RowStart = @PageSize * @PageIndex + 1, @RowEnd = @RowStart + @PageSize - 1

	DECLARE @ExistingProductDetails TABLE (ProductId INT,Sporttype INT,Bettype INT, LeagueGroupID SMALLINT, TicketType TINYINT)
	DECLARE @SAgWinLossDetails TABLE(CustID int, TurnOver money, TurnoverNoDraw MONEY, GrossComm money, MemberWinLost money, 
		PlayerComm money, MemberTotal money, AgWinLost money, AgComm money, AgTotal money, 
		MAgWinLost money, MAgComm money, MAgTotal money, SAgWinLost money, SAgComm money, SAgTotal money, Company money)
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
		
	DECLARE @TmpCondSumWL TABLE(sporttype INT, bettype INT,	LeagueGroupID	SMALLINT, TicketType TINYINT)

	;WITH cte AS 
	(
		SELECT f.SportType, f.BetType, x.LeagueGroupID, f.TicketType, f.ProductID
		FROM dbo.f_SumWinloss_ConditionSel(@ProductIds) f
		CROSS APPLY (SELECT CAST (val AS INT) LeagueGroupID FROM  strSplit(f.LeagueGroupID, ',') x) x
	)
	INSERT INTO @TmpCondSumWL(SportType, BetType, LeagueGroupID, TicketType) 
	SELECT f.SportType, f.BetType, f.LeagueGroupID, f.TicketType
	FROM cte f
		LEFT JOIN @ExistingProductDetails e ON f.ProductID = e.ProductId 
	WHERE e.ProductId IS NULL OR (e.Bettype = f.BetType AND e.Sporttype = f.SportType AND e.TicketType = f.TicketType AND e.LeagueGroupID = f.LeagueGroupID AND e.ProductID = f.ProductId)


	----Get Sport Bettype Matrix------
	DECLARE @isTest BIT = 0
	SELECT  @isTest = dbo.f_CheckSPVersion(@@PROCID)
				
	IF @Todate >= @BalanceUpDay
	BEGIN 
		IF @ToDate > @MoveBetsDay
		BEGIN
			IF @MoveBetsDay > @FromDate
				SELECT @FDate = DATEADD(DD, 1, @MoveBetsDay)

			IF @masterID IS NULL
			BEGIN
				; WITH cte_bettrans AS 
				(	
					SELECT	MRecommend,	
							CASE WHEN ( 
									(l.LeagueGroupID IN (42,74,108,113) AND m.sporttype = 1 ) 
									 OR (l.LeagueGroupID IN (122, 42) AND m.sporttype = 2 )
									 OR (l.LeagueGroupID = 42 AND m.sporttype = 50)
								  ) AND b.betdaqid <> -2 AND b.winlostdate >= @SeparateSabaSport_Cutoff THEN m.sporttype
							ELSE 0 END  sporttype, 
							CASE WHEN ( 
										(l.LeagueGroupID IN (42,74,108,113) AND m.sporttype = 1 ) 
											OR (l.LeagueGroupID IN (122, 42) AND m.sporttype = 2 )
											OR (l.LeagueGroupID = 42 AND m.sporttype = 50)
										) AND b.betdaqid <> -2 AND b.winlostdate >= @SeparateSabaSport_Cutoff THEN l.LeagueGroupID
							ELSE 0 END LeagueGroupID,
							CASE WHEN b.betdaqid = -2 THEN 1 ELSE 0 END TicketType,
							b.bettype,
							b.statusID,
							CASE WHEN  b.modds IN (-0.25, 0.25) THEN b.modds ELSE 0 END modds,
							b.tpositiontaking,
							SUM(ABS(b.stake)) stake,
							SUM(winlost) winlost,
							SUM(actual_stake) actual_stake,
							SUM(playercomm) playercomm,
							SUM(acomm) acomm,
							SUM(comm) comm,
							SUM(scomm) scomm,
							SUM(swinlost) swinlost,
							SUM(mwinlost) mwinlost,
							SUM(awinlost) awinlost,
							SUM(b.oddsspread) oddsspread
					FROM	bodb02.dbo.bettrans b WITH (NOLOCK)
					LEFT JOIN dbo.match m WITH(NOLOCK) ON b.matchid = m.matchid AND m.eventdate = b.winlostdate AND m.sporttype IN (1,2,50)
					LEFT JOIN dbo.League l WITH(NOLOCK) ON m.leagueid = l.leagueid
					WHERE	winlostdate between @FDate and @TDate 
						AND srecommend = @custid 
						AND b.statusID IN (111,112,113)
					GROUP BY MRecommend,	
							CASE WHEN ( 
									(l.LeagueGroupID IN (42,74,108,113) AND m.sporttype = 1 ) 
									 OR (l.LeagueGroupID IN (122, 42) AND m.sporttype = 2 )
									 OR (l.LeagueGroupID = 42 AND m.sporttype = 50)
								  ) AND b.betdaqid <> -2 AND b.winlostdate >= @SeparateSabaSport_Cutoff THEN m.sporttype
							ELSE 0 END , 
							CASE WHEN ( 
										(l.LeagueGroupID IN (42,74,108,113) AND m.sporttype = 1 ) 
											OR (l.LeagueGroupID IN (122, 42) AND m.sporttype = 2 )
											OR (l.LeagueGroupID = 42 AND m.sporttype = 50)
										) AND b.betdaqid <> -2 AND b.winlostdate >= @SeparateSabaSport_Cutoff THEN l.LeagueGroupID
							ELSE 0 END,
							CASE WHEN b.betdaqid = -2 THEN 1 ELSE 0 END,
							b.bettype,
							b.statusID,
							CASE WHEN  b.modds IN (-0.25, 0.25) THEN b.modds ELSE 0 END,
							b.tpositiontaking
				)
				INSERT INTO @SAgWinLossDetails
				SELECT
					MRecommend,			
					sum(ABS(b.stake)) as TurnOver,
					SUM(CASE
						WHEN s.RefTable IN (1, 2) THEN 0 -- bettransRnG/bettransLC
						WHEN s.ProductId = 47 THEN b.oddsspread -- BBIN
						WHEN s.ProductId = 1 AND b.statusId = 111 THEN 0 -- SB draw
						WHEN s.ProductId = 1 AND b.StatusId IN (112, 113) AND b.modds IN (-0.25, 0.25) THEN ABS(b.stake)/2 -- SB half won/lose
						ELSE ABS(b.stake)
					END) AS TurnoverNoDraw,
					SUM(CASE
						WHEN s.RefTable IN (1, 2) THEN 0
						WHEN tpositiontaking = 1 THEN 0
						ELSE scomm/(1 - tpositiontaking)
					END) AS GrossComm,
					sum(winlost-actual_stake), --MemberWinlost
					sum(playercomm), -- PlayerComm
					isnull(sum(winlost-actual_stake), 0) + isnull(sum(playercomm), 0), --MemberTotal
					sum(awinlost), -- AgWinlost
					isnull(sum(comm-playercomm),0), --AgComm
					isnull(sum(awinlost+comm-playercomm), 0), --AgTotal			
					sum(mwinlost), -- MAgWinlost
					sum(acomm)-sum(comm), --MAgComm
					isnull(sum(mwinlost), 0) + isnull(sum(acomm), 0)-sum(comm), --MAgTotal
					sum(swinlost), -- SAgWinlost
					isnull(sum(scomm),0) -isnull(sum(acomm),0), --SAgComm
					isnull(sum(swinlost), 0) + isnull(sum(scomm), 0)-sum(acomm), --SAgTotal
					-(isnull(sum(swinlost), 0) + isnull(sum(awinlost), 0) + isnull(sum(mwinlost), 0) + isnull(sum(scomm), 0) + isnull(sum(winlost-actual_stake), 0)) --Company				
				FROM cte_bettrans b 
					INNER JOIN (
									SELECT	ISNULL(p.GroupProductId, f.ProductID) AS ProductID, f.BetType, f.RefTable, ISNULL(e.LeagueGroupID,0) AS LeagueGroupID, ISNULL(e.TicketType,0) AS TicketType, ISNULL(SportType,0) AS SportType
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
									) s ON b.bettype = s.bettype AND (s.ProductID <> 1 OR (s.ProductID = 1 AND b.sporttype = s.SportType AND b.LeagueGroupID = s.LeagueGroupID AND b.TicketType = s.TicketType))
			
				GROUP BY MRecommend

				-- bettransRnG
				INSERT INTO @GrossComm (CustId, TurnoverNoDraw, GrossComm)
				SELECT b.mrecommend AS CustId
					,SUM(CASE WHEN cont.ContributionBettype IS NULL THEN b.BetStake ELSE 0 END) AS TurnoverNoDraw
					,SUM(b.BetStake * b.sdiscount) AS GrossComm
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
					AND srecommend = @custid
				GROUP BY b.mrecommend
				
				-- bettransLC
				INSERT INTO @GrossComm (CustId, TurnoverNoDraw, GrossComm)
				SELECT b.mrecommend AS CustId
					,SUM(CASE WHEN cont.ContributionBettype IS NULL THEN b.NetStake ELSE 0 END) AS TurnoverNoDraw
					,SUM(b.NetStake * b.sdiscount) AS GrossComm
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
					AND srecommend = @custid
				GROUP BY b.mrecommend
				
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
			ELSE
			BEGIN
				; WITH cte_bettrans AS 
				(	
					SELECT	MRecommend,	
							CASE WHEN ( 
									(l.LeagueGroupID IN (42,74,108,113) AND m.sporttype = 1 ) 
									 OR (l.LeagueGroupID IN (122, 42) AND m.sporttype = 2 )
									 OR (l.LeagueGroupID = 42 AND m.sporttype = 50)
								  ) AND b.betdaqid <> -2 AND b.winlostdate >= @SeparateSabaSport_Cutoff THEN m.sporttype
							ELSE 0 END  sporttype, 
							CASE WHEN ( 
										(l.LeagueGroupID IN (42,74,108,113) AND m.sporttype = 1 ) 
											OR (l.LeagueGroupID IN (122, 42) AND m.sporttype = 2 )
											OR (l.LeagueGroupID = 42 AND m.sporttype = 50)
										) AND b.betdaqid <> -2 AND b.winlostdate >= @SeparateSabaSport_Cutoff THEN l.LeagueGroupID
							ELSE 0 END LeagueGroupID,
							CASE WHEN b.betdaqid = -2 THEN 1 ELSE 0 END TicketType,
							b.bettype,
							b.statusID,
							CASE WHEN  b.modds IN (-0.25, 0.25) THEN b.modds ELSE 0 END modds,
							b.tpositiontaking,
							SUM(ABS(b.stake)) stake,
							SUM(winlost) winlost,
							SUM(actual_stake) actual_stake,
							SUM(playercomm) playercomm,
							SUM(acomm) acomm,
							SUM(comm) comm,
							SUM(scomm) scomm,
							SUM(swinlost) swinlost,
							SUM(mwinlost) mwinlost,
							SUM(awinlost) awinlost,
							SUM(b.oddsspread) oddsspread
					FROM	bodb02.dbo.bettrans b WITH (NOLOCK)
					LEFT JOIN dbo.match m WITH(NOLOCK) ON b.matchid = m.matchid AND m.eventdate = b.winlostdate AND m.sporttype IN (1,2,50)
					LEFT JOIN dbo.League l WITH(NOLOCK) ON m.leagueid = l.leagueid
					WHERE		winlostdate between @FDate and @TDate 
							AND b.mrecommend = @masterID
							AND b.statusID IN (111,112,113)
					GROUP BY MRecommend,	
							CASE WHEN ( 
									(l.LeagueGroupID IN (42,74,108,113) AND m.sporttype = 1 ) 
									 OR (l.LeagueGroupID IN (122, 42) AND m.sporttype = 2 )
									 OR (l.LeagueGroupID = 42 AND m.sporttype = 50)
								  ) AND b.betdaqid <> -2 AND b.winlostdate >= @SeparateSabaSport_Cutoff THEN m.sporttype
							ELSE 0 END , 
							CASE WHEN ( 
										(l.LeagueGroupID IN (42,74,108,113) AND m.sporttype = 1 ) 
											OR (l.LeagueGroupID IN (122, 42) AND m.sporttype = 2 )
											OR (l.LeagueGroupID = 42 AND m.sporttype = 50)
										) AND b.betdaqid <> -2 AND b.winlostdate >= @SeparateSabaSport_Cutoff THEN l.LeagueGroupID
							ELSE 0 END,
							CASE WHEN b.betdaqid = -2 THEN 1 ELSE 0 END,
							b.bettype,
							b.statusID,
							CASE WHEN  b.modds IN (-0.25, 0.25) THEN b.modds ELSE 0 END,
							b.tpositiontaking
				)
				
				INSERT INTO @SAgWinLossDetails
				SELECT
					MRecommend,			
					sum(ABS(b.stake)) as TurnOver,
					SUM(CASE
							WHEN s.RefTable IN (1, 2) THEN 0 -- bettransRnG/bettransLC
							WHEN s.ProductId = 47 THEN b.oddsspread -- BBIN
							WHEN s.ProductId = 1 AND b.statusId = 111 THEN 0 -- SB draw
							WHEN s.ProductId = 1 AND b.StatusId IN (112, 113) AND b.modds IN (-0.25, 0.25) THEN ABS(b.stake)/2 -- SB half won/lose
							ELSE ABS(b.stake)
						END) AS TurnoverNoDraw,
					SUM(CASE
							WHEN s.RefTable IN (1, 2) THEN 0
							WHEN tpositiontaking = 1 THEN 0
							ELSE scomm/(1 - tpositiontaking)
						END) AS GrossComm,
					sum(winlost-actual_stake), --MemberWinlost
					sum(playercomm), -- PlayerComm
					isnull(sum(winlost-actual_stake), 0) + isnull(sum(playercomm), 0), --MemberTotal
					sum(awinlost), -- AgWinlost
					isnull(sum(comm-playercomm),0), --AgComm
					isnull(sum(awinlost+comm-playercomm), 0), --AgTotal			
					sum(mwinlost), -- MAgWinlost
					sum(acomm)-sum(comm), --MAgComm
					isnull(sum(mwinlost), 0) + isnull(sum(acomm), 0)-sum(comm), --MAgTotal
					sum(swinlost), -- SAgWinlost
					isnull(sum(scomm),0) -isnull(sum(acomm),0), --SAgComm
					isnull(sum(swinlost), 0) + isnull(sum(scomm), 0)-sum(acomm), --SAgTotal
					-(isnull(sum(swinlost), 0) + isnull(sum(awinlost), 0) + isnull(sum(mwinlost), 0) + isnull(sum(scomm), 0) + isnull(sum(winlost-actual_stake), 0)) --Company				
				FROM cte_bettrans b
					INNER JOIN (
									SELECT	ISNULL(p.GroupProductId, f.ProductID) AS ProductID, f.BetType, f.RefTable, ISNULL(e.LeagueGroupID,0) AS LeagueGroupID, ISNULL(e.TicketType,0) AS TicketType, ISNULL(SportType,0) AS SportType
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
									) s ON b.bettype = s.bettype AND (s.ProductID <> 1 OR (s.ProductID = 1 AND b.sporttype = s.SportType AND b.LeagueGroupID = s.LeagueGroupID AND b.TicketType = s.TicketType))
				GROUP BY MRecommend

				-- bettransRnG
				INSERT INTO @GrossComm (CustId, TurnoverNoDraw, GrossComm)
				SELECT b.mrecommend AS CustId
					,SUM(CASE WHEN cont.ContributionBettype IS NULL THEN b.BetStake ELSE 0 END) AS TurnoverNoDraw
					,SUM(b.BetStake * b.sdiscount) AS GrossComm
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
					AND mrecommend = @masterID
				GROUP BY b.mrecommend
				
				-- bettransLC
				INSERT INTO @GrossComm (CustId, TurnoverNoDraw, GrossComm)
				SELECT b.mrecommend AS CustId
					,SUM(CASE WHEN cont.ContributionBettype IS NULL THEN b.NetStake ELSE 0 END) AS TurnoverNoDraw
					,SUM(b.NetStake * b.sdiscount) AS GrossComm
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
					AND mrecommend = @masterID
				GROUP BY b.mrecommend
				
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
		END
		
		SELECT @FDate = @FromDate

		IF @BalanceUpDay > @FromDate
			SELECT @FDate = @BalanceUpDay
		
		IF @FromDate <= @MoveBetsDay
		BEGIN
			IF @ToDate > @MoveBetsDay
				SELECT @TDate = @MoveBetsDay

			IF @masterID IS NULL
			BEGIN
				INSERT INTO @SAgWinLossDetails
				SELECT
					CustID,			
					sum(ABS(TurnOver)) as TurnOver,
					SUM(ABS(TunroverNoDraw)) as TurnoverNoDraw,
					sum(grosscomm) as GrossComm,
					sum(winlost), --MemberWinlost
					sum(playercomm), -- PlayerComm
					isnull(sum(winlost), 0) + isnull(sum(playercomm), 0), --MemberTotal
					sum(awinlost), -- AgWinlost
					isnull(sum(comm-playercomm),0), --AgComm
					isnull(sum(awinlost+comm-playercomm), 0), --AgTotal		
					sum(mwinlost), -- MAgWinlost
					sum(acomm)-sum(comm), --MAgComm
					isnull(sum(mwinlost), 0) + isnull(sum(acomm), 0)-sum(comm), --MAgTotal
					sum(swinlost), -- SAgWinlost
					isnull(sum(scomm),0) -isnull(sum(acomm),0), --SAgComm
					isnull(sum(swinlost), 0) + isnull(sum(scomm), 0)-sum(acomm), --SAgTotal
					-(isnull(sum(swinlost), 0) + isnull(sum(awinlost), 0) + isnull(sum(mwinlost), 0) + isnull(sum(scomm), 0) + isnull(sum(winlost), 0)) --Company					
				FROM
					bodb02.dbo.sum_winloss b WITH (NOLOCK) INNER JOIN @TmpCondSumWL t ON b.sporttype = t.sporttype AND b.bettype = t.bettype AND ISNULL(b.leagueGroupID,0) = t.LeagueGroupID AND ISNULL(b.ticketType,0) = t.TicketType
				WHERE
					winlostdate between @FDate and @TDate			
					AND SRecommend = @custid
					AND RoleID = 3
				GROUP BY CustID
			
			END
			ELSE
			BEGIN
				INSERT INTO @SAgWinLossDetails
				SELECT
					CustID,			
					sum(ABS(TurnOver)) as TurnOver,
					SUM(ABS(TunroverNoDraw)) as TurnoverNoDraw,
					sum(grosscomm) as GrossComm,
					sum(winlost), --MemberWinlost
					sum(playercomm), -- PlayerComm
					isnull(sum(winlost), 0) + isnull(sum(playercomm), 0), --MemberTotal
					sum(awinlost), -- AgWinlost
					isnull(sum(comm-playercomm),0), --AgComm
					isnull(sum(awinlost+comm-playercomm), 0), --AgTotal		
					sum(mwinlost), -- MAgWinlost
					sum(acomm)-sum(comm), --MAgComm
					isnull(sum(mwinlost), 0) + isnull(sum(acomm), 0)-sum(comm), --MAgTotal
					sum(swinlost), -- SAgWinlost
					isnull(sum(scomm),0) -isnull(sum(acomm),0), --SAgComm
					isnull(sum(swinlost), 0) + isnull(sum(scomm), 0)-sum(acomm), --SAgTotal
					-(isnull(sum(swinlost), 0) + isnull(sum(awinlost), 0) + isnull(sum(mwinlost), 0) + isnull(sum(scomm), 0) + isnull(sum(winlost), 0)) --Company					
				FROM
					bodb02.dbo.sum_winloss b WITH (NOLOCK) INNER JOIN @TmpCondSumWL t ON b.sporttype = t.sporttype AND b.bettype = t.bettype AND ISNULL(b.leagueGroupID,0) = t.LeagueGroupID AND ISNULL(b.ticketType,0) = t.TicketType
				WHERE
					winlostdate between @FDate and @TDate			
					AND b.mrecommend = @masterID
					AND RoleID = 3
				GROUP BY CustID
			END
		END
		
	END

	IF @FromDate < @BalanceUpDay 
	BEGIN
		SELECT @FDate = @FromDate

		IF @ToDate >= DATEADD(dd, -1, @BalanceUpDay)
			SELECT @TDate = DATEADD(dd, -1, @BalanceUpDay)
			
		SELECT custid,  mrecommend, turnover,TunroverNoDraw as  TurnoverNoDraw, winlost, awinlost, mwinlost, swinlost, playercomm, comm, acomm, scomm, grosscomm, sporttype, bettype , ISNULL(leagueGroupID,0) leagueGroupID, ISNULL(ticketType,0) ticketType
			INTO #Sum_WinLoss_Old
		FROM bodb_Summary.dbo.Sum_WinLoss_Old b WITH(NOLOCK)
		WHERE winlostdate BETWEEN @FDate AND @TDate			
				--and SRecommend IN (SELECT custID FROM @tmpSuperList)
				and SRecommend = @custid
				AND RoleID = 3 
				and (@masterID is null or b.mrecommend = @masterID)
				
		INSERT INTO @SAgWinLossDetails
			SELECT
				CustID,			
				sum(ABS(TurnOver)) as TurnOver,
				SUM(ABS(TurnoverNoDraw)) as TurnoverNoDraw,
				sum(grosscomm) as GrossComm,
				sum(winlost), --MemberWinlost
				sum(playercomm), -- PlayerComm
				isnull(sum(winlost), 0) + isnull(sum(playercomm), 0), --MemberTotal
				sum(awinlost), -- AgWinlost
				isnull(sum(comm-playercomm),0), --AgComm
				isnull(sum(awinlost+comm-playercomm), 0), --AgTotal		
				sum(mwinlost), -- MAgWinlost
				sum(acomm)-sum(comm), --MAgComm
				isnull(sum(mwinlost), 0) + isnull(sum(acomm), 0)-sum(comm), --MAgTotal
				sum(swinlost), -- SAgWinlost
				isnull(sum(scomm),0) -isnull(sum(acomm),0), --SAgComm
				isnull(sum(swinlost), 0) + isnull(sum(scomm), 0)-sum(acomm), --SAgTotal
				-(isnull(sum(swinlost), 0) + isnull(sum(awinlost), 0) + isnull(sum(mwinlost), 0) + isnull(sum(scomm), 0) + isnull(sum(winlost), 0)) --Company								
			FROM
				#Sum_WinLoss_Old b WITH(NOLOCK) INNER JOIN @TmpCondSumWL t ON b.sporttype = t.sporttype AND b.bettype = t.bettype AND b.leagueGroupID = t.LeagueGroupID AND b.ticketType = t.TicketType
			GROUP BY CustID
	END	

	IF ((@PageSize <= 0) AND (@PageIndex <= 0))
	BEGIN
	    
		SELECT
			w.CustID, 
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
			sum(SAgWinlost) as SAgWinlost,
			sum(SAgComm) as SAgComm,
			sum(SAgTotal) as SAgTotal,
			sum(Company) as Company	
		FROM @SAgWinLossDetails w INNER JOIN bodb02.dbo.custinfo c WITH(NOLOCK) ON w.CustID = c.CustID 
		Group by w.CustID, c.UserName
		order by c.Username
		
		RETURN
	END


	IF @TotalRows = 0  
	BEGIN  
		SELECT @TotalRows = count(tmp.CustID)
		FROM 
		(
			SELECT CustID
			FROM @SAgWinLossDetails
			Group by CustID
		) tmp
	 
	END

	SELECT wl.*
	FROM
		(
		SELECT
			w.CustID, 
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
			sum(SAgWinlost) as SAgWinlost,
			sum(SAgComm) as SAgComm,
			sum(SAgTotal) as SAgTotal,
			sum(Company) as Company,
			ROW_NUMBER() over(order by c.UserName) as RowNum
		    
		FROM @SAgWinLossDetails w INNER JOIN bodb02.dbo.custinfo c WITH(NOLOCK) ON w.CustID = c.CustID 
		Group by w.CustID, c.UserName
		) wl

	WHERE wl.RowNum between @RowStart and @RowEnd

END	
GO
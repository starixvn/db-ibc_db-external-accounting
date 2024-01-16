/*<info serverAlias="DBAGE-bodb02" executers="bodbExtAccNet" isFunction="0" isNested="0"></info>*/
CREATE PROCEDURE [dbo].[EAS_Rpt_WinLossDetailByCurrency_SAg]
	@custid			INT,--srecommend
	@masterid		INT = NULL,
	@FromDate		SMALLDATETIME,
	@ToDate			SMALLDATETIME,
	@ProductIds		VARCHAR(MAX) = '',
	@ProductDetails NVARCHAR(MAX) = 'All',
	@MoveBetsDay	SMALLDATETIME,
	@BalanceUpDay	SMALLDATETIME,
	@BaseCurrency	INT = 1, --MYR
	@GroupName		VARCHAR(50)
AS

/*
	Created by: Lewis
	Date: 2023-12-05
	Task : Master Winloss Detail By Currency
	DB: DBAGE/bodb02
	Original: [EAS_Rpt_WinLossDetail_SAg]
	Revisions:
		- 20231205@Lewis: Initialize SP [RedmineID: #196959]
	
	Param's Explanation:
		@BaseCurrency:  0 unchecked
						1 MYR
						2 CNY
						3 THB
						4 IDR


*/
BEGIN
	SET NOCOUNT ON

	-- Exchange Rate Oanda
	CREATE TABLE #tmp_Oanda(
		ExchangeDate SMALLDATETIME
		,CurrencyId INT
		,CurrencyName NVARCHAR(50)
		,Code VARCHAR(12)
		,Rate FLOAT
	)
	INSERT INTO #tmp_Oanda(
		ExchangeDate
		,CurrencyId
		,CurrencyName
		,Code
		,Rate
	)
	SELECT ExchangeDate
		,CurrencyId
		,CurrencyName
		,Code
		,Rate 
	FROM dbo.EAS_f_GetExchangeRate(@FromDate,@ToDate,@GroupName,@BaseCurrency) 
	OPTION (MAXRECURSION 0);

	 
	-----------------------------------------
	DECLARE @FDate SMALLDATETIME, @TDate SMALLDATETIME, @__ProductDetails XML;

	SELECT @FDate = @FromDate, @TDate = @ToDate

	DECLARE @ExistingProductDetails TABLE (ProductId INT,Sporttype INT,Bettype INT, LeagueGroupID SMALLINT, TicketType TINYINT)

	DECLARE @SAgWinLossDetails TABLE(
		winlostdate SMALLDATETIME,
		CustID INT, TurnOver MONEY, TurnoverNoDraw MONEY, GrossComm MONEY, MemberWinLost MONEY, 
		PlayerComm MONEY, MemberTotal MONEY, AgWinLost MONEY, AgComm MONEY, AgTotal MONEY, 
		MAgWinLost MONEY, MAgComm MONEY, MAgTotal MONEY, SAgWinLost MONEY, SAgComm MONEY, SAgTotal MONEY, Company MONEY)

	DECLARE @GrossComm TABLE (winlostdate SMALLDATETIME, CustId INT, TurnoverNoDraw MONEY, GrossComm MONEY)

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
	SELECT	ISNULL(p.GroupProductId, f.ProductID) AS ProductID, f.BetType, f.RefTable, ISNULL(e.LeagueGroupID,0) AS LeagueGroupID, ISNULL(e.TicketType,0) AS TicketType, ISNULL(SportType,0) AS SportType
	INTO #tmpSportBettype
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
					SELECT	
							b.winlostdate,
							MRecommend,
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
								WHEN b.tpositiontaking = 1 THEN 0
								ELSE scomm/(1 - tpositiontaking)
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
					FROM bodb02.dbo.bettrans b WITH (NOLOCK)
						LEFT JOIN dbo.match m WITH(NOLOCK) ON b.matchid = m.matchid AND m.eventdate = b.winlostdate AND m.sporttype IN (1,2,50,43,5)
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
										 OR (l.LeagueGroupID = 151 AND m.sporttype = 43)
									  ) AND b.betdaqid <> -2 AND b.winlostdate >= @SeparateSabaSport_Cutoff THEN m.sporttype
								ELSE 0 END  sporttype, 
								CASE WHEN ( 
											(l.LeagueGroupID IN (42,74,108,113) AND m.sporttype = 1 ) 
												OR (l.LeagueGroupID IN (122, 42) AND m.sporttype = 2 )
												OR (l.LeagueGroupID = 42 AND m.sporttype = 50)
												OR (l.LeagueGroupID = 42 AND m.sporttype = 5) --SabaTennis
												OR (l.LeagueGroupID = 151 AND m.sporttype = 43)
											) AND b.betdaqid <> -2 AND b.winlostdate >= @SeparateSabaSport_Cutoff THEN l.LeagueGroupID
								ELSE 0 END LeagueGroupID,
								CASE WHEN b.betdaqid = -2 THEN 1 ELSE 0 END TicketType
						) AS et
						INNER JOIN #tmpSportBettype s ON b.bettype = s.bettype 
						AND (s.ProductID <> 1 OR (s.ProductID = 1 AND et.sporttype = s.SportType AND et.LeagueGroupID = s.LeagueGroupID AND et.TicketType = s.TicketType))
					WHERE	winlostdate BETWEEN @FDate and @TDate 
						AND srecommend = @custid 
						AND b.statusID IN (111,112,113)
					GROUP BY b.winlostdate,MRecommend
				)
				INSERT INTO @SAgWinLossDetails
				SELECT
					winlostdate,
					MRecommend,			
					SUM(ABS(b.stake)) as TurnOver,
					SUM(TurnoverNoDraw) AS TurnoverNoDraw,
					SUM(GrossComm) AS GrossComm,
					SUM(winlost-actual_stake), --MemberWinlost
					SUM(playercomm), -- PlayerComm
					ISNULL(SUM(winlost-actual_stake), 0) + ISNULL(SUM(playercomm), 0), --MemberTotal
					SUM(awinlost), -- AgWinlost
					ISNULL(SUM(comm-playercomm),0), --AgComm
					ISNULL(SUM(awinlost+comm-playercomm), 0), --AgTotal			
					SUM(mwinlost), -- MAgWinlost
					SUM(acomm)-SUM(comm), --MAgComm
					ISNULL(SUM(mwinlost), 0) + ISNULL(SUM(acomm), 0)-SUM(comm), --MAgTotal
					SUM(swinlost), -- SAgWinlost
					ISNULL(SUM(scomm),0) -ISNULL(SUM(acomm),0), --SAgComm
					ISNULL(SUM(swinlost), 0) + ISNULL(SUM(scomm), 0)-SUM(acomm), --SAgTotal
					-(ISNULL(SUM(swinlost), 0) + ISNULL(SUM(awinlost), 0) + ISNULL(SUM(mwinlost), 0) + ISNULL(SUM(scomm), 0) + ISNULL(SUM(winlost-actual_stake), 0)) --Company				
				FROM cte_bettrans b 
				GROUP BY winlostdate,MRecommend

				-- bettransRnG
				INSERT INTO @GrossComm (winlostdate, CustId, TurnoverNoDraw, GrossComm)
				SELECT
					b.winlostdate
					,b.mrecommend AS CustId
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
				GROUP BY b.winlostdate, b.mrecommend
				
				-- bettransLC
				INSERT INTO @GrossComm (winlostdate, CustId, TurnoverNoDraw, GrossComm)
				SELECT
					b.winlostdate
					,b.mrecommend AS CustId
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
				GROUP BY b.winlostdate,b.mrecommend
				
				IF EXISTS (SELECT 1 FROM @GrossComm)
				BEGIN
					UPDATE t
					SET t.TurnoverNoDraw = ISNULL(t.TurnoverNoDraw, 0) + ISNULL(c.TurnoverNoDraw, 0)
						,t.GrossComm = ISNULL(t.GrossComm, 0) + ISNULL(c.GrossComm, 0)
					FROM @SAgWinLossDetails t
						INNER JOIN (
							SELECT winlostdate,CustId, SUM(GrossComm) AS GrossComm, SUM(TurnoverNoDraw) AS TurnoverNoDraw FROM @GrossComm GROUP BY winlostdate,CustId
						) c ON t.CustId = c.CustId AND t.winlostdate = c.winlostdate
				END
			END
			ELSE
			BEGIN
				; WITH cte_bettrans AS 
				(	
					SELECT
						b.winlostdate,
						MRecommend,	
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
								WHEN tpositiontaking = 1 THEN 0
								ELSE scomm/(1 - tpositiontaking)
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
					FROM	bodb02.dbo.bettrans b WITH (NOLOCK)
						LEFT JOIN dbo.match m WITH(NOLOCK) ON b.matchid = m.matchid AND m.eventdate = b.winlostdate AND m.sporttype IN (1,2,50,43,5)
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
									 OR (l.LeagueGroupID = 151 AND m.sporttype = 43)
								  ) AND b.betdaqid <> -2 AND b.winlostdate >= @SeparateSabaSport_Cutoff THEN m.sporttype
							ELSE 0 END  sporttype, 
							CASE WHEN ( 
										(l.LeagueGroupID IN (42,74,108,113) AND m.sporttype = 1 ) 
											OR (l.LeagueGroupID IN (122, 42) AND m.sporttype = 2 )
											OR (l.LeagueGroupID = 42 AND m.sporttype = 50)
											OR (l.LeagueGroupID = 42 AND m.sporttype = 5) --SabaTennis
											OR (l.LeagueGroupID = 151 AND m.sporttype = 43)
										) AND b.betdaqid <> -2 AND b.winlostdate >= @SeparateSabaSport_Cutoff THEN l.LeagueGroupID
							ELSE 0 END LeagueGroupID,
							CASE WHEN b.betdaqid = -2 THEN 1 ELSE 0 END TicketType
						) AS et
						INNER JOIN #tmpSportBettype s ON b.bettype = s.bettype AND (s.ProductID <> 1 OR (s.ProductID = 1 AND et.sporttype = s.SportType AND et.LeagueGroupID = s.LeagueGroupID AND et.TicketType = s.TicketType))
					WHERE	winlostdate between @FDate and @TDate 
							AND b.mrecommend = @masterID
							AND b.statusID IN (111,112,113)
					GROUP BY b.winlostdate,MRecommend
				)
				
				INSERT INTO @SAgWinLossDetails
				SELECT
					winlostdate,
					MRecommend,			
					SUM(ABS(b.stake)) as TurnOver,
					SUM(TurnoverNoDraw) AS TurnoverNoDraw,
					SUM(GrossComm) AS GrossComm,
					SUM(winlost-actual_stake), --MemberWinlost
					SUM(playercomm), -- PlayerComm
					ISNULL(SUM(winlost-actual_stake), 0) + ISNULL(SUM(playercomm), 0), --MemberTotal
					SUM(awinlost), -- AgWinlost
					ISNULL(SUM(comm-playercomm),0), --AgComm
					ISNULL(SUM(awinlost+comm-playercomm), 0), --AgTotal			
					SUM(mwinlost), -- MAgWinlost
					SUM(acomm)-SUM(comm), --MAgComm
					ISNULL(SUM(mwinlost), 0) + ISNULL(SUM(acomm), 0)-SUM(comm), --MAgTotal
					SUM(swinlost), -- SAgWinlost
					ISNULL(SUM(scomm),0) -ISNULL(SUM(acomm),0), --SAgComm
					ISNULL(SUM(swinlost), 0) + ISNULL(SUM(scomm), 0)-SUM(acomm), --SAgTotal
					-(ISNULL(SUM(swinlost), 0) + ISNULL(SUM(awinlost), 0) + ISNULL(SUM(mwinlost), 0) + ISNULL(SUM(scomm), 0) + ISNULL(SUM(winlost-actual_stake), 0)) --Company				
				FROM cte_bettrans b
				GROUP BY winlostdate,MRecommend

				-- bettransRnG
				INSERT INTO @GrossComm (winlostdate, CustId, TurnoverNoDraw, GrossComm)
				SELECT
					b.winlostdate
					,b.mrecommend AS CustId
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
				GROUP BY b.winlostdate,b.mrecommend
				
				-- bettransLC
				INSERT INTO @GrossComm (winlostdate, CustId, TurnoverNoDraw, GrossComm)
				SELECT
					b.winlostdate
					,b.mrecommend AS CustId
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
				GROUP BY b.winlostdate, b.mrecommend
				
				IF EXISTS (SELECT 1 FROM @GrossComm)
				BEGIN
					UPDATE t
					SET t.TurnoverNoDraw = ISNULL(t.TurnoverNoDraw, 0) + ISNULL(c.TurnoverNoDraw, 0)
						,t.GrossComm = ISNULL(t.GrossComm, 0) + ISNULL(c.GrossComm, 0)
					FROM @SAgWinLossDetails t
						INNER JOIN (
							SELECT winlostdate, CustId, SUM(GrossComm) AS GrossComm, SUM(TurnoverNoDraw) AS TurnoverNoDraw FROM @GrossComm GROUP BY winlostdate, CustId
						) c ON t.CustId = c.CustId AND t.winlostdate = c.winlostdate
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
					b.winlostdate,
					CustID,			
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
				FROM
					bodb02.dbo.sum_winloss b WITH (NOLOCK) INNER JOIN @TmpCondSumWL t ON b.sporttype = t.sporttype AND b.bettype = t.bettype AND ISNULL(b.leagueGroupID,0) = t.LeagueGroupID AND ISNULL(b.ticketType,0) = t.TicketType
				WHERE
					winlostdate between @FDate and @TDate			
					AND SRecommend = @custid
					AND RoleID = 3
				GROUP BY b.winlostdate,CustID
			
			END
			ELSE
			BEGIN
				INSERT INTO @SAgWinLossDetails
				SELECT
					winlostdate,
					CustID,			
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
				FROM
					bodb02.dbo.sum_winloss b WITH (NOLOCK) INNER JOIN @TmpCondSumWL t ON b.sporttype = t.sporttype AND b.bettype = t.bettype AND ISNULL(b.leagueGroupID,0) = t.LeagueGroupID AND ISNULL(b.ticketType,0) = t.TicketType
				WHERE
					winlostdate between @FDate and @TDate			
					AND b.mrecommend = @masterID
					AND RoleID = 3
				GROUP BY b.winlostdate, CustID
			END
		END
		
	END

	IF @FromDate < @BalanceUpDay 
	BEGIN
		SELECT @FDate = @FromDate

		IF @ToDate >= DATEADD(dd, -1, @BalanceUpDay)
			SELECT @TDate = DATEADD(dd, -1, @BalanceUpDay)
			
		SELECT b.winlostdate, custid,  mrecommend, turnover,TunroverNoDraw as  TurnoverNoDraw, winlost, awinlost, mwinlost, swinlost, playercomm, comm, acomm, scomm, grosscomm, sporttype, bettype , ISNULL(leagueGroupID,0) leagueGroupID, ISNULL(ticketType,0) ticketType
			INTO #Sum_WinLoss_Old
		FROM bodb_Summary.dbo.Sum_WinLoss_Old b WITH(NOLOCK)
		WHERE winlostdate BETWEEN @FDate AND @TDate			
				--and SRecommend IN (SELECT custID FROM @tmpSuperList)
				and SRecommend = @custid
				AND RoleID = 3 
				and (@masterID is null or b.mrecommend = @masterID)
				
		INSERT INTO @SAgWinLossDetails
			SELECT
				b.winlostdate,
				CustID,			
				SUM(ABS(TurnOver)) as TurnOver,
				SUM(ABS(TurnoverNoDraw)) as TurnoverNoDraw,
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
			FROM
				#Sum_WinLoss_Old b WITH(NOLOCK) INNER JOIN @TmpCondSumWL t ON b.sporttype = t.sporttype AND b.bettype = t.bettype AND b.leagueGroupID = t.LeagueGroupID AND b.ticketType = t.TicketType
			GROUP BY b.winlostdate,CustID
	END	

		-- RESULT --
		CREATE TABLE #tmp_result(
			CustID INT
			, UserName NVARCHAR(50)
			, CurrencyID INT
			, CurrencyName NVARCHAR(50)
			, Turnover DECIMAL(19,8)
			, TurnoverNoDraw DECIMAL(19,8)
			, GrossComm DECIMAL(19,8)
			, MemberWinLost DECIMAL(19,8)
			, PlayerComm DECIMAL(19,8)
			, MemberTotal DECIMAL(19,8)
			, AgWinLost DECIMAL(19,8)
			, AgComm DECIMAL(19,8)
			, AgTotal DECIMAL(19,8)
			, MAgWinLost DECIMAL(19,8)
			, MAgComm DECIMAL(19,8)
			, MAgTotal DECIMAL(19,8)
			, SAgWinLost DECIMAL(19,8)
			, SAgComm DECIMAL(19,8)
			, SAgTotal DECIMAL(19,8)
			, Company DECIMAL(19,8)
		)
	    INSERT INTO #tmp_result(
			CustID 
			, UserName 
			, CurrencyID 
			, CurrencyName
			, Turnover 
			, TurnoverNoDraw 
			, GrossComm 
			, MemberWinLost 
			, PlayerComm 
			, MemberTotal 
			, AgWinLost 
			, AgComm 
			, AgTotal 
			, MAgWinLost 
			, MAgComm 
			, MAgTotal 
			, SAgWinLost 
			, SAgComm 
			, SAgTotal 
			, Company 
		)
		SELECT
			w.CustID, 
			c.UserName,
			c.currency,
			o.CurrencyName,
			SUM(TurnOver * o.Rate) as TurnOver,
			SUM(TurnoverNoDraw * o.Rate) as TurnoverNoDraw,
			SUM(GrossComm * o.Rate) as GrossComm,
			SUM(MemberWinLost * o.Rate) as MemberWinlost,
			SUM(PlayerComm * o.Rate) as PlayerComm,
			SUM(MemberTotal * o.Rate) as MemberTotal,
			SUM(AgWinlost * o.Rate) as AgWinlost,
			SUM(AgComm * o.Rate) as AgComm,
			SUM(AgTotal * o.Rate) as AgTotal,
			SUM(MAgWinlost * o.Rate) as MAgWinlost,
			SUM(MAgComm * o.Rate) as MAgComm,
			SUM(MAgTotal * o.Rate) as MAgTotal,
			SUM(SAgWinlost * o.Rate) as SAgWinlost,
			SUM(SAgComm * o.Rate) as SAgComm,
			SUM(SAgTotal * o.Rate) as SAgTotal,
			SUM(Company * o.Rate) as Company	
		FROM @SAgWinLossDetails w 
		INNER JOIN bodb02.dbo.custinfo c WITH(NOLOCK) 
			ON w.CustID = c.CustID 
		INNER JOIN #tmp_Oanda o 
			ON c.currency = o.CurrencyId
			AND w.winlostdate = o.ExchangeDate
		GROUP BY w.winlostdate,w.CustID, c.UserName,c.currency,o.CurrencyName
		ORDER BY c.Username
	
	--Grid--
		SELECT CustID 
				, UserName 
				, CurrencyID 
				, CurrencyName
				, SUM(Turnover) Turnover
				, SUM(TurnoverNoDraw) TurnoverNoDraw
				, SUM(GrossComm) GrossComm
				, SUM(MemberWinLost) MemberWinLost
				, SUM(PlayerComm) PlayerComm
				, SUM(MemberTotal) MemberTotal
				, SUM(AgWinLost) AgWinLost
				, SUM(AgComm) AgComm
				, SUM(AgTotal) AgTotal
				, SUM(MAgWinLost) MAgWinLost
				, SUM(MAgComm) MAgComm
				, SUM(MAgTotal) MAgTotal
				, SUM(SAgWinLost) SAgWinLost
				, SUM(SAgComm) SAgComm
				, SUM(SAgTotal) SAgTotal
				, SUM(Company) Company
		FROM #tmp_result
		GROUP BY CustID 
				, UserName 
				, CurrencyID 
				, CurrencyName

	-- Total --
			IF @BaseCurrency = 0
			BEGIN
				SELECT 
					'Total ' + CurrencyName AS Total
					, SUM(Turnover) Turnover
					, SUM(TurnoverNoDraw) TurnoverNoDraw
					, SUM(GrossComm) GrossComm
					, SUM(MemberWinLost) MemberWinLost
					, SUM(PlayerComm) PlayerComm
					, SUM(MemberTotal) MemberTotal
					, SUM(AgWinLost) AgWinLost
					, SUM(AgComm) AgComm
					, SUM(AgTotal) AgTotal
					, SUM(MAgWinLost) MAgWinLost
					, SUM(MAgComm) MAgComm
					, SUM(MAgTotal) MAgTotal
					, SUM(SAgWinLost) SAgWinLost
					, SUM(SAgComm) SAgComm
					, SUM(SAgTotal) SAgTotal
					, SUM(Company) Company
				FROM #tmp_result
				GROUP BY CurrencyName
			END
			ELSE
			BEGIN
				SELECT 
					'Grand Total in ' + CASE WHEN @BaseCurrency = 1 THEN 'MYR'
											 WHEN @BaseCurrency = 2 THEN 'CNY'
											 WHEN @BaseCurrency = 3 THEN 'THB'
											 WHEN @BaseCurrency = 4 THEN 'IDR'
											END AS Total
					, SUM(Turnover) Turnover
					, SUM(TurnoverNoDraw) TurnoverNoDraw
					, SUM(GrossComm) GrossComm
					, SUM(MemberWinLost) MemberWinLost
					, SUM(PlayerComm) PlayerComm
					, SUM(MemberTotal) MemberTotal
					, SUM(AgWinLost) AgWinLost
					, SUM(AgComm) AgComm
					, SUM(AgTotal) AgTotal
					, SUM(MAgWinLost) MAgWinLost
					, SUM(MAgComm) MAgComm
					, SUM(MAgTotal) MAgTotal
					, SUM(SAgWinLost) SAgWinLost
					, SUM(SAgComm) SAgComm
					, SUM(SAgTotal) SAgTotal
					, SUM(Company) Company
				FROM #tmp_result
			END

	DROP TABLE #tmp_Oanda
	DROP TABLE #tmp_result
END	
GO
/*<info serverAlias="DBAGE-bodb02" executers="wsv_xnap" isFunction="0" isNested="0"></info>*/
CREATE PROCEDURE [dbo].[EAS_Rpt_WinLossDetailByCurrency_MAg]
	@custid			INT,--mrecommend
	@Agentid		INT = NULL,
	@FromDate		SMALLDATETIME,
	@ToDate			SMALLDATETIME,
	@ProductIds		VARCHAR(MAX) = '',
	@ProductDetails NVARCHAR(MAX) = 'All',
	@MoveBetsDay	SMALLDATETIME,
	@BalanceUpDay	SMALLDATETIME,
	@BaseCurrency	VARCHAR(5) = 'MYR', --MYR
	@GroupName		VARCHAR(50)
AS
/*
	Created by: Lewis
	Date: 2023-12-05
	Task : Agent Winloss Detail By Currency
	DB: DBAGE/bodb02
	Original: [EAS_Rpt_WinLossDetailByCurrency_MAg]
	Revisions:
		- 20231205@Lewis: Initialize SP [RedmineID: #196959]
		- 20240116@Lewis: Sort by Username [RedmineID: #196959]
		- 20240306@Lewis: Add Virtual Ice Hockey [RedmineID: #201129]
		- 20240515@Lewis: Add SABA Kabaddi [RedmineID: #203763]
	    - 20240918@Lewis: Rebate Retention - Reward [RedmineId: #208503]
		- 20241113@Lewis: Enhance:											[RedmineID: #203763]
								+ Source data: bettrans - bettrans_compact
								+ New Currency ExchangeRate
								+ Decimal(24,4)
	
	Param's Explanation:
		@BaseCurrency:  NULL - unchecked
						 MYR
						 CNY
						 THB
						 IDR


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
	FROM dbo.EAS_f_GetDailyExchangeRate(@FromDate,@ToDate,@GroupName,@BaseCurrency) 
	OPTION (MAXRECURSION 0);

	 
	-----------------------------------------
	DECLARE @FDate SMALLDATETIME, @TDate SMALLDATETIME, @__ProductDetails XML;

	SELECT @FDate = @FromDate, @TDate = @ToDate

	DECLARE @ExistingProductDetails TABLE (ProductId INT,Sporttype INT,Bettype INT, LeagueGroupID SMALLINT, TicketType TINYINT)

	DECLARE @MAgWinLossDetails TABLE(
		winlostdate SMALLDATETIME,
		CustID INT, TurnOver MONEY, TurnoverNoDraw MONEY, GrossComm MONEY, MemberWinLost MONEY, 
		PlayerComm MONEY, MemberTotal MONEY, AgWinLost MONEY, AgComm MONEY, AgTotal MONEY, 
		MAgWinLost MONEY, MAgComm MONEY, MAgTotal MONEY, Company MONEY
		, RewardAmount MONEY
		)

	DECLARE @GrossComm TABLE (winlostdate SMALLDATETIME,CustId INT, TurnoverNoDraw MONEY, GrossComm MONEY)

	SELECT @ProductIds = bodb02.dbo.f_AddRelatedProducts(@ProductIds)
	SELECT @__ProductDetails = CONVERT(XML, @ProductDetails)

	INSERT INTO @ExistingProductDetails(ProductId,Sporttype,Bettype,LeagueGroupID,TicketType)
	SELECT ProductId,Sporttype,Bettype,LeagueGroupID,TicketType
	FROM dbo.f_ProductDetail_ConditionSel(@ProductDetails, @__ProductDetails)

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
				; WITH cte_Agent AS (
					SELECT custid
					FROM dbo.Customer WITH (NOLOCK)
					WHERE mrecommend = @custid
						AND roleid = 2
				)
				INSERT @MAgWinLossDetails (	winlostdate,
											CustID , TurnOver , TurnoverNoDraw , GrossComm , MemberWinLost , 
											PlayerComm , MemberTotal , AgWinLost , AgComm , AgTotal , 
											MAgWinLost , MAgComm , MAgTotal , Company )
				SELECT
					b.winlostdate
					,b.custid
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
					,-(ISNULL(SUM(awinlost), 0) + ISNULL(SUM(mwinlost), 0) + ISNULL(SUM(acomm), 0) + ISNULL(SUM(winlost), 0)) --Company
				FROM bodb_AGE.dbo.bettrans_compact b WITH(NOLOCK)
					INNER JOIN cte_Agent c ON c.custid = b.custid
					INNER JOIN #tmpSportBettype s ON b.bettype = s.bettype 
						AND (s.ProductID <> 1 OR (s.ProductID = 1 AND b.sporttype = s.SportType AND b.LeagueGroupID = s.LeagueGroupID AND b.TicketType = s.TicketType))
				WHERE b.winlostdate between @FDate and @TDate 
				GROUP BY b.winlostdate,b.custid

				-- bettransRnG
				INSERT INTO @GrossComm (winlostdate, CustId, TurnoverNoDraw, GrossComm)
				SELECT 
					b.winlostdate
					,b.recommend AS CustId
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
				GROUP BY b.winlostdate,b.recommend
			
				-- bettransLC
				INSERT INTO @GrossComm (winlostdate, CustId, TurnoverNoDraw, GrossComm)
				SELECT
					b.winlostdate
					,b.recommend AS CustId
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
				GROUP BY b.winlostdate,b.recommend

				IF EXISTS (SELECT 1 FROM @GrossComm)
				BEGIN
					UPDATE t
					SET t.TurnoverNoDraw = ISNULL(t.TurnoverNoDraw, 0) + ISNULL(c.TurnoverNoDraw, 0)
						,t.GrossComm = ISNULL(t.GrossComm, 0) + ISNULL(c.GrossComm, 0)
					FROM @MAgWinLossDetails t
						INNER JOIN (
							SELECT winlostdate,CustId, SUM(GrossComm) AS GrossComm, SUM(TurnoverNoDraw) AS TurnoverNoDraw FROM @GrossComm GROUP BY winlostdate,CustId
						) c ON t.CustId = c.CustId AND t.winlostdate = c.winlostdate
				END
			END
			ELSE
			BEGIN
				INSERT @MAgWinLossDetails (winlostdate,
											CustID , TurnOver , TurnoverNoDraw , GrossComm , MemberWinLost , 
											PlayerComm , MemberTotal , AgWinLost , AgComm , AgTotal , 
											MAgWinLost , MAgComm , MAgTotal , Company )
				SELECT 
					b.winlostdate
					,b.custid
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
					,-(ISNULL(SUM(awinlost), 0) + ISNULL(SUM(mwinlost), 0) + ISNULL(SUM(acomm), 0) + ISNULL(SUM(winlost), 0)) --Company
				FROM bodb_AGE.dbo.bettrans_compact b WITH(NOLOCK)
					INNER JOIN #tmpSportBettype s ON b.bettype = s.bettype 
						AND (s.ProductID <> 1 OR (s.ProductID = 1 AND b.sporttype = s.SportType AND b.LeagueGroupID = s.LeagueGroupID AND b.TicketType = s.TicketType))
				WHERE b.winlostdate between @FDate and @TDate 
					AND b.custid = @Agentid
				GROUP BY b.winlostdate,b.custid

				-- bettransRnG
				INSERT INTO @GrossComm (winlostdate, CustId, TurnoverNoDraw, GrossComm)
				SELECT 
					b.winlostdate
					,b.recommend AS CustId
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
				GROUP BY b.winlostdate,b.recommend
			
				-- bettransLC
				INSERT INTO @GrossComm (winlostdate, CustId, TurnoverNoDraw, GrossComm)
				SELECT 
					b.winlostdate
					,b.recommend AS CustId
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
				GROUP BY b.winlostdate,b.recommend

				IF EXISTS (SELECT 1 FROM @GrossComm)
				BEGIN
					UPDATE t
					SET t.TurnoverNoDraw = ISNULL(t.TurnoverNoDraw, 0) + ISNULL(c.TurnoverNoDraw, 0)
						,t.GrossComm = ISNULL(t.GrossComm, 0) + ISNULL(c.GrossComm, 0)
					FROM @MAgWinLossDetails t
						INNER JOIN (
							SELECT winlostdate, CustId, SUM(GrossComm) AS GrossComm, SUM(TurnoverNoDraw) AS TurnoverNoDraw FROM @GrossComm GROUP BY winlostdate,CustId
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

			IF @Agentid IS NULL
			BEGIN
				INSERT INTO @MAgWinLossDetails (winlostdate,
											CustID , TurnOver , TurnoverNoDraw , GrossComm , MemberWinLost , 
											PlayerComm , MemberTotal , AgWinLost , AgComm , AgTotal , 
											MAgWinLost , MAgComm , MAgTotal , Company )
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
					ISNULL(SUM(comm-playercomm), 0), --AgComm
					ISNULL(SUM(awinlost), 0) + ISNULL(SUM(comm-playercomm), 0), --AgTotal
					SUM(mwinlost), -- MAgWinlost
					SUM(acomm)-SUM(comm), --MAgComm
					ISNULL(SUM(mwinlost), 0) + ISNULL(SUM(acomm), 0)-SUM(comm), --MAgTotal
					-(ISNULL(SUM(awinlost), 0) + ISNULL(SUM(mwinlost), 0) + ISNULL(SUM(acomm), 0) + ISNULL(SUM(winlost), 0))--Company				
				FROM
					bodb02.dbo.sum_winloss b WITH (NOLOCK) INNER JOIN @TmpCondSumWL t ON b.sporttype = t.sporttype AND b.bettype = t.bettype AND ISNULL(b.leagueGroupID,0) = t.LeagueGroupID AND ISNULL(b.ticketType,0) = t.TicketType
				WHERE winlostdate between @FDate and @TDate			
						AND MRecommend=@custid 
						AND RoleID=2
				GROUP BY b.winlostdate,CustID		
			END
			ELSE
			BEGIN
				INSERT INTO @MAgWinLossDetails (winlostdate,
											CustID , TurnOver , TurnoverNoDraw , GrossComm , MemberWinLost , 
											PlayerComm , MemberTotal , AgWinLost , AgComm , AgTotal , 
											MAgWinLost , MAgComm , MAgTotal , Company )
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
					ISNULL(SUM(comm-playercomm), 0), --AgComm
					ISNULL(SUM(awinlost), 0) + ISNULL(SUM(comm-playercomm), 0), --AgTotal
					SUM(mwinlost), -- MAgWinlost
					SUM(acomm)-SUM(comm), --MAgComm
					ISNULL(SUM(mwinlost), 0) + ISNULL(SUM(acomm), 0)-SUM(comm), --MAgTotal
					-(ISNULL(SUM(awinlost), 0) + ISNULL(SUM(mwinlost), 0) + ISNULL(SUM(acomm), 0) + ISNULL(SUM(winlost), 0))--Company				
				FROM
					bodb02.dbo.sum_winloss b WITH (NOLOCK) INNER JOIN @TmpCondSumWL t ON b.sporttype = t.sporttype AND b.bettype = t.bettype AND ISNULL(b.leagueGroupID,0) = t.LeagueGroupID AND ISNULL(b.ticketType,0) = t.TicketType
				WHERE winlostdate between @FDate and @TDate			
					AND b.recommend = @Agentid
					AND RoleID=2
				GROUP BY b.winlostdate,CustID
			END
		END
		
		
	END

	IF @FromDate < @BalanceUpDay 
	BEGIN
		SELECT @FDate = @FromDate

		IF @ToDate >= DATEADD(dd, -1, @BalanceUpDay)
			SELECT @TDate = DATEADD(dd, -1, @BalanceUpDay)
		
		INSERT INTO @MAgWinLossDetails (winlostdate,
											CustID , TurnOver , TurnoverNoDraw , GrossComm , MemberWinLost , 
											PlayerComm , MemberTotal , AgWinLost , AgComm , AgTotal , 
											MAgWinLost , MAgComm , MAgTotal , Company )
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
			ISNULL(SUM(comm-playercomm), 0), --AgComm
			ISNULL(SUM(awinlost), 0) + ISNULL(SUM(comm-playercomm), 0), --AgTotal
			SUM(mwinlost), -- MAgWinlost
			SUM(acomm)-SUM(comm), --MAgComm
			ISNULL(SUM(mwinlost), 0) + ISNULL(SUM(acomm), 0)-SUM(comm), --MAgTotal
			-(ISNULL(SUM(awinlost), 0) + ISNULL(SUM(mwinlost), 0) + ISNULL(SUM(acomm), 0) + ISNULL(SUM(winlost), 0))--Company				
		FROM
			bodb_Summary.dbo.Sum_WinLoss_Old b WITH(NOLOCK) INNER JOIN @TmpCondSumWL t ON b.sporttype = t.sporttype AND b.bettype = t.bettype AND ISNULL(b.leagueGroupID,0) = t.LeagueGroupID AND ISNULL(b.ticketType,0) = t.TicketType
		WHERE
			winlostdate between @FDate and @TDate			
			and MRecommend=@custid
			AND (@Agentid is null or b.recommend = @Agentid)
			and RoleID=2
		GROUP BY b.winlostdate,CustID

	END	

	--TODO: SabaWalletTicket
	SELECT @FDate = @FromDate, @TDate = @ToDate

	INSERT INTO @MAgWinLossDetails (winlostdate, CustID, RewardAmount)
	SELECT b.WinlostDate,b.Recommend,SUM(b.Amount)
	FROM SabaWalletTicket b WITH (NOLOCK)
	WHERE b.WinlostDate BETWEEN @FDate AND @TDate
		AND b.WalletID = 2
		AND b.Mrecommend = @custid
		AND (@Agentid IS NULL OR b.Recommend = @Agentid)
	GROUP BY b.WinlostDate,b.Recommend
	---------------------

		-- RESULT
		CREATE TABLE #tmp_result(
			CustID INT
			, UserName NVARCHAR(50)
			, CurrencyID INT
			, CurrencyName NVARCHAR(50)
			, Turnover DECIMAL(24,4)
			, TurnoverNoDraw DECIMAL(24,4)
			, GrossComm DECIMAL(24,4)
			, MemberWinLost DECIMAL(24,4)
			, PlayerComm DECIMAL(24,4)
			, MemberTotal DECIMAL(24,4)
			, AgWinLost DECIMAL(24,4)
			, AgComm DECIMAL(24,4)
			, AgTotal DECIMAL(24,4)
			, MAgWinLost DECIMAL(24,4)
			, MAgComm DECIMAL(24,4)
			, MAgTotal DECIMAL(24,4)
			, Company DECIMAL(24,4)
			, RewardAmount DECIMAL (19,8)
			, RewardCurrency VARCHAR(12)
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
			, Company 
			, RewardAmount
			, RewardCurrency
		)
		SELECT
			w.CustID, 
			c.UserName,
			c.currency AS CurrencyID,
			o.CurrencyName AS CurrencyName,
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
			SUM(Company * o.Rate) as Company,
			SUM(w.RewardAmount * o.Rate) AS RewardAmount,
			o.Code AS RewardCurrency
		FROM @MAgWinLossDetails w 
		INNER JOIN bodb02.dbo.Customer c WITH(NOLOCK) 
			ON w.CustID = c.CustID 
		INNER JOIN #tmp_Oanda o 
			ON c.currency = o.CurrencyId
			AND w.winlostdate = o.ExchangeDate
		GROUP BY w.CustID, c.UserName,c.currency,o.CurrencyName
		
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
				, SUM(Company) Company
				, SUM(RewardAmount) RewardAmount
				, RewardCurrency
		FROM #tmp_result
		GROUP BY CustID 
				, UserName 
				, CurrencyID 
				, CurrencyName
				, RewardCurrency
		ORDER BY Username

	-- Total --
			IF ISNULL(@BaseCurrency,'') = ''
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
					, SUM(Company) Company
					, SUM(RewardAmount) RewardAmount
					, RewardCurrency
				FROM #tmp_result
				GROUP BY CurrencyName, RewardCurrency
			END
			ELSE
			BEGIN
				SELECT 
					'Grand Total in ' + @BaseCurrency AS Total
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
					, SUM(Company) Company
					, SUM(RewardAmount) RewardAmount
					, '' AS RewardCurrency
				FROM #tmp_result
			END

	DROP TABLE #tmp_Oanda
	DROP TABLE #tmp_result
END	
GO
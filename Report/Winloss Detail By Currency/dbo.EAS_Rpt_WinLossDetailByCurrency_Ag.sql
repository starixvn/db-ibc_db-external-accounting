/*<info serverAlias="DBAGE-bodb02" executers="wsv_xnap" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[EAS_Rpt_WinLossDetailByCurrency_Ag]
	@CustID			INT,--recommend
	@memberID		INT = NULL,
	@FromDate		SMALLDATETIME,
	@ToDate			SMALLDATETIME,
	@ProductIds		VARCHAR(MAX) = '',
	@ProductDetails NVARCHAR(MAX) = 'All',
	@MoveBetsDay	SMALLDATETIME,
	@BalanceUpDay	SMALLDATETIME,
	@BaseCurrency	VARCHAR(5) = 'MYR',
	@GroupName		VARCHAR(50)
AS
/*
	Created by: Lewis
	Date: 2023-12-05
	Task : Member Winloss Detail By Currency
	DB: DBAGE/bodb02
	Original: [EAS_Rpt_WinLossDetail_Ag]
	Revisions:
		- 20231205@Lewis: Initialize SP [RedmineID: #196959]
		- 20240116@Lewis: Sort by Username [RedmineID: #196959]
		- 20240306@Lewis: Add Virtual Ice Hockey [RedmineID: #201129]
		- 20240515@Lewis: Add SABA Kabaddi [RedmineID: #203763]
	    - 20240918@Lewis: Rebate Retention - Reward [RedmineId: #208503]
		- 20241216@Bobby: Enhance MBU & Base Currency [RedmineID: #213507]
	
	Param's Explanation:
		@BaseCurrency:  NULL unchecked
						 MYR
						 CNY
						 THB
						 IDR


*/
BEGIN
	SET NOCOUNT ON;

	DECLARE @srecommend INT,
		@mrecommend INT

	-- Exchange Rate Oanda
	DROP TABLE IF EXISTS #tmp_Oanda;
	CREATE TABLE #tmp_Oanda(
		ExchangeDate SMALLDATETIME
		,CurrencyId INT
		,CurrencyName NVARCHAR(50)
		,Code VARCHAR(12)
		,Rate FLOAT
		,PRIMARY KEY (CurrencyId, ExchangeDate)
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
	FROM dbo.EAS_f_GetDailyExchangeRate(@FromDate,@ToDate,@GroupName,@BaseCurrency);

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


	DECLARE @FDate SMALLDATETIME, @TDate SMALLDATETIME,@__ProductDetails XML;

	SELECT @FDate = @FromDate, @TDate = @ToDate

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

	DECLARE @GrossComm TABLE (CustId INT, TurnoverNoDraw DECIMAL(24,4), GrossComm DECIMAL(24,4))

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


	--TODO: bettrans_compact
	SELECT @FDate = FromDate, @TDate = ToDate
	FROM (VALUES(@FromDate)) AS t (CheckDate)
	OUTER APPLY (
		SELECT * FROM dbo.f_MBU_RangeDate(CheckDate, @ToDate, @BalanceUpDay, @MoveBetsDay)
		WHERE RangeType = 1
	) AS fc

	IF @FDate IS NOT NULL
	BEGIN
		INSERT INTO @AgWinLossDetails(CustID, TurnOver, TurnoverNoDraw, GrossComm, MemberWinLost, 
									PlayerComm, MemberTotal, AgWinLost, AgComm, AgTotal, Company)
		SELECT
			b.CustID,
			SUM(ABS(b.turnover)*ex.Rate) as TurnOver,
			SUM(TurnoverNoDraw*ex.Rate) AS TurnoverNoDraw,
			SUM(GrossComm*ex.Rate) AS GrossComm,
			SUM(winlost*ex.Rate), --MemberWinlost
			SUM(playercomm*ex.Rate), -- PlayerComm
			ISNULL(SUM(winlost*ex.Rate), 0) + ISNULL(SUM(playercomm*ex.Rate), 0), --MemberTotal
			SUM(awinlost*ex.Rate), -- AgWinlost
			SUM((comm-playercomm)*ex.Rate), --AgComm
			ISNULL(SUM(awinlost*ex.Rate), 0) + ISNULL(SUM((comm-playercomm)*ex.Rate), 0), --AgTotal
			-ISNULL(SUM((winlost+awinlost+comm)*ex.Rate), 0) --Company
		FROM bodb_AGE.dbo.bettrans_compact b WITH(NOLOCK)
			INNER JOIN #downlineList dl ON dl.custid = b.custid
			INNER JOIN #tmp_Oanda ex ON ex.ExchangeDate = b.winlostdate AND ex.CurrencyId = dl.CurrencyId
			INNER JOIN #tmpSportBettype s ON b.bettype = s.bettype 
					AND (s.ProductID <> 1 OR (s.ProductID = 1 AND b.sporttype = s.SportType AND b.LeagueGroupID = s.LeagueGroupID AND b.TicketType = s.TicketType))
		WHERE b.winlostdate between @FDate and @TDate
		GROUP BY b.CustID

		-- bettransRnG
		INSERT INTO @GrossComm (CustId, TurnoverNoDraw, GrossComm)
		SELECT 
			dl.CustId
			,SUM(CASE WHEN cont.ContributionBettype IS NULL THEN b.BetStake ELSE 0 END*ex.Rate) AS TurnoverNoDraw
			,SUM(b.BetStake * b.discount*ex.Rate) AS GrossComm
		FROM dbo.bettransRnG b WITH(NOLOCK)
			INNER JOIN #downlineList dl ON dl.custid = b.custid
			INNER JOIN #tmp_Oanda ex ON ex.CurrencyId = dl.CurrencyId AND ex.ExchangeDate = b.winlostdate
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
		GROUP BY dl.CustId
				
		-- bettransLC
		INSERT INTO @GrossComm (CustId, TurnoverNoDraw, GrossComm)
		SELECT 
			dl.CustId
			,SUM(CASE WHEN cont.ContributionBettype IS NULL THEN b.NetStake ELSE 0 END*ex.Rate) AS TurnoverNoDraw
			,SUM(b.NetStake * b.discount*ex.Rate) AS GrossComm
		FROM dbo.bettransLC b WITH(NOLOCK)
			INNER JOIN #downlineList dl ON dl.custid = b.custid
			INNER JOIN #tmp_Oanda ex ON ex.CurrencyId = dl.CurrencyId AND ex.ExchangeDate = b.winlostdate
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
		GROUP BY dl.CustId

		IF EXISTS (SELECT 1 FROM @GrossComm)
		BEGIN
			UPDATE t
			SET t.TurnoverNoDraw = ISNULL(t.TurnoverNoDraw, 0) + ISNULL(c.TurnoverNoDraw, 0)
				,t.GrossComm = ISNULL(t.GrossComm, 0) + ISNULL(c.GrossComm, 0)
			FROM @AgWinLossDetails t
				INNER JOIN (
					SELECT CustId, SUM(GrossComm) AS GrossComm, SUM(TurnoverNoDraw) AS TurnoverNoDraw 
					FROM @GrossComm 
					GROUP BY CustId
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
		INSERT INTO @AgWinLossDetails(
									CustID, TurnOver, TurnoverNoDraw, GrossComm, MemberWinLost, 
									PlayerComm, MemberTotal, AgWinLost, AgComm, AgTotal, Company)
		SELECT
			dl.CustID,			
			SUM(ABS(TurnOver)*ex.Rate) as TurnOver,
			SUM(ABS(TunroverNoDraw)*ex.Rate) as TurnoverNoDraw,
			SUM(grosscomm*ex.Rate) as GrossComm,
			SUM(winlost*ex.Rate), --MemberWinlost
			SUM(playercomm*ex.Rate), -- PlayerComm
			ISNULL(SUM(winlost*ex.Rate), 0) + ISNULL(SUM(playercomm), 0), --MemberTotal
			SUM(awinlost*ex.Rate), -- AgWinlost
			SUM((comm-playercomm)*ex.Rate), --AgComm
			ISNULL(SUM(awinlost*ex.Rate), 0) + ISNULL(SUM((comm-playercomm)*ex.Rate), 0), --AgTotal
			-ISNULL(SUM((winlost+awinlost+comm)*ex.Rate), 0) --Company
		FROM
			bodb02.dbo.sum_winloss b WITH (NOLOCK) 
			INNER JOIN #downlineList dl ON dl.custid = b.custid
			INNER JOIN #tmp_Oanda ex ON ex.CurrencyId = dl.CurrencyId AND ex.ExchangeDate = b.winlostdate
			INNER JOIN @TmpCondSumWL t ON b.sporttype = t.sporttype AND b.bettype = t.bettype AND ISNULL(b.leagueGroupID,0) = t.LeagueGroupID AND ISNULL(b.ticketType,0) = t.TicketType
		WHERE
			b.winlostdate BETWEEN @FDate and @TDate	
			AND b.srecommend=@srecommend
			AND b.mrecommend=@mrecommend
			AND b.recommend=@CustID
			AND b.RoleID=1
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
		INSERT INTO @AgWinLossDetails(
										CustID, TurnOver, TurnoverNoDraw, GrossComm, MemberWinLost, 
										PlayerComm, MemberTotal, AgWinLost, AgComm, AgTotal, Company
									)
			SELECT
				dl.CustID,			
				SUM(ABS(TurnOver)*ex.Rate) as TurnOver,
				SUM(ABS(TunroverNoDraw)*ex.Rate) as TurnoverNoDraw,
				SUM(grosscomm*ex.Rate) as GrossComm,
				SUM(winlost*ex.Rate), --MemberWinlost
				SUM(playercomm*ex.Rate), -- PlayerComm
				ISNULL(SUM(winlost*ex.Rate), 0) + ISNULL(SUM(playercomm*ex.Rate), 0), --MemberTotal
				SUM(awinlost*ex.Rate), -- AgWinlost
				SUM((comm-playercomm)*ex.Rate), --AgComm
				ISNULL(SUM(awinlost*ex.Rate), 0) + ISNULL(SUM((comm-playercomm)*ex.Rate), 0), --AgTotal
				-ISNULL(SUM((winlost+awinlost+comm)*ex.Rate), 0) --Company
			FROM
				bodb_Summary.dbo.Sum_WinLoss_Old b WITH(NOLOCK) 
				INNER JOIN #downlineList dl ON dl.custid = b.custid
				INNER JOIN #tmp_Oanda ex ON ex.CurrencyId = dl.CurrencyId AND ex.ExchangeDate = b.winlostdate
				INNER JOIN @TmpCondSumWL t ON b.sporttype = t.sporttype AND b.bettype = t.bettype AND ISNULL(b.leagueGroupID,0) = t.LeagueGroupID AND ISNULL(b.ticketType,0) = t.TicketType
			WHERE
				b.winlostdate between @FDate and @TDate	
				AND b.srecommend=@srecommend
				AND b.mrecommend=@mrecommend
				AND b.recommend=@CustID
				and b.RoleID=1
			GROUP BY dl.CustID
	END
		
	--TODO: SabaWalletTicket.
	SELECT @FDate = @FromDate, @TDate = @ToDate

	INSERT INTO @AgWinLossDetails(CustID, RewardAmount)
	SELECT dl.CustID, SUM(b.Amount*ex.Rate)
	FROM dbo.SabaWalletTicket b WITH (NOLOCK)
	INNER JOIN #downlineList dl ON dl.custid = b.custid
	INNER JOIN #tmp_Oanda ex ON ex.CurrencyId = dl.CurrencyId AND ex.ExchangeDate = b.winlostdate
	WHERE b.WinlostDate BETWEEN @FDate AND @TDate
		AND b.WalletID = 2
		
	GROUP BY dl.CustID
	-----------------------------		
		
	--Grid--
	SELECT dl.CustID 
			, dl.UserName 
			, dl.CurrencyID 
			, dl.CurrencyName
			, SUM(Turnover) Turnover
			, SUM(TurnoverNoDraw) TurnoverNoDraw
			, SUM(GrossComm) GrossComm
			, SUM(MemberWinLost) MemberWinLost
			, SUM(PlayerComm) PlayerComm
			, SUM(MemberTotal) MemberTotal
			, SUM(AgWinLost) AgWinLost
			, SUM(AgComm) AgComm
			, SUM(AgTotal) AgTotal
			, SUM(Company) Company
			, SUM(RewardAmount) RewardAmount
			, dl.CurrencyCode AS RewardCurrency
	FROM @AgWinLossDetails b
	INNER JOIN #downlineList dl ON dl.custid = b.CustID
	GROUP BY dl.CustID 
			, dl.UserName 
			, dl.CurrencyID 
			, dl.CurrencyName
			, dl.CurrencyCode
	ORDER BY dl.Username

	-- Total --
	IF @BaseCurrency = ''
	BEGIN
		SELECT 
			CONCAT('Total ', dl.CurrencyName) AS Total
			, SUM(Turnover) Turnover
			, SUM(TurnoverNoDraw) TurnoverNoDraw
			, SUM(GrossComm) GrossComm
			, SUM(MemberWinLost) MemberWinLost
			, SUM(PlayerComm) PlayerComm
			, SUM(MemberTotal) MemberTotal
			, SUM(AgWinLost) AgWinLost
			, SUM(AgComm) AgComm
			, SUM(AgTotal) AgTotal
			, SUM(Company) Company
			, SUM(RewardAmount) RewardAmount
			, dl.CurrencyCode AS RewardCurrency
		FROM @AgWinLossDetails b
		INNER JOIN #downlineList dl ON dl.custid = b.CustID
		GROUP BY dl.CurrencyName, dl.CurrencyCode
	END
	ELSE
	BEGIN
		SELECT 
			CONCAT('Grand Total in ', @BaseCurrency) AS Total
			, SUM(Turnover) Turnover
			, SUM(TurnoverNoDraw) TurnoverNoDraw
			, SUM(GrossComm) GrossComm
			, SUM(MemberWinLost) MemberWinLost
			, SUM(PlayerComm) PlayerComm
			, SUM(MemberTotal) MemberTotal
			, SUM(AgWinLost) AgWinLost
			, SUM(AgComm) AgComm
			, SUM(AgTotal) AgTotal
			, SUM(Company) Company
			, SUM(RewardAmount) RewardAmount
			, '' AS RewardCurrency
		FROM @AgWinLossDetails
	END

END	
GO
/*<info serverAlias="DBAGE-bodb02" executers="wsv_xnap" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[EAS_Rpt_WinLossDetailByCurrency_SAg]
	@custid			INT,--srecommend
	@masterid		INT = NULL,
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
	Task : Master Winloss Detail By Currency
	DB: DBAGE/bodb02
	Original: [EAS_Rpt_WinLossDetail_SAg]
	Revisions:
		- 20231205@Lewis: Initialize SP [RedmineID: #196959]
		- 20240116@Lewis: Sort by Username [RedmineID: #196959]
		- 20240306@Lewis: Add Virtual Ice Hockey [RedmineID: #201129]
		- 20240515@Lewis: Add SABA Kabaddi [RedmineID: #203763]
	    - 20240918@Lewis: Rebate Retention - Reward [RedmineId: #208503]
		- 20241216@Bobby: Enahnce MBU & Base Currency [RedmineID: #213507]
	
	Param's Explanation:
		@BaseCurrency:  unchecked
						MYR
						CNY
						THB
						IDR


*/
BEGIN
	SET NOCOUNT ON

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
	FROM dbo.EAS_f_GetDailyExchangeRate(@FromDate,@ToDate,@GroupName,@BaseCurrency) ;

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

	-----------------------------------------
	DECLARE @FDate SMALLDATETIME, @TDate SMALLDATETIME, @__ProductDetails XML;

	SELECT @FDate = @FromDate, @TDate = @ToDate

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
		RewardAmount	DECIMAL(24,4)
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

	--TODO: bettrans
	SELECT @FDate = FromDate, @TDate = ToDate
	FROM (VALUES(@FromDate)) AS t (CheckDate)
	OUTER APPLY (
		SELECT * FROM dbo.f_MBU_RangeDate(CheckDate, @ToDate, @BalanceUpDay, @MoveBetsDay)
		WHERE RangeType = 1
	) AS fc


	IF @FDate IS NOT NULL
	BEGIN
				
		INSERT INTO @SAgWinLossDetails(
			CustID, TurnOver, TurnoverNoDraw, GrossComm, MemberWinLost, 
			PlayerComm, MemberTotal, AgWinLost, AgComm, AgTotal, 
			MAgWinLost, MAgComm, MAgTotal, SAgWinLost, SAgComm, SAgTotal, Company
		)
		SELECT
			b.custid,			
			SUM(ABS(b.Turnover)*ex.Rate) as TurnOver,
			SUM(TurnoverNoDraw*ex.Rate) AS TurnoverNoDraw,
			SUM(GrossComm*ex.Rate) AS GrossComm,
			SUM(winlost*ex.Rate), --MemberWinlost
			SUM(playercomm*ex.Rate), -- PlayerComm
			ISNULL(SUM(winlost*ex.Rate), 0) + ISNULL(SUM(playercomm*ex.Rate), 0), --MemberTotal
			SUM(awinlost*ex.Rate), -- AgWinlost
			ISNULL(SUM((comm-playercomm)*ex.Rate),0), --AgComm
			ISNULL(SUM((awinlost+comm-playercomm)*ex.Rate), 0), --AgTotal			
			SUM(mwinlost*ex.Rate), -- MAgWinlost
			SUM(acomm*ex.Rate)-SUM(comm*ex.Rate), --MAgComm
			ISNULL(SUM(mwinlost*ex.Rate), 0) + ISNULL(SUM(acomm*ex.Rate), 0)-SUM(comm*ex.Rate), --MAgTotal
			SUM(swinlost*ex.Rate), -- SAgWinlost
			ISNULL(SUM(scomm*ex.Rate),0) -ISNULL(SUM(acomm*ex.Rate),0), --SAgComm
			ISNULL(SUM(swinlost*ex.Rate), 0) + ISNULL(SUM(scomm*ex.Rate), 0)-SUM(acomm*ex.Rate), --SAgTotal
			-(ISNULL(SUM(swinlost*ex.Rate), 0) + ISNULL(SUM(awinlost*ex.Rate), 0) + ISNULL(SUM(mwinlost*ex.Rate), 0) + ISNULL(SUM(scomm*ex.Rate), 0) + ISNULL(SUM(winlost*ex.Rate), 0)) --Company				
		FROM bodb_Age.dbo.bettrans_compact b WITH(NOLOCK)
			INNER JOIN #downlineList dl ON dl.custid = b.custid
			INNER JOIN #tmp_Oanda ex ON ex.CurrencyId = dl.CurrencyId AND ex.ExchangeDate = b.winlostdate
			INNER JOIN #tmpSportBettype s ON b.bettype = s.bettype 
				AND (s.ProductID <> 1 OR (s.ProductID = 1 AND b.sporttype = s.SportType AND b.LeagueGroupID = s.LeagueGroupID AND b.TicketType = s.TicketType))
		WHERE b.winlostdate BETWEEN @FDate and @TDate 
		GROUP BY b.custid

		-- bettransRnG
		INSERT INTO @GrossComm (CustId, TurnoverNoDraw, GrossComm)
		SELECT
			dl.CustId
			,SUM(CASE WHEN cont.ContributionBettype IS NULL THEN b.BetStake ELSE 0 END*ex.Rate) AS TurnoverNoDraw
			,SUM(b.BetStake * b.sdiscount*ex.Rate) AS GrossComm
		FROM dbo.bettransRnG b WITH(NOLOCK)
			INNER JOIN #downlineList dl ON dl.custid = IIF(b.mrecommend=-4, b.custid, b.mrecommend)
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
			AND srecommend = @custid
		GROUP BY dl.custid
				
		-- bettransLC
		INSERT INTO @GrossComm (CustId, TurnoverNoDraw, GrossComm)
		SELECT
			dl.CustId
			,SUM(CASE WHEN cont.ContributionBettype IS NULL THEN b.NetStake ELSE 0 END*ex.Rate) AS TurnoverNoDraw
			,SUM(b.NetStake * b.sdiscount*ex.Rate) AS GrossComm
		FROM dbo.bettransLC b WITH(NOLOCK)
			INNER JOIN #downlineList dl ON dl.custid = IIF(b.mrecommend=-4, b.custid, b.mrecommend)
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
			AND srecommend = @custid
		GROUP BY b.winlostdate,dl.custid
				
		IF EXISTS (SELECT 1 FROM @GrossComm)
		BEGIN
			UPDATE t
			SET t.TurnoverNoDraw = ISNULL(t.TurnoverNoDraw, 0) + ISNULL(c.TurnoverNoDraw, 0)
				,t.GrossComm = ISNULL(t.GrossComm, 0) + ISNULL(c.GrossComm, 0)
			FROM @SAgWinLossDetails t
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
		
			INSERT INTO @SAgWinLossDetails(
				CustID, TurnOver, TurnoverNoDraw, GrossComm, MemberWinLost, 
				PlayerComm, MemberTotal, AgWinLost, AgComm, AgTotal, 
				MAgWinLost, MAgComm, MAgTotal, SAgWinLost, SAgComm, SAgTotal, Company
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
				ISNULL(SUM((comm-playercomm)*ex.Rate),0), --AgComm
				ISNULL(SUM((awinlost+comm-playercomm)*ex.Rate), 0), --AgTotal		
				SUM(mwinlost*ex.Rate), -- MAgWinlost
				SUM(acomm*ex.Rate)-SUM(comm*ex.Rate), --MAgComm
				ISNULL(SUM(mwinlost*ex.Rate), 0) + ISNULL(SUM(acomm*ex.Rate), 0)-SUM(comm*ex.Rate), --MAgTotal
				SUM(swinlost*ex.Rate), -- SAgWinlost
				ISNULL(SUM(scomm*ex.Rate),0) -ISNULL(SUM(acomm*ex.Rate),0), --SAgComm
				ISNULL(SUM(swinlost*ex.Rate), 0) + ISNULL(SUM(scomm*ex.Rate), 0)-SUM(acomm*ex.Rate), --SAgTotal
				-(ISNULL(SUM(swinlost*ex.Rate), 0) + ISNULL(SUM(awinlost*ex.Rate), 0) + ISNULL(SUM(mwinlost*ex.Rate), 0) + ISNULL(SUM(scomm*ex.Rate), 0) + ISNULL(SUM(winlost*ex.Rate), 0)) --Company					
			FROM
				bodb02.dbo.sum_winloss b WITH (NOLOCK) 
				INNER JOIN #downlineList dl ON  dl.mrecommend = b.mrecommend AND dl.recommend = b.recommend AND dl.custid = b.custid
				INNER JOIN #tmp_Oanda ex ON ex.CurrencyId = dl.CurrencyId AND ex.ExchangeDate = b.winlostdate
				INNER JOIN @TmpCondSumWL t ON b.sporttype = t.sporttype AND b.bettype = t.bettype AND ISNULL(b.leagueGroupID,0) = t.LeagueGroupID AND ISNULL(b.ticketType,0) = t.TicketType
			WHERE
				b.winlostdate BETWEEN @FDate and @TDate			
				AND b.SRecommend = @custid
				AND b.MRecommend IN (dl.custid, -4)
				AND b.Recommend IN (0, -4)
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
							
		INSERT INTO @SAgWinLossDetails(
										CustID, TurnOver, TurnoverNoDraw, GrossComm, MemberWinLost, 
										PlayerComm, MemberTotal, AgWinLost, AgComm, AgTotal, 
										MAgWinLost, MAgComm, MAgTotal, SAgWinLost, SAgComm, SAgTotal, Company
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
				ISNULL(SUM((comm-playercomm)*ex.Rate),0), --AgComm
				ISNULL(SUM((awinlost+comm-playercomm)*ex.Rate), 0), --AgTotal		
				SUM(mwinlost*ex.Rate), -- MAgWinlost
				SUM(acomm*ex.Rate)-SUM(comm*ex.Rate), --MAgComm
				ISNULL(SUM(mwinlost*ex.Rate), 0) + ISNULL(SUM(acomm*ex.Rate), 0)-SUM(comm*ex.Rate), --MAgTotal
				SUM(swinlost*ex.Rate), -- SAgWinlost
				ISNULL(SUM(scomm*ex.Rate),0) -ISNULL(SUM(acomm*ex.Rate),0), --SAgComm
				ISNULL(SUM(swinlost*ex.Rate), 0) + ISNULL(SUM(scomm*ex.Rate), 0)-SUM(acomm*ex.Rate), --SAgTotal
				-(ISNULL(SUM(swinlost*ex.Rate), 0) + ISNULL(SUM(awinlost*ex.Rate), 0) + ISNULL(SUM(mwinlost*ex.Rate), 0) + ISNULL(SUM(scomm*ex.Rate), 0) + ISNULL(SUM(winlost*ex.Rate), 0)) --Company								
			FROM bodb_Summary.dbo.Sum_WinLoss_Old b WITH(NOLOCK)
				INNER JOIN #downlineList dl ON dl.custid = b.mRecommend 
				INNER JOIN #tmp_Oanda ex ON ex.CurrencyId = dl.CurrencyId AND ex.ExchangeDate = b.winlostdate
				INNER JOIN @TmpCondSumWL t ON b.sporttype = t.sporttype AND b.bettype = t.bettype AND b.leagueGroupID = t.LeagueGroupID AND b.ticketType = t.TicketType
			WHERE b.winlostdate BETWEEN @FDate AND @TDate			
				AND b.SRecommend = @custid
				AND b.MRecommend IN (dl.custid)
				AND b.Recommend IN (0)
				AND b.RoleID IN (3) 
				
			GROUP BY dl.custid
	END	

	--TODO: SabaWalletTicket	
	SELECT @FDate = @FromDate, @TDate = @ToDate

	INSERT INTO @SAgWinLossDetails(CustID,RewardAmount)
	SELECT dl.custid, SUM(b.Amount*ex.Rate)
	FROM dbo.SabaWalletTicket b WITH (NOLOCK)
		INNER JOIN #downlineList dl ON dl.custid = b.mRecommend AND dl.roleid = 3
		INNER JOIN #tmp_Oanda ex ON ex.CurrencyId = dl.CurrencyId AND ex.ExchangeDate = b.winlostdate
	WHERE b.WinlostDate BETWEEN @FDate AND @TDate
		AND b.WalletID = 2
	GROUP BY dl.custid

	UNION ALL
	SELECT dl.custid, SUM(b.Amount*ex.Rate)
	FROM dbo.SabaWalletTicket b WITH (NOLOCK)
		INNER JOIN #downlineList dl ON dl.custid = b.CustID AND dl.roleid = 1
		INNER JOIN #tmp_Oanda ex ON ex.CurrencyId = dl.CurrencyId AND ex.ExchangeDate = b.winlostdate
	WHERE b.WinlostDate BETWEEN @FDate AND @TDate
		AND b.WalletID = 2
	GROUP BY dl.custid
	------------

	--Grid--
	SELECT b.CustID 
			, dl.UserName, dl.roleId
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
			, SUM(MAgWinLost) MAgWinLost
			, SUM(MAgComm) MAgComm
			, SUM(MAgTotal) MAgTotal
			, SUM(SAgWinLost) SAgWinLost
			, SUM(SAgComm) SAgComm
			, SUM(SAgTotal) SAgTotal
			, SUM(Company) Company
			, SUM(RewardAmount) RewardAmount
			, dl.CurrencyCode AS RewardCurrency
	FROM @SAgWinLossDetails b
		INNER JOIN #downlineList dl ON dl.custid = b.CustID
	GROUP BY b.CustID 
			, dl.UserName 
			, dl.CurrencyID 
			, dl.CurrencyName
			, dl.CurrencyCode, dl.roleid
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
			, SUM(MAgWinLost) MAgWinLost
			, SUM(MAgComm) MAgComm
			, SUM(MAgTotal) MAgTotal
			, SUM(SAgWinLost) SAgWinLost
			, SUM(SAgComm) SAgComm
			, SUM(SAgTotal) SAgTotal
			, SUM(Company) Company
			, SUM(RewardAmount) RewardAmount
			, dl.CurrencyCode AS RewardCurrency
		FROM @SAgWinLossDetails b
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
			, SUM(MAgWinLost) MAgWinLost
			, SUM(MAgComm) MAgComm
			, SUM(MAgTotal) MAgTotal
			, SUM(SAgWinLost) SAgWinLost
			, SUM(SAgComm) SAgComm
			, SUM(SAgTotal) SAgTotal
			, SUM(Company) Company
			, SUM(RewardAmount) RewardAmount
			, '' AS RewardCurrency
		FROM @SAgWinLossDetails
	END
END	
GO
/*<info serverAlias="DBAGE-bodb02" executers="wsv_xnap" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[EAS_Rpt_WinLossDetailByCurrency_ByPT] 	
	@GroupName		VARCHAR(50),
	@CustId         INT = NULL,
	@FromDate		SMALLDATETIME,
	@ToDate			SMALLDATETIME,
	@ProductIds		VARCHAR(MAX),
	@ProductDetails NVARCHAR(MAX),
	@BalanceUpDay	SMALLDATETIME,
	@MoveBetsDay	SMALLDATETIME,
	@BaseCurrency	VARCHAR(5) = '',
	@Currencies		NVARCHAR(MAX) = ''
AS
/*
	Created by: Lewis
	Date: 2023-12-18
	Task : Details win/lost by PT Currency
	DB: DBAGE/bodb02
	Revisions:
		- 20231218@Lewis: Initialize SPs [RedmineID : #196959]
		- 20240116@Lewis: Sort by Username [RedmineID: #196959]
		- 20240306@Lewis: Add Virtual Ice Hockey [RedmineID: #201129]
		- 20240515@Lewis: Add SABA Kabaddi [RedmineID: #203763]
		- 20241216@Bobby: Enhance MBU date range [RedmineID: #215182]

	Param's Explanation:
		- @BaseCurrency:  MYR|CNY|THB|IDR

*/
BEGIN
	SET NOCOUNT ON;

	DROP TABLE IF EXISTS #GrossComm;
	DROP TABLE IF EXISTS #ComWinLossDetails;
	DROP TABLE IF EXISTS #tmp_Oanda;
	DROP TABLE IF EXISTS #TmpCondSumWL;

	-- Exchange Rate Oanda
	CREATE TABLE #tmp_Oanda(
		ExchangeDate SMALLDATETIME
		,CurrencyId INT
		,CurrencyName NVARCHAR(50)
		,Code VARCHAR(12)
		,Rate FLOAT
		INDEX CIX_#tmp_Oanda (CurrencyId, ExchangeDate)
	);

	INSERT INTO #tmp_Oanda(ExchangeDate,CurrencyId,CurrencyName,Code,Rate)
	SELECT ExchangeDate
		,CurrencyId
		,CurrencyName
		,Code
		,Rate 
	FROM dbo.EAS_f_GetDailyExchangeRate(@FromDate,@ToDate,@GroupName,@BaseCurrency);

	DECLARE @tmp_currencylist TABLE(CurrencyName VARCHAR(15))  
	INSERT INTO @tmp_currencylist(CurrencyName)  
	SELECT [value] FROM STRING_SPLIT(@Currencies,',')  
	-----------------------------------------

	DECLARE @tmpSuperList TABLE(custID INT PRIMARY KEY, CurrencyId INT, UserName VARCHAR(50), CurrencyName NVARCHAR(15));

	INSERT INTO @tmpSuperList(CustID, UserName, CurrencyId, CurrencyName)
	SELECT cg.custId, ci.username, ci.Currency, ex.currency
	FROM dbo.Acc_CustGroup cg WITH(NOLOCK)
		INNER JOIN dbo.custinfo ci WITH(NOLOCK) ON ci.custid = cg.custid
		INNER JOIN dbo.Exchange ex WITH(NOLOCK) ON ex.ExchangeId = ci.currency
		LEFT JOIN @tmp_currencylist tmp ON tmp.CurrencyName = ex.currency
	WHERE cg.GroupName = @GroupName
		AND (@custid IS NULL OR cg.custid = @custid) 
		AND (@Currencies='' OR tmp.CurrencyName IS NOT NULL)

	DECLARE @ExistingProductDetails TABLE (ProductId INT,Sporttype INT,Bettype INT, LeagueGroupID SMALLINT, TicketType TINYINT)
	DECLARE @isTest BIT, @__ProductDetails XML;
	SELECT  @isTest = dbo.f_CheckSPVersion(@@PROCID);	

	SELECT @ProductIds = dbo.f_AddRelatedProducts(@ProductIds);
	SELECT @__ProductDetails = CONVERT(XML, @ProductDetails)

	INSERT INTO @ExistingProductDetails(ProductId, Sporttype,Bettype,LeagueGroupID,TicketType)
	SELECT ProductId,Sporttype,Bettype,LeagueGroupID,TicketType
	FROM dbo.f_ProductDetail_ConditionSel(@ProductDetails, @__ProductDetails)

	DECLARE @SeparateSabaSport_Cutoff SMALLDATETIME 

	SELECT @SeparateSabaSport_Cutoff = CutoffDate
	FROM dbo.f_GetCutoffDate()
	WHERE TypeName = 'SabaSport'

	CREATE TABLE #TmpCondSumWL(
		SportType		INT,
		BetType			INT,
		ProductID		INT,
		LeagueGroupID	SMALLINT, 
		TicketType		TINYINT
		INDEX CIX_#TmpCondSumWL CLUSTERED (SportType, BetType)
	);

	IF @FromDate <= @MoveBetsDay
	BEGIN
		INSERT INTO #TmpCondSumWL(SportType, BetType, LeagueGroupID, TicketType, ProductID) 
		SELECT f.SportType, f.BetType, f.LeagueGroupID, f.TicketType, ISNULL(p.GroupProductId, f.ProductID)
		FROM dbo.f_SumWinloss_ConditionSel(@ProductIds) f
			LEFT JOIN @ExistingProductDetails e ON f.ProductID = e.ProductId 
			LEFT JOIN dbo.f_GroupProduct() p ON f.ProductID = p.ProductId    
		WHERE e.ProductId IS NULL OR (e.Bettype = f.BetType AND e.Sporttype = f.SportType AND e.TicketType = f.TicketType AND e.LeagueGroupID = f.LeagueGroupID AND e.ProductID =  ISNULL(p.GroupProductId, f.ProductID))
	END

	CREATE TABLE #ComWinLossDetails 
	(	
		CustID			INT, 
		ProductID		INT,
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
		INDEX CIX_#ComWinLossDetails CLUSTERED (CustID, ProductID)
	);

	CREATE TABLE #GrossComm (CustId INT, ProductId INT, TurnoverNoDraw DECIMAL(24,4), GrossComm DECIMAL(24,4))

	--Avoid Parameter Sniffing for bettrans and sum_winloss
	DECLARE @FDate	SMALLDATETIME,
			@TDate	SMALLDATETIME;
	    
	--TODO: bettrans_compact
	SELECT @FDate = FromDate, @TDate = ToDate
	FROM (VALUES(@FromDate)) AS t (CheckDate)
	OUTER APPLY (
		SELECT * FROM dbo.f_MBU_RangeDate(CheckDate, @ToDate, @BalanceUpDay, @MoveBetsDay)
		WHERE RangeType = 1
	) AS fc
	
	IF @FDate IS NOT NULL
	BEGIN
		-- bettrans 
		; WITH cte_SportBettype AS (
			SELECT	ISNULL(p.GroupProductId, f.ProductID) AS ProductID, f.BetType, f.RefTable, ISNULL(e.LeagueGroupID,0) AS LeagueGroupID, ISNULL(e.TicketType,0) AS TicketType, ISNULL(SportType,0) AS SportType
			FROM dbo.f_SportBettypeMatrixByProduct_Sel(@ProductIds, @IsTest) f
				LEFT JOIN dbo.f_GroupProduct() p ON f.ProductID = p.ProductId
				LEFT JOIN @ExistingProductDetails e ON e.ProductId = f.ProductID 
			WHERE EXISTS(
				SELECT 1
				WHERE e.ProductId IS NULL 
				OR (e.Bettype = f.BetType 
					OR (
						e.Bettype = 0  AND  (e.ProductId = 1 OR  f.BetType NOT IN (SELECT g.Bettype FROM f_GetProductDetail() g WHERE g.ProductId <> 1))
					)
				)
			)		
		)
		INSERT INTO #ComWinLossDetails(CustID,ProductID,Turnover,TurnoverNoDraw,GrossComm
			, MemberWinLost,PlayerComm --,MemberTotal
			, AgWinLost,AgComm --,AgTotal
			, MAgWinLost,MAgComm --,MAgTotal
			, SAgWinLost,SAgComm,SComm --,SAgTotal
			--, Company
		)
		SELECT 
			b.custid,																																																	
			s.ProductID,																									
			SUM(b.Turnover*ex.Rate),
			SUM(TurnoverNoDraw*ex.Rate) AS TurnoverNoDraw,
			SUM(GrossComm*ex.Rate) AS GrossComm,
			SUM(winlost*ex.Rate) ,
			SUM(playercomm*ex.Rate) ,
			SUM(awinlost*ex.Rate), --AgWinlost
			SUM((comm-playercomm)*ex.Rate), --AgComm
			SUM(mwinlost*ex.Rate) , --MAgWinlost
			SUM((acomm-comm)*ex.Rate), --MAgComm
			SUM(swinlost*ex.Rate),		--SAgWinlost																								
			SUM((scomm-acomm)*ex.Rate),	--SAgComm																					
			SUM(scomm*ex.Rate) --SComm		
		FROM bodb_Age.dbo.bettrans_compact b WITH (NOLOCK)
			INNER JOIN @tmpSuperList ts ON ts.custID = b.custid
			INNER JOIN cte_SportBettype s ON b.bettype = s.bettype 
					AND (s.ProductID <> 1 OR (s.ProductID = 1 AND b.sporttype = s.SportType AND b.LeagueGroupID = s.LeagueGroupID AND b.TicketType = s.TicketType))
			INNER JOIN #tmp_Oanda ex ON ex.ExchangeDate = b.winlostdate AND ex.CurrencyId = ts.CurrencyId
		WHERE b.winlostdate BETWEEN @FDate AND @Tdate
		GROUP BY b.custid, s.ProductID

		-- bettransRnG
		INSERT INTO #GrossComm (CustId, ProductId, TurnoverNoDraw, GrossComm)
		SELECT ts.custID, s.ProductId
			,SUM(CASE WHEN cont.ContributionBettype IS NULL THEN b.BetStake ELSE 0 END * ex.Rate) AS TurnoverNoDraw
			,SUM(b.BetStake * b.sdiscount * ex.Rate) AS GrossComm
		FROM dbo.bettransRnG b WITH(NOLOCK)
			INNER JOIN @tmpSuperList ts ON ts.custID = b.srecommend
			INNER JOIN #tmp_Oanda ex ON ex.ExchangeDate = b.winlostdate AND ex.CurrencyId = ts.CurrencyId
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
		GROUP BY ts.custID, s.ProductId
		
		-- bettransLC
		INSERT INTO #GrossComm (CustId, ProductId, TurnoverNoDraw, GrossComm)
		SELECT ts.custID, s.ProductId
			,SUM(CASE WHEN cont.ContributionBettype IS NULL THEN b.NetStake ELSE 0 END * ex.Rate) AS TurnoverNoDraw
			,SUM(b.NetStake * b.sdiscount * ex.Rate) AS GrossComm
		FROM dbo.bettransLC b WITH(NOLOCK)
			INNER JOIN @tmpSuperList ts ON ts.custID = b.srecommend
			INNER JOIN #tmp_Oanda ex ON ex.ExchangeDate = b.winlostdate AND ex.CurrencyId = ts.CurrencyId
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
		GROUP BY ts.custID, s.ProductId

		IF EXISTS (SELECT 1 FROM #GrossComm)
		BEGIN
			UPDATE t
			SET t.TurnoverNoDraw = ISNULL(t.TurnoverNoDraw, 0) + ISNULL(c.TurnoverNoDraw, 0)
				,t.GrossComm = ISNULL(t.GrossComm, 0) + ISNULL(c.GrossComm, 0)
			FROM #ComWinLossDetails t
				INNER JOIN (
					SELECT CustId, ProductId, SUM(GrossComm) AS GrossComm, SUM(TurnoverNoDraw) AS TurnoverNoDraw 
					FROM #GrossComm 
					GROUP BY CustId, ProductId
				) c ON t.CustId = c.CustId AND t.ProductId = c.ProductId 
		END
	END

	DECLARE @winlostdateTable TABLE (winlostdate SMALLDATETIME, custid INT, CurrencyId INT);

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
		INSERT INTO @winlostdateTable(winlostdate, custid, CurrencyId)
		SELECT cte.winlostdate, ts.custid, ts.CurrencyId
		FROM CTE_Winlostdate cte
		CROSS JOIN @tmpSuperList ts

		INSERT INTO #ComWinLossDetails(CustID,ProductID,Turnover,TurnoverNoDraw,GrossComm
			, MemberWinLost,PlayerComm --,MemberTotal
			, AgWinLost,AgComm --,AgTotal
			, MAgWinLost,MAgComm --,MAgTotal
			, SAgWinLost,SAgComm,SComm --,SAgTotal
			--, Company
		)
		SELECT ts.CustID,
			t.ProductID,
			SUM(b.Turnover*ex.Rate),
			SUM(TunroverNoDraw*ex.Rate) AS TurnoverNoDraw,
			SUM(GrossComm*ex.Rate) AS GrossComm,
			SUM(winlost*ex.Rate) ,
			SUM(playercomm*ex.Rate) ,
			SUM(awinlost*ex.Rate), --AgWinlost
			SUM((ISNULL(comm,0)-ISNULL(playercomm,0))*ex.Rate), --AgComm
			SUM(mwinlost*ex.Rate) , --MAgWinlost
			SUM((ISNULL(acomm,0)-ISNULL(comm,0))*ex.Rate), --MAgComm
			SUM(swinlost*ex.Rate),		--SAgWinlost																								
			SUM((ISNULL(scomm,0)-ISNULL(acomm,0))*ex.Rate),	--SAgComm																						
			SUM(scomm*ex.Rate) --SComm

		FROM dbo.SUM_winloss b WITH(NOLOCK) 
			INNER JOIN @winlostdateTable ts ON b.winlostdate = ts.winlostdate
				AND b.srecommend = ts.custid
			INNER JOIN #tmp_Oanda ex ON ex.ExchangeDate = b.winlostdate AND ex.CurrencyId = ts.CurrencyId
			INNER JOIN #TmpCondSumWL t ON b.sporttype = t.sporttype 
				AND b.bettype = t.bettype 
				AND b.leagueGroupID = t.LeagueGroupID 
				AND b.ticketType = t.TicketType
		
		WHERE b.mrecommend = 0
			AND b.recommend = 0
			AND b.RoleID = 4
		GROUP BY ts.CustID, t.ProductID;
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
		INSERT INTO @winlostdateTable(winlostdate, custid, CurrencyId)
		SELECT cte.winlostdate, ts.custid, ts.CurrencyId
		FROM CTE_Winlostdate cte
		CROSS JOIN @tmpSuperList ts
		OPTION (MAXRECURSION 0);

		-- using cte to remove predicate when seek on sum_winloss_old
		INSERT INTO #ComWinLossDetails(CustID,ProductID,Turnover,TurnoverNoDraw,GrossComm
			, MemberWinLost,PlayerComm --,MemberTotal
			, AgWinLost,AgComm --,AgTotal
			, MAgWinLost,MAgComm --,MAgTotal
			, SAgWinLost,SAgComm,SComm --,SAgTotal
			--, Company
		)
		SELECT ts.CustID,
			t.ProductID,
			SUM(b.Turnover*ex.Rate),
			SUM(TunroverNoDraw*ex.Rate) AS TurnoverNoDraw,
			SUM(GrossComm*ex.Rate) AS GrossComm,
			SUM(winlost*ex.Rate) ,
			SUM(playercomm*ex.Rate) ,
			SUM(awinlost*ex.Rate), --AgWinlost
			SUM((ISNULL(comm,0)-ISNULL(playercomm,0))*ex.Rate), --AgComm
			SUM(mwinlost*ex.Rate) , --MAgWinlost
			SUM((ISNULL(acomm,0)-ISNULL(comm,0))*ex.Rate), --MAgComm
			SUM(swinlost*ex.Rate),		--SAgWinlost																								
			SUM((ISNULL(scomm,0)-ISNULL(acomm,0))*ex.Rate),	--SAgComm																					
			SUM(scomm*ex.Rate) --SComm

		FROM bodb_Summary.dbo.Sum_WinLoss_Old b WITH(NOLOCK) 
			INNER JOIN @winlostdateTable ts ON b.winlostdate = ts.winlostdate
				AND b.srecommend = ts.custid
			INNER JOIN #tmp_Oanda ex ON ex.ExchangeDate = b.winlostdate AND ex.CurrencyId = ts.CurrencyId
			INNER JOIN #TmpCondSumWL t ON b.sporttype = t.sporttype 
				AND b.bettype = t.bettype 
				AND b.leagueGroupID = t.LeagueGroupID 
				AND b.ticketType = t.TicketType

		WHERE b.mrecommend = 0
			AND b.recommend = 0
			AND b.RoleID = 4
		GROUP BY ts.CustID,  t.ProductID;
	END

	--TODO: Detail output
	SELECT 	w.CustID,
			ts.UserName,
			w.ProductID,
			p.ProductName,
			ts.CurrencyId,
			ts.CurrencyName,
			SUM(Turnover) Turnover,
			SUM(TurnoverNoDraw) TurnoverNoDraw,
			SUM(GrossComm) GrossComm, 
			SUM(MemberWinLost) MemberWinLost,
			SUM(PlayerComm) PlayerComm,
			SUM(MemberWinLost + PlayerComm) AS MemberTotal,
			SUM(AgWinLost) AgWinLost,
			SUM(AgComm) AgComm,
			SUM(AgWinLost + AgComm) AS AgTotal,
			SUM(MAgWinLost) MAgWinLost,
			SUM(MAgComm) MAgComm	,
			SUM(MAgWinLost + MAgComm) AS MAgTotal,
			SUM(SAgWinLost) SAgWinLost, 
			SUM(SAgComm) SAgComm	, 
			SUM(SAgWinLost + SAgComm) AS SAgTotal, 
			-SUM(SAgWinLost + MAgWinLost + AgWinLost + SComm + MemberWinLost) AS Company
	FROM #ComWinLossDetails w

		INNER JOIN @tmpSuperList ts ON w.CustID = ts.CustID
		INNER JOIN dbo.Products p WITH(NOLOCK) ON w.ProductId = p.ProductID

	GROUP BY w.CustID,ts.UserName,w.ProductID, p.ProductName,ts.CurrencyId,ts.CurrencyName
	ORDER BY ts.Username

	-- TODO: Sum Total
	IF @BaseCurrency = ''
	BEGIN
		SELECT 
			CONCAT('Total ', ts.CurrencyName) AS Total
			, SUM(Turnover) Turnover
			, SUM(TurnoverNoDraw) TurnoverNoDraw
			, SUM(GrossComm) GrossComm
			, SUM(MemberWinLost) MemberWinLost
			, SUM(PlayerComm) PlayerComm
			, SUM(MemberWinLost + PlayerComm) AS MemberTotal
			, SUM(AgWinLost) AgWinLost
			, SUM(AgComm) AgComm
			, SUM(AgWinLost + AgComm) AS AgTotal
			, SUM(MAgWinLost) MAgWinLost
			, SUM(MAgComm) MAgComm	
			, SUM(MAgWinLost + MAgComm) AS MAgTotal
			, SUM(SAgWinLost) SAgWinLost
			, SUM(SAgComm) SAgComm	
			, SUM(SAgWinLost + SAgComm) AS SAgTotal
			, -SUM(SAgWinLost + MAgWinLost + AgWinLost + SComm + MemberWinLost) AS Company
		FROM #ComWinLossDetails w
			INNER JOIN @tmpSuperList ts ON ts.custID = w.CustID
		GROUP BY ts.CurrencyName
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
			, SUM(MemberWinLost + PlayerComm) AS MemberTotal
			, SUM(AgWinLost) AgWinLost
			, SUM(AgComm) AgComm
			, SUM(AgWinLost + AgComm) AS AgTotal
			, SUM(MAgWinLost) MAgWinLost
			, SUM(MAgComm) MAgComm	
			, SUM(MAgWinLost + MAgComm) AS MAgTotal
			, SUM(SAgWinLost) SAgWinLost
			, SUM(SAgComm) SAgComm	
			, SUM(SAgWinLost + SAgComm) AS SAgTotal
			, -SUM(SAgWinLost + MAgWinLost + AgWinLost + SComm + MemberWinLost) AS Company
		FROM #ComWinLossDetails w
	END
END
GO
/*<info serverAlias="DBAGE-bodb02" executers="wsv_xnap" isFunction="0" isNested="0"></info>*/
CREATE PROCEDURE [dbo].[EAS_Rpt_WinLossDetailByCurrency_ByPT] 	
	@GroupName		VARCHAR(50),
	@CustId         INT = NULL,
	@FromDate		SMALLDATETIME,
	@ToDate			SMALLDATETIME,
	@ProductIds		VARCHAR(MAX),
	@ProductDetails NVARCHAR(MAX),
	@BalanceUpDay	SMALLDATETIME,
	@MoveBetsDay	SMALLDATETIME,
	@BaseCurrency	INT = 1, --MYR
	@CurrencyIds	NVARCHAR(MAX)
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

	CREATE TABLE #tmp_currencylist(CurrencyId INT)  
	INSERT INTO #tmp_currencylist(CurrencyId)  
	SELECT value FROM string_split(@CurrencyIds,',')  
	-----------------------------------------

	CREATE TABLE #tmpSuperList (custID INT PRIMARY KEY)

	INSERT INTO #tmpSuperList(CustID)
	SELECT custID 
	FROM bodb02.dbo.Acc_CustGroup WITH(NOLOCK)
	WHERE (@custid IS NULL OR custid = @custid) AND GroupName = @GroupName

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

	DROP TABLE IF EXISTS #TmpCondSumWL;
	CREATE TABLE #TmpCondSumWL(
		SportType		INT,
		BetType			INT,
		ProductID		INT,
		LeagueGroupID	SMALLINT, 
		TicketType		TINYINT
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
		winlostdate		SMALLDATETIME,
		CustID			INT, 
		ProductID		INT,
		Turnover		MONEY,
		TurnoverNoDraw	MONEY,
		GrossComm		MONEY, 
		MemberWinLost	MONEY,
		PlayerComm		MONEY,
		MemberTotal		MONEY,
		AgWinLost		MONEY,
		AgComm			MONEY,
		AgTotal			MONEY,
		MAgWinLost		MONEY,
		MAgComm			MONEY,
		MAgTotal		MONEY,
		SAgWinLost		MONEY, 
		SAgComm			MONEY, 
		SAgTotal		MONEY, 
		Company			MONEY
	);


	CREATE TABLE #GrossComm (winlostdate SMALLDATETIME, CustId INT, ProductId INT, TurnoverNoDraw MONEY, GrossComm MONEY)

	--Avoid Parameter Sniffing for bettrans and sum_winloss
	DECLARE @FDate	SMALLDATETIME,
			@TDate	SMALLDATETIME,
			@CID	INT;
	    
	SELECT	@FDate = @FromDate,
			@TDate = @ToDate

	IF @ToDate >= @BalanceUpDay
	BEGIN
		IF @FromDate <= @MoveBetsDay
		BEGIN
			SET @FDate = DATEADD(DD, 1, @MoveBetsDay);
		END

		-- SportBetype 
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
		),
		cte_bettrans AS
		(
			SELECT	b.winlostdate,
					b.SRecommend,
					s.ProductID,
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
									  ) AND b.betdaqid <> -2 AND b.winlostdate >= @SeparateSabaSport_Cutoff  THEN m.sporttype
						ELSE 0 END  sporttype, 
						CASE WHEN ( 
										(l.LeagueGroupID IN (42,74,108,113) AND m.sporttype = 1 ) 
										 OR (l.LeagueGroupID IN (122, 42) AND m.sporttype = 2 )
										 OR (l.LeagueGroupID = 42 AND m.sporttype = 50)
										 OR (l.LeagueGroupID = 42 AND m.sporttype = 5) --SabaTennis
										 OR (l.LeagueGroupID = 42 AND m.sporttype = 4) --Virtual Ice Hockey
										 OR (l.LeagueGroupID = 42 AND m.sporttype = 47) --SABA Kabaddi
										 OR (l.LeagueGroupID = 151 AND m.sporttype = 43)
									  ) AND b.betdaqid <> -2 AND b.winlostdate >= @SeparateSabaSport_Cutoff  THEN l.LeagueGroupID
						ELSE 0 END LeagueGroupID,
						CASE WHEN b.betdaqid = -2 THEN 1 ELSE 0 END TicketType
				) AS et
				INNER JOIN cte_SportBettype s ON b.bettype = s.bettype 
					AND (s.ProductID <> 1 OR (s.ProductID = 1 AND et.sporttype = s.SportType AND et.LeagueGroupID = s.LeagueGroupID AND et.TicketType = s.TicketType))
			WHERE	b.winlostdate BETWEEN @FDate AND @Tdate
					AND b.srecommend IN (SELECT custID FROM #tmpSuperList) 
					AND b.statusID IN (111, 112, 113) 
		GROUP BY	b.winlostdate,
					b.SRecommend,
					s.ProductID
		)
		INSERT INTO #ComWinLossDetails(winlostdate,CustID, ProductID,Turnover,TurnoverNoDraw,GrossComm, MemberWinLost,PlayerComm,MemberTotal,AgWinLost,AgComm,AgTotal,MAgWinLost,MAgComm,MAgTotal,SAgWinLost, SAgComm, SAgTotal, Company)
		SELECT
			b.winlostdate,
			SRecommend,																																																	
			b.ProductID,																									
			SUM(ABS(b.stake)),
			SUM(TurnoverNoDraw) AS TurnoverNoDraw,
			SUM(GrossComm) AS GrossComm,
			SUM(winlost - actual_stake) ,
			SUM(playercomm) ,
			SUM(winlost - actual_stake) + SUM(playercomm),
			SUM(awinlost),
			ISNULL(SUM(comm - playercomm),0) ,
			SUM(awinlost) + ISNULL(SUM(comm - playercomm),0),
			SUM(mwinlost) ,
			SUM(acomm)-SUM(comm),
			SUM(mwinlost) + SUM(acomm)-SUM(comm),
			SUM(swinlost),																										
			SUM(scomm) - SUM(acomm),																							
			SUM(swinlost) + SUM(scomm) -SUM(acomm),																			
			-(SUM(swinlost) +SUM(awinlost)+ SUM(winlost-actual_stake) + SUM(mwinlost) + SUM(scomm))				
		FROM cte_bettrans b WITH (NOLOCK)
		GROUP BY b.winlostdate, srecommend, b.ProductID

		-- bettransRnG
		INSERT INTO #GrossComm (winlostdate, CustId, ProductId, TurnoverNoDraw, GrossComm)
		SELECT b.winlostdate, b.srecommend AS CustId, s.ProductId
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
			AND b.srecommend IN (SELECT custID FROM #tmpSuperList)
		GROUP BY b.winlostdate, b.srecommend, s.ProductId
		
		-- bettransLC
		INSERT INTO #GrossComm (winlostdate, CustId, ProductId, TurnoverNoDraw, GrossComm)
		SELECT b.winlostdate, b.srecommend AS CustId, s.ProductId
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
			AND b.srecommend IN (SELECT custID FROM #tmpSuperList)
		GROUP BY b.winlostdate, b.srecommend, s.ProductId

		IF EXISTS (SELECT 1 FROM #GrossComm)
		BEGIN
			UPDATE t
			SET t.TurnoverNoDraw = ISNULL(t.TurnoverNoDraw, 0) + ISNULL(c.TurnoverNoDraw, 0)
				,t.GrossComm = ISNULL(t.GrossComm, 0) + ISNULL(c.GrossComm, 0)
			FROM #ComWinLossDetails t
				INNER JOIN (
					SELECT winlostdate, CustId, ProductId, SUM(GrossComm) AS GrossComm, SUM(TurnoverNoDraw) AS TurnoverNoDraw FROM #GrossComm GROUP BY winlostdate, CustId, ProductId
				) c ON t.CustId = c.CustId AND t.ProductId = c.ProductId AND t.winlostdate = c.winlostdate
		END
		
		IF @BalanceUpDay < @FromDate
		BEGIN
			SET @FDate = @FromDate;
		END
		ELSE
		BEGIN
			SET @FDate = @BalanceUpDay;
		END
		
		IF @ToDate > @MoveBetsDay
		BEGIN
			SET @TDate = @MoveBetsDay;
		END

		INSERT INTO #ComWinLossDetails(winlostdate, CustID, ProductID,Turnover,TurnoverNoDraw,GrossComm, MemberWinLost,PlayerComm,MemberTotal,AgWinLost,AgComm,AgTotal,MAgWinLost,MAgComm,MAgTotal,SAgWinLost, SAgComm, SAgTotal, Company)
		SELECT b.winlostdate,
			   b.CustID,
			   t.ProductID,
			   SUM(Turnover),
			   SUM(TunroverNoDraw),
			   SUM(GrossComm),
			   SUM(winlost),
			   SUM(playercomm),
			   SUM(winlost) + SUM(playercomm),
			   SUM(awinlost),
			   ISNULL(SUM(comm - playercomm),0),
			   SUM(awinlost) + ISNULL(SUM(comm - playercomm),0),
			   SUM(mwinlost),
			   SUM(acomm) - SUM(comm),
			   SUM(mwinlost) +  SUM(acomm) - SUM(comm),
			   SUM(swinlost),
			   ISNULL(SUM(scomm),0) - ISNULL(SUM(acomm),0),
			   SUM(swinlost) +  ISNULL(SUM(scomm),0) -  ISNULL(SUM(acomm),0),
			   	-(SUM(swinlost)+ SUM(mwinlost) +SUM(awinlost) + SUM(winlost)  + SUM(scomm))

		FROM dbo.SUM_winloss b WITH(NOLOCK)
			INNER JOIN #TmpCondSumWL t ON b.sporttype = t.sporttype AND b.bettype = t.bettype AND ISNULL(b.leagueGroupID,0) = t.LeagueGroupID AND ISNULL(b.ticketType,0) = t.TicketType
		WHERE b.winlostdate BETWEEN @FDate AND @TDate
			AND b.custid  IN (SELECT tmp.custID FROM #tmpSuperList tmp) 
			AND RoleID = 4
		GROUP BY b.winlostdate, b.CustID, ProductID;
	END

	SELECT	@FDate = @FromDate,
			@TDate = @ToDate;
	
	IF @FromDate < @BalanceUpDay
	BEGIN
		IF @ToDate >= DATEADD(dd, -1, @BalanceUpDay)
		BEGIN
			SELECT @TDate = DATEADD(dd, -1, @BalanceUpDay);
		END

		DECLARE @winlostdateTable TABLE (winlostdate smalldatetime)

		;WITH CTE_Winlostdate (winlostdate ) AS
		(
			SELECT @FDate AS winlostdate
			UNION ALL
			SELECT DATEADD(DAY, 1, winlostdate)
			FROM CTE_Winlostdate
			WHERE winlostdate < @TDate
		)
		INSERT INTO @winlostdateTable(winlostdate)
		select * from CTE_Winlostdate
		OPTION (MAXRECURSION 0)

		-- using cte to remove predicate when seek on sum_winloss_old
		INSERT INTO #ComWinLossDetails(winlostdate, CustID, ProductID,Turnover,TurnoverNoDraw,GrossComm, MemberWinLost,PlayerComm,MemberTotal,AgWinLost,AgComm,AgTotal,MAgWinLost,MAgComm,MAgTotal,SAgWinLost, SAgComm, SAgTotal, Company)
		SELECT b.winlostdate,
			   b.CustID,
			   w.ProductID,
			   SUM(Turnover),
			   SUM(TunroverNoDraw),
			   SUM(GrossComm),
			   SUM(winlost),
			   SUM(playercomm),
			   SUM(winlost) + SUM(playercomm),
			   SUM(awinlost),
			   ISNULL(SUM(comm - playercomm),0),
			   SUM(awinlost) + ISNULL(SUM(comm - playercomm),0),
			   SUM(mwinlost),
			   SUM(acomm) - SUM(comm),
			   SUM(mwinlost) + SUM(acomm) - SUM(comm),
			   SUM(swinlost),
			   ISNULL(SUM(scomm),0) - ISNULL(SUM(acomm),0),
			   SUM(swinlost) +  ISNULL(SUM(scomm),0) -  ISNULL(SUM(acomm),0),
			   	-(SUM(swinlost)+ SUM(mwinlost) +SUM(awinlost) + SUM(winlost)  + SUM(scomm))

		FROM bodb_Summary.dbo.Sum_WinLoss_Old b WITH(NOLOCK)
		CROSS APPLY (
				SELECT  t.winlostdate, u.SportType, u.BetType, u.ProductID, u.LeagueGroupID, u.TicketType
				FROM #TmpCondSumWL u
				cross join @winlostdateTable t
		) w
		WHERE b.winlostdate = w.winlostdate
			AND b.custid  IN (SELECT tmp.custID FROM #tmpSuperList tmp) 
			AND b.RoleID = 4
			AND b.sporttype = w.sporttype
			AND b.bettype = w.bettype
			AND ISNULL(b.leagueGroupID,0) = w.LeagueGroupID
			AND ISNULL(b.ticketType,0) = w.TicketType
		GROUP BY b.winlostdate, b.CustID,  w.ProductID;
	END
	--RESULT--
	CREATE TABLE #tmp_result(
		CustID INT
		, UserName NVARCHAR(50)
		, ProductID INT
		, ProductName VARCHAR(50)
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
		, ProductID
		, ProductName
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
	SELECT 	w.CustID,
			c.UserName,
			w.ProductID,
			p.ProductName,
			o.CurrencyId,
			o.CurrencyName,
			SUM(Turnover * o.Rate) Turnover,
			SUM(TurnoverNoDraw * o.Rate) TurnoverNoDraw,
			SUM(GrossComm * o.Rate) GrossComm, 
			SUM(MemberWinLost * o.Rate) MemberWinLost,
			SUM(PlayerComm * o.Rate) PlayerComm,
			SUM(MemberTotal * o.Rate) MemberTotal,
			SUM(AgWinLost * o.Rate) AgWinLost,
			SUM(AgComm * o.Rate) AgComm,
			SUM(AgTotal * o.Rate) AgTotal,
			SUM(MAgWinLost * o.Rate) MAgWinLost,
			SUM(MAgComm * o.Rate) MAgComm	,
			SUM(MAgTotal * o.Rate) MAgTotal,
			SUM(SAgWinLost * o.Rate) SAgWinLost, 
			SUM(SAgComm * o.Rate) SAgComm	, 
			SUM(SAgTotal * o.Rate) SAgTotal, 
			SUM(Company * o.Rate) Company
	FROM #ComWinLossDetails w
	INNER JOIN dbo.custinfo c WITH(NOLOCK) ON w.CustID = c.CustID
	INNER JOIN #tmp_Oanda o ON o.CurrencyId = c.currency AND o.ExchangeDate = w.winlostdate
	INNER JOIN dbo.Products p WITH(NOLOCK) ON w.ProductId = p.ProductID
	WHERE c.currency IN (SELECT CurrencyId FROM #tmp_currencylist)
	GROUP BY w.winlostdate,w.CustID,c.UserName,w.ProductID, p.ProductName,o.CurrencyId,o.CurrencyName
	


	SELECT	CustID,
			UserName,
			ProductID,
			ProductName,
			CurrencyId,
			CurrencyName,
			SUM(Turnover) Turnover,
			SUM(TurnoverNoDraw) TurnoverNoDraw,
			SUM(GrossComm) GrossComm, 
			SUM(MemberWinLost) MemberWinLost,
			SUM(PlayerComm) PlayerComm,
			SUM(MemberTotal) MemberTotal,
			SUM(AgWinLost) AgWinLost,
			SUM(AgComm) AgComm,
			SUM(AgTotal) AgTotal,
			SUM(MAgWinLost) MAgWinLost,
			SUM(MAgComm) MAgComm	,
			SUM(MAgTotal) MAgTotal,
			SUM(SAgWinLost) SAgWinLost, 
			SUM(SAgComm) SAgComm	, 
			SUM(SAgTotal) SAgTotal, 
			SUM(Company) Company
	FROM #tmp_result
	GROUP BY CustID,
			UserName,
			ProductID,
			ProductName,
			CurrencyId,
			CurrencyName
	ORDER BY Username

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


	DROP TABLE #GrossComm;
	DROP TABLE #tmpSuperList;
	DROP TABLE #ComWinLossDetails;
	DROP TABLE #tmp_Oanda;
	DROP TABLE #tmp_currencylist;
	DROP TABLE #tmp_result;
END
GO
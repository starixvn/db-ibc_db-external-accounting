/*<info serverAlias="DBAGE-bodb02" executers="wsv_xnap" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[EAS_Rpt_WinLossDetailByCurrency_Com]	
	@GroupName		VARCHAR(50),
	@custid			INT = NULL,	
	@FromDate		SMALLDATETIME,
	@ToDate			SMALLDATETIME,
	@ProductIds		VARCHAR(MAX) = '',
	@ProductDetails NVARCHAR(MAX) = 'All',
	@MoveBetsDay	SMALLDATETIME,
	@BalanceUpDay	SMALLDATETIME,
	@BaseCurrency	VARCHAR(5) = 'MYR',
	@Currencies		NVARCHAR(MAX) = ''

AS
/*
	Created by: Lewis
	Date: 2023-12-05
	Task : Super Winloss Detail
	DB: DBAGE/bodb02
	Original: [EAS_Rpt_WinLossDetail_Com]
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

	-- Exchange Rate Oanda
	DROP TABLE IF EXISTS #tmp_Oanda;
	CREATE TABLE #tmp_Oanda(
		ExchangeDate SMALLDATETIME
		,CurrencyId INT
		,CurrencyName NVARCHAR(50)
		,Code VARCHAR(12)
		,Rate FLOAT
		,PRIMARY KEY (CurrencyId, ExchangeDate)
	);

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

	DECLARE @tmp_currencylist TABLE(CurrencyName NVARCHAR(15))  
	INSERT INTO @tmp_currencylist(CurrencyName)  
	SELECT VALUE FROM STRING_SPLIT(@Currencies,',') 
	 
	-----------------------------------------
	DROP TABLE IF EXISTS #tmpSuperList
	CREATE TABLE #tmpSuperList (custID INT PRIMARY KEY, CurrencyId INT, UserName VARCHAR(50), CurrencyName NVARCHAR(15), CurrencyCode NVARCHAR(15));

	DECLARE @ExistingProductDetails TABLE (ProductId INT,Sporttype INT,Bettype INT, LeagueGroupID SMALLINT, TicketType TINYINT)
	DECLARE @FDate SMALLDATETIME, @TDate SMALLDATETIME, @__ProductDetails XML;

	SELECT @FDate = @FromDate, @TDate = @ToDate

	INSERT INTO #tmpSuperList(CustID, UserName, CurrencyId,CurrencyName, CurrencyCode)
	SELECT cg.custId, ci.username, ci.Currency, ex.currency, ex.Code
	FROM dbo.Acc_CustGroup cg WITH(NOLOCK)
		INNER JOIN dbo.custinfo ci WITH(NOLOCK) ON ci.custid = cg.custid
		INNER JOIN dbo.Exchange ex WITH(NOLOCK) ON ex.ExchangeId = ci.currency
		LEFT JOIN @tmp_currencylist tmp ON tmp.CurrencyName = ex.currency
	WHERE cg.GroupName = @GroupName
		AND (@custid IS NULL OR cg.custid = @custid) 
		AND (@Currencies='' OR tmp.CurrencyName IS NOT NULL)

	DROP TABLE IF EXISTS #ComWinLossDetails;
	CREATE TABLE #ComWinLossDetails 
	(
		CustID INT, 
		Turnover		DECIMAL(24,4), 
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
		ExtraWinloss	DECIMAL(24,4), 
		ExtraComm		DECIMAL(24,4), 
		ExtraTotal		DECIMAL(24,4), 
		Company			DECIMAL(24,4), 
		CompanyAfterExtraPT		DECIMAL(24,4),
		RewardAmount			DECIMAL(24,4)
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

	--Force optimizer to seek on IX_srecommend index
	DECLARE @n BIGINT = 2147483647

	--TODO: bettrans
	SELECT @FDate = FromDate, @TDate = ToDate
	FROM (VALUES(@FromDate)) AS t (CheckDate)
	OUTER APPLY (
		SELECT * FROM dbo.f_MBU_RangeDate(CheckDate, @ToDate, @BalanceUpDay, @MoveBetsDay)
		WHERE RangeType = 1
	) AS fc

	IF @FDate IS NOT NULL
	BEGIN 
		---- get extra PT from table setting
		DROP TABLE IF EXISTS #tmpSuperExtraPT;
		CREATE TABLE #tmpSuperExtraPT(SuperId INT, winlostdate SMALLDATETIME, productId INT, sporttype INT, bettypePT INT,  ExtraPT DECIMAL(24,4), RefTable TINYINT, LeagueGroupID SMALLINT, TicketType TINYINT
			INDEX  CIX_tmpSuperExtraPT CLUSTERED (SuperId, winlostdate, bettypePT)
		);

		;
		WITH wld AS (
			SELECT @FDate AS winlostdate
			UNION ALL
			SELECT DATEADD(DD, 1, winlostdate) 
			FROM wld
			WHERE winlostdate < @TDate
		), superWLD AS (
			SELECT cg.custID AS SuperID, wld.winlostdate
			FROM #tmpSuperList cg
			CROSS APPLY wld
		),
		superBet AS (
			SELECT sw.SuperID, sw.winlostdate, b.bettype
			FROM bodb_AGE.dbo.bettrans_compact b WITH(NOLOCK)
			INNER JOIN superWLD sw ON sw.SuperID = b.custid AND sw.winlostdate = b.winlostdate
			GROUP BY sw.SuperID, sw.winlostdate, b.bettype
		)
		INSERT INTO #tmpSuperExtraPT(SuperId, winlostdate, productId, Sporttype, bettypePT, ExtraPT, RefTable, LeagueGroupID, TicketType)
		SELECT b.SuperID, b.winlostdate, tbl.ProductID, tbl.Sporttype, b.bettype, ept.ExtraPT, tbl.RefTable
			, tbl.LeagueGroupID, tbl.TicketType
		FROM superBet b 
		CROSS APPLY 
		(
			SELECT DISTINCT
				s.ProductID, s.RefTable, s.Sporttype, s.LeagueGroupID, s.TicketType
			FROM #SportBettype s
			WHERE s.bettype = b.bettype
		) AS tbl
		OUTER APPLY 
		(
			SELECT DISTINCT expt2.SuperId, expt2.ExtraPT
			FROM dbo.Acc_GroupExtraPT2Setting expt2 WITH (NOLOCK)
			WHERE b.winlostdate BETWEEN expt2.FromDate AND expt2.ToDate
					AND tbl.ProductID = expt2.ProductID
					AND b.SuperID = expt2.SuperId 
					AND ISNULL(expt2.SubProduct,'') = ''
					AND expt2.Sporttype = 0
		) AS ept
		OPTION (MAXRECURSION 0);
			
			
		DROP TABLE IF EXISTS #ComWinLossDetails_bettrans;
		CREATE TABLE #ComWinLossDetails_bettrans 
		(
			winlostdate		SMALLDATETIME,
			SRecommend		INT, 
			bettype			DECIMAL(24,4), 
			StatusID		TINYINT, 
			tpositiontaking SMALLMONEY,
			epositiontaking SMALLMONEY,
			RefTable		TINYINT,
			ExtraPT2		DECIMAL(9,8),
			TurnoverNoDraw	DECIMAL(24,4),
			stake			DECIMAL(24,4), 
			scomm			DECIMAL(24,4), 
			MemberWinlost	DECIMAL(24,4), 
			playercomm		DECIMAL(24,4), 
			AgWinlost		DECIMAL(24,4), 
			AgComm			DECIMAL(24,4),
			MAgWinlost		DECIMAL(24,4), 
			MAgComm			DECIMAL(24,4), 
			SAgWinlost		DECIMAL(24,4), 
			SAgComm			DECIMAL(24,4),
			betid			DECIMAL(24,4), 
			GrossComm		DECIMAL(24,4)
		);

		INSERT INTO #ComWinLossDetails 	(
				CustID, Turnover, TurnoverNoDraw, GrossComm, MemberWinLost, PlayerComm, MemberTotal, AgWinLost, AgComm, 
				AgTotal, MAgWinLost, MAgComm, MAgTotal, SAgWinLost, SAgComm, SAgTotal, Company
			)
		SELECT
			b.custid,
			SUM(TurnOver*ex.Rate), -- TurnOver
			SUM(TurnoverNoDraw*ex.Rate) as TurnoverNoDraw,
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
		FROM bodb_AGE.dbo.bettrans_compact b WITH(NOLOCK)			
			INNER JOIN #tmpSuperExtraPT sl ON sl.SuperId = b.custid  
					AND sl.Winlostdate = b.winlostdate
					AND sl.bettypePT = b.bettype
					AND (sl.ProductID <> 1 OR (sl.ProductID = 1 AND b.sporttype = sl.SportType AND b.LeagueGroupID = sl.LeagueGroupID AND b.TicketType = sl.TicketType))
			INNER JOIN #tmpSuperList ts ON ts.custid = b.custid
			INNER JOIN #tmp_Oanda ex ON  ex.CurrencyId = ts.CurrencyId AND ex.ExchangeDate = b.winlostdate
		GROUP BY b.CustID

		DELETE #ComWinLossDetails_bettrans

		IF EXISTS (SELECT 1 FROM #SportBettype WHERE RefTable = 1) -- bettransRnG
		BEGIN
			INSERT INTO #ComWinLossDetails_bettrans (winlostdate,SRecommend, bettype, stake, GrossComm) -- use stake for Net Stake
			SELECT b.winlostdate,b.srecommend, b.gameID, SUM(b.BetStake), SUM(b.BetStake * b.sdiscount)
			FROM dbo.bettransRnG b WITH (NOLOCK)
			WHERE b.winlostdate BETWEEN @FDate AND @TDate 
				AND b.srecommend IN (SELECT custID FROM #tmpSuperList) 
				and b.statusID IN (111, 112, 113)
			GROUP BY b.winlostdate,b.srecommend, b.gameID
		END

		IF EXISTS (SELECT 1 FROM #SportBettype WHERE RefTable = 2) -- bettransLC
		BEGIN
			INSERT INTO #ComWinLossDetails_bettrans (winlostdate,SRecommend, bettype, stake, GrossComm) -- use stake for Net Stake
			SELECT b.winlostdate,b.srecommend, b.gameID, SUM(b.NetStake), SUM(b.NetStake * b.sdiscount)
			FROM dbo.bettransLC b WITH (NOLOCK)
			WHERE b.winlostdate BETWEEN @FDate AND @TDate 
				AND b.srecommend IN (SELECT custID FROM #tmpSuperList) 
				and b.statusID IN (111, 112, 113)
			GROUP BY b.winlostdate,b.srecommend, b.gameID
		END

		IF EXISTS (SELECT 1 FROM #ComWinLossDetails_bettrans)
		BEGIN
			UPDATE t
			SET t.TurnoverNoDraw = ISNULL(t.TurnoverNoDraw, 0) + ISNULL(c.TurnoverNoDraw, 0)
				,t.GrossComm = ISNULL(t.GrossComm, 0) + ISNULL(c.GrossComm, 0)
			FROM #ComWinLossDetails t
				INNER JOIN (
					SELECT b.srecommend, SUM(b.GrossComm*ex.Rate) AS GrossComm, 
						SUM(CASE WHEN cont.ContributionBettype IS NULL THEN b.stake ELSE 0 END*ex.Rate) AS TurnoverNoDraw
					FROM #ComWinLossDetails_bettrans b
						INNER JOIN #SportBettype s ON b.bettype = s.Bettype AND s.RefTable IN (1, 2)
						OUTER APPLY 
						(
							SELECT f.Bettype AS ContributionBettype
							FROM dbo.f_BettypePrizeGroup() f
							WHERE f.BettypeGroup = 'Contribution'
								AND f.Bettype = b.bettype
						) cont
						INNER JOIN #tmpSuperList ts ON ts.custid = b.SRecommend
						INNER JOIN #tmp_Oanda ex ON  ex.CurrencyId = ts.CurrencyId AND ex.ExchangeDate = b.winlostdate
					GROUP BY b.srecommend
				) c ON t.CustId = c.srecommend 
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
		INSERT INTO #ComWinLossDetails (
				CustID, Turnover, TurnoverNoDraw, GrossComm, MemberWinLost, PlayerComm, MemberTotal, AgWinLost, AgComm, 
				AgTotal, MAgWinLost, MAgComm, MAgTotal, SAgWinLost, SAgComm, SAgTotal, Company )
		SELECT
			ts.CustID,			
			SUM(TurnOver*ex.Rate), -- TurnOver
			SUM(TunroverNoDraw*ex.Rate) as TurnoverNoDraw,
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
			INNER JOIN #TmpCondSumWL t 
				ON b.sporttype = t.sporttype AND b.bettype = t.bettype AND ISNULL(b.leagueGroupID,0) = t.LeagueGroupID AND ISNULL(b.ticketType,0) = t.TicketType
			INNER JOIN #tmpSuperList ts ON ts.custid = b.srecommend
			INNER JOIN #tmp_Oanda ex ON ex.ExchangeDate = b.winlostdate AND ex.CurrencyId = ts.CurrencyId
		WHERE
			b.winlostdate BETWEEN @FDate and @TDate	
			AND b.mrecommend = 0
			AND b.recommend = 0
			AND b.custid = ts.custID
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
		SELECT * FROM CTE_Winlostdate
		OPTION (MAXRECURSION 0)

		INSERT INTO #ComWinLossDetails (
					CustID, Turnover, TurnoverNoDraw, GrossComm, MemberWinLost, PlayerComm, MemberTotal, AgWinLost, AgComm, 
					AgTotal, MAgWinLost, MAgComm, MAgTotal, SAgWinLost, SAgComm, SAgTotal, Company )
		SELECT
			ts.CustID,			
			SUM(TurnOver*ex.Rate), -- TurnOver
			SUM(TunroverNoDraw*ex.Rate) as TurnoverNoDraw,
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
			bodb_Summary.dbo.Sum_WinLoss_Old b WITH(NOLOCK) 
			INNER JOIN #tmpSuperList ts ON ts.custid = b.SRecommend
			INNER JOIN #tmp_Oanda ex ON ex.ExchangeDate = b.winlostdate AND ex.CurrencyId = ts.CurrencyId
			CROSS APPLY (
				SELECT  t.winlostdate, u.SportType, u.BetType, u.LeagueGroupID, u.TicketType
				FROM #TmpCondSumWL u
				CROSS JOIN @winlostdateTable t
			) w
		WHERE b.winlostdate = w.winlostdate  
				AND b.mrecommend = 0
				AND b.recommend = 0
				AND b.roleid = 4
				AND b.sporttype = w.sporttype 
				AND b.bettype = w.bettype
				AND ISNULL(b.leagueGroupID,0) = w.LeagueGroupID
				AND ISNULL(b.ticketType,0) = w.TicketType
		GROUP BY ts.CustID

	END	

	--TODO: SabaWalletTicket
	SELECT @FDate = @FromDate, @TDate = @ToDate

	INSERT INTO #ComWinLossDetails(CustID, RewardAmount)
	SELECT b.Srecommend, SUM(b.Amount*ex.Rate)
	FROM dbo.SabaWalletTicket b WITH (NOLOCK)
	INNER JOIN #tmpSuperList s ON b.Srecommend = s.custID
	INNER JOIN #tmp_Oanda ex ON ex.ExchangeDate = b.winlostdate AND ex.CurrencyId = s.CurrencyId
	WHERE b.WinlostDate BETWEEN @FDate AND @TDate
		AND b.WalletID = 2
	GROUP BY b.Srecommend

	--Result--
	SELECT ts.CustID 
		, ts.UserName 
		, ts.CurrencyID 
		, ts.CurrencyName
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
		, ts.CurrencyCode AS RewardCurrency
	FROM #ComWinLossDetails b
	INNER JOIN #tmpSuperList ts ON ts.custID = b.CustID
	GROUP BY ts.CustID 
		, ts.UserName 
		, ts.CurrencyID 
		, ts.CurrencyName
		, ts.CurrencyCode
	ORDER BY ts.Username

	-- Total --
	IF @BaseCurrency = ''
	BEGIN
		SELECT 
			CONCAT('Total ', ts.CurrencyName) AS Total
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
			, ts.CurencyCode AS RewardCurrency
		FROM #ComWinLossDetails b
		INNER JOIN #tmpSuperList ts ON ts.custID = b.CustID
		GROUP BY ts.CurrencyName, ts.CurrencyCode
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
		FROM #ComWinLossDetails
	END
END
GO

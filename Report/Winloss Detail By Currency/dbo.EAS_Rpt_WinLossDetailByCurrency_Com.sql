/*<info serverAlias="DBAGE-bodb02" executers="bodbExtAccNet" isFunction="0" isNested="0"></info>*/
CREATE PROCEDURE [dbo].[EAS_Rpt_WinLossDetailByCurrency_Com]	
	@GroupName		VARCHAR(50),
	@custid			INT = NULL,	
	@FromDate		SMALLDATETIME,
	@ToDate			SMALLDATETIME,
	@ProductIds		VARCHAR(MAX) = '',
	@ProductDetails NVARCHAR(MAX) = 'All',
	@MoveBetsDay	SMALLDATETIME,
	@BalanceUpDay	SMALLDATETIME,
	@BaseCurrency	INT = 1, --MYR
	@CurrencyIds	NVARCHAR(MAX) = ''

AS
/*
	Created by: Lewis
	Date: 2023-12-05
	Task : Super Winloss Detail
	DB: DBAGE/bodb02
	Original: [EAS_Rpt_WinLossDetail_Com]
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
	SET NOCOUNT ON;
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

	DECLARE @ExistingProductDetails TABLE (ProductId INT,Sporttype INT,Bettype INT, LeagueGroupID SMALLINT, TicketType TINYINT)
	DECLARE @FDate SMALLDATETIME, @TDate SMALLDATETIME, @__ProductDetails XML;

	SELECT @FDate = @FromDate, @TDate = @ToDate

	INSERT INTO #tmpSuperList(CustID)
	SELECT cg.custID
	FROM bodb02.dbo.Acc_CustGroup cg WITH(NOLOCK)
	WHERE (@custid IS NULL OR custid = @custid)
		AND GroupName = @GroupName

	CREATE TABLE #ComWinLossDetails 
	(
		winlostdate SMALLDATETIME,
		CustID INT, Turnover MONEY, TurnoverNoDraw MONEY, GrossComm MONEY, MemberWinLost MONEY, 
		PlayerComm MONEY, MemberTotal MONEY, AgWinLost MONEY, AgComm MONEY, AgTotal MONEY, 
		MAgWinLost MONEY, MAgComm MONEY, MAgTotal MONEY, SAgWinLost MONEY, SAgComm MONEY, SAgTotal MONEY,
		Company MONEY
	)

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
	
	IF @Todate >= @BalanceUpDay
	BEGIN 
		IF @ToDate > @MoveBetsDay
		BEGIN
			IF @MoveBetsDay > @FromDate
				SELECT @FDate = DATEADD(DD, 1, @MoveBetsDay) --DATEADD(dd, -1, @BalanceUpDay)

			---- get extra PT from table setting
			
			CREATE TABLE #tmpSuperExtraPT(SuperId INT, winlostdate SMALLDATETIME, productId INT, sporttype INT, bettypePT INT,  ExtraPT MONEY, RefTable TINYINT, LeagueGroupID SMALLINT, TicketType TINYINT)
			CREATE CLUSTERED INDEX CIX_tmpSuperExtraPT ON #tmpSuperExtraPT(SuperId, winlostdate, bettypePT)

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
				FROM dbo.bettrans b WITH(NOLOCK)
				INNER JOIN superWLD sw ON sw.SuperID = b.srecommend AND sw.winlostdate = b.winlostdate
				WHERE b.statusID IN (111,112,113)
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
			

			CREATE TABLE #ComWinLossDetails_bettrans 
			(
				winlostdate		SMALLDATETIME,
				SRecommend		INT, 
				bettype			MONEY, 
				StatusID		TINYINT, 
				tpositiontaking SMALLMONEY,
				epositiontaking SMALLMONEY,
				RefTable		TINYINT,
				ExtraPT2		DECIMAL(9,8),
				TurnoverNoDraw	MONEY,
				stake			MONEY, 
				scomm			MONEY, 
				MemberWinlost	MONEY, 
				playercomm		MONEY, 
				AgWinlost		MONEY, 
				AgComm			MONEY,
				MAgWinlost		MONEY, 
				MAgComm			MONEY, 
				SAgWinlost		MONEY, 
				SAgComm			MONEY,
				betid			MONEY, 
				GrossComm		MONEY
			)

			INSERT #ComWinLossDetails_bettrans(
				winlostdate,SRecommend, bettype, tpositiontaking, epositiontaking, RefTable, ExtraPT2
				,TurnoverNoDraw,stake, scomm, MemberWinlost, playercomm, AgWinlost, AgComm, MAgWinlost, MAgComm, SAgWinlost, SAgComm, betid, GrossComm
			)
			 SELECT
				b.winlostdate,
				SRecommend,
				bettype,
				tpositiontaking,
				epositiontaking,
				sl.RefTable,
				sl.ExtraPT,
				SUM(CASE
					WHEN sl.RefTable IN (1, 2) THEN 0 -- bettransRnG/bettransLC
					WHEN sl.ProductId = 47 THEN b.oddsspread -- BBIN
					WHEN sl.ProductId = 1 AND b.statusId = 111 THEN 0 -- SB draw
					WHEN sl.ProductId = 1 AND b.StatusId IN (112, 113) AND b.modds IN (-0.25, 0.25) THEN ABS(b.stake)/2 -- SB half won/lose
					ELSE ABS(b.stake)
				END) AS TurnoverNoDraw,
				SUM(ABS(b.stake)),	
				SUM(scomm),
				sum(winlost-actual_stake), --MemberWinlost
				sum(playercomm), -- PlayerComm
				sum(awinlost), -- AgWinlost
				isnull(sum(comm-playercomm),0), --AgComm	
				sum(mwinlost), -- MAgWinlost
				sum(acomm)-sum(comm), --MAgComm
				sum(swinlost), -- SAgWinlost
				isnull(sum(scomm),0) -isnull(sum(acomm),0), --SAgComm
				SUM(ISNULL(b.betid/CONVERT(DECIMAL(19,8), 100000000), 0)),    
				SUM(CASE WHEN tpositiontaking = 1 THEN 0 ELSE scomm/(1-tpositiontaking) END) AS GrossComm
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
								) AND b.betdaqid <> -2 AND b.winlostdate >= @SeparateSabaSport_Cutoff THEN l.LeagueGroupID
					ELSE 0 END AS LeagueGroupID,
					CASE WHEN ( 
								(l.LeagueGroupID IN (42,74,108,113) AND m.sporttype = 1 ) 
									OR (l.LeagueGroupID IN (122, 42) AND m.sporttype = 2 )
									OR (l.LeagueGroupID = 42 AND m.sporttype = 50)
									OR (l.LeagueGroupID = 42 AND m.sporttype = 5) --SabaTennis
									OR (l.LeagueGroupID = 151 AND m.sporttype = 43)
								) AND b.betdaqid <> -2 AND b.winlostdate >= @SeparateSabaSport_Cutoff THEN m.sporttype
					ELSE 0 END  AS sporttype, 
					CASE WHEN b.betdaqid = -2 THEN 1 ELSE 0 END AS TicketType
				) AS et
				INNER JOIN #tmpSuperExtraPT sl ON sl.SuperId = b.srecommend 
					AND sl.Winlostdate = b.winlostdate
					AND sl.bettypePT = b.bettype
					AND (sl.ProductID <> 1 OR (sl.ProductID = 1 AND et.sporttype = sl.SportType AND et.LeagueGroupID = sl.LeagueGroupID AND et.TicketType = sl.TicketType))
			
			WHERE b.statusID IN (111,112,113)
			GROUP BY 
				b.winlostdate
				, b.SRecommend
				, b.bettype
				, b.tpositiontaking
				, b.epositiontaking
				, sl.RefTable
				, sl.ExtraPT
			OPTION (MAXDOP 8);

			INSERT INTO #ComWinLossDetails 	(
					winlostdate,
					CustID, Turnover, TurnoverNoDraw, GrossComm, MemberWinLost, PlayerComm, MemberTotal, AgWinLost, AgComm, 
					AgTotal, MAgWinLost, MAgComm, MAgTotal, SAgWinLost, SAgComm, SAgTotal, Company
				)
			SELECT
				b.winlostdate,
				b.SRecommend,
				SUM(b.stake) AS Turnover,
				SUM(TurnoverNoDraw) AS TurnoverNoDraw,
				SUM(CASE 
						WHEN b.RefTable IN (1, 2) THEN 0
						ELSE b.GrossComm
					END) AS GrossComm,
				SUM(MemberWinlost), --MemberWinlost
				SUM(playercomm), -- PlayerComm
				SUM(ISNULL(MemberWinlost, 0)) + SUM(ISNULL(playercomm, 0)), --MemberTotal
				SUM(AgWinlost), -- AgWinlost
				SUM(AgComm), --AgComm
				SUM(AgWinlost+ AgComm), --AgTotal			
				SUM(MAgWinlost), -- MAgWinlost
				SUM(MAgComm), --MAgComm
				SUM(MAgWinlost + MAgComm), --MAgTotal
				SUM(SAgWinlost), -- SAgWinlost
				SUM(SAgComm), --SAgComm
				SUM(SAgWinlost + SAgComm), --SAgTotal
			
				-(ISNULL(SUM(SAgWinlost), 0) + ISNULL(SUM(AgWinlost), 0) + ISNULL(SUM(MAgWinlost), 0) + ISNULL(SUM(scomm), 0) + ISNULL(SUM(b.MemberWinlost), 0)) --Company									
			FROM
				#ComWinLossDetails_bettrans b WITH (NOLOCK)
			GROUP BY b.SRecommend,b.winlostdate

			TRUNCATE TABLE #ComWinLossDetails_bettrans

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
						SELECT b.winlostdate,b.srecommend, SUM(b.GrossComm) AS GrossComm, SUM(CASE WHEN cont.ContributionBettype IS NULL THEN b.stake ELSE 0 END) AS TurnoverNoDraw
						FROM #ComWinLossDetails_bettrans b
							INNER JOIN #SportBettype s ON b.bettype = s.Bettype AND s.RefTable IN (1, 2)
							OUTER APPLY 
							(
								SELECT f.Bettype AS ContributionBettype
								FROM dbo.f_BettypePrizeGroup() f
								WHERE f.BettypeGroup = 'Contribution'
									AND f.Bettype = b.bettype
							) cont
						GROUP BY b.winlostdate,b.srecommend
					) c ON t.CustId = c.srecommend AND t.winlostdate = c.winlostdate
			END

		END
   
		SELECT @FDate = @FromDate
	
		IF @BalanceUpDay > @FromDate
			SELECT @FDate = @BalanceUpDay

		IF @FromDate <= @MoveBetsDay
		BEGIN
			IF @ToDate > @MoveBetsDay
				SELECT @TDate = @MoveBetsDay

			INSERT INTO #ComWinLossDetails (
					winlostdate,
					CustID, Turnover, TurnoverNoDraw, GrossComm, MemberWinLost, PlayerComm, MemberTotal, AgWinLost, AgComm, 
					AgTotal, MAgWinLost, MAgComm, MAgTotal, SAgWinLost, SAgComm, SAgTotal, Company )
			SELECT
				b.winlostdate,
				CustID,			
				SUM(TurnOver), -- TurnOver
				SUM(TunroverNoDraw) as TurnoverNoDraw,
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
				bodb02.dbo.sum_winloss b WITH (NOLOCK) 
			INNER JOIN #TmpCondSumWL t 
				ON b.sporttype = t.sporttype AND b.bettype = t.bettype AND ISNULL(b.leagueGroupID,0) = t.LeagueGroupID AND ISNULL(b.ticketType,0) = t.TicketType
			WHERE
				winlostdate between @FDate and @TDate			
				and SRecommend IN (SELECT custID FROM #tmpSuperList)
				and RoleID = 4
			GROUP BY b.winlostdate,CustID
		END
	END

	IF @FromDate < @BalanceUpDay 
	BEGIN
		SELECT @FDate = @FromDate

		IF @ToDate >= DATEADD(dd, -1, @BalanceUpDay)
			SELECT @TDate = DATEADD(dd, -1, @BalanceUpDay)
		
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
					winlostdate,
					CustID, Turnover, TurnoverNoDraw, GrossComm, MemberWinLost, PlayerComm, MemberTotal, AgWinLost, AgComm, 
					AgTotal, MAgWinLost, MAgComm, MAgTotal, SAgWinLost, SAgComm, SAgTotal, Company )
			SELECT
				b.winlostdate,
				CustID,			
				SUM(TurnOver), -- TurnOver
				SUM(TunroverNoDraw) as TurnoverNoDraw,
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
			   bodb_Summary.dbo.Sum_WinLoss_Old b WITH(NOLOCK) 
			   CROSS APPLY (
					SELECT  t.winlostdate, u.SportType, u.BetType, u.LeagueGroupID, u.TicketType
					FROM #TmpCondSumWL u
					cross join @winlostdateTable t
				) w
			WHERE b.winlostdate = w.winlostdate  
					AND b.custid IN (SELECT tmp.custID FROM #tmpSuperList tmp)
					AND b.roleid = 4
					AND b.sporttype = w.sporttype 
					AND b.bettype = w.bettype
					AND ISNULL(b.leagueGroupID,0) = w.LeagueGroupID
					AND ISNULL(b.ticketType,0) = w.TicketType
			GROUP BY b.winlostdate,b.CustID

	END	

	-- RESULT
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
			c.currency as CurrencyId,
			o.CurrencyName as 'Currency Name',
			SUM(TurnOver * o.Rate) as Turnover,
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
			SUM(w.Company * o.Rate) AS Company
		FROM #ComWinLossDetails w 
			INNER JOIN bodb02.dbo.custinfo c WITH(NOLOCK) 
				ON w.CustID = c.CustID
			INNER JOIN #tmp_Oanda o
				ON c.currency = o.CurrencyId
				AND w.winlostdate = o.ExchangeDate
		WHERE c.currency IN (SELECT CurrencyId FROM #tmp_currencylist)
		GROUP BY w.winlostdate,w.CustID, c.UserName,c.currency,o.CurrencyName
		ORDER BY c.Username
	
	--Result--
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

	DROP TABLE #tmp_currencylist
	DROP TABLE #tmp_Oanda
	DROP TABLE #tmpSuperList;
	DROP TABLE #ComWinLossDetails;
	DROP TABLE #TmpCondSumWL;
	DROP TABLE #SportBettype;
	DROP TABLE #tmpSuperExtraPT;
	DROP TABLE #ComWinLossDetails_bettrans;
	DROP TABLE #tmp_result
END
GO

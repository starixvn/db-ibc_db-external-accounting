/*<info serverAlias="DBAGE-bodb02" executers="wsv_xnap" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[EAS_MatchWinloss_Detail] 	
	@GroupName		VARCHAR(50),
	@FromDate		SMALLDATETIME,
	@SportType		SMALLINT,
	@LeagueIds		VARCHAR(1000),
	@MatchIds		VARCHAR(1000),
	@BetTypes		VARCHAR(MAX),
	@Currencies		VARCHAR(1000)	= '',
	@BaseCurrency	VARCHAR(5)		= '',
	@SortBy			VARCHAR(30)		= 'kickofftime',
	@SortType		TINYINT = 0,
	@Page			INT = 1,
	@PageSize		INT = 100,
	@TotalRows		INT = 0 OUTPUT
AS
/*
	Created by: 20240718@Bobby
	Task : Implement match winloss reports [RedmineID : #205355]
	DB: DBAGE/bodb02

	Revisions:
		- 20240718@Bobby: Initialize SPs
*/
BEGIN
	SET NOCOUNT ON;

	DECLARE @fromDateCheck	SMALLDATETIME,
		@BaseCurrencyId		INT,
		@moveBetDate		SMALLDATETIME,
		@balanceUpDate		SMALLDATETIME;

	SELECT @fromDateCheck	= CAST(ISNULL(@FromDate, GETDATE()) AS DATE),
			@Currencies		= ISNULL(@Currencies, ''),
			@BaseCurrency	= ISNULL(@BaseCurrency, '')
	;

	DROP TABLE IF EXISTS #tmpLeague;
	DROP TABLE IF EXISTS #tmpMatch;
	DROP TABLE IF EXISTS #tmpBettype;
	DROP TABLE IF EXISTS #tmpReportData;
	DROP TABLE IF EXISTS #tmpSuperList;
	DROP TABLE IF EXISTS #tmpExchangeRate;

	CREATE TABLE #tmpSuperList(custID INT PRIMARY KEY, Currency INT)
	CREATE TABLE #tmpLeague(leagueid INT PRIMARY KEY);
	CREATE TABLE #tmpMatch(matchid INT PRIMARY KEY);
	CREATE TABLE #tmpBettype(bettype INT PRIMARY KEY, GroupTypeId INT);
	CREATE TABLE #tmpReportData (
		matchid INT 
		,bettype INT 
		,leagueid INT
		,matchcode VARCHAR(50)
		,kickofftime DATETIME
		,homeid INT
		,awayid INT
		,isNeutral BIT
		,stakeAvg DECIMAL(24, 4)
		,betCount INT
		,turnover DECIMAL(24, 4)
		,netTurnover DECIMAL(24, 4)
		,grossComm DECIMAL(24, 4)
		
		----member
		,memberWinloss DECIMAL(24, 4)
		,memberComm DECIMAL(24, 4)
		,memberTotal DECIMAL(24, 4)
		
		----agent
		,agentWinloss DECIMAL(24, 4)
		,agentComm DECIMAL(24, 4)
		,agentTotal DECIMAL(24, 4)

		----master
		,masterWinloss DECIMAL(24, 4)
		,masterComm DECIMAL(24, 4)
		,masterTotal DECIMAL(24, 4)

		----super
		,snetTurnover DECIMAL(24, 4)
		,superWinloss DECIMAL(24, 4)
		,superComm DECIMAL(24, 4)
		,superTotal DECIMAL(24, 4)

		----company
		,companyComm DECIMAL(24, 4)
		,PRIMARY KEY (matchid, bettype)
	);
	CREATE TABLE #tmpExchangeRate(CurrencyId INT, ExchangeDate SMALLDATETIME, Rate MONEY);

	--TODO Saba's sports if any
	DECLARE @sportTypeList TABLE(SportType INT, LeagueGroupId INT);
	IF @SportType > 0
	BEGIN
		INSERT INTO @sportTypeList(SportType, LeagueGroupId)
		VALUES (@SportType, 0)
	END
	ELSE 
	BEGIN 
		INSERT INTO @sportTypeList(SportType, LeagueGroupId)
		SELECT ref.Sporttype, ref.LeagueGroupID
		FROM [dbo].[EAS_f_SabaSportSel] () AS saba
		OUTER APPLY
		(
			SELECT Sporttype, LeagueGroupID
			FROM OPENJSON(saba.SporttypeRef)
			WITH (Sporttype INT '$.Sporttype', 
				LeagueGroupIDs NVARCHAR(MAX) '$.LeagueGroupID' AS JSON
			)
			OUTER APPLY OPENJSON(LeagueGroupIDs) WITH (LeagueGroupID INT '$')
		) AS ref
		WHERE saba.SabaGroupType = @SportType
			AND ref.Sporttype > 0
		
	END

	----TODO: Headline
	INSERT INTO #tmpSuperList
	SELECT DISTINCT cg.custID, c.Currency
	FROM dbo.Acc_CustGroup cg WITH(NOLOCK)
	INNER JOIN dbo.Customer c WITH(NOLOCK) ON c.custid = cg.CustID
	WHERE GroupName = @GroupName

	--TODO: Filter by Currency if ANY
	IF @Currencies <> ''
	BEGIN
		DELETE sl
		FROM #tmpSuperList sl
		INNER JOIN dbo.Exchange ex WITH(NOLOCK) ON ex.ExchangeId = sl.Currency
		LEFT JOIN STRING_SPLIT(@Currencies, ',') cl ON cl.[value] = ex.Code
		WHERE cl.[value] IS NULL
	END

	--TODO: @LeaguaIds filetring
	INSERT INTO #tmpLeague (leagueid)
	SELECT DISTINCT value FROM STRING_SPLIT(@LeagueIds, ',');

	--TODO: @MatchIds filetring
	INSERT INTO #tmpMatch (matchid)
	SELECT DISTINCT value FROM STRING_SPLIT(@MatchIds, ',');

	--TODO: @Bettypes filetring
	INSERT INTO #tmpBettype (bettype, GroupTypeId)
	SELECT ISNULL(bg.bettype, t.bettype) AS bettype
		,ISNULL(bg.GroupTypeId, t.bettype) AS GroupTypeId
	FROM (
		SELECT DISTINCT CAST([value] AS INT) AS bettype
		FROM STRING_SPLIT(@Bettypes, ',')
	) AS t
	LEFT JOIN dbo.f_GroupBettype() bg ON bg.GroupTypeId = t.bettype
	;

	--TODO: Exchange rate
	IF @BaseCurrency <> ''
	BEGIN
		SELECT TOP 1 
			@BaseCurrencyId = CASE WHEN @BaseCurrency = @Currencies THEN 0 ELSE ex.ExchangeId END
		FROM dbo.Exchange ex WITH (NOLOCK)
		WHERE ex.Code = @BaseCurrency;

		INSERT INTo #tmpExchangeRate(CurrencyId, ExchangeDate, Rate)
		SELECT CurrencyId, ExchangeDate, ISNULL(Rate, 1) AS Rate
		FROM dbo.EAS_f_GetExchangeRate (@fromDateCheck, @fromDateCheck, @GroupName, ISNULL(@BaseCurrencyId,0))
	END

	--TODO: get BU/MB days
	EXEC dbo.NAP_Admin_GetMovebetDate @MovebetDate = @moveBetDate OUTPUT
	EXEC dbo.NAP_Admin_GetBalanceUpDate @BalanceUpDate = @balanceUpDate OUTPUT

	--TODO: rptMatchWinloss_compact
	IF @fromDateCheck > @moveBetDate
	BEGIN
		INSERT INTO #tmpReportData
		SELECT CASE 
				WHEN rpt.bettype IN (9,29) THEN 29
				WHEN rpt.bettype IN (10) THEN rpt.bettype
				ELSE rpt.matchid END AS matchid
			,ISNULL(bt.GroupTypeId, rpt.bettype) AS bettype
			,rpt.leagueid, rpt.matchcode
			,ISNULL(m.GlobalShowTime, 0) AS kickofftime ---> admin change KO time any time
			,rpt.homeid, rpt.awayid, rpt.isNeutral
			,AVG((rpt.turnover * ex.Rate)/rpt.betCount)	AS stakeAvg
			,SUM(rpt.betCount)	AS betCount
			,SUM(rpt.turnover * ex.Rate)	AS turnover
			,SUM(rpt.netTurnover * ex.Rate)	AS netTurnover
			,SUM(rpt.grossComm * ex.Rate) AS grossComm

			----member
			,SUM(rpt.winlost * ex.Rate) AS memberWinloss
			,SUM(rpt.playercomm * ex.Rate) AS memberComm
			,SUM((rpt.winlost + rpt.playercomm) * ex.Rate) AS memberTotal
		
			----agent
			,SUM(rpt.awinlost * ex.Rate) AS agentWinloss
			,SUM((rpt.comm - rpt.playercomm) * ex.Rate) AS agentComm
			,SUM((rpt.awinlost + rpt.comm - rpt.playercomm) * ex.Rate) AS agentTotal

			----master
			,SUM(rpt.mwinlost * ex.Rate) AS masterWinloss
			,SUM((rpt.acomm - rpt.comm) * ex.Rate) AS masterComm
			,SUM((rpt.mwinlost + rpt.acomm - rpt.comm) * ex.Rate) AS masterTotal

			----super
			,SUM(rpt.netTurnover * ex.Rate) AS snetTurnover
			,SUM(rpt.swinlost * ex.Rate) AS superWinloss
			,SUM((rpt.scomm - rpt.acomm) * ex.Rate) AS superComm
			,SUM((rpt.swinlost + rpt.scomm - rpt.acomm) * ex.Rate) AS superTotal
		
			----company
			,SUM(rpt.scomm * ex.Rate) AS companyComm
		FROM bodb_Summary.dbo.rptMatchWinloss_compact rpt WITH(NOLOCK)
			INNER JOIN #tmpSuperList sl ON sl.custID = rpt.custid
			INNER JOIN #tmpBettype bt ON bt.bettype = rpt.bettype
			LEFT JOIN @sportTypeList st ON st.SportType = rpt.sporttype AND st.LeagueGroupId = rpt.leaguegroupid
			LEFT JOIN #tmpLeague tl ON tl.leagueid = rpt.leagueid
			LEFT JOIN #tmpMatch tm ON tm.matchid = rpt.matchid
			LEFT JOIN dbo.[match] m WITH(NOLOCK) ON m.matchid = rpt.matchid
			LEFT JOIN #tmpExchangeRate tx  ON tx.currencyId = rpt.currency AND tx.ExchangeDate = rpt.winlostdate
			OUTER APPLY (
				SELECT 
					CASE 
						WHEN @BaseCurrency = @Currencies THEN 1
						ELSE ISNULL(tx.Rate, 1) END
			) AS ex(Rate)
		WHERE rpt.winlostdate = @fromDateCheck
			AND NOT (m.eventstatus <> 'Completed')
			AND 1 = CASE 
						WHEN rpt.bettype IN (9,29) THEN 1
						WHEN st.sporttype > 0 AND tl.leagueid > 0 AND tm.matchid > 0 THEN 1
						ELSE 0
					END
		GROUP BY 
			CASE 
				WHEN rpt.bettype IN (9,29) THEN 29
				WHEN rpt.bettype IN (10) THEN rpt.bettype
				ELSE rpt.matchid END
			, ISNULL(bt.GroupTypeId, rpt.bettype)
			, rpt.leagueid, rpt.matchcode
			, ISNULL(m.GlobalShowTime, 0)
			, rpt.homeid, rpt.awayid, rpt.isNeutral
		;
	END

	--TODO: rptMatchWinloss
	IF (@fromDateCheck BETWEEN @balanceUpDate AND @moveBetDate)
	BEGIN
		INSERT INTO #tmpReportData
		SELECT CASE 
				WHEN rpt.bettype IN (9,29) THEN 29
				WHEN rpt.bettype IN (10) THEN rpt.bettype
				ELSE rpt.matchid END AS matchid
			,ISNULL(bt.GroupTypeId, rpt.bettype) AS bettype
			,rpt.leagueid, rpt.matchcode, rpt.kickofftime, rpt.homeid, rpt.awayid, rpt.isNeutral
			,AVG((rpt.turnover * ex.Rate)/rpt.betCount)	AS stakeAvg
			,SUM(rpt.betCount)	AS betCount
			,SUM(rpt.turnover * ex.Rate)	AS turnover
			,SUM(rpt.netTurnover * ex.Rate)	AS netTurnover
			,SUM(rpt.grossComm * ex.Rate) AS grossComm

			----member
			,SUM(rpt.winlost * ex.Rate) AS memberWinloss
			,SUM(rpt.playercomm * ex.Rate) AS memberComm
			,SUM((rpt.winlost + rpt.playercomm) * ex.Rate) AS memberTotal
		
			----agent
			,SUM(rpt.awinlost * ex.Rate) AS agentWinloss
			,SUM((rpt.comm - rpt.playercomm) * ex.Rate) AS agentComm
			,SUM((rpt.awinlost + rpt.comm - rpt.playercomm) * ex.Rate) AS agentTotal

			----master
			,SUM(rpt.mwinlost * ex.Rate) AS masterWinloss
			,SUM((rpt.acomm - rpt.comm) * ex.Rate) AS masterComm
			,SUM((rpt.mwinlost + rpt.acomm - rpt.comm) * ex.Rate) AS masterTotal

			----super
			,SUM(rpt.netTurnover * ex.Rate) AS snetTurnover
			,SUM(rpt.swinlost * ex.Rate) AS superWinloss
			,SUM((rpt.scomm - rpt.acomm) * ex.Rate) AS superComm
			,SUM((rpt.swinlost + rpt.scomm - rpt.acomm) * ex.Rate) AS superTotal
		
			----company
			,SUM(rpt.scomm * ex.Rate) AS companyComm
		FROM bodb_Summary.dbo.rptMatchWinloss rpt WITH(NOLOCK)
			INNER JOIN #tmpSuperList sl ON sl.custID = rpt.custid
			INNER JOIN #tmpBettype bt ON bt.bettype = rpt.bettype
			LEFT JOIN @sportTypeList st ON st.SportType = rpt.sporttype AND st.LeagueGroupId = rpt.leaguegroupid
			LEFT JOIN #tmpLeague tl ON tl.leagueid = rpt.leagueid
			LEFT JOIN #tmpMatch tm ON tm.matchid = rpt.matchid
			LEFT JOIN #tmpExchangeRate tx  ON tx.currencyId = rpt.currency AND tx.ExchangeDate = rpt.winlostdate
			OUTER APPLY (
				SELECT 
					CASE 
						WHEN @BaseCurrency = @Currencies THEN 1
						ELSE ISNULL(tx.Rate, 1) END
			) AS ex(Rate)
		WHERE rpt.winlostdate = @fromDateCheck
			AND 1 = CASE 
						WHEN rpt.bettype IN (9,29) THEN 1
						WHEN st.sporttype > 0 AND tl.leagueid > 0 AND tm.matchid > 0 THEN 1
						ELSE 0
					END
		GROUP BY 
			CASE 
				WHEN rpt.bettype IN (9,29) THEN 29
				WHEN rpt.bettype IN (10) THEN rpt.bettype
				ELSE rpt.matchid END
			, ISNULL(bt.GroupTypeId, rpt.bettype)
			, rpt.leagueid, rpt.matchcode, rpt.kickofftime, rpt.homeid, rpt.awayid, rpt.isNeutral;

	END

	--TODO: rptMatchWinloss_old
	IF (@fromDateCheck < @balanceUpDate)
	BEGIN
		INSERT INTO #tmpReportData
		SELECT CASE 
				WHEN rpt.bettype IN (9,29) THEN 29
				WHEN rpt.bettype IN (10) THEN rpt.bettype
				ELSE rpt.matchid END AS matchid
			,ISNULL(bt.GroupTypeId, rpt.bettype) AS bettype
			,rpt.leagueid, rpt.matchcode, rpt.kickofftime, rpt.homeid, rpt.awayid, rpt.isNeutral
			,AVG((rpt.turnover * ex.Rate)/rpt.betCount)	AS stakeAvg
			,SUM(rpt.betCount)	AS betCount
			,SUM(rpt.turnover * ex.Rate)	AS turnover
			,SUM(rpt.netTurnover * ex.Rate)	AS netTurnover
			,SUM(rpt.grossComm * ex.Rate) AS grossComm

			----member
			,SUM(rpt.winlost * ex.Rate) AS memberWinloss
			,SUM(rpt.playercomm * ex.Rate) AS memberComm
			,SUM((rpt.winlost + rpt.playercomm) * ex.Rate) AS memberTotal
		
			----agent
			,SUM(rpt.awinlost * ex.Rate) AS agentWinloss
			,SUM((rpt.comm - rpt.playercomm) * ex.Rate) AS agentComm
			,SUM((rpt.awinlost + rpt.comm - rpt.playercomm) * ex.Rate) AS agentTotal

			----master
			,SUM(rpt.mwinlost * ex.Rate) AS masterWinloss
			,SUM((rpt.acomm - rpt.comm) * ex.Rate) AS masterComm
			,SUM((rpt.mwinlost + rpt.acomm - rpt.comm) * ex.Rate) AS masterTotal

			----super
			,SUM(rpt.netTurnover * ex.Rate) AS snetTurnover
			,SUM(rpt.swinlost * ex.Rate) AS superWinloss
			,SUM((rpt.scomm - rpt.acomm) * ex.Rate) AS superComm
			,SUM((rpt.swinlost + rpt.scomm - rpt.acomm) * ex.Rate) AS superTotal
		
			----company
			,SUM(rpt.scomm * ex.Rate) AS companyComm
		FROM bodb_Summary.dbo.rptMatchWinloss_old rpt WITH(NOLOCK)
			INNER JOIN #tmpSuperList sl ON sl.custID = rpt.custid
			INNER JOIN #tmpBettype bt ON bt.bettype = rpt.bettype
			LEFT JOIN @sportTypeList st ON st.SportType = rpt.sporttype AND st.leaguegroupid = rpt.leaguegroupid
			LEFT JOIN #tmpLeague tl ON tl.leagueid = rpt.leagueid
			LEFT JOIN #tmpMatch tm ON tm.matchid = rpt.matchid
			LEFT JOIN #tmpExchangeRate tx  ON tx.currencyId = rpt.currency AND tx.ExchangeDate = rpt.winlostdate
			OUTER APPLY (
				SELECT 
					CASE 
						WHEN @BaseCurrency = @Currencies THEN 1
						ELSE ISNULL(tx.Rate, 1) END
			) AS ex(Rate)
		WHERE rpt.winlostdate = @fromDateCheck
			AND 1 = CASE 
						WHEN rpt.bettype IN (9,29) THEN 1
						WHEN st.sporttype > 0 AND tl.leagueid > 0 AND tm.matchid > 0 THEN 1
						ELSE 0
					END
		GROUP BY 
			CASE 
				WHEN rpt.bettype IN (9,29) THEN 29
				WHEN rpt.bettype IN (10) THEN rpt.bettype
				ELSE rpt.matchid END
			, ISNULL(bt.GroupTypeId, rpt.bettype)
			, rpt.leagueid, rpt.matchcode, rpt.kickofftime, rpt.homeid, rpt.awayid, rpt.isNeutral;

	END

	-- SORTING: match Level 1
	DROP TABLE IF EXISTS #tmpPaging;
	CREATE TABLE #tmpPaging (matchid INT PRIMARY KEY, pIdx INT, TotalRows INT);

	DROP TABLE IF EXISTS #tmpSortValue;
	CREATE TABLE #tmpSortValue (matchid INT PRIMARY KEY, SortValue DECIMAL(24, 4));

	INSERT INTO #tmpSortValue
	SELECT matchid,
		CASE 
			WHEN @SortBy = 'betcount' THEN SUM(betcount)
			WHEN @SortBy = 'stakeAvg' THEN AVG(stakeAvg)
			WHEN @SortBy = 'turnover' THEN SUM(turnover)
			WHEN @SortBy = 'netTurnover' THEN SUM(netTurnover)
			WHEN @SortBy = 'grossComm' THEN SUM(grossComm)

			WHEN @SortBy = 'memberWinloss' THEN SUM(memberWinloss)
			WHEN @SortBy = 'memberComm' THEN SUM(memberComm)
			WHEN @SortBy = 'memberTotal' THEN SUM(memberTotal)

			WHEN @SortBy = 'agentWinloss' THEN SUM(agentWinloss)
			WHEN @SortBy = 'agentComm' THEN SUM(agentComm)
			WHEN @SortBy = 'agentTotal' THEN SUM(agentTotal)

			WHEN @SortBy = 'masterWinloss' THEN SUM(masterWinloss)
			WHEN @SortBy = 'masterComm' THEN SUM(masterComm)
			WHEN @SortBy = 'masterTotal' THEN SUM(masterTotal)

			WHEN @SortBy = 'superWinloss' THEN SUM(superWinloss)
			WHEN @SortBy = 'superComm' THEN SUM(superComm)
			WHEN @SortBy = 'superTotal' THEN SUM(superTotal)
			WHEN @SortBy = 'superMargin' THEN IIF(SUM(snetTurnover) = 0, 0, SUM(superTotal)*100/SUM(snetTurnover))

			WHEN @SortBy = 'companyComm' THEN SUM(companyComm)
			ELSE DATEDIFF(MINUTE, '2020-01-01', MAX(kickofftime)) 
		END AS SortValue
	FROM #tmpReportData rpt
	GROUP BY rpt.matchid;

	-- Paging match
	INSERT INTO #tmpPaging (matchid, pIdx, TotalRows)
	SELECT matchid
		,ROW_NUMBER() OVER (
			ORDER BY  
				CASE WHEN @SortType = 0 THEN sv.SortValue ELSE 0 END ASC,
				CASE WHEN @SortType = 1 THEN sv.SortValue ELSE 0 END DESC
		) AS pIdx
		, COUNT(1) OVER() AS TotalRows
	FROm #tmpSortValue sv
	WHERE sv.matchid NOT IN (9, 29, 10)
	ORDER BY pIdx
	OFFSET (@Page-1)*@PageSize ROWS FETCH NEXT @PageSize ROWS ONLY;
	
	--SET @TotalRow
	SELECT TOP(1) @TotalRows = TotalRows FROM #tmpPaging;
	
	-- Paging by match - level 1
	SELECT p.pIdx, rpt.matchid, leagueid, matchcode, kickofftime, homeid, awayid, isNeutral
		,AVG(stakeAvg)	AS stakeAvg
		,SUM(betCount)	AS betCount
		,SUM(turnover)	AS turnover
		,SUM(netTurnover)	AS netTurnover
		,SUM(grossComm) AS grossComm

		----member
		,SUM(memberWinloss) AS memberWinloss
		,SUM(memberComm) AS memberComm
		,SUM(memberTotal) AS memberTotal
		
		----agent
		,SUM(agentWinloss) AS agentWinloss
		,SUM(agentComm) AS agentComm
		,SUM(agentTotal) AS agentTotal

		----master
		,SUM(masterWinloss) AS masterWinloss
		,SUM(masterComm) AS masterComm
		,SUM(masterTotal) AS masterTotal

		----super
		--,SUM(snetTurnover) AS snetTurnover
		,SUM(superWinloss) AS superWinloss
		,SUM(superComm) AS superComm
		,SUM(superTotal) AS superTotal
		,IIF(SUM(snetTurnover)=0, 0, CONVERT(SMALLMONEY,SUM(superTotal)*100 / SUM(snetTurnover))) AS superMargin

		----company
		,SUM(companyComm) AS companyComm
	
	FROM #tmpReportData rpt
	INNER JOIN #tmpPaging p ON p.matchid = rpt.matchid
	GROUP BY p.pIdx, rpt.matchid,leagueid, matchcode, kickofftime, homeid, awayid, isNeutral
	ORDER BY p.pIdx ASC

	--Paging: match-bettype Level 2
	;WITH CTE_SortBettype AS (
		SELECT p.pIdx, p.matchid, rpt.bettype
			,CASE 
				WHEN @SortBy = 'betcount' THEN (betcount)
				WHEN @SortBy = 'stakeAvg' THEN (stakeAvg)
				WHEN @SortBy = 'turnover' THEN (turnover)
				WHEN @SortBy = 'netTurnover' THEN (netTurnover)
				WHEN @SortBy = 'grossComm' THEN (grossComm)

				WHEN @SortBy = 'memberWinloss' THEN (memberWinloss)
				WHEN @SortBy = 'memberComm' THEN (memberComm)
				WHEN @SortBy = 'memberTotal' THEN (memberTotal)

				WHEN @SortBy = 'agentWinloss' THEN (agentWinloss)
				WHEN @SortBy = 'agentComm' THEN (agentComm)
				WHEN @SortBy = 'agentTotal' THEN (agentTotal)

				WHEN @SortBy = 'masterWinloss' THEN (masterWinloss)
				WHEN @SortBy = 'masterComm' THEN (masterComm)
				WHEN @SortBy = 'masterTotal' THEN (masterTotal)

				WHEN @SortBy = 'superWinloss' THEN (superWinloss)
				WHEN @SortBy = 'superComm' THEN (superComm)
				WHEN @SortBy = 'superTotal' THEN (superTotal)
				WHEN @SortBy = 'superMargin' THEN IIF(snetTurnover = 0, 0, (superTotal*100/snetTurnover))

				WHEN @SortBy = 'companyComm' THEN (companyComm)
				ELSE (bettype)
			END AS Sortvalue
		FROM #tmpReportData rpt
		INNER JOIN #tmpPaging p ON p.matchid = rpt.matchid
	)
	SELECT sv.pIdx, sv.matchid
		,ROW_NUMBER() OVER (
			PARTITION BY sv.pIdx, sv.matchid 
			ORDER BY 
				CASE WHEN @SortBy <> 'kickofftime' AND @SortType = 0 THEN sv.SortValue ELSE 0 END ASC
				,CASE WHEN @SortBy <> 'kickofftime' AND @SortType = 1 THEN sv.SortValue ELSE 0 END DESC
				,CASE WHEN @SortBy = 'kickofftime' THEN sv.SortValue ELSE 0 END ASC
		) AS cIdx
		, sv.bettype
		,(stakeAvg) AS stakeAvg
		,(betCount)	AS betCount
		,(turnover)	AS turnover
		,(netTurnover)	AS netTurnover
		,(grossComm) AS grossComm

		----member
		,(memberWinloss) AS memberWinloss
		,(memberComm) AS memberComm
		,(memberTotal) AS memberTotal
		
		----agent
		,(agentWinloss) AS agentWinloss
		,(agentComm) AS agentComm
		,(agentTotal) AS agentTotal

		----master
		,(masterWinloss) AS masterWinloss
		,(masterComm) AS masterComm
		,(masterTotal) AS masterTotal

		----super
		--,(snetTurnover) AS snetTurnover
		,(superWinloss) AS superWinloss
		,(superComm) AS superComm
		,(superTotal) AS superTotal
		,IIF(snetTurnover=0, 0, CONVERT(SMALLMONEY,superTotal*100 / snetTurnover)) AS superMargin

		----company
		,(rpt.companyComm) AS companyComm
	
	FROM #tmpReportData rpt
	INNER JOIN CTE_SortBettype sv ON sv.matchid = rpt.matchid AND sv.bettype = rpt.bettype
	ORDER BY sv.pIdx, sv.matchid, cIdx
	;

	--Grant Sub Total
	SELECT 
		AVG(stakeAvg) AS stakeAvg
		,SUM(betCount) AS betCount
		,SUM(turnover) AS turnover
		,SUM(netTurnover) AS netTurnover
		,SUM(grossComm) AS grossComm
		
		----member
		,SUM(memberWinloss) AS memberWinloss
		,SUM(memberComm) AS memberComm
		,SUM(memberTotal) AS memberTotal
		
		----agent
		,SUM(agentWinloss) AS agentWinloss
		,SUM(agentComm) AS agentComm
		,SUM(agentTotal) AS agentTotal

		----master
		,SUM(masterWinloss) AS masterWinloss
		,SUM(masterComm) AS masterComm
		,SUM(masterTotal) AS masterTotal

		----super
		--,SUM(snetTurnover) AS snetTurnover
		,SUM(superWinloss) AS superWinloss
		,SUM(superComm) AS superComm
		,SUM(superTotal) AS superTotal
		,IIF(SUM(snetTurnover) =0, 0, CONVERT(SMALLMONEY,SUM(superTotal)*100 / SUM(snetTurnover))) AS superMargin

		----company
		,SUM(companyComm) AS companyComm
	FROM #tmpReportData rpt
	INNER JOIN #tmpPaging p ON p.matchid = rpt.matchid
	;

	--Parlay vs Outright
	SELECT 
		rpt.matchid AS bettype
		,(stakeAvg) AS stakeAvg
		,(betCount) AS betCount
		,(turnover) AS turnover
		,(netTurnover) AS netTurnover
		,(grossComm) AS grossComm
		
		----member
		,(memberWinloss) AS memberWinloss
		,(memberComm) AS memberComm
		,(memberTotal) AS memberTotal
		
		----agent
		,(agentWinloss) AS agentWinloss
		,(agentComm) AS agentComm
		,(agentTotal) AS agentTotal

		----master
		,(masterWinloss) AS masterWinloss
		,(masterComm) AS masterComm
		,(masterTotal) AS masterTotal

		----super
		--,(snetTurnover) snetTurnover
		,(superWinloss) AS superWinloss
		,(superComm) AS superComm
		,(superTotal) AS superTotal
		,IIF(snetTurnover = 0, 0, CONVERT(SMALLMONEY, (superTotal*100/snetTurnover))) AS superMargin

		----company
		,(companyComm) AS companyComm
	FROM #tmpReportData rpt
	INNER JOIN #tmpSortValue sv ON sv.matchid = rpt.matchid
	WHERE rpt.matchid IN (29, 10)
	ORDER BY 
		CASE WHEN @SortType = 0 THEN sv.SortValue ELSE 0 END ASC,
		CASE WHEN @SortType = 1 THEN sv.SortValue ELSE 0 END DESC

	--Grant Total
	SELECT 
		AVG(stakeAvg) AS stakeAvg
		,SUM(betCount) AS betCount
		,SUM(turnover) AS turnover
		,SUM(netTurnover) AS netTurnover
		,SUM(grossComm) AS grossComm
		
		----member
		,SUM(memberWinloss) AS memberWinloss
		,SUM(memberComm) AS memberComm
		,SUM(memberTotal) AS memberTotal
		
		----agent
		,SUM(agentWinloss) AS agentWinloss
		,SUM(agentComm) AS agentComm
		,SUM(agentTotal) AS agentTotal

		----master
		,SUM(masterWinloss) AS masterWinloss
		,SUM(masterComm) AS masterComm
		,SUM(masterTotal) AS masterTotal

		----super
		--,SUM(snetTurnover) AS snetTurnover
		,SUM(superWinloss) AS superWinloss
		,SUM(superComm) AS superComm
		,SUM(superTotal) AS superTotal
		,IIF(SUM(snetTurnover) =0, 0, CONVERT(SMALLMONEY,SUM(superTotal)*100 / SUM(snetTurnover))) AS superMargin

		----company
		,SUM(companyComm) AS companyComm
	FROM #tmpReportData

END
GO

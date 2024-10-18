/*<info serverAlias="DBAGE-bodb02" executers="wsv_xnap" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[EAS_MatchWinloss_Summary] 	
	@GroupName		VARCHAR(50),
	@FromDate		SMALLDATETIME,
	@ToDate			SMALLDATETIME,
	@SportType		SMALLINT,
	@LeagueIds		VARCHAR(1000)	= '',
	@Currencies		VARCHAR(1000)	= '',
	@BaseCurrency	VARCHAR(5)		= '',
	@SortBy			VARCHAR(30)		= 'kickofftime',
	@SortType		TINYINT = 0,
	@Page			INT = 1,
	@PageSize		INT = 500,
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
		@toDateCheck		SMALLDATETIME,
		@moveBetDate		SMALLDATETIME,
		@balanceUpDate		SMALLDATETIME,
		@baseCurrencyId		INT;

	SELECT @fromDateCheck	= CAST(ISNULL(@FromDate, GETDATE()) AS DATE),
		@toDateCheck		= CASt(ISNULL(@ToDate, GETDATE()) AS DATE),
		@Currencies			= ISNULL(@Currencies, ''),
		@BaseCurrency		= ISNULL(@BaseCurrency, '')
	;

	DROP TABLE IF EXISTS #tmpLeague;
	DROP TABLE IF EXISTS #tmpReportData;
	DROP TABLE IF EXISTS #tmpSuperList;
	DROP TABLE IF EXISTS #tmpExchangeRate;

	CREATE TABLE #tmpSuperList(custID INT PRIMARY KEY, Currency INT)
	CREATE TABLE #tmpLeague(leagueid INT, SportType INT, LeagueGroupId INT, SabaGroupType INT, PRIMARY KEY (leagueid, SportType, LeagueGroupId));
	CREATE TABLE #tmpReportData (
		matchid INT 
		,leagueid INT
		,matchcode NVARCHAR(50)
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
		,superWinloss DECIMAL(24, 4)
		,superComm DECIMAL(24, 4)
		,superTotal DECIMAL(24, 4)

		----company
		,companyTotal DECIMAL(24, 4)
	);
	CREATE CLUSTERED INDEX CIX_matchid ON #tmpReportData(matchid);

	CREATE TABLE #tmpExchangeRate(CurrencyId INT, ExchangeDate SMALLDATETIME, Rate MONEY);

	--TODO Saba's sports if any
	DECLARE @sportTypeList TABLE(SportType INT, LeagueGroupId INT, SabaGroupType INT);
	IF @SportType > 0
	BEGIN
		INSERT INTO @sportTypeList(SportType, LeagueGroupId, SabaGroupType)
		VALUES (@SportType, 0, 0)
	END
	ELSE 
	BEGIN 
		INSERT INTO @sportTypeList(SportType, LeagueGroupId, SabaGroupType)
		SELECT Sporttype, LeagueGroupID, SabaGroupType
		FROM [dbo].[EAS_f_SabaSportSel] () AS saba
	END

	----TODO: Headline
	INSERT INTO #tmpSuperList
	SELECT DISTINCT cg.custID, c.currency
	FROM dbo.Acc_CustGroup cg WITH(NOLOCK)
	INNER JOIN dbo.Customer c WITH(NOLOCK) ON c.custid = cg.CustID
	WHERE GroupName = @GroupName
	;

	--TODO: @LeaguaIds filetring
	INSERT INTO #tmpLeague (leagueid, SportType, LeagueGroupId, SabaGroupType)
	SELECT lt.leagueid, sl.SportType, sl.LeagueGroupId, sl.SabaGroupType
	FROM @sportTypeList sl
	OUTER APPLY (
		SELECT DISTINCT CAST(value  AS INT) AS leagueid
		FROM STRING_SPLIT(@LeagueIds, ',')
	) AS lt
	;
	
	--TODO: Filter by Currency if ANY
	IF @Currencies <> ''
	BEGIN
		DELETE sl
		FROM #tmpSuperList sl
		INNER JOIN dbo.Exchange ex WITH(NOLOCK) ON ex.ExchangeId = sl.Currency
		LEFT JOIN STRING_SPLIT(@Currencies, ',') cl ON cl.[value] = ex.Currency
		WHERE cl.[value] IS NULL
	END

	--TODO: Exchange rate
	IF @BaseCurrency <> ''
	BEGIN
		INSERT INTO #tmpExchangeRate(CurrencyId, ExchangeDate, Rate)
		SELECT CurrencyId, ExchangeDate, Rate
		FROM dbo.EAS_f_GetDailyExchangeRate (@fromDateCheck, @toDateCheck, @GroupName, @BaseCurrency);
	END

	--TODO: get BU/MB days
	EXEC dbo.NAP_Admin_GetMovebetDate @MovebetDate = @moveBetDate OUTPUT
	EXEC dbo.NAP_Admin_GetBalanceUpDate @BalanceUpDate = @balanceUpDate OUTPUT

	--TODO: FETCH data
	IF @ToDate > @moveBetDate
	BEGIN
		--RESET: @fromDateCheck
		SELECT @fromDateCheck = IIF(@fromDate < @moveBetDate, DATEADD(DAY, 1, @moveBetDate), @fromDate)
				,@toDateCheck = @ToDate

		INSERT INTO #tmpReportData
		SELECT 
			CASE 
				WHEN rpt.bettype IN (9,29) THEN 29
				WHEN rpt.bettype IN (10) THEN rpt.bettype
				WHEN rpt.ChildMatchType = 200 THEN rpt.parentid
				ELSE rpt.matchid END AS matchid
			,rpt.leagueid
			,rpt.matchcode
			,ISNULL(DATEADD(HOUR, 12, m.kickofftime), 0) AS kickofftime ---> admin can change KO time any time
			,rpt.homeid, rpt.awayid, rpt.isNeutral
			,SUM(rpt.turnover * ex.Rate)/SUM(rpt.betCount)	AS stakeAvg
			,SUM(rpt.betCount)	AS betCount
			,SUM(rpt.turnover * ex.Rate)	AS turnover
			,SUM(rpt.turnoverNoDraw * ex.Rate)	AS netTurnover
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
			,SUM(rpt.swinlost * ex.Rate) AS superWinloss
			,SUM((rpt.scomm - rpt.acomm) * ex.Rate) AS superComm
			,SUM((rpt.swinlost + rpt.scomm - rpt.acomm) * ex.Rate) AS superTotal
		
			----company
			,-SUM((rpt.swinlost+rpt.mwinlost+rpt.awinlost+rpt.winlost+rpt.scomm) * ex.Rate) AS companyTotal
	
		FROM bodb_Summary.dbo.rptMatchWinloss_compact rpt WITH(NOLOCK)
			INNER JOIN #tmpSuperList sl ON sl.custID = rpt.custid
			LEFT JOIN #tmpLeague tl ON tl.leagueid = rpt.leagueid AND tl.SportType = rpt.sporttype AND tl.LeagueGroupId = rpt.leaguegroupid
			LEFT JOIN dbo.[match] m WITH(NOLOCK) ON m.matchid = rpt.matchid
			LEFT JOIN dbo.[outright] o WITH(NOLOCK) ON o.orid = rpt.matchid
			LEFT JOIN #tmpExchangeRate tx  ON tx.currencyId = rpt.currency AND tx.ExchangeDate = rpt.winlostdate
			OUTER APPLY (
				SELECT 
					CASE 
						WHEN @BaseCurrency = @Currencies THEN 1
						ELSE ISNULL(tx.Rate, 1) END
			) AS ex(Rate)
		WHERE 
			rpt.winlostdate BETWEEN @fromDateCheck AND @toDateCheck
			AND NOT (rpt.bettype NOT IN (10, 29) AND (m.eventstatus <> 'Completed'))
			AND NOT (rpt.bettype = 10 AND (o.oddsstatus <> 'Completed')) 
			AND 1 = CASE
						WHEN rpt.bettype IN (9,29) THEN 1
						WHEN @SportType > 0	AND tl.SportType > 0 THEN 1 --normal sports
						WHEN @SportType < 0	AND tl.SabaGroupType = @SportType AND tl.SportType > 0 THEN 1 --Saba sports
						ELSE 0
					END
		GROUP BY 
			CASE 
				WHEN rpt.bettype IN (9,29) THEN 29
				WHEN rpt.bettype IN (10) THEN rpt.bettype
				WHEN rpt.ChildMatchType = 200 THEN rpt.parentid
				ELSE rpt.matchid END
			, rpt.leagueid
			, rpt.matchcode, ISNULL(DATEADD(HOUR, 12, m.kickofftime), 0), rpt.homeid, rpt.awayid, rpt.isNeutral;
	END

	IF @FromDate <= @moveBetDate
	BEGIN
		--RESET: @fromDateCheck
		SELECT @fromDateCheck	= IIF(@FromDate < @balanceUpdate, @balanceUpdate, @FromDate)
			,@toDateCheck		= IIF(@ToDate > @moveBetDate, @moveBetDate, @ToDate)

		INSERT INTO #tmpReportData
		SELECT 
			CASE 
				WHEN rpt.bettype IN (9,29) THEN 29
				WHEN rpt.bettype IN (10) THEN rpt.bettype
				WHEN rpt.ChildMatchType = 200 THEN rpt.parentid
				ELSE rpt.matchid END AS matchid
			,rpt.leagueid
			,rpt.matchcode, DATEADD(HOUR, 12, rpt.kickofftime) AS kickofftime, rpt.homeid, rpt.awayid, rpt.isNeutral
			,SUM(rpt.turnover * ex.Rate)/SUM(rpt.betCount)	AS stakeAvg
			,SUM(rpt.betCount)	AS betCount
			,SUM(rpt.turnover * ex.Rate)	AS turnover
			,SUM(rpt.turnoverNoDraw * ex.Rate)	AS netTurnover
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
			,SUM(rpt.swinlost * ex.Rate) AS superWinloss
			,SUM((rpt.scomm - rpt.acomm) * ex.Rate) AS superComm
			,SUM((rpt.swinlost + rpt.scomm - rpt.acomm) * ex.Rate) AS superTotal
		
			----company
			,-SUM((rpt.swinlost+rpt.mwinlost+rpt.awinlost+rpt.winlost+rpt.scomm) * ex.Rate) AS companyTotal
	
		FROM bodb_Summary.dbo.rptMatchWinloss rpt WITH(NOLOCK)
			INNER JOIN #tmpSuperList sl ON sl.custID = rpt.custid
			LEFT JOIN #tmpLeague tl ON tl.leagueid = rpt.leagueid AND tl.SportType = rpt.sporttype AND tl.LeagueGroupId = rpt.leaguegroupid
			LEFT JOIN #tmpExchangeRate tx  ON tx.currencyId = rpt.currency AND tx.ExchangeDate = rpt.winlostdate
			OUTER APPLY (
				SELECT 
					CASE 
						WHEN @BaseCurrency = @Currencies THEN 1
						ELSE ISNULL(tx.Rate, 1) END
			) AS ex(Rate)
		WHERE 
			rpt.winlostdate BETWEEN @fromDateCheck AND @toDateCheck
			AND 1 = CASE 
						WHEN rpt.bettype IN (9,29) THEN 1
						WHEN @SportType > 0	AND tl.SportType > 0 THEN 1 --normal sports
						WHEN @SportType < 0	AND tl.SabaGroupType = @SportType AND tl.SportType > 0 THEN 1 --Saba sports
						ELSE 0
					END
		GROUP BY 
			CASE 
				WHEN rpt.bettype IN (9,29) THEN 29
				WHEN rpt.bettype IN (10) THEN rpt.bettype
				WHEN rpt.ChildMatchType = 200 THEN rpt.parentid
				ELSE rpt.matchid END
			, rpt.leagueid
			, rpt.matchcode, DATEADD(HOUR, 12, rpt.kickofftime), rpt.homeid, rpt.awayid, rpt.isNeutral;
	END

	--TODO: rptMatchWinloss_old
	IF (@FromDate < @balanceUpDate)
	BEGIN
		--RESET: @toDateCheck
		SELECT @fromDateCheck = @FromDate
				,@toDateCheck = IIF(@ToDate >= @balanceUpDate, DATEADD(DAY, -1, @balanceUpDate), @ToDate)

		INSERT INTO #tmpReportData
		SELECT 
			CASE 
				WHEN rpt.bettype IN (9,29) THEN 29
				WHEN rpt.bettype IN (10) THEN rpt.bettype
				WHEN rpt.ChildMatchType = 200 THEN rpt.parentid
				ELSE rpt.matchid END AS matchid
			,rpt.leagueid
			,rpt.matchcode, DATEADD(HOUR, 12, rpt.kickofftime) AS kickofftime, rpt.homeid, rpt.awayid, rpt.isNeutral
			,SUM(rpt.turnover * ex.Rate)/SUM(rpt.betCount)	AS stakeAvg
			,SUM(rpt.betCount)	AS betCount
			,SUM(rpt.turnover * ex.Rate)	AS turnover
			,SUM(rpt.turnoverNoDraw * ex.Rate)	AS netTurnover
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
			,SUM(rpt.swinlost * ex.Rate) AS superWinloss
			,SUM((rpt.scomm - rpt.acomm) * ex.Rate) AS superComm
			,SUM((rpt.swinlost + rpt.scomm - rpt.acomm) * ex.Rate) AS superTotal
		
			----company
			,-SUM((rpt.swinlost+rpt.mwinlost+rpt.awinlost+rpt.winlost+rpt.scomm) * ex.Rate) AS companyTotal
	
		FROM bodb_Summary.dbo.rptMatchWinloss_old rpt WITH(NOLOCK)
			INNER JOIN #tmpSuperList sl ON sl.custID = rpt.custid
			LEFT JOIN #tmpLeague tl ON tl.leagueid = rpt.leagueid AND tl.SportType = rpt.sporttype AND tl.LeagueGroupId = rpt.leaguegroupid
			LEFT JOIN #tmpExchangeRate tx  ON tx.currencyId = rpt.currency AND tx.ExchangeDate = rpt.winlostdate
			OUTER APPLY (
				SELECT 
					CASE 
						WHEN @BaseCurrency = @Currencies THEN 1
						ELSE ISNULL(tx.Rate, 1) END
			) AS ex(Rate)
		WHERE 
			rpt.winlostdate BETWEEN @fromDateCheck AND @toDateCheck
			AND 1 = CASE
						WHEN rpt.bettype IN (9,29) THEN 1
						WHEN @SportType > 0	AND tl.SportType > 0 THEN 1 --normal sports
						WHEN @SportType < 0	AND tl.SabaGroupType = @SportType AND tl.SportType > 0 THEN 1 --Saba sports
						ELSE 0
					END
		GROUP BY 
			CASE 
				WHEN rpt.bettype IN (9,29) THEN 29
				WHEN rpt.bettype IN (10) THEN rpt.bettype
				WHEN rpt.ChildMatchType = 200 THEN rpt.parentid
				ELSE rpt.matchid END
			, rpt.leagueid
			, rpt.matchcode, DATEADD(HOUR, 12, rpt.kickofftime), rpt.homeid, rpt.awayid, rpt.isNeutral;
	END

	-- TODO: Sorting all columns
	DROP TABLE IF EXISTS #tmpSortValue;
	CREATE TABLE #tmpSortValue (matchid INT, SortValue DECIMAL(24, 4));

	INSERT INTO #tmpSortValue
	SELECT matchid,
		(CASE 
			WHEN @SortBy = 'betcount' THEN SUM(betcount)
			WHEN @SortBy = 'stakeAvg' THEN SUM(stakeAvg)
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
			WHEN @SortBy = 'memberMargin' THEN IIF(SUM(netTurnover)=0, 0, (SUM(memberTotal)*100/SUM(netTurnover)))

			WHEN @SortBy = 'companyTotal' THEN SUM(companyTotal)
			ELSE DATEDIFF(MINUTE, '2020-01-01', MAX(rpt.kickofftime)) END --KO time
		) AS SortValue
	FROM #tmpReportData rpt
	GROUP BY matchid


	-- TODO: paging match
	DROP TABLE IF EXISTS #tmpPaging;
	CREATE TABLE #tmpPaging (matchid INT, pIdx INT, TotalRows INT);

	INSERT INTO #tmpPaging
	SELECT matchid
		,ROW_NUMBER() OVER (
			ORDER BY  
				CASE WHEN @SortType = 0 THEN SortValue ELSE 0 END ASC,
				CASE WHEN @SortType = 1 THEN SortValue ELSE 0 END DESC
		) AS pIdx
		, COUNT(1) OVER() AS TotalRows
	FROm #tmpSortValue sv
	WHERE matchid NOT IN (9, 29, 10)
	ORDER BY pIdx
	OFFSET (@Page-1)*@PageSize ROWS FETCH NEXT @PageSize ROWS ONLY;
	
	--SET @TotalRowss
	SELECT TOP(1) @TotalRows = TotalRows FROM #tmpPaging;

	--FETCH rows
	SELECT p.pIdx, leagueid, p.matchid, matchcode, kickofftime, homeid, awayid, isNeutral
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
		,(superWinloss) AS superWinloss
		,(superComm) AS superComm
		,(superTotal) AS superTotal
		,IIF(netTurnover = 0, 0, CONVERT(SMALLMONEY, (memberTotal*100/netTurnover))) AS memberMargin

		----company
		,(companyTotal) AS companyTotal
	FROM #tmpReportData rpt
	INNER JOIN #tmpPaging p ON p.matchid = rpt.matchid
	ORDER BY p.pIdx ASC


	--Sum Total of matches
	SELECT 
		SUM(turnover)/SUM(betCount) AS stakeAvg
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
		,SUM(superWinloss) AS superWinloss
		,SUM(superComm) AS superComm
		,SUM(superTotal) AS superTotal
		,IIF(SUM(netTurnover) = 0, 0, CONVERT(SMALLMONEY, SUM(memberTotal)*100/SUM(netTurnover))) AS memberMargin

		----company
		,SUM(companyTotal) AS companyTotal
	FROM #tmpReportData rpt
	INNER JOIN #tmpPaging p ON p.matchid = rpt.matchid

	--Parlay vs Outright
	SELECT 
		rpt.matchid  AS bettype
		,SUM(turnover)/SUM(betCount) AS stakeAvg
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
		,SUM(superWinloss) AS superWinloss
		,SUM(superComm) AS superComm
		,SUM(superTotal) AS superTotal
		,IIF(SUM(netTurnover) = 0, 0, CONVERT(SMALLMONEY, (SUM(memberTotal)*100/SUM(netTurnover)))) AS memberMargin

		----company
		,SUM(companyTotal) AS companyTotal
	FROM #tmpReportData rpt
	INNER JOIN #tmpSortValue s ON s.matchid = rpt.matchid
	WHERE rpt.matchid IN (29, 10)
	GROUP BY rpt.matchid, s.SortValue
	ORDER BY 
		CASE WHEN @SortType = 0 THEN s.SortValue ELSE 0 END ASC,
		CASE WHEN @SortType = 1 THEN s.SortValue ELSE 0 END DESC

	--Sum Total
	SELECT 
		SUM(turnover)/SUM(betCount) AS stakeAvg
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
		,SUM(superWinloss) AS superWinloss
		,SUM(superComm) AS superComm
		,SUM(superTotal) AS superTotal
		,IIF(SUM(netTurnover) =0, 0, CONVERT(SMALLMONEY,SUM(memberTotal)*100 / SUM(netTurnover))) AS memberMargin

		----company
		,SUM(companyTotal) AS companyTotal
	FROM #tmpReportData

END
GO

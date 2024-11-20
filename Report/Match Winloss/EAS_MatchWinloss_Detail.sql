/*<info serverAlias="DBAGE-bodb02" executers="wsv_xnap" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[EAS_MatchWinloss_Detail]
	@GroupName		VARCHAR(50),
	@FromDate		SMALLDATETIME,
	@SportType		SMALLINT,
	@LeagueIds		VARCHAR(MAX)	= '',
	@MatchIds		VARCHAR(MAX)	= '',
	@BetTypes		VARCHAR(MAX)	= '',
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
	CREATE TABLE #tmpLeague(leagueid INT, SportType INT, LeagueGroupId INT, SabaGroupType INT, PRIMARY KEY (leagueid, SportType, LeagueGroupId));
	CREATE TABLE #tmpMatch(matchid INT PRIMARY KEY);
	CREATE TABLE #tmpBettype(bettype INT PRIMARY KEY, GroupTypeId INT);
	CREATE TABLE #tmpReportData (
		matchid INT
		,isParent BIT
		,bettype INT 
		,leagueid INT
		,matchcode VARCHAR(50)
		,kickofftime DATETIME
		,homeid INT
		,awayid INT
		,isNeutral BIT
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
	CREATE CLUSTERED INDEX CIX_matchid ON #tmpReportData(matchid, bettype);

	CREATE TABLE #tmpExchangeRate(CurrencyId INT, ExchangeDate SMALLDATETIME, Rate FLOAT);

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
		LEFT JOIN STRING_SPLIT(@Currencies, ',') cl ON cl.[value] = ex.Currency --currency name
		WHERE cl.[value] IS NULL
	END

	--TODO: @LeaguaIds filetring
	INSERT INTO #tmpLeague (leagueid, SportType, LeagueGroupId, SabaGroupType)
	SELECT lt.leagueid, sl.SportType, sl.LeagueGroupId, sl.SabaGroupType
	FROM @sportTypeList sl
	OUTER APPLY (
		SELECT DISTINCT CAST(value  AS INT) AS leagueid
		FROM STRING_SPLIT(@LeagueIds, ',')
	) AS lt
	;

	--TODO: @MatchIds filetring
	INSERT INTO #tmpMatch (matchid)
	SELECT DISTINCT value FROM STRING_SPLIT(@MatchIds, ',');

	--TODO: @Bettypes filetring
	DECLARE @isTest BIT = 0
	SELECT  @isTest = dbo.f_CheckSPVersion(@@PROCID);

	INSERT INTO #tmpBettype (bettype, GroupTypeId)
	SELECT ISNULL(bg.bettype, t.bettype) AS bettype
		,ISNULL(bg.GroupTypeId, bt.typeid)
	FROM (
		SELECT DISTINCT CAST([value] AS INT) AS bettype
		FROM STRING_SPLIT(@Bettypes, ',')
	) AS t
	INNER JOIN dbo.Bettype bt WITH (NOLOCK)	ON bt.typeid = t.bettype
	LEFT JOIN dbo.f_GroupBettype() bg ON bg.GroupTypeId = t.bettype
	;

	--TODO: Other bettypes
	IF (CONCAT(',',@Bettypes, ',') LIKE '%,9999,%')
	BEGIN
		WITH CTE_OtherBettype AS (
			SELECT DISTINCT 
				bt.typeid
			FROM dbo.SportBettypeMatrix sb WITH (NOLOCK)
				INNER JOIN dbo.Products p WITH (NOLOCK)	ON p.ProductID = sb.ProductID
				INNER JOIN dbo.Bettype bt WITH (NOLOCK)	ON bt.typeid = sb.bettype
				LEFT JOIN (
					SELECT ISNULL(bg.bettype, t.TypeId) AS TypeId
					FROM [dbo].[EAS_f_MatchWinloss_BettypeSel] () t 
					LEFT JOIN dbo.f_GroupBettype() bg ON bg.GroupTypeId = t.TypeId

				) AS cte ON cte.TypeId = bt.typeid
				LEFT JOIN #tmpBettype tmp ON tmp.bettype = bt.typeid
			WHERE p.ProductID = 1
				AND sb.IsTest <= @isTest
				AND cte.typeid IS NULL
				AND tmp.bettype IS NULL
		)
		INSERT INTO #tmpBettype (bettype, GroupTypeId)
		SELECT typeid, 9999 AS GroupTypeId --Other group bettype
		FROM CTE_OtherBettype 
	END

	--TODO: Exchange rate
	IF @BaseCurrency <> ''
	BEGIN
		INSERT INTO #tmpExchangeRate(CurrencyId, ExchangeDate, Rate)
		SELECT CurrencyId, ExchangeDate, Rate
		FROM dbo.EAS_f_GetDailyExchangeRate (@fromDateCheck, @fromDateCheck, @GroupName, @BaseCurrency)
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
				WHEN rpt.ChildMatchType = 200 THEN rpt.parentid
				ELSE rpt.matchid END AS matchid
			,IIF(rpt.parentid > 0, 0, 1) isParent
			,bt.GroupTypeId AS bettype
			,rpt.leagueid
			,IIF(rpt.bettype NOT IN (9,29,10), m.matchcode, rpt.matchcode) AS matchcode ---> admin change matchcode any time
			,ISNULL(DATEADD(HOUR, 12, m.kickofftime), 0) AS kickofftime ---> admin change KO time any time
			,rpt.homeid, rpt.awayid, rpt.isNeutral
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
			INNER JOIN #tmpBettype bt ON bt.bettype = rpt.bettype
			LEFT JOIN #tmpLeague tl ON tl.leagueid = rpt.leagueid AND tl.SportType = rpt.sporttype AND tl.LeagueGroupId = rpt.LeagueGroupId
			LEFT JOIN dbo.[match] m WITH(NOLOCK) ON m.matchid = rpt.matchid
			LEFT JOIN #tmpMatch tm ON tm.matchid = IIF(m.ChildMatchType = 200, m.parentId, m.matchid)
			LEFT JOIN dbo.[outright] o WITH(NOLOCK) ON o.orid = rpt.matchid
			LEFT JOIN #tmpExchangeRate tx  ON tx.currencyId = rpt.currency AND tx.ExchangeDate = rpt.winlostdate
			OUTER APPLY (
				SELECT 
					CASE 
						WHEN @BaseCurrency = @Currencies THEN 1
						ELSE ISNULL(tx.Rate, 1) END
			) AS ex(Rate)
		WHERE rpt.winlostdate = @fromDateCheck
			AND 1 = CASE 
						WHEN rpt.bettype IN(9,29) THEN 1
						WHEN o.orid > 0 AND o.oddsstatus = 'Completed' THEN 1
						WHEN tm.matchid > 0 AND m.eventstatus = 'Completed' THEN 1
					ELSE 0 END
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
			, IIF(rpt.parentid > 0, 0, 1)
			, bt.GroupTypeId
			, rpt.leagueid
			, IIF(rpt.bettype NOT IN (9,29,10), m.matchcode, rpt.matchcode)
			, ISNULL(DATEADD(HOUR, 12, m.kickofftime), 0)
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
				WHEN rpt.ChildMatchType = 200 THEN rpt.parentid
				ELSE rpt.matchid END AS matchid
			,IIF(rpt.parentid > 0, 0, 1) isParent
			,bt.GroupTypeId AS bettype
			,rpt.leagueid, rpt.matchcode, DATEADD(HOUR, 12, rpt.kickofftime) AS kickofftime, rpt.homeid, rpt.awayid, rpt.isNeutral
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
			INNER JOIN #tmpBettype bt ON bt.bettype = rpt.bettype
			LEFT JOIN #tmpLeague tl ON tl.leagueid = rpt.leagueid AND tl.SportType = rpt.sporttype AND tl.LeagueGroupId = rpt.LeagueGroupId
			LEFT JOIN #tmpMatch tm ON tm.matchid = IIF(rpt.ChildMatchType = 200, rpt.parentId, rpt.matchid)
			LEFT JOIN #tmpExchangeRate tx  ON tx.currencyId = rpt.currency AND tx.ExchangeDate = rpt.winlostdate
			OUTER APPLY (
				SELECT 
					CASE 
						WHEN @BaseCurrency = @Currencies THEN 1
						ELSE ISNULL(tx.Rate, 1) END
			) AS ex(Rate)
		WHERE rpt.winlostdate = @fromDateCheck
			AND 1 = CASE 
						WHEN rpt.bettype IN(10,9,29) THEN 1
						WHEN tm.matchid > 0 THEN 1
					ELSE 0 END
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
			, IIF(rpt.parentid > 0, 0, 1)
			, bt.GroupTypeId
			, rpt.leagueid, rpt.matchcode, DATEADD(HOUR, 12, rpt.kickofftime), rpt.homeid, rpt.awayid, rpt.isNeutral;

	END

	--TODO: rptMatchWinloss_old
	IF (@fromDateCheck < @balanceUpDate)
	BEGIN
		INSERT INTO #tmpReportData
		SELECT CASE 
				WHEN rpt.bettype IN (9,29) THEN 29
				WHEN rpt.bettype IN (10) THEN rpt.bettype
				WHEN rpt.ChildMatchType = 200 THEN rpt.parentid
				ELSE rpt.matchid END AS matchid
			,IIF(rpt.parentid > 0, 0, 1) isParent
			,bt.GroupTypeId AS bettype
			,rpt.leagueid, rpt.matchcode, DATEADD(HOUR, 12, rpt.kickofftime) AS kickofftime, rpt.homeid, rpt.awayid, rpt.isNeutral
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
			INNER JOIN #tmpBettype bt ON bt.bettype = rpt.bettype
			LEFT JOIN #tmpLeague tl ON tl.leagueid = rpt.leagueid AND tl.SportType = rpt.sporttype AND tl.LeagueGroupId = rpt.LeagueGroupId
			LEFT JOIN #tmpMatch tm ON tm.matchid = IIF(rpt.ChildMatchType = 200, rpt.parentId, rpt.matchid)
			LEFT JOIN #tmpExchangeRate tx  ON tx.currencyId = rpt.currency AND tx.ExchangeDate = rpt.winlostdate
			OUTER APPLY (
				SELECT 
					CASE 
						WHEN @BaseCurrency = @Currencies THEN 1
						ELSE ISNULL(tx.Rate, 1) END
			) AS ex(Rate)
		WHERE rpt.winlostdate = @fromDateCheck
			AND 1 = CASE 
						WHEN rpt.bettype IN(10,9,29) THEN 1
						WHEN tm.matchid > 0 THEN 1
					ELSE 0 END
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
			, IIF(rpt.parentid > 0, 0, 1)
			, bt.GroupTypeId
			, rpt.leagueid, rpt.matchcode, DATEADD(HOUR, 12, rpt.kickofftime), rpt.homeid, rpt.awayid, rpt.isNeutral;

	END

	--TODO: Check/Update parent/child info
	IF EXISTS (
		SELECT 1 FROM #tmpReportData 
		GROUP BY matchid 
		HAVING (COUNT(matchcode) > 1 OR COUNT(kickofftime) > 1)
	)
	BEGIN
		WITH CTE_MatchDiff AS (
			SELECT matchid
			FROM #tmpReportData 
			GROUP BY matchid 
			HAVING (COUNT(matchcode) > 1 OR COUNT(kickofftime) > 1)
		), 
		CTE_MatchParent AS (
			SELECT matchid, matchcode, kickofftime
			FROM (
				SELECT mi.matchid, matchcode, kickofftime
					,ROW_NUMBER() OVER (PARTITION BY mi.matchid ORDER BY kickofftime) AS rIdx
				FROM #tmpReportData rpt WITH(NOLOCK)
				INNER JOIN CTE_MatchDiff mi ON mi.matchid = rpt.matchid
				WHERE rpt.IsParent = 1
			) AS m
			WHERE m.rIdx = 1
		)
		UPDATE rpt
		SET rpt.matchcode = mp.matchcode, rpt.kickofftime = mp.kickofftime
		FROM #tmpReportData rpt
		INNER JOIN CTE_MatchParent mp ON mp.matchid = rpt.matchid
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
			WHEN @SortBy = 'stakeAvg' THEN SUM(turnover)/SUM(betcount)
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
			WHEN @SortBy = 'memberMargin' THEN IIF(SUM(netTurnover) = 0, 0, SUM(memberTotal)*100/SUM(netTurnover))

			WHEN @SortBy = 'companyTotal' THEN SUM(companyTotal)
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
	SELECT p.pIdx, rpt.matchid, rpt.leagueid, rpt.homeid, rpt.awayid, rpt.isNeutral
		,rpt.matchcode, rpt.kickofftime
		,SUM(turnover)/SUM(betCount) AS stakeAvg
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
		,SUM(superWinloss) AS superWinloss
		,SUM(superComm) AS superComm
		,SUM(superTotal) AS superTotal
		,IIF(SUM(netTurnover)=0, 0, CONVERT(SMALLMONEY,SUM(memberTotal)*100 / SUM(netTurnover))) AS memberMargin

		----company
		,SUM(companyTotal) AS companyTotal
	
	FROM #tmpReportData rpt
		INNER JOIN #tmpPaging p ON p.matchid = rpt.matchid
	GROUP BY p.pIdx, rpt.matchid,rpt.leagueid,rpt.homeid,rpt.awayid,rpt.isNeutral
		, rpt.matchcode, rpt.kickofftime
	ORDER BY p.pIdx ASC

	--Paging: match-bettype Level 2
	;WITH CTE_SortBettype AS (
		SELECT p.pIdx, p.matchid, rpt.bettype
			,CASE 
				WHEN @SortBy = 'betcount' THEN SUM(betcount)
				WHEN @SortBy = 'stakeAvg' THEN SUM(turnover)/SUM(betcount)
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
				WHEN @SortBy = 'memberMargin' THEN IIF(SUM(netTurnover) = 0, 0, SUM(memberTotal)*100/SUM(netTurnover))

				WHEN @SortBy = 'companyTotal' THEN SUM(companyTotal)
				ELSE (bettype)
			END AS Sortvalue
		FROM #tmpReportData rpt
		INNER JOIN #tmpPaging p ON p.matchid = rpt.matchid
		GROUP BY p.pIdx, p.matchid, rpt.bettype
	)
	SELECT sv.pIdx, sv.matchid
		,ROW_NUMBER() OVER (
			PARTITION BY sv.pIdx, sv.matchid 
			ORDER BY 
				CASE WHEN @SortBy <> 'kickofftime' AND @SortType = 0 THEN sv.SortValue ELSE 0 END ASC
				,CASE WHEN @SortBy <> 'kickofftime' AND @SortType = 1 THEN sv.SortValue ELSE 0 END DESC
				,CASE WHEN @SortBy = 'kickofftime' THEN sv.SortValue ELSE 0 END ASC
		) AS cIdx
		,sv.bettype
		,SUM(turnover)/SUM(betCount) AS stakeAvg
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
		,SUM(superWinloss) AS superWinloss
		,SUM(superComm) AS superComm
		,SUM(superTotal) AS superTotal
		,IIF(SUM(netTurnover)=0, 0, CONVERT(SMALLMONEY,SUM(memberTotal)*100 / SUM(netTurnover))) AS memberMargin

		----company
		,SUM(companyTotal) AS companyTotal
	
	FROM #tmpReportData rpt
	INNER JOIN CTE_SortBettype sv ON sv.matchid = rpt.matchid AND sv.bettype = rpt.bettype
	GROUP BY sv.pIdx, sv.matchid, sv.bettype, sv.Sortvalue
	ORDER BY sv.pIdx, cIdx
	;

	--Grant Sub Total
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
	FROM #tmpReportData rpt
	WHERE rpt.matchid NOT IN (29, 10)
	;

	--Parlay vs Outright
	SELECT 
		rpt.matchid AS bettype
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
	INNER JOIN #tmpSortValue sv ON sv.matchid = rpt.matchid
	WHERE rpt.matchid IN (29, 10)
	GROUP BY rpt.matchid, sv.SortValue
	ORDER BY 
		CASE WHEN @SortType = 0 THEN sv.SortValue ELSE 0 END ASC,
		CASE WHEN @SortType = 1 THEN sv.SortValue ELSE 0 END DESC

	--Grant Total
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

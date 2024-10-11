/*<info serverAlias="DBAGE-bodb02" executers="wsv_xnap" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[EAS_MatchWinloss_EventSel]
	@GroupName	VARCHAR(50),
	@FromDate	SMALLDATETIME,
	@SportType	SMALLINT,
	@LeagueIds	VARCHAR(1000)
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
			@moveBetDate	SMALLDATETIME,
			@balanceUpDate	SMALLDATETIME
		;

	SELECT @fromDateCheck	= CAST(ISNULL(@FromDate, GETDATE()) AS DATE)
	;

	DROP TABLE IF EXISTS #tmpSuperList;
	DROP TABLE IF EXISTS #tmpLeague;
	DROP TABLE IF EXISTS #tmpMatch;

	CREATE TABLE #tmpSuperList(custID INT PRIMARY KEY);
	CREATE TABLE #tmpLeague(leagueid INT PRIMARY KEY);
	CREATE TABLE #tmpMatch(matchid INT PRIMARY KEY, matchcode NVARCHAR(50), homeid INT, awayid INT, isNeutral BIT);
	
	--TODO Saba's sports if any
	DECLARE @sportTypeList TABLE(SportType INT, leagueGroupId INT, SabaGroupType INT);
	IF @SportType > 0
	BEGIN
		INSERT INTO @sportTypeList(SportType, leagueGroupId, SabaGroupType)
		VALUES (@SportType, 0, 0)
	END
	ELSE 
	BEGIN 
		INSERT INTO @sportTypeList(SportType, leagueGroupId, SabaGroupType)
		SELECT ref.Sporttype, ref.leagueGroupId, saba.SabaGroupType
		FROM [dbo].[EAS_f_SabaSportSel] () AS saba
		OUTER APPLY
		(
			SELECT Sporttype, leagueGroupId
			FROM OPENJSON(saba.SporttypeRef)
			WITH (Sporttype INT '$.Sporttype', 
				leagueGroupIds NVARCHAR(MAX) '$.LeagueGroupID' AS JSON
			)
			OUTER APPLY OPENJSON(leagueGroupIds) WITH (leagueGroupId INT '$')
		) AS ref
		WHERE ref.Sporttype > 0
		
	END

	----TODO: Headline
	INSERT INTO #tmpSuperList
	SELECT DISTINCT custID 
	FROM dbo.Acc_CustGroup WITH(NOLOCK)
	WHERE GroupName = @GroupName;

	--TODO: LeaguaIds filetring
	INSERT INTO #tmpLeague (leagueid)
	SELECT DISTINCT value FROM STRING_SPLIT(@LeagueIds, ',');

	--TODO: get BU/MB days
	EXEC dbo.NAP_Admin_GetMovebetDate @MovebetDate = @moveBetDate OUTPUT
	EXEC dbo.NAP_Admin_GetBalanceUpDate @BalanceUpDate = @balanceUpDate OUTPUT

	IF @fromDateCheck > @moveBetDate
	BEGIN
		INSERT INTO #tmpMatch
		SELECT DISTINCT IIF(rpt.ChildMatchType = 200, rpt.parentid, rpt.matchid) AS matchid, rpt.matchcode, rpt.homeid, rpt.awayid, rpt.isNeutral
		FROM bodb_Summary.dbo.rptMatchWinloss_compact rpt WITH(NOLOCK)
			INNER JOIN #tmpSuperList sl ON sl.custID = rpt.custid
			LEFT JOIN @sportTypeList st ON st.SportType = rpt.SportType AND st.leagueGroupId = rpt.leagueGroupId
			INNER JOIN #tmpLeague tl ON tl.leagueid = rpt.leagueid
			INNER JOIN dbo.[match] m WITH(NOLOCK) ON m.matchid = IIF(rpt.ChildMatchType = 200, rpt.parentid, rpt.matchid)
		WHERE rpt.winlostdate = @fromDateCheck
			AND NOT (m.eventstatus <> 'Completed')
			AND 1 = CASE 
						WHEN @SportType > 0		AND st.SportType > 0 THEN 1 --normal sports
						WHEN @SportType <> -99	AND st.SabaGroupType = @SportType AND st.leagueGroupId > 0 THEN 1 --Saba defined sports
						WHEN @SportType = -99	AND rpt.leagueGroupId > 0 AND st.leagueGroupId IS NULL THEN 1 --Saba others sports
						ELSE 0
					END
	END

	IF @fromDateCheck BETWEEN @balanceUpDate AND @moveBetDate
	BEGIN
		INSERT INTO #tmpMatch
		SELECT DISTINCT IIF(rpt.ChildMatchType = 200, rpt.parentid, rpt.matchid) AS matchid, rpt.matchcode, rpt.homeid, rpt.awayid, rpt.isNeutral
		FROM bodb_Summary.dbo.rptMatchWinloss rpt WITH(NOLOCK)
			INNER JOIN #tmpSuperList sl ON sl.custID = rpt.custid
			LEFT JOIN @sportTypeList st ON st.SportType = rpt.SportType AND st.leagueGroupId = rpt.leagueGroupId
			INNER JOIN #tmpLeague tl ON tl.leagueid = rpt.leagueid
		WHERE rpt.winlostdate = @fromDateCheck
			AND rpt.bettype NOT IN (9, 29, 10)
			AND 1 = CASE 
						WHEN @SportType > 0		AND st.SportType > 0 THEN 1 --normal sports
						WHEN @SportType <> -99	AND st.SabaGroupType = @SportType AND st.leagueGroupId > 0 THEN 1 --Saba defined sports
						WHEN @SportType = -99	AND rpt.leagueGroupId > 0 AND st.leagueGroupId IS NULL THEN 1 --Saba others sports
						ELSE 0
					END
	END

	IF @fromDateCheck < @balanceUpDate
	BEGIN
		INSERT INTO #tmpMatch
		SELECT DISTINCT IIF(rpt.ChildMatchType = 200, rpt.parentid, rpt.matchid) AS matchid, rpt.matchcode, rpt.homeid, rpt.awayid, rpt.isNeutral
		FROM bodb_Summary.dbo.rptMatchWinloss_old rpt WITH(NOLOCK)
			INNER JOIN #tmpSuperList sl ON sl.custID = rpt.custid
			LEFT JOIN @sportTypeList st ON st.SportType = rpt.SportType AND st.leagueGroupId = rpt.leagueGroupId
			INNER JOIN #tmpLeague tl ON tl.leagueid = rpt.leagueid
		WHERE rpt.winlostdate = @fromDateCheck
			AND rpt.bettype NOT IN (9, 29, 10)
			AND 1 = CASE 
						WHEN @SportType > 0		AND st.SportType > 0 THEN 1 --normal sports
						WHEN @SportType <> -99	AND st.SabaGroupType = @SportType AND st.leagueGroupId > 0 THEN 1 --Saba defined sports
						WHEN @SportType = -99	AND rpt.leagueGroupId > 0 AND st.leagueGroupId IS NULL THEN 1 --Saba others sports
						ELSE 0
					END
	END

	SELECT matchid
		, matchcode
		, homeid
		, awayid
		, isNeutral
	FROM #tmpMatch tmp
	ORDER BY matchid
END
GO
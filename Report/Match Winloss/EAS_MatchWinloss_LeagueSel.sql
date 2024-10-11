/*<info serverAlias="DBAGE-bodb02" executers="wsv_xnap" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[EAS_MatchWinloss_LeagueSel]
	@GroupName	VARCHAR(50),
	@FromDate	SMALLDATETIME,
	@ToDate		SMALLDATETIME,
	@SportType	SMALLINT
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
		@balanceUpDate		SMALLDATETIME
	;

	SELECT @fromDateCheck	= CAST(ISNULL(@FromDate, GETDATE()) AS DATE),
		@toDateCheck		= CASt(ISNULL(@toDateCheck, GETDATE()) AS DATE)
	;

	DROP TABLE IF EXISTS #tmpSuperList;
	CREATE TABLE #tmpSuperList (custID INT PRIMARY KEY)

	DROP TABLE IF EXISTS #tmpLeague;
	CREATE TABLE #tmpLeague (leagueid INT, leagueGroupId INT)
	
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
				leagueGroupIds NVARCHAR(MAX) '$.leagueGroupId' AS JSON
			)
			OUTER APPLY OPENJSON(leagueGroupIds) WITH (leagueGroupId INT '$')
		) AS ref
		WHERE ref.Sporttype > 0
			--AND saba.SabaGroupType = @SportType
		;
		
	END

	----TODO: Headline
	INSERT INTO #tmpSuperList
	SELECT DISTINCT custID 
	FROM dbo.Acc_CustGroup WITH(NOLOCK)
	WHERE GroupName = @GroupName;

	--TODO: get BU/MB days
	EXEC dbo.NAP_Admin_GetMovebetDate @MovebetDate = @moveBetDate OUTPUT
	EXEC dbo.NAP_Admin_GetBalanceUpDate @BalanceUpDate = @balanceUpDate OUTPUT

	IF @ToDate > @moveBetDate
	BEGIN
		SELECT @fromDateCheck	= IIF(@FromDate < @moveBetDate, DATEADD(DAY, 1, @moveBetDate), @FromDate),
				@toDateCheck	= @ToDate;

		INSERT INTO #tmpLeague
		SELECT DISTINCT rpt.leagueid, rpt.leagueGroupId
		FROM bodb_Summary.dbo.rptMatchWinloss_compact rpt WITH(NOLOCK)
			INNER JOIN #tmpSuperList sl ON sl.custID = rpt.custid
			LEFT JOIN @sportTypeList st ON st.SportType = rpt.SportType AND st.leagueGroupId = rpt.leagueGroupId
			LEFT JOIN dbo.[match] m WITH(NOLOCK) ON m.matchid = rpt.matchid
		WHERE rpt.winlostdate BETWEEN @fromDateCheck AND @toDateCheck
			AND NOT (m.eventstatus <> 'Completed')
			AND rpt.bettype NOT IN (9, 29)
			AND 1 = CASE 
						WHEN @SportType > 0		AND st.SportType > 0 THEN 1 --normal sports
						WHEN @SportType <> -99	AND st.SabaGroupType = @SportType AND st.leagueGroupId > 0 THEN 1 --Saba defined sports
						WHEN @SportType = -99	AND rpt.leagueGroupId > 0 AND st.leagueGroupId IS NULL THEN 1 --Saba others sports
						ELSE 0
					END
			
	END

	IF @ToDate >= @balanceUpDate
	BEGIN
		SELECT @fromDateCheck	= IIF(@FromDate < @balanceUpDate, @balanceUpDate, @FromDate)
			,@toDateCheck		= IIF(@ToDate > @moveBetDate, @moveBetDate, @ToDate);

		INSERT INTO #tmpLeague
		SELECT DISTINCT rpt.leagueid, rpt.leagueGroupId
		FROM bodb_Summary.dbo.rptMatchWinloss rpt WITH(NOLOCK)
			INNER JOIN #tmpSuperList sl ON sl.custID = rpt.custid
			INNER JOIN @sportTypeList st ON st.SportType = rpt.SportType AND st.leagueGroupId = rpt.leagueGroupId
		WHERE rpt.winlostdate BETWEEN @fromDateCheck AND @toDateCheck
			AND rpt.bettype NOT IN (9, 29)
			AND 1 = CASE 
						WHEN @SportType > 0		AND st.SportType > 0 THEN 1 --normal sports
						WHEN @SportType <> -99	AND st.SabaGroupType = @SportType AND st.leagueGroupId > 0 THEN 1 --Saba defined sports
						WHEN @SportType = -99	AND rpt.leagueGroupId > 0 AND st.leagueGroupId IS NULL THEN 1 --Saba others sports
						ELSE 0
					END
			
	END

	IF @FromDate < @balanceUpDate
	BEGIN
		SELECT @fromDateCheck	= @FromDate
				,@toDateCheck	= IIF(@ToDate > @balanceUpDate, DATEADD(DAY, -1, @balanceUpDate), @ToDate);

		INSERT INTO #tmpLeague
		SELECT DISTINCT rpt.leagueid, rpt.leagueGroupId
		FROM bodb_Summary.dbo.rptMatchWinloss_old rpt WITH(NOLOCK)
			INNER JOIN #tmpSuperList sl ON sl.custID = rpt.custid
			INNER JOIN @sportTypeList st ON st.SportType = rpt.SportType AND st.leagueGroupId = rpt.leagueGroupId
		WHERE rpt.winlostdate BETWEEN @fromDateCheck AND @toDateCheck
			AND rpt.bettype NOT IN (9, 29)
			AND 1 = CASE 
						WHEN @SportType > 0		AND st.SportType > 0 THEN 1 --normal sports
						WHEN @SportType <> -99	AND st.SabaGroupType = @SportType AND st.leagueGroupId > 0 THEN 1 --Saba defined sports
						WHEN @SportType = -99	AND rpt.leagueGroupId > 0 AND st.leagueGroupId IS NULL THEN 1 --Saba others sports
						ELSE 0
					END
	END
	
	SELECT tmp.leagueid
		, tmp.leagueGroupId
		, l.leaguename
	FROM (SELECT DISTINCT leagueid, leagueGroupId FROM #tmpLeague ) AS tmp
	INNER JOIN dbo.League l WITH(NOLOCK) ON l.leagueid = tmp.leagueid
	ORDER BY tmp.leagueid, l.leagueGroupId
END
GO
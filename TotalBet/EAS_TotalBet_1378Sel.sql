/*<info serverAlias="DBBOF-bodb02" executers="bodbExtAccNet" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[EAS_TotalBet_1378Sel] 	
	@GroupName		VARCHAR(50),
	@LeagueIds		VARCHAR(1000) = NULL,
	@MatchIds		VARCHAR(1000) = NULL,
	@ViewMode		TINYINT = 1
AS
/*
	Created by: Bobby@20221215
	Task : Implement new totalbet view by extra/super PT [RedmineID : #180319]
	DB: DBBOF/bodb02
	Revisions:
		- 20221215@Bobby: Initialize SPs

	Explanation:
		- @ViewMode: TINYINT
			+ 1 -> View by headline [actual_stake * epositiontaking|ExtraPT2]
			+ 2 -> View by super [actual_stake * spositiontaking]
*/
BEGIN
	SET NOCOUNT ON;

	DECLARE @winlostdate SMALLDATETIME;

	-- INPUT validation
	SELECT @ViewMode	= IIF(@ViewMode NOT IN (1,2), 1, @ViewMode)
		, @LeagueIds	= IIF(@LeagueIds = 'ALL', NULL, @LeagueIds)
		, @MatchIds		= IIF(@MatchIds = 'ALL', NULL, @MatchIds)
		, @winlostdate	= CAST(GETDATE() AS DATE)

	-- filter league								
	DECLARE @leagueList TABLE  (leagueid INT);								
	INSERT INTO @leagueList (leagueid)								
	SELECT DISTINCT VALUE FROM STRING_SPLIT(@LeagueIds, ',');								
								
	-- filter match								
	DECLARE @matchList TABLE  (matchid INT);								
	INSERT INTO @matchList (matchid)								
	SELECT DISTINCT VALUE FROM STRING_SPLIT(@MatchIds, ',');								
								
	-- filter headline/super								
	DROP TABLE IF EXISTS #super;								
	CREATE TABLE #super (custid INT PRIMARY KEY, ExtraPT2 DECIMAL(9,8));
	
	INSERT INTO #super (custid,ExtraPT2)								
	SELECT DISTINCT cg.custid, ept.ExtraPT	
	FROM dbo.Acc_CustGroup cg WITH(NOLOCK)								
	INNER JOIN  dbo.custinfo ci WITH(NOLOCK) ON ci.custid = cg.CustID
	OUTER APPLY 
	(
		SELECT TOP 1 expt2.ExtraPT
		FROM dbo.Acc_GroupExtraPT2Setting expt2 WITH (NOLOCK)
		WHERE @winlostdate BETWEEN expt2.FromDate AND  expt2.ToDate
			AND cg.custid = expt2.SuperId 
			AND expt2.ProductID = 1
			AND expt2.Sporttype = 0
	) AS ept
	WHERE cg.GroupName = @GroupName								
		AND ci.[Enabled] = 1		
		AND cg.RoleID = 4							
	;								
								
	-- filter running events
	DROP TABLE IF EXISTS #cteEvent;								
	CREATE TABLE #cteEvent(matchid INT PRIMARY KEY);								
	
	WITH cte_match AS (
		SELECT m.matchid								
		FROM dbo.match m WITH(NOLOCK)	
		OUTER APPLY (SELECT TOP 1 1 AS IsExist FROM @leagueList t WHERE t.leagueid = m.leagueid) AS lc
		WHERE m.sporttype =  1								
			AND (@LeagueIds IS NULL OR lc.IsExist = 1)							
			AND @MatchIds IS NULL							
			AND m.eventstatus = 'running'	
		UNION								
		SELECT m.matchid								
		FROM dbo.match m WITH(NOLOCK)								
		INNER JOIN @matchList t on t.matchid = m.matchid	
		OUTER APPLY (SELECT TOP 1 1 AS IsExist FROM @leagueList t WHERE t.leagueid = m.leagueid) AS lc								
		WHERE m.sporttype =  1								
			AND (@LeagueIds IS NULL OR lc.IsExist = 1)							
			AND @MatchIds IS NOT NULL							
			AND m.eventstatus = 'running'	
	)
	INSERT INTO #cteEvent (matchid)	
	SELECT m.matchid
	FROM cte_match m
	CROSS APPLY ( 
		SELECT TOP 1 1 AS IsRunning 
		FROM dbo.odds o WITH(NOLOCK) 
		WHERE o.matchid	= m.matchid 
			AND o.bettype IN (1,7,3,8)
			AND o.oddsstatus <> 'closed'
			AND o.IsDeleted <> 1
	) AS ck

	--- TODO: totalbet
	;WITH totalbet AS (								
		SELECT							
			b.matchid,						
			b.liveindicator,						
			b.livehomescore,						
			b.liveawayscore,						
			SUM(IIF(b.bettype = 1 AND b.betteam = 'h', cal.stakePT, 0)) AS home_odds_HDP,						
			SUM(IIF(b.bettype = 1 AND b.betteam = 'a', cal.stakePT, 0)) AS away_odds_HDP,	
			SUM(IIF(b.bettype = 1 AND b.betteam IN ('h','a'), 1, 0))	AS count_odds_HDP,
			---------
			SUM(IIF(b.bettype = 3 AND b.betteam = 'h', cal.stakePT, 0)) AS home_odds_OU,						
			SUM(IIF(b.bettype = 3 AND b.betteam = 'a', cal.stakePT, 0)) AS away_odds_OU,
			SUM(IIF(b.bettype = 3 AND b.betteam IN ('h','a'), 1, 0))	AS count_odds_OU,
			----------
			SUM(IIF(b.bettype = 7 AND b.betteam = 'h', cal.stakePT, 0)) AS home_odds_HTHDP,						
			SUM(IIF(b.bettype = 7 AND b.betteam = 'a', cal.stakePT, 0)) AS away_odds_HTHDP,	
			SUM(IIF(b.bettype = 7 AND b.betteam IN ('h','a'), 1, 0))	AS count_odds_HTHDP,	
			----------
			SUM(IIF(b.bettype = 8 AND b.betteam = 'h', cal.stakePT, 0)) AS home_odds_HTOU,						
			SUM(IIF(b.bettype = 8 AND b.betteam = 'a', cal.stakePT, 0)) AS away_odds_HTOU,
			SUM(IIF(b.bettype = 8 AND b.betteam IN ('h','a'), 1, 0))	AS count_odds_HTOU
		FROM dbo.bettrans b WITH(NOLOCK, INDEX = IX_betrunning_srecommend)							
		INNER JOIN #super super ON super.CustID = b.srecommend							
		INNER JOIN #cteEvent e ON e.matchid = b.matchid							
		CROSS APPLY (							
			SELECT b.actual_stake * IIF(@ViewMode = 1, ISNULL(super.ExtraPT2, b.epositiontaking), b.spositiontaking) AS stakePT					
		) AS cal							
		WHERE b.statusID IN (0,1)							
			AND b.bettype IN (1,3,7,8)				
								
		GROUP BY							
			b.matchid,						
			b.liveindicator,						
			b.livehomescore,						
			b.liveawayscore						
	)
	SELECT e.leagueid, e.matchid, e.homeid,	e.awayid, e.showtime, e.matchcode, tb.liveindicator, tb.livehomescore, tb.liveawayscore
		, CAST(IIF(tb.home_odds_HDP <> 0 OR tb.away_odds_HDP <> 0 ,tb.home_odds_HDP - tb.away_odds_HDP, IIF(tb.count_odds_HDP > 0, 0, NULL)) AS MONEY) AS HDPFT
		, CAST(IIF(tb.home_odds_OU <> 0 OR tb.away_odds_OU <> 0, tb.home_odds_OU - tb.away_odds_OU, IIF(tb.count_odds_OU > 0, 0, NULL)) AS MONEY) AS OUFT
		, CAST(IIF(tb.home_odds_HTHDP <> 0 OR tb.away_odds_HTHDP <> 0, tb.home_odds_HTHDP - tb.away_odds_HTHDP, IIF(tb.count_odds_HTHDP > 0, 0, NULL)) AS MONEY) AS HDPHT
		, CAST(IIF(tb.home_odds_HTOU <> 0 OR tb.away_odds_HTOU <> 0, tb.home_odds_HTOU - tb.away_odds_HTOU, IIF(tb.count_odds_HTOU > 0, 0, NULL)) AS MONEY) AS OUHT	
		, ROW_NUMBER() OVER (PARTITION BY tb.liveindicator, e.matchcode ORDER BY tb.liveindicator DESC, e.matchcode ASC, (tb.liveawayscore + tb.livehomescore) DESC) AS RIdx
	FROM totalbet tb								
	INNER JOIN dbo.match e WITH(NOLOCK) ON e.matchid = tb.matchid
	ORDER BY tb.liveindicator DESC;				
END
GO
/*<info serverAlias="DBBOF-bodb02" executers="wsv_xnap" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[EAS_TotalBet_EventSel] 	
	@LeagueIds		VARCHAR(MAX) = NULL
AS
/*
	Created by: Bobby@20221215
	Task : Implement new totalbet view by extra/super PT [RedmineID : #180319]
	DB: DBBOF/bodb02
	Revisions:
		- 20221215@Bobby: Initialize SPs
		- 20240912@Bobby: Multiple leagues [RedmineID : #210635]

*/
BEGIN
	SET NOCOUNT ON;

	--- SB only
	DECLARE @sporttype TINYINT = 1;

	-- filter league								
	DECLARE @leagueList TABLE  (leagueid INT PRIMARY KEY);								
	INSERT INTO @leagueList (leagueid)								
	SELECT DISTINCT VALUE FROM STRING_SPLIT(@LeagueIds, ',');	

	SELECT m.matchid, m.matchcode, m.homeid, m.awayid, m.IsNeutral
		,l.leagueid
		,l.leaguename
	FROM dbo.match m WITH(NOLOCK) 
	INNER JOIN dbo.League l WITH(NOLOCK) ON l.leagueid = m.leagueid
	INNER JOIN @leagueList f ON f.leagueid = l.leagueid
	OUTER APPLY ( 
		SELECT TOP 1 1 AS IsRunning 
		FROM dbo.odds o WITH(NOLOCK) 
		WHERE o.matchid	= m.matchid 
			AND o.bettype IN (1,7,3,8)
			AND o.oddsstatus <> 'closed'
			AND o.IsDeleted <> 1
	) AS ck
	WHERE m.sporttype		= @sporttype
		AND m.eventstatus	= 'running'
		AND ck.IsRunning	= 1
END
GO
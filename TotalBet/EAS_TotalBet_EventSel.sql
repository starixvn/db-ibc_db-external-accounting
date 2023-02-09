/*<info serverAlias="DBBOF-bodb02" executers="bodbExtAccNet" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[EAS_TotalBet_EventSel] 	
	@LeagueId		INT
AS
/*
	Created by: Bobby@20221215
	Task : Implement new totalbet view by extra/super PT [RedmineID : #180319]
	DB: DBBOF/bodb02
	Revisions:
		- 20221215@Bobby: Initialize SPs

*/
BEGIN
	SET NOCOUNT ON;

	--- SB only
	DECLARE @sporttype TINYINT = 1;

	SELECT m.matchid, m.matchcode, m.homeid, m.awayid, m.IsNeutral
	FROM dbo.match m WITH(NOLOCK) 
	OUTER APPLY ( 
		SELECT TOP 1 1 AS IsRunning 
		FROM dbo.odds o WITH(NOLOCK) 
		WHERE o.matchid	= m.matchid 
			AND o.bettype IN (1,7,3,8)
			AND o.oddsstatus <> 'closed'
			AND o.IsDeleted <> 1
	) AS ck
	WHERE m.leagueid		= @LeagueId
		AND m.sporttype		= @sporttype
		AND m.eventstatus	= 'running'
		AND ck.IsRunning	= 1
END
GO
/*<info serverAlias="DBBOF-bodb02" executers="bodbExtAccNet" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[EAS_TotalBet_LeagueSel] 	
	@IsTest BIT = NULL
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
	DECLARE @sporttype	TINYINT = 1,
		@ckIsTest		BIT;

	SELECT @ckIsTest = ISNULL(@IsTest, 0);

	SELECT l.leagueid
		, l.leaguename
	FROM dbo.League l WITH(NOLOCK)
	CROSS APPLY (
		SELECT TOP(1) 1 AS IsRunning 
		FROM dbo.match m WITH(NOLOCK) 
		INNER JOIN dbo.odds o WITH(NOLOCK) ON o.matchid	= m.matchid 
		WHERE m.leagueid = l.leagueid 
			AND m.eventstatus = 'running'
			AND o.bettype IN (1,7,3,8)
			AND o.oddsstatus <> 'closed'
			AND o.IsDeleted <> 1
	) AS ck
	WHERE l.sporttype		= @sporttype
		AND l.IsActive		= 1
		AND ck.IsRunning	= 1
		AND l.IsTest		= IIF(@ckIsTest = 1, l.IsTest, @ckIsTest)
		AND l.LeagueGroupID  NOT IN (113 ) -- Exclude Saba PinGoal
END
GO
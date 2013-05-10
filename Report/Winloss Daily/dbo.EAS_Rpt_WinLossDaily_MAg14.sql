ALTER PROCEDURE [dbo].[EAS_Rpt_WinLossDaily_MAg14]
	@winlostdate	DATETIME,
	@custID			INT,
	@agentID		INT = NULL
AS
/*
	Created by: Dan
	Date: 2012-10-29
	Task: Daily WinLoss for Site 
	DB: DBEAS/bodb_EAS
	Original: [Acc_Rpt_WinLossDaily_MAgEx14]
	Revisions:
		- 20130121@Dan: Move sp from DB06/bodb02 to DBEAS/bodb_EAS
	Param's Explanation:		
		@custID: Master ID 
*/
BEGIN
	SET NOCOUNT ON
	

	SELECT	b.Recommend CustID,
			ci.username,
			SUM(CASE WHEN b.liveawayscore = 0 AND b.bettype IN (33,43) THEN ABS(b.stake)/2 ELSE ABS(b.stake) END) totalTO,
			SUM((CASE WHEN b.liveawayscore = 0 AND b.bettype IN (33,43) THEN ABS(b.stake)/2 ELSE ABS(b.stake) END)*(1 - b.tpositiontaking)) ComTO,
			SUM((CASE WHEN b.liveawayscore = 0 AND b.bettype IN (33,43) THEN ABS(b.stake)/2 ELSE ABS(b.stake) END)*b.spositiontaking) SAgTO,
			SUM((CASE WHEN b.liveawayscore = 0 AND b.bettype IN (33,43) THEN ABS(b.stake)/2 ELSE ABS(b.stake) END)*b.mpositiontaking) MAgTO,
			SUM((CASE WHEN b.liveawayscore = 0 AND b.bettype IN (33,43) THEN ABS(b.stake)/2 ELSE ABS(b.stake) END)*b.apositiontaking) AgTO,
			
			-SUM(b.winlost - b.actual_stake + b.awinlost + b.mwinlost + b.swinlost + b.scomm) ComWinlost,
			SUM(b.swinlost + b.scomm - b.acomm) SAgWinlost,
			SUM(b.mwinlost + b.acomm - b.comm) MAgWinlost,
			SUM(b.awinlost + b.comm - b.playercomm) AgWinlost

	FROM	bodb02.dbo.Bettrans14 b WITH (NOLOCK)
			INNER JOIN bodb02.dbo.custinfo ci WITH (NOLOCK) ON b.Recommend = ci.custID 
	WHERE	b.winlostdate = @winlostdate
			AND b.MRecommend = @CustID 
			AND (@agentID is null or b.recommend = @agentID) 
			AND b.ruben = 1
			AND b.bettype < 19999
			AND b.statusID NOT IN (101,102,103,121)
	GROUP BY b.Recommend, ci.username 
	ORDER BY ci.username
	
END

GO
GRANT EXECUTE ON [dbo].[EAS_Rpt_WinLossDaily_MAg14] TO [bodbExtAccNet]
GO
GRANT VIEW DEFINITION ON [dbo].[EAS_Rpt_WinLossDaily_MAg14] TO [vnteam]
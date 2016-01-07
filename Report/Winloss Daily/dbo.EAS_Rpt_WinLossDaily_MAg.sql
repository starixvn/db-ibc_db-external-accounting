ALTER PROCEDURE [dbo].[EAS_Rpt_WinLossDaily_MAg]
	@winlostdate	DATETIME,
	@custID			INT,
	@agentID		INT = NULL
AS
/*
	Created by: Dan
	Date: 2012-10-29
	Task: Daily WinLoss for Site
	DB: DBEAS/bodb_EAS
	Original: Acc_Rpt_WinLossDaily_MAgEx
	Revisions:
		- 20130121@Dan: Move sp from DB06/bodb02 to DBEAS/bodb_EAS
		- 20160107@Percy: Get data both bettransRNG and bettrans table [Redmine: #48286]
		
	Param's Explanation:		
		@custID: Master ID 
*/
BEGIN
	SET NOCOUNT ON
	
	IF @winlostdate < CAST(DATEADD(DD, -1, GETDATE()) AS DATE)
	BEGIN	
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

		FROM	bodb02.dbo.Bettrans b WITH (NOLOCK)
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
	ELSE
	BEGIN
		DECLARE @SportBettype TABLE(ProductID INT, Bettype INT,EventType INT)
		INSERT INTO @SportBettype
			EXEC bodb02.dbo.Acc_SportBettypeMatrix_Sel @mode = 4
		
		DELETE @SportBettype WHERE ProductID NOT IN (6, 11, 17) -- bettransRNG
		DELETE @SportBettype WHERE Bettype = 71 -- old bettype RNG
		
		SELECT  CustID, username,
				SUM(totalTO) AS totalTO,
				SUM(ComTO) AS ComTO,
				SUM(SAgTO) AS SAgTO,
				SUM(MAgTO) AS MAgTO,
				SUM(AgTO) AS AgTO,
				SUM(ComWinlost) AS ComWinlost,
				SUM(SAgWinlost) AS SAgWinlost,
				SUM(MAgWinlost) AS MAgWinlost,
				SUM(AgWinlost) AS AgWinlost
		FROM (
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

			FROM	bodb02.dbo.Bettrans b WITH (NOLOCK)
					INNER JOIN bodb02.dbo.custinfo ci WITH (NOLOCK) ON b.Recommend = ci.custID 
			WHERE	b.winlostdate = @winlostdate
					AND b.MRecommend = @CustID 
					AND (@agentID is null or b.recommend = @agentID) 
					AND b.ruben = 1
					AND b.bettype < 19999 AND b.bettype NOT IN (SELECT bettype FROM @SportBettype)
					AND b.statusID NOT IN (101,102,103,121)
			GROUP BY b.Recommend, ci.username 
			
			UNION ALL -- bettransRNG
			
			SELECT	b.Recommend CustID,
					ci.username,
					SUM(ABS(b.stake)) totalTO,
					SUM(ABS(b.stake)*(1 - b.tpositiontaking)) ComTO,
					SUM(ABS(b.stake)*b.spositiontaking) SAgTO,
					SUM(ABS(b.stake)*b.mpositiontaking) MAgTO,
					SUM(ABS(b.stake)*b.apositiontaking) AgTO,
					
					-SUM(b.winlost - b.actual_stake + b.awinlost + b.mwinlost + b.swinlost + b.scomm) ComWinlost,
					SUM(b.swinlost + b.scomm - b.acomm) SAgWinlost,
					SUM(b.mwinlost + b.acomm - b.comm) MAgWinlost,
					SUM(b.awinlost + b.comm - b.playercomm) AgWinlost

			FROM	bodb02.dbo.Bettrans b WITH (NOLOCK)
					INNER JOIN bodb02.dbo.custinfo ci WITH (NOLOCK) ON b.Recommend = ci.custID 
			WHERE	b.winlostdate = @winlostdate
					AND b.MRecommend = @CustID 
					AND (@agentID is null or b.recommend = @agentID)
					AND b.gameID < 19999
					AND b.statusID NOT IN (0,1,101,102,103,121)
			GROUP BY b.Recommend, ci.username
		) AS A
		GROUP BY CustID, username
		ORDER BY username
	END
END


GO
GRANT EXECUTE ON [dbo].[EAS_Rpt_WinLossDaily_MAg] TO [bodbExtAccNet]
GO
GRANT VIEW DEFINITION ON [dbo].[EAS_Rpt_WinLossDaily_MAg] TO [vnteam]
GO
/*<info serverAlias="DBEAS-bodb_EAS" executers="bodbExtAccNet" viewers="" isFunction="0" isNested="0"></info>*/
USE [bodb_EAS]
GO

ALTER PROCEDURE [dbo].[EAS_Rpt_WinLossDaily_SAg]
	@winlostdate		SMALLDATETIME,
	@custID				INT,
	@masterID			INT = NULL,
	@ExcludeProductIds	VARCHAR(MAX) = ''
AS
/*
	Created by: Dan
	Date: 2012-10-29
	Task: Daily WinLoss for Site 
	DB: DBEAS/bodb_EAS
	Original: Acc_Rpt_WinLossDaily_SAgEx
	Revisions:	
		- 20130121@Dan: Move sp from DB06/bodb02 to DBEAS/bodb_EAS
		- 20160107@Percy: Get data from bettransRNG, bettransLC and bettrans table [Redmine: #48286]
		- 20160215@Percy: Support new product AllBet [Redmine: #50922]
		- 20160414@Victor: Support new product Voidbridge [Redmine: #55468]
		- 20161028@Percy:
			1. Support Fishing World [RedmineID: #65735]
			2. Apply column RefTable
		- 20181004@Percy: Add @ExcludeProductIds to exclude some products [RedmineID: #101644]

	Param's Explanation:		
		@custID: Super ID 
*/
BEGIN
	SET NOCOUNT ON

	DECLARE @isTest BIT = 0
	SELECT  @isTest = dbo.f_CheckSPVersion(@@PROCID)
	
	DECLARE @ExcludeBettype TABLE(Bettype INT)

	IF ISNULL(@ExcludeProductIds, '') <> ''
		INSERT INTO @ExcludeBettype (Bettype)
		SELECT DISTINCT Bettype FROM bodb02.dbo.f_SportBettypeMatrixByProduct_Sel(@ExcludeProductIds, @isTest)
	
	IF @winlostdate < CAST(DATEADD(DD, -1, GETDATE()) AS DATE)
	BEGIN
		SELECT	b.MRecommend CustID,
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
				INNER JOIN bodb02.dbo.custinfo ci WITH (NOLOCK) ON b.Mrecommend = ci.custID 
		WHERE	b.winlostdate = @winlostdate
				AND b.srecommend = @CustID 
				AND (@masterID is null or b.mrecommend = @masterID) 
				AND b.ruben = 1
				AND b.bettype < 19999
				AND b.statusID NOT IN (101,102,103,121)
				AND NOT EXISTS (SELECT 1 FROM @ExcludeBettype s WHERE s.Bettype = b.bettype)
		GROUP BY b.MRecommend, ci.username 
		ORDER BY ci.username
	END
	ELSE
	BEGIN
		DECLARE @SportBettype TABLE (Bettype INT)
		INSERT INTO @SportBettype (Bettype)
		SELECT DISTINCT Bettype FROM bodb02.dbo.f_SportBettypeMatrix_Sel(0, 0, 0, 2, '', '', @isTest)
		WHERE RefTable IN (1,2) -- bettype in bettransRnG/bettransLC

		INSERT INTO @SportBettype (bettype)
		SELECT e.Bettype
		FROM @ExcludeBettype e
			LEFT JOIN @SportBettype s ON e.Bettype = s.Bettype
		WHERE s.Bettype IS NULL
		
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
			SELECT	b.MRecommend CustID,
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
					INNER JOIN bodb02.dbo.custinfo ci WITH (NOLOCK) ON b.Mrecommend = ci.custID 
			WHERE	b.winlostdate = @winlostdate
					AND b.srecommend = @CustID 
					AND (@masterID is null or b.mrecommend = @masterID) 
					AND b.ruben = 1
					AND b.bettype < 19999
					AND b.statusID NOT IN (101,102,103,121)
					AND NOT EXISTS (SELECT 1 FROM @SportBettype s WHERE s.Bettype = b.bettype)
			GROUP BY b.MRecommend, ci.username
			
			UNION ALL -- bettransRNG
			
			SELECT	b.MRecommend CustID,
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

			FROM	bodb02.dbo.BettransRNG b WITH (NOLOCK)
					INNER JOIN bodb02.dbo.custinfo ci WITH (NOLOCK) ON b.Mrecommend = ci.custID 
			WHERE	b.winlostdate = @winlostdate
					AND b.srecommend = @CustID 
					AND (@masterID is null or b.mrecommend = @masterID)
					--AND b.gameID < 19999
					AND b.statusID NOT IN (0,1,101,102,103,121)
					AND NOT EXISTS (SELECT 1 FROM @ExcludeBettype s WHERE s.Bettype = b.gameId)
			GROUP BY b.MRecommend, ci.username
			
			UNION ALL -- bettransLC
			
			SELECT	b.MRecommend CustID,
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

			FROM	bodb02.dbo.BettransLC b WITH (NOLOCK)
					INNER JOIN bodb02.dbo.custinfo ci WITH (NOLOCK) ON b.Mrecommend = ci.custID 
			WHERE	b.winlostdate = @winlostdate
					AND b.srecommend = @CustID 
					AND (@masterID is null or b.mrecommend = @masterID)
					--AND b.gameID < 19999
					AND b.statusID NOT IN (0,1,101,102,103,121)
					AND NOT EXISTS (SELECT 1 FROM @ExcludeBettype s WHERE s.Bettype = b.gameId)
			GROUP BY b.MRecommend, ci.username
		) AS A
		GROUP BY CustID, username
		ORDER BY username
	END
	
END
GO
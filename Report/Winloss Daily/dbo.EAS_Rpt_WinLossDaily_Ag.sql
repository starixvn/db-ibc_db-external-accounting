/*<info serverAlias="DBAGE-bodb02" executers="bodbExtAccNet" viewers="" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[EAS_Rpt_WinLossDaily_Ag]
	@winlostdate		SMALLDATETIME,
	@custID				INT,
	@memberID			INT = NULL,
	@ExcludeProductIds	VARCHAR(MAX) = ''
AS
/*
	Created by: Dan
	Date: 2012-10-29
	Task: Daily WinLoss for Site 
	DB: DBAGE/bodb02
	Original: [Acc_Rpt_WinLossDaily_AgEx]
	Revisions:
		- 20130121@Dan: Move sp from DB06/bodb02 to DBEAS/bodb_EAS
		- 20160107@Percy: Get data from bettransRNG, bettransLC and bettrans table [Redmine: #48286]
		- 20160215@Percy: Support new product AllBet [Redmine: #50922]
		- 20160414@Victor: Support new product Voidbridge [Redmine: #55468]
		- 20161028@Percy:
			1. Support Fishing World [RedmineID: #65735]
			2. Apply column RefTable
		- 20181004@Percy: Add @ExcludeProductIds to exclude some products [RedmineID: #101644]
		- 20181031@Helen: DB052 Indexes Revolution [RedmineID: 103572]
		- 20181113@Paul: Enhance performance [RedmineID: #103479]
		- 20190418@Kan: DB053/bodb02 Migration, Move sp from DBEAS/bodb_EAS to DB053/bodb02 [Redmine: #111865]
		
	Param's Explanation:		
		@custID: Agent ID 
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
	
		IF @memberID IS NULL
		BEGIN
			SELECT	b.custID,
				b.username,
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
			WHERE	b.winlostdate = @winlostdate
					AND b.Recommend = @CustID 
					AND b.statusID IN (111,112,113)
					AND NOT EXISTS (SELECT 1 FROM @ExcludeBettype s WHERE s.Bettype = b.bettype)
			GROUP BY b.custID, b.username
			ORDER BY b.username	
		
		END
		ELSE
		BEGIN
			SELECT	b.custID,
					b.username,
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
			WHERE	b.winlostdate = @winlostdate
					AND b.custid = @memberID
					AND b.statusID IN (111,112,113)
					AND NOT EXISTS (SELECT 1 FROM @ExcludeBettype s WHERE s.Bettype = b.bettype)
			GROUP BY b.custID, b.username
			ORDER BY b.username	
		END
		
		
	END
	ELSE
	BEGIN
		DECLARE @SportBettype TABLE(ProductID INT, Bettype INT)
		INSERT INTO @SportBettype (ProductID, Bettype)
		SELECT ProductID, Bettype FROM bodb02.dbo.f_SportBettypeMatrix_Sel(0, 0, 0, 2, '', '', @isTest)
		WHERE RefTable IN (1,2) -- bettype in bettransRnG/bettransLC
		
		IF @memberID IS NULL
		BEGIN
			SELECT  custID, username,
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
				SELECT	b.custID,
						b.username,
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
				WHERE	b.winlostdate = @winlostdate
						AND b.Recommend = @CustID 
						AND b.statusID IN (111,112,113)
						AND NOT EXISTS (SELECT 1 FROM @SportBettype s WHERE s.Bettype = b.Bettype)
				GROUP BY b.custID, b.username
				
				UNION ALL -- bettransRNG
				
				SELECT	b.custID,
						b.username,
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
				WHERE	b.winlostdate = @winlostdate
						AND b.Recommend = @CustID 
						AND b.statusID IN (111,112,113)
						AND NOT EXISTS (SELECT 1 FROM @ExcludeBettype s WHERE s.Bettype = b.gameId)
				GROUP BY b.custID, b.username

				UNION ALL -- bettransLC
				
				SELECT	b.custID,
						b.username,
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
				WHERE	b.winlostdate = @winlostdate
						AND b.Recommend = @CustID 
						AND b.statusID IN (111,112,113)
						AND NOT EXISTS (SELECT 1 FROM @ExcludeBettype s WHERE s.Bettype = b.gameId)
				GROUP BY b.custID, b.username
			) AS A
			GROUP BY custID, username
			ORDER BY username
		
		END
		ELSE
		BEGIN
			SELECT  custID, username,
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
				SELECT	b.custID,
						b.username,
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
				WHERE	b.winlostdate = @winlostdate
						AND b.custid = @memberID
						AND b.statusID IN (111,112,113)
						AND NOT EXISTS (SELECT 1 FROM @SportBettype s WHERE s.Bettype = b.Bettype)
				GROUP BY b.custID, b.username
				
				UNION ALL -- bettransRNG
				
				SELECT	b.custID,
						b.username,
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
				WHERE	b.winlostdate = @winlostdate
						AND b.custid = @memberID
						AND b.statusID IN (111,112,113)
						AND NOT EXISTS (SELECT 1 FROM @ExcludeBettype s WHERE s.Bettype = b.gameId)
				GROUP BY b.custID, b.username

				UNION ALL -- bettransLC
				
				SELECT	b.custID,
						b.username,
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
				WHERE	b.winlostdate = @winlostdate
						AND b.custid = @memberID
						AND b.statusID IN (111,112,113)
						AND NOT EXISTS (SELECT 1 FROM @ExcludeBettype s WHERE s.Bettype = b.gameId)
				GROUP BY b.custID, b.username
			) AS A
			GROUP BY custID, username
			ORDER BY username
		
		END
	END
END
GO
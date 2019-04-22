/*<info serverAlias="DBAGE-bodb02" executers="bodbExtAccNet" viewers="" isFunction="0" isNested="0"></info>*/
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
	DB: DBAGE/bodb02
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
		- 20181031@Helen: DB052 Indexes Revolution [RedmineID: 103572]
		- 20181113@Paul: Enhance performance [RedmineID: #103479]
		- 20190418@Kan: DB053/bodb02 Migration, Move sp from DBEAS/bodb_EAS to DB053/bodb02 [Redmine: #111865]
		
	Param's Explanation:		
		@custID: Super ID 
*/
BEGIN
	SET NOCOUNT ON

	DECLARE @isTest BIT = 0
	SELECT  @isTest = dbo.f_CheckSPVersion(@@PROCID)
	
	DECLARE @ExcludeBettype TABLE(Bettype INT)
	
	DECLARE @username_tmp NVARCHAR(50)
	
	IF @masterID IS NOT NULL
	BEGIN
		SET @username_tmp = (SELECT username FROM bodb02.dbo.custinfo ci WITH (NOLOCK)  WHERE custID = @masterID)
	END
	
	IF ISNULL(@ExcludeProductIds, '') <> ''
		INSERT INTO @ExcludeBettype (Bettype)
		SELECT DISTINCT Bettype FROM bodb02.dbo.f_SportBettypeMatrixByProduct_Sel(@ExcludeProductIds, @isTest)
	
	IF @winlostdate < CAST(DATEADD(DD, -1, GETDATE()) AS DATE)
	BEGIN
		IF @masterID IS NULL
		BEGIN
			SELECT	d.CustID,
					ci.username,
					d.totalTO,
					d.ComTO,
					d.SAgTO,
					d.MAgTO,
					d.AgTO,
					d.ComWinlost,
					d.SAgWinlost,
					d.MAgWinlost,
					d.AgWinlost
			FROM (
					SELECT	b.MRecommend CustID,
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
							AND b.srecommend = @CustID 
							AND b.statusID IN (111,112,113)
							AND NOT EXISTS (SELECT 1 FROM @ExcludeBettype s WHERE s.Bettype = b.bettype)
					GROUP BY b.MRecommend
				) d
				INNER JOIN bodb02.dbo.custinfo ci WITH (NOLOCK) ON d.CustID = ci.custID
			ORDER BY ci.username
		END
		ELSE
		BEGIN
			SELECT	b.MRecommend CustID,
				@username_tmp AS username,
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
					AND b.mrecommend = @masterID
					AND b.statusID IN (111,112,113)
					AND NOT EXISTS (SELECT 1 FROM @ExcludeBettype s WHERE s.Bettype = b.bettype)
			GROUP BY b.MRecommend
			
		END
		
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
		
		IF @masterID IS NULL
		BEGIN
			SELECT  a.CustID, username,
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
						AND b.srecommend = @CustID 
						AND b.statusID IN (111,112,113)
						AND NOT EXISTS (SELECT 1 FROM @SportBettype s WHERE s.Bettype = b.bettype)
				GROUP BY b.MRecommend
				
				UNION ALL -- bettransRNG
				
				SELECT	b.MRecommend CustID,
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
						AND b.srecommend = @CustID 
						AND b.statusID IN (111,112,113)
						AND NOT EXISTS (SELECT 1 FROM @ExcludeBettype s WHERE s.Bettype = b.gameId)
				GROUP BY b.MRecommend
				
				UNION ALL -- bettransLC
				
				SELECT	b.MRecommend CustID,
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
						AND b.srecommend = @CustID 
						AND b.statusID IN (111,112,113)
						AND NOT EXISTS (SELECT 1 FROM @ExcludeBettype s WHERE s.Bettype = b.gameId)
				GROUP BY b.MRecommend
			) AS A
			INNER JOIN bodb02.dbo.custinfo ci WITH (NOLOCK) ON a.CustID = ci.custID
			GROUP BY a.CustID, username
			ORDER BY username
			
		END
		ELSE
		BEGIN
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
						@username_tmp AS username,
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
						AND b.mrecommend = @masterID
						AND b.statusID IN (111,112,113)
						AND NOT EXISTS (SELECT 1 FROM @SportBettype s WHERE s.Bettype = b.bettype)
				GROUP BY b.MRecommend
				
				UNION ALL -- bettransRNG
				
				SELECT	b.MRecommend CustID,
						@username_tmp AS username,
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
						AND b.mrecommend = @masterID
						AND b.statusID IN (111,112,113)
						AND NOT EXISTS (SELECT 1 FROM @ExcludeBettype s WHERE s.Bettype = b.gameId)
				GROUP BY b.MRecommend
				
				UNION ALL -- bettransLC
				
				SELECT	b.MRecommend CustID,
						@username_tmp AS username,
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
						AND b.mrecommend = @masterID
						AND b.statusID IN (111,112,113)
						AND NOT EXISTS (SELECT 1 FROM @ExcludeBettype s WHERE s.Bettype = b.gameId)
				GROUP BY b.MRecommend
			) AS A
			GROUP BY CustID, username
			ORDER BY username
		END
	END
END
GO
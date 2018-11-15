/*<info serverAlias="DBEAS-bodb_EAS" executers="bodbExtAccNet" viewers="" isFunction="0" isNested="0"></info>*/
USE [bodb_EAS]
GO

ALTER PROCEDURE [dbo].[EAS_Rpt_WinLossDaily_Com]
	@winlostdate		SMALLDATETIME,
	@custid				INT = NULL,	
	@GroupName			VARCHAR(50) = 'ACCTHAI',
	@ExcludeProductIds	VARCHAR(MAX) = ''
AS
/*
	Created by: Dan
	Date: 2012-29-10
	Task: Daily WinLoss for Site
	DB: DBEAS/bodb_EAS
	Original: Acc_Rpt_WinLossDaily_ComEx
	Revisions:
		
	Param's Explanation:
		- 20130121@Dan: Move sp from DB06/bodb02 to DBEAS/bodb_EAS, call to bodb_AGE for Acc_CustGroup
		- 20160107@Percy: Get data from bettransRNG, bettransLC and bettrans table [Redmine: #48286]
		- 20160215@Percy: Support new product AllBet [Redmine: #50922]
		- 20160414@Victor: Support new product Voidbridge [Redmine: #55468]		
		- 20160824@Sophia: Enhance Performance (work around for hotfix) [Redmine: #62941]
		- 20161028@Percy:
			1. Support Fishing World [RedmineID: #65735]
			2. Apply column RefTable
		- 20181004@Percy: Add @ExcludeProductIds to exclude some products [RedmineID: #101644]
		- 20181113@Paul: Enhance performance [RedmineID: #103479]
*/
BEGIN
	SET NOCOUNT ON

	DECLARE @isTest BIT = 0
	SELECT  @isTest = dbo.f_CheckSPVersion(@@PROCID)
	
	DECLARE @ExcludeBettype TABLE(Bettype INT)

	IF ISNULL(@ExcludeProductIds, '') <> ''
		INSERT INTO @ExcludeBettype (Bettype)
		SELECT DISTINCT Bettype FROM bodb02.dbo.f_SportBettypeMatrixByProduct_Sel(@ExcludeProductIds, @isTest)

	CREATE TABLE #tmpSuperList ( custID INT, username VARCHAR(30), PRIMARY KEY (custID ASC))	
	
	INSERT INTO #tmpSuperList(CustID, username)
	SELECT custID,username 
	FROM bodb02.dbo.custinfo (NOLOCK)
	WHERE 
		custid in (SELECT custid from DBAGE.bodb_AGE.dbo.Acc_CustGroup WITH(nolock) WHERE GroupName = @GroupName)
		AND (@custid IS NULL OR custid=@custid)	
	
	IF @winlostdate < CAST(DATEADD(DD, -1, GETDATE()) AS DATE)
	BEGIN
		SELECT	d.CustID,
				t.username,
				d.totalTO,
				d.ComTO,
				d.SAgTO,
				d.MAgTO,
				d.AgTO,
				d.ComWinlost,
				d.SAgWinlost,
				d.MAgWinlost,
				d.AgWinlost
		FROM #tmpSuperList t
			CROSS APPLY (
				SELECT	TOP 1 b.SRecommend CustID,
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
						AND b.statusID IN (111,112,113)
						AND NOT EXISTS (SELECT 1 FROM @ExcludeBettype s WHERE s.Bettype = b.bettype)
						AND b.srecommend = t.custID
				GROUP BY b.SRecommend
			) d
		ORDER BY t.username
	END
	ELSE
	BEGIN
		CREATE TABLE #SportBettype (ProductID INT, Bettype INT) 
		INSERT INTO #SportBettype (ProductID, Bettype)
		SELECT ProductID, Bettype FROM bodb02.dbo.f_SportBettypeMatrix_Sel(0, 0, 0, 2, '', '', @isTest)
		WHERE RefTable IN (1,2) -- bettype in bettransRnG/bettransLC

		INSERT INTO #SportBettype (bettype)
		SELECT e.Bettype
		FROM @ExcludeBettype e
			LEFT JOIN #SportBettype s ON e.Bettype = s.Bettype
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
			SELECT d.CustID,
					t.username,
					d.totalTO,
					d.ComTO,
					d.SAgTO,
					d.MAgTO,
					d.AgTO,					
					d.ComWinlost,
					d.SAgWinlost,
					d.MAgWinlost,
					d.AgWinlost
			FROM #tmpSuperList t
				CROSS APPLY (
					SELECT	TOP 1 b.SRecommend CustID,
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
							AND b.statusID IN (111,112,113)
							AND NOT EXISTS (SELECT 1 FROM #SportBettype s WHERE s.Bettype = b.bettype)
							AND b.srecommend = t.custID
					GROUP BY b.SRecommend
				) d
			
			UNION ALL -- bettransRNG
			
			SELECT d.CustID,
					t.username,
					d.totalTO,
					d.ComTO,
					d.SAgTO,
					d.MAgTO,
					d.AgTO,					
					d.ComWinlost,
					d.SAgWinlost,
					d.MAgWinlost,
					d.AgWinlost
			FROM #tmpSuperList t
				CROSS APPLY (
					SELECT	TOP 1 b.SRecommend CustID,
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
							AND b.statusID IN (111,112,113)
							AND NOT EXISTS (SELECT 1 FROM @ExcludeBettype s WHERE s.Bettype = b.gameId)
							AND b.srecommend = t.custID 
					GROUP BY b.SRecommend
				) d
			
			UNION ALL -- bettransLC
			
			SELECT d.CustID,
					t.username,
					d.totalTO,
					d.ComTO,
					d.SAgTO,
					d.MAgTO,
					d.AgTO,					
					d.ComWinlost,
					d.SAgWinlost,
					d.MAgWinlost,
					d.AgWinlost
			FROM #tmpSuperList t
				CROSS APPLY (
					SELECT	TOP 1 b.SRecommend CustID,
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
							AND b.statusID IN (111,112,113)
							AND NOT EXISTS (SELECT 1 FROM @ExcludeBettype s WHERE s.Bettype = b.gameId)
							AND b.srecommend = t.custID 
					GROUP BY b.SRecommend
				) d
		) AS A
		GROUP BY CustID, username
		ORDER BY username
		
		DROP TABLE #SportBettype
	END

	DROP TABLE #tmpSuperList
END
GO
/*<info serverAlias="DBEAS-bodb_EAS" executers="bodbExtAccNet" viewers="" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[EAS_Rpt_WinLossDaily_SAg14]
	@winlostdate		SMALLDATETIME,
	@custID				INT,
	@masterID			INT = NULL,
	@ExcludeProductIds	VARCHAR(MAX) = ''
AS
/*
	Created by: Dan
	Date: 2012-10-29
	Task: Daily WinLoss for Site by Currency 
	DB: DBEAS/bodb_EAS
	Original: Acc_Rpt_WinLossDaily_SAgEx14
	
	Revisions:		
		- 20130121@Dan: Move sp from DB06/bodb02 to DBEAS/bodb_EAS
		- 20181004@Percy: Add @ExcludeProductIds to exclude some products [RedmineID: #101644]
		- 20181031@Helen: DB052 Indexes Revolution [RedmineID: 103572]
		
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
	
	DECLARE @username_tmp NVARCHAR(50)
	
	IF @masterID IS NOT NULL
	BEGIN
		SET @username_tmp = (SELECT username FROM bodb02.dbo.custinfo ci WITH (NOLOCK)  WHERE custID = @masterID)
	END
	
	IF @masterID IS NULL
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

		FROM	bodb02.dbo.Bettrans14 b WITH (NOLOCK)
				INNER JOIN bodb02.dbo.custinfo ci WITH (NOLOCK) ON b.Mrecommend = ci.custID 
		WHERE	b.winlostdate = @winlostdate
				AND b.srecommend = @CustID 
				AND b.ruben = 1
				AND b.bettype < 19999
				AND b.statusID NOT IN (101,102,103,121)
				AND NOT EXISTS (SELECT 1 FROM @ExcludeBettype s WHERE s.Bettype = b.bettype)
		GROUP BY b.MRecommend, ci.username 
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

		FROM	bodb02.dbo.Bettrans14 b WITH (NOLOCK)
		WHERE	b.winlostdate = @winlostdate
				AND b.mrecommend = @masterID
				AND b.ruben = 1
				AND b.bettype < 19999
				AND b.statusID NOT IN (101,102,103,121)
				AND NOT EXISTS (SELECT 1 FROM @ExcludeBettype s WHERE s.Bettype = b.bettype)
		GROUP BY b.MRecommend
	END
END
GO
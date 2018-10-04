/*<info serverAlias="DBEAS-bodb_EAS" executers="bodbExtAccNet" viewers="" isFunction="0" isNested="0"></info>*/
USE [bodb_EAS]
GO

ALTER PROCEDURE [dbo].[EAS_Rpt_WinLossDaily_Com14]
	@winlostdate		DATETIME,	
	@custid				INT = NULL,	
	@GroupName			VARCHAR(50) = 'ACCTHAI',
	@ExcludeProductIds	VARCHAR(MAX) = ''
AS
/*
	Created by: Dan
	Date: 2012-10-29
	Task: Daily WinLoss for Site
	DB: DBEAS/bodb_EAS
	Original: [Acc_Rpt_WinLossDaily_ComEx14]
	Revisions:
		- 20130121@Dan: Move sp from DB06/bodb02 to DBEAS/bodb_EAS, call to bodb_AGE for Acc_CustGroup
		- 20160824@Sophia: Enhance Performance (work around for hotfix) [Redmine: #62941]
		- 20181004@Percy: Add @ExcludeProductIds to exclude some products [RedmineID: #101644]
	
	Param's Explanation:
		
*/
BEGIN
	SET NOCOUNT ON

	DECLARE @isTest BIT = 0
	SELECT  @isTest = dbo.f_CheckSPVersion(@@PROCID)
	
	DECLARE @ExcludeBettype TABLE(Bettype INT)

	IF ISNULL(@ExcludeProductIds, '') <> ''
		INSERT INTO @ExcludeBettype (Bettype)
		SELECT DISTINCT Bettype FROM bodb02.dbo.f_SportBettypeMatrixByProduct_Sel(@ExcludeProductIds, @isTest)

	CREATE TABLE #tmpSuperList( custID INT, username VARCHAR(30), PRIMARY KEY (custID ASC))

	INSERT INTO #tmpSuperList(CustID, username)
	SELECT custID,username 
	FROM bodb02.dbo.custinfo (NOLOCK)
	WHERE 
		custid in (SELECT custid from DBAGE.bodb_AGE.dbo.Acc_CustGroup WITH(nolock) WHERE GroupName = @GroupName)
		AND (@custid IS NULL OR custid=@custid)	

	SELECT	b.SRecommend CustID,
			t.username,
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
			INNER JOIN #tmpSuperList t ON b.srecommend = t.custID 
	WHERE	b.winlostdate = @winlostdate
			AND b.ruben = 1
			AND b.bettype < 19999
			AND b.statusID NOT IN (101,102,103,121)
			AND NOT EXISTS (SELECT 1 FROM @ExcludeBettype s WHERE s.Bettype = b.bettype)
	GROUP BY b.SRecommend, t.username 
	ORDER BY t.username
	
	DROP TABLE #tmpSuperList
END
GO
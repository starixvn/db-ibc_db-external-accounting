ALTER PROCEDURE [dbo].[EAS_Rpt_WinLossDaily_Com14]
	@winlostdate	DATETIME,	
	@custid			INT = NULL,	
	@GroupName		VARCHAR(50) = 'ACCTHAI'--ACCTHAI or ACCINDO
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
	
	Param's Explanation:
		
*/
BEGIN
	SET NOCOUNT ON
	CREATE TABLE #tmpSuperList( custID INT, username VARCHAR(30), PRIMARY KEY (custID ASC))

	/*
	INSERT INTO #tmpSuperList(CustID, username)
	SELECT	custID, username 
	FROM	custinfo WITH (NOLOCK)
	WHERE	currency = @currency 
			AND roleid = 4 
			AND dbo.f_isDummySuper(custID) = 0
	*/
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
	GROUP BY b.SRecommend, t.username 
	ORDER BY t.username
	
	DROP TABLE #tmpSuperList
END

GO
GRANT EXECUTE ON [dbo].[EAS_Rpt_WinLossDaily_Com14] TO [bodbExtAccNet]
GO
GRANT VIEW DEFINITION ON [dbo].[EAS_Rpt_WinLossDaily_Com14] TO [vnteam]
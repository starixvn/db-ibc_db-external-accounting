USE [bodb_EAS]
GO

ALTER PROCEDURE [dbo].[EAS_Rpt_WinLossDetail_Com] 	
	@GroupName		VARCHAR(50) = 'ACCTHAI',--ACCTHAI or ACCINDO
	@custid			INT = NULL,	
	@FromDate		SMALLDATETIME,
	@ToDate			SMALLDATETIME,
	@showSB			BIT = 1,
	@showCasino		BIT = 0,
	@showP2P		BIT = 0,
	@showRB			BIT = 0,	
	@showNG			BIT = 0,
	@showBI			BIT = 0,
	@showLiveCasino BIT = 0,
	@showVS			BIT = 0,
	@showKeno		BIT = 0,
	@showGD			BIT = 0,
	@showCB			BIT = 0,
	@showCF			BIT = 0,
	@showAB			BIT = 0,
	@showVB			BIT = 0,
	@BalanceUpDay	SMALLDATETIME	
AS

/*
Created by: Dan
Date: 2012-10-29
Task : Super Winloss Detail
DB: DBEAS/bodb_EAS
Original: Acc_Rpt_WinLossDetail_ComEx
Revisions:
	- 20130121@Dan: Move sp from DB053/bodb02 to DBEAS/bodb_EAS, call to bodb_AGE for Acc_CustGroup, add linked server DBSUM for bodb_Summary
	- 20140305@Patrick: Add more Keno product(sport:202, bettype between 1501 and 1599)
	- 20140321@Lukas: seperate P2P product to enhance performance
	- 20140420@Francis: revise SP to use temporary table instead of variable table to improve performance
	- 20150502@Lukas: Revise SP to insert into Temporary table (#Sum_WinLoss_Old) of a remote table (DBSUM.bodb_Summary.dbo.Sum_WinLoss_Old) to enhance performance (HotFix #35279)
	- 20150528@Sophia: Apply Gold Deluxe and Sport bettype Matrix [Redmine: #36775]
	- 20150907@Winnie: Add CB [Redmine: #43099]
	- 20151217@Percy: Add Cockfighting [Redmine: #48836]
	- 20160107@Percy: Include new bettype range of the new RNG Casino [Redmine: #48286]
	- 20160215@Percy: Support new product AllBet [Redmine: #50922]
	- 20160225@Sophia: Add new column TurnoverNoDraw [Redmine: #51427]
	- 20160414@Victor: Support new product Voidbridge [Redmine: #55468]
	- 20160809@Percy: Modify Net Turnover for Allbet [RedmineID: #61876]
	- 20160824@Sophia: Enhance Performance (work around for hotfix) [Redmine: #62941]
*/

SET NOCOUNT ON

CREATE TABLE #tmpSuperList ( custID INT PRIMARY KEY)

INSERT INTO #tmpSuperList(CustID)
SELECT custID 
FROM DBAGE.bodb_AGE.dbo.Acc_CustGroup WITH(NOLOCK)
WHERE (@custid IS NULL OR custid = @custid)
	AND GroupName = @GroupName

CREATE TABLE #ComWinLossDetails (CustID int, Turnover money, TurnoverNoDraw MONEY, GrossComm money, MemberWinLost money, 
	PlayerComm money, MemberTotal money, AgWinLost money, AgComm money, AgTotal money, 
	MAgWinLost money, MAgComm money, MAgTotal money, SAgWinLost money, SAgComm money, SAgTotal money, Company money)

CREATE TABLE #TmpCond  (sporttype INT, bettype INT)--, PRIMARY KEY NONCLUSTERED (Bettype ASC, sporttype ASC))
CREATE TABLE #TmpCondSumWL (sporttype INT, bettype INT)--, PRIMARY KEY NONCLUSTERED (Bettype ASC, sporttype ASC))

----Get Sport Bettype Matrix------
DECLARE @isTest BIT = 0
SELECT  @isTest = dbo.f_CheckSPVersion(@@PROCID)


CREATE TABLE #SportBettype (ProductID INT, Bettype INT, PRIMARY KEY NONCLUSTERED (Bettype ASC, ProductID ASC))

INSERT INTO #SportBettype (ProductID, Bettype)
SELECT ProductID, Bettype FROM bodb02.dbo.f_SportBettypeMatrix_Sel(0, 0, 0, 2, '', '', @isTest)


IF @ShowSB = 1
BEGIN
	--Bettrans
	--INSERT INTO #TmpCond(Sporttype, Bettype)
	--SELECT 0 AS sporttype, typeid FROM bodb02.dbo.bettype (NOLOCK)
	--WHERE	typeid < 31 OR typeid BETWEEN 120 AND 999 or typeid between 1301 and 1334

	INSERT INTO #TmpCond(Sporttype, Bettype) 
	SELECT	0 AS sporttype, Bettype 
	FROM	#SportBettype  
	WHERE	ProductId = 1

	--Sum_winloss
	INSERT INTO #TmpCondSumWL(sporttype, Bettype)
	VALUES(0,0)	
END
IF @ShowCasino = 1
BEGIN
	--INSERT INTO #TmpCond(sporttype, Bettype)
	--VALUES(251,71)

	INSERT INTO #TmpCond(Sporttype, Bettype) 
	SELECT	251 AS sporttype, Bettype 
	FROM	#SportBettype  
	WHERE	ProductId = 6

	--Sum_winloss
	INSERT INTO #TmpCondSumWL(sporttype, Bettype)
	VALUES(251,71), (208,0), (209,0), (210,0)
END
IF @ShowP2P = 1
BEGIN
	--INSERT INTO #TmpCond(sporttype, Bettype)
	--VALUES(253,1000)

	INSERT INTO #TmpCond(Sporttype, Bettype) 
	SELECT	253 AS sporttype, Bettype 
	FROM	#SportBettype  
	WHERE	ProductId = 9

	--Sum_winloss
	INSERT INTO #TmpCondSumWL(sporttype, Bettype)
	VALUES(253,1000)
END
--RaceBook
IF @ShowRB = 1
BEGIN
	--Bettrans
	--INSERT INTO #TmpCond(Sporttype, Bettype)
	--	SELECT 151 AS sporttype, typeid FROM bodb02.dbo.bettype (NOLOCK)
	--	WHERE typeid IN (31,32,33,41,42,43)

	INSERT INTO #TmpCond(Sporttype, Bettype) 
	SELECT	151 AS sporttype, Bettype 
	FROM	#SportBettype  
	WHERE	ProductId = 2

	
	--Sum_winloss
	INSERT INTO #TmpCondSumWL(Sporttype, Bettype)
	SELECT 151, 0	
	
END

IF @ShowNG = 1
BEGIN
	--Bettrans
	--INSERT INTO #TmpCond(Sporttype, Bettype)
	--SELECT 161 AS sporttype, typeid FROM bodb02.dbo.bettype (NOLOCK)
	--WHERE typeid BETWEEN 81 AND 120

	INSERT INTO #TmpCond(Sporttype, Bettype) 
	SELECT	161 AS sporttype, Bettype 
	FROM	#SportBettype  
	WHERE	ProductId = 3


	--Sum_winloss
	INSERT INTO #TmpCondSumWL(Sporttype, Bettype)
	VALUES(161,0)
END
IF @ShowBI = 1
BEGIN
	--INSERT INTO #TmpCond(sporttype, Bettype)
	--VALUES(252,73)

	INSERT INTO #TmpCond(Sporttype, Bettype) 
	SELECT	252 AS sporttype, Bettype 
	FROM	#SportBettype  
	WHERE	ProductId = 7

	--Sum_winloss
	INSERT INTO #TmpCondSumWL(Sporttype, Bettype)
	VALUES(252,73)
END	

IF @showLiveCasino = 1
BEGIN
	--Bettrans
	--INSERT INTO #TmpCond(Sporttype, Bettype)
	--SELECT 162 AS sporttype, typeid FROM bodb02.dbo.bettype (NOLOCK)
	--WHERE typeid BETWEEN 1101 AND 1199

	INSERT INTO #TmpCond(Sporttype, Bettype) 
	SELECT	162 AS sporttype, Bettype 
	FROM	#SportBettype  
	WHERE	ProductId = 4

	--Sum_winloss
	INSERT INTO #TmpCondSumWL(Sporttype, Bettype)
	VALUES(162,0)
END
	
IF @showVS = 1
BEGIN
	--Bettrans
	--INSERT INTO #TmpCond(Sporttype, Bettype)
	--SELECT 180 AS sporttype, typeid FROM bodb02.dbo.bettype (NOLOCK)
	--WHERE typeid BETWEEN 1201 AND 1299

	INSERT INTO #TmpCond(Sporttype, Bettype) 
	SELECT	180 AS sporttype, Bettype 
	FROM	#SportBettype  
	WHERE	ProductId = 5


	--Sum_winloss
	INSERT INTO #TmpCondSumWL(Sporttype, Bettype)
	VALUES(180,0)
END

IF @showKeno = 1
BEGIN
	--Bettrans
	--INSERT INTO #TmpCond(Sporttype, Bettype)
	--SELECT 202 AS sporttype, typeid FROM bodb02.dbo.bettype (NOLOCK)
	--WHERE typeid BETWEEN 1501 AND 1599

	INSERT INTO #TmpCond(Sporttype, Bettype) 
	SELECT	202 AS sporttype, Bettype 
	FROM	#SportBettype  
	WHERE	ProductId = 8
	
	--Sum_winloss
	INSERT INTO #TmpCondSumWL(Sporttype, Bettype)
	VALUES(202,0)
END

IF @showGD = 1
BEGIN
	-- bettrans
	INSERT INTO #TmpCond(Sporttype, Bettype) 
	SELECT	255 AS sporttype, Bettype 
	FROM	#SportBettype  
	WHERE	ProductId = 12

	--Sum_winloss
	INSERT INTO #TmpCondSumWL(sporttype, bettype)
	VALUES(255, 0)
END	
IF @showCB = 1
BEGIN
	-- bettrans
	INSERT INTO #TmpCond(Sporttype, Bettype) 
	SELECT	204 AS sporttype, Bettype 
	FROM	#SportBettype  
	WHERE	ProductId = 15

	--Sum_winloss
	INSERT INTO #TmpCondSumWL(sporttype, bettype)
	VALUES(204, 0)
END
IF @showCF = 1
BEGIN
	-- bettrans
	INSERT INTO #TmpCond(Sporttype, Bettype) 
	SELECT	206 AS sporttype, Bettype 
	FROM	#SportBettype  
	WHERE	ProductId = 19

	--Sum_winloss
	INSERT INTO #TmpCondSumWL(sporttype, bettype)
	VALUES(206, 1003)
END
IF @showAB = 1
BEGIN
	-- bettrans
	INSERT INTO #TmpCond(Sporttype, Bettype) 
	SELECT	211 AS sporttype, Bettype 
	FROM	#SportBettype  
	WHERE	ProductId = 21

	--Sum_winloss
	INSERT INTO #TmpCondSumWL(sporttype, bettype)
	VALUES(211, 0)
END
IF @showVB = 1
BEGIN
	-- bettrans
	INSERT INTO #TmpCond(Sporttype, Bettype) 
	SELECT	212 AS sporttype, Bettype 
	FROM	#SportBettype  
	WHERE	ProductId = 22

	--Sum_winloss
	INSERT INTO #TmpCondSumWL(sporttype, bettype)
	VALUES(212, 0)
END

IF @Todate >= @BalanceUpDay
BEGIN 
    INSERT INTO #ComWinLossDetails
	    SELECT
		    SRecommend,			
			SUM(case when b.liveawayscore = 0 and b.bettype in(33,43) then b.stake/2 else ABS(b.stake) end),	
			 SUM(CASE WHEN b.liveawayscore = 0 and b.bettype in(33,43) THEN ABS(b.stake)/2 
					WHEN b.StatusID IN (112,113) AND b.MOdds IN (-0.25, 0.25) AND s.ProductId = 1 THEN ABS(b.stake)/2
					WHEN b.StatusID = 111 AND s.ProductId = 1 THEN 0 
					WHEN s.ProductID = 21 THEN b.oddsspread -- Allbet
					ELSE ABS(b.stake) 
					END) AS TurnoverNoDraw,
		    --sum(case when b.bettype = 1000 THEN oddsspread else case when tpositiontaking=1 then 0 else scomm/(1-tpositiontaking) end end) as GrossComm,
		    sum(case when tpositiontaking=1 then 0 else scomm/(1-tpositiontaking) end) as GrossComm,
		    sum(winlost-actual_stake), --MemberWinlost
		    sum(playercomm), -- PlayerComm
		    isnull(sum(winlost-actual_stake), 0) + isnull(sum(playercomm), 0), --MemberTotal
		    sum(awinlost), -- AgWinlost
		    isnull(sum(comm-playercomm),0), --AgComm
		    isnull(sum(awinlost+comm-playercomm), 0), --AgTotal			
		    sum(mwinlost), -- MAgWinlost
		    sum(acomm)-sum(comm), --MAgComm
		    isnull(sum(mwinlost), 0) + isnull(sum(acomm), 0)-sum(comm), --MAgTotal
		    sum(swinlost), -- SAgWinlost
		    isnull(sum(scomm),0) -isnull(sum(acomm),0), --SAgComm
		    isnull(sum(swinlost), 0) + isnull(sum(scomm), 0)-sum(acomm), --SAgTotal
		    -(isnull(sum(swinlost), 0) + isnull(sum(awinlost), 0) + isnull(sum(mwinlost), 0) + isnull(sum(scomm), 0) + isnull(sum(winlost-actual_stake), 0)) --Company				
	    FROM
		    bodb02.dbo.bettrans b WITH (NOLOCK) 
			INNER JOIN #TmpCond t ON b.bettype = t.bettype
			LEFT JOIN #SportBettype s ON b.bettype = s.Bettype
	    WHERE
		    b.winlostdate between @FromDate and @todate and
		    b.srecommend in (SELECT custID FROM #tmpSuperList) and
		    b.ruben = 1 and
		    b.statusID not in (101, 102, 103)   and 
		    b.bettype <> 1000
	    GROUP BY SRecommend, CASE WHEN b.bettype = 71 OR b.bettype BETWEEN 2101 AND 2399 THEN 71 ELSE b.bettype END
	    
	-- seperate P2P to improve performance
	IF @showP2P = 1 
	BEGIN 
		INSERT INTO #ComWinLossDetails
	    SELECT
		    SRecommend,			
			SUM(ABS(b.stake)) as TurnOver,
			SUM(ABS(b.stake)) as TurnoverNoDraw,	
		    sum(case when b.bettype = 1000 THEN oddsspread else case when tpositiontaking=1 then 0 else scomm/(1-tpositiontaking) end end) as GrossComm,
		    sum(winlost-actual_stake), --MemberWinlost
		    sum(playercomm), -- PlayerComm
		    isnull(sum(winlost-actual_stake), 0) + isnull(sum(playercomm), 0), --MemberTotal
		    sum(awinlost), -- AgWinlost
		    isnull(sum(comm-playercomm),0), --AgComm
		    isnull(sum(awinlost+comm-playercomm), 0), --AgTotal			
		    sum(mwinlost), -- MAgWinlost
		    sum(acomm)-sum(comm), --MAgComm
		    isnull(sum(mwinlost), 0) + isnull(sum(acomm), 0)-sum(comm), --MAgTotal
		    sum(swinlost), -- SAgWinlost
		    isnull(sum(scomm),0) -isnull(sum(acomm),0), --SAgComm
		    isnull(sum(swinlost), 0) + isnull(sum(scomm), 0)-sum(acomm), --SAgTotal
		    -(isnull(sum(swinlost), 0) + isnull(sum(awinlost), 0) + isnull(sum(mwinlost), 0) + isnull(sum(scomm), 0) + isnull(sum(winlost-actual_stake), 0)) --Company				
	    FROM
		    bodb02.dbo.bettrans b WITH (NOLOCK) INNER JOIN #TmpCond t ON b.bettype = t.bettype
	    WHERE
		    b.winlostdate between @FromDate and @todate and
		    b.srecommend in (SELECT custID FROM #tmpSuperList) and
		    b.ruben = 1 and
		    b.statusID not in (101, 102, 103)  and 
		    b.bettype = 1000
	    GROUP BY SRecommend, b.bettype
	END 

	if @BalanceUpDay < @FromDate
	    select @BalanceUpDay=@FromDate
		
    INSERT INTO #ComWinLossDetails
	    SELECT
		    CustID,			
		    sum(TurnOver), -- TurnOver
			SUM(TunroverNoDraw) as TurnoverNoDraw,
		    sum(grosscomm) as GrossComm,
		    sum(winlost), --MemberWinlost
		    sum(playercomm), -- PlayerComm
		    isnull(sum(winlost), 0) + isnull(sum(playercomm), 0), --MemberTotal
		    sum(awinlost), -- AgWinlost
		    isnull(sum(comm-playercomm),0), --AgComm
		    isnull(sum(awinlost+comm-playercomm), 0), --AgTotal		
		    sum(mwinlost), -- MAgWinlost
		    sum(acomm)-sum(comm), --MAgComm
		    isnull(sum(mwinlost), 0) + isnull(sum(acomm), 0)-sum(comm), --MAgTotal
		    sum(swinlost), -- SAgWinlost
		    isnull(sum(scomm),0) -isnull(sum(acomm),0), --SAgComm
		    isnull(sum(swinlost), 0) + isnull(sum(scomm), 0)-sum(acomm), --SAgTotal
		    -(isnull(sum(swinlost), 0) + isnull(sum(awinlost), 0) + isnull(sum(mwinlost), 0) + isnull(sum(scomm), 0) + isnull(sum(winlost), 0)) --Company					
	    FROM
		    bodb02.dbo.sum_winloss b WITH (NOLOCK) INNER JOIN #TmpCondSumWL t ON b.sporttype = t.sporttype AND b.bettype = t.bettype
	    WHERE
		    winlostdate between @BalanceUpDay and @todate			
		    and SRecommend IN (SELECT custID FROM #tmpSuperList)
		    and RoleID = 4
	    GROUP BY CustID
END

IF @FromDate < @BalanceUpDay 
BEGIN
	if @ToDate >= DATEADD(dd, -1, @BalanceUpDay)
		select @ToDate = DATEADD(dd, -1, @BalanceUpDay)
	
	
	SELECT custid,  srecommend, turnover, TunroverNoDraw as TurnoverNoDraw, winlost, awinlost, mwinlost, swinlost, playercomm, comm, acomm, scomm, grosscomm, sporttype, bettype 
		INTO #Sum_WinLoss_Old
	FROM DBSUM.bodb_Summary.dbo.Sum_WinLoss_Old b WITH(NOLOCK)
	WHERE winlostdate BETWEEN @fromdate AND @ToDate			
		    --and SRecommend IN (SELECT custID FROM #tmpSuperList)
		    AND RoleID = 4 
		    
    INSERT INTO #ComWinLossDetails
	    SELECT
		    CustID,			
		    sum(TurnOver), -- TurnOver
			SUM(TurnoverNoDraw) as TurnoverNoDraw,
		    sum(grosscomm) as GrossComm,
		    sum(winlost), --MemberWinlost
		    sum(playercomm), -- PlayerComm
		    isnull(sum(winlost), 0) + isnull(sum(playercomm), 0), --MemberTotal
		    sum(awinlost), -- AgWinlost
		    isnull(sum(comm-playercomm),0), --AgComm
		    isnull(sum(awinlost+comm-playercomm), 0), --AgTotal		
		    sum(mwinlost), -- MAgWinlost
		    sum(acomm)-sum(comm), --MAgComm
		    isnull(sum(mwinlost), 0) + isnull(sum(acomm), 0)-sum(comm), --MAgTotal
		    sum(swinlost), -- SAgWinlost
		    isnull(sum(scomm),0) -isnull(sum(acomm),0), --SAgComm
		    isnull(sum(swinlost), 0) + isnull(sum(scomm), 0)-sum(acomm), --SAgTotal
		    -(isnull(sum(swinlost), 0) + isnull(sum(awinlost), 0) + isnull(sum(mwinlost), 0) + isnull(sum(scomm), 0) + isnull(sum(winlost), 0)) --Company								
	    FROM
		    #Sum_WinLoss_Old b WITH(NOLOCK) INNER JOIN #TmpCondSumWL t ON b.sporttype = t.sporttype AND b.bettype = t.bettype
	    WHERE
		    --winlostdate between @fromdate and @ToDate			
		     SRecommend IN (SELECT custID FROM #tmpSuperList)
		    --and RoleID = 4
	    GROUP BY CustID

END	

SELECT
	w.CustID, 
	c.UserName, 
	sum(TurnOver) as Turnover,
	SUM(TurnoverNoDraw) as TurnoverNoDraw,
	sum(GrossComm) as GrossComm,
	sum(MemberWinLost) as MemberWinlost,
	sum(PlayerComm) as PlayerComm,
	sum(MemberTotal) as MemberTotal,
	sum(AgWinlost) as AgWinlost,
	sum(AgComm) as AgComm,
	sum(AgTotal) as AgTotal,
	sum(MAgWinlost) as MAgWinlost,
	sum(MAgComm) as MAgComm,
	sum(MAgTotal) as MAgTotal,
	sum(SAgWinlost) as SAgWinlost,
	sum(SAgComm) as SAgComm,
	sum(SAgTotal) as SAgTotal,
	sum(Company) as Company	
FROM #ComWinLossDetails w INNER JOIN bodb02.dbo.custinfo c WITH(NOLOCK) ON w.CustID = c.CustID 
Group by w.CustID, c.UserName
order by c.Username

DROP TABLE #ComWinLossDetails

DROP TABLE #tmpSuperList
DROP TABLE #SportBettype
DROP TABLE #TmpCond
DROP TABLE #TmpCondSumWL

GO

SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO


GO 
 GRANT EXECUTE ON [dbo].[EAS_Rpt_WinLossDetail_Com] TO [bodbExtAccNet]
GO 
 GRANT VIEW DEFINITION ON [dbo].[EAS_Rpt_WinLossDetail_Com] TO [vnteam]
GO 

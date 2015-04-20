USE [bodb_EAS]
GO
/****** Object:  StoredProcedure [dbo].[EAS_Rpt_WinLossDetail_Com]    Script Date: 4/20/2015 4:06:25 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/****** Object:  Stored Procedure dbo.EAS_Rpt_WinLossDetail_Com    Script Date: 3/18/2014 12:25:22 AM ******/
/****** Object:  Stored Procedure dbo.EAS_Rpt_WinLossDetail_Com    Script Date: 3/11/2014 10:33:17 AM ******/
ALTER PROCEDURE [dbo].[EAS_Rpt_WinLossDetail_Com] 	
	@GroupName		VARCHAR(50) = 'ACCTHAI',--ACCTHAI or ACCINDO
	@custid		INT = NULL,	
	@FromDate	SMALLDATETIME,
	@ToDate		SMALLDATETIME,
	@showSB		BIT=1,
	@showCasino BIT=0,
	@showP2P	BIT=0,
	@showRB		BIT=0,	
	@showNG		BIT=0,
	@showBI		BIT=0,
	@showVS		BIT=0,
	@showLiveCasino BIT = 0,
	@showKeno BIT = 0,
	@BalanceUpDay SMALLDATETIME	
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
	- 20140420@Francis: revise SP to use temporary table instead of variable table to improver performance
*/

SET NOCOUNT ON

DECLARE @tmpSuperList TABLE( custID INT)

INSERT INTO @tmpSuperList(CustID)
SELECT custID 
FROM DBAGE.bodb_AGE.dbo.Acc_CustGroup WITH(NOLOCK)
WHERE (@custid IS NULL OR custid = @custid)
	AND GroupName = @GroupName

CREATE TABLE #ComWinLossDetails (CustID int, Turnover money, GrossComm money, MemberWinLost money, 
	PlayerComm money, MemberTotal money, AgWinLost money, AgComm money, AgTotal money, 
	MAgWinLost money, MAgComm money, MAgTotal money, SAgWinLost money, SAgComm money, SAgTotal money, Company money)

DECLARE @TmpCond TABLE(sporttype INT, bettype INT)
DECLARE @TmpCondSumWL TABLE(sporttype INT, bettype INT)
IF @ShowSB = 1
BEGIN
	--Bettrans
	INSERT INTO @TmpCond(Sporttype, Bettype)
	SELECT 0 AS sporttype, typeid FROM bodb02.dbo.bettype (NOLOCK)
	WHERE	typeid < 31 OR typeid BETWEEN 120 AND 999 or typeid between 1301 and 1334
	--Sum_winloss
	INSERT INTO @TmpCondSumWL(sporttype, Bettype)
	VALUES(0,0)	
END
IF @ShowCasino = 1
BEGIN
	INSERT INTO @TmpCond(sporttype, Bettype)
	VALUES(251,71)
	--Sum_winloss
	INSERT INTO @TmpCondSumWL(sporttype, Bettype)
	VALUES(251,71)
END
IF @ShowP2P = 1
BEGIN
	INSERT INTO @TmpCond(sporttype, Bettype)
	VALUES(253,1000)
	--Sum_winloss
	INSERT INTO @TmpCondSumWL(sporttype, Bettype)
	VALUES(253,1000)
END
--RaceBook
IF @ShowRB = 1
BEGIN
	--Bettrans
	INSERT INTO @TmpCond(Sporttype, Bettype)
		SELECT 151 AS sporttype, typeid FROM bodb02.dbo.bettype (NOLOCK)
		WHERE typeid IN (31,32,33,41,42,43)
	
	--Sum_winloss
	INSERT INTO @TmpCondSumWL(Sporttype, Bettype)
		SELECT 151, 0	
	
END

IF @ShowNG = 1
BEGIN
	--Bettrans
	INSERT INTO @TmpCond(Sporttype, Bettype)
	SELECT 161 AS sporttype, typeid FROM bodb02.dbo.bettype (NOLOCK)
	WHERE typeid BETWEEN 81 AND 120

	--Sum_winloss
	INSERT INTO @TmpCondSumWL(Sporttype, Bettype)
	VALUES(161,0)
END
IF @ShowBI = 1
BEGIN
	INSERT INTO @TmpCond(sporttype, Bettype)
	VALUES(252,73)

	--Sum_winloss
	INSERT INTO @TmpCondSumWL(Sporttype, Bettype)
	VALUES(252,73)
END	

IF @showLiveCasino = 1
BEGIN
	--Bettrans
	INSERT INTO @TmpCond(Sporttype, Bettype)
	SELECT 162 AS sporttype, typeid FROM bodb02.dbo.bettype (NOLOCK)
	WHERE typeid BETWEEN 1101 AND 1199

	--Sum_winloss
	INSERT INTO @TmpCondSumWL(Sporttype, Bettype)
	VALUES(162,0)
END
	
IF @showVS = 1
BEGIN
	--Bettrans
	INSERT INTO @TmpCond(Sporttype, Bettype)
	SELECT 180 AS sporttype, typeid FROM bodb02.dbo.bettype (NOLOCK)
	WHERE typeid BETWEEN 1201 AND 1299

	--Sum_winloss
	INSERT INTO @TmpCondSumWL(Sporttype, Bettype)
	VALUES(180,0)
END

IF @showKeno = 1
BEGIN
	--Bettrans
	INSERT INTO @TmpCond(Sporttype, Bettype)
	SELECT 202 AS sporttype, typeid FROM bodb02.dbo.bettype (NOLOCK)
	WHERE typeid BETWEEN 1501 AND 1599
	
	--Sum_winloss
	INSERT INTO @TmpCondSumWL(Sporttype, Bettype)
	VALUES(202,0)
END

IF @Todate >= @BalanceUpDay
BEGIN 
    INSERT INTO #ComWinLossDetails
	    SELECT
		    SRecommend,			
			SUM(case when b.liveawayscore = 0 and b.bettype in(33,43) then b.stake/2 else ABS(b.stake) end),	
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
		    bodb02.dbo.bettrans b WITH (NOLOCK) INNER JOIN @TmpCond t ON b.bettype = t.bettype
	    WHERE
		    b.winlostdate between @FromDate and @todate and
		    b.srecommend in (SELECT custID FROM @tmpSuperList) and
		    b.ruben = 1 and
		    b.statusID not in (101, 102, 103)   and 
		    b.bettype <> 1000
	    GROUP BY SRecommend, b.bettype
	    
	-- seperate P2P to improve performance
	INSERT INTO #ComWinLossDetails
	    SELECT
		    SRecommend,			
			SUM(case when b.liveawayscore = 0 and b.bettype in(33,43) then b.stake/2 else ABS(b.stake) end),	
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
		    bodb02.dbo.bettrans b WITH (NOLOCK) INNER JOIN @TmpCond t ON b.bettype = t.bettype
	    WHERE
		    b.winlostdate between @FromDate and @todate and
		    b.srecommend in (SELECT custID FROM @tmpSuperList) and
		    b.ruben = 1 and
		    b.statusID not in (101, 102, 103)  and 
		    b.bettype = 1000
	    GROUP BY SRecommend, b.bettype
	if @BalanceUpDay < @FromDate
	    select @BalanceUpDay=@FromDate
		
    INSERT INTO #ComWinLossDetails
	    SELECT
		    CustID,			
		    sum(TurnOver), -- TurnOver
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
		    bodb02.dbo.sum_winloss b WITH (NOLOCK) INNER JOIN @TmpCondSumWL t ON b.sporttype = t.sporttype AND b.bettype = t.bettype
	    WHERE
		    winlostdate between @BalanceUpDay and @todate			
		    and SRecommend IN (SELECT custID FROM @tmpSuperList)
		    and RoleID = 4
	    GROUP BY CustID
END

IF @FromDate < @BalanceUpDay 
BEGIN
	if @ToDate >= DATEADD(dd, -1, @BalanceUpDay)
		select @ToDate = DATEADD(dd, -1, @BalanceUpDay)
	
    INSERT INTO #ComWinLossDetails
	    SELECT
		    CustID,			
		    sum(TurnOver), -- TurnOver
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
		    DBSUM.bodb_Summary.dbo.Sum_WinLoss_Old b WITH(NOLOCK) INNER JOIN @TmpCondSumWL t ON b.sporttype = t.sporttype AND b.bettype = t.bettype
	    WHERE
		    winlostdate between @fromdate and @ToDate			
		    and SRecommend IN (SELECT custID FROM @tmpSuperList)
		    and RoleID = 4
	    GROUP BY CustID

END	

SELECT
	w.CustID, 
	c.UserName, 
	sum(TurnOver) as Turnover,
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

GO
GRANT EXECUTE ON [dbo].[EAS_Rpt_WinLossDetail_Com] TO [bodbExtAccNet] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[EAS_Rpt_WinLossDetail_Com] TO [vnteam] AS [dbo]
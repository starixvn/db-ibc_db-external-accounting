/*<info serverAlias="DBEAS-bodb_EAS" executers="bodbExtAccNet" viewers="" isFunction="0" isNested="0"></info>*/
USE [bodb_EAS]
GO

ALTER PROCEDURE [dbo].[EAS_Rpt_WinLossDetail_Com] 	
	@GroupName		VARCHAR(50) = 'ACCTHAI',--ACCTHAI or ACCINDO
	@custid			INT = NULL,	
	@FromDate		SMALLDATETIME,
	@ToDate			SMALLDATETIME,
	@ProductIds		VARCHAR(MAX) = '',
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
	- 20160915@Johnson: Integrate NG2 [RedmineSPU: #30]
	- 20161028@Percy: Support Fishing World [RedmineID: #65735]
	- 20161001@Daniel: Change to REASDPAST when get from bettrans due to pagesplit
	- 20161020@Francis: Avoid pagesplit by prompting index seek on bettrans [Redmine: #65042]
	- 20170622@Percy: Combine Betradar Virtual Sports with Virtual Sports [RedmineID: #78340]
	- 20170703@Percy: Support Keno Lottery [RedmineID: #78068]
	- 20170830@Percy:
		1. Integrate Lucky 3 [RedmineID: #76770]
		2. Change list of @show[ProductCode] to @ProductIDs - apply all new products
	- 20171002@Percy: Hotfix - Duplicated data due to duplicated bettype [RedmineID: #84167]
	- 20180913@Percy: Bullfighting - Add data into TurnoverNoDraw column [RedmineID: #101288]
*/

SET NOCOUNT ON

CREATE TABLE #tmpSuperList (custID INT PRIMARY KEY)

INSERT INTO #tmpSuperList(CustID)
SELECT custID 
FROM DBAGE.bodb_AGE.dbo.Acc_CustGroup WITH(NOLOCK)
WHERE (@custid IS NULL OR custid = @custid)
	AND GroupName = @GroupName

CREATE TABLE #ComWinLossDetails (CustID int, Turnover money, TurnoverNoDraw MONEY, GrossComm money, MemberWinLost money, 
	PlayerComm money, MemberTotal money, AgWinLost money, AgComm money, AgTotal money, 
	MAgWinLost money, MAgComm money, MAgTotal money, SAgWinLost money, SAgComm money, SAgTotal money, Company money)

CREATE TABLE #TmpCondSumWL (sporttype INT, bettype INT)--, PRIMARY KEY NONCLUSTERED (Bettype ASC, sporttype ASC))

SELECT @ProductIds = bodb02.dbo.f_AddRelatedProducts(@ProductIds)

----Get Sport Bettype Matrix------
DECLARE @isTest BIT = 0
SELECT  @isTest = dbo.f_CheckSPVersion(@@PROCID)

CREATE TABLE #SportBettype (ProductID INT, Bettype INT, PRIMARY KEY NONCLUSTERED (Bettype ASC, ProductID ASC))

INSERT INTO #SportBettype (ProductID, Bettype)
SELECT ProductID, Bettype FROM bodb02.dbo.f_SportBettypeMatrixByProduct_Sel(@ProductIds, @isTest) s

INSERT INTO #TmpCondSumWL (sporttype, bettype)
SELECT sporttype, bettype
FROM bodb02.dbo.f_SumWinloss_ConditionSel(@ProductIds)

--Force optimizer to seek on IX_srecommend index
DECLARE @n INT = 2147483647
	
IF @Todate >= @BalanceUpDay
BEGIN 
    INSERT INTO #ComWinLossDetails
	    SELECT
		    SRecommend,			
			SUM(case when b.liveawayscore = 0 and b.bettype in(33,43) then b.stake/2 else ABS(b.stake) end),	
			 SUM(CASE WHEN b.liveawayscore = 0 and b.bettype in(33,43) THEN ABS(b.stake)/2 
					WHEN b.StatusID IN (112,113) AND b.MOdds IN (-0.25, 0.25) AND s.ProductId = 1 THEN ABS(b.stake)/2
					WHEN b.StatusID = 111 AND s.ProductId IN (1,30) THEN 0 -- Sportsbook, Bullfighting
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
		    bodb02.dbo.bettrans b WITH (READPAST)
			INNER JOIN #SportBettype s ON b.bettype = s.Bettype
	    WHERE
		    b.winlostdate between @FromDate and @todate and
		    b.srecommend in (SELECT TOP (@n) custID FROM #tmpSuperList) and
		    b.ruben = 1 and
		    b.statusID not in (101, 102, 103) and 
		    b.bettype <> 1000
	    GROUP BY SRecommend, CASE WHEN b.bettype = 71 OR b.bettype BETWEEN 2101 AND 2399 THEN 71 ELSE b.bettype END
	    OPTION (OPTIMIZE FOR (@n = 1))
	    
	-- seperate P2P to improve performance
	IF EXISTS (SELECT bettype FROM #SportBettype WHERE ProductID = 9)
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
		    bodb02.dbo.bettrans b WITH (NOLOCK) INNER JOIN #SportBettype s ON b.bettype = s.bettype
	    WHERE
		    b.winlostdate between @FromDate and @todate and
		    b.srecommend in (SELECT TOP (@n) custID FROM #tmpSuperList) and
		    b.ruben = 1 and
		    b.statusID not in (101, 102, 103) and 
		    b.bettype = 1000
	    GROUP BY SRecommend, b.bettype
	    OPTION (OPTIMIZE FOR (@n = 1))
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
		     SRecommend IN (SELECT custID FROM #tmpSuperList)
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
DROP TABLE #TmpCondSumWL

GO
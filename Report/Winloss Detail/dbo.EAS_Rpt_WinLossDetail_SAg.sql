USE [bodb_EAS]
GO

ALTER PROCEDURE [dbo].[EAS_Rpt_WinLossDetail_SAg]
	@custid			INT,--srecommend
	@masterid		INT = NULL,
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
	@showNG2		BIT = 0,
	@showFW			BIT = 0,
	@showLO			BIT = 0,
	@BalanceUpDay	SMALLDATETIME,
	@PageSize		INT = 0,
	@PageIndex		INT = 0,
	@TotalRows		INT = 0 OUTPUT
WITH RECOMPILE
AS

/*
Created by: Dan
Date: 2012-11-12
Task : Master Winloss Detail
DB: DBEAS/bodb_EAS
Original SP: [Age_Rpt_WinLossDetail_SAg]
Revisions:
	- 20130121@Dan: Move sp from DB053/bodb02 to DBEAS/bodb_EAS, add linked server DBSUM for bodb_Summary
	- 20140305@Patrick: Add more Keno product(sport:202, bettype between 1501 and 1599)
	- 20150507@Lukas: avoid join remoted table by using local temp table
	- 20150528@Sophia: Apply Gold Deluxe and Sport bettype Matrix [Redmine: #36775]
	- 20150907@Winnie: Add CB [Redmine: #43099]
	- 20151217@Percy: Add Cockfighting [Redmine: #48836]
	- 20160107@Percy: Include new bettype range of the new RNG Casino [Redmine: #48286]
	- 20160215@Percy: Support new product AllBet [Redmine: #50922]
	- 20160225@Sophia: Add new column TurnoverNoDraw [Redmine: #51427]
	- 20160414@Victor: Support new product Voidbridge [Redmine: #55468]
	- 20160809@Percy: Modify Net Turnover for Allbet [RedmineID: #61876]
	- 20160915@Johnson: Integrate NG2 [RedmineSPU: #30]
	- 20161028@Percy: Support Fishing World [RedmineID: #65735]
	- 20170622@Percy: Combine Betradar Virtual Sports with Virtual Sports [RedmineID: #78340]
	- 20170703@Percy: Support Keno Lottery [RedmineID: #78068]
*/

SET NOCOUNT ON

DECLARE @RowStart int, @RowEnd int  
SELECT @PageIndex = @PageIndex - 1, @RowStart = @PageSize * @PageIndex + 1, @RowEnd = @RowStart + @PageSize - 1


DECLARE @SAgWinLossDetails TABLE(CustID int, TurnOver money, TurnoverNoDraw MONEY, GrossComm money, MemberWinLost money, 
	PlayerComm money, MemberTotal money, AgWinLost money, AgComm money, AgTotal money, 
	MAgWinLost money, MAgComm money, MAgTotal money, SAgWinLost money, SAgComm money, SAgTotal money, Company money)

	
DECLARE @TmpCondSumWL TABLE(sporttype INT, bettype INT)
IF @ShowSB = 1
BEGIN
	--Sum_winloss
	INSERT INTO @TmpCondSumWL(sporttype, Bettype)
	VALUES(0,0)	
END
IF @ShowCasino = 1
BEGIN
	--Sum_winloss
	INSERT INTO @TmpCondSumWL(sporttype, Bettype)
	VALUES(251,71), (208,0), (209,0), (210,0)
END
IF @ShowP2P = 1
BEGIN
	--Sum_winloss
	INSERT INTO @TmpCondSumWL(sporttype, Bettype)
	VALUES(253,1000)
END
IF @ShowRB = 1  
BEGIN  
 --Sum_winloss  
 INSERT INTO @TmpCondSumWL(Sporttype, Bettype)  
 SELECT 151,0
END 
IF @ShowNG = 1
BEGIN
	--Sum_winloss
	INSERT INTO @TmpCondSumWL(Sporttype, Bettype)
	VALUES(161,0)
END
IF @ShowBI = 1
BEGIN
	--Sum_winloss
	INSERT INTO @TmpCondSumWL(Sporttype, Bettype)
	VALUES(252,73)
END	
IF @showLiveCasino = 1
BEGIN
	--Sum_winloss  
	INSERT INTO @TmpCondSumWL(Sporttype, Bettype)  
	VALUES(162,0) 
END
IF @showVS = 1
BEGIN
	--Sum_winloss  
	INSERT INTO @TmpCondSumWL(Sporttype, Bettype)  
	VALUES(180,0), (190,0)
END

IF @showKeno = 1
BEGIN
	--Sum_winloss  
	INSERT INTO @TmpCondSumWL(Sporttype, Bettype)  
	VALUES(202,0) 
END

IF @showGD = 1
BEGIN 
	--Sum_winloss  
	INSERT INTO @TmpCondSumWL(Sporttype, Bettype)  
	VALUES(255, 0) 
END
IF @showCB = 1
BEGIN
	--Sum_winloss
	INSERT INTO @TmpCondSumWL(sporttype, bettype)
	VALUES(204, 0)
END
IF @showCF = 1
BEGIN
	--Sum_winloss
	INSERT INTO @TmpCondSumWL(sporttype, bettype)
	VALUES(206, 1003)
END
IF @showAB = 1
BEGIN
	--Sum_winloss
	INSERT INTO @TmpCondSumWL(sporttype, bettype)
	VALUES(211, 0)
END
IF @showVB = 1
BEGIN
	--Sum_winloss
	INSERT INTO @TmpCondSumWL(sporttype, bettype)
	VALUES(212, 0)
END
IF @showNG2 = 1
BEGIN
	--Sum_winloss
	INSERT INTO @TmpCondSumWL(sporttype, bettype)
	VALUES(213, 0)
END
IF @showFW = 1
BEGIN
	--Sum_winloss
	INSERT INTO @TmpCondSumWL(sporttype, bettype)
	VALUES(219, 0)
END
IF @showLO = 1
BEGIN
	--Sum_winloss
	INSERT INTO @TmpCondSumWL(sporttype, bettype)
	VALUES(220, 0)
END

----Get Sport Bettype Matrix------
DECLARE @isTest BIT = 0
SELECT  @isTest = dbo.f_CheckSPVersion(@@PROCID)

DECLARE @SportBettype TABLE(ProductID INT, Bettype INT)
INSERT INTO @SportBettype (ProductID, Bettype)
SELECT ISNULL(p.GroupProductId, s.ProductID), Bettype FROM bodb02.dbo.f_SportBettypeMatrix_Sel(0, 0, 0, 2, '', '', @isTest) s
	LEFT JOIN bodb02.dbo.f_GroupProduct() p ON s.ProductID = p.ProductId
	
IF @Todate >= @BalanceUpDay
BEGIN 
    INSERT INTO @SAgWinLossDetails
	    SELECT
		    MRecommend,			
			sum(case when b.liveawayscore = 0 and b.bettype in(33,43) then ABS(b.stake)/2 else ABS(b.stake) end) as TurnOver,
			SUM(CASE WHEN b.liveawayscore = 0 and b.bettype in(33,43) THEN ABS(b.stake)/2 
					WHEN b.StatusID IN (112,113) AND b.MOdds IN (-0.25, 0.25) AND s.ProductId = 1 THEN ABS(b.stake)/2
					WHEN b.StatusID = 111 AND s.ProductId = 1 THEN 0
					WHEN s.ProductID = 21 THEN b.oddsspread -- Allbet
					ELSE ABS(b.stake) 
					END) AS TurnoverNoDraw,
		    sum(case when b.bettype = 1000 then oddsspread else case when tpositiontaking=1 then 0 else scomm/(1-tpositiontaking) end end) as GrossComm,
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
		    bodb02.dbo.bettrans b WITH (NOLOCK, index=IX_srecommend)
			INNER JOIN @SportBettype s ON b.bettype = s.Bettype
	    WHERE	
			(
				   s.ProductID = CASE WHEN @showSB			= 1 THEN 1  ELSE 0 END
				OR s.ProductID = CASE WHEN @ShowRB			= 1 THEN 2  ELSE 0 END
				OR s.ProductID = CASE WHEN @showCasino		= 1 THEN 6  ELSE 0 END
				OR s.ProductID = CASE WHEN @showP2P			= 1 THEN 9  ELSE 0 END
				OR s.ProductID = CASE WHEN @showNG			= 1 THEN 3  ELSE 0 END
				OR s.ProductID = CASE WHEN @showBI			= 1 THEN 7  ELSE 0 END
				OR s.ProductID = CASE WHEN @showLiveCasino	= 1 THEN 4  ELSE 0 END
				OR s.ProductID = CASE WHEN @showVS			= 1 THEN 5  ELSE 0 END
				OR s.ProductID = CASE WHEN @showKeno		= 1 THEN 8  ELSE 0 END
				OR s.ProductID = CASE WHEN @showGD			= 1 THEN 12 ELSE 0 END
				OR s.ProductID = CASE WHEN @showCB			= 1 THEN 15 ELSE 0 END
				OR s.ProductID = CASE WHEN @showCF			= 1 THEN 19 ELSE 0 END
				OR s.ProductID = CASE WHEN @showAB			= 1 THEN 21 ELSE 0 END
				OR s.ProductID = CASE WHEN @showVB			= 1 THEN 22 ELSE 0 END
				OR s.ProductID = CASE WHEN @showNG2			= 1 THEN 23 ELSE 0 END
				OR s.ProductID = CASE WHEN @showFW			= 1 THEN 24 ELSE 0 END
				OR s.ProductID = CASE WHEN @showLO			= 1 THEN 28 ELSE 0 END
			)
		    AND winlostdate between @FromDate and @todate 
		    AND srecommend = @custid 
		    AND (@masterID is null or b.mrecommend = @masterID)
		    AND b.statusID not in (0,1,101, 102, 103) 
	    GROUP BY MRecommend, CASE WHEN b.bettype = 71 OR b.bettype BETWEEN 2101 AND 2399 THEN 71 ELSE b.bettype END
		
	if @BalanceUpDay < @FromDate
	    select @BalanceUpDay=@FromDate
		
    INSERT INTO @SAgWinLossDetails
	    SELECT
		    CustID,			
		    sum(ABS(TurnOver)) as TurnOver,
			SUM(ABS(TunroverNoDraw)) as TurnoverNoDraw,
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
		    and SRecommend = @custid
		    and (@masterID is null or b.mrecommend = @masterID)
		    and RoleID = 3
	    GROUP BY CustID
END

IF @FromDate < @BalanceUpDay 
BEGIN
	if @ToDate >= DATEADD(dd, -1, @BalanceUpDay)
		select @ToDate = DATEADD(dd, -1, @BalanceUpDay)
	
	
	
	SELECT custid,  mrecommend, turnover,TunroverNoDraw as  TurnoverNoDraw, winlost, awinlost, mwinlost, swinlost, playercomm, comm, acomm, scomm, grosscomm, sporttype, bettype 
		INTO #Sum_WinLoss_Old
	FROM DBSUM.bodb_Summary.dbo.Sum_WinLoss_Old b WITH(NOLOCK)
	WHERE winlostdate BETWEEN @fromdate AND @ToDate			
		    --and SRecommend IN (SELECT custID FROM @tmpSuperList)
		    and SRecommend = @custid
		    AND RoleID = 3 
			and (@masterID is null or b.mrecommend = @masterID)
			
    INSERT INTO @SAgWinLossDetails
	    SELECT
		    CustID,			
		    sum(ABS(TurnOver)) as TurnOver,
			SUM(ABS(TurnoverNoDraw)) as TurnoverNoDraw,
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
		    #Sum_WinLoss_Old b WITH(NOLOCK) INNER JOIN @TmpCondSumWL t ON b.sporttype = t.sporttype AND b.bettype = t.bettype
	    --WHERE
		   -- --winlostdate between @fromdate and @ToDate			
		   -- ----and SRecommend = @custid
		   -- --and 
		   -- (@masterID is null or b.mrecommend = @masterID)		   
	    GROUP BY CustID

   	    --Write log to monitor performance on DB06
--	    EXEC bodb_CustomerLog.dbo.WriteLog_userlog_sumwinloss_old 
--			@CustID = @CustID,
--			@SpName = 'Age_Rpt_WinLossDetail_SAg_thien2'
END	

IF ((@PageSize <= 0) AND (@PageIndex <= 0))
BEGIN
    
    SELECT
	    w.CustID, 
	    c.UserName, 
	    sum(TurnOver) as TurnOver,
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
    FROM @SAgWinLossDetails w INNER JOIN bodb02.dbo.custinfo c WITH(NOLOCK) ON w.CustID = c.CustID 
    Group by w.CustID, c.UserName
    order by c.Username

    
    RETURN
END


IF @TotalRows = 0  
BEGIN  
    SELECT @TotalRows = count(tmp.CustID)
    FROM 
    (
        SELECT CustID
        FROM @SAgWinLossDetails
        Group by CustID
    ) tmp
 
END

SELECT wl.*
FROM
    (
    SELECT
	    w.CustID, 
	    c.UserName, 
	    sum(TurnOver) as TurnOver,
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
	    sum(Company) as Company,
	    ROW_NUMBER() over(order by c.UserName) as RowNum
	    
    FROM @SAgWinLossDetails w INNER JOIN bodb02.dbo.custinfo c WITH(NOLOCK) ON w.CustID = c.CustID 
    Group by w.CustID, c.UserName
    ) wl

WHERE wl.RowNum between @RowStart and @RowEnd


GO

SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO


GO 
 GRANT EXECUTE ON [dbo].[EAS_Rpt_WinLossDetail_SAg] TO [bodbExtAccNet]
GO 
 GRANT VIEW DEFINITION ON [dbo].[EAS_Rpt_WinLossDetail_SAg] TO [vnteam]
GO 

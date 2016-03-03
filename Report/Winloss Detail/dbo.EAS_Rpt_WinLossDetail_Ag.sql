ALTER PROCEDURE [dbo].[EAS_Rpt_WinLossDetail_Ag]
	@CustID int ,--recommend
	@memberID int =  Null,
	@FromDate smalldatetime,
	@ToDate smalldatetime,
	@showSB bit=1,
	@showCasino bit=0,
	@showP2P bit=0,	
	@showRB bit=0,
	@showNG BIT=0,
	@showBI BIT=0,
	@showLiveCasino BIT = 0,
	@showVS BIT = 0,
	@showKeno BIT = 0,
	@showGD BIT = 0,
	@showCB BIT = 0,
	@showCF BIT = 0,
	@BalanceUpDay SMALLDATETIME,
	@PageSize int=0,
	@PageIndex int=0,
	@TotalRows int=0 output
AS
/*
Created by: Scott
Date: 2012-11-15
Task : Member Winloss Detail
DB: DBEAS/bodb_EAS
Original SP: [Age_Rpt_WinLossDetail_Ag]
Revisions:
	- 20130121@Dan: Move sp from DB053/bodb02 to DBEAS/bodb_EAS, add linked server DBSUM for bodb_Summary
	- 20140305@Patrick: Add more Keno product(sport:202, bettype between 1501 and 1599)
	- 20150528@Sophia: Apply Gold Deluxe and Sport bettype Matrix [Redmine: #36775]
	- 20150907@Winnie: Add CB [Redmine: #43099]
	- 20151217@Percy: Add Cockfighting [Redmine: #48836]
	- 20160107@Percy: Include new bettype range of the new RNG Casino [Redmine: #48286]
	- 20160225@Sophia: Add new column TurnoverNoDraw [Redmine: #51427]
*/
SET NOCOUNT ON

DECLARE @RowStart int, @RowEnd int  
SELECT @PageIndex = @PageIndex - 1, @RowStart = @PageSize * @PageIndex + 1, @RowEnd = @RowStart + @PageSize - 1
 
DECLARE @AgWinLossDetails TABLE(CustID int, TurnOver money, TurnoverNoDraw MONEY, GrossComm money, MemberWinLost money, 
	PlayerComm money, MemberTotal money, AgWinLost money, AgComm money, AgTotal money, Company money)

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
 VALUES(180,0) 
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

----Get Sport Bettype Matrix------
DECLARE @SportBettype TABLE(ProductID INT,Bettype INT,EventType INT)
INSERT INTO @SportBettype
EXEC bodb02.dbo.Acc_SportBettypeMatrix_Sel @mode = 4

IF @Todate >= @BalanceUpDay
BEGIN 
    INSERT INTO @AgWinLossDetails
	    SELECT
		    CustID,
			sum(case when b.liveawayscore = 0 and b.bettype in(33,43) then ABS(b.stake)/2 else ABS(b.stake) end) as TurnOver,
			SUM(CASE WHEN b.liveawayscore = 0 and b.bettype in(33,43) THEN ABS(b.stake)/2 
					WHEN b.StatusID IN (112,113) AND b.MOdds IN (-0.25, 0.25) AND s.ProductId = 1 THEN ABS(b.stake)/2
					WHEN b.StatusID = 111 AND s.ProductId = 1 THEN 0 ELSE ABS(b.stake) 
					END) AS TurnoverNoDraw,
		    sum(case when b.bettype = 1000 then oddsspread else comm/(1- apositiontaking) end) as GrossComm,
		    sum(winlost-actual_stake), --MemberWinlost
		    sum(playercomm), -- PlayerComm
		    isnull(sum(winlost-actual_stake), 0) + isnull(sum(playercomm), 0), --MemberTotal
		    sum(awinlost), -- AgWinlost
		    sum(comm-playercomm), --AgComm
		    isnull(sum(awinlost), 0) + isnull(sum(comm-playercomm), 0), --AgTotal
		    -isnull(sum(winlost-actual_stake +awinlost+comm), 0) --Company
	    FROM
		    bodb02.dbo.bettrans b WITH (NOLOCK)
			INNER JOIN @SportBettype s ON b.bettype = s.Bettype
	    WHERE
			(
				s.ProductID = CASE WHEN @showSB = 1 THEN 1 ELSE 0 END
				OR s.ProductID = CASE WHEN @ShowRB = 1 THEN 2 ELSE 0 END
				OR s.ProductID = CASE WHEN @showCasino = 1 THEN 6 ELSE 0 END
				OR s.ProductID = CASE WHEN @showP2P = 1 THEN 9 ELSE 0 END
				OR s.ProductID = CASE WHEN @showNG = 1 THEN 3 ELSE 0 END
				OR s.ProductID = CASE WHEN @showBI = 1 THEN 7 ELSE 0 END
				OR s.ProductID = CASE WHEN @showLiveCasino = 1 THEN 4 ELSE 0 END
				OR s.ProductID = CASE WHEN @showVS = 1 THEN 5 ELSE 0 END
				OR s.ProductID = CASE WHEN @showKeno = 1 THEN 8 ELSE 0 END
				OR s.ProductID = CASE WHEN @showGD = 1 THEN 12 ELSE 0 END
				OR s.ProductID = CASE WHEN @showCB = 1 THEN 15 ELSE 0 END
				OR s.ProductID = CASE WHEN @showCF = 1 THEN 19 ELSE 0 END
			)			
			--(
			--	bettype < case when @showSB=1 then 31 else 0 end
			--	OR bettype between 121 and case when @showSB=1 then 999 else 0 end
			--	OR bettype between 1301 and case when @showSB=1 then 1334 else 0 end
			--	OR bettype between 31 and case when @ShowRB=1 then 49 else 0 end
			--	OR bettype = case when @showCasino=1 then 71 else 0 end
			--	OR bettype = case when @showP2P=1 then 1000 else 0 end
			--	OR bettype BETWEEN 81 AND (CASE WHEN @showNG=1 THEN 120 ELSE 0 END)
			--	OR bettype = (CASE WHEN @showBI =1 THEN 73 ELSE 0 END)
			--	OR bettype BETWEEN 1101 AND (CASE WHEN @showLiveCasino =1 THEN 1199 ELSE 0 END)  
			--	OR bettype BETWEEN 1201 AND (CASE WHEN @showVS=1 THEN 1299 ELSE 0 END)
			--	OR bettype BETWEEN 1501 AND (CASE WHEN @showKeno = 1 THEN 1599 ELSE 0 END)
			--)  
		    AND winlostdate between @FromDate and @todate
		    --and status not in ('VOID', 'REJECT', 'Refund')
		    and b.statusID not in (101, 102, 103)
		    and Recommend=@CustID
		    and ruben=1 
		    and (@memberID is null or b.custid = @memberID)
	    GROUP BY CustID, CASE WHEN b.bettype = 71 OR b.bettype BETWEEN 2101 AND 2399 THEN 71 ELSE b.bettype END

	if @BalanceUpDay < @FromDate
	    select @BalanceUpDay=@FromDate
		
    INSERT INTO @AgWinLossDetails
	    SELECT
		    CustID,			
		    sum(ABS(TurnOver)) as TurnOver,
			SUM(ABS(TurnoverNoDraw)) as TurnoverNoDraw,
		    sum(grosscomm) as GrossComm,
		    sum(winlost), --MemberWinlost
		    sum(playercomm), -- PlayerComm
		    isnull(sum(winlost), 0) + isnull(sum(playercomm), 0), --MemberTotal
		    sum(awinlost), -- AgWinlost
		    sum(comm-playercomm), --AgComm
		    isnull(sum(awinlost), 0) + isnull(sum(comm-playercomm), 0), --AgTotal
		    -isnull(sum(winlost+awinlost+comm), 0) --Company
	    FROM
		    bodb02.dbo.sum_winloss b WITH (NOLOCK) INNER JOIN @TmpCondSumWL t ON b.sporttype = t.sporttype AND b.bettype = t.bettype
	    WHERE
		    winlostdate between @BalanceUpDay and @todate			
		    and recommend=@CustID
		    and RoleID=1
		    and (@memberID is null or b.custid = @memberID)
	    GROUP BY CustID
END

IF @FromDate < @BalanceUpDay 
BEGIN
	if @ToDate >= DATEADD(dd, -1, @BalanceUpDay)
		select @ToDate = DATEADD(dd, -1, @BalanceUpDay)
	
    INSERT INTO @AgWinLossDetails
	    SELECT
		    CustID,			
		    sum(ABS(TurnOver)) as TurnOver,
			SUM(ABS(TurnoverNoDraw)) as TurnoverNoDraw,
		    sum(grosscomm) as GrossComm,
		    sum(winlost), --MemberWinlost
		    sum(playercomm), -- PlayerComm
		    isnull(sum(winlost), 0) + isnull(sum(playercomm), 0), --MemberTotal
		    sum(awinlost), -- AgWinlost
		    sum(comm-playercomm), --AgComm
		    isnull(sum(awinlost), 0) + isnull(sum(comm-playercomm), 0), --AgTotal
		    -isnull(sum(winlost+awinlost+comm), 0) --Company
	    FROM
		    DBSUM.bodb_Summary.dbo.Sum_WinLoss_Old b WITH(NOLOCK) INNER JOIN @TmpCondSumWL t ON b.sporttype = t.sporttype AND b.bettype = t.bettype
	    WHERE
		    winlostdate between @fromdate and @ToDate	
		    and recommend=@custid
		    and RoleID=1
		    and (@memberID is null or b.custid = @memberID)
	    GROUP BY CustID
	    
	    --Write log to monitor performance on DB06
--	    EXEC bodb_CustomerLog.dbo.WriteLog_userlog_sumwinloss_old 
--			@CustID = @CustID,
--			@SpName = 'Age_Rpt_WinLossDetail_Ag'

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
	    sum(Company) as Company
    FROM @AgWinLossDetails w INNER JOIN bodb02.dbo.Customer c WITH(NOLOCK) ON w.CustID = c.CustID 
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
        FROM @AgWinLossDetails
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
        sum(Company) as Company,
        ROW_NUMBER() over (order by c.UserName) as RowNum	
    FROM @AgWinLossDetails w INNER JOIN bodb02.dbo.Customer c WITH(NOLOCK) ON w.CustID = c.CustID 
    Group by w.CustID, c.UserName
    ) wl
    
WHERE wl.RowNum between @RowStart and @RowEnd

GO
GRANT EXECUTE ON [dbo].[EAS_Rpt_WinLossDetail_Ag] TO [bodbExtAccNet]
GO
GRANT VIEW DEFINITION ON [dbo].[EAS_Rpt_WinLossDetail_Ag] TO [vnteam]
GO
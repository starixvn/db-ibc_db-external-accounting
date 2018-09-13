/*<info serverAlias="DBEAS-bodb_EAS" executers="bodbExtAccNet" viewers="" isFunction="0" isNested="0"></info>*/
USE [bodb_EAS]
GO

ALTER PROCEDURE [dbo].[EAS_Rpt_WinLossDetailPokerGames_SAg]
	@custid			INT,--srecommend
	@masterid		INT = NULL,
	@FromDate		SMALLDATETIME,
	@ToDate			SMALLDATETIME,
	@ProductIds		VARCHAR(MAX) = '33',
	@BalanceUpDay	SMALLDATETIME,
	@PageSize		INT = 0,
	@PageIndex		INT = 0,
	@TotalRows		INT = 0 OUTPUT
WITH RECOMPILE
AS

/*
Created by: Sophia
Date: 20180912
Task : Super Poker Games Winloss Detail
DB: DBEAS/bodb_EAS
Original: EAS_Rpt_WinLossDetail_SAg
Revisions:
	
*/

SET NOCOUNT ON

DECLARE @RowStart int, @RowEnd int  
SELECT @PageIndex = @PageIndex - 1, @RowStart = @PageSize * @PageIndex + 1, @RowEnd = @RowStart + @PageSize - 1


DECLARE @SAgWinLossDetails TABLE(CustID int, TurnOver money, TurnoverNoDraw MONEY, GrossComm money, MemberWinLost money, InsGemMemberWinLost money, 
	PlayerComm money, MemberTotal money, InsGemAgWinLost money, AgComm money, AgTotal money, 
	InsGemMAgWinLost money, MAgComm money, MAgTotal money, InsGemSAgWinLost money, SAgComm money, SAgTotal money, Company money)

SELECT @ProductIds = bodb02.dbo.f_AddRelatedProducts(@ProductIds)
	
DECLARE @TmpCondSumWL TABLE(sporttype INT, bettype INT)
INSERT INTO @TmpCondSumWL (sporttype, bettype)
SELECT sporttype, bettype
FROM bodb02.dbo.f_SumWinloss_ConditionSel(@ProductIds)

----Get Sport Bettype Matrix------
DECLARE @isTest BIT = 0
SELECT  @isTest = dbo.f_CheckSPVersion(@@PROCID)

DECLARE @SportBettype TABLE(ProductID INT, Bettype INT)
INSERT INTO @SportBettype (ProductID, Bettype)
SELECT ISNULL(p.GroupProductId, s.ProductID), Bettype FROM bodb02.dbo.f_SportBettypeMatrixByProduct_Sel(@ProductIds, @isTest) s
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
			winlostdate between @FromDate and @todate 
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
	    GROUP BY CustID
END	

IF ((@PageSize <= 0) AND (@PageIndex <= 0))
BEGIN
    
    SELECT
	    w.CustID, 
	    c.UserName, 
	    sum(TurnOver) as TurnOver,
		SUM(TurnoverNoDraw) as TurnoverNoDraw,
	    sum(GrossComm) as TaxComm,
	    sum(MemberWinLost) as MemberWinloss,
		sum(InsGemMemberWinLost) as InsGemMemberWinLoss,
	    sum(PlayerComm) as PlayerComm,
	    sum(MemberTotal) as MemberTotal,
	    sum(InsGemAgWinlost) as InsGemAgWinLoss,
	    sum(AgComm) as AgComm,
	    sum(AgTotal) as AgTotal,
	    sum(InsGemMAgWinlost) as InsGemMAgWinLoss,
	    sum(MAgComm) as MAgComm,
	    sum(MAgTotal) as MAgTotal,
	    sum(InsGemSAgWinlost) as InsGemSAgWinLoss,
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
	    sum(GrossComm) as TaxComm,
		sum(MemberWinLost) as MemberWinLoss,
	    sum(InsGemMemberWinLost) as InsGemMemberWinLoss,
	    sum(PlayerComm) as PlayerComm,
	    sum(MemberTotal) as MemberTotal,
	    sum(InsGemAgWinlost) as InsGemAgWinLoss,
	    sum(AgComm) as AgComm,
	    sum(AgTotal) as AgTotal,
	    sum(InsGemMAgWinlost) as InsGemMAgWinLoss,
	    sum(MAgComm) as MAgComm,
	    sum(MAgTotal) as MAgTotal,
	    sum(InsGemSAgWinlost) as InsGemSAgWinLoss,
	    sum(SAgComm) as SAgComm,
	    sum(SAgTotal) as SAgTotal,
	    sum(Company) as Company,
	    ROW_NUMBER() over(order by c.UserName) as RowNum
	    
    FROM @SAgWinLossDetails w INNER JOIN bodb02.dbo.custinfo c WITH(NOLOCK) ON w.CustID = c.CustID 
    Group by w.CustID, c.UserName
    ) wl

WHERE wl.RowNum between @RowStart and @RowEnd
GO
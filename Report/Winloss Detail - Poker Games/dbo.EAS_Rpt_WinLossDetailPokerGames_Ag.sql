/*<info serverAlias="DBAGE-bodb02" executers="bodbExtAccNet" viewers="" isFunction="0" isNested="0"></info>*/
USE [bodb02]
GO

ALTER PROCEDURE [dbo].[EAS_Rpt_WinLossDetailPokerGames_Ag]
	@CustID			INT,--recommend
	@memberID		INT = NULL,
	@FromDate		SMALLDATETIME,
	@ToDate			SMALLDATETIME,
	@ProductIds		VARCHAR(MAX) = '33',
	@BalanceUpDay	SMALLDATETIME,
	@MoveBetsDay	SMALLDATETIME,
	@PageSize		INT = 0,
	@PageIndex		INT = 0,
	@TotalRows		INT = 0 OUTPUT
AS
/*
	Created by: Sophia
	Date: 20180912
	Task : Agent Poker Games Winloss Detail [Redmine: #101376]
	DB: DBAGE-bodb02
	Original: EAS_Rpt_WinLossDetail_Ag
	Revisions:
		-20180912@Sophia: initial SP
	
*/

SET NOCOUNT ON

DECLARE @RowStart int, @RowEnd int  
SELECT @PageIndex = @PageIndex - 1, @RowStart = @PageSize * @PageIndex + 1, @RowEnd = @RowStart + @PageSize - 1
 
DECLARE @AgWinLossDetails TABLE(CustID int, Turnover money, NetTurnover MONEY, TaxComm money, TotalMemberWinLoss money, MemberWinLoss money, InsGemMemberWinLoss money, 
	PlayerComm money, MemberTotal money, InsGemAgWinLoss money, AgComm money, AgTotal money, Company money)

----Get Sport Bettype Matrix------
DECLARE @isTest BIT = 0
SELECT  @isTest = dbo.f_CheckSPVersion(@@PROCID)

DECLARE @SportBettype TABLE(Bettype INT)
INSERT INTO @SportBettype (Bettype)
SELECT Bettype 
FROM bodb02.dbo.f_SportBettypeMatrixByProduct_Sel(@ProductIds, @isTest) s

----Avoid Parameter Sniffing 
	DECLARE @FDate	SMALLDATETIME,
			@TDate	SMALLDATETIME
	    
	SELECT	@FDate = @FromDate,
			@TDate = @ToDate 
			
IF @ToDate > @MoveBetsDay
	BEGIN
		SELECT	@TDate = @ToDate,
				@FDate = CASE WHEN @FromDate <= @MoveBetsDay THEN DATEADD(DAY, 1, @MoveBetsDay) ELSE @FromDate END
				
		INSERT INTO @AgWinLossDetails
	    SELECT
		    CustID,
			SUM(ABS(b.stake)) as Turnover,
			SUM(CASE WHEN b.bettype = 1499 THEN ABS(b.stake) ELSE ISNULL(CAST(('<xml>' + b.ExtraInfo + '</xml>') AS XML).value('data(/xml/p33/@to)[1]','MONEY'), 0) END ) AS NetTurnover,
			SUM(ISNULL(b.oddsspread,0)) as TaxComm,			
			
			SUM(b.winlost - b.actual_stake) AS TotalMemberWinLoss,			
			SUM(b.winlost - b.actual_stake) - SUM(ISNULL(b.TransID2,0)/ CONVERT(DECIMAL(19,8),10000)) AS MemberWinLoss,			
			SUM(ISNULL(b.TransID2,0)/ CONVERT(DECIMAL(19,8),10000)) AS InsGemMemberWinLoss,			
			SUM(ISNULL(b.playercomm,0)) AS PlayerComm,			
		    SUM(b.winlost - b.actual_stake) + SUM(ISNULL(b.playercomm,0)) as MemberTotal, 
			
			SUM(b.awinlost) AS InsGemAgWinLoss,
			SUM(ISNULL(b.comm,0)) - SUM(ISNULL(b.playercomm,0)) AS AgComm,
			SUM(b.awinlost) + SUM(ISNULL(b.comm,0)) - SUM(ISNULL(b.playercomm,0)) AS AgTotal,	
			
			- (SUM(b.winlost - b.actual_stake) + SUM(b.awinlost) + SUM(ISNULL(b.comm,0))) as Company			 
	    FROM
		    bodb02.dbo.bettrans b WITH (NOLOCK)			
	    WHERE	
		    winlostdate between @FDate and @TDate
		    and b.statusID in (111,112,113)
		    and Recommend = @CustID		
		    and (@memberID is null or b.custid = @memberID)
			AND EXISTS (SELECT 1 FROM @SportBettype s WHERE b.bettype = s.Bettype)
	    GROUP BY CustID 

	END
	
	IF @FromDate <= @MoveBetsDay
	BEGIN
		SELECT  @FDate = @FromDate,
				@TDate = CASE WHEN @ToDate > @MoveBetsDay THEN @MoveBetsDay ELSE @ToDate END
		
		INSERT INTO @AgWinLossDetails
	    SELECT
		   CustID,
			SUM(TurnOver) AS TurnOver,
			SUM(NetTurnover) AS NetTurnover,
		    SUM(TotalComm) AS TaxComm,
		    SUM(Winloss) AS TotalMemberWinLoss,
			SUM(WinLoss) - SUM(InsGemMemberWinLoss) AS MemberWinLoss,
			SUM(InsGemMemberWinLoss) AS InsGemMemberWinLoss,
		    SUM(PlayerComm) AS PlayerComm,			
		    SUM(Winloss) +  SUM(PlayerComm) AS MemberTotal,
			
		    SUM(AgWinLoss) AS InsGemAgWinLoss,
			SUM(AgComm) - SUM(PlayerComm) AS AgComm,
		    SUM(AgWinLoss) +SUM(AgComm) - SUM(PlayerComm) AS AgTotal,
			
			- (SUM(b.Winloss) + SUM(b.AgWinLoss) +SUM(AgComm)) AS Company
	    FROM
		    bodb_Summary.dbo.rptPokerGamesSumWinLoss b WITH(NOLOCK) 
	    WHERE
		    winlostdate between @FDate and @TDate	
		    and recommend=@custid
		    and RoleID=1
		    and (@memberID is null or b.custid = @memberID)
	    GROUP BY CustID
	END


IF ((@PageSize <= 0) AND (@PageIndex <= 0))
BEGIN

    SELECT
	    w.CustID, 
	    c.UserName, 
	    sum(Turnover) as Turnover,
		SUM(NetTurnover) as NetTurnover,
	    sum(TaxComm) as TaxComm,
	    sum(MemberWinLoss) as MemberWinLoss,
		sum(InsGemMemberWinLoss) as InsGemMemberWinLoss,
	    sum(PlayerComm) as PlayerComm,
	    sum(MemberTotal) as MemberTotal,
	    sum(InsGemAgWinLoss) as InsGemAgWinLoss,
	    sum(AgComm) as AgComm,
	    sum(AgTotal) as AgTotal,
	    sum(Company) as Company
    FROM @AgWinLossDetails w 
	INNER JOIN bodb02.dbo.custinfo c WITH(NOLOCK) ON w.CustID = c.CustID 
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
        sum(Turnover) as Turnover,
		SUM(NetTurnover) as NetTurnover,
        sum(TaxComm) as TaxComm,
        sum(MemberWinLoss) as MemberWinLoss,
		sum(InsGemMemberWinLoss) as InsGemMemberWinLoss,
        sum(PlayerComm) as PlayerComm,
        sum(MemberTotal) as MemberTotal,
        sum(InsGemAgWinLoss) as InsGemAgWinLoss,
        sum(AgComm) as AgComm,
        sum(AgTotal) as AgTotal,
        sum(Company) as Company,
        ROW_NUMBER() over (order by c.UserName) as RowNum	
    FROM @AgWinLossDetails w 
	INNER JOIN bodb02.dbo.custinfo c WITH(NOLOCK) ON w.CustID = c.CustID 
    Group by w.CustID, c.UserName
    ) wl
    
WHERE wl.RowNum between @RowStart and @RowEnd
GO
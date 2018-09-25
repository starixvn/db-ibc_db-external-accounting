/*<info serverAlias="DBAGE-bodb02" executers="bodbExtAccNet" viewers="" isFunction="0" isNested="0"></info>*/
USE [bodb02]
GO

ALTER PROCEDURE [dbo].[EAS_Rpt_WinLossDetailPokerGames_Com] 	
	@GroupName		VARCHAR(50) = 'ACCTHAI',--ACCTHAI or ACCINDO
	@custid			INT = NULL,	
	@FromDate		SMALLDATETIME,
	@ToDate			SMALLDATETIME,
	@ProductIds		VARCHAR(MAX) = '33',  --- Poker Games
	@BalanceUpDay	SMALLDATETIME,
	@MoveBetsDay	SMALLDATETIME
AS

/*
	Created by: 20180912@Sophia
	Task : 	Company Poker Games Winloss Detail [redmine: #101376]
	DB: 	DBAGE/bodb02
	Original: EAS_Rpt_WinLossDetail_Com
	Revisions:
		-20180912@Sophia: initial SP
		-20180925@Viet: enhance SP
	
*/

SET NOCOUNT ON

CREATE TABLE #tmpSuperList (custID INT PRIMARY KEY)

INSERT INTO #tmpSuperList(CustID)
SELECT custID 
FROM bodb_AGE.dbo.Acc_CustGroup WITH(NOLOCK)
WHERE (@custid IS NULL OR custid = @custid)
	AND GroupName = @GroupName
	

CREATE TABLE #ComWinLossDetails (CustID int, Turnover money, NetTurnover MONEY, TaxComm money, 
	TotalMemberWinLoss money, MemberWinLoss money, InsGemMemberWinLoss money, 
	PlayerComm money, MemberTotal money, InsGemAgWinLoss money, AgComm money, AgTotal money, 
	InsGemMAgWinLoss money, MAgComm money, MAgTotal money, InsGemSAgWinLoss money, SAgComm money, SAgTotal money, Company money)
  
----Get Sport Bettype Matrix------
DECLARE @isTest BIT = 0
SELECT  @isTest = dbo.f_CheckSPVersion(@@PROCID)

----Avoid Parameter Sniffing 
DECLARE @FDate	SMALLDATETIME,
		@TDate	SMALLDATETIME
	    
SELECT	@FDate = @FromDate,
		@TDate = @ToDate 

--Force optimizer to seek on IX_srecommend index
--DECLARE @n INT = 2147483647
		
IF @ToDate > @MoveBetsDay
	BEGIN
		SELECT	@TDate = @ToDate,
				@FDate = CASE WHEN @FromDate <= @MoveBetsDay THEN DATEADD(DAY, 1, @MoveBetsDay) ELSE @FromDate END
 
		SELECT srecommend, bettype, swinlost, actual_stake, stake, winlost, acomm, comm, playercomm, mwinlost, awinlost, scomm, transid, oddsspread
		INTO #Temp_bettrans
		FROM dbo.bettrans b WITH(NOLOCK, Index = IX_srecommend)
			INNER JOIN #tmpSuperList t ON b.srecommend = t.custID
		WHERE
		    b.winlostdate BETWEEN @FDate and @TDate and
		    b.statusID In (111,112,113) and 
			b.bettype IN (
				SELECT bettype 
				FROM bodb02.dbo.SportBettypeMatrix WITH(NOLOCK) 
				WHERE ProductID = 33 AND (IsTest = 0 OR IsTest = @IsTest)
			)

		IF @@ROWCOUNT > 0
		BEGIN
			INSERT INTO #ComWinLossDetails
			SELECT
				b.SRecommend,						
				SUM(ABS(b.stake)) as Turnover,
				SUM(CASE WHEN b.bettype = 1499 THEN ABS(b.stake) ELSE ISNULL(CAST(('<xml>' + d.ExtraInfo + '</xml>') AS XML).value('data(/xml/p33/@to)[1]','MONEY'), 0) END ) AS NetTurnover,
				SUM(ISNULL(b.oddsspread,0)) as TaxComm,			
			
				SUM(b.winlost - b.actual_stake) AS TotalMemberWinLoss,			
				SUM(b.winlost - b.actual_stake) - SUM(ISNULL(d.TransID2,0)/ CONVERT(DECIMAL(19,8),10000)) AS MemberWinLoss,			
				SUM(ISNULL(d.TransID2,0)/ CONVERT(DECIMAL(19,8),10000)) AS InsGemMemberWinLoss,			
				SUM(ISNULL(b.playercomm,0)) AS PlayerComm,			
				SUM(b.winlost - b.actual_stake) + SUM(ISNULL(b.playercomm,0)) as MemberTotal, 
			
				SUM(b.awinlost) AS InsGemAgWinLoss,
				SUM(ISNULL(b.comm,0)) - SUM(ISNULL(b.playercomm,0)) AS AgComm,
				SUM(b.awinlost) + SUM(ISNULL(b.comm,0)) - SUM(ISNULL(b.playercomm,0)) AS AgTotal,					
			
				SUM(b.mwinlost) AS InsGemMAgWinLoss,
				SUM(ISNULL(b.acomm,0)) - SUM(ISNULL(b.comm,0)) AS MAgComm,
				SUM(b.mwinlost) + SUM(ISNULL(b.acomm,0)) - SUM(ISNULL(b.comm,0)) AS MAgTotal,
			
				SUM(b.swinlost) AS InsGemSAgWinLoss,
				SUM(ISNULL(b.scomm,0)) - SUM(ISNULL(b.acomm,0)) AS SAgComm,
				SUM(b.swinlost) +SUM(ISNULL(b.scomm,0)) - SUM(ISNULL(b.acomm,0)) AS SAgTotal,				
			
				- (SUM(b.winlost - b.actual_stake) + SUM(b.awinlost) + SUM(b.mwinlost) + SUM(b.swinlost) + SUM(ISNULL(b.scomm,0))) as Company		 
			FROM #Temp_bettrans b
				INNER JOIN dbo.bettrans d WITH(NOLOCK) on b.transid = d.transid
			GROUP BY b.srecommend	
		END
		DROP TABLE #Temp_bettrans
	END    
		
	IF @FromDate <= @MoveBetsDay
	BEGIN
		SELECT  @FDate = @FromDate,
				@TDate = CASE WHEN @ToDate > @MoveBetsDay THEN @MoveBetsDay ELSE @ToDate END
		
		
		INSERT INTO #ComWinLossDetails
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
			
			SUM(MAgWinLoss) AS InsGemMAgWinLoss,
			SUM(MAgComm) - SUM(AgComm) AS MAgComm,				
		    SUM(MAgWinLoss) + SUM(MAgComm) - SUM(AgComm) AS MAgTotal,
			
		    SUM(SAgWinLoss) AS InsGemSAgWinLoss,
			SUM(SAgComm) - SUM(MAgComm) AS SAgComm,
				
		    SUM(SAgWinLoss) + SUM(SAgComm) - SUM(MAgComm) AS SAgTotal,
			
		    - (SUM(b.Winloss) + SUM(b.AgWinLoss) + SUM(b.MAgWinLoss) + SUM(b.SAgWinLoss) + SUM(ISNULL(b.SAgComm,0))) AS Company	 			
	    FROM bodb_Summary.dbo.rptPokerGamesSumWinLoss b WITH(NOLOCK)
	    WHERE
		    winlostdate between @FDate and @TDate			
		    and SRecommend IN (SELECT custID FROM #tmpSuperList)
		    and RoleID = 4
	    GROUP BY CustID
	END
	
	
SELECT
	w.CustID, 
	c.UserName, 
	sum(TurnOver) as Turnover,
	SUM(NetTurnover) as NetTurnover,
	sum(TaxComm) as TaxComm,
	sum(MemberWinLoss) as MemberWinLoss,
	sum(InsGemMemberWinLoss) as InsGemMemberWinLoss,
	sum(PlayerComm) as PlayerComm,
	sum(MemberTotal) as MemberTotal,
	sum(InsGemAgWinLoss) as InsGemAgWinLoss,
	sum(AgComm) as AgComm,
	sum(AgTotal) as AgTotal,
	sum(InsGemMAgWinLoss) as InsGemMAgWinLoss,
	sum(MAgComm) as MAgComm,
	sum(MAgTotal) as MAgTotal,
	sum(InsGemSAgWinLoss) as InsGemSAgWinLoss,
	sum(SAgComm) as SAgComm,
	sum(SAgTotal) as SAgTotal,
	sum(Company) as Company	
FROM #ComWinLossDetails w 
INNER JOIN bodb02.dbo.custinfo c WITH(NOLOCK) ON w.CustID = c.CustID 
Group by w.CustID, c.UserName
order by c.Username

DROP TABLE #ComWinLossDetails

DROP TABLE #tmpSuperList
GO
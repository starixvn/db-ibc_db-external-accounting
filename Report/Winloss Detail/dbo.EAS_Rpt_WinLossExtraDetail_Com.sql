/*<info serverAlias="DBAGE-bodb02" executers="bodbExtAccNet" isFunction="0" isNested="0"></info>*/
CREATE PROCEDURE [dbo].[EAS_Rpt_WinLossExtraDetail_Com] 	
	@GroupName		VARCHAR(50) = 'ACCINDO',--ACCTHAI or ACCINDO
	@custid			INT = NULL,	
	@FromDate		SMALLDATETIME,
	@ToDate			SMALLDATETIME,
	@ProductIds		VARCHAR(MAX) = '46',
	@MovebetDay     SMALLDATETIME	
AS
/*
	Created by: Malcolm
	Date: 2020-06-17
	Task : Implement new report to settle IBCBet Live Casino
	DB: DBAGE/bodb02
	Revisions:
		- 20130121@Malcolm: intiate SPs [RedmineID : #135593]
*/

SET NOCOUNT ON

CREATE TABLE #tmpSuperList (custID INT PRIMARY KEY)

INSERT INTO #tmpSuperList(CustID)
SELECT custID 
FROM bodb02.dbo.Acc_CustGroup WITH(NOLOCK)
WHERE (@custid IS NULL OR custid = @custid)
	AND GroupName = @GroupName

CREATE TABLE #ComWinLossDetails (CustID int, Turnover money, TurnoverNoDraw MONEY, GrossComm money, MemberWinLost money, 
	PlayerComm money, MemberTotal money, AgWinLost money, AgComm money, AgTotal money, MAgWinLost money, MAgComm money, 
	MAgTotal money, SAgWinLost money, SAgComm money, SAgTotal money, Company money,ExtraWinloss money, ExtraComm money, ExtraTotal money, 
	NetCompany money,BetCount INT)

SELECT @ProductIds = bodb02.dbo.f_AddRelatedProducts(@ProductIds)

----Get Sport Bettype Matrix------
DECLARE @isTest BIT = 0
SELECT  @isTest = dbo.f_CheckSPVersion(@@PROCID)

CREATE TABLE #SportBettype (ProductID INT, Bettype INT, PRIMARY KEY NONCLUSTERED (Bettype ASC, ProductID ASC))

INSERT INTO #SportBettype (ProductID, Bettype)
SELECT ProductID, Bettype FROM bodb02.dbo.f_SportBettypeMatrixByProduct_Sel(@ProductIds, @isTest) s


--Force optimizer to seek on IX_srecommend index
DECLARE @n INT = 2147483647
	

IF @ToDate > @MovebetDay
	BEGIN
		INSERT INTO #ComWinLossDetails
		SELECT
			SRecommend,			
			SUM(ABS(b.stake)),	
			SUM(CASE WHEN b.StatusID IN (112,113) AND b.MOdds IN (-0.25, 0.25) AND s.ProductId = 1 THEN ABS(b.stake)/2
					 WHEN b.StatusID = 111 AND s.ProductId IN (1) THEN 0 -- Sportsbook
					 WHEN s.ProductID IN (21, 39, 45, 46, 47)  THEN b.oddsspread -- Allbet, SA Gaming, SexyGaming, IBCBet Live Casino, BBIN
				ELSE ABS(b.stake) END) AS TurnoverNoDraw,
			SUM(CASE WHEN tpositiontaking = 1 THEN 0 ELSE scomm/(1-tpositiontaking) END) AS GrossComm,
			SUM(winlost-actual_stake), --MemberWinlost
			SUM(playercomm), -- PlayerComm
			SUM(winlost-actual_stake) + sum(playercomm), --MemberTotal
			SUM(awinlost), -- AgWinlost
			SUM(comm-playercomm), --AgComm
			SUM(awinlost+comm-playercomm), --AgTotal			
			SUM(mwinlost), -- MAgWinlost
			SUM(acomm)-SUM(comm), --MAgComm
			SUM(mwinlost) + SUM(acomm)-SUM(comm), --MAgTotal
			SUM(swinlost), -- SAgWinlost
			SUM(scomm) - SUM(acomm), --SAgComm
			SUM(swinlost) + SUM(scomm) -SUM(acomm), --SAgTotal
			-(SUM(swinlost) + SUM(awinlost) + SUM(mwinlost) + SUM(scomm) + SUM(winlost-actual_stake)), --Company,
			SUM((winlost - actual_stake) * epositiontaking), -- extra win loss
			-SUM(scomm),--extra comm
			SUM((winlost - actual_stake) * epositiontaking - scomm),-- extra total
			-SUM((winlost - actual_stake) - swinlost - mwinlost - awinlost),-- net company
			COUNT(1) BetCount

		FROM bodb02.dbo.bettrans b WITH (READPAST)
					INNER JOIN #SportBettype s ON b.bettype = s.Bettype
		WHERE b.winlostdate between @FromDate and @todate and
			  b.srecommend in (SELECT TOP (@n) custID FROM #tmpSuperList) and
			  b.ruben = 1 and
			  b.statusID not in (101, 102, 103)
		GROUP BY srecommend
		OPTION (OPTIMIZE FOR (@n = 1))
	END

IF @FromDate <= @MovebetDay
BEGIN
    SELECT @ToDate = @MovebetDay

	INSERT INTO #ComWinLossDetails
	SELECT
		CustID,			
		SUM(TurnOver), -- TurnOver
		SUM(TunroverNoDraw) as TurnoverNoDraw,
		SUM(GrossComm) as GrossComm,
		SUM(WinLoss), --MemberWinlost
		SUM(PlayerComm), -- PlayerComm
		SUM(WinLoss)+ SUM(playercomm), --MemberTotal
		SUM(AgWinLoss), -- AgWinlost
		SUM(AgComm), --AgComm
		SUM(AgWinLoss+AgComm), --AgTotal		
		SUM(MAgWinLoss), -- MAgWinlost
		SUM(MAgComm), --MAgComm
		SUM(MAgWinLoss) + SUM(MAgComm) ,--MAgTotal
		SUM(SAgWinLoss), -- SAgWinlost
		SUM(SAgComm), --SAgComm
		SUM(SAgWinLoss) + SUM(SAgComm), --SAgTotal
		 -(SUM(SAgWinLoss) + SUM(AgWinLoss) + SUM(MAgWinLoss) - SUM(ExtraComm) + SUM(WinLoss)),-- Company
        SUM(ExtraWinloss),--ExtraWinloss
	    SUM(ExtraComm),--ExtraComm
		SUM(ExtraWinloss) + SUM(ExtraComm), --ExtraTotal
		-SUM(WinLoss - SAgWinLoss - MAgWinLoss - AgWinLoss), -- NetCompany
		SUM(BetCount) --BetCount
	FROM bodb_Summary.dbo.sum_winloss_extra b WITH (NOLOCK) 
	WHERE winlostdate between @FromDate and @todate			
		and SRecommend IN (SELECT custID FROM #tmpSuperList)
		and RoleID = 4
		AND EXISTS(SELECT 1 FROM bodb02.dbo.strSplit(@ProductIds,',') WHERE val = b.ProductId)
	GROUP BY CustID
END

SELECT
	w.CustID				AS CustID, 
	c.UserName				AS Username, 
	SUM(TurnOver)			AS Turnover,
	SUM(TurnoverNoDraw)		AS TurnoverNoDraw,
	SUM(GrossComm)			AS GrossComm,
	SUM(MemberWinLost)		AS MemberWinlost,
	SUM(PlayerComm)			AS PlayerComm,
	SUM(MemberTotal)		AS MemberTotal,
	SUM(AgWinlost)			AS AgWinlost,
	SUM(AgComm)				AS AgComm,
	SUM(AgTotal)			AS AgTotal,
	SUM(MAgWinlost)			AS MAgWinlost,
	SUM(MAgComm)			AS MAgComm,
	SUM(MAgTotal)			AS MAgTotal,
	SUM(SAgWinlost)			AS SAgWinlost,
	SUM(SAgComm)			AS SAgComm,
	SUM(SAgTotal)			AS SAgTotal,
	SUM(Company)			AS Company,
	SUM(ExtraWinloss)		AS ExtWinloss,
	SUM(ExtraComm)			AS ExtComm,
	SUM(ExtraTotal)			AS ExtTotal,
	SUM(NetCompany)			AS NetCompany
FROM #ComWinLossDetails w INNER JOIN bodb02.dbo.custinfo c WITH(NOLOCK) ON w.CustID = c.CustID 
Group by w.CustID, c.UserName
order by c.Username


DROP TABLE #ComWinLossDetails

DROP TABLE #tmpSuperList
DROP TABLE #SportBettype

GO
/*<info serverAlias="DBAGE-bodb02" executers="bodbExtAccNet" isFunction="0" isNested="0"></info>*/
CREATE PROCEDURE [dbo].[EAS_Rpt_WinLossExtraDetail_Com] 	
	@GroupName		VARCHAR(50) = 'ACCTHAI',--ACCTHAI or ACCINDO
	@custid			INT = NULL,	
	@FromDate		SMALLDATETIME,
	@ToDate			SMALLDATETIME,
	@ProductIds		VARCHAR(MAX) = '',
	@BalanceUpDay	SMALLDATETIME	
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
	MAgTotal money, SAgWinLost money, SAgComm money, SAgTotal money, Company money,ExtWinloss money, ExtComm money, ExtTotal money, 
	NetCompany money)

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
			SUM(ABS(b.stake)),	
			 SUM(CASE WHEN b.StatusID IN (112,113) AND b.MOdds IN (-0.25, 0.25) AND s.ProductId = 1 THEN ABS(b.stake)/2
					WHEN b.StatusID = 111 AND s.ProductId IN (1) THEN 0 -- Sportsbook
					WHEN s.ProductID IN (21, 39, 45, 46, 47)  THEN b.oddsspread -- Allbet, SA Gaming, SexyGaming, IBCBet Live Casino, BBIN
					ELSE ABS(b.stake) 
					END) AS TurnoverNoDraw,
		    SUM(CASE WHEN tpositiontaking = 1 THEN 0 ELSE scomm/(1-tpositiontaking) END) AS GrossComm,
		    sum(winlost-actual_stake), --MemberWinlost
		    sum(playercomm), -- PlayerComm
		    sum(winlost-actual_stake) + sum(playercomm), --MemberTotal
		    sum(awinlost), -- AgWinlost
		    sum(comm-playercomm), --AgComm
		    sum(awinlost+comm-playercomm), --AgTotal			
		    sum(mwinlost), -- MAgWinlost
		    sum(acomm)-sum(comm), --MAgComm
		    sum(mwinlost) + sum(acomm)-sum(comm), --MAgTotal
		    sum(swinlost), -- SAgWinlost
		    sum(scomm) - sum(acomm), --SAgComm
		    sum(swinlost) + sum(scomm) -sum(acomm), --SAgTotal
		    -(sum(swinlost) + sum(awinlost) + sum(mwinlost) + sum(scomm) + sum(winlost-actual_stake)), --Company,
			sum(winlost * epositiontaking) - sum(actual_stake * epositiontaking), -- extra win loss
			-sum(scomm),--extra comm
			sum(winlost + comm),-- extra total
			-sum((winlost - actual_stake) - swinlost - mwinlost - awinlost)-- net company
	    FROM
		    bodb02.dbo.bettrans b WITH (READPAST)
			INNER JOIN #SportBettype s ON b.bettype = s.Bettype
	    WHERE
		    b.winlostdate between @FromDate and @todate and
		    b.srecommend in (SELECT TOP (@n) custID FROM #tmpSuperList) and
		    b.ruben = 1 and
		    b.statusID not in (101, 102, 103)
	    GROUP BY SRecommend, CASE WHEN b.bettype = 71 OR b.bettype BETWEEN 2101 AND 2399 THEN 71 ELSE b.bettype END
	    OPTION (OPTIMIZE FOR (@n = 1))
END

--SELECT
--	w.CustID, 
--	c.UserName, 
--	sum(TurnOver) as Turnover,
--	SUM(TurnoverNoDraw) as TurnoverNoDraw,
--	sum(GrossComm) as GrossComm,
--	sum(MemberWinLost) as MemberWinlost,
--	sum(PlayerComm) as PlayerComm,
--	sum(MemberTotal) as MemberTotal,
--	sum(AgWinlost) as AgWinlost,
--	sum(AgComm) as AgComm,
--	sum(AgTotal) as AgTotal,
--	sum(MAgWinlost) as MAgWinlost,
--	sum(MAgComm) as MAgComm,
--	sum(MAgTotal) as MAgTotal,
--	sum(SAgWinlost) as SAgWinlost,
--	sum(SAgComm) as SAgComm,
--	sum(SAgTotal) as SAgTotal,
--	sum(Company) as Company,
--	sum(ExtWinloss) AS ExtWinloss,
--	sum(ExtComm) AS ExtComm,
--	sum(ExtTotal) AS ExtTotal,
--	sum(NetCompany) AS NetCompany
--FROM #ComWinLossDetails w INNER JOIN bodb02.dbo.custinfo c WITH(NOLOCK) ON w.CustID = c.CustID 
--Group by w.CustID, c.UserName
--order by c.Username


SELECT
	1, 
	10, 
	1110000 as Turnover,
	2000 as TurnoverNoDraw,
	2000 as GrossComm,
	2000 as MemberWinlost,
	2000 as PlayerComm,
	2000 as MemberTotal,
	2000 as AgWinlost,
	2000 as AgComm,
	2000 as AgTotal,
	2000 as MAgWinlost,
	2000 as MAgComm,
	2000 as MAgTotal,
	2000 as SAgWinlost,
	2000 as SAgComm,
	2000 as SAgTotal,
	2000 as Company,
	2000 AS ExtWinloss,
	2000 AS ExtComm,
	2000 AS ExtTotal,
	2000 AS NetCompany


DROP TABLE #ComWinLossDetails

DROP TABLE #tmpSuperList
DROP TABLE #SportBettype
DROP TABLE #TmpCondSumWL

GO
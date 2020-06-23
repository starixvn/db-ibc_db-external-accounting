/*<info serverAlias="DBAGE-bodb02" executers="bodbExtAccNet" isFunction="0" isNested="0"></info>*/
CREATE PROCEDURE [dbo].[EAS_Rpt_WinLossDetailExtra_Com] 	
	@GroupName		VARCHAR(50) = 'ACCINDO',
	@CustId         INT = NULL,
	@ProductIds		VARCHAR(MAX) = '46',
	@FromDate		SMALLDATETIME,
	@ToDate			SMALLDATETIME,
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
WHERE (@custid IS NULL OR custid = @custid) AND GroupName = @GroupName

CREATE TABLE #ComWinLossDetails 
(	
	CustID			INT, 
	Turnover		MONEY,
	TurnoverNoDraw	MONEY, 
	GrossComm		MONEY, 
	MemberWinLost	MONEY, 
	PlayerComm		MONEY, 
	MemberTotal		MONEY, 
	SAgWinLost		MONEY, 
	SAgComm			MONEY, 
	SAgTotal		MONEY, 
	ExtraWinloss	MONEY, 
	ExtraComm		MONEY, 
	ExtraTotal		MONEY, 
	NetCompany		MONEY,
	BetCount		INT
)

DECLARE @isTest BIT = 0
SELECT  @isTest = dbo.f_CheckSPVersion(@@PROCID)

CREATE TABLE #Product 
(	
	ProductID INT, 
	Bettype INT, 
	PRIMARY KEY NONCLUSTERED (Bettype ASC, ProductID ASC)
)

INSERT INTO #Product (ProductID, Bettype)
SELECT DISTINCT ProductID, Bettype 
FROM bodb02.dbo.f_SportBettypeMatrixByProduct_Sel(@ProductIds, @isTest) 

IF @ToDate > @MovebetDay
	BEGIN
		INSERT INTO #ComWinLossDetails
		SELECT
			SRecommend,																				-- CustId		
			SUM(ABS(b.stake)),																		-- Turnover
			SUM(CASE WHEN s.ProductID = 46 THEN b.oddsspread ELSE ABS(stake) END),					-- TurnoverNoDraw(net Turnover)
			SUM(CASE WHEN tpositiontaking = 1 THEN 0 ELSE scomm/(1-tpositiontaking) END),			-- GrossComm,
			SUM(winlost-actual_stake),																-- MemberWinlost
			SUM(playercomm),																		-- PlayerComm
			SUM(winlost-actual_stake) + sum(playercomm),											-- MemberTotal			
			SUM(swinlost),																			-- SAgWinlost
			SUM(scomm) - SUM(acomm),																-- SAgComm
			SUM(swinlost) + SUM(scomm) -SUM(acomm),													-- SAgTotal
			SUM((winlost - actual_stake) * epositiontaking),										-- Extra win loss
			-SUM(scomm),																			-- Extra comm
			SUM((winlost - actual_stake) * epositiontaking - scomm),								-- Extra total
			-SUM((winlost - actual_stake) * (1 + epositiontaking) + swinlost + mwinlost + awinlost),-- Net company
			COUNT(1)																				-- Bet Count

		FROM bodb02.dbo.bettrans b WITH (NOLOCK)
			INNER JOIN #Product s ON b.bettype = s.Bettype
		WHERE b.winlostdate BETWEEN @FromDate AND @todate 
			AND b.srecommend IN (SELECT  custID FROM #tmpSuperList) 
			AND b.ruben = 1 
			AND b.statusID NOT IN (101, 102, 103)
		GROUP BY srecommend
	END

IF @FromDate <= @MovebetDay
BEGIN
    SELECT @ToDate = @MovebetDay

	INSERT INTO #ComWinLossDetails
	SELECT
		CustID,																--	CustId
		SUM(Turnover),														--	Turnover
		SUM(TunroverNoDraw),												--	TurnoverNoDraw(net Turnover),
		SUM(GrossComm) ,													--	GrossComm,
		SUM(WinLoss),														--	MemberWinlost
		SUM(PlayerComm),													--	PlayerComm
		SUM(WinLoss)+ SUM(playercomm),										--	MemberTotal	
		SUM(SAgWinLoss),													--	SAgWinlost
		SUM(SAgComm),														--	SAgComm
		SUM(SAgWinLoss) + SUM(SAgComm),										--	SAgTotal
        SUM(ExtraWinloss),													--	ExtraWinloss
	    SUM(ExtraComm),														--	ExtraComm
		SUM(ExtraWinloss) + SUM(ExtraComm),									--	ExtraTotal
		-SUM(WinLoss + SAgWinLoss + MAgWinLoss + AgWinLoss + ExtraWinloss),	--	NetCompany
		SUM(BetCount)														--	BetCount
	FROM bodb_Summary.dbo.Sum_Winloss_Extra b WITH (NOLOCK) 
	WHERE winlostdate between @FromDate and @todate			
		AND CustId IN (SELECT custID FROM #tmpSuperList)
		AND RoleID = 4
		AND EXISTS(SELECT 1 FROM bodb02.dbo.strSplit(@ProductIds,',') WHERE val = b.ProductId) 
	GROUP BY CustID
END

SELECT
	w.CustID				AS CustId, 
	c.UserName				AS Username, 
	SUM(Turnover)			AS Turnover,
	SUM(TurnoverNoDraw)		AS TurnoverNoDraw, --(Net Turnover)
	SUM(GrossComm)			AS GrossComm,
	SUM(MemberWinLost)		AS MemberWinlost,
	SUM(PlayerComm)			AS PlayerComm,
	SUM(MemberTotal)		AS MemberTotal,
	SUM(SAgWinlost)			AS SAgWinlost,
	SUM(SAgComm)			AS SAgComm,
	SUM(SAgTotal)			AS SAgTotal,
	SUM(ExtraWinloss)		AS ExtWinloss,
	SUM(ExtraComm)			AS ExtComm,
	SUM(ExtraTotal)			AS ExtTotal,
	SUM(NetCompany)			AS NetCompany
FROM #ComWinLossDetails w 
	INNER JOIN bodb02.dbo.custinfo c WITH(NOLOCK) ON w.CustID = c.CustID 
GROUP BY w.CustID, c.UserName
ORDER BY c.Username


DROP TABLE #ComWinLossDetails

DROP TABLE #tmpSuperList

DROP TABLE #Product

GO
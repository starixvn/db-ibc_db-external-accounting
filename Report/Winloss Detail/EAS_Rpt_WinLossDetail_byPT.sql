/*<info serverAlias="DBAGE-bodb02" executers="bodbExtAccNet" isFunction="0" isNested="0"></info>*/
CREATE PROCEDURE [dbo].[EAS_Rpt_WinLossDetail_byPT] 	
	@GroupName		VARCHAR(50) = 'ACCINDO',
	@CustId         INT = NULL,
	@ProductIds		VARCHAR(MAX) = '46',
	@FromDate		SMALLDATETIME,
	@ToDate			SMALLDATETIME,
	@MovebetDay     SMALLDATETIME	
AS
/*
	Created by: Danny
	Date: 2020-10-13
	Task : Implement new report details win/lost by PT 
	DB: DBAGE/bodb02
	Revisions:
		- 20201013@Danny: intiate SPs [RedmineID : #139937]
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
	PT				SMALLMONEY,
	ProductID		INT,
	Turnover		MONEY,
	GrossComm		MONEY, 
	MAgTotal		MONEY, 
	SAgWinLost		MONEY, 
	SAgComm			MONEY, 
	SAgTotal		MONEY, 
	Company			MONEY,
	BetCount		INT
)


CREATE TABLE #ComWinLossDetailsByPT
(
	CustID			INT, 
	PT				SMALLMONEY,
	Name			NVARCHAR(100),
	Turnover		MONEY,
	GrossComm		MONEY, 
	MAgTotal		MONEY, 
	SAgWinLost		MONEY, 
	SAgComm			MONEY, 
	SAgTotal		MONEY, 
	Company			MONEY,
	BetCount		INT,
	DisplayOrder	TINYINT	
);


DECLARE @isTest BIT = 0
SELECT  @isTest = dbo.f_CheckSPVersion(@@PROCID)

CREATE TABLE #Product 
(	
	ProductID INT, 
	Bettype INT, 
	RefTable TINYINT
	PRIMARY KEY NONCLUSTERED (Bettype ASC, ProductID ASC, RefTable  ASC)
)

INSERT INTO #Product (ProductID, Bettype, RefTable)
SELECT DISTINCT ProductID, Bettype , RefTable
FROM bodb02.dbo.f_SportBettypeMatrixByProduct_Sel(@ProductIds, @isTest) 

IF @ToDate > @MovebetDay
	BEGIN
		INSERT INTO #ComWinLossDetails
		SELECT
			SRecommend,																											-- SRecommend
			tpositiontaking,																									-- tpositiontaking
			s.ProductID,																										-- ProductID
			SUM(ABS(b.stake)),																									-- Turnover
			SUM(CASE WHEN tpositiontaking = 1 THEN 0 ELSE scomm/(1-tpositiontaking) END),										-- GrossComm,
			SUM(winlost-actual_stake) + SUM(mwinlost) + SUM(awinlost) + SUM(acomm) AS MAgTotal,									-- MAgTotal
			SUM(swinlost),																										-- SAgWinlost
			SUM(scomm) - SUM(acomm),																							-- SAgComm
			SUM(swinlost) + SUM(scomm) -SUM(acomm),																				-- SAgTotal
			-(SUM(winlost-actual_stake) + SUM(mwinlost) + SUM(awinlost) + SUM(acomm)) - (SUM(swinlost) + SUM(scomm) -SUM(acomm)),-- Company
			COUNT(1)																											-- Bet Count

		FROM bodb02.dbo.bettrans b WITH (NOLOCK)
			INNER JOIN #Product s ON b.bettype = s.Bettype AND s.RefTable IN (0,3)
		WHERE b.winlostdate BETWEEN @FromDate AND @todate 
			AND b.srecommend IN (SELECT custID FROM #tmpSuperList) 
			AND b.ruben = 1 
			AND b.statusID NOT IN (101, 102, 103)
		GROUP BY srecommend, tpositiontaking, s.ProductID

		INSERT INTO #ComWinLossDetails
		SELECT
			SRecommend,																											-- SRecommend
			tpositiontaking,																									-- tpositiontaking
			s.ProductID,																										-- ProductID
			SUM(ABS(b.stake)),																									-- Turnover
			SUM(CASE WHEN tpositiontaking = 1 THEN 0 ELSE scomm/(1-tpositiontaking) END),										-- GrossComm,
			SUM(winlost-actual_stake) + SUM(mwinlost) + SUM(awinlost) + SUM(acomm) AS MAgTotal,									-- MAgTotal
			SUM(swinlost),																										-- SAgWinlost
			SUM(scomm) - SUM(acomm),																							-- SAgComm
			SUM(swinlost) + SUM(scomm) -SUM(acomm),																				-- SAgTotal
			-(SUM(winlost-actual_stake) + SUM(mwinlost) + SUM(awinlost) + SUM(acomm)) - (SUM(swinlost) + SUM(scomm) -SUM(acomm)),-- Company
			COUNT(1)																											-- Bet Count

		FROM bodb02.dbo.bettransRnG b WITH (NOLOCK)
			INNER JOIN #Product s ON b.gameID = s.Bettype
		WHERE b.winlostdate BETWEEN @FromDate AND @todate 
			AND b.srecommend IN (SELECT custID FROM #tmpSuperList) 
			AND b.statusID NOT IN (101, 102, 103)
		GROUP BY srecommend, tpositiontaking, s.ProductID

		INSERT INTO #ComWinLossDetails
		SELECT
			SRecommend,																											-- SRecommend
			tpositiontaking,																									-- tpositiontaking
			s.ProductID,																										-- ProductID
			SUM(ABS(b.stake)),																									-- Turnover
			SUM(CASE WHEN tpositiontaking = 1 THEN 0 ELSE scomm/(1-tpositiontaking) END),										-- GrossComm,
			SUM(winlost-actual_stake) + SUM(mwinlost) + SUM(awinlost) + SUM(acomm) AS MAgTotal,									-- MAgTotal
			SUM(swinlost),																										-- SAgWinlost
			SUM(scomm) - SUM(acomm),																							-- SAgComm
			SUM(swinlost) + SUM(scomm) -SUM(acomm),																				-- SAgTotal
			-(SUM(winlost-actual_stake) + SUM(mwinlost) + SUM(awinlost) + SUM(acomm)) - (SUM(swinlost) + SUM(scomm) -SUM(acomm)),-- Company
			COUNT(1)																											-- Bet Count

		FROM bodb02.dbo.bettransLC b WITH (NOLOCK)
			INNER JOIN #Product s ON b.gameID = s.Bettype
		WHERE b.winlostdate BETWEEN @FromDate AND @todate 
			AND b.srecommend IN (SELECT custID FROM #tmpSuperList) 
			AND b.statusID NOT IN (101, 102, 103)
		GROUP BY srecommend, tpositiontaking, s.ProductID


	END

IF @FromDate <= @MovebetDay
BEGIN
    IF @ToDate > @MovebetDay
    SELECT @ToDate = @MovebetDay

	INSERT INTO #ComWinLossDetails
	SELECT
		CustID,																									--	CustId
		PT,																										--  PT
		ProductID,																								--  ProductID
		SUM(Turnover),																							--	Turnover
		SUM(GrossComm) ,																						--	GrossComm
		SUM(Winloss) + SUM(MAgWinLoss) + SUM(AgWinLoss) + SUM(MAgComm),											--  MAgTotal
		SUM(SAgWinLoss),																						--	SAgWinlost
		SUM(SAgComm),																							--	SAgComm
		SUM(SAgWinLoss) + SUM(SAgComm),																			--	SAgTotal
		-(SUM(Winloss) + SUM(MAgWinLoss) + SUM(AgWinLoss) + SUM(MAgComm)) - (SUM(SAgWinLoss) + SUM(SAgComm)),	--	Company
		SUM(BetCount)																							--	BetCount
	FROM bodb_Summary.dbo.Sum_Winloss_byPT b WITH (NOLOCK) 
	WHERE winlostdate between @FromDate and @todate			
		AND CustId IN (SELECT custID FROM #tmpSuperList)
		AND RoleID = 4
		AND EXISTS(SELECT 1 FROM bodb02.dbo.strSplit(@ProductIds,',') WHERE val = b.ProductId) 
	GROUP BY CustID,PT,	ProductID

END

INSERT INTO #ComWinLossDetailsByPT(CustID,Name,Turnover,GrossComm,MAgTotal,SAgWinLost,SAgComm,SAgTotal,Company,BetCount,DisplayOrder)
SELECT	w.CustID AS CustId, 
		c.UserName, 
		SUM(TurnOver) as Turnover,
		SUM(GrossComm) as GrossComm,
		SUM(MAgTotal) as MAgTotal,
		SUM(SAgWinlost) as SAgWinLoss,
		SUM(SAgComm) as SAgComm,
		SUM(SAgTotal) as SAgTotal,
		SUM(Company) as Company,
		SUM(BetCount) as BetCount,
		0
FROM #ComWinLossDetails w 
	INNER JOIN dbo.custinfo c WITH(NOLOCK) ON w.CustID = c.CustID
GROUP BY w.CustID, c.UserName


INSERT INTO #ComWinLossDetailsByPT(CustID,PT,Name,Turnover,GrossComm,MAgTotal,SAgWinLost,SAgComm,SAgTotal,Company,BetCount,DisplayOrder)
SELECT	w.CustID AS CustId, 
		w.PT,
		CAST((PT * 100) as NVARCHAR(50)) + '% PT', 
		SUM(TurnOver) as Turnover,
		SUM(GrossComm) as GrossComm,
		SUM(MAgTotal) as MAgTotal,
		SUM(SAgWinlost) as SAgWinLoss,
		SUM(SAgComm) as SAgComm,
		SUM(SAgTotal) as SAgTotal,
		SUM(Company) as Company,
		SUM(BetCount) as BetCount,
		1
FROM #ComWinLossDetails w 
GROUP BY w.CustID, w.PT


INSERT INTO #ComWinLossDetailsByPT(CustID,PT,Name,Turnover,GrossComm,MAgTotal,SAgWinLost,SAgComm,SAgTotal,Company,BetCount,DisplayOrder)
SELECT	w.CustID AS CustId, 
		w.PT,
		CAST(c.ProductName AS NVARCHAR(100)), 
		SUM(TurnOver) as Turnover,
		SUM(GrossComm) as GrossComm,
		SUM(MAgTotal) as MAgTotal,
		SUM(SAgWinlost) as SAgWinLoss,
		SUM(SAgComm) as SAgComm,
		SUM(SAgTotal) as SAgTotal,
		SUM(Company) as Company,
		SUM(BetCount) as BetCount,
		2
FROM #ComWinLossDetails w 
	INNER JOIN dbo.Products c WITH(NOLOCK) ON w.ProductId = c.ProductID
GROUP BY w.CustID, w.PT,c.ProductName


SELECT
	w.CustID, 
	w.Name, 
	w.Turnover,
	w.GrossComm,
	w.MAgTotal,
	w.SAgWinLost,
	w.SAgComm,
	w.SAgTotal,
	w.Company,
	w.BetCount,
	w.DisplayOrder
FROM #ComWinLossDetailsByPT w 
	INNER JOIN bodb02.dbo.custinfo c WITH(NOLOCK) ON w.CustID = c.CustID 
ORDER BY c.Username,  w.PT, w.DisplayOrder


SELECT
	NULL as CustID, 
	'Total' as Name, 
	SUM(w.Turnover) Turnover,
	SUM(w.GrossComm) GrossComm,
	SUM(w.MAgTotal) MAgTotal,
	SUM(w.SAgWinLost) SAgWinLost,
	SUM(w.SAgComm) SAgComm,
	SUM(w.SAgTotal) SAgTotal,
	SUM(w.Company) Company,
	SUM(w.BetCount) BetCount
FROM #ComWinLossDetailsByPT w 



DROP TABLE #ComWinLossDetails
DROP TABLE #ComWinLossDetailsByPT
DROP TABLE #tmpSuperList
DROP TABLE #Product

GO
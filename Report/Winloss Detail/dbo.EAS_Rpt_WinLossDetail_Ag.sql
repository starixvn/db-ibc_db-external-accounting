/*<info serverAlias="DBAGE-bodb02" executers="bodbExtAccNet" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[EAS_Rpt_WinLossDetail_Ag]
	@CustID			INT,--recommend
	@memberID		INT = NULL,
	@FromDate		SMALLDATETIME,
	@ToDate			SMALLDATETIME,
	@ProductIds		VARCHAR(MAX) = '',
	@BalanceUpDay	SMALLDATETIME,
	@PageSize		INT = 0,
	@PageIndex		INT = 0,
	@TotalRows		INT = 0 OUTPUT
AS
/*
Created by: Scott
Date: 2012-11-15
Task : Member Winloss Detail
DB: DBAGE/bodb02
Original SP: [Age_Rpt_WinLossDetail_Ag]
Revisions:
	- 20130121@Dan: Move sp from DB053/bodb02 to DBEAS/bodb_EAS, add linked server DBSUM for bodb_Summary
	- 20140305@Patrick: Add more Keno product(sport:202, bettype between 1501 and 1599)
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
	- 20170830@Percy:
		1. Integrate Lucky 3 [RedmineID: #76770]
		2. Change list of @show[ProductCode] to @ProductIDs - apply all new products
	- 20180913@Percy: Bullfighting - Add data into TurnoverNoDraw column [RedmineID: #101288]
	- 20180914@Percy: Poker Games - Modify GrossComm [RedmineID: #101550]
	- 20181031@Helen: DB052 Indexes Revolution [RedmineID: 103572]
	- 20190418@Kan: DB053/bodb02 Migration, Move sp from DBEAS/bodb_EAS to DB053/bodb02 [Redmine: #111865]
	- 20190826@Percy: Remove inactive products [RedmineID: #118699]
*/
BEGIN
	SET NOCOUNT ON

	DECLARE @RowStart int, @RowEnd int  
	SELECT @PageIndex = @PageIndex - 1, @RowStart = @PageSize * @PageIndex + 1, @RowEnd = @RowStart + @PageSize - 1
	 
	DECLARE @AgWinLossDetails TABLE(CustID int, TurnOver money, TurnoverNoDraw MONEY, GrossComm money, MemberWinLost money, 
		PlayerComm money, MemberTotal money, AgWinLost money, AgComm money, AgTotal money, Company money)

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
		IF @memberID IS NULL
		BEGIN
			INSERT INTO @AgWinLossDetails
			SELECT
				CustID,
				sum(ABS(b.stake)) as TurnOver,
				SUM(CASE WHEN b.StatusID IN (112,113) AND b.MOdds IN (-0.25, 0.25) AND s.ProductId = 1 THEN ABS(b.stake)/2
						WHEN b.StatusID = 111 AND s.ProductId IN (1) THEN 0 -- Sportsbook
						WHEN s.ProductID = 21 THEN b.oddsspread -- Allbet
						ELSE ABS(b.stake)
						END) AS TurnoverNoDraw,
				SUM(CASE WHEN apositiontaking = 1 THEN 0 ELSE comm/(1- apositiontaking) END) AS GrossComm,
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
				winlostdate between @FromDate and @todate
				AND b.statusID not in (101, 102, 103)
				AND Recommend=@CustID
				AND ruben=1 
			GROUP BY CustID, CASE WHEN b.bettype = 71 OR b.bettype BETWEEN 2101 AND 2399 THEN 71 ELSE b.bettype END
		END
		ELSE
		BEGIN
			INSERT INTO @AgWinLossDetails
			SELECT
				CustID,
				sum(ABS(b.stake)) as TurnOver,
				SUM(CASE WHEN b.StatusID IN (112,113) AND b.MOdds IN (-0.25, 0.25) AND s.ProductId = 1 THEN ABS(b.stake)/2
						WHEN b.StatusID = 111 AND s.ProductId IN (1) THEN 0 -- Sportsbook
						WHEN s.ProductID = 21 THEN b.oddsspread -- Allbet
						ELSE ABS(b.stake)
						END) AS TurnoverNoDraw,
				SUM(CASE WHEN apositiontaking = 1 THEN 0 ELSE comm/(1- apositiontaking) END) AS GrossComm,
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
				winlostdate between @FromDate and @todate
				AND b.statusID not in (101, 102, 103)
				AND ruben=1 
				AND b.custid = @memberID
			GROUP BY CustID, CASE WHEN b.bettype = 71 OR b.bettype BETWEEN 2101 AND 2399 THEN 71 ELSE b.bettype END
		END 
		

		if @BalanceUpDay < @FromDate
			select @BalanceUpDay=@FromDate
		
		IF @memberID IS NULL
		BEGIN
			INSERT INTO @AgWinLossDetails
			SELECT
				CustID,			
				sum(ABS(TurnOver)) as TurnOver,
				SUM(ABS(TunroverNoDraw)) as TurnoverNoDraw,
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
				AND recommend=@CustID
				AND RoleID=1
			GROUP BY CustID
			
		END
		ELSE
		BEGIN
			INSERT INTO @AgWinLossDetails
			SELECT
				CustID,			
				sum(ABS(TurnOver)) as TurnOver,
				SUM(ABS(TunroverNoDraw)) as TurnoverNoDraw,
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
				AND RoleID=1
				AND b.custid = @memberID
			GROUP BY CustID
		END
	END

	IF @FromDate < @BalanceUpDay 
	BEGIN
		if @ToDate >= DATEADD(dd, -1, @BalanceUpDay)
			select @ToDate = DATEADD(dd, -1, @BalanceUpDay)
		
		INSERT INTO @AgWinLossDetails
			SELECT
				CustID,			
				sum(ABS(TurnOver)) as TurnOver,
				SUM(ABS(TunroverNoDraw)) as TurnoverNoDraw,
				sum(grosscomm) as GrossComm,
				sum(winlost), --MemberWinlost
				sum(playercomm), -- PlayerComm
				isnull(sum(winlost), 0) + isnull(sum(playercomm), 0), --MemberTotal
				sum(awinlost), -- AgWinlost
				sum(comm-playercomm), --AgComm
				isnull(sum(awinlost), 0) + isnull(sum(comm-playercomm), 0), --AgTotal
				-isnull(sum(winlost+awinlost+comm), 0) --Company
			FROM
				bodb_Summary.dbo.Sum_WinLoss_Old b WITH(NOLOCK) INNER JOIN @TmpCondSumWL t ON b.sporttype = t.sporttype AND b.bettype = t.bettype
			WHERE
				winlostdate between @fromdate and @ToDate	
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
END	
GO
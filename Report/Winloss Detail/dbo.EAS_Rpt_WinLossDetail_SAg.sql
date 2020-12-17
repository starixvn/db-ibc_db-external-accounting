/*<info serverAlias="DBAGE-bodb02" executers="bodbExtAccNet" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[EAS_Rpt_WinLossDetail_SAg]
	@custid			INT,--srecommend
	@masterid		INT = NULL,
	@FromDate		SMALLDATETIME,
	@ToDate			SMALLDATETIME,
	@ProductIds		VARCHAR(MAX) = '',
	@ProductDetails NVARCHAR(MAX) = 'All',
	@MoveBetsDay	SMALLDATETIME,
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
DB: DBAGE/bodb02
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
	- 20170830@Percy:
		1. Integrate Lucky 3 [RedmineID: #76770]
		2. Change list of @show[ProductCode] to @ProductIDs - apply all new products
	- 20180913@Percy: Bullfighting - Add data into TurnoverNoDraw column [RedmineID: #101288]
	- 20180914@Percy: Poker Games - Modify GrossComm [RedmineID: #101550]
	- 20181031@Helen: DB052 Indexes Revolution [RedmineID: 103572]
	- 20190418@Kan: DB053/bodb02 Migration, Move sp from DBEAS/bodb_EAS to DB053/bodb02 [Redmine: #111865]
	- 20190826@Percy: Remove inactive products [RedmineID: #118699]
	- 20200410@Sophia: Add BBIN, Sexy Gaming, SA Gaming [RedmineId: #131358]
	- 20200422@Sophia: Add IBCBet Live Casino [RedmineId: #130693]
	- 20200601@Sophia: Add ION [RedmineId: #132325]
	- 20200909@Malcolm : Report Enhancement for Jackpot Product [RedmineID : #139575]
	- 20200915@Malcolm : Add WM Live Casino [Redmine : #131584]
	- 20201201@Malcolm : Add Gold Diamond Gaming [Redmine : #144110]
	
	Param's Explanation:
	 @ProductDetails:		
		<ROOT>
				<ProductDetail ProductId = "32" Sporttype = "248" Bettype = "0"/>
				<ProductDetail ProductId = "32" Sporttype = "248" Bettype = "4298"/>
		</ROOT>	
*/
BEGIN
	SET NOCOUNT ON

	DECLARE @RowStart int, @RowEnd int, @iDoc INT, @FDate SMALLDATETIME, @TDate SMALLDATETIME, @__ProductDetails XML;

	SELECT @FDate = @FromDate, @TDate = @ToDate

	SELECT @PageIndex = @PageIndex - 1, @RowStart = @PageSize * @PageIndex + 1, @RowEnd = @RowStart + @PageSize - 1

	DECLARE @ExistingProductDetails TABLE (ProductId INT,Sporttype INT,Bettype INT)

	DECLARE @SAgWinLossDetails TABLE(CustID int, TurnOver money, TurnoverNoDraw MONEY, GrossComm money, MemberWinLost money, 
		PlayerComm money, MemberTotal money, AgWinLost money, AgComm money, AgTotal money, 
		MAgWinLost money, MAgComm money, MAgTotal money, SAgWinLost money, SAgComm money, SAgTotal money, Company money)

	SELECT @ProductIds = bodb02.dbo.f_AddRelatedProducts(@ProductIds)

	IF ISNULL(@ProductDetails,'') = ''
	BEGIN 
		INSERT INTO @ExistingProductDetails
		(
			ProductId
			,Sporttype
			,Bettype
		)
		VALUES(NULL, NULL, NULL)
	END
	ELSE IF ISNULL(@ProductDetails,'')  = 'All'
	BEGIN
		INSERT INTO @ExistingProductDetails
		(
			ProductId
			,Sporttype
			,Bettype
		)
		SELECT 
			ProductId
			,Sporttype
			,Bettype
		FROM dbo.f_GetProductDetail() f
	END
	ELSE 		
	BEGIN	
		SELECT @__ProductDetails = CONVERT(XML, @ProductDetails)
	
		INSERT INTO @ExistingProductDetails
		(
			ProductId
			,Sporttype
			,Bettype
		)
		SELECT 
			t.c.value('(@ProductId)[1]', 'SMALLINT') AS ProductID
			, t.c.value('(@Sporttype)[1]', 'SMALLINT') AS Sporttype
			, t.c.value('(@Bettype)[1]', 'SMALLINT') AS Bettype
		FROM @__ProductDetails.nodes('ROOT/ProductDetail') t(c)
	END
		
	DECLARE @TmpCondSumWL TABLE(sporttype INT, bettype INT)
	INSERT INTO @TmpCondSumWL (sporttype, bettype)
	SELECT f.sporttype, f.bettype
	FROM bodb02.dbo.f_SumWinloss_ConditionSel(@ProductIds) f
		LEFT JOIN @ExistingProductDetails e ON f.ProductID = e.ProductId
	WHERE e.ProductId IS NULL OR (e.Bettype = f.BetType)

	----Get Sport Bettype Matrix------
	DECLARE @isTest BIT = 0
	SELECT  @isTest = dbo.f_CheckSPVersion(@@PROCID)

	DECLARE @SportBettype TABLE(ProductID INT, Bettype INT)

	INSERT INTO @SportBettype(
	    ProductId
		,BetType
	)
	SELECT ISNULL(p.GroupProductId, f.ProductID), f.BetType
	FROM dbo.f_SportBettypeMatrixByProduct_Sel(@ProductIds, @IsTest) f
		LEFT JOIN bodb02.dbo.f_GroupProduct() p ON P.ProductId = f.ProductID
		LEFT JOIN @ExistingProductDetails e ON e.ProductId = f.ProductID
	WHERE EXISTS(SELECT 1
				WHERE e.ProductId IS NULL 
					OR 
						(
							e.Bettype = f.BetType 
							OR (e.Bettype = 0 AND f.BetType NOT IN (SELECT g.Bettype FROM f_GetProductDetail() g))
						)
				)
				
	IF @Todate >= @BalanceUpDay
	BEGIN 
		IF @ToDate > @MoveBetsDay
		BEGIN
			IF @MoveBetsDay > @FromDate
				SELECT @FDate = DATEADD(DD, 1, @MoveBetsDay)

			IF @masterID IS NULL
			BEGIN
				INSERT INTO @SAgWinLossDetails
				SELECT
					MRecommend,			
					sum(ABS(b.stake)) as TurnOver,
					SUM(CASE WHEN b.StatusID IN (112,113) AND b.MOdds IN (-0.25, 0.25) AND s.ProductId = 1 THEN ABS(b.stake)/2
							WHEN b.StatusID = 111 AND s.ProductId IN (1) THEN 0 -- Sportsbook
							WHEN s.ProductID IN (21, 39, 45, 46, 47, 51, 52, 59)  THEN b.oddsspread -- Allbet, SA Gaming, SexyGaming, IBCBet Live Casino, BBIN, WM, ION, GDG
							ELSE ABS(b.stake) 
							END) AS TurnoverNoDraw,
					SUM(CASE WHEN tpositiontaking = 1 THEN 0 ELSE scomm/(1-tpositiontaking) END) AS GrossComm,
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
					bodb02.dbo.bettrans b WITH (NOLOCK)
					INNER JOIN @SportBettype s ON b.bettype = s.Bettype 
				WHERE	
					winlostdate between @FDate and @TDate 
					AND srecommend = @custid 
					AND b.statusID IN (111,112,113)
				GROUP BY MRecommend
			
			END
			ELSE
			BEGIN
				INSERT INTO @SAgWinLossDetails
				SELECT
					MRecommend,			
					sum(ABS(b.stake)) as TurnOver,
					SUM(CASE WHEN b.StatusID IN (112,113) AND b.MOdds IN (-0.25, 0.25) AND s.ProductId = 1 THEN ABS(b.stake)/2
							WHEN b.StatusID = 111 AND s.ProductId IN (1) THEN 0 -- Sportsbook
							WHEN s.ProductID IN (21, 39, 45, 46, 47, 51, 52, 59)  THEN b.oddsspread -- Allbet, SA Gaming, SexyGaming, IBCBet Live Casino, BBIN, WM, ION, GDG
							ELSE ABS(b.stake) 
							END) AS TurnoverNoDraw,
					SUM(CASE WHEN tpositiontaking = 1 THEN 0 ELSE scomm/(1-tpositiontaking) END) AS GrossComm,
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
					bodb02.dbo.bettrans b WITH (NOLOCK)
					INNER JOIN @SportBettype s ON b.bettype = s.Bettype 
				WHERE	
					winlostdate between @FDate and @TDate 
					AND b.mrecommend = @masterID
					AND b.statusID IN (111,112,113)
				GROUP BY MRecommend
			
			END
		END
		
		SELECT @FDate = @FromDate

		IF @BalanceUpDay > @FromDate
			SELECT @FDate = @BalanceUpDay
		
		IF @FromDate <= @MoveBetsDay
		BEGIN
			IF @ToDate > @MoveBetsDay
				SELECT @TDate = @MoveBetsDay

			IF @masterID IS NULL
			BEGIN
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
					winlostdate between @FDate and @TDate			
					AND SRecommend = @custid
					AND RoleID = 3
				GROUP BY CustID
			
			END
			ELSE
			BEGIN
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
					winlostdate between @FDate and @TDate			
					AND b.mrecommend = @masterID
					AND RoleID = 3
				GROUP BY CustID
			END
		END
		
	END

	IF @FromDate < @BalanceUpDay 
	BEGIN
		SELECT @FDate = @FromDate

		IF @ToDate >= DATEADD(dd, -1, @BalanceUpDay)
			SELECT @TDate = DATEADD(dd, -1, @BalanceUpDay)
			
		SELECT custid,  mrecommend, turnover,TunroverNoDraw as  TurnoverNoDraw, winlost, awinlost, mwinlost, swinlost, playercomm, comm, acomm, scomm, grosscomm, sporttype, bettype 
			INTO #Sum_WinLoss_Old
		FROM bodb_Summary.dbo.Sum_WinLoss_Old b WITH(NOLOCK)
		WHERE winlostdate BETWEEN @FDate AND @TDate			
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

END	
GO
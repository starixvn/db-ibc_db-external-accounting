/*<info serverAlias="DBAGE-bodb02" executers="bodbExtAccNet" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[EAS_Rpt_WinLossDetail_Com] 	
	@GroupName		VARCHAR(50) = 'ACCTHAI',--ACCTHAI or ACCINDO
	@custid			INT = NULL,	
	@FromDate		SMALLDATETIME,
	@ToDate			SMALLDATETIME,
	@ProductIds		VARCHAR(MAX) = '',
	@ProductDetails NVARCHAR(MAX) = 'All',
	@MoveBetsDay	SMALLDATETIME,
	@BalanceUpDay	SMALLDATETIME	
AS
/*
	Created by: Dan
	Date: 2012-10-29
	Task : Super Winloss Detail
	DB: DBAGE/bodb02
	Original: Acc_Rpt_WinLossDetail_ComEx
	Revisions:
		- 20130121@Dan: Move sp from DB053/bodb02 to DBEAS/bodb_EAS, call to bodb_AGE for Acc_CustGroup, add linked server DBSUM for bodb_Summary
		- 20140305@Patrick: Add more Keno product(sport:202, bettype between 1501 and 1599)
		- 20140321@Lukas: seperate P2P product to enhance performance
		- 20140420@Francis: revise SP to use temporary table instead of variable table to improve performance
		- 20150502@Lukas: Revise SP to insert into Temporary table (#Sum_WinLoss_Old) of a remote table (DBSUM.bodb_Summary.dbo.Sum_WinLoss_Old) to enhance performance (HotFix #35279)
		- 20150528@Sophia: Apply Gold Deluxe and Sport bettype Matrix [Redmine: #36775]
		- 20150907@Winnie: Add CB [Redmine: #43099]
		- 20151217@Percy: Add Cockfighting [Redmine: #48836]
		- 20160107@Percy: Include new bettype range of the new RNG Casino [Redmine: #48286]
		- 20160215@Percy: Support new product AllBet [Redmine: #50922]
		- 20160225@Sophia: Add new column TurnoverNoDraw [Redmine: #51427]
		- 20160414@Victor: Support new product Voidbridge [Redmine: #55468]
		- 20160809@Percy: Modify Net Turnover for Allbet [RedmineID: #61876]
		- 20160824@Sophia: Enhance Performance (work around for hotfix) [Redmine: #62941]
		- 20160915@Johnson: Integrate NG2 [RedmineSPU: #30]
		- 20161028@Percy: Support Fishing World [RedmineID: #65735]
		- 20161001@Daniel: Change to REASDPAST when get from bettrans due to pagesplit
		- 20161020@Francis: Avoid pagesplit by prompting index seek on bettrans [Redmine: #65042]
		- 20170622@Percy: Combine Betradar Virtual Sports with Virtual Sports [RedmineID: #78340]
		- 20170703@Percy: Support Keno Lottery [RedmineID: #78068]
		- 20170830@Percy:
			1. Integrate Lucky 3 [RedmineID: #76770]
			2. Change list of @show[ProductCode] to @ProductIDs - apply all new products
		- 20171002@Percy: Hotfix - Duplicated data due to duplicated bettype [RedmineID: #84167]
		- 20180913@Percy: Bullfighting - Add data into TurnoverNoDraw column [RedmineID: #101288]
		- 20180914@Percy: Poker Games - Modify GrossComm [RedmineID: #101550]
		- 20181122@Elodie: DB053/bodb_Age Migration [Redmine:#104770]
		- 20190418@Kan: DB053/bodb02 Migration, Move sp from DBEAS/bodb_EAS to DB053/bodb02 [Redmine: #111865]
		- 20190826@Percy: Remove inactive products [RedmineID: #118699]
		- 20200410@Sophia: Add BBIN, Sexy Gaming, SA Gaming [RedmineId: #131358]
		- 20200422@Sophia: Add IBCBet Live Casino [RedmineId: #130693]
		- 20200601@Sophia: Add ION [RedmineId: #132325]
		- 20200708@Sol: Add new columns to the report for Extra PT - Redmine: [#136320]
		- 20200826@Sol: Add new column to the report for Extra PT - Redmine: [#140389]
		- 20200828@Sol: enhance sp to prevent deadlock, increase maxdop to use parallelism - Redmine: [#140531]
		- 20200909@Malcolm: Report Enhancement for Jackpot Product [RedmineID : #139575]
		- 20200915@Malcolm: Add WM Live Casino [Redmine : #131584]
		- 20201201@Malcolm : Add Gold Diamond Gaming [Redmine : #144110]
		- 20201210@Malcolm: Add Big Gaming [RedmineId : #142459]
		- 20201230@Danny : Enhance peformance [Redmine : #147836]
		- 20210310@Malcolm: Add Pragmatic Live Casino [RedmineId : #133717]
		- 20210617@Sol: changed how to calc net turn over - [RedmineId : #156653]
		- 20211122@Percy: Enhance gross comm formula [RedmineID: #164479]
	
	Param's Explanation:
	 @ProductDetails:		
		<ROOT>
				<ProductDetail ProductId = "32" Sporttype = "248" Bettype = "0"/>
				<ProductDetail ProductId = "32" Sporttype = "248" Bettype = "4298"/>
		</ROOT>	

*/

SET NOCOUNT ON

CREATE TABLE #tmpSuperList (custID INT PRIMARY KEY)

DECLARE @ExistingProductDetails TABLE (ProductId INT,Sporttype INT,Bettype INT)
DECLARE @iDoc INT, @FDate SMALLDATETIME, @TDate SMALLDATETIME, @__ProductDetails XML;

SELECT @FDate = @FromDate, @TDate = @ToDate

INSERT INTO #tmpSuperList(CustID)
SELECT custID 
FROM bodb02.dbo.Acc_CustGroup WITH(NOLOCK)
WHERE (@custid IS NULL OR custid = @custid)
	AND GroupName = @GroupName

CREATE TABLE #ComWinLossDetails 
(
	CustID int, Turnover money, TurnoverNoDraw MONEY, GrossComm money, MemberWinLost money, 
	PlayerComm money, MemberTotal money, AgWinLost money, AgComm money, AgTotal money, 
	MAgWinLost money, MAgComm money, MAgTotal money, SAgWinLost money, SAgComm money, SAgTotal MONEY,
	ExtraWinloss MONEY, ExtraComm MONEY, ExtraTotal MONEY, Company MONEY, CompanyAfterExtraPT MONEY
)

CREATE TABLE #TmpCondSumWL (sporttype INT, bettype INT)--, PRIMARY KEY NONCLUSTERED (Bettype ASC, sporttype ASC))

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

----Get Sport Bettype Matrix------
DECLARE @isTest BIT = 0
SELECT  @isTest = dbo.f_CheckSPVersion(@@PROCID)

CREATE TABLE #SportBettype (ProductID INT, Bettype INT, RefTable TINYINT, IsContributionBettype BIT, PRIMARY KEY NONCLUSTERED (Bettype ASC, ProductID ASC))

INSERT INTO #TmpCondSumWL (sporttype, bettype)
SELECT f.sporttype, f.bettype
FROM bodb02.dbo.f_SumWinloss_ConditionSel(@ProductIds) f
LEFT JOIN @ExistingProductDetails e ON f.ProductID = e.ProductId
	WHERE e.ProductId IS NULL OR (e.Bettype = f.BetType)

INSERT INTO #SportBettype (ProductId, BetType, RefTable, IsContributionBettype)
SELECT ISNULL(p.GroupProductId, f.ProductID), f.BetType, f.RefTable,
		CASE WHEN fc.Bettype IS NOT NULL THEN 1 ELSE 0 END AS IsContributionBettype
FROM dbo.f_SportBettypeMatrixByProduct_Sel(@ProductIds, @IsTest) f
	LEFT JOIN bodb02.dbo.f_GroupProduct() p ON P.ProductId = f.ProductID
	LEFT JOIN @ExistingProductDetails e ON e.ProductId = f.ProductID
	LEFT JOIN dbo.f_BettypePrizeGroup() fc ON f.BetType = fc.BetType AND fc.BettypeGroup = 'Contribution'
WHERE EXISTS(SELECT 1
			WHERE e.ProductId IS NULL 
				OR 
					(
						e.Bettype = f.BetType 
						OR (e.Bettype = 0 AND f.BetType NOT IN (SELECT g.Bettype FROM f_GetProductDetail() g))
					)
			)

--Force optimizer to seek on IX_srecommend index
DECLARE @n BIGINT = 2147483647
	
IF @Todate >= @BalanceUpDay
BEGIN 
	IF @ToDate > @MoveBetsDay
	BEGIN
		IF @MoveBetsDay > @FromDate
		SELECT @FDate = DATEADD(DD, 1, @MoveBetsDay) --DATEADD(dd, -1, @BalanceUpDay)

		CREATE TABLE #ComWinLossDetails_bettrans 
		(
			SRecommend int, 
			bettype money, 
			StatusID TINYINT, 
			MOdds Smallmoney, 
			tpositiontaking Smallmoney, 
			stake money, 
			oddsspread money, 
			scomm money, 
			MemberWinlost money, 
			playercomm money, 
			AgWinlost money, 
			AgComm money,
			MAgWinlost money, 
			MAgComm money, 
			SAgWinlost money, 
			SAgComm MONEY,
			betid MONEY, 
			epositiontaking Smallmoney,
			Winlostdate Smalldatetime,
			GrossComm MONEY
		)

		INSERT #ComWinLossDetails_bettrans
		 SELECT
		    SRecommend,
			bettype,
			StatusID,
			MOdds,
			tpositiontaking,
			SUM(ABS(b.stake)),	
			SUM(b.oddsspread),
			SUM(scomm),
		    sum(winlost-actual_stake), --MemberWinlost
		    sum(playercomm), -- PlayerComm
		    sum(awinlost), -- AgWinlost
		    isnull(sum(comm-playercomm),0), --AgComm	
		    sum(mwinlost), -- MAgWinlost
		    sum(acomm)-sum(comm), --MAgComm
		    sum(swinlost), -- SAgWinlost
		    isnull(sum(scomm),0) -isnull(sum(acomm),0), --SAgComm
			SUM(ISNULL(b.betid/CONVERT(DECIMAL(19,8), 100000000), 0)),    
			epositiontaking,
			Winlostdate,
			SUM(CASE WHEN tpositiontaking = 1 THEN 0 ELSE scomm/(1-tpositiontaking) END) 

	    FROM bodb02.dbo.bettrans b WITH (NOLOCK)
	    WHERE
		    b.winlostdate between @FDate and @TDate 
		    and b.srecommend in (SELECT custID FROM #tmpSuperList) 
		    and b.statusID IN (111,112,113)
	    GROUP BY SRecommend, bettype, StatusID, MOdds, tpositiontaking,Winlostdate, epositiontaking
	    OPTION (MAXDOP 8)

		INSERT INTO #ComWinLossDetails
	    SELECT
		    SRecommend,
			SUM(ABS(b.stake)),
			SUM(CASE
					WHEN s.RefTable IN (1, 2) THEN 0 -- bettransRnG/bettransLC
					WHEN s.ProductId = 47 THEN b.oddsspread -- BBIN
					WHEN s.ProductId = 1 AND b.statusId = 111 THEN 0 -- SB draw
					WHEN s.ProductId = 1 AND b.StatusId IN (112, 113) AND b.modds IN (-0.25, 0.25) THEN ABS(b.stake)/2 -- SB half won/lose
					ELSE ABS(b.stake)
				END) AS TurnoverNoDraw,
			SUM(CASE
					WHEN s.RefTable IN (1, 2) THEN 0
					WHEN tpositiontaking = 1 THEN 0
					ELSE GrossComm
				END) AS GrossComm,
		    sum(MemberWinlost), --MemberWinlost
		    sum(playercomm), -- PlayerComm
		    SUM(isnull(MemberWinlost, 0)) + SUM(isnull(playercomm, 0)), --MemberTotal
		    sum(AgWinlost), -- AgWinlost
			sum(AgComm), --AgComm
		    sum(AgWinlost+ AgComm), --AgTotal			
		    sum(MAgWinlost), -- MAgWinlost
		    sum(MAgComm), --MAgComm
		    sum(MAgWinlost + MAgComm), --MAgTotal
		    sum(SAgWinlost), -- SAgWinlost
		    sum(SAgComm), --SAgComm
			sum(SAgWinlost + SAgComm), --SAgTotal
			ISNULL(-1 * SUM(CASE
							-- Jackpot
							WHEN b.bettype IN (2198, 2398, 2998, 4297) THEN
								CASE WHEN b.tpositiontaking = 1 THEN 0 ELSE b.betid END
							WHEN b.bettype IN (2199, 2399, 2999, 4298) THEN 0
							ELSE 
								CASE WHEN b.tpositiontaking = 1 THEN 0 ELSE b.MemberWinlost END
							END
							* 
							CASE WHEN tbl.ExtraPT IS NOT NULL THEN tbl.ExtraPT ELSE ISNULL(b.epositiontaking, 0) END
							),0) AS ExtraWinloss,
			ISNULL(-1 * SUM(CASE 
							/*IBCBet Live Casino*/
							WHEN b.bettype BETWEEN 3201 AND 3299 THEN b.scomm
							WHEN b.bettype IN (2198, 2398, 2998, 2199, 2399, 2999, 4297, 4298) THEN 0
							ELSE  b.GrossComm * CASE WHEN tbl.ExtraPT IS NOT NULL THEN tbl.ExtraPT ELSE ISNULL(b.epositiontaking, 0) END
							END
							), 0) AS ExtraComm,
			-1 * (
				ISNULL(SUM(CASE 
							-- Jackpot
							WHEN b.bettype IN (2198, 2398, 2998, 4297) THEN
								CASE WHEN b.tpositiontaking = 1 THEN 0 ELSE b.betid END
							WHEN b.bettype IN (2199, 2399, 2999, 4298) THEN 0
							ELSE 
								CASE WHEN b.tpositiontaking = 1 THEN 0 ELSE b.MemberWinlost END
							END
							*	 
							CASE WHEN tbl.ExtraPT IS NOT NULL THEN tbl.ExtraPT ELSE ISNULL(b.epositiontaking, 0) END
							),0)
				+
				ISNULL(SUM(CASE 
							/*IBCBet Live Casino*/
							WHEN b.bettype BETWEEN 3201 AND 3299 THEN b.scomm
							WHEN b.bettype IN (2198, 2398, 2998, 2199, 2399, 2999, 4297, 4298) THEN 0
							ELSE b.GrossComm * CASE WHEN tbl.ExtraPT IS NOT NULL THEN tbl.ExtraPT ELSE ISNULL(b.epositiontaking, 0) END
							END
							), 0)
				) AS ExtraTotal,
			-(isnull(sum(SAgWinlost), 0) + isnull(sum(AgWinlost), 0) + isnull(sum(MAgWinlost), 0) + isnull(sum(scomm), 0) + isnull(sum(b.MemberWinlost), 0)), --Company				
		    -1 * (
					ISNULL(SUM(SAgWinlost), 0) + ISNULL(SUM(AgWinlost), 0) + ISNULL(SUM(MAgWinlost), 0) + ISNULL(SUM(scomm), 0) + ISNULL(SUM(b.MemberWinlost), 0)
					+ 
					-1 * (
						ISNULL(SUM(CASE
									-- Jackpot
									WHEN b.bettype IN (2198, 2398, 2998, 4297) THEN
										CASE WHEN b.tpositiontaking = 1 THEN 0 ELSE b.betid END
									WHEN b.bettype IN (2199, 2399, 2999, 4298) THEN 0
									ELSE 
										CASE WHEN b.tpositiontaking = 1 THEN 0 ELSE b.MemberWinlost END
									END
									* 
									CASE WHEN tbl.ExtraPT IS NOT NULL THEN tbl.ExtraPT ELSE ISNULL(b.epositiontaking, 0) END
									),0)
						+
						ISNULL(SUM(CASE 
									/*IBCBet Live Casino*/
									WHEN b.bettype BETWEEN 3201 AND 3299 THEN b.scomm
									WHEN b.bettype IN (2198, 2398, 2998, 2199, 2399, 2999, 4297, 4298) THEN 0
									ELSE b.GrossComm* CASE WHEN tbl.ExtraPT IS NOT NULL THEN tbl.ExtraPT ELSE ISNULL(b.epositiontaking, 0) END
									END
								), 0)
					)
				) AS CompanyAfterExtraPT				
	    FROM
		    #ComWinLossDetails_bettrans b WITH (NOLOCK)
			INNER JOIN #SportBettype s ON b.bettype = s.Bettype 
			OUTER APPLY 
			(
				SELECT expt2.SuperId, expt2.ExtraPT
				FROM dbo.Acc_GroupExtraPT2Setting expt2 WITH (NOLOCK)
				WHERE
				(b.Winlostdate BETWEEN expt2.FromDate AND  expt2.ToDate  )
						AND expt2.ProductID = s.ProductID
						AND b.srecommend = expt2.SuperId 
						AND ISNULL(expt2.SubProduct,'') = ''
						AND expt2.Sporttype = 0
			) tbl
	    GROUP BY SRecommend

		TRUNCATE TABLE #ComWinLossDetails_bettrans

		INSERT INTO #ComWinLossDetails_bettrans (SRecommend, bettype, stake, GrossComm) -- use stake for Net Stake
		SELECT b.srecommend, b.gameID, SUM(b.BetStake), SUM(b.BetStake * b.sdiscount)
		FROM dbo.bettransRnG b WITH (NOLOCK)
		WHERE b.winlostdate BETWEEN @FDate AND @TDate 
		    AND b.srecommend IN (SELECT custID FROM #tmpSuperList) 
		    and b.statusID IN (111, 112, 113)
		GROUP BY b.srecommend, b.gameID

		INSERT INTO #ComWinLossDetails_bettrans (SRecommend, bettype, stake, GrossComm) -- use stake for Net Stake
		SELECT b.srecommend, b.gameID, SUM(b.NetStake), SUM(b.NetStake * b.sdiscount)
		FROM dbo.bettransLC b WITH (NOLOCK)
		WHERE b.winlostdate BETWEEN @FDate AND @TDate 
		    AND b.srecommend IN (SELECT custID FROM #tmpSuperList) 
		    and b.statusID IN (111, 112, 113)
		GROUP BY b.srecommend, b.gameID

		UPDATE t
		SET t.TurnoverNoDraw = ISNULL(t.TurnoverNoDraw, 0) + ISNULL(c.TurnoverNoDraw, 0)
			,t.GrossComm = ISNULL(t.GrossComm, 0) + ISNULL(c.GrossComm, 0)
		FROM #ComWinLossDetails t
			INNER JOIN (
				SELECT b.srecommend, SUM(GrossComm) AS GrossComm, SUM(stake) AS TurnoverNoDraw
				FROM #ComWinLossDetails_bettrans b
					INNER JOIN #SportBettype s ON b.bettype = s.Bettype AND s.RefTable IN (1, 2)
				GROUP BY b.srecommend
			) c ON t.CustId = c.srecommend
		
		DROP TABLE #ComWinLossDetails_bettrans
	END
   
	SELECT @FDate = @FromDate
	
	IF @BalanceUpDay > @FromDate
	    SELECT @FDate = @BalanceUpDay

	IF @FromDate <= @MoveBetsDay
	BEGIN
		IF @ToDate > @MoveBetsDay
			SELECT @TDate = @MoveBetsDay

		INSERT INTO #ComWinLossDetails
	    SELECT
		    CustID,			
		    sum(TurnOver), -- TurnOver
			SUM(TunroverNoDraw) as TurnoverNoDraw,
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
			ISNULL(SUM(b.ExtraWinloss), 0) AS ExtraWinloss,
			ISNULL(SUM(b.ExtraComm), 0) AS ExtraComm,
			ISNULL(SUM(b.ExtraWinloss + b.ExtraComm), 0) AS ExtraTotal,
			-(isnull(sum(swinlost), 0) + isnull(sum(awinlost), 0) + isnull(sum(mwinlost), 0) + isnull(sum(scomm), 0) + isnull(sum(winlost), 0)), --Company
		    -(isnull(sum(swinlost), 0) + isnull(sum(awinlost), 0) + isnull(sum(mwinlost), 0) + isnull(sum(scomm), 0) + isnull(sum(winlost), 0) + ISNULL(SUM(b.ExtraWinloss + b.ExtraComm), 0)) --Company after extra pt					
	    FROM
		    bodb02.dbo.sum_winloss b WITH (NOLOCK) INNER JOIN #TmpCondSumWL t ON b.sporttype = t.sporttype AND b.bettype = t.bettype
	    WHERE
		    winlostdate between @FDate and @TDate			
		    and SRecommend IN (SELECT custID FROM #tmpSuperList)
		    and RoleID = 4
	    GROUP BY CustID
	END
END

IF @FromDate < @BalanceUpDay 
BEGIN
	SELECT @FDate = @FromDate

	IF @ToDate >= DATEADD(dd, -1, @BalanceUpDay)
		SELECT @TDate = DATEADD(dd, -1, @BalanceUpDay)
		
DECLARE @winlostdateTable TABLE (winlostdate smalldatetime)

	;WITH CTE_Winlostdate (winlostdate ) AS
	(
		SELECT @FDate AS winlostdate
		UNION ALL
		SELECT DATEADD(DAY, 1, winlostdate)
		FROM CTE_Winlostdate
		WHERE winlostdate < @TDate
	)
	INSERT INTO @winlostdateTable(winlostdate)
	select * from CTE_Winlostdate
	OPTION (MAXRECURSION 0)

    INSERT INTO #ComWinLossDetails
	    SELECT
		    CustID,			
		    sum(TurnOver), -- TurnOver
			SUM(TunroverNoDraw) as TurnoverNoDraw,
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
			ISNULL(SUM(b.ExtraWinloss), 0) AS ExtraWinloss,
			ISNULL(SUM(b.ExtraComm), 0) AS ExtraComm,
			ISNULL(SUM(b.ExtraWinloss + b.ExtraComm), 0) AS ExtraTotal,
			-(isnull(sum(swinlost), 0) + isnull(sum(awinlost), 0) + isnull(sum(mwinlost), 0) + isnull(sum(scomm), 0) + isnull(sum(winlost), 0)), --Company
		    -(isnull(sum(swinlost), 0) + isnull(sum(awinlost), 0) + isnull(sum(mwinlost), 0) + isnull(sum(scomm), 0) + isnull(sum(winlost), 0) + ISNULL(SUM(b.ExtraWinloss + b.ExtraComm), 0)) --Company after extra pt							
	    FROM
		   bodb_Summary.dbo.Sum_WinLoss_Old b WITH(NOLOCK) 
		   CROSS APPLY (
				SELECT  t.winlostdate, u.SportType, u.BetType
				FROM #TmpCondSumWL u
				cross join @winlostdateTable t
			) w
	    WHERE b.winlostdate = w.winlostdate  
		    AND b.custid IN (SELECT tmp.custID FROM #tmpSuperList tmp)
			AND b.roleid = 4
			 AND b.sporttype = w.sporttype 
			 AND b.bettype = w.bettype
	    GROUP BY b.CustID

END	

SELECT
	w.CustID, 
	c.UserName, 
	sum(TurnOver) as Turnover,
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
	SUM(w.ExtraWinloss) AS ExtraWinloss,
	SUM(w.ExtraComm) AS ExtraComm,
	SUM(w.ExtraTotal) AS ExtraTotal,
	SUM(w.Company) AS Company,
	SUM(w.CompanyAfterExtraPT) as CompanyAfterExtraPT	
FROM #ComWinLossDetails w INNER JOIN bodb02.dbo.custinfo c WITH(NOLOCK) ON w.CustID = c.CustID 
Group by w.CustID, c.UserName
order by c.Username

DROP TABLE #ComWinLossDetails

DROP TABLE #tmpSuperList
DROP TABLE #SportBettype
DROP TABLE #TmpCondSumWL

GO
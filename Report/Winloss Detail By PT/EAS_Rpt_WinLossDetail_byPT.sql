/*<info serverAlias="DBAGE-bodb02" executers="bodbExtAccNet" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[EAS_Rpt_WinLossDetail_byPT] 	
	@GroupName		VARCHAR(50) = 'ACCINDO',
	@CustId         INT = NULL,
	@FromDate		SMALLDATETIME,
	@ToDate			SMALLDATETIME,
	@ProductIds		VARCHAR(MAX) = '46',
	@ProductDetails NVARCHAR(MAX) = 'All',
	@BalanceUpDay	SMALLDATETIME,
	@MoveBetsDay	SMALLDATETIME,
	@PageSize		INT = 0,
	@PageIndex		INT = 0,
	@TotalRecords	INT = 0 OUTPUT
AS
/*
	Created by: Danny
	Date: 2020-10-13
	Task : Implement new report details win/lost by PT 
	DB: DBAGE/bodb02
	Revisions:
		- 20201013@Danny: Initialize SPs [RedmineID : #139937]
		- 20201201@Malcolm : Add Gold Diamond Gaming [Redmine : #144110]
		- 20201221@Danny : Enhance performance [Redmine : #147331]
		- 20201210@Malcolm: Add Big Gaming [RedmineId : #142459]
		- 20210310@Malcolm: Add Pragmatic Live Casino [RedmineId : #133717]
		- 20210617@Sol: changed how to calc net turn over - [RedmineId : #156653]
		- 20211122@Percy: Enhance gross comm formula [RedmineID: #164479]
*/

SET NOCOUNT ON

	DECLARE @RowStart	INT,
			@RowEnd		INT

	SELECT	@PageIndex = @PageIndex - 1,
			@RowStart = @PageSize * @PageIndex + 1,
			@RowEnd = @RowStart + @PageSize - 1;

	CREATE TABLE #tmpSuperList (custID INT PRIMARY KEY)

	INSERT INTO #tmpSuperList(CustID)
	SELECT custID 
	FROM bodb02.dbo.Acc_CustGroup WITH(NOLOCK)
	WHERE (@custid IS NULL OR custid = @custid) AND GroupName = @GroupName

	DECLARE @ExistingProductDetails TABLE (ProductId INT,Sporttype INT,Bettype INT)
	DECLARE @isTest BIT, @__ProductDetails XML;
	SELECT  @isTest = dbo.f_CheckSPVersion(@@PROCID);	

	SELECT @ProductIds = dbo.f_AddRelatedProducts(@ProductIds);

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

	CREATE TABLE #TmpCondSumWL(
		SportType	INT,
		BetType		INT,
		ProductID	INT
	);

	INSERT INTO #TmpCondSumWL(SportType, BetType,ProductID) 
	SELECT f.SportType, f.BetType, ISNULL(p.GroupProductId, f.ProductID) 
	FROM dbo.f_SumWinloss_ConditionSel(@ProductIds) f
		LEFT JOIN @ExistingProductDetails e ON f.ProductID = e.ProductId
		LEFT JOIN dbo.f_GroupProduct() p ON f.ProductID = p.ProductId
	WHERE e.ProductId IS NULL OR (e.Bettype = f.BetType)

	CREATE TABLE #ComWinLossDetails 
	(	
		CustID			INT, 
		ProductID		INT,
		Turnover		MONEY,
		TurnoverNoDraw	MONEY,
		GrossComm		MONEY, 
		MemberWinLost	MONEY,
		PlayerComm		MONEY,
		MemberTotal		MONEY,
		AgWinLost		MONEY,
		AgComm			MONEY,
		AgTotal			MONEY,
		MAgWinLost		MONEY,
		MAgComm			MONEY,
		MAgTotal		MONEY,
		SAgWinLost		MONEY, 
		SAgComm			MONEY, 
		SAgTotal		MONEY, 
		Company			MONEY,
		BetCount		INT
	);

	CREATE TABLE #ComWinLossDetailsSuperList
	(
		CustID			INT, 
		Name			NVARCHAR(100)
	);

	CREATE TABLE #GrossComm (CustId INT, ProductId INT, TurnoverNoDraw MONEY, GrossComm MONEY)

	--Avoid Parameter Sniffing for bettrans and sum_winloss
	DECLARE @FDate	SMALLDATETIME,
			@TDate	SMALLDATETIME,
			@CID	INT;
	    
	SELECT	@FDate = @FromDate,
			@TDate = @ToDate


	IF @ToDate >= @BalanceUpDay
	BEGIN
		IF @FromDate <= @MoveBetsDay
		BEGIN
			SET @FDate = DATEADD(DD, 1, @MoveBetsDay);
		END

		INSERT INTO #ComWinLossDetails(CustID, ProductID,Turnover,TurnoverNoDraw,GrossComm, MemberWinLost,PlayerComm,MemberTotal,AgWinLost,AgComm,AgTotal,MAgWinLost,MAgComm,MAgTotal,SAgWinLost, SAgComm, SAgTotal, Company,BetCount)
		SELECT
			SRecommend,																																																	
			s.ProductID,																									
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
					ELSE scomm/(1 - tpositiontaking)
				END) AS GrossComm,
			SUM(winlost - actual_stake) ,
			SUM(playercomm) ,
			SUM(winlost - actual_stake) + SUM(playercomm),
			SUM(awinlost),
			ISNULL(SUM(comm - playercomm),0) ,
			SUM(awinlost) + ISNULL(SUM(comm - playercomm),0),
			SUM(mwinlost) ,
			SUM(acomm)-SUM(comm),
			SUM(mwinlost) + SUM(acomm)-SUM(comm),
			SUM(swinlost),																										
			SUM(scomm) - SUM(acomm),																							
			SUM(swinlost) + SUM(scomm) -SUM(acomm),																			
			-(SUM(swinlost) +SUM(awinlost)+ SUM(winlost-actual_stake) + SUM(mwinlost) + SUM(scomm)) ,						
			COUNT(1)																										

		FROM bodb02.dbo.bettrans b WITH (NOLOCK)
			INNER JOIN (
							SELECT	ISNULL(p.GroupProductId, f.ProductID) AS ProductID, f.BetType, f.RefTable
							FROM dbo.f_SportBettypeMatrixByProduct_Sel(@ProductIds, @IsTest) f
								LEFT JOIN dbo.f_GroupProduct() p ON f.ProductID = p.ProductId
								LEFT JOIN @ExistingProductDetails e ON e.ProductId = f.ProductID 
							WHERE EXISTS(SELECT 1
										 WHERE e.ProductId IS NULL 
											OR 
												(
													e.Bettype = f.BetType 
														  OR (
																e.Bettype = 0 AND f.BetType NOT IN (SELECT g.Bettype FROM f_GetProductDetail() g)
															 )
												)
										)												
							) s ON b.bettype = s.Bettype
		WHERE b.winlostdate BETWEEN @FDate AND @Tdate
			AND b.srecommend IN (SELECT custID FROM #tmpSuperList) 
			AND b.statusID IN (111, 112, 113) 
		GROUP BY srecommend, s.ProductID

		-- bettransRnG
		INSERT INTO #GrossComm (CustId, ProductId, TurnoverNoDraw, GrossComm)
		SELECT b.srecommend AS CustId, s.ProductId
			,SUM(CASE WHEN cont.ContributionBettype IS NULL THEN b.BetStake ELSE 0 END) AS TurnoverNoDraw
			,SUM(b.BetStake * b.sdiscount) AS GrossComm
		FROM dbo.bettransRnG b WITH(NOLOCK)
			INNER JOIN (
							SELECT	ISNULL(p.GroupProductId, f.ProductID) AS ProductID, f.BetType
							FROM dbo.f_SportBettypeMatrixByProduct_Sel(@ProductIds, @IsTest) f
								LEFT JOIN dbo.f_GroupProduct() p ON f.ProductID = p.ProductId
								LEFT JOIN @ExistingProductDetails e ON e.ProductId = f.ProductID 
							WHERE EXISTS(SELECT 1
										 WHERE e.ProductId IS NULL 
											OR 
												(
													e.Bettype = f.BetType 
														  OR (
																e.Bettype = 0 AND f.BetType NOT IN (SELECT g.Bettype FROM f_GetProductDetail() g)
															 )
												)
										)
								AND f.RefTable = 1
							) s ON b.gameID = s.Bettype
			OUTER APPLY 
			(
				SELECT f.Bettype AS ContributionBettype
				FROM dbo.f_BettypePrizeGroup() f
				WHERE f.BettypeGroup = 'Contribution'
					AND f.Bettype = b.gameID
			) cont
		WHERE winlostdate BETWEEN @FDate AND @TDate
			AND statusID IN (111, 112, 113) 
			AND b.srecommend IN (SELECT custID FROM #tmpSuperList)
		GROUP BY b.srecommend, s.ProductId
		
		-- bettransLC
		INSERT INTO #GrossComm (CustId, ProductId, TurnoverNoDraw, GrossComm)
		SELECT b.srecommend AS CustId, s.ProductId
			,SUM(CASE WHEN cont.ContributionBettype IS NULL THEN b.NetStake ELSE 0 END) AS TurnoverNoDraw
			,SUM(b.NetStake * b.sdiscount) AS GrossComm
		FROM dbo.bettransLC b WITH(NOLOCK)
			INNER JOIN (
							SELECT	ISNULL(p.GroupProductId, f.ProductID) AS ProductID, f.BetType
							FROM dbo.f_SportBettypeMatrixByProduct_Sel(@ProductIds, @IsTest) f
								LEFT JOIN dbo.f_GroupProduct() p ON f.ProductID = p.ProductId
								LEFT JOIN @ExistingProductDetails e ON e.ProductId = f.ProductID 
							WHERE EXISTS(SELECT 1
										 WHERE e.ProductId IS NULL 
											OR 
												(
													e.Bettype = f.BetType 
														  OR (
																e.Bettype = 0 AND f.BetType NOT IN (SELECT g.Bettype FROM f_GetProductDetail() g)
															 )
												)
										)
								AND f.RefTable = 1
							) s ON b.gameID = s.Bettype
			OUTER APPLY 
			(
				SELECT f.Bettype AS ContributionBettype
				FROM dbo.f_BettypePrizeGroup() f
				WHERE f.BettypeGroup = 'Contribution'
					AND f.Bettype = b.gameID
			) cont
		WHERE winlostdate BETWEEN @FDate AND @TDate
			AND statusID IN (111, 112, 113) 
			AND b.srecommend IN (SELECT custID FROM #tmpSuperList)
		GROUP BY b.srecommend, s.ProductId

		IF EXISTS (SELECT 1 FROM #GrossComm)
		BEGIN
			UPDATE t
			SET t.TurnoverNoDraw = ISNULL(t.TurnoverNoDraw, 0) + ISNULL(c.TurnoverNoDraw, 0)
				,t.GrossComm = ISNULL(t.GrossComm, 0) + ISNULL(c.GrossComm, 0)
			FROM #ComWinLossDetails t
				INNER JOIN (
					SELECT CustId, ProductId, SUM(GrossComm) AS GrossComm, SUM(TurnoverNoDraw) AS TurnoverNoDraw FROM #GrossComm GROUP BY CustId, ProductId
				) c ON t.CustId = c.CustId AND t.ProductId = c.ProductId
		END
		
		IF @BalanceUpDay < @FromDate
		BEGIN
			SET @FDate = @FromDate;
		END
		ELSE
		BEGIN
			SET @FDate = @BalanceUpDay;
		END
		
		IF @ToDate > @MoveBetsDay
		BEGIN
			SET @TDate = @MoveBetsDay;
		END

		INSERT INTO #ComWinLossDetails(CustID, ProductID,Turnover,TurnoverNoDraw,GrossComm, MemberWinLost,PlayerComm,MemberTotal,AgWinLost,AgComm,AgTotal,MAgWinLost,MAgComm,MAgTotal,SAgWinLost, SAgComm, SAgTotal, Company,BetCount)
		SELECT b.CustID,
			   t.ProductID,
			   SUM(Turnover),
			   SUM(TunroverNoDraw),
			   SUM(GrossComm),
			   SUM(winlost),
			   SUM(playercomm),
			   SUM(winlost) + SUM(playercomm),
			   SUM(awinlost),
			   ISNULL(SUM(comm - playercomm),0),
			   SUM(awinlost) + ISNULL(SUM(comm - playercomm),0),
			   SUM(mwinlost),
			   SUM(acomm) - SUM(comm),
			   SUM(mwinlost) +  SUM(acomm) - SUM(comm),
			   SUM(swinlost),
			   ISNULL(SUM(scomm),0) - ISNULL(SUM(acomm),0),
			   SUM(swinlost) +  ISNULL(SUM(scomm),0) -  ISNULL(SUM(acomm),0),
			   	-(SUM(swinlost)+ SUM(mwinlost) +SUM(awinlost) + SUM(winlost)  + SUM(scomm)),
			 SUM(betcount)

		FROM dbo.SUM_winloss b WITH(NOLOCK)
			INNER JOIN #TmpCondSumWL t ON b.sporttype = t.sporttype AND b.bettype = t.bettype
		WHERE b.winlostdate BETWEEN @FDate AND @TDate
			AND b.custid  IN (SELECT tmp.custID FROM #tmpSuperList tmp) 
			AND RoleID = 4
		GROUP BY b.CustID, ProductID;
	END

	SELECT	@FDate = @FromDate,
			@TDate = @ToDate;
	
	IF @FromDate < @BalanceUpDay
	BEGIN
		IF @ToDate >= DATEADD(dd, -1, @BalanceUpDay)
		BEGIN
			SELECT @TDate = DATEADD(dd, -1, @BalanceUpDay);
		END

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



		-- using cte to remove predicate when seek on sum_winloss_old
		INSERT INTO #ComWinLossDetails(CustID, ProductID,Turnover,TurnoverNoDraw,GrossComm, MemberWinLost,PlayerComm,MemberTotal,AgWinLost,AgComm,AgTotal,MAgWinLost,MAgComm,MAgTotal,SAgWinLost, SAgComm, SAgTotal, Company,BetCount)
		SELECT b.CustID,
			   w.ProductID,
			   SUM(Turnover),
			   SUM(TunroverNoDraw),
			   SUM(GrossComm),
			   SUM(winlost),
			   SUM(playercomm),
			   SUM(winlost) + SUM(playercomm),
			   SUM(awinlost),
			   ISNULL(SUM(comm - playercomm),0),
			   SUM(awinlost) + ISNULL(SUM(comm - playercomm),0),
			   SUM(mwinlost),
			   SUM(acomm) - SUM(comm),
			   SUM(mwinlost) + SUM(acomm) - SUM(comm),
			   SUM(swinlost),
			   ISNULL(SUM(scomm),0) - ISNULL(SUM(acomm),0),
			   SUM(swinlost) +  ISNULL(SUM(scomm),0) -  ISNULL(SUM(acomm),0),
			   	-(SUM(swinlost)+ SUM(mwinlost) +SUM(awinlost) + SUM(winlost)  + SUM(scomm)),
				SUM(betcount)

		FROM bodb_Summary.dbo.Sum_WinLoss_Old b WITH(NOLOCK)
		CROSS APPLY (
				SELECT  t.winlostdate, u.SportType, u.BetType, u.ProductID
				FROM #TmpCondSumWL u
				cross join @winlostdateTable t
		) w
		WHERE b.winlostdate = w.winlostdate
			AND b.custid  IN (SELECT tmp.custID FROM #tmpSuperList tmp) 
			AND b.RoleID = 4
			AND b.sporttype = w.sporttype
			AND b.bettype = w.bettype
		GROUP BY b.CustID,  w.ProductID;
	END

	IF @TotalRecords = 0  
	BEGIN  
	
		INSERT INTO #ComWinLossDetailsSuperList(CustID,Name)
		SELECT	w.CustID, c.UserName  	
		FROM #ComWinLossDetails w 	
		INNER JOIN dbo.custinfo c WITH(NOLOCK) ON w.CustID = c.CustID
		GROUP BY w.CustID, c.UserName 

		SELECT @TotalRecords = count(CustID)
		FROM #ComWinLossDetailsSuperList;

		--SELECT @TotalRecords = count(distinct CustID)
		--FROM #ComWinLossDetails;

	END

	IF ((@PageSize <= 0) AND (@PageIndex <= 0))
	BEGIN

		SELECT 	w.CustID,
				c.UserName,
				w.ProductID,
				p.ProductName,
				SUM(Turnover) Turnover,
				SUM(TurnoverNoDraw) TurnoverNoDraw,
				SUM(GrossComm) GrossComm, 
				SUM(MemberWinLost) MemberWinLost,
				SUM(PlayerComm) PlayerComm,
				SUM(MemberTotal) MemberTotal,
				SUM(AgWinLost) AgWinLost,
				SUM(AgComm) AgComm,
				SUM(AgTotal) AgTotal,
				SUM(MAgWinLost) MAgWinLost,
				SUM(MAgComm) MAgComm	,
				SUM(MAgTotal) MAgTotal,
				SUM(SAgWinLost) SAgWinLost, 
				SUM(SAgComm) SAgComm	, 
				SUM(SAgTotal) SAgTotal, 
				SUM(Company) Company,
				SUM(BetCount) BetCount
		FROM #ComWinLossDetails w
		INNER JOIN dbo.custinfo c WITH(NOLOCK) ON w.CustID = c.CustID
		INNER JOIN dbo.Products p WITH(NOLOCK) ON w.ProductId = p.ProductID
		GROUP BY w.CustID,c.UserName,w.ProductID, p.ProductName
		ORDER BY c.UserName

		SELECT	NULL AS CustId,
				'Total' AS UserName,
				NULL AS  ProductID,
				NULL AS  ProductName,
				SUM(Turnover) Turnover,
				SUM(TurnoverNoDraw) TurnoverNoDraw,
				SUM(GrossComm) GrossComm, 
				SUM(MemberWinLost) MemberWinLost,
				SUM(PlayerComm) PlayerComm,
				SUM(MemberTotal) MemberTotal,
				SUM(AgWinLost) AgWinLost,
				SUM(AgComm) AgComm,
				SUM(AgTotal) AgTotal,
				SUM(MAgWinLost) MAgWinLost,
				SUM(MAgComm) MAgComm	,
				SUM(MAgTotal) MAgTotal,
				SUM(SAgWinLost) SAgWinLost, 
				SUM(SAgComm) SAgComm	, 
				SUM(SAgTotal) SAgTotal, 
				SUM(Company) Company,
				SUM(BetCount) BetCount
		FROM	#ComWinLossDetails;

		RETURN
	END


	;WITH CTE_filter(CustID) AS
	(	SELECT CustID FROM
		(
			SELECT CustID,  ROW_NUMBER() OVER(ORDER BY name ASC) as rownum FROM #ComWinLossDetailsSuperList
		) sort
		WHERE sort.rownum BETWEEN @RowStart AND @RowEnd
		
	)
	SELECT 	w.CustID,
			c.UserName,
			w.ProductID,
			p.ProductName,
			SUM(Turnover) Turnover,
			SUM(TurnoverNoDraw) TurnoverNoDraw,
			SUM(GrossComm) GrossComm, 
			SUM(MemberWinLost) MemberWinLost,
			SUM(PlayerComm) PlayerComm,
			SUM(MemberTotal) MemberTotal,
			SUM(AgWinLost) AgWinLost,
			SUM(AgComm) AgComm,
			SUM(AgTotal) AgTotal,
			SUM(MAgWinLost) MAgWinLost,
			SUM(MAgComm) MAgComm	,
			SUM(MAgTotal) MAgTotal,
			SUM(SAgWinLost) SAgWinLost, 
			SUM(SAgComm) SAgComm	, 
			SUM(SAgTotal) SAgTotal, 
			SUM(Company) Company,
			SUM(BetCount) BetCount
	FROM #ComWinLossDetails w
	INNER JOIN CTE_filter f ON f.CustID = w.CustID
	INNER JOIN dbo.custinfo c WITH(NOLOCK) ON w.CustID = c.CustID
	INNER JOIN dbo.Products p WITH(NOLOCK) ON w.ProductId = p.ProductID
	GROUP BY w.CustID, c.UserName, w.ProductID, p.ProductName
	ORDER BY c.UserName


	
	SELECT	NULL AS CustId,
			'Total' AS UserName,
			NULL AS  ProductID,
			NULL AS  ProductName,
			SUM(Turnover) Turnover,
			SUM(TurnoverNoDraw) TurnoverNoDraw,
			SUM(GrossComm) GrossComm, 
			SUM(MemberWinLost) MemberWinLost,
			SUM(PlayerComm) PlayerComm,
			SUM(MemberTotal) MemberTotal,
			SUM(AgWinLost) AgWinLost,
			SUM(AgComm) AgComm,
			SUM(AgTotal) AgTotal,
			SUM(MAgWinLost) MAgWinLost,
			SUM(MAgComm) MAgComm	,
			SUM(MAgTotal) MAgTotal,
			SUM(SAgWinLost) SAgWinLost, 
			SUM(SAgComm) SAgComm	, 
			SUM(SAgTotal) SAgTotal, 
			SUM(Company) Company,
			SUM(BetCount) BetCount
	FROM	#ComWinLossDetails;

DROP TABLE #TmpCondSumWL
DROP TABLE #ComWinLossDetails
DROP TABLE #ComWinLossDetailsSuperList
DROP TABLE #tmpSuperList
DROP TABLE #GrossComm

GO
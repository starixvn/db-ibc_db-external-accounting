/*<info serverAlias="DBAGE-bodb02" executers="wsv_xnap" isFunction="0" isNested="0"></info>*/
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
		- 20220208@Danny: Separate Saba Sport Performance [Redmine: #167177]
		- 20220525@Danny: Separate Saba Sport Performance [Redmine: #173196]
		- 20221208@Eddie: Add New SABA ESports PinGoal [RedmineID: #181383]
		- 20221229@Bobby: Enhance GrossComm figure [RedmineID: #182155]
		- 20230630@Lewis: Add Saba Tennis [RedmineID: #190459]
		- 20240125@Lewis: Show Archived User [RedmineID: #199410]
		- 20240306@Lewis: Add Virtual Ice Hockey [RedmineID: #201129]
		- 20240515@Lewis: Add SABA Kabaddi [RedmineID: #203763]
		- 20241216@Bobby: Enhance MBU date range [RedmineID: #215182]

	 @ProductDetails:		
		N'<ROOT>
                <ProductDetail ProductId="32" Sporttype="248" Bettype="0" LeagueGroupId="0" TicketType="0"/>
                <ProductDetail ProductId="32" Sporttype="248" Bettype="4297" LeagueGroupId="0" TicketType="0"/>
                <ProductDetail ProductId="32" Sporttype="248" Bettype="4298" LeagueGroupId="0" TicketType="0"/>
                <ProductDetail ProductId="45" Sporttype="243" Bettype="0" LeagueGroupId="0" TicketType="0"/>
                <ProductDetail ProductId="45" Sporttype="243" Bettype="3150" LeagueGroupId="0" TicketType="0"/>
                <ProductDetail ProductId="36" Sporttype="247" Bettype="0" LeagueGroupId="0" TicketType="0"/>
                <ProductDetail ProductId="36" Sporttype="247" Bettype="4599" LeagueGroupId="0" TicketType="0"/>
                <ProductDetail ProductId="36" Sporttype="247" Bettype="4600" LeagueGroupId="0" TicketType="0"/>
                <ProductDetail ProductId="21" Sporttype="211" Bettype="0" LeagueGroupId="0" TicketType="0"/>
                <ProductDetail ProductId="21" Sporttype="211" Bettype="2499" LeagueGroupId="0" TicketType="0"/>
                <ProductDetail ProductId="1" Sporttype="0" Bettype="0" LeagueGroupId="0" TicketType="0"/>
                <ProductDetail ProductId="1" Sporttype="0" Bettype="0" LeagueGroupId="0" TicketType="1"/>
                <ProductDetail ProductId="1" Sporttype="1" Bettype="0" LeagueGroupId="42" TicketType="0"/>
                <ProductDetail ProductId="1" Sporttype="1" Bettype="0" LeagueGroupId="74" TicketType="0"/>
                <ProductDetail ProductId="1" Sporttype="1" Bettype="0" LeagueGroupId="108" TicketType="0"/>
                <ProductDetail ProductId="1" Sporttype="2" Bettype="0" LeagueGroupId="42" TicketType="0"/>
                <ProductDetail ProductId="1" Sporttype="50" Bettype="0" LeagueGroupId="42" TicketType="0"/>
                <ProductDetail ProductId="1" Sporttype="1" Bettype="0" LeagueGroupId="113" TicketType="0"/>
                <ProductDetail ProductId="1" Sporttype="2" Bettype="0" LeagueGroupId="122" TicketType="0"/>
            </ROOT>'
*/
BEGIN
	SET NOCOUNT ON

	DECLARE @RowStart	INT,
			@RowEnd		INT

	SELECT	@PageIndex = @PageIndex - 1,
			@RowStart = @PageSize * @PageIndex + 1,
			@RowEnd = @RowStart + @PageSize - 1;

	DROP TABLE IF EXISTS #tmpSuperList;
	CREATE TABLE #tmpSuperList (custID INT PRIMARY KEY, UserName VARCHAR(50));

	INSERT INTO #tmpSuperList(CustID, UserName)
	SELECT cg.custId, ci.username
	FROM dbo.Acc_CustGroup cg WITH(NOLOCK)
		LEFT JOIN dbo.custinfo ci WITH(NOLOCK) ON ci.custid = cg.custid -- COVER archived accounts
	WHERE cg.GroupName = @GroupName
		AND (@custid IS NULL OR cg.custid = @custid)
	;


	DECLARE @ExistingProductDetails TABLE (ProductId INT,Sporttype INT,Bettype INT, LeagueGroupID SMALLINT, TicketType TINYINT)
	DECLARE @isTest BIT, @__ProductDetails XML;
	SELECT  @isTest = dbo.f_CheckSPVersion(@@PROCID);	

	SELECT @ProductIds = dbo.f_AddRelatedProducts(@ProductIds);
	SELECT @__ProductDetails = CONVERT(XML, @ProductDetails)

	INSERT INTO @ExistingProductDetails(ProductId, Sporttype,Bettype,LeagueGroupID,TicketType)
	SELECT ProductId,Sporttype,Bettype,LeagueGroupID,TicketType
	FROM dbo.f_ProductDetail_ConditionSel(@ProductDetails, @__ProductDetails)

	DECLARE @SeparateSabaSport_Cutoff SMALLDATETIME 

	SELECT @SeparateSabaSport_Cutoff = CutoffDate
	FROM dbo.f_GetCutoffDate()
	WHERE TypeName = 'SabaSport'

	DROP TABLE IF EXISTS #TmpCondSumWL;
	CREATE TABLE #TmpCondSumWL(
		SportType		INT,
		BetType			INT,
		ProductID		INT,
		LeagueGroupID	SMALLINT, 
		TicketType		TINYINT
	);

	IF @FromDate <= @MoveBetsDay
	BEGIN
		INSERT INTO #TmpCondSumWL(SportType, BetType, LeagueGroupID, TicketType, ProductID) 
		SELECT f.SportType, f.BetType, f.LeagueGroupID, f.TicketType, ISNULL(p.GroupProductId, f.ProductID)
		FROM dbo.f_SumWinloss_ConditionSel(@ProductIds) f
			LEFT JOIN @ExistingProductDetails e ON f.ProductID = e.ProductId 
			LEFT JOIN dbo.f_GroupProduct() p ON f.ProductID = p.ProductId    
		WHERE e.ProductId IS NULL OR (e.Bettype = f.BetType AND e.Sporttype = f.SportType AND e.TicketType = f.TicketType AND e.LeagueGroupID = f.LeagueGroupID AND e.ProductID =  ISNULL(p.GroupProductId, f.ProductID))
	END

	DROP TABLE IF EXISTS #ComWinLossDetails;
	CREATE TABLE #ComWinLossDetails 
	(	
		CustID			INT, 
		ProductID		INT,
		Turnover		DECIMAL(24,4),
		TurnoverNoDraw	DECIMAL(24,4),
		GrossComm		DECIMAL(24,4), 
		MemberWinLost	DECIMAL(24,4),
		PlayerComm		DECIMAL(24,4),
		MemberTotal		DECIMAL(24,4),
		AgWinLost		DECIMAL(24,4),
		AgComm			DECIMAL(24,4),
		AgTotal			DECIMAL(24,4),
		MAgWinLost		DECIMAL(24,4),
		MAgComm			DECIMAL(24,4),
		MAgTotal		DECIMAL(24,4),
		SAgWinLost		DECIMAL(24,4), 
		SAgComm			DECIMAL(24,4), 
		SAgTotal		DECIMAL(24,4), 
		Company			DECIMAL(24,4)
		INDEX CIX_#ComWinLossDetails CLUSTERED (CustID, ProductID)
	);

	DROP TABLE IF EXISTS #GrossComm;
	CREATE TABLE #GrossComm (CustId INT, ProductId INT, TurnoverNoDraw DECIMAL(24, 4), GrossComm DECIMAL(24, 4))

	--Avoid Parameter Sniffing for bettrans and sum_winloss
	DECLARE @FDate	SMALLDATETIME,
			@TDate	SMALLDATETIME;
	    
	--TODO: bettrans_compact
	SELECT @FDate = FromDate, @TDate = ToDate
	FROM (VALUES(@FromDate)) AS t (CheckDate)
	OUTER APPLY (
		SELECT * FROM dbo.f_MBU_RangeDate(CheckDate, @ToDate, @BalanceUpDay, @MoveBetsDay)
		WHERE RangeType = 1
	) AS fc
	
	IF @FDate IS NOT NULL
	BEGIN
		-- bettrans 
		; WITH cte_SportBettype AS (
			SELECT	ISNULL(p.GroupProductId, f.ProductID) AS ProductID, f.BetType, f.RefTable, ISNULL(e.LeagueGroupID,0) AS LeagueGroupID, ISNULL(e.TicketType,0) AS TicketType, ISNULL(SportType,0) AS SportType
			FROM dbo.f_SportBettypeMatrixByProduct_Sel(@ProductIds, @IsTest) f
				LEFT JOIN dbo.f_GroupProduct() p ON f.ProductID = p.ProductId
				LEFT JOIN @ExistingProductDetails e ON e.ProductId = f.ProductID 
			WHERE EXISTS(
				SELECT 1
				WHERE e.ProductId IS NULL 
				OR (e.Bettype = f.BetType 
					OR (
						e.Bettype = 0  AND  (e.ProductId = 1 OR  f.BetType NOT IN (SELECT g.Bettype FROM f_GetProductDetail() g WHERE g.ProductId <> 1))
					)
				)
			)		
		)
		INSERT INTO #ComWinLossDetails(CustID, ProductID,Turnover,TurnoverNoDraw,GrossComm, MemberWinLost,PlayerComm,MemberTotal,AgWinLost,AgComm,AgTotal,MAgWinLost,MAgComm,MAgTotal,SAgWinLost, SAgComm, SAgTotal, Company)
		SELECT
			b.custID,																																																	
			s.ProductID,																									
			SUM(ABS(b.Turnover)),
			SUM(TurnoverNoDraw) AS TurnoverNoDraw,
			SUM(GrossComm) AS GrossComm,
			SUM(winlost) ,
			SUM(playercomm) ,
			SUM(winlost) + SUM(playercomm),
			SUM(awinlost),
			ISNULL(SUM(comm - playercomm),0) ,
			SUM(awinlost) + ISNULL(SUM(comm - playercomm),0),
			SUM(mwinlost) ,
			SUM(acomm)-SUM(comm),
			SUM(mwinlost) + SUM(acomm)-SUM(comm),
			SUM(swinlost),																										
			SUM(scomm) - SUM(acomm),																							
			SUM(swinlost) + SUM(scomm) -SUM(acomm),																			
			-(SUM(swinlost) +SUM(awinlost)+ SUM(winlost) + SUM(mwinlost) + SUM(scomm))				
		FROM bodb_Age.dbo.bettrans_compact b WITH (NOLOCK)
			INNER JOIN #tmpSuperList ts ON ts.custID = b.custid
			INNER JOIN cte_SportBettype s ON b.bettype = s.bettype 
					AND (s.ProductID <> 1 OR (s.ProductID = 1 AND b.sporttype = s.SportType AND b.LeagueGroupID = s.LeagueGroupID AND b.TicketType = s.TicketType))
		WHERE b.winlostdate BETWEEN @FDate AND @Tdate
		GROUP BY b.custID, s.ProductID

		-- bettransRnG
		INSERT INTO #GrossComm (CustId, ProductId, TurnoverNoDraw, GrossComm)
		SELECT ts.custID, s.ProductId
			,SUM(CASE WHEN cont.ContributionBettype IS NULL THEN b.BetStake ELSE 0 END) AS TurnoverNoDraw
			,SUM(b.BetStake * b.sdiscount) AS GrossComm
		FROM dbo.bettransRnG b WITH(NOLOCK)
			INNER JOIN #tmpSuperList ts ON ts.custID = b.srecommend
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
																e.Bettype = 0  AND  (e.ProductId = 1 OR  f.BetType NOT IN (SELECT g.Bettype FROM f_GetProductDetail() g WHERE g.ProductId <> 1) )
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
		GROUP BY ts.custID, s.ProductId
		
		-- bettransLC
		INSERT INTO #GrossComm (CustId, ProductId, TurnoverNoDraw, GrossComm)
		SELECT ts.custID, s.ProductId
			,SUM(CASE WHEN cont.ContributionBettype IS NULL THEN b.NetStake ELSE 0 END) AS TurnoverNoDraw
			,SUM(b.NetStake * b.sdiscount) AS GrossComm
		FROM dbo.bettransLC b WITH(NOLOCK)
			INNER JOIN #tmpSuperList ts ON ts.custID = b.srecommend
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
																e.Bettype = 0  AND  (e.ProductId = 1 OR  f.BetType NOT IN (SELECT g.Bettype FROM f_GetProductDetail() g WHERE g.ProductId <> 1) )
														)
												)
										)
								AND f.RefTable = 2
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
		GROUP BY ts.custID, s.ProductId

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
	END
		
	DECLARE @winlostdateTable TABLE (winlostdate SMALLDATETIME, custid INT);

	--TODO: sum_winloss
	SELECT @FDate = FromDate, @TDate = ToDate
	FROM (VALUES(@FromDate)) AS t (CheckDate)
	OUTER APPLY (
		SELECT * FROM dbo.f_MBU_RangeDate(CheckDate, @ToDate, @BalanceUpDay, @MoveBetsDay)
		WHERE RangeType = 2
	) AS fc
	
	IF @FDate IS NOT NULL
	BEGIN
		DELETE @winlostdateTable;

		WITH CTE_Winlostdate (winlostdate ) AS
		(
			SELECT @FDate AS winlostdate
			UNION ALL
			SELECT DATEADD(DAY, 1, winlostdate)
			FROM CTE_Winlostdate
			WHERE winlostdate < @TDate
		)
		INSERT INTO @winlostdateTable(winlostdate, custid)
		SELECT cte.winlostdate, ts.custid
		FROM CTE_Winlostdate cte
		CROSS JOIN #tmpSuperList ts

		INSERT INTO #ComWinLossDetails(CustID, ProductID,Turnover,TurnoverNoDraw,GrossComm, MemberWinLost,PlayerComm,MemberTotal,AgWinLost,AgComm,AgTotal,MAgWinLost,MAgComm,MAgTotal,SAgWinLost, SAgComm, SAgTotal, Company)
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
			   	-(SUM(swinlost)+ SUM(mwinlost) +SUM(awinlost) + SUM(winlost)  + SUM(scomm))

		FROM dbo.SUM_winloss b WITH(NOLOCK) 
			INNER JOIN @winlostdateTable ts ON b.winlostdate = ts.winlostdate
				AND b.srecommend = ts.custid
			INNER JOIN #TmpCondSumWL t ON b.sporttype = t.sporttype 
				AND b.bettype = t.bettype 
				AND b.leagueGroupID = t.LeagueGroupID 
				AND b.ticketType = t.TicketType

		WHERE b.mrecommend		= 0
			AND b.recommend		= 0
			AND b.RoleID		= 4
		GROUP BY b.CustID, t.ProductID;
	END

	--TODO: sum_winloss_old
	SELECT @FDate = FromDate, @TDate = ToDate
	FROM (VALUES(@FromDate)) AS t (CheckDate)
	OUTER APPLY (
		SELECT * FROM dbo.f_MBU_RangeDate(CheckDate, @ToDate, @BalanceUpDay, @MoveBetsDay)
		WHERE RangeType = 3
	) AS fc
	
	IF @FDate IS NOT NULL
	BEGIN
		DELETE @winlostdateTable;
		;WITH CTE_Winlostdate (winlostdate ) AS
		(
			SELECT @FDate AS winlostdate
			UNION ALL
			SELECT DATEADD(DAY, 1, winlostdate)
			FROM CTE_Winlostdate
			WHERE winlostdate < @TDate
		)
		INSERT INTO @winlostdateTable(winlostdate, custid)
		SELECT cte.winlostdate, ts.custid
		FROM CTE_Winlostdate cte
		CROSS JOIN #tmpSuperList ts
		OPTION (MAXRECURSION 0);

		-- using cte to remove predicate when seek on sum_winloss_old
		INSERT INTO #ComWinLossDetails(CustID, ProductID,Turnover,TurnoverNoDraw,GrossComm, MemberWinLost,PlayerComm,MemberTotal,AgWinLost,AgComm,AgTotal,MAgWinLost,MAgComm,MAgTotal,SAgWinLost, SAgComm, SAgTotal, Company)
		SELECT ts.CustID,
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
			   SUM(mwinlost) + SUM(acomm) - SUM(comm),
			   SUM(swinlost),
			   ISNULL(SUM(scomm),0) - ISNULL(SUM(acomm),0),
			   SUM(swinlost) +  ISNULL(SUM(scomm),0) -  ISNULL(SUM(acomm),0),
			   	-(SUM(swinlost)+ SUM(mwinlost) +SUM(awinlost) + SUM(winlost)  + SUM(scomm))

		FROM bodb_Summary.dbo.SUM_winloss_old b WITH(NOLOCK) 
			INNER JOIN @winlostdateTable ts ON b.winlostdate = ts.winlostdate
				AND b.srecommend = ts.custid
			INNER JOIN #TmpCondSumWL t ON b.sporttype = t.sporttype 
				AND b.bettype = t.bettype 
				AND b.leagueGroupID = t.LeagueGroupID 
				AND b.ticketType = t.TicketType

		WHERE b.mrecommend		= 0
			AND b.recommend		= 0
			AND b.RoleID		= 4
		GROUP BY ts.CustID, t.ProductID;
	END
			
	--TODO: Export excel
	IF ((@PageSize <= 0) AND (@PageIndex <= 0))
	BEGIN
		SELECT 	ts.CustID,
				ts.UserName,
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
				SUM(Company) Company
		FROM #ComWinLossDetails w
			LEFT JOIN #tmpSuperList ts ON w.CustID = ts.CustID
			INNER JOIN dbo.Products p WITH(NOLOCK) ON w.ProductId = p.ProductID
		GROUP BY ts.CustID
				, ts.UserName
				, w.ProductID
				, p.ProductName
		ORDER BY IIF(ts.Username IS NULL,1,0), ts.Username;

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
				SUM(Company) Company
		FROM	#ComWinLossDetails;

		RETURN
	END

	--TODO: Paging result
	ELSE 
	BEGIN
		SELECT @TotalRecords = COUNT(DISTINCT custid) FROM #ComWinLossDetails;

		;WITH CTE_filter AS
		(	
			SELECT ts.CustID, ts.UserName
				,  ROW_NUMBER() OVER(ORDER BY IIF(ts.Username IS NULL,1,0), ts.UserName ASC) as rownum 
			FROM #tmpSuperList ts
			INNER JOIN (
				SELECT DISTINCT custid FROM #ComWinLossDetails
			) AS w ON w.CustID = ts.custID
		)
		SELECT 	ts.CustID,
				ts.UserName,
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
				SUM(Company) Company
		FROM #ComWinLossDetails w
			LEFT JOIN CTE_filter ts ON ts.CustID = w.CustID
			INNER JOIN dbo.Products p WITH(NOLOCK) ON w.ProductId = p.ProductID
		WHERE ts.rownum BETWEEN @RowStart AND @RowEnd
		GROUP BY 
			ts.CustID
			, ts.UserName
			, w.ProductID
			, p.ProductName
		ORDER BY IIF(ts.Username IS NULL,1,0),ts.UserName
	
		-- TODO: Sum Total
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
				SUM(Company) Company
		FROM	#ComWinLossDetails;
	END
END
GO
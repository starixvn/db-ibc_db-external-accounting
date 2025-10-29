/*<info serverAlias="DBAGE-bodb02" executers="wsv_xnap" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[EAS_Rpt_WinLossDetail_bySubGroup] 	
	@FromDate		SMALLDATETIME,
	@ToDate			SMALLDATETIME,
	@ProductIds		VARCHAR(MAX) = '46',
	@ProductDetails NVARCHAR(MAX) = 'All',
	@GroupName		VARCHAR(50) = 'ACCINDO',
	@SubGroup		VARCHAR(50) = NULL,
	@SubGroupList   NVARCHAR(MAX) = '',
	@BalanceUpDay	SMALLDATETIME,
	@MoveBetsDay	SMALLDATETIME,
	@PageSize		INT = 0,
	@PageIndex		INT = 0,
	@TotalRecords	INT = 0 OUTPUT
AS
/*
	Created by: Evan
	Date: 2022-01-07
	Task : Implement new report Win Loss Detail By Sub Group
	DB: DBAGE/bodb02
	Revisions:
		- 20220107@Evan: Initialize SPs [RedmineID : #166058]
		- 20220317@Danny: Separate Saba Sport Performance [Redmine: #167177]
		- 20221208@Eddie: Add New SABA ESports PinGoal [RedmineID: #181383]
		- 20221229@Bobby: Enhance GrossComm figure [RedmineID: #182155]
		- 20230630@Lewis: Add Saba Tennis [RedmineID: #190459]
		- 20240306@Lewis: Add Virtual Ice Hockey [RedmineID: #201129]
		- 20240515@Lewis: Add SABA Kabaddi [RedmineID: #203763]
		- 20240729@Lewis: Scale Out DBCust - Remove Linked Server [Redmine : #206895]
		- 20241216@Bobby: Enhance MBU date range [RedmineID: #215182]
		- 20250528@Dave: Add RewardAmount column [RedmineID: #228292]
		- 20251028@Bobby: Changes impact on core func f_GetProductDetail [RedmineID: #235369]

	Param's Explanation:  
		@FromDate, @ToDate: date range  
		@ProductIds: list of products  
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
		@GroupName: main group
		@SubGroup: sub groups of main group (default get all)
*/
BEGIN
	SET NOCOUNT ON

	DECLARE @RowStart	INT,
			@RowEnd		INT
			
	SELECT	@PageIndex = @PageIndex - 1,
			@RowStart = @PageSize * @PageIndex + 1,
			@RowEnd = @RowStart + @PageSize - 1;

	DROP TABLE IF EXISTS #tmpSuperList;
	CREATE TABLE #tmpSuperList (custID INT PRIMARY KEY)
	 -- ========================================

	-- Get list of subgroup
	DROP TABLE IF EXISTS #tmpSubGroup;
	CREATE TABLE #tmpSubGroup (SubGroup VARCHAR(50))
	
	IF ISNULL(@SubGroupList,'')<>''
	BEGIN
		INSERT INTO #tmpSubGroup
		SELECT	SubGroup
		FROM	OPENJSON (@SubGroupList)
		WITH (SubGroup VARCHAR(50))
		WHERE	SubGroup = ISNULL(@SubGroup,SubGroup);
	END
	 -- ========================================
	-- Get list of super, avoid case SubGroup not belong to MainGroup

	IF EXISTS (	SELECT TOP 1 1 FROM #tmpSubGroup)
		INSERT INTO #tmpSuperList(CustID)
		SELECT custID 
		FROM bodb02.dbo.Acc_CustGroup WITH(NOLOCK)
		WHERE GroupName = ISNULL(@SubGroup,@GroupName)

	ELSE IF @SubGroup IS NULL
		INSERT INTO #tmpSuperList(CustID)
		SELECT custID 
		FROM bodb02.dbo.Acc_CustGroup WITH(NOLOCK)
		WHERE GroupName = @GroupName

	DECLARE @ExistingProductDetails TABLE (ProductId INT,Sporttype INT,Bettype INT,LeagueGroupID SMALLINT, TicketType TINYINT)
	DECLARE @isTest BIT, @__ProductDetails XML;

	DECLARE @SeparateSabaSport_Cutoff SMALLDATETIME 

	SELECT @SeparateSabaSport_Cutoff = CutoffDate
	FROM dbo.f_GetCutoffDate()
	WHERE TypeName = 'SabaSport'

	SELECT @isTest = dbo.f_CheckSPVersion(@@PROCID);	
	SELECT @ProductIds = dbo.f_AddRelatedProducts(@ProductIds);
	SELECT @__ProductDetails = CONVERT(XML, @ProductDetails)

	INSERT INTO @ExistingProductDetails(ProductId,Sporttype,Bettype,LeagueGroupID,TicketType)
	SELECT ProductId,Sporttype,Bettype,LeagueGroupID,TicketType
	FROM dbo.f_ProductDetail_ConditionSel(@ProductDetails, @__ProductDetails)

	DROP TABLE IF EXISTS #TmpCondSumWL;
	CREATE TABLE #TmpCondSumWL(
		SportType	INT,
		BetType		INT,
		LeagueGroupID SMALLINT, 
		TicketType TINYINT,
		INDEX IX_SportType (SportType, BetType)
	);

	IF @FromDate <= @MoveBetsDay
	BEGIN
		INSERT INTO #TmpCondSumWL(SportType, BetType, LeagueGroupID, TicketType) 
		SELECT f.SportType, f.BetType, f.LeagueGroupID, f.TicketType
		FROM dbo.f_SumWinloss_ConditionSel(@ProductIds) f
			LEFT JOIN @ExistingProductDetails e ON f.ProductID = e.ProductId 
		WHERE e.ProductId IS NULL OR (e.Bettype = f.BetType AND e.Sporttype = f.SportType AND e.TicketType = f.TicketType AND e.LeagueGroupID = f.LeagueGroupID AND e.ProductID = f.ProductId)
	END

	DROP TABLE IF EXISTS #ComWinLossDetails;
	CREATE TABLE #ComWinLossDetails 
	(	
		CustID			INT, 
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
		Company			DECIMAL(24,4),
		RewardAmount    MONEY DEFAULT(0)
	);

	DROP TABLE IF EXISTS #ComWinLossDetailsSubGroupList;
	CREATE TABLE #ComWinLossDetailsSubGroupList
	(
		CustID				INT, 
		SubGroup			VARCHAR(50)
	);

	DROP TABLE IF EXISTS #GrossComm;
	CREATE TABLE #GrossComm (CustId INT, TurnoverNoDraw DECIMAL(24,4), GrossComm DECIMAL(24,4))

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

		;WITH cte_SportBettype AS (
			SELECT	ISNULL(p.GroupProductId, f.ProductID) AS ProductID, f.BetType, f.RefTable, ISNULL(e.LeagueGroupID,0) AS LeagueGroupID, ISNULL(e.TicketType,0) AS TicketType, ISNULL(SportType,0) AS SportType
			FROM dbo.f_SportBettypeMatrixByProduct_Sel(@ProductIds, @IsTest) f
				LEFT JOIN dbo.f_GroupProduct() p ON f.ProductID = p.ProductId
				LEFT JOIN @ExistingProductDetails e ON e.ProductId = f.ProductID 
			WHERE EXISTS(
				SELECT 1
				WHERE e.ProductId IS NULL 
				OR (
					e.Bettype = f.BetType 
						OR (
							e.Bettype = 0  AND  (e.ProductId = 1 OR  f.BetType NOT IN (SELECT g.Bettype FROM f_GetProductDetail_Old() g WHERE g.ProductId <> 1) )
						)
					)
				)		
		)
		INSERT INTO #ComWinLossDetails(CustID, Turnover,TurnoverNoDraw,GrossComm, MemberWinLost,PlayerComm,MemberTotal,AgWinLost,AgComm,AgTotal,MAgWinLost,MAgComm,MAgTotal,SAgWinLost, SAgComm, SAgTotal, Company)
		SELECT
			b.custid,																																																	
			SUM(ABS(b.Turnover)) AS Turnover,
			SUM(TurnoverNoDraw) AS TurnoverNoDraw,
			SUM(GrossComm) AS GrossComm,
			SUM(winlost) AS MemberWinLost,
			SUM(playercomm) ,
			SUM(winlost) + SUM(playercomm) AS MemberTotal ,
			SUM(awinlost),
			ISNULL(SUM(comm - playercomm),0) AS AgComm,
			SUM(awinlost) + ISNULL(SUM(comm - playercomm),0) AS AgTotal,
			SUM(mwinlost) AS MAgWinLost,
			SUM(acomm)-SUM(comm) AS MAgComm,
			SUM(mwinlost) + SUM(acomm)-SUM(comm) AS MAgTotal,
			SUM(swinlost) AS SAgWinLost,																										
			SUM(scomm) - SUM(acomm) AS SAgComm,																							
			SUM(swinlost) + SUM(scomm) -SUM(acomm) AS SAgTotal,																			
			-(SUM(swinlost) +SUM(awinlost)+ SUM(winlost) + SUM(mwinlost) + SUM(scomm)) AS Company			
		FROM bodb_Age.dbo.bettrans_compact b WITH(NOLOCK)
			INNER JOIN #tmpSuperList ts On ts.custID = b.custid
			INNER JOIN cte_SportBettype s ON b.bettype = s.bettype 
					AND (s.ProductID <> 1 OR (s.ProductID = 1 AND b.sporttype = s.SportType AND b.LeagueGroupID = s.LeagueGroupID AND b.TicketType = s.TicketType))
		WHERE b.winlostdate BETWEEN @FDate AND @Tdate
		GROUP BY b.custid

		-- bettransRnG
		INSERT INTO #GrossComm (CustId, TurnoverNoDraw, GrossComm)
		SELECT b.srecommend AS CustId
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
																e.Bettype = 0 AND f.BetType NOT IN (SELECT g.Bettype FROM f_GetProductDetail_Old() g)
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
		GROUP BY b.srecommend
		
		-- bettransLC
		INSERT INTO #GrossComm (CustId, TurnoverNoDraw, GrossComm)
		SELECT b.srecommend AS CustId
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
																e.Bettype = 0 AND f.BetType NOT IN (SELECT g.Bettype FROM f_GetProductDetail_Old() g)
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
			AND b.srecommend IN (SELECT custID FROM #tmpSuperList)
		GROUP BY b.srecommend

		IF EXISTS (SELECT 1 FROM #GrossComm)
		BEGIN
			UPDATE t
			SET t.TurnoverNoDraw = ISNULL(t.TurnoverNoDraw, 0) + ISNULL(c.TurnoverNoDraw, 0)
				,t.GrossComm = ISNULL(t.GrossComm, 0) + ISNULL(c.GrossComm, 0)
			FROM #ComWinLossDetails t
				INNER JOIN (
					SELECT CustId, SUM(GrossComm) AS GrossComm, SUM(TurnoverNoDraw) AS TurnoverNoDraw 
					FROM #GrossComm 
					GROUP BY CustId
				) c ON t.CustId = c.CustId 
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
		CROSS JOIN #tmpSuperList ts;

		INSERT INTO #ComWinLossDetails(CustID, Turnover,TurnoverNoDraw,GrossComm, MemberWinLost,PlayerComm,MemberTotal,AgWinLost,AgComm,AgTotal,MAgWinLost,MAgComm,MAgTotal,SAgWinLost, SAgComm, SAgTotal, Company)
		SELECT ts.CustID,
			   SUM(Turnover),
			   SUM(TunroverNoDraw),
			   SUM(GrossComm),
			   SUM(winlost) AS MemberWinLost,
			   SUM(playercomm),
			   SUM(winlost) + SUM(playercomm) AS MemberTotal,
			   SUM(awinlost) AS AgWinLost,
			   ISNULL(SUM(comm - playercomm),0) AS AgComm,
			   SUM(awinlost) + ISNULL(SUM(comm - playercomm),0) AS AgTotal,
			   SUM(mwinlost) AS MAgWinLost,
			   SUM(acomm) - SUM(comm) AS MAgComm,
			   SUM(mwinlost) +  SUM(acomm) - SUM(comm) AS MAgTotal,
			   SUM(swinlost) AS SAgWinLost,
			   ISNULL(SUM(scomm),0) - ISNULL(SUM(acomm),0) AS SAgComm,
			   SUM(swinlost) +  ISNULL(SUM(scomm),0) -  ISNULL(SUM(acomm),0) AS SAgTotal,
			   	-(SUM(swinlost)+ SUM(mwinlost) +SUM(awinlost) + SUM(winlost)  + SUM(scomm)) AS Company
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
		GROUP BY ts.CustID;
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

		;WITH CTE_Winlostdate (winlostdate) AS
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
		INSERT INTO #ComWinLossDetails(CustID, Turnover,TurnoverNoDraw,GrossComm, MemberWinLost,PlayerComm,MemberTotal,AgWinLost,AgComm,AgTotal,MAgWinLost,MAgComm,MAgTotal,SAgWinLost, SAgComm, SAgTotal, Company)
		SELECT ts.CustID,
			   SUM(Turnover),
			   ISNULL(SUM(TunroverNoDraw), 0),
			   SUM(GrossComm),
			   SUM(winlost) AS MemberWinLost,
			   SUM(playercomm),
			   SUM(winlost) + SUM(playercomm) AS MemberTotal,
			   SUM(awinlost) AS AgWinLost,
			   ISNULL(SUM(comm - playercomm),0) AS AgComm,
			   SUM(awinlost) + ISNULL(SUM(comm - playercomm),0) AS AgTotal,
			   SUM(mwinlost) AS MAgWinLost,
			   SUM(acomm) - SUM(comm) AS MAgComm,
			   SUM(mwinlost) +  SUM(acomm) - SUM(comm) AS MAgTotal,
			   SUM(swinlost) AS SAgWinLost,
			   ISNULL(SUM(scomm),0) - ISNULL(SUM(acomm),0) AS SAgComm,
			   SUM(swinlost) +  ISNULL(SUM(scomm),0) -  ISNULL(SUM(acomm),0) AS SAgTotal,
			   	-(SUM(swinlost)+ SUM(mwinlost) +SUM(awinlost) + SUM(winlost)  + SUM(scomm)) AS Company
		FROM bodb_Summary.dbo.Sum_WinLoss_Old b WITH(NOLOCK)
			INNER JOIN @winlostdateTable ts ON b.winlostdate = ts.winlostdate
				AND b.srecommend = ts.custid
			INNER JOIN #TmpCondSumWL t ON b.sporttype = t.sporttype 
				AND b.bettype = t.bettype 
				AND b.leagueGroupID = t.LeagueGroupID 
				AND b.ticketType = t.TicketType

		WHERE b.mrecommend		= 0
			AND b.recommend		= 0
			AND b.RoleID		= 4
		GROUP BY ts.CustID;

	END

	/*Reward processing*/
	SELECT @FDate = @FromDate, @TDate = @ToDate;
	WITH CTE_RewardProcessing AS (
		SELECT 
			a.custid,
			SUM(swt.Amount) as TotalAmount
		FROM #tmpSuperList a
		INNER JOIN SabaWalletTicket swt WITH (NOLOCK) ON 
			swt.WinlostDate BETWEEN @FDate AND @Tdate
			AND swt.WalletID = 2
			AND swt.srecommend = a.custid
		GROUP BY a.custid
	)
	INSERT #ComWinLossDetails (
		CustID, Turnover, TurnoverNoDraw, GrossComm, MemberWinLost, PlayerComm, MemberTotal,
		AgWinLost, AgComm, AgTotal, MAgWinLost, MAgComm, MAgTotal, SAgWinLost, SAgComm, SAgTotal, Company, RewardAmount
	)
	SELECT 
		custid,
		0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,   /*All columns except RewardAmount set to 0*/
		TotalAmount
	FROM CTE_RewardProcessing
	WHERE TotalAmount > 0;

	DECLARE @CurrencyCode VARCHAR(12);

	SELECT TOP(1) @CurrencyCode = e.Code
	FROM #tmpSuperList w WITH(NOLOCK)
	INNER JOIN dbo.CustInfo c WITH(NOLOCK)
		ON w.CustID = c.custid
	INNER JOIN dbo.Exchange e WITH (NOLOCK)
		ON c.currency = e.ExchangeId;

	--TODO: Export excel
	IF ((@PageSize <= 0) AND (@PageIndex <= 0))
	BEGIN

		SELECT 	w.CustID,
				d.GroupName AS SubGroup,
				c.UserName,
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
				SUM(RewardAmount) RewardAmount,
				@CurrencyCode RewardCurrency
		FROM #ComWinLossDetails w
		INNER JOIN dbo.custinfo c WITH(NOLOCK) ON w.CustID = c.CustID
		OUTER APPLY (	SELECT GroupName 
						FROM dbo.Acc_CustGroup g WITH (NOLOCK)
						WHERE w.CustID = g.CustID and g.GroupName IN (SELECT SubGroup FROM #tmpSubGroup)) d
		GROUP BY w.CustID, c.UserName,d.GroupName
		ORDER BY COALESCE(d.GroupName,'zzzz'),c.username;

		SELECT	NULL AS CustId,
				'Total' AS UserName,
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
				SUM(RewardAmount) RewardAmount,
				@CurrencyCode RewardCurrency
		FROM	#ComWinLossDetails;

		RETURN
	END

	--TODO: Paging
	IF @TotalRecords = 0  
	BEGIN  

		INSERT INTO #ComWinLossDetailsSubGroupList(CustID,SubGroup)
		SELECT	CustID	,GroupName
		FROM (	
			SELECT w.CustID,d.GroupName   
			FROM #ComWinLossDetails w   
			OUTER APPLY (	
				SELECT GroupName   
				FROM dbo.Acc_CustGroup g WITH (NOLOCK)   
				WHERE w.CustID = g.CustID AND g.GroupName IN (SELECT SubGroup FROM #tmpSubGroup) 
			) d  
			GROUP BY w.CustID,d.GroupName
		) a
		
		SELECT @TotalRecords = COUNT(1)
		FROM #ComWinLossDetailsSubGroupList;

	END

	;WITH CTE_Filter(CustID,SubGroup,username) AS
	(	
		SELECT	CustID,SubGroup,username 
		FROM	(
					SELECT c.CustID, SubGroup, c.username, ROW_NUMBER() OVER(ORDER BY COALESCE(SubGroup,'zzzz'),c.username) as RowNum
					FROM #ComWinLossDetailsSubGroupList w 
						INNER JOIN dbo.custinfo c WITH(NOLOCK) ON c.custid = w.CustID
				) sort
		WHERE sort.rownum BETWEEN @RowStart AND @RowEnd
	)
   SELECT w.CustID,  
		 f.SubGroup,  
		 f.UserName,  
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
		 SUM(MAgComm) MAgComm ,  
		 SUM(MAgTotal) MAgTotal,  
		 SUM(SAgWinLost) SAgWinLost,   
		 SUM(SAgComm) SAgComm ,   
		 SUM(SAgTotal) SAgTotal,   
		 SUM(Company) Company,
		 SUM(RewardAmount) RewardAmount,
		 @CurrencyCode RewardCurrency
   FROM #ComWinLossDetails w  
		INNER JOIN CTE_Filter f ON f.CustID = w.CustID
   GROUP BY w.CustID, f.SubGroup, f.username
   ORDER BY COALESCE(f.SubGroup,'zzzz'), f.username
	
	SELECT	NULL AS CustId,
			'Total' AS UserName,
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
			SUM(RewardAmount) RewardAmount,
			@CurrencyCode RewardCurrency
	FROM	#ComWinLossDetails;

END
GO
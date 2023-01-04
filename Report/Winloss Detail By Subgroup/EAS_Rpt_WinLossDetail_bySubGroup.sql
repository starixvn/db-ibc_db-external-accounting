/*<info serverAlias="DBAGE-bodb02" executers="bodbExtAccNet" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[EAS_Rpt_WinLossDetail_bySubGroup] 	
	@FromDate		SMALLDATETIME,
	@ToDate			SMALLDATETIME,
	@ProductIds		VARCHAR(MAX) = '46',
	@ProductDetails NVARCHAR(MAX) = 'All',
	@GroupName		VARCHAR(50) = 'ACCINDO',
	@SubGroup		VARCHAR(50) = NULL,
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

	DECLARE @ParentID INT

	SELECT @ParentID = GroupID FROM DBCUST.NAP_UserControl.dbo.eaGroup WITH(NOLOCK) WHERE GroupName = @GroupName

	-- Get list of subgroup
	DROP TABLE IF EXISTS #tmpSubGroup;
	CREATE TABLE #tmpSubGroup (SubGroup VARCHAR(50))
	
	INSERT INTO #tmpSubGroup
	SELECT	GroupName
	FROM	DBCUST.NAP_UserControl.dbo.eaGroup WITH(NOLOCK)
	WHERE	ParentID = @ParentID
			AND GroupName = ISNULL(@SubGroup,GroupName);

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
		TicketType TINYINT
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
		Company			MONEY
	);

	DROP TABLE IF EXISTS #ComWinLossDetailsSubGroupList;
	CREATE TABLE #ComWinLossDetailsSubGroupList
	(
		CustID				INT, 
		SubGroup			VARCHAR(50)
	);

	DROP TABLE IF EXISTS #GrossComm;
	CREATE TABLE #GrossComm (CustId INT, TurnoverNoDraw MONEY, GrossComm MONEY)

	--Avoid Parameter Sniffing for bettrans and sum_winloss
	DECLARE @FDate	SMALLDATETIME,
			@TDate	SMALLDATETIME;
	    
	SELECT	@FDate = @FromDate,
			@TDate = @ToDate

	IF @ToDate >= @BalanceUpDay
	BEGIN
		IF @FromDate <= @MoveBetsDay
		BEGIN
			SET @FDate = DATEADD(DD, 1, @MoveBetsDay);
		END

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
							e.Bettype = 0  AND  (e.ProductId = 1 OR  f.BetType NOT IN (SELECT g.Bettype FROM f_GetProductDetail() g WHERE g.ProductId <> 1) )
						)
					)
				)		
		),
		cte_bettrans AS
		(
			SELECT  SRecommend,
					SUM(ABS(b.stake)) stake,
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
					SUM(winlost) winlost,
					SUM(actual_stake) actual_stake,
					SUM(playercomm) playercomm,
					SUM(acomm) acomm,
					SUM(comm) comm,
					SUM(scomm) scomm,
					SUM(swinlost) swinlost,
					SUM(mwinlost) mwinlost,
					SUM(awinlost) awinlost
			FROM	bodb02.dbo.bettrans b WITH (NOLOCK)
				LEFT JOIN dbo.match m WITH(NOLOCK) ON b.matchid = m.matchid AND m.eventdate = b.winlostdate AND m.sporttype IN (1,2,50,43)
				LEFT JOIN (
						SELECT LeagueGroupID, leagueid
						FROM dbo.League l WITH(NOLOCK) WHERE l.LeagueGroupID IN (42,74,108,113,122,151)
				) AS l  ON m.leagueid = l.leagueid
				OUTER APPLY (
					SELECT CASE WHEN ( 
							(l.LeagueGroupID IN (42,74,108,113) AND m.sporttype = 1 ) 
								OR (l.LeagueGroupID IN (122, 42) AND m.sporttype = 2 )
								OR (l.LeagueGroupID = 42 AND m.sporttype = 50)
								OR (l.LeagueGroupID = 151 AND m.sporttype = 43)
							) AND b.betdaqid <> -2 AND b.winlostdate >= @SeparateSabaSport_Cutoff THEN m.sporttype
					ELSE 0 END  sporttype, 
					CASE WHEN ( 
								(l.LeagueGroupID IN (42,74,108,113) AND m.sporttype = 1 ) 
									OR (l.LeagueGroupID IN (122, 42) AND m.sporttype = 2 )
									OR (l.LeagueGroupID = 42 AND m.sporttype = 50)
									OR (l.LeagueGroupID = 151 AND m.sporttype = 43)
								) AND b.betdaqid <> -2 AND b.winlostdate >= @SeparateSabaSport_Cutoff THEN l.LeagueGroupID
					ELSE 0 END LeagueGroupID,
					CASE WHEN b.betdaqid = -2 THEN 1 ELSE 0 END TicketType
				) AS et
				INNER JOIN cte_SportBettype s ON b.bettype = s.bettype 
					AND (s.ProductID <> 1 OR (s.ProductID = 1 AND et.sporttype = s.SportType AND et.LeagueGroupID = s.LeagueGroupID AND et.TicketType = s.TicketType))
			WHERE b.winlostdate BETWEEN @FDate AND @Tdate
				AND b.srecommend IN (SELECT custID FROM #tmpSuperList) 
				AND b.statusID IN (111, 112, 113) 
			GROUP BY SRecommend	
					
		)

		INSERT INTO #ComWinLossDetails(CustID, Turnover,TurnoverNoDraw,GrossComm, MemberWinLost,PlayerComm,MemberTotal,AgWinLost,AgComm,AgTotal,MAgWinLost,MAgComm,MAgTotal,SAgWinLost, SAgComm, SAgTotal, Company)
		SELECT
			SRecommend,																																																	
			SUM(ABS(b.stake)) AS Turnover,
			SUM(TurnoverNoDraw) AS TurnoverNoDraw,
			SUM(GrossComm) AS GrossComm,
			SUM(winlost - actual_stake) AS MemberWinLost,
			SUM(playercomm) ,
			SUM(winlost - actual_stake) + SUM(playercomm) AS MemberTotal ,
			SUM(awinlost),
			ISNULL(SUM(comm - playercomm),0) AS AgComm,
			SUM(awinlost) + ISNULL(SUM(comm - playercomm),0) AS AgTotal,
			SUM(mwinlost) AS MAgWinLost,
			SUM(acomm)-SUM(comm) AS MAgComm,
			SUM(mwinlost) + SUM(acomm)-SUM(comm) AS MAgTotal,
			SUM(swinlost) AS SAgWinLost,																										
			SUM(scomm) - SUM(acomm) AS SAgComm,																							
			SUM(swinlost) + SUM(scomm) -SUM(acomm) AS SAgTotal,																			
			-(SUM(swinlost) +SUM(awinlost)+ SUM(winlost-actual_stake) + SUM(mwinlost) + SUM(scomm)) AS Company					
		FROM cte_bettrans b
		GROUP BY srecommend

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
																e.Bettype = 0 AND f.BetType NOT IN (SELECT g.Bettype FROM f_GetProductDetail() g)
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

		INSERT INTO #ComWinLossDetails(CustID, Turnover,TurnoverNoDraw,GrossComm, MemberWinLost,PlayerComm,MemberTotal,AgWinLost,AgComm,AgTotal,MAgWinLost,MAgComm,MAgTotal,SAgWinLost, SAgComm, SAgTotal, Company,BetCount)
		SELECT b.CustID,
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
			   	-(SUM(swinlost)+ SUM(mwinlost) +SUM(awinlost) + SUM(winlost)  + SUM(scomm)) AS Company,
			 SUM(betcount) AS BetCount
		FROM dbo.SUM_winloss b WITH(NOLOCK)
			INNER JOIN #TmpCondSumWL t ON b.sporttype = t.sporttype AND b.bettype = t.bettype AND ISNULL(b.leagueGroupID,0) = t.LeagueGroupID AND ISNULL(b.ticketType,0) = t.TicketType
		WHERE b.winlostdate BETWEEN @FDate AND @TDate
			AND b.custid  IN (SELECT tmp.custID FROM #tmpSuperList tmp) 
			AND RoleID = 4
		GROUP BY b.CustID;
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

		;WITH CTE_Winlostdate (winlostdate) AS
		(
			SELECT @FDate AS winlostdate
			UNION ALL
			SELECT DATEADD(DAY, 1, winlostdate)
			FROM CTE_Winlostdate
			WHERE winlostdate < @TDate
		)
		INSERT INTO @winlostdateTable(winlostdate)
		SELECT * FROM CTE_Winlostdate
		OPTION (MAXRECURSION 0)
		
		-- using cte to remove predicate when seek on sum_winloss_old
		INSERT INTO #ComWinLossDetails(CustID, Turnover,TurnoverNoDraw,GrossComm, MemberWinLost,PlayerComm,MemberTotal,AgWinLost,AgComm,AgTotal,MAgWinLost,MAgComm,MAgTotal,SAgWinLost, SAgComm, SAgTotal, Company,BetCount)
		SELECT b.CustID,
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
			   	-(SUM(swinlost)+ SUM(mwinlost) +SUM(awinlost) + SUM(winlost)  + SUM(scomm)) AS Company,
			 SUM(betcount) AS BetCount
		FROM bodb_Summary.dbo.Sum_WinLoss_Old b WITH(NOLOCK)
		CROSS APPLY (
				SELECT  t.winlostdate, u.SportType, u.BetType, u.LeagueGroupID, u.TicketType
				FROM #TmpCondSumWL u
				CROSS JOIN @winlostdateTable t
		) w
		WHERE b.winlostdate = w.winlostdate
			AND b.custid  IN (SELECT tmp.custID FROM #tmpSuperList tmp) 
			AND b.RoleID = 4
			AND b.sporttype = w.sporttype
			AND b.bettype = w.bettype
			AND ISNULL(b.leagueGroupID,0) = w.LeagueGroupID 
			AND ISNULL(b.ticketType,0) = w.TicketType
		GROUP BY b.CustID;
		
	END

	IF @TotalRecords = 0  
	BEGIN  

		INSERT INTO #ComWinLossDetailsSubGroupList(CustID,SubGroup)
		SELECT	CustID	,GroupName
		FROM (	SELECT w.CustID,d.GroupName   
				FROM #ComWinLossDetails w   
				OUTER APPLY (	SELECT GroupName   
								FROM Acc_CustGroup g WITH (NOLOCK)   
								WHERE w.CustID = g.CustID AND g.GroupName IN (SELECT SubGroup FROM #tmpSubGroup) 
							) d  
				GROUP BY w.CustID,d.GroupName
			) a
		
		SELECT @TotalRecords = COUNT(CustID)
		FROM #ComWinLossDetailsSubGroupList;

	END

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
				SUM(BetCount) BetCount
		FROM #ComWinLossDetails w
		INNER JOIN dbo.custinfo c WITH(NOLOCK) ON w.CustID = c.CustID
		OUTER APPLY (	SELECT GroupName 
						FROM Acc_CustGroup g WITH (NOLOCK)
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
				SUM(BetCount) BetCount
		FROM	#ComWinLossDetails;

		RETURN
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
		 SUM(BetCount) BetCount
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
			SUM(BetCount) BetCount
	FROM	#ComWinLossDetails;

END
GO
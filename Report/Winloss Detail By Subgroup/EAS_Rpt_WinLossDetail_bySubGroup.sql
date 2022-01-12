/*<info serverAlias="DBAGE-bodb02" executers="bodbExtAccNet" isFunction="0" isNested="0"></info>*/
CREATE PROCEDURE [dbo].[EAS_Rpt_WinLossDetail_bySubGroup] 	
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
	Param's Explanation:  
		@FromDate, @ToDate: date range  
		@ProductIds: list of products  
		@ProductDetails:    
			<ROOT>  
				<ProductDetail ProductId = "32" Sporttype = "248" Bettype = "0"/>  
				<ProductDetail ProductId = "32" Sporttype = "248" Bettype = "4298"/>  
			</ROOT> 
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

	CREATE TABLE #tmpSuperList (custID INT PRIMARY KEY)
	DECLARE @ParentID INT
	SELECT @ParentID = GroupID FROM DBCUST.NAP_UserControl.dbo.eaGroup WITH(NOLOCK) WHERE GroupName = @GroupName

	-- Get list of subgroup
	DECLARE @ListSubGroup TABLE (SubGroup Varchar(50))

	INSERT INTO @ListSubGroup
	SELECT GroupName
	FROM DBCUST.NAP_UserControl.dbo.eaGroup WITH(NOLOCK)
	WHERE ParentID = @ParentID
		AND GroupName = ISNULL(@SubGroup,GroupName);
	
	-- Get list of super, avoid case SubGroup not belong to MainGroup
	IF EXISTS (	SELECT TOP 1 1 FROM @ListSubGroup)
		INSERT INTO #tmpSuperList(CustID)
		SELECT custID 
		FROM bodb02.dbo.Acc_CustGroup WITH(NOLOCK)
		WHERE GroupName = ISNULL(@SubGroup,@GroupName)

	ELSE IF @SubGroup IS NULL
		INSERT INTO #tmpSuperList(CustID)
		SELECT custID 
		FROM bodb02.dbo.Acc_CustGroup WITH(NOLOCK)
		WHERE GroupName = @GroupName

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
		BetType		INT
	);

	INSERT INTO #TmpCondSumWL(SportType, BetType) 
	SELECT f.SportType, f.BetType 
	FROM dbo.f_SumWinloss_ConditionSel(@ProductIds) f
		LEFT JOIN @ExistingProductDetails e ON f.ProductID = e.ProductId
	WHERE e.ProductId IS NULL OR (e.Bettype = f.BetType)

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
		Company			MONEY,
		BetCount		INT
	);

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

		INSERT INTO #ComWinLossDetails(CustID, Turnover,TurnoverNoDraw,GrossComm, MemberWinLost,PlayerComm,MemberTotal,AgWinLost,AgComm,AgTotal,MAgWinLost,MAgComm,MAgTotal,SAgWinLost, SAgComm, SAgTotal, Company,BetCount)
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
					ELSE scomm/(1 - tpositiontaking)
				END) AS GrossComm,
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
			-(SUM(swinlost) +SUM(awinlost)+ SUM(winlost-actual_stake) + SUM(mwinlost) + SUM(scomm)) AS Company ,						
			COUNT(1) AS BetCount																										
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
			INNER JOIN #TmpCondSumWL t ON b.sporttype = t.sporttype AND b.bettype = t.bettype
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
				SELECT  t.winlostdate, u.SportType, u.BetType
				FROM #TmpCondSumWL u
				CROSS JOIN @winlostdateTable t
		) w
		WHERE b.winlostdate = w.winlostdate
			AND b.custid  IN (SELECT tmp.custID FROM #tmpSuperList tmp) 
			AND b.RoleID = 4
			AND b.sporttype = w.sporttype
			AND b.bettype = w.bettype
		GROUP BY b.CustID;
		
	END

	IF @TotalRecords = 0  
	BEGIN  
		SELECT @TotalRecords = COUNT(a.CustID)
		FROM (	SELECT w.CustID 
				FROM #ComWinLossDetails w 
				OUTER APPLY (	SELECT GroupName 
								FROM Acc_CustGroup g WITH (NOLOCK) 
								WHERE w.CustID = g.CustID and g.GroupName in (SELECT SubGroup FROM @ListSubGroup)) d
				GROUP BY w.CustID,d.GroupName
			) a
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
						WHERE w.CustID = g.CustID and g.GroupName in (SELECT SubGroup FROM @ListSubGroup)) d
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

	SELECT 	*
	FROM (
			SELECT w.CustID,
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
					SUM(BetCount) BetCount,
					ROW_NUMBER() OVER(ORDER BY COALESCE(GroupName,'zzzz'),c.UserName) as RowNum
			FROM #ComWinLossDetails w
			INNER JOIN dbo.custinfo c WITH(NOLOCK) ON w.CustID = c.CustID
			OUTER APPLY (	SELECT GroupName 
							FROM Acc_CustGroup g WITH (NOLOCK)
							WHERE w.CustID = g.CustID and g.GroupName in (SELECT SubGroup FROM @ListSubGroup)) d
			GROUP BY w.CustID, c.UserName,d.GroupName
		)rs
		WHERE rs.RowNum BETWEEN @RowStart AND @RowEnd;
	
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

	DROP TABLE #TmpCondSumWL
	DROP TABLE #ComWinLossDetails
	DROP TABLE #tmpSuperList
	DROP TABLE #GrossComm	
END
GO
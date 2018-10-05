/*<info serverAlias="DBAGE-bodb02" executers="bodbExtAccNet" viewers="" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[EAS_Rpt_WinLossDetailPokerGames_MAg]
	@custid			INT,--mrecommend
	@Agentid		INT = NULL,
	@FromDate		SMALLDATETIME,
	@ToDate			SMALLDATETIME,
	@ProductIds		VARCHAR(MAX) = '33',
	@BalanceUpDay	SMALLDATETIME,
	@MoveBetsDay	SMALLDATETIME,
	@PageSize		INT = 0,
	@PageIndex		INT = 0,
	@TotalRows		INT = 0 OUTPUT
AS
/*
	Created by: Sophia
	Date: 20180912
	Task : Master Poker Games Winloss Detail [Redmine: #101376]
	DB: DBAGE-bodb02
	Original: EAS_Rpt_WinLossDetail_MAg
	Revisions:
		-20180912@Sophia: initial SP
		- 20181003@Helen: Modify code to adapt indexes changed on DB053 [Redmine:101405]
*/
BEGIN
	SET NOCOUNT ON

	DECLARE @RowStart int, @RowEnd int, @ID INT = 1  
	SELECT @PageIndex = @PageIndex - 1, @RowStart = @PageSize * @PageIndex + 1, @RowEnd = @RowStart + @PageSize - 1


	DECLARE @MAgWinLossDetails TABLE(CustID int, Turnover money, NetTurnover MONEY, TaxComm money, TotalMemberWinLoss MONEY, MemberWinLoss money, InsGemMemberWinLoss money,
		PlayerComm money, MemberTotal money, InsGemAgWinLoss money, AgComm money, AgTotal money, 
		InsGemMAgWinLoss money, MAgComm money, MAgTotal money, Company money)

	----Get Sport Bettype Matrix------
	DECLARE @isTest BIT = 0
	SELECT  @isTest = dbo.f_CheckSPVersion(@@PROCID)

	DECLARE @SportBettype TABLE(Bettype SMALLINT)
	INSERT INTO @SportBettype ( Bettype)
	SELECT Bettype 
	FROM bodb02.dbo.f_SportBettypeMatrixByProduct_Sel(@ProductIds, @isTest) s 

	----Avoid Parameter Sniffing 
		DECLARE @FDate	SMALLDATETIME,
				@TDate	SMALLDATETIME
		    
		SELECT	@FDate = @FromDate,
				@TDate = @ToDate 
				

	----- Get Report			
			
	IF @ToDate > @MoveBetsDay
		BEGIN
			SELECT	@TDate = @ToDate,
					@FDate = CASE WHEN @FromDate <= @MoveBetsDay THEN DATEADD(DAY, 1, @MoveBetsDay) ELSE @FromDate END
			
			IF @Agentid IS NULL -- Passing mrecommend: using @custid (mrecommend)
			BEGIN
				INSERT INTO @MAgWinLossDetails
				SELECT
					Recommend,			
					SUM(ABS(b.stake)) as Turnover,
					SUM(CASE WHEN b.bettype = 1499 THEN ABS(b.stake) ELSE ISNULL(CAST(('<xml>' + b.ExtraInfo + '</xml>') AS XML).value('data(/xml/p33/@to)[1]','MONEY'), 0) END ) AS NetTurnover,
					SUM(ISNULL(b.oddsspread,0)) as TaxComm,		
					 
					SUM(b.winlost - b.actual_stake) AS TotalMemberWinLoss,			
					SUM(b.winlost - b.actual_stake) - SUM(ISNULL(b.TransID2,0)/ CONVERT(DECIMAL(19,8),10000)) AS MemberWinLoss,			
					SUM(ISNULL(b.TransID2,0)/ CONVERT(DECIMAL(19,8),10000)) AS InsGemMemberWinLoss,			
					SUM(ISNULL(b.playercomm,0)) AS PlayerComm,			
					SUM(b.winlost - b.actual_stake) + SUM(ISNULL(b.playercomm,0)) as MemberTotal, 
					
					SUM(b.awinlost) AS InsGemAgWinLoss,
					SUM(ISNULL(b.comm,0)) - SUM(ISNULL(b.playercomm,0)) AS AgComm,
					SUM(b.awinlost) + SUM(ISNULL(b.comm,0)) - SUM(ISNULL(b.playercomm,0)) AS AgTotal,					
					
					SUM(b.mwinlost) AS InsGemMAgWinLoss,
					SUM(ISNULL(b.acomm,0)) - SUM(ISNULL(b.comm,0)) AS MAgComm,
					SUM(b.mwinlost) + SUM(ISNULL(b.acomm,0)) - SUM(ISNULL(b.comm,0)) AS MAgTotal,
					
					- (SUM(b.winlost - b.actual_stake) + SUM(b.awinlost) + SUM(b.mwinlost) + SUM(ISNULL(b.acomm,0))) as Company				 			
				FROM
					bodb02.dbo.bettrans b WITH (NOLOCK)
				WHERE b.mrecommend = @custid	
					AND b.recommend * @ID = 0 -- get by recommend only
					AND winlostdate BETWEEN @FDate AND @TDate
					AND statusID IN (111, 112, 113)				
					AND EXISTS (SELECT 1 FROM @SportBettype s WHERE b.bettype = s.Bettype)
				GROUP BY Recommend 
		    
			END
			ELSE -- By agentID 
			BEGIN
				INSERT INTO @MAgWinLossDetails
				SELECT
					Recommend,			
					SUM(ABS(b.stake)) as Turnover,
					SUM(CASE WHEN b.bettype = 1499 THEN ABS(b.stake) ELSE ISNULL(CAST(('<xml>' + b.ExtraInfo + '</xml>') AS XML).value('data(/xml/p33/@to)[1]','MONEY'), 0) END ) AS NetTurnover,
					SUM(ISNULL(b.oddsspread,0)) as TaxComm,		
					 
					SUM(b.winlost - b.actual_stake) AS TotalMemberWinLoss,			
					SUM(b.winlost - b.actual_stake) - SUM(ISNULL(b.TransID2,0)/ CONVERT(DECIMAL(19,8),10000)) AS MemberWinLoss,			
					SUM(ISNULL(b.TransID2,0)/ CONVERT(DECIMAL(19,8),10000)) AS InsGemMemberWinLoss,			
					SUM(ISNULL(b.playercomm,0)) AS PlayerComm,			
					SUM(b.winlost - b.actual_stake) + SUM(ISNULL(b.playercomm,0)) as MemberTotal, 
					
					SUM(b.awinlost) AS InsGemAgWinLoss,
					SUM(ISNULL(b.comm,0)) - SUM(ISNULL(b.playercomm,0)) AS AgComm,
					SUM(b.awinlost) + SUM(ISNULL(b.comm,0)) - SUM(ISNULL(b.playercomm,0)) AS AgTotal,					
					
					SUM(b.mwinlost) AS InsGemMAgWinLoss,
					SUM(ISNULL(b.acomm,0)) - SUM(ISNULL(b.comm,0)) AS MAgComm,
					SUM(b.mwinlost) + SUM(ISNULL(b.acomm,0)) - SUM(ISNULL(b.comm,0)) AS MAgTotal,
					
					- (SUM(b.winlost - b.actual_stake) + SUM(b.awinlost) + SUM(b.mwinlost) + SUM(ISNULL(b.acomm,0))) as Company				 			
				FROM
					bodb02.dbo.bettrans b WITH (NOLOCK)
				WHERE b.recommend = @custid	
					AND winlostdate BETWEEN @FDate AND @TDate
					AND statusID IN (111, 112, 113)				
					AND EXISTS (SELECT 1 FROM @SportBettype s WHERE b.bettype = s.Bettype)
				GROUP BY Recommend 
			END
		END	
		
		IF @FromDate <= @MoveBetsDay
		BEGIN
			SELECT  @FDate = @FromDate,
					@TDate = CASE WHEN @ToDate > @MoveBetsDay THEN @MoveBetsDay ELSE @ToDate END
					
			INSERT INTO @MAgWinLossDetails
			SELECT
				CustID,			
				SUM(TurnOver) AS TurnOver,
				SUM(NetTurnover) AS NetTurnover,
				SUM(TotalComm) AS TaxComm,
				SUM(Winloss) AS TotalMemberWinLoss,
				SUM(WinLoss) - SUM(InsGemMemberWinLoss) AS MemberWinLoss,
				SUM(InsGemMemberWinLoss) AS InsGemMemberWinLoss,
				SUM(PlayerComm) AS PlayerComm,			
				SUM(Winloss) +  SUM(PlayerComm) AS MemberTotal,
				
				SUM(AgWinLoss) AS InsGemAgWinLoss,
				SUM(AgComm) - SUM(PlayerComm) AS AgComm,
				SUM(AgWinLoss) +SUM(AgComm) - SUM(PlayerComm) AS AgTotal,
				
				SUM(MAgWinLoss) AS InsGemMAgWinLoss,
				SUM(MAgComm) - SUM(AgComm) AS MAgComm,				
				SUM(MAgWinLoss) + SUM(MAgComm) - SUM(AgComm) AS MAgTotal,
				
				- (SUM(b.Winloss) + SUM(b.AgWinLoss) + SUM(b.MAgWinLoss) + SUM(ISNULL(b.MAgComm,0))) AS Company			   		
			FROM bodb_Summary.dbo.rptPokerGamesSumWinLoss b WITH(NOLOCK)
			WHERE
				winlostdate between @FDate and @TDate			
				and MRecommend = @custid 
				AND (@Agentid is null or b.recommend = @Agentid)
				and RoleID = 2
			GROUP BY CustID
		END


	IF ((@PageSize <= 0) AND (@PageIndex <= 0))
	BEGIN

		SELECT
			w.CustID, 
			c.UserName, 
			sum(Turnover) as Turnover,
			SUM(NetTurnover) as NetTurnover,
			sum(TaxComm) as TaxComm,
			sum(MemberWinLoss) as MemberWinLoss,
			sum(InsGemMemberWinLoss) as InsGemMemberWinLoss,
			sum(PlayerComm) as PlayerComm,
			sum(MemberTotal) as MemberTotal,
			sum(InsGemAgWinLoss) as InsGemAgWinLoss,
			sum(AgComm) as AgComm,
			sum(AgTotal) as AgTotal,
			sum(InsGemMAgWinLoss) as InsGemMAgWinLoss,
			sum(MAgComm) as MAgComm,
			sum(MAgTotal) as MAgTotal,
			sum(Company) as Company	
		FROM @MAgWinLossDetails w 
		INNER JOIN bodb02.dbo.Custinfo c WITH(NOLOCK) ON w.CustID = c.CustID 
		Group by w.CustID, c.UserName
		ORDER BY c.Username

		RETURN
	END


	IF @TotalRows = 0  
	BEGIN  
		SELECT @TotalRows = count(tmp.CustID)
		FROM 
		(
			SELECT CustID
			FROM @MAgWinLossDetails
			Group by CustID
		) tmp
	 
	END

	SELECT wl.*
	FROM
		(
			SELECT
				w.CustID, 
				c.UserName, 
				sum(Turnover) as Turnover,
				sum(TaxComm) as TaxComm,
				sum(InsGemMemberWinLoss) as InsGemMemberWinLoss,
				sum(PlayerComm) as PlayerComm,
				sum(MemberTotal) as MemberTotal,
				sum(InsGemAgWinLoss) as InsGemAgWinLoss,
				sum(AgComm) as AgComm,
				sum(AgTotal) as AgTotal,
				sum(InsGemMAgWinLoss) as InsGemMAgWinLoss,
				sum(MAgComm) as MAgComm,
				sum(MAgTotal) as MAgTotal,
				sum(Company) as Company,
				ROW_NUMBER() over (order by c.UserName) as RowNum
			FROM @MAgWinLossDetails w 
			INNER JOIN bodb02.dbo.Custinfo c WITH(NOLOCK) ON w.CustID = c.CustID 
			Group by w.CustID, c.UserName
		) wl
	    
	WHERE wl.RowNum between @RowStart and @RowEnd
END	
GO
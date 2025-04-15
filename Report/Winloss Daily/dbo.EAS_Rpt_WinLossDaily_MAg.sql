/*<info serverAlias="DBAGE-bodb02" executers="wsv_xnap" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[EAS_Rpt_WinLossDaily_MAg]
	@winlostdate		SMALLDATETIME,
	@custID				INT,
	@agentID			INT = NULL,
	@ExcludeProductIds	VARCHAR(MAX) = '46',
	@MemberId			INT = NULL
AS
/*
	Created by: Dan
	Date: 2012-10-29
	Task: Daily WinLoss for Site
	DB: DBAGE/bodb02
	Original: Acc_Rpt_WinLossDaily_MAgEx
	Revisions:
		- 20130121@Dan: Move sp from DB06/bodb02 to DBEAS/bodb_EAS
		- 20160107@Percy: Get data from bettransRNG, bettransLC and bettrans table [Redmine: #48286]
		- 20160215@Percy: Support new product AllBet [Redmine: #50922]
		- 20160414@Victor: Support new product Voidbridge [Redmine: #55468]
		- 20161028@Percy:
			1. Support Fishing World [RedmineID: #65735]
			2. Apply column RefTable
		- 20181004@Percy: Add @ExcludeProductIds to exclude some products [RedmineID: #101644]
		- 20181031@Helen: DB052 Indexes Revolution [RedmineID: 103572]
		- 20181113@Paul: Enhance performance [RedmineID: #103479]
		- 20190418@Kan: DB053/bodb02 Migration, Move sp from DBEAS/bodb_EAS to DB053/bodb02 [Redmine: #111865]
		- 20190826@Percy: Remove inactive products [RedmineID: #118699]
		- 20200629@Malcolm : exclude ProductId = 46 [RedmineID : #135593]
		- 20241226@Bobby: Super/Master Direct Members [RedmineID: #211969]
		
	Param's Explanation:		
		@custID: Master ID 
*/
BEGIN
	SET NOCOUNT ON

	DECLARE @isTest BIT = 0
	SELECT  @isTest = dbo.f_CheckSPVersion(@@PROCID)
	
	DECLARE @ExcludeBettype TABLE(Bettype INT)
	
	DECLARE @username_tmp NVARCHAR(50) 
	
	IF @agentID IS NOT NULL
	BEGIN
		SET @username_tmp = (SELECT username FROM bodb02.dbo.custinfo ci WITH (NOLOCK)  WHERE custID = @agentID)
	END
	
	IF ISNULL(@ExcludeProductIds, '') <> ''
		INSERT INTO @ExcludeBettype (Bettype)
		SELECT DISTINCT Bettype FROM bodb02.dbo.f_SportBettypeMatrixByProduct_Sel(@ExcludeProductIds, @isTest)
	
	IF @winlostdate < CAST(DATEADD(DD, -1, GETDATE()) AS DATE)
	BEGIN
		IF @agentID IS NULL
		BEGIN
			SELECT	d.CustID,
					ci.username, ci.RoleId,
					d.totalTO,
					d.ComTO,
					d.SAgTO,
					d.MAgTO,
					d.AgTO,
					d.ComWinlost,
					d.SAgWinlost,
					d.MAgWinlost,
					d.AgWinlost
					
			FROM (
					SELECT 
						IIF(b.Recommend=-3, b.custid, b.Recommend) AS CustID,
						SUM(ABS(b.stake)) totalTO,
						SUM(ABS(b.stake) * (1 - b.tpositiontaking)) ComTO,
						SUM(ABS(b.stake) * b.spositiontaking) SAgTO,
						SUM(ABS(b.stake) * b.mpositiontaking) MAgTO,
						SUM(ABS(b.stake) * b.apositiontaking) AgTO,
				
						-SUM(b.winlost - b.actual_stake + b.awinlost + b.mwinlost + b.swinlost + b.scomm) ComWinlost,
						SUM(b.swinlost + b.scomm - b.acomm) SAgWinlost,
						SUM(b.mwinlost + b.acomm - b.comm) MAgWinlost,
						SUM(b.awinlost + b.comm - b.playercomm) AgWinlost

					FROM	bodb02.dbo.Bettrans b WITH (NOLOCK)
					WHERE	b.winlostdate = @winlostdate
							AND b.MRecommend = @CustID 
							AND b.statusID IN (111,112,113)
							AND NOT EXISTS (SELECT 1 FROM @ExcludeBettype s WHERE s.Bettype = b.bettype)

					GROUP BY IIF(b.Recommend=-3, b.custid, b.Recommend)
				) d
				INNER JOIN bodb02.dbo.custinfo ci WITH (NOLOCK) ON d.CustID = ci.custID 
				WHERE (
						@memberId IS NULL OR 
						@memberId = d.custid --> search Direct Member
					)
			ORDER BY ci.username
		END
		ELSE
		BEGIN
						
			SELECT	b.Recommend AS CustID, 
				@username_tmp AS username, 2 AS RoleId,
				SUM(ABS(b.stake)) totalTO,
				SUM(ABS(b.stake) * (1 - b.tpositiontaking)) ComTO,
				SUM(ABS(b.stake) * b.spositiontaking) SAgTO,
				SUM(ABS(b.stake) * b.mpositiontaking) MAgTO,
				SUM(ABS(b.stake) * b.apositiontaking) AgTO,
				
				-SUM(b.winlost - b.actual_stake + b.awinlost + b.mwinlost + b.swinlost + b.scomm) ComWinlost,
				SUM(b.swinlost + b.scomm - b.acomm) SAgWinlost,
				SUM(b.mwinlost + b.acomm - b.comm) MAgWinlost,
				SUM(b.awinlost + b.comm - b.playercomm) AgWinlost

			FROM	bodb02.dbo.Bettrans b WITH (NOLOCK)
			WHERE	b.winlostdate = @winlostdate
					AND b.recommend = @agentID
					AND b.statusID IN (111,112,113)
					AND NOT EXISTS (SELECT 1 FROM @ExcludeBettype s WHERE s.Bettype = b.bettype)
			GROUP BY b.Recommend
			
		END
	END
	ELSE
	BEGIN
		DECLARE @SportBettype TABLE(ProductID INT, Bettype INT)
		INSERT INTO @SportBettype (ProductID, Bettype)
		SELECT ProductID, Bettype FROM bodb02.dbo.f_SportBettypeMatrix_Sel(0, 0, 0, 2, '', '', @isTest)
		WHERE RefTable IN (1,2) -- bettype in bettransRnG/bettransLC
		
		IF @agentID IS NULL
		BEGIN
			SELECT  a.CustID, ci.username, ci.roleid,
				SUM(totalTO) AS totalTO,
				SUM(ComTO) AS ComTO,
				SUM(SAgTO) AS SAgTO,
				SUM(MAgTO) AS MAgTO,
				SUM(AgTO) AS AgTO,
				SUM(ComWinlost) AS ComWinlost,
				SUM(SAgWinlost) AS SAgWinlost,
				SUM(MAgWinlost) AS MAgWinlost,
				SUM(AgWinlost) AS AgWinlost
			FROM (
				SELECT	IIF(b.Recommend=-3, b.custid, b.Recommend) AS CustID,
						SUM(ABS(b.stake)) totalTO,
						SUM(ABS(b.stake) * (1 - b.tpositiontaking)) ComTO,
						SUM(ABS(b.stake) * b.spositiontaking) SAgTO,
						SUM(ABS(b.stake) * b.mpositiontaking) MAgTO,
						SUM(ABS(b.stake) * b.apositiontaking) AgTO,
						
						-SUM(b.winlost - b.actual_stake + b.awinlost + b.mwinlost + b.swinlost + b.scomm) ComWinlost,
						SUM(b.swinlost + b.scomm - b.acomm) SAgWinlost,
						SUM(b.mwinlost + b.acomm - b.comm) MAgWinlost,
						SUM(b.awinlost + b.comm - b.playercomm) AgWinlost

				FROM	bodb02.dbo.Bettrans b WITH (NOLOCK)
				WHERE	b.winlostdate = @winlostdate
						AND b.MRecommend = @CustID 
						AND b.statusID IN (111,112,113)
						AND NOT EXISTS (SELECT 1 FROM @SportBettype s WHERE s.Bettype = b.bettype)
						
				GROUP BY IIF(b.Recommend=-3, b.custid, b.Recommend)
				
				UNION ALL -- bettransRNG
				
				SELECT	IIF(b.Recommend=-3, b.custid, b.Recommend) AS CustID,
						SUM(ABS(b.stake)) totalTO,
						SUM(ABS(b.stake)*(1 - b.tpositiontaking)) ComTO,
						SUM(ABS(b.stake)*b.spositiontaking) SAgTO,
						SUM(ABS(b.stake)*b.mpositiontaking) MAgTO,
						SUM(ABS(b.stake)*b.apositiontaking) AgTO,
						
						-SUM(b.winlost - b.actual_stake + b.awinlost + b.mwinlost + b.swinlost + b.scomm) ComWinlost,
						SUM(b.swinlost + b.scomm - b.acomm) SAgWinlost,
						SUM(b.mwinlost + b.acomm - b.comm) MAgWinlost,
						SUM(b.awinlost + b.comm - b.playercomm) AgWinlost

				FROM	bodb02.dbo.BettransRNG b WITH (NOLOCK)
				WHERE	b.winlostdate = @winlostdate
						AND b.MRecommend = @CustID 
						AND b.statusID IN (111,112,113)
						AND NOT EXISTS (SELECT 1 FROM @ExcludeBettype s WHERE s.Bettype = b.gameId)
						
				GROUP BY IIF(b.Recommend=-3, b.custid, b.Recommend)

				UNION ALL -- bettransLC
				
				SELECT	IIF(b.Recommend=-3, b.custid, b.Recommend) AS CustID,
						SUM(ABS(b.stake)) totalTO,
						SUM(ABS(b.stake)*(1 - b.tpositiontaking)) ComTO,
						SUM(ABS(b.stake)*b.spositiontaking) SAgTO,
						SUM(ABS(b.stake)*b.mpositiontaking) MAgTO,
						SUM(ABS(b.stake)*b.apositiontaking) AgTO,
						
						-SUM(b.winlost - b.actual_stake + b.awinlost + b.mwinlost + b.swinlost + b.scomm) ComWinlost,
						SUM(b.swinlost + b.scomm - b.acomm) SAgWinlost,
						SUM(b.mwinlost + b.acomm - b.comm) MAgWinlost,
						SUM(b.awinlost + b.comm - b.playercomm) AgWinlost

				FROM	bodb02.dbo.BettransLC b WITH (NOLOCK)
				WHERE	b.winlostdate = @winlostdate
						AND b.MRecommend = @CustID 
						AND b.statusID IN (111,112,113)
						AND NOT EXISTS (SELECT 1 FROM @ExcludeBettype s WHERE s.Bettype = b.gameId)
						
				GROUP BY IIF(b.Recommend=-3, b.custid, b.Recommend)
			) AS A
			INNER JOIN bodb02.dbo.custinfo ci WITH (NOLOCK) ON a.custID = ci.custID 
			WHERE (
						@memberId IS NULL OR 
						@memberId = ci.custid --> search Direct Member
					)
			GROUP BY a.CustID, ci.username,ci.roleid
			ORDER BY username
		
		END
		ELSE
		BEGIN
			SELECT  CustID, username, 2 AS RoleId,
				SUM(totalTO) AS totalTO,
				SUM(ComTO) AS ComTO,
				SUM(SAgTO) AS SAgTO,
				SUM(MAgTO) AS MAgTO,
				SUM(AgTO) AS AgTO,
				SUM(ComWinlost) AS ComWinlost,
				SUM(SAgWinlost) AS SAgWinlost,
				SUM(MAgWinlost) AS MAgWinlost,
				SUM(AgWinlost) AS AgWinlost
			FROM (
				SELECT	b.Recommend AS CustID,
						@username_tmp AS username,
						SUM(ABS(b.stake)) totalTO,
						SUM(ABS(b.stake) * (1 - b.tpositiontaking)) ComTO,
						SUM(ABS(b.stake) * b.spositiontaking) SAgTO,
						SUM(ABS(b.stake) * b.mpositiontaking) MAgTO,
						SUM(ABS(b.stake) * b.apositiontaking) AgTO,
						
						-SUM(b.winlost - b.actual_stake + b.awinlost + b.mwinlost + b.swinlost + b.scomm) ComWinlost,
						SUM(b.swinlost + b.scomm - b.acomm) SAgWinlost,
						SUM(b.mwinlost + b.acomm - b.comm) MAgWinlost,
						SUM(b.awinlost + b.comm - b.playercomm) AgWinlost

				FROM	bodb02.dbo.Bettrans b WITH (NOLOCK)
						
				WHERE	b.winlostdate = @winlostdate
						AND b.recommend = @agentID
						AND b.statusID IN (111,112,113)
						AND NOT EXISTS (SELECT 1 FROM @SportBettype s WHERE s.Bettype = b.bettype)
				GROUP BY b.Recommend
				
				UNION ALL -- bettransRNG
				
				SELECT	b.Recommend CustID,
						@username_tmp AS username,
						SUM(ABS(b.stake)) totalTO,
						SUM(ABS(b.stake)*(1 - b.tpositiontaking)) ComTO,
						SUM(ABS(b.stake)*b.spositiontaking) SAgTO,
						SUM(ABS(b.stake)*b.mpositiontaking) MAgTO,
						SUM(ABS(b.stake)*b.apositiontaking) AgTO,
						
						-SUM(b.winlost - b.actual_stake + b.awinlost + b.mwinlost + b.swinlost + b.scomm) ComWinlost,
						SUM(b.swinlost + b.scomm - b.acomm) SAgWinlost,
						SUM(b.mwinlost + b.acomm - b.comm) MAgWinlost,
						SUM(b.awinlost + b.comm - b.playercomm) AgWinlost

				FROM	bodb02.dbo.BettransRNG b WITH (NOLOCK)
				WHERE	b.winlostdate = @winlostdate
						AND b.recommend = @agentID
						AND b.statusID IN (111,112,113)
						AND NOT EXISTS (SELECT 1 FROM @ExcludeBettype s WHERE s.Bettype = b.gameId)
				GROUP BY b.Recommend

				UNION ALL -- bettransLC
				
				SELECT	b.Recommend CustID,
						@username_tmp AS username,
						SUM(ABS(b.stake)) totalTO,
						SUM(ABS(b.stake)*(1 - b.tpositiontaking)) ComTO,
						SUM(ABS(b.stake)*b.spositiontaking) SAgTO,
						SUM(ABS(b.stake)*b.mpositiontaking) MAgTO,
						SUM(ABS(b.stake)*b.apositiontaking) AgTO,
						
						-SUM(b.winlost - b.actual_stake + b.awinlost + b.mwinlost + b.swinlost + b.scomm) ComWinlost,
						SUM(b.swinlost + b.scomm - b.acomm) SAgWinlost,
						SUM(b.mwinlost + b.acomm - b.comm) MAgWinlost,
						SUM(b.awinlost + b.comm - b.playercomm) AgWinlost

				FROM	bodb02.dbo.BettransLC b WITH (NOLOCK)
						
				WHERE	b.winlostdate = @winlostdate
						AND b.recommend = @agentID
						AND b.statusID IN (111,112,113)
						AND NOT EXISTS (SELECT 1 FROM @ExcludeBettype s WHERE s.Bettype = b.gameId)
				GROUP BY b.Recommend
			) AS A
			GROUP BY CustID, username
			ORDER BY username
		
		END
	END
END
GO
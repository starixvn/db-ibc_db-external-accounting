/*<info serverAlias="DBAGE-bodb02" executers="wsv_xnap" viewers="" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[EAS_CustomerSelBalanceCashInfo]
	@CustId INT
AS

/*
	Created by Elodie
	Date: 2018-11-05
	DB: DBAGE.bodb02
	Task: Get Balance Information of Customer

	Revisions:
		- 20181105@Elodie: Get Balance Information of Customer by CustID [RedmineID: #95978]
		- 20241224@Max: Offer Direct Member for Super/Master [Redmine: #211969]
		
	Param's Explaination:
		- @CustId: custid
*/

BEGIN
	SET NOCOUNT ON

	DECLARE @yesterday SMALLDATETIME
	SELECT  @yesterday = CONVERT(DATE, DATEADD(DAY, -1, GETDATE()))

	-- Get bettype --
	DECLARE @isTest BIT = 0
	SELECT  @isTest = dbo.f_CheckSPVersion(@@PROCID)
	
	CREATE TABLE #SportBettype (bettype INT, RefTable TINYINT)
	INSERT INTO #SportBettype (bettype, RefTable)
	SELECT bettype, RefTable FROM dbo.f_SportBettypeMatrix_Sel (0, 0, 0, 2, '', '', @isTest)

	DECLARE @roleID TINYINT, @srecommend INT, @ID INT = 1

	SELECT  @roleID = roleid , @srecommend = srecommend FROM dbo.custInfo WITH(NOLOCK) WHERE custid = @custID
	
	IF ISNULL(@roleID, 5) > 4
	BEGIN
		RETURN
	END

	DECLARE @UsedCredit MONEY
	
	DECLARE @MinDate SMALLDATETIME
	SELECT 	@MinDate = MIN (Winlostdate)
	FROM 	dbo.bettrans b WITH (NOLOCK)
	WHERE 	b.srecommend = @srecommend
			AND b.ruben = 0	
		
	-- Get Balance Information --
	CREATE TABLE #BalanceInfo
	(
		superCash MONEY, yesterday_superCash MONEY, superOutstanding MONEY,
		masterCash MONEY, yesterday_masterCash MONEY, masterOutstanding MONEY,
		agentCash MONEY, yesterday_agentCash MONEY, agentOutstanding MONEY,
		memberCash MONEY, yesterday_memberCash MONEY, memberOutstanding MONEY
	)

    IF @roleid = 1
	BEGIN
		-- bettransRNG
		INSERT INTO #BalanceInfo (memberCash, yesterday_memberCash, memberOutstanding)
		SELECT 
			SUM(CASE WHEN statusID NOT IN (0,1) THEN winlost-actual_stake+playercomm ELSE 0 END),
			SUM(CASE WHEN statusID NOT IN (0,1) AND winlostdate = @yesterday THEN winlost-actual_stake+playercomm ELSE 0 END),
			SUM(CASE WHEN statusID IN (0,1) THEN ABS(actual_stake) ELSE 0 END)
	    FROM dbo.bettransRNG WITH(NOLOCK)
		WHERE custid = @custid
			AND (
				statusID IN (0,1)
				OR winlostdate >= @yesterday
			)

		-- bettransLC
		INSERT INTO #BalanceInfo (memberCash, yesterday_memberCash, memberOutstanding)
		SELECT 
			SUM(CASE WHEN statusID NOT IN (0,1) THEN winlost-actual_stake+playercomm ELSE 0 END),
			SUM(CASE WHEN statusID NOT IN (0,1) AND winlostdate = @yesterday THEN winlost-actual_stake+playercomm ELSE 0 END),
			SUM(CASE WHEN statusID IN (0,1) THEN ABS(actual_stake) ELSE 0 END)
	    FROM dbo.bettransLC WITH(NOLOCK)
		WHERE custid = @custid
			AND (
				statusID IN (0,1)
				OR winlostdate >= @yesterday
			)

		-- translog
		INSERT INTO #BalanceInfo (memberCash, yesterday_memberCash, memberOutstanding)
		SELECT 0, 0, ABS(actual_stake)
	    FROM dbo.translog t WITH(NOLOCK)
		WHERE custid = @custid
			AND statusID IN (0,1)

		-- bettrans
		INSERT INTO #BalanceInfo (memberCash, yesterday_memberCash, memberOutstanding)
		SELECT 0, 0, ABS(actual_stake)
		FROM dbo.bettrans b WITH(NOLOCK)
		WHERE b.custid = @custid
			AND b.ruben = 0
			AND NOT EXISTS (SELECT TOP 1 1 FROM #SportBettype s WHERE s.Bettype = b.bettype AND s.RefTable <> 0)

		INSERT INTO #BalanceInfo (memberCash, yesterday_memberCash, memberOutstanding)
		SELECT
			SUM(winlost-actual_stake+playercomm),
			SUM(CASE WHEN (winlostdate <= @yesterday OR b.bettype > 20000) THEN winlost-actual_stake+playercomm ELSE 0 END),
			0
		FROM dbo.bettrans b WITH(NOLOCK)
		WHERE b.custid = @custid
			AND b.ruben = 1
			AND (
				b.winlostdate < @yesterday
				OR NOT EXISTS (SELECT TOP 1 1 FROM #SportBettype s WHERE s.Bettype = b.bettype AND s.RefTable IN (1, 2))
			)

		SELECT
			SUM(memberCash) AS Cash,
			SUM(yesterday_memberCash) AS yesterday_Cash,
			SUM(memberOutstanding) AS outstanding
		FROM #BalanceInfo
    END 
    ELSE IF @roleid = 2
    BEGIN
	    SELECT @UsedCredit = SUM(credit)  
	    FROM DBCUST.CustDB.dbo.custinfo WITH(NOLOCK)
	    WHERE roleid = 1 AND recommend = @custid
				
		-- bettransRNG
		INSERT INTO #BalanceInfo (agentCash, yesterday_agentCash, agentOutstanding, memberCash, yesterday_memberCash, memberOutstanding)
		SELECT 
			SUM(CASE WHEN statusID NOT IN (0,1) THEN awinlost+comm-playercomm ELSE 0 END),
			SUM(CASE WHEN statusID NOT IN (0,1) AND winlostdate = @yesterday THEN awinlost+comm-playercomm ELSE 0 END),
			SUM(CASE WHEN statusID IN (0,1) THEN ABS(actual_stake * apositiontaking) ELSE 0 END),
			SUM(CASE WHEN statusID NOT IN (0,1) THEN winlost-actual_stake+playercomm ELSE 0 END),
			SUM(CASE WHEN statusID NOT IN (0,1) AND winlostdate = @yesterday THEN winlost-actual_stake+playercomm ELSE 0 END),
			SUM(CASE WHEN statusID IN (0,1) THEN ABS(actual_stake) ELSE 0 END)
	    FROM dbo.bettransRNG WITH(NOLOCK)
		WHERE recommend = @custid
			AND (
				statusID IN (0,1)
				OR winlostdate >= @yesterday
			)

		-- bettransLC
		INSERT INTO #BalanceInfo (agentCash, yesterday_agentCash, agentOutstanding, memberCash, yesterday_memberCash, memberOutstanding)
		SELECT 
			SUM(CASE WHEN statusID NOT IN (0,1) THEN awinlost+comm-playercomm ELSE 0 END),
			SUM(CASE WHEN statusID NOT IN (0,1) AND winlostdate = @yesterday THEN awinlost+comm-playercomm ELSE 0 END),
			SUM(CASE WHEN statusID IN (0,1) THEN ABS(actual_stake * apositiontaking) ELSE 0 END),
			SUM(CASE WHEN statusID NOT IN (0,1) THEN winlost-actual_stake+playercomm ELSE 0 END),
			SUM(CASE WHEN statusID NOT IN (0,1) AND winlostdate = @yesterday THEN winlost-actual_stake+playercomm ELSE 0 END),
			SUM(CASE WHEN statusID IN (0,1) THEN ABS(actual_stake) ELSE 0 END)
	    FROM dbo.bettransLC WITH(NOLOCK)
		WHERE recommend = @custid
			AND (
				statusID IN (0,1)
				OR winlostdate >= @yesterday
			)

		-- translog
		INSERT INTO #BalanceInfo (agentCash, yesterday_agentCash, agentOutstanding, memberCash, yesterday_memberCash, memberOutstanding)
		SELECT 0, 0, SUM(ABS(actual_stake*apositiontaking)), 0, 0, SUM(ABS(actual_stake))
	    FROM dbo.translog t WITH(NOLOCK)
		WHERE recommend = @custid
			AND statusID IN (0,1)

		-- bettrans 
		; WITH Bettrans_CTE AS (
				SELECT  Winlostdate, bettype , 
						SUM(ABS(actual_stake*apositiontaking)) AS agentOutstanding, 
						SUM(CASE WHEN custid <> recommend THEN ABS(actual_stake) ELSE 0 END) AS memberOutstanding
				FROM dbo.bettrans b WITH(NOLOCK)   
				WHERE b.recommend = @custid
					AND b.ruben = 0	
					AND b.winlostdate >= @MinDate
				GROUP BY Winlostdate, bettype
			)			
		INSERT INTO #BalanceInfo (agentCash, yesterday_agentCash, agentOutstanding, memberCash, yesterday_memberCash, memberOutstanding)
		SELECT 0, 0, SUM(agentOutstanding), 0, 0, SUM(memberOutstanding)
		FROM Bettrans_CTE b 
		WHERE NOT EXISTS (SELECT TOP 1 1 FROM #SportBettype s WHERE s.Bettype = b.bettype AND s.RefTable <> 0)
								
								
		INSERT INTO #BalanceInfo (agentCash, yesterday_agentCash, agentOutstanding, memberCash, yesterday_memberCash, memberOutstanding)
		SELECT
			SUM(CASE WHEN custid = recommend THEN winlost-actual_stake ELSE awinlost+comm-playercomm END),
			SUM(CASE WHEN custid = recommend THEN winlost-actual_stake ELSE awinlost+comm-playercomm END),
			0,
			SUM(CASE WHEN custid <> recommend THEN winlost-actual_stake+playercomm ELSE 0 END),
			SUM(CASE WHEN custid <> recommend THEN winlost-actual_stake+playercomm ELSE 0 END),
			0
		FROM dbo.bettrans b WITH(NOLOCK)   
		WHERE b.recommend = @custid
			AND b.ruben = 1
			AND b.winlostdate < @yesterday		
			
			
		; WITH Bettrans_CTE AS (			
			SELECT Winlostdate, bettype,
				SUM(CASE WHEN custid = recommend THEN winlost-actual_stake ELSE awinlost+comm-playercomm END) AS agentCash,
				SUM(CASE WHEN (winlostdate = @yesterday OR b.bettype > 20000) THEN CASE WHEN custid = recommend THEN winlost-actual_stake ELSE awinlost+comm-playercomm END ELSE 0 END) AS yesterday_agentCash,
				SUM(CASE WHEN custid <> recommend THEN winlost-actual_stake+playercomm ELSE 0 END) AS memberCash,
				SUM(CASE WHEN custid <> recommend AND (winlostdate = @yesterday OR b.bettype > 20000) THEN winlost-actual_stake+playercomm ELSE 0 END) AS yesterday_memberCash
			FROM dbo.bettrans b WITH(NOLOCK)
			WHERE b.recommend = @custid
				AND b.ruben = 1
				AND b.winlostdate >= @yesterday	
			GROUP BY Winlostdate, bettype				
			)			
		INSERT INTO #BalanceInfo (agentCash, yesterday_agentCash, agentOutstanding, memberCash, yesterday_memberCash, memberOutstanding)
		SELECT
			SUM(agentCash),
			SUM(yesterday_agentCash),
			0,
			SUM(memberCash),
			SUM(yesterday_memberCash),
			0
		FROM Bettrans_CTE b
		WHERE NOT EXISTS (SELECT TOP 1 1 FROM #SportBettype s WHERE s.Bettype = b.bettype AND s.RefTable IN (1, 2))
			
		
		SELECT
			SUM(agentCash) AS agentCash,
			SUM(yesterday_agentCash) AS yesterday_agentCash,
			SUM(agentOutstanding) AS agentPositionTaking,
			SUM(memberCash) AS customerCash,
			SUM(yesterday_memberCash) AS yesterday_customerCash,
			SUM(memberOutstanding) AS customerOutstanding,
			@UsedCredit AS agentUsedCredit
		FROM #BalanceInfo
    END
    ELSE IF @roleid = 3
    BEGIN
	    SELECT @UsedCredit = SUM(credit)  
	    FROM DBCUST.CustDB.dbo.custinfo WITH(NOLOCK) 
	    WHERE roleid=2 
		    AND mrecommend = @custid
		
		-- bettransRNG
		INSERT INTO #BalanceInfo (masterCash, yesterday_masterCash, masterOutstanding, agentCash, yesterday_agentCash, memberCash, yesterday_memberCash, memberOutstanding)
		SELECT 
			SUM(CASE WHEN statusID NOT IN (0,1) THEN mwinlost+acomm-comm ELSE 0 END),
			SUM(CASE WHEN statusID NOT IN (0,1) AND winlostdate = @yesterday THEN mwinlost+acomm-comm ELSE 0 END),
			SUM(CASE WHEN statusID IN (0,1) THEN ABS(actual_stake * mpositiontaking) ELSE 0 END),
			SUM(CASE WHEN statusID NOT IN (0,1) THEN awinlost+comm-playercomm ELSE 0 END),
			SUM(CASE WHEN statusID NOT IN (0,1) AND winlostdate = @yesterday THEN awinlost+comm-playercomm ELSE 0 END),
			SUM(CASE WHEN statusID NOT IN (0,1) THEN winlost-actual_stake+playercomm ELSE 0 END),
			SUM(CASE WHEN statusID NOT IN (0,1) AND winlostdate = @yesterday THEN winlost-actual_stake+playercomm ELSE 0 END),
			SUM(CASE WHEN statusID IN (0,1) THEN ABS(actual_stake) ELSE 0 END)
	    FROM dbo.bettransRNG WITH(NOLOCK)
		WHERE mrecommend = @custid
			AND (
				statusID IN (0,1)
				OR winlostdate >= @yesterday
			)

		-- bettransLC
		INSERT INTO #BalanceInfo (masterCash, yesterday_masterCash, masterOutstanding, agentCash, yesterday_agentCash, memberCash, yesterday_memberCash, memberOutstanding)
		SELECT 
			SUM(CASE WHEN statusID NOT IN (0,1) THEN mwinlost+acomm-comm ELSE 0 END),
			SUM(CASE WHEN statusID NOT IN (0,1) AND winlostdate = @yesterday THEN mwinlost+acomm-comm ELSE 0 END),
			SUM(CASE WHEN statusID IN (0,1) THEN ABS(actual_stake * mpositiontaking) ELSE 0 END),
			SUM(CASE WHEN statusID NOT IN (0,1) THEN awinlost+comm-playercomm ELSE 0 END),
			SUM(CASE WHEN statusID NOT IN (0,1) AND winlostdate = @yesterday THEN awinlost+comm-playercomm ELSE 0 END),
			SUM(CASE WHEN statusID NOT IN (0,1) THEN winlost-actual_stake+playercomm ELSE 0 END),
			SUM(CASE WHEN statusID NOT IN (0,1) AND winlostdate = @yesterday THEN winlost-actual_stake+playercomm ELSE 0 END),
			SUM(CASE WHEN statusID IN (0,1) THEN ABS(actual_stake) ELSE 0 END)
	    FROM dbo.bettransLC WITH(NOLOCK)
		WHERE mrecommend = @custid
			AND (
				statusID IN (0,1)
				OR winlostdate >= @yesterday
			)

		-- translog
		INSERT INTO #BalanceInfo (masterCash, yesterday_masterCash, masterOutstanding, agentCash, yesterday_agentCash, memberCash, yesterday_memberCash, memberOutstanding)
		SELECT 0, 0, SUM(ABS(actual_stake*mpositiontaking)), 0, 0, 0, 0, SUM(ABS(actual_stake))
	    FROM dbo.translog t WITH(NOLOCK)
		WHERE mrecommend = @custid
			AND statusID IN (0,1)

		-- bettrans /* need check custid = recommend due to sum/balance/transfer tickets */
		; WITH Bettrans_CTE AS (
			SELECT  Winlostdate, bettype,
					SUM(ABS(actual_stake*mpositiontaking)) AS masterOutstanding,
					SUM(ABS(CASE WHEN custid <> recommend THEN actual_stake ELSE 0 END)) AS memberOutstanding
			FROM dbo.bettrans b WITH(NOLOCK)
			WHERE b.mrecommend  = @CustId 
				AND b.recommend <> 0     --- level Agent and Customer
				AND b.ruben = 0
				AND b.winlostdate >= @MinDate
			GROUP BY Winlostdate, bettype
			 
			)		
		INSERT INTO #BalanceInfo (masterCash, yesterday_masterCash, masterOutstanding, agentCash, yesterday_agentCash, memberCash, yesterday_memberCash, memberOutstanding)
		SELECT 0, 0, SUM(masterOutstanding), 0, 0, 0, 0, SUM(memberOutstanding)
		FROM  Bettrans_CTE  b
		WHERE NOT EXISTS (SELECT TOP 1 1 FROM #SportBettype s WHERE s.Bettype = b.bettype AND s.RefTable <> 0)		
						

		INSERT INTO #BalanceInfo (masterCash, yesterday_masterCash, masterOutstanding, agentCash, yesterday_agentCash, memberCash, yesterday_memberCash, memberOutstanding)
		SELECT
			SUM(mwinlost+acomm-comm),
			SUM(mwinlost+acomm-comm),
			0,
			SUM(CASE WHEN custid = recommend THEN winlost-actual_stake ELSE awinlost+comm-playercomm END),
			SUM(CASE WHEN custid = recommend THEN winlost-actual_stake ELSE awinlost+comm-playercomm END),
			SUM(CASE WHEN custid <> recommend THEN winlost-actual_stake+playercomm ELSE 0 END),
			SUM(CASE WHEN custid <> recommend THEN winlost-actual_stake+playercomm ELSE 0 END),
			0
		FROM dbo.bettrans b WITH(NOLOCK)
		WHERE  b.mrecommend  = @CustId 
			AND b.recommend  <> 0     --- level Agent and Customer
			AND b.ruben = 1
			AND b.winlostdate < @yesterday		
			

		; WITH Bettrans_CTE AS (
			SELECT  Winlostdate, bettype,
					SUM(mwinlost+acomm-comm) AS masterCash,
					SUM(CASE WHEN (winlostdate = @yesterday OR bettype > 20000) THEN mwinlost+acomm-comm ELSE 0 END) AS yesterday_masterCash,
					SUM(CASE WHEN custid = recommend THEN winlost-actual_stake ELSE awinlost+comm-playercomm END) AS agentCash,
					SUM(CASE WHEN (winlostdate = @yesterday OR bettype > 20000) THEN CASE WHEN custid = recommend THEN winlost-actual_stake ELSE awinlost+comm-playercomm END ELSE 0 END) AS yesterday_agentCash,
					SUM(CASE WHEN custid <> recommend THEN winlost-actual_stake+playercomm ELSE 0 END) AS memberCash,
					SUM(CASE WHEN (winlostdate = @yesterday OR bettype > 20000) AND custid <> recommend THEN winlost-actual_stake+playercomm ELSE 0 END) AS yesterday_memberCash					
				FROM dbo.bettrans b WITH(NOLOCK)
				WHERE   
					b.mrecommend = @CustId 
					AND b.recommend  <> 0     --- level Agent and Customer
					AND b.ruben = 1
					AND b.winlostdate >= @yesterday		
				GROUP BY Winlostdate, bettype
			)
		INSERT INTO #BalanceInfo (masterCash, yesterday_masterCash, masterOutstanding, agentCash, yesterday_agentCash, memberCash, yesterday_memberCash, memberOutstanding)
		SELECT
			SUM(masterCash),
			SUM(yesterday_masterCash),
			0,
			SUM(agentCash),
			SUM(yesterday_agentCash),
			SUM(memberCash),
			SUM(yesterday_memberCash),
			0
		FROM Bettrans_CTE b
		WHERE NOT EXISTS (SELECT TOP 1 1 FROM #SportBettype s WHERE s.Bettype = b.bettype AND s.RefTable IN (1, 2))
			
			
		-- sum, balance, transfer tickets of this master
		INSERT INTO #BalanceInfo (masterCash, yesterday_masterCash, masterOutstanding, agentCash, yesterday_agentCash, memberCash, yesterday_memberCash, memberOutstanding)
		SELECT
			SUM(winlost-actual_stake),
			SUM(CASE WHEN (winlostdate <= @yesterday OR b.bettype > 20000) THEN winlost-actual_stake ELSE 0 END),
			SUM(CASE WHEN ruben = 0 THEN ABS(actual_stake*mpositiontaking) ELSE 0 END),
			SUM(awinlost+comm-playercomm),
			SUM(CASE WHEN (winlostdate <= @yesterday OR b.bettype > 20000) THEN awinlost+comm-playercomm ELSE 0 END),
			0,
			0,
			0
		FROM dbo.bettrans b WITH(NOLOCK)
		WHERE custid = @custid
			AND b.matchid = 0
			AND b.bettype >= 19999

		SELECT
			SUM(masterCash) AS masterCash,
			SUM(yesterday_masterCash) AS yesterday_masterCash,
			SUM(masterOutstanding) AS masterPositionTaking,
			SUM(agentCash) AS agentCash,
			SUM(yesterday_agentCash) AS yesterday_agentCash,
			SUM(memberCash) AS customerCash,
			SUM(yesterday_memberCash) AS yesterday_customerCash,
			SUM(memberOutstanding) AS customerOutstanding,
			@UsedCredit AS masterUsedCredit
		FROM #BalanceInfo
    END
    ELSE IF @roleid = 4
    BEGIN
	    SELECT @UsedCredit = SUM(credit) 
	    FROM DBCUST.CustDB.dbo.custinfo WITH(NOLOCK)
	    WHERE roleid=3
		     AND srecommend = @custid 	    	

		-- bettransRNG
		INSERT INTO #BalanceInfo (superCash, yesterday_superCash, superOutstanding, masterCash, yesterday_masterCash, agentCash, yesterday_agentCash, memberCash, yesterday_memberCash, memberOutstanding)
		SELECT 
			SUM(CASE WHEN statusID NOT IN (0,1) THEN swinlost+scomm-acomm ELSE 0 END),
			SUM(CASE WHEN statusID NOT IN (0,1) AND winlostdate = @yesterday THEN swinlost+scomm-acomm ELSE 0 END),
			SUM(CASE WHEN statusID IN (0,1) THEN ABS(actual_stake * spositiontaking) ELSE 0 END),
			SUM(CASE WHEN statusID NOT IN (0,1) THEN mwinlost+acomm-comm ELSE 0 END),
			SUM(CASE WHEN statusID NOT IN (0,1) AND winlostdate = @yesterday THEN mwinlost+acomm-comm ELSE 0 END),
			SUM(CASE WHEN statusID NOT IN (0,1) THEN awinlost+comm-playercomm ELSE 0 END),
			SUM(CASE WHEN statusID NOT IN (0,1) AND winlostdate = @yesterday THEN awinlost+comm-playercomm ELSE 0 END),
			SUM(CASE WHEN statusID NOT IN (0,1) THEN winlost-actual_stake+playercomm ELSE 0 END),
			SUM(CASE WHEN statusID NOT IN (0,1) AND winlostdate = @yesterday THEN winlost-actual_stake+playercomm ELSE 0 END),
			SUM(CASE WHEN statusID IN (0,1) THEN ABS(actual_stake) ELSE 0 END)
	    FROM dbo.bettransRNG WITH(NOLOCK)
		WHERE srecommend = @custid
			AND (
				statusID IN (0,1)
				OR winlostdate >= @yesterday
			)

		-- bettransLC
		INSERT INTO #BalanceInfo (superCash, yesterday_superCash, superOutstanding, masterCash, yesterday_masterCash, agentCash, yesterday_agentCash, memberCash, yesterday_memberCash, memberOutstanding)
		SELECT 
			SUM(CASE WHEN statusID NOT IN (0,1) THEN swinlost+scomm-acomm ELSE 0 END),
			SUM(CASE WHEN statusID NOT IN (0,1) AND winlostdate = @yesterday THEN swinlost+scomm-acomm ELSE 0 END),
			SUM(CASE WHEN statusID IN (0,1) THEN ABS(actual_stake * spositiontaking) ELSE 0 END),
			SUM(CASE WHEN statusID NOT IN (0,1) THEN mwinlost+acomm-comm ELSE 0 END),
			SUM(CASE WHEN statusID NOT IN (0,1) AND winlostdate = @yesterday THEN mwinlost+acomm-comm ELSE 0 END),
			SUM(CASE WHEN statusID NOT IN (0,1) THEN awinlost+comm-playercomm ELSE 0 END),
			SUM(CASE WHEN statusID NOT IN (0,1) AND winlostdate = @yesterday THEN awinlost+comm-playercomm ELSE 0 END),
			SUM(CASE WHEN statusID NOT IN (0,1) THEN winlost-actual_stake+playercomm ELSE 0 END),
			SUM(CASE WHEN statusID NOT IN (0,1) AND winlostdate = @yesterday THEN winlost-actual_stake+playercomm ELSE 0 END),
			SUM(CASE WHEN statusID IN (0,1) THEN ABS(actual_stake) ELSE 0 END)
	    FROM dbo.bettransLC WITH(NOLOCK)
		WHERE srecommend = @custid
			AND (
				statusID IN (0,1)
				OR winlostdate >= @yesterday
			)

		-- translog
		INSERT INTO #BalanceInfo (superCash, yesterday_superCash, superOutstanding, masterCash, yesterday_masterCash, agentCash, yesterday_agentCash, memberCash, yesterday_memberCash, memberOutstanding)
		SELECT 0, 0, SUM(ABS(actual_stake*spositiontaking)), 0, 0, 0, 0, 0, 0, SUM(ABS(actual_stake))
	    FROM dbo.translog t WITH(NOLOCK)
		WHERE EXISTS (SELECT TOP 1 1 FROM dbo.custInfo c WITH(NOLOCK) WHERE c.srecommend = @custid AND c.roleid = 3 AND t.mrecommend = c.custid)
			AND statusID IN (0,1)

		-- bettrans 
		; WITH Bettrans_CTE AS (		
			SELECT WinlostDate, bettype,
				   SUM(ABS(actual_stake*spositiontaking)) AS superOutstanding, 
				   SUM(ABS(CASE WHEN custid <> recommend THEN actual_stake ELSE 0 END)) AS memberOutstanding
			FROM dbo.bettrans b WITH(NOLOCK)
			WHERE  
				b.srecommend = @CustId
				AND b.recommend  <> 0     --- level Agent and Customer
				AND b.custId <> b.recommend   --- get level member only
				AND b.ruben = 0
				AND b.winlostdate >= @MinDate			
			GROUP By WinlostDate, bettype
			)
		INSERT INTO #BalanceInfo (superCash, yesterday_superCash, superOutstanding, masterCash, yesterday_masterCash, agentCash, yesterday_agentCash, memberCash, yesterday_memberCash, memberOutstanding)
		SELECT 0, 0, SUM(superOutstanding), 0, 0, 0, 0, 0, 0, SUM(memberOutstanding) 
		FROM Bettrans_CTE b
		WHERE  NOT EXISTS (SELECT TOP 1 1 FROM #SportBettype s WHERE s.Bettype = b.bettype AND s.RefTable <> 0)
		

		INSERT INTO #BalanceInfo (superCash, yesterday_superCash, superOutstanding, masterCash, yesterday_masterCash, agentCash, yesterday_agentCash, memberCash, yesterday_memberCash, memberOutstanding)
		SELECT
			SUM(swinlost+scomm-acomm),
			SUM(swinlost+scomm-acomm),
			0,
			SUM(mwinlost+acomm-comm),
			SUM(mwinlost+acomm-comm),
			SUM(CASE WHEN custid = recommend THEN winlost-actual_stake ELSE awinlost+comm-playercomm END),
			SUM(CASE WHEN custid = recommend THEN winlost-actual_stake ELSE awinlost+comm-playercomm END),
			SUM(CASE WHEN custid <> recommend THEN winlost-actual_stake+playercomm ELSE 0 END),
			SUM(CASE WHEN custid <> recommend THEN winlost-actual_stake+playercomm ELSE 0 END),
			0
		FROM dbo.bettrans b WITH(NOLOCK)
		WHERE 
			b.srecommend = @CustId
			AND b.recommend <> 0     --- level Agent and Customer
			AND b.ruben = 1
			AND b.winlostdate < @yesterday

		;WITH Bettrans_CTE AS (
			SELECT winlostdate, Bettype,
					SUM(swinlost+scomm-acomm) superCash,
					SUM(CASE WHEN (winlostdate = @yesterday OR bettype > 20000) THEN swinlost+scomm-acomm ELSE 0 END) AS yesterday_superCash,	
					SUM(mwinlost+acomm-comm) AS masterCash,
					SUM(CASE WHEN (winlostdate = @yesterday OR bettype > 20000) THEN mwinlost+acomm-comm ELSE 0 END) as yesterday_masterCash,
					SUM(CASE WHEN custid = recommend THEN winlost-actual_stake ELSE awinlost+comm-playercomm END) as agentCash,
					SUM(CASE WHEN (winlostdate = @yesterday OR bettype > 20000) THEN CASE WHEN custid = recommend THEN winlost-actual_stake ELSE awinlost+comm-playercomm END ELSE 0 END) as yesterday_agentCash,
					SUM(CASE WHEN custid <> recommend THEN winlost-actual_stake+playercomm ELSE 0 END) as memberCash,
					SUM(CASE WHEN (winlostdate = @yesterday OR bettype > 20000) AND custid <> recommend THEN winlost-actual_stake+playercomm ELSE 0 END) as yesterday_memberCash
			FROM dbo.bettrans b WITH(NOLOCK)
			WHERE 
				b.srecommend = @CustId
				AND b.recommend <> 0     --- level Agent and Customer
				AND b.ruben = 1
				AND b.winlostdate >= @yesterday
			GROUP BY winlostdate, Bettype 
		 )
		INSERT INTO #BalanceInfo (superCash, yesterday_superCash, superOutstanding, masterCash, yesterday_masterCash, agentCash, yesterday_agentCash, memberCash, yesterday_memberCash, memberOutstanding)
		SELECT
			SUM(superCash),
			SUM(yesterday_superCash),
			0,
			SUM(masterCash),
			SUM(yesterday_masterCash),
			SUM(agentCash),
			SUM(yesterday_agentCash),
			SUM(memberCash),
			SUM(yesterday_memberCash),
			0
		FROM Bettrans_CTE b
		WHERE NOT EXISTS (SELECT TOP 1 1 FROM #SportBettype s WHERE s.Bettype = b.bettype AND s.RefTable IN (1, 2))


			-- sum, balance, transfer tickets of this super and all masters
		INSERT INTO #BalanceInfo (superCash, yesterday_superCash, superOutstanding, masterCash, yesterday_masterCash, agentCash, yesterday_agentCash, memberCash, yesterday_memberCash, memberOutstanding)
		SELECT
			SUM(CASE WHEN custid = srecommend THEN winlost-actual_stake ELSE swinlost+scomm-acomm END),
			SUM(CASE WHEN (winlostdate <= @yesterday OR b.bettype > 20000) THEN CASE WHEN custid = srecommend THEN winlost-actual_stake ELSE swinlost+scomm-acomm END ELSE 0 END),
			SUM(CASE WHEN ruben = 0 THEN ABS(actual_stake*spositiontaking) ELSE 0 END),
			SUM(CASE WHEN custid = mrecommend THEN winlost-actual_stake ELSE mwinlost+acomm-comm END),
			SUM(CASE WHEN (winlostdate <= @yesterday OR b.bettype > 20000) THEN CASE WHEN custid = mrecommend THEN winlost-actual_stake ELSE mwinlost+acomm-comm END ELSE 0 END),
			SUM(awinlost+comm-playercomm),
			SUM(CASE WHEN (winlostdate <= @yesterday OR b.bettype > 20000) THEN awinlost+comm-playercomm ELSE 0 END),
			0,
			0,
			0
		FROM dbo.bettrans b WITH(NOLOCK)
		WHERE 
			b.srecommend = @CustID
			AND (b.recommend * @ID) = 0   --- level master and super 
			AND b.matchid = 0
			AND b.bettype >= 19999

		SELECT
			SUM(superCash) AS superCash,
			SUM(yesterday_superCash) AS yesterday_superCash,
			SUM(superOutstanding) AS superPositionTaking,
			SUM(masterCash) AS masterCash,
			SUM(yesterday_masterCash) AS yesterday_masterCash,
			SUM(agentCash) AS agentCash,
			SUM(yesterday_agentCash) AS yesterday_agentCash,
			SUM(memberCash) AS customerCash,
			SUM(yesterday_memberCash) AS yesterday_customerCash,
			SUM(memberOutstanding) AS customerOutstanding,
			@UsedCredit AS superUsedCredit
		FROM #BalanceInfo
    END
	
	DROP TABLE #SportBettype
	DROP TABLE #BalanceInfo

END
GO
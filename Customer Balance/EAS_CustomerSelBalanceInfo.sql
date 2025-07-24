/*<info serverAlias="DBAGE-bodb02" executers="wsv_xnap" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[EAS_CustomerSelBalanceInfo]
	@CustId	INT
AS

/*
	Created: 20181112@Percy
	DB: DBAGE.bodb02
	Task: Ext NAP - Left menu - Search customer - Balance Info

	Revisions:
		- 20181112@Percy: Initialize SP [RedmineID: #95978]
		- 20191227@Johnson: get last transdate [redmine:#125894]
		- 20200602@Percy: Separate PendingTransfer3rd to Cash and Balance [RedmineID: #135200]
		- 20210505@Sol: NAP - Alpha - Allow more time for transfer - [Redmine: #149927]
		- 20211122@Danny: Split transfer tickets out of bettrans [Redmine: #164196]
		- 20221128@Evan: Enhance performance get max transid [RedmineID: #180141]
		- 20230227@Evan: Balance-Up support transfer 247 [Redmine: #173554]
        - 20240918@Lewis: Rebate Retention - RewardReceivable RewardPayable [RedmineId: #208503]
		- 20241224@Max: Offer Direct Member for Super/Master [Redmine: #211969]
		- 20250626@Dave: Add AccumCredit of AllCashMember to AgentUsedCredit [Redmine: #232372]
		- 20250707@Bobby: Transfer changes for Cash Service [Redmine: #232421]

*/

BEGIN
	SET NOCOUNT ON

	DECLARE @RoleId TINYINT, @CurrencyId INT, @Currency NVARCHAR(50), @Credit MONEY, @UsedCredit MONEY
			,@transdate DATETIME, @transid BIGINT, @transferid BIGINT
			
	SELECT  @RoleId = roleid, @CurrencyId = currency FROM dbo.custInfo WITH (NOLOCK) WHERE custid = @CustId

	IF @RoleId NOT BETWEEN 1 AND 4
		RETURN

	-- get move bet date
	DECLARE @balanceUpDay SMALLDATETIME, @moveBetsDay SMALLDATETIME
	DECLARE @tblMoveBetBalanceUp AS TABLE (BalanceUpDay SMALLDATETIME, MoveBetsDay SMALLDATETIME)

	INSERT INTO @tblMoveBetBalanceUp(BalanceUpDay,MoveBetsDay)
	EXEC bodb02.dbo.Age_SelBalanceUpDay

	SELECT @balanceUpDay = BalanceUpDay, @moveBetsDay = MoveBetsDay FROM @tblMoveBetBalanceUp

	SELECT  @Currency = currency FROM dbo.Exchange WITH (NOLOCK) WHERE exchangeId = @CurrencyId

	-- Credit: get data real time on DBCUST
	SELECT  @Credit = ISNULL(credit, 0) 
	FROM DBCUST.CustDB.dbo.custInfo WITH (NOLOCK) 
	WHERE custid = @CustId

	-- Balance Info
	DECLARE @today SMALLDATETIME, @yesterday SMALLDATETIME
	SELECT  @today		= CONVERT(DATE, GETDATE())
	SELECT  @yesterday	= DATEADD(DAY, -1, @today)
	
	CREATE TABLE #SportBettypeMatrix (bettype INT, refTable TINYINT)
	INSERT INTO #SportBettypeMatrix (bettype, refTable)
	SELECT DISTINCT bettype, refTable FROM dbo.SportBettypeMatrix WITH (NOLOCK) WHERE refTable <> 0

	DECLARE @TotalCash MONEY, @YesterdayCash MONEY, @Outstanding MONEY, @TotalBalance MONEY, @YesterdayBalance MONEY, @DownlineOutstanding MONEY, @PendingTransfer3rd MONEY

	CREATE TABLE #BalanceInfo
	(
		winlostdate SMALLDATETIME, bettype INT, statusId TINYINT, roleId TINYINT,
		swinlost MONEY, scomm MONEY,
		mwinlost MONEY, acomm MONEY,
		awinlost MONEY, comm MONEY,
		winlost MONEY, actual_stake MONEY, playercomm MONEY,
		actual_stakePT MONEY
	)

	-- Super
	IF @RoleId = 4
	BEGIN
		--last txn 
		SELECT @transid = MAX(transid) FROM bettrans WITH (NOLOCK) 
		WHERE srecommend = @custid
		OPTION (OPTIMIZE FOR(@custid = -1))

		SELECT @transferid = MAX(transid) FROM dbo.transfer WITH (NOLOCK) 
		WHERE srecommend = @custid
			AND bettype NOT IN (20000,19999)
		OPTION (OPTIMIZE FOR(@custid = -1))

		SELECT @transdate = MAX(transdate)
		FROM
		(
			SELECT transdate FROM bettrans WITH (NOLOCK) WHERE transid = @transid
			UNION ALL
			SELECT transdate FROM dbo.transfer WITH (NOLOCK) WHERE transid = @transferid
		) x
		
		-- Credit
		SELECT @UsedCredit = SUM(ISNULL(credit, 0)) 
		FROM DBCUST.CustDB.dbo.custInfo WITH (NOLOCK) 
		WHERE srecommend = @CustId 
			AND 1 = CASE WHEN roleId = 3 THEN 1
						WHEN roleid = 1 AND recommend = -4 THEN 1 ELSE 0 END

		-- bettrans
		INSERT INTO #BalanceInfo (winlostdate, bettype, statusId, roleId, winlost, actual_stake, swinlost, mwinlost, awinlost, scomm, acomm, actual_stakePT)
		SELECT 
			winlostdate, bettype, statusID, CASE WHEN custId = @CustId THEN 4 ELSE 0 END,
			SUM(winlost), SUM(actual_stake), SUM(swinlost), SUM(mwinlost), SUM(awinlost), SUM(scomm), SUM(acomm), SUM(ABS(actual_stake) * spositiontaking)
		FROM dbo.bettrans WITH (NOLOCK)
		WHERE srecommend = @CustId
			AND  winlostdate > @moveBetsDay
		GROUP BY winlostdate, bettype, statusID, CASE WHEN custId = @CustId THEN 4 ELSE 0 END

		-- transfer
		INSERT INTO #BalanceInfo (winlostdate, bettype, statusId, roleId, winlost, actual_stake, swinlost, mwinlost, awinlost, scomm, acomm, actual_stakePT)
		SELECT 
			winlostdate, bettype, statusID, CASE WHEN custId = @CustId THEN 4 ELSE 0 END,
			SUM(winlost), SUM(actual_stake), SUM(swinlost), SUM(mwinlost), SUM(awinlost), SUM(scomm), SUM(acomm), SUM(ABS(actual_stake) * ISNULL(ti.spositiontaking,0))
		FROM dbo.transfer t WITH(NOLOCK)
		LEFT JOIN dbo.transferInfo ti WITH(NOLOCK) ON t.TransId = ti.TransId
		WHERE srecommend = @CustId
			AND 1 = CASE WHEN bettype = 19999 AND winlostdate > @moveBetsDay THEN 0 --> new sum 
						WHEN bettype = 20000 AND winlostdate > @balanceUpDay THEN 0 --> new bal
						WHEN winlostdate < @balanceUpDay THEN 0 --> old data
					ELSE 1 END
		GROUP BY winlostdate, bettype, statusID, CASE WHEN custId = @CustId THEN 4 ELSE 0 END

		DELETE b
		FROM #BalanceInfo b
		WHERE EXISTS (SELECT 1 FROM #SportBettypeMatrix s WHERE b.bettype = s.bettype AND s.RefTable IN (1,2))
			AND b.winlostdate >= @yesterday

		DELETE b
		FROM #BalanceInfo b
		WHERE EXISTS (SELECT 1 FROM #SportBettypeMatrix s WHERE b.bettype = s.bettype)
			AND b.statusId IN (0,1)

		UPDATE #BalanceInfo
		SET winlostdate = @yesterday
		WHERE bettype > 20000 AND winlostdate = @today AND bettype < 31000

		UPDATE #BalanceInfo
		SET bettype = -10
		WHERE bettype IN (21008, 21009) -- BBIN Transfer

		-- translog
		INSERT INTO #BalanceInfo (winlostdate, bettype, statusId, roleId, winlost, actual_stake, swinlost, mwinlost, awinlost, scomm, acomm, actual_stakePT)
		SELECT @today, -1, 0, 1, 0, SUM(actual_stake), 0, 0, 0, 0, 0, SUM(ABS(actual_stake) * spositiontaking)
		FROM dbo.translog WITH (NOLOCK)
		WHERE srecommend = @custid
			AND statusId IN (0,1)

		-- bettransRnG
		INSERT INTO #BalanceInfo (winlostdate, bettype, statusId, roleId, winlost, actual_stake, swinlost, mwinlost, awinlost, scomm, acomm, actual_stakePT)
		SELECT 
			winlostdate, -2, statusID, 1,
			SUM(winlost), SUM(actual_stake), SUM(swinlost), SUM(mwinlost), SUM(awinlost), SUM(scomm), SUM(acomm), SUM(ABS(actual_stake) * spositiontaking)
		FROM dbo.bettransRnG WITH (NOLOCK)
		WHERE srecommend = @CustId
			AND (statusId IN (0,1) OR winlostdate >= @yesterday)
		GROUP BY
			winlostdate, statusID

		-- bettransLC
		INSERT INTO #BalanceInfo (winlostdate, bettype, statusId, roleId, winlost, actual_stake, swinlost, mwinlost, awinlost, scomm, acomm, actual_stakePT)
		SELECT 
			winlostdate, -3, statusID, 1,
			SUM(winlost), SUM(actual_stake), SUM(swinlost), SUM(mwinlost), SUM(awinlost), SUM(scomm), SUM(acomm), SUM(ABS(actual_stake) * spositiontaking)
		FROM dbo.bettransLC WITH (NOLOCK)
		WHERE srecommend = @CustId
			AND (statusId IN (0,1) OR winlostdate >= @yesterday)
		GROUP BY
			winlostdate, statusID

		SELECT
			@TotalCash				= SUM(CASE WHEN bettype = -10 OR statusId IN (0,1) THEN 0 ELSE CASE WHEN roleId = 4 THEN winlost - actual_stake ELSE swinlost + scomm - acomm END END),
			@YesterdayCash			= SUM(CASE WHEN bettype = -10 OR statusId IN (0,1) OR winlostdate > @yesterday THEN 0 ELSE CASE WHEN roleId = 4 THEN winlost - actual_stake ELSE swinlost + scomm - acomm END END * ck.CalYesterday),
			@Outstanding			= SUM(CASE WHEN statusId IN (0,1) THEN actual_stakePT ELSE 0 END),
			
			@TotalBalance			= SUM(CASE WHEN bettype = -10 OR statusId IN (0,1) THEN 0 ELSE winlost - actual_stake + swinlost + mwinlost + awinlost + scomm END),
			@YesterdayBalance		= SUM(CASE WHEN bettype = -10 OR statusId IN (0,1) OR winlostdate > @yesterday THEN 0 ELSE winlost - actual_stake + swinlost + mwinlost + awinlost + scomm END * ck.CalYesterday),
			@DownlineOutstanding	= SUM(CASE WHEN statusId IN (0,1) THEN actual_stake ELSE 0 END),

			@PendingTransfer3rd		= SUM(CASE WHEN bettype = -10 THEN -(winlost-actual_stake) ELSE 0 END)
		FROM #BalanceInfo
			OUTER APPLY (
				SELECT CASE 
						WHEN winlostdate > @yesterday AND bettype >= 31000 THEN 0 --> Cash service today transfers
						ELSE 1 END
			) AS ck(CalYesterday)
	END
	ELSE IF @RoleId = 3
	BEGIN
		--last txn 
		SELECT @transid = MAX(transid) FROM bettrans WITH (NOLOCK) 
		WHERE mrecommend = @custid
		OPTION (OPTIMIZE FOR(@custid = -1))

		SELECT 	@transferid = MAX(transid) FROM dbo.Transfer WITH (NOLOCK) 
		WHERE 	mrecommend = @custid
				AND bettype NOT IN (20000,19999)
		OPTION (OPTIMIZE FOR(@custid = -1))

		SELECT @transdate = MAX(transdate)
		FROM 
		(
			SELECT transdate FROM bettrans WITH (NOLOCK) WHERE transid = @transid
			UNION ALL
			SELECT transdate FROM dbo.Transfer WITH (NOLOCK) WHERE transid = @transferid
		) x
		
		-- Credit
		SELECT @UsedCredit = SUM(ISNULL(credit, 0)) 
		FROM DBCUST.CustDB.dbo.custInfo WITH (NOLOCK) 
		WHERE mrecommend = @CustId 
			AND 1 = CASE WHEN roleId = 2 THEN 1
						WHEN roleid = 1 AND recommend = -3 THEN 1 ELSE 0 END

		-- bettrans
		INSERT INTO #BalanceInfo (winlostdate, bettype, statusId, roleId, winlost, actual_stake, mwinlost, awinlost, acomm, comm, actual_stakePT)
		SELECT 
			winlostdate, bettype, statusID, CASE WHEN custId = @CustId THEN 3 ELSE 0 END,
			SUM(winlost), SUM(actual_stake), SUM(mwinlost), SUM(awinlost), SUM(acomm), SUM(comm), SUM(ABS(actual_stake) * mpositiontaking)
		FROM dbo.bettrans WITH (NOLOCK)
		WHERE mrecommend = @CustId
			AND winlostdate > @moveBetsDay
		GROUP BY
			winlostdate, bettype, statusID, CASE WHEN custId = @CustId THEN 3 ELSE 0 END

		-- transfer
		INSERT INTO #BalanceInfo (winlostdate, bettype, statusId, roleId, winlost, actual_stake, mwinlost, awinlost, acomm, comm, actual_stakePT)
		SELECT 
			winlostdate, bettype, statusID, CASE WHEN custId = @CustId THEN 3 ELSE 0 END,
			SUM(winlost), SUM(actual_stake), SUM(mwinlost), SUM(awinlost), SUM(acomm), SUM(comm), SUM(ABS(actual_stake) * ISNULL(mpositiontaking,0))
		FROM dbo.transfer t WITH (NOLOCK)
		LEFT JOIN dbo.transferInfo ti WITH(NOLOCK) ON t.TransId = ti.TransId
		WHERE mrecommend = @CustId
			AND 1 = CASE WHEN bettype = 19999 AND winlostdate > @moveBetsDay THEN 0 --> new sum 
						WHEN bettype = 20000 AND winlostdate > @balanceUpDay THEN 0 --> new bal
						WHEN winlostdate < @balanceUpDay THEN 0 --> old data
					ELSE 1 END
		GROUP BY winlostdate, bettype, statusID, CASE WHEN custId = @CustId THEN 3 ELSE 0 END

		DELETE b
		FROM #BalanceInfo b
		WHERE EXISTS (SELECT 1 FROM #SportBettypeMatrix s WHERE b.bettype = s.bettype AND s.RefTable IN (1,2))
			AND b.winlostdate >= @yesterday

		DELETE b
		FROM #BalanceInfo b
		WHERE EXISTS (SELECT 1 FROM #SportBettypeMatrix s WHERE b.bettype = s.bettype)
			AND b.statusId IN (0,1)

		UPDATE #BalanceInfo
		SET winlostdate = @yesterday
		WHERE bettype > 20000 AND winlostdate = @today AND bettype < 31000

		UPDATE #BalanceInfo
		SET bettype = -10
		WHERE bettype IN (21008, 21009) -- BBIN Transfer

		-- translog
		INSERT INTO #BalanceInfo (winlostdate, bettype, statusId, roleId, winlost, actual_stake, mwinlost, awinlost, acomm, comm, actual_stakePT)
		SELECT @today, -1, 0, 1, 0, SUM(actual_stake), 0, 0, 0, 0, SUM(ABS(actual_stake) * mpositiontaking)
		FROM dbo.translog WITH (NOLOCK)
		WHERE mrecommend = @custid
			AND statusId IN (0,1)

		-- bettransRnG
		INSERT INTO #BalanceInfo (winlostdate, bettype, statusId, roleId, winlost, actual_stake, mwinlost, awinlost, acomm, comm, actual_stakePT)
		SELECT 
			winlostdate, -2, statusID, 1,
			SUM(winlost), SUM(actual_stake), SUM(mwinlost), SUM(awinlost), SUM(acomm), SUM(comm), SUM(ABS(actual_stake) * mpositiontaking)
		FROM dbo.bettransRnG WITH (NOLOCK)
		WHERE mrecommend = @CustId
			AND (statusId IN (0,1) OR winlostdate >= @yesterday)
		GROUP BY
			winlostdate, statusID

		-- bettransLC
		INSERT INTO #BalanceInfo (winlostdate, bettype, statusId, roleId, winlost, actual_stake, mwinlost, awinlost, acomm, comm, actual_stakePT)
		SELECT 
			winlostdate, -3, statusID, 1,
			SUM(winlost), SUM(actual_stake), SUM(mwinlost), SUM(awinlost), SUM(acomm), SUM(comm), SUM(ABS(actual_stake) * mpositiontaking)
		FROM dbo.bettransLC WITH (NOLOCK)
		WHERE mrecommend = @CustId
			AND (statusId IN (0,1) OR winlostdate >= @yesterday)
		GROUP BY
			winlostdate, statusID

		SELECT
			@TotalCash				= SUM(CASE WHEN bettype = -10 OR statusId IN (0,1) THEN 0 ELSE CASE WHEN roleId = 3 THEN winlost - actual_stake ELSE mwinlost + acomm - comm END END),
			@YesterdayCash			= SUM(CASE WHEN bettype = -10 OR statusId IN (0,1) OR winlostdate > @yesterday THEN 0 ELSE CASE WHEN roleId = 3 THEN winlost - actual_stake ELSE mwinlost + acomm - comm END END * ck.CalYesterday),
			@Outstanding			= SUM(CASE WHEN statusId IN (0,1) THEN actual_stakePT ELSE 0 END),
			
			@TotalBalance			= SUM(CASE WHEN bettype = -10 OR statusId IN (0,1) THEN 0 ELSE winlost - actual_stake + mwinlost + awinlost + acomm END),
			@YesterdayBalance		= SUM(CASE WHEN bettype = -10 OR statusId IN (0,1) OR winlostdate > @yesterday THEN 0 ELSE winlost - actual_stake + mwinlost + awinlost + acomm END * ck.CalYesterday),
			@DownlineOutstanding	= SUM(CASE WHEN statusId IN (0,1) THEN actual_stake ELSE 0 END),

			@PendingTransfer3rd		= SUM(CASE WHEN bettype = -10 THEN -(winlost-actual_stake) ELSE 0 END)
		FROM #BalanceInfo
			OUTER APPLY (
				SELECT CASE 
						WHEN winlostdate > @yesterday AND bettype >= 31000 THEN 0 --> Cash service today transfers
						ELSE 1 END
			) AS ck(CalYesterday)	
	END
	ELSE IF @RoleId = 2
	BEGIN
			
		--last txn 
		SELECT @transid = MAX(transid) FROM bettrans WITH (NOLOCK) 
		WHERE recommend = @custid
		OPTION (OPTIMIZE FOR(@custid = -1))

		SELECT @transferid = MAX(transid) FROM dbo.Transfer WITH (NOLOCK) 
		WHERE recommend = @custid AND bettype NOT IN (20000,19999)
		OPTION (OPTIMIZE FOR(@custid = -1))
		
		SELECT @transdate = MAX(transdate)
		FROM
		(
			SELECT transdate FROM bettrans WITH (NOLOCK) WHERE transid = @transid
			UNION ALL
			SELECT transdate FROM  dbo.Transfer WITH (NOLOCK)  WHERE transid = @transferid
		) x
		
		-- Credit
		SELECT @UsedCredit = SUM(ISNULL(credit, 0)) 
		FROM DBCUST.CustDB.dbo.custInfo WITH (NOLOCK) 
		WHERE recommend = @CustId AND roleId = 1;
		SELECT @UsedCredit = ISNULL(SUM(AccumCreditReturn),0) + @UsedCredit
		FROM dbo.CashAccumCredit WITH (NOLOCK) 
		WHERE Recommend = @CustId 
			AND AccumCreditReturn > 0;
		-- bettrans
		INSERT INTO #BalanceInfo (winlostdate, bettype, statusId, roleId, winlost, actual_stake, awinlost, comm, playercomm, actual_stakePT)
		SELECT 
			winlostdate, bettype, statusID, CASE WHEN custId = @CustId THEN 2 ELSE 0 END,
			SUM(winlost), SUM(actual_stake), SUM(awinlost), SUM(comm), SUM(playercomm), SUM(ABS(actual_stake) * apositiontaking)
		FROM dbo.bettrans WITH (NOLOCK)
		WHERE recommend = @CustId
			AND winlostdate > @moveBetsDay
		GROUP BY winlostdate, bettype, statusID, CASE WHEN custId = @CustId THEN 2 ELSE 0 END

		-- Transfer
		INSERT INTO #BalanceInfo (winlostdate, bettype, statusId, roleId, winlost, actual_stake, awinlost, comm, playercomm, actual_stakePT)
		SELECT 
			winlostdate, bettype, statusID, CASE WHEN custId = @CustId THEN 2 ELSE 0 END,
			SUM(winlost), SUM(actual_stake), SUM(awinlost), SUM(comm), SUM(playercomm), SUM(ABS(actual_stake) * ISNULL(apositiontaking,0))
		FROM dbo.Transfer t WITH (NOLOCK)
		LEFT JOIN dbo.transferInfo ti WITH(NOLOCK) ON t.TransId = ti.TransId
		WHERE recommend = @CustId
			AND 1 = CASE WHEN bettype = 19999 AND winlostdate > @moveBetsDay THEN 0 --> new sum 
						WHEN bettype = 20000 AND winlostdate > @balanceUpDay THEN 0 --> new bal
						WHEN winlostdate < @balanceUpDay THEN 0 --> old data
					ELSE 1 END
		GROUP BY winlostdate, bettype, statusID, CASE WHEN custId = @CustId THEN 2 ELSE 0 END

		DELETE b
		FROM #BalanceInfo b
		WHERE EXISTS (SELECT 1 FROM #SportBettypeMatrix s WHERE b.bettype = s.bettype AND s.RefTable IN (1,2))
			AND b.winlostdate >= @yesterday

		DELETE b
		FROM #BalanceInfo b
		WHERE EXISTS (SELECT 1 FROM #SportBettypeMatrix s WHERE b.bettype = s.bettype)
			AND b.statusId IN (0,1)

		UPDATE #BalanceInfo
		SET winlostdate = @yesterday
		WHERE bettype > 20000 AND winlostdate = @today AND bettype < 31000

		UPDATE #BalanceInfo
		SET bettype = -10
		WHERE bettype IN (21008, 21009) -- BBIN Transfer

		-- translog
		INSERT INTO #BalanceInfo (winlostdate, bettype, statusId, roleId, winlost, actual_stake, awinlost, comm, playercomm, actual_stakePT)
		SELECT @today, -1, 0, 1, 0, SUM(actual_stake), 0, 0, 0, SUM(ABS(actual_stake) * apositiontaking)
		FROM dbo.translog WITH (NOLOCK)
		WHERE recommend = @custid
			AND statusId IN (0,1)

		-- bettransRnG
		INSERT INTO #BalanceInfo (winlostdate, bettype, statusId, roleId, winlost, actual_stake, awinlost, comm, playercomm, actual_stakePT)
		SELECT 
			winlostdate, -2, statusID, 1,
			SUM(winlost), SUM(actual_stake), SUM(awinlost), SUM(comm), SUM(playercomm), SUM(ABS(actual_stake) * apositiontaking)
		FROM dbo.bettransRnG WITH (NOLOCK)
		WHERE recommend = @CustId
			AND (statusId IN (0,1) OR winlostdate >= @yesterday)
		GROUP BY
			winlostdate, statusID

		-- bettransLC
		INSERT INTO #BalanceInfo (winlostdate, bettype, statusId, roleId, winlost, actual_stake, awinlost, comm, playercomm, actual_stakePT)
		SELECT 
			winlostdate, -3, statusID, 1,
			SUM(winlost), SUM(actual_stake), SUM(awinlost), SUM(comm), SUM(playercomm), SUM(ABS(actual_stake) * apositiontaking)
		FROM dbo.bettransLC WITH (NOLOCK)
		WHERE recommend = @CustId
			AND (statusId IN (0,1) OR winlostdate >= @yesterday)
		GROUP BY
			winlostdate, statusID

		SELECT
			@TotalCash				= SUM(CASE WHEN bettype = -10 OR statusId IN (0,1) THEN 0 ELSE CASE WHEN roleId = 2 THEN winlost - actual_stake ELSE awinlost + comm - playercomm END END),
			@YesterdayCash			= SUM(CASE WHEN bettype = -10 OR statusId IN (0,1) OR winlostdate > @yesterday THEN 0 ELSE CASE WHEN roleId = 2 THEN winlost - actual_stake ELSE awinlost + comm - playercomm END END * ck.CalYesterday),
			@Outstanding			= SUM(CASE WHEN statusId IN (0,1) THEN actual_stakePT ELSE 0 END),
			
			@TotalBalance			= SUM(CASE WHEN bettype = -10 OR statusId IN (0,1) THEN 0 ELSE winlost - actual_stake + awinlost + comm END),
			@YesterdayBalance		= SUM(CASE WHEN bettype = -10 OR statusId IN (0,1) OR winlostdate > @yesterday THEN 0 ELSE winlost - actual_stake + awinlost + comm END * ck.CalYesterday),
			@DownlineOutstanding	= SUM(CASE WHEN statusId IN (0,1) THEN actual_stake ELSE 0 END),

			@PendingTransfer3rd		= SUM(CASE WHEN bettype = -10 THEN -(winlost-actual_stake) ELSE 0 END)
		FROM #BalanceInfo
			OUTER APPLY (
				SELECT CASE 
						WHEN winlostdate > @yesterday AND bettype >= 31000 THEN 0 --> Cash service today transfers
						ELSE 1 END
			) AS ck(CalYesterday)	
	END
	ELSE IF @RoleId = 1
	BEGIN
		--last txn 		
		SELECT @transid = MAX(transid) FROM bettrans WITH (NOLOCK) 
		WHERE custid = @custid
		OPTION(OPTIMIZE FOR	(@custid = -1))

		SELECT @transferid = MAX(transid) FROM dbo.Transfer WITH (NOLOCK) 
		WHERE custid = @custid
		AND bettype NOT IN (20000,19999)
		OPTION (OPTIMIZE FOR(@custid = -1))

		SELECT @transdate = MAX(transdate)
		FROM 
		(
			SELECT transdate FROM bettrans WITH (NOLOCK) WHERE transid = @transid
			UNION ALL
			SELECT transdate FROM dbo.Transfer WITH (NOLOCK) WHERE transid = @transferid
		) x

		-- Credit
		SELECT @UsedCredit = ISNULL(@Credit, 0)
		
		-- bettrans
		INSERT INTO #BalanceInfo (winlostdate, bettype, statusId, winlost, actual_stake, playercomm)
		SELECT 
			winlostdate, bettype, statusID,
			SUM(winlost), SUM(actual_stake), SUM(playercomm)
		FROM dbo.bettrans WITH (NOLOCK)
		WHERE custid = @CustId AND statusID NOT IN (0,1)
			AND winlostdate > @moveBetsDay
		GROUP BY winlostdate, bettype, statusID

		-- transfer
		INSERT INTO #BalanceInfo (winlostdate, bettype, statusId, winlost, actual_stake, playercomm)
		SELECT 
			winlostdate, bettype, statusID,
			SUM(winlost), SUM(actual_stake), SUM(playercomm)
		FROM dbo.transfer WITH (NOLOCK)
		WHERE custid = @CustId AND statusID NOT IN (0,1)
			AND bettype NOT IN (21008, 21009) -- BBIN Transfer
			AND 1 = CASE WHEN bettype = 19999 AND winlostdate > @moveBetsDay THEN 0 --> new sum
						WHEN bettype = 20000 AND winlostdate > @balanceUpDay THEN 0 --> new bal
						WHEN winlostdate < @balanceUpDay THEN 0 --> old data
						WHEN winlostdate > @yesterday AND bettype >= 31000 THEN 0 --> Cash service today transfers
					ELSE 1 END
		GROUP BY winlostdate, bettype, statusID

		DELETE b
		FROM #BalanceInfo b
		WHERE EXISTS (SELECT 1 FROM #SportBettypeMatrix s WHERE b.bettype = s.bettype AND s.RefTable IN (1,2))
			AND b.winlostdate >= @yesterday

		UPDATE #BalanceInfo
		SET winlostdate = @yesterday
		WHERE bettype > 20000 AND winlostdate = @today

		DELETE #BalanceInfo WHERE winlostdate > @yesterday

		-- bettransRnG
		INSERT INTO #BalanceInfo (winlostdate, bettype, statusId, winlost, actual_stake, playercomm)
		SELECT 
			winlostdate, -2, statusID,
			SUM(winlost), SUM(actual_stake), SUM(playercomm)
		FROM dbo.bettransRnG WITH (NOLOCK)
		WHERE custid = @CustId AND winlostdate = @yesterday AND statusID NOT IN (0,1)
		GROUP BY
			winlostdate, statusID

		-- bettransLC
		INSERT INTO #BalanceInfo (winlostdate, bettype, statusId, winlost, actual_stake, playercomm)
		SELECT 
			winlostdate, -3, statusID,
			SUM(winlost), SUM(actual_stake), SUM(playercomm)
		FROM dbo.bettransLC WITH (NOLOCK)
		WHERE custid = @CustId AND winlostdate = @yesterday AND statusID NOT IN (0,1)
		GROUP BY
			winlostdate, statusID

		SELECT
			@YesterdayCash		= SUM(winlost - actual_stake + playercomm),
			
			@YesterdayBalance	= SUM(winlost - actual_stake + playercomm)
		FROM #BalanceInfo
	END

	--Reward
	DECLARE
			@RewardPending MONEY = NULL ,
			@RewardBalance MONEY = NULL ,  
			@RewardCurrency VARCHAR(10) = NULL 
	EXEC Acc_CustomerSelBalanceReward @CustId = @CustID
									  ,@RewardPending  = @RewardPending OUTPUT   
									  ,@RewardBalance  = @RewardBalance OUTPUT
									  ,@RewardCurrency = @RewardCurrency OUTPUT

	SELECT
		@transdate 				AS LastTxn,
		@Credit					AS Credit,
		@UsedCredit				AS UsedCredit,
		@CurrencyId				AS CurrencyId,
		@Currency				AS Currency,
		-----------------------------------------------
		@TotalCash				AS TotalCash,
		@YesterdayCash			AS YesterdayCash,
		@Outstanding			AS Outstanding,
		-----------------------------------------------
		@TotalBalance			AS TotalBalance,
		@YesterdayBalance		AS YesterdayBalance,
		@DownlineOutstanding	AS DownlineOutstanding,
		-----------------------------------------------
		@PendingTransfer3rd		AS PendingTransfer3rd,
		--Reward
		@RewardPending AS RewardPayable,
		@RewardBalance AS RewardReceivable,
		@RewardCurrency AS RewardCurrency

	DROP TABLE #SportBettypeMatrix
	DROP TABLE #BalanceInfo
END
GO
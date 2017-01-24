ALTER PROCEDURE [dbo].[EAS_CustomerSelByAg]
    @Recommend	int,  
    @Custid		int = null,  
    @Enabled	bit = null,  
    @Closed		bit = null,  
    @Suspended	bit = NULL,
	@UserID		INT = NULL
AS  
/*  
Created by: Scott  
Date: 2012-12-17  
Task : Customer list by agent
DB: DBCUST/CustDB
Original SP: Acc_CustomerSelByAg
Revisions:  
	- 20130121@Dan: Move sp from DB053/bodb02 to DBEAS/bodb_EAS
	- 20130517@Lukas: 
			fix bug - wrong comm rate 
			add filter to reduce workload
	- 20131023@Elodie: Get more field HideVirtualSports, DisableCasinoBonus, DisableHRFixedOdds			
	- 20140120@Elodie: Hot fix to get information of disabled customer
	- 20140626@Logan: 1.Add Keno status [Redmine: #18268]
	                  2.Code aligning
    - 20140822@Logan:   Add Esports status [Redmine: #20666]
	- 20150514@Kathy: Add Gold Deluxe product [Redmine:#34486] 
	- 20150612@Kathy: Move sp from DBEAS.bodb_EAS to DBCUST.CustDB, use temp GameType [Redmine:#36216]
	- 20150825@Helen: Colossus Bet - [Redmine: #41264]
	- 20150904@Helen: commission setting for MO [Redmine #41470]
	- 20151028@Helen: Member Information to support Muay Thai  [Redmine: #45496]
	- 20151209@Helen: Member information for Cockfighting [Redmine: #48133]
	- 20160114@Helen: Cricket - [Redmine: #50027]
	- 20160127@Billy: Member information for AllBet - [Redmine: #51713]
	- 20160411@Winnie: VoidBridge - [Redmine: #55546]
	- 20160606@Elodie: Hot fix to order list customer [Redmine: #58862]
	- 20160624@Winnie: Enhance Performance for Customer List SPs [Redmine: #59854]
	- 20160801@Elodie: NG2 Product - [Redmine: #60809]
	- 20160907@Elodie: Apply User Control permission of View/Access Special Site [Redmine: #63012]
	- 20160810@Winnie: All bet setting VIP Barcarat #61733
	- 20170120@Elodie: Don't offer Massac(1507), Malta(1509) anymore [#70693]
	
exec EAS_CustomerSelByAg @Recommend=9367272,@Custid=default,@Enabled=default,@Closed=default,@Suspended=default	
*/  
BEGIN    
    SET NOCOUNT ON  

    DECLARE @TransferOption BIT, @IsInternalAdmin BIT = 0
	DECLARE @IsMyanmarOdds BIT = 0,@discountMyanmarOdds DECIMAL (9,8) = 0
	
	DECLARE @tmp_GameType TABLE (GameTypeID INT, GameTypeName NVARCHAR(50), IsDisabled BIT, IBCBettypeID INT)
	 
	 BEGIN TRY		
		INSERT INTO @tmp_GameType (GameTypeID, GameTypeName, IsDisabled, IBCBettypeID)
		SELECT GameTypeID, GameTypeName, IsDisabled, IBCBettypeID FROM DBAGE.bodb02.dbo.GameType WITH (NOLOCK)
	 END TRY
	 BEGIN CATCH		
		INSERT INTO @tmp_GameType (GameTypeID, GameTypeName, IsDisabled, IBCBettypeID)
		SELECT GameTypeID, GameTypeName, IsDisabled, IBCBettypeID FROM DBTXN.bodb02.dbo.GameType WITH (NOLOCK)
	 END CATCH
	 
	 SET @IsMyanmarOdds = dbo.fn_IsMyanmarOdds (@Recommend)

	IF @IsMyanmarOdds = 1
		SET @discountMyanmarOdds = (SELECT commrate FROM AgentCommRate WITH (NOLOCK) WHERE custid = @Recommend AND Sporttype = 1 AND Bettype = 301)
	 
    SELECT @TransferOption = CASE
                               WHEN TransferOption = 0 THEN 0
                               ELSE 1
                             END
                             
     FROM dbo.custagent WITH(NOLOCK)
     WHERE custid = @Recommend

	 	 EXEC DBPOLICY.bodb02.dbo.Acc_CustomerIsInternalAdmin @Custid = @UserID, @IsInternalAdmin = @IsInternalAdmin OUTPUT

	-- For DCS
    DECLARE	@bitmapOrder_MuayThai		INT 
		,	@bitmapOrder_CockFighting	INT
		,	@bitmapOrder_Cricket		INT
		,	@IsIMBC						BIT = 0
		,	@bitmapOrder_AllBet			INT
		,	@bitmapOrder_AllBetVIP		INT
		,	@bitmapOrder_VoidBridge		INT
		,	@bitmapOrder_NG2			INT
    
    SET @bitmapOrder_MuayThai = (SELECT bitmapOrder FROM ProductStatusProfile WITH (NOLOCK) WHERE Sporttype = 44 AND Bettype = 3)
    SET @bitmapOrder_CockFighting = (SELECT bitmapOrder FROM ProductStatusProfile WITH (NOLOCK) WHERE Sporttype = 206 AND Bettype = 1003)
    SET @bitmapOrder_Cricket = (SELECT bitmapOrder FROM ProductStatusProfile WITH (NOLOCK) WHERE Sporttype = 50 AND Bettype = 501)
	SET @bitmapOrder_VoidBridge = (SELECT bitmapOrder FROM ProductStatusProfile WITH (NOLOCK) WHERE Sporttype = 212 AND Bettype = 4001)
	SET @bitmapOrder_NG2 = (SELECT bitmapOrder FROM ProductStatusProfile WITH (NOLOCK) WHERE Sporttype = 213 AND Bettype = 2501)
    
	SELECT	@bitmapOrder_AllBet =	(
										SELECT	psp.bitmapOrder
										FROM	dbo.ProductStatusProfile AS psp WITH(NOLOCK)
										WHERE	psp.Sporttype = 211
											AND	psp.Bettype = 2401
									)
	    
	SELECT	@bitmapOrder_AllBetVIP =	(
										SELECT	psp.bitmapOrder
										FROM	dbo.ProductStatusProfile AS psp WITH(NOLOCK)
										WHERE	psp.Sporttype = 211
											AND	psp.Bettype = 2402
									)
    
    DECLARE	@IsHidden_MuayThai		INT = 1
		,	@IsHidden_CockFighting	INT = 1
		,	@IsHidden_Cricket		INT = 1
		,	@IsHidden_AllBet		INT = 1
		,	@IsHidden_VoidBridge	INT = 1
		,	@IsHidden_NG2			INT = 1
    
    DECLARE	@SportBook2				INT = 16
		,	@CockFighting			INT = 19
		,	@Cricket				INT = 20
		,	@AllBet					INT = 21
		,	@VoidBridge				INT = 22
		,	@NG2					INT = 23
    
	IF EXISTS( SELECT 1 FROM dbo.f_CustSetting_SportBetTypeSettingSelect(@SportBook2,4))
	BEGIN
		SET @IsHidden_MuayThai = 0
	END
	IF EXISTS( SELECT 1 FROM dbo.f_CustSetting_SportBetTypeSettingSelect(@CockFighting,4))
	BEGIN
		SET @IsHidden_CockFighting = 0
	END
	IF EXISTS (SELECT TOP(1) 1 FROM dbo.f_CustSetting_SportBetTypeSettingSelect(@AllBet, 4))
	BEGIN
	    SET	@IsHidden_AllBet = 0
	END

	IF EXISTS( SELECT 1 FROM dbo.f_CustSetting_SportBetTypeSettingSelect(@VoidBridge,4))
	BEGIN
		SET @IsHidden_VoidBridge = 0
	END
	IF EXISTS( SELECT 1 FROM dbo.f_CustSetting_SportBetTypeSettingSelect(@NG2,11))
	BEGIN
		SET @IsHidden_NG2 = 0
	END
	IF EXISTS( SELECT 1 FROM dbo.f_CustSetting_SportBetTypeSettingSelect(@Cricket,4))
	BEGIN
		SET @IsHidden_Cricket = 0
	END
	
	IF EXISTS (SELECT 1 FROM Customer WITH (NOLOCK) WHERE custid = @Recommend AND [Site] = 'IMBC')
		SET @IsIMBC = 1
			
	
    SELECT custinfo.custid, custInfo.currency, roleid, autosuspend, reject, closed,
			MatchLimit, VirtualMultiplier, Enabled, DisableHorseRacing,
			DisableFinancial, DisableCasino, SyncCasino, DisableOutright,
			DisableOpenTote, DisableBingo, DisableNumber, SyncBingo,
			disable151_au, disable152_uk, disable152_au, disable153_au,
			isAutoResetP2P, DisableP2P, DisableFunP2P, DisableLiveCasino,
			SyncLiveCasino, DisableVirtualSports, DoubleCommLosing, Recommend,
			HideVirtualSports, DisableCasinoBonus, DisableHRFixedOdds, HideKeno,
			DisableEsports, DisableGoldDeluxe, HideGoldDeluxe,DisableColossusBet, HideColossusBet,

			-- For MuayThai
			(SELECT value FROM dbo.f_CustSetting_ProductStatusSel(cps.bitmapIsDisabled, @bitmapOrder_MuayThai)) AS DisableMuayThai,
			CAST(CASE WHEN @IsHidden_MuayThai = 0 AND (SELECT value FROM dbo.f_CustSetting_ProductStatusSel(cps.bitmapIsHidden, @bitmapOrder_MuayThai)) = 0 THEN 0 ELSE 1 END AS BIT) AS HideMuayThai,
			-- For CockFighting
			(SELECT value FROM dbo.f_CustSetting_ProductStatusSel(cps.bitmapIsDisabled, @bitmapOrder_CockFighting)) AS DisableCockFighting,
			CAST(CASE WHEN @IsHidden_CockFighting = 0 AND (SELECT value FROM dbo.f_CustSetting_ProductStatusSel(cps.bitmapIsHidden, @bitmapOrder_CockFighting)) = 0 THEN 0 ELSE 1 END AS BIT) AS HideCockFighting,
			-- For AllBet
			(SELECT value FROM dbo.f_CustSetting_ProductStatusSel(cps.bitmapIsDisabled, @bitmapOrder_AllBet)) AS DisableAllBet,
			(SELECT value FROM dbo.f_CustSetting_ProductStatusSel(cps.bitmapIsDisabled, @bitmapOrder_AllBetVIP)) AS DisableAllBetVIP,
			CAST(	CASE	WHEN	@IsHidden_AllBet = 0 
								--AND	sbhsc.IsHidden = 0
								AND	(SELECT value FROM dbo.f_CustSetting_ProductStatusSel(cps.bitmapIsHidden, @bitmapOrder_AllBet)) = 0 
								THEN 0
							ELSE 1 
					END AS BIT) AS HideAllBet,
			(SELECT value FROM dbo.f_CustSetting_ProductStatusSel(cpsUpline.bitmapIsHidden, @bitmapOrder_AllBet)) AS HideAllBetUpline,
			(SELECT value FROM dbo.f_CustSetting_ProductStatusSel(cps.bitmapHasSynced, @bitmapOrder_AllBet)) AS SyncedAllBet,
			(SELECT value FROM dbo.f_CustSetting_ProductStatusSel(cpsUpline.bitmapHasSynced, @bitmapOrder_AllBet)) AS SyncedAllBetUpline,
			1 AS SyncedAllBetDownline,
			
			-- For Cricket
			(SELECT value FROM dbo.f_CustSetting_ProductStatusSel(cps.bitmapIsDisabled, @bitmapOrder_Cricket)) AS DisableCricket,
			CAST( CASE WHEN @IsIMBC = 1 AND @IsHidden_Cricket = 0 AND (SELECT value FROM dbo.f_CustSetting_ProductStatusSel(cps.bitmapIsHidden, @bitmapOrder_Cricket)) = 0 THEN 0 ELSE 1 END AS BIT) AS HideCricket,

			-- For VoidBridge
			(SELECT value FROM dbo.f_CustSetting_ProductStatusSel(cps.bitmapIsDisabled, @bitmapOrder_VoidBridge)) AS DisableVoidBridge,
			(SELECT value FROM dbo.f_CustSetting_ProductStatusSel(cpsUpline.bitmapIsHidden, @bitmapOrder_VoidBridge)) AS HideVoidBridgeUpline,
			(SELECT value FROM dbo.f_CustSetting_ProductStatusSel(cpsUpline.bitmapIsDisabled, @bitmapOrder_VoidBridge)) AS DisableVoidBridgeUpline,
			CAST(CASE WHEN @IsHidden_VoidBridge = 0 AND (SELECT value FROM dbo.f_CustSetting_ProductStatusSel(cps.bitmapIsHidden, @bitmapOrder_VoidBridge)) = 0 THEN 0 ELSE 1 END AS BIT) AS HideVoidBridge,
			(SELECT value FROM dbo.f_CustSetting_ProductStatusSel(cps.bitmapHasSynced, @bitmapOrder_VoidBridge)) AS SyncedVoidBridge,
			(SELECT value FROM dbo.f_CustSetting_ProductStatusSel(cpsUpline.bitmapHasSynced, @bitmapOrder_VoidBridge)) AS SyncedVoidBridgeUpline,
			1 AS SyncedVoidBridgeDownline,
			
			-- For NG2
			(SELECT value FROM dbo.f_CustSetting_ProductStatusSel(cps.bitmapIsDisabled, @bitmapOrder_NG2)) AS DisableNG2,
			CAST(CASE WHEN @IsHidden_NG2 = 0 AND (SELECT value FROM dbo.f_CustSetting_ProductStatusSel(cpsUpline.bitmapIsHidden, @bitmapOrder_NG2)) = 0 THEN 0 ELSE 1 END AS BIT) AS HideNG2Upline,
			(SELECT value FROM dbo.f_CustSetting_ProductStatusSel(cpsUpline.bitmapIsDisabled, @bitmapOrder_NG2)) AS DisableNG2Upline,
			CAST(CASE WHEN @IsHidden_NG2 = 0 AND (SELECT value FROM dbo.f_CustSetting_ProductStatusSel(cps.bitmapIsHidden, @bitmapOrder_NG2)) = 0 THEN 0 ELSE 1 END AS BIT) AS HideNG2,
			(SELECT value FROM dbo.f_CustSetting_ProductStatusSel(cps.bitmapHasSynced, @bitmapOrder_NG2)) AS SyncedNG2,
			(SELECT value FROM dbo.f_CustSetting_ProductStatusSel(cpsUpline.bitmapHasSynced, @bitmapOrder_NG2)) AS SyncedNG2Upline
    INTO #custinfo
    FROM dbo.custinfo WITH(NOLOCK)
		LEFT JOIN CustProductStatus cps WITH (NOLOCK) ON cps.CustID = custinfo.custid  

		-- Check isHidden AllBet
		--OUTER APPLY	dbo.f_CustSetting_SportBetTypeHiddenBySiteCurrency(custInfo.custid, @AllBet) AS sbhsc
		
		-- Upline Status
		INNER JOIN	dbo.CustProductStatus AS cpsUpline WITH (NOLOCK)
				ON	cpsUpline.CustID =	CASE	WHEN custInfo.roleid = 1 THEN custInfo.recommend
												WHEN custInfo.roleid = 2 THEN custInfo.mrecommend
												ELSE custInfo.srecommend
										END
		   
     WHERE Recommend = @Recommend
       AND roleid = 1
       AND (@custid is null or custinfo.custid = @custid)
       AND enabled = case
                       when coalesce(@Closed, @Suspended) is not null then 1
                       else coalesce(@enabled, enabled)
                     end
       AND isnull(closed, 0) = case
                                 when @suspended = 1 then 0
                                 else coalesce(@closed, isnull(closed, 0))
                               end
       AND isnull(reject, 0) = case
                                 when @Closed = 0 then 0
                                 else coalesce(@suspended, isnull(reject, 0))
                               end

    --temp custsetting
    SELECT cs.custid,
           bettype,
           sporttype,
           discount,
           playerdiscount
      INTO #CustSetting
      FROM dbo.custsetting cs WITH(NOLOCK)
		INNER JOIN #custinfo ci on cs.custid = ci.custid
     WHERE bettype in (1, 4, 5)
       and sporttype = 1

    --temp custsetting3rd
    SELECT cs3.custid,
           bettype,
           sporttype,
           discount,
           playerdiscount
      INTO #custsetting3rd
      FROM dbo.custsetting3rd cs3 WITH(NOLOCK)
		INNER JOIN #custinfo ci on cs3.custid = ci.custid
     WHERE bettype = 81
       and sporttype = 161
       
	-- get data for filtered customers	
	DECLARE @SearchQuery varchar(1024)
	DECLARE @tmp TABLE (siteid INT,site NVARCHAR(50), SpecialGroup TINYINT )
	DECLARE @tmpUserid VARCHAR(50)
	SELECT @tmpUserid=CAST(@Userid AS VARCHAR(50))
	SELECT @SearchQuery = 'SELECT * 
	FROM OPENQUERY(DBPOLICY, 
	''SELECT siteid , site,SpecialGroup FROM bodb02.dbo.f_GetDeniedSiteByUser( ''''' + @tmpUserid + ''''')'')'

	INSERT INTO  @tmp (siteid , site,SpecialGroup)
	EXECUTE(@SearchQuery)

    SELECT cu.custid,
           cu.username,
           isnull(cu.username2,'') NickName,
           ci.enabled,
           ci.closed,
           isnull(ci.reject, 0) as suspended,
           cu.roleid,
           isnull(cu.firstname, '') as firstname,
           isnull(cu.lastname, '') as lastname,
           cu.ugroup,
	       --agent commission
	       max(case
	             when cs.bettype = 1 and cs.sporttype = 1 then cs.discount
	             else 0
	           end) as discount,
	       max(case
	             when cs.bettype = 4 and cs.sporttype = 1 then cs.discount
	             else 0
	           end) as discountcs,
	       max(case
	             when cs.bettype = 5 and cs.sporttype = 1 then cs.discount
	             else 0
	           end) as discount1x2,
	       max(case
	             when cs3.bettype = 81 and cs3.sporttype = 161 then cs3.discount
	             else 0
	           end) as discountnumber,

   	       --player commission
	       max(case
	             when cs.bettype = 1 and cs.sporttype = 1 then cs.playerdiscount
	             else 0
	           end) as playerdiscount,
	       max(case
	             when cs.bettype = 4 and cs.sporttype = 1 then cs.playerdiscount
	             else 0
	           end) as playerdiscountcs,
	       max(case
	             when cs.bettype = 5 and cs.sporttype = 1 then cs.playerdiscount
	             else 0
	           end) as playerdiscount1x2,
	       max(case
	             when cs3.bettype = 81 and cs3.sporttype = 161 then cs3.playerdiscount
	             else 0
	           end) as playerdiscountnumber,
	       cu.creatdate as createdate,
	       isnull(cu.iplogin, '') as lastloginip,
	       ci.DoubleCommLosing,
	       isnull(ci.DisableOutright, 0) as DisableOutright,
	       isnull(case
	                when ci.disablehorseracing = 0 or ci.disableOpenTote = 0
	                  or ci.disable151_au = 0 or ci.disable152_uk = 0
	                  or ci.disable152_au = 0 or ci.disable153_au = 0 then 0
	                else 1
	              end, 0) as Disable151,
	       isnull(ci.disablehorseracing, 0) as disable151_31,
	       isnull(ci.disableOpenTote, 0) as disable151_41,
	       isnull(ci.disable151_au, 0) as disable151_51,
	       isnull(ci.disable152_uk, 0) as disable152_41,
	       isnull(ci.disable152_au, 0) as disable152_51,
	       isnull(ci.disable153_au, 0) as disable153_51,

	       -- For casino
	       ci.synccasino,
	       ci.disablecasino,
	       ci.syncBingo,
	       ci.DisableBingo,
	       ci.DisableNumber,

	       --For P2P
	       ci.isAutoResetP2P,
	       ci.DisableP2P,
	       ci.DisableFunP2P,

	       -- For live casino
	       ci.DisableLiveCasino,
	       ci.SyncLiveCasino,

	       -- For VirtualSports
	       ci.DisableVirtualSports,
	       ci.DoubleCommLosing,
	       ci.HideVirtualSports,
           ci.DisableCasinoBonus,
	       ci.DisableHRFixedOdds,
	       -- For Esports
	       ci.DisableEsports,
	       
	       -- For Keno
	       ci.HideKeno,
	       MIN(CASE WHEN g.IBCBetTypeID in (1501,1503,1504,1505,1508,1511,1513,1514,1515,1516) THEN cg.IsDisabled ELSE 1 END) as DisableKeno,
	       ISNULL(ci.DisableGoldDeluxe,1) AS DisableGoldDeluxe,
		   ISNULL(ci.HideGoldDeluxe,1) AS HideGoldDeluxe,
		   
		   ISNULL(ci.DisableColossusBet,1) AS DisableColossusBet,
		   ISNULL(ci.HideColossusBet,1) AS HideColossusBet,
		   
		   ISNULL(ci.DisableMuayThai,1) AS DisableMuayThai,
		   ISNULL(ci.HideMuayThai,1) AS HideMuayThai,
		   
		   ISNULL(ci.DisableCockFighting,1) AS DisableCockFighting,
		   ISNULL(ci.HideCockFighting,1) AS HideCockFighting,
		   
		   ISNULL(ci.DisableAllBet,1) AS DisableAllBet,
		   ISNULL(ci.DisableAllBetVIP,1) AS DisableAllBetVIP,
		   ISNULL(ci.HideAllBet,1) AS HideAllBet,
		    ISNULL(ci.HideAllBetUpline,1) AS HideAllBetUpline,
		   ISNULL(ci.SyncedAllBet,1) AS SyncedAllBet,
		   ISNULL(ci.SyncedAllBetUpline,1) AS SyncedAllBetUpline,
		   ISNULL(ci.SyncedAllBetDownline,1) AS SyncedAllBetDownline,

		    
		   ISNULL(ci.DisableVoidBridge,1) AS DisableVoidBridge,
		   ISNULL(ci.DisableVoidBridgeUpline,1) AS DisableVoidBridgeUpline,
		   ISNULL(ci.HideVoidBridge,1) AS HideVoidBridge,
		   ISNULL(ci.HideVoidBridgeUpline,1) AS HideVoidBridgeUpline,
		   ISNULL(ci.SyncedVoidBridge,1) AS SyncedVoidBridge,
		   ISNULL(ci.SyncedVoidBridgeUpline,1) AS SyncedVoidBridgeUpline,
		   ISNULL(ci.SyncedVoidBridgeDownline,1) AS SyncedVoidBridgeDownline,

		   ISNULL(ci.DisableNG2,1) AS DisableNG2,
		   ISNULL(ci.DisableNG2Upline,1) AS DisableNG2Upline,
		   ISNULL(ci.HideNG2,1) AS HideNG2,
		   ISNULL(ci.HideNG2Upline,1) AS HideNG2Upline,
		   ISNULL(ci.SyncedNG2,1) AS SyncedNG2,
		   ISNULL(ci.SyncedNG2Upline,1) AS SyncedNG2Upline,

	       --transfer condition
	       @TransferOption disableTransfer,	
	       ROW_NUMBER() OVER (ORDER BY ci.enabled desc,
	                                   ci.closed,
	                                   isnull(ci.reject, 0),
	                                   cu.username
	                         ) as RowNumber,
			-- Myanmar odds
			ISNULL(@IsMyanmarOdds,0) AS IsMyanmarOdds,
			ISNULL(AC.playerdiscount,0) AS playerdiscountMyanmarOdds,
			ISNULL(@discountMyanmarOdds,0) AS discountMyanmarOdds,
			
			-- Cricket
			ISNULL(@IsIMBC,0) AS IsIMBC,
			ISNULL(ci.DisableCricket,1) AS DisableCricket,
			ISNULL(ci.HideCricket,1) AS HideCricket,
			ISNULL(cdm.PlayerDiscount,0) AS playerdiscountCricket,
			ISNULL(cdm.AgentDiscount,0) AS discountCricket
			
      FROM dbo.customer AS cu with(NOLOCK)
		INNER JOIN #Custinfo ci with(nolock) on cu.custid = ci.custid
		
		 LEFT JOIN #CustSetting as cs with(NOLOCK) on cu.custid = cs.custid
		 LEFT JOIN #custsetting3rd cs3 with(nolock) on cu.custid = cs3.custid
		 LEFT JOIN dbo.CustGameType cg WITH(NOLOCK) ON cg.CustID = ci.custid
		 LEFT JOIN @tmp_GameType g ON cg.GameTypeID = g.GameTypeID
													 AND g.IBCBetTypeID IN (1501,1503,1504,1505,1508,1511,1513,1514,1515,1516)
		 
		LEFT JOIN CustCommRate AC WITH (NOLOCK) ON AC.CustId = CI.custid AND AC.Sporttype = 1 AND AC.Bettype = 301 AND @IsMyanmarOdds = 1		 																			
		LEFT JOIN CustDiscount3rd_Member cdm WITH (NOLOCK) ON cdm.CustID = ci.custid AND cdm.SportType = 50 AND cdm.BetType = 501 AND @IsIMBC = 1
     WHERE ((cs.sporttype IN (1) AND cs.bettype IN (1, 5, 4) AND cs3.sporttype IN (161) AND cs3.bettype IN (81))
				OR (cs.sporttype IS NULL AND cs.bettype IS NULL AND cs3.sporttype IS NULL AND cs3.bettype IS NULL))
			AND (@IsInternalAdmin = 0 OR cu.site NOT IN (SELECT site FROM @tmp ))
	 GROUP BY cu.custid, cu.username, cu.username2, cu.ugroup, ci.enabled, ci.closed,
			   ci.reject, cu.roleid, cu.firstname, cu.lastname, cu.creatdate, cu.iplogin,
			   ci.DoubleCommLosing, ci.DisableOutright, ci.disablehorseracing,
			   ci.disableOpenTote, ci.disable151_au, ci.disable152_uk, ci.disable152_au,
			   ci.disable153_au, ci.disablehorseracing, ci.disableOpenTote, ci.disable151_au,
			   ci.disable152_uk, ci.disable152_au, ci.disable153_au, ci.synccasino,
			   ci.disablecasino, ci.syncBingo, ci.DisableBingo, ci.DisableNumber,  
			   ci.isAutoResetP2P, ci.DisableP2P, ci.DisableFunP2P, ci.DisableLiveCasino,
			   ci.SyncLiveCasino, ci.DisableVirtualSports, ci.DoubleCommLosing,
			   ci.HideVirtualSports, ci.DisableCasinoBonus, ci.DisableHRFixedOdds,
			   ci.HideKeno, ci.DisableEsports, ci.HideGoldDeluxe, ci.DisableGoldDeluxe,ci.DisableColossusBet,ci.HideColossusBet,AC.playerdiscount
			   , ci.DisableMuayThai, ci.HideMuayThai,ci.DisableCockFighting,ci.HideCockFighting, ci.DisableAllBet,ci.DisableAllBetVIP, ci.HideAllBet, ci.HideAllBetUpline,  ci.SyncedAllBet, ci.SyncedAllBetUpline, ci.SyncedAllBetDownline
			   ,ci.DisableVoidBridge,ci.DisableVoidBridgeUpline, ci.HideVoidBridge,ci.HideVoidBridgeUpline, ci.SyncedVoidBridge,ci.SyncedVoidBridgeUpline, ci.SyncedVoidBridgeDownline
			   ,ci.DisableNG2,ci.DisableNG2Upline, ci.HideNG2,ci.HideNG2Upline, ci.SyncedNG2,ci.SyncedNG2Upline
			   , ci.HideCricket, ci.DisableCricket, cdm.AgentDiscount, cdm.PlayerDiscount
	ORDER BY RowNumber

    DROP TABLE #Custinfo,
               #CustSetting,
               #custsetting3rd
END

GO
GRANT EXECUTE ON [dbo].[EAS_CustomerSelByAg] TO [bodbExtAccNet] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[EAS_CustomerSelByAg] TO [vnteam] AS [dbo]
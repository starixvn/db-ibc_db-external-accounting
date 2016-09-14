ALTER PROCEDURE [dbo].[EAS_CustomerSelByCom]  
    @GroupName	VARCHAR(50) = 'ACCTHAI',
    @Custid		int = null,
    @Enabled	bit = null,
    @Closed		bit = null,
    @Suspended	bit = NULL,
	@UserID		INT = NULL
AS  

/*  
Created by: Scott  
Date: 2012-12-17  
Task : Customer list by company
DB: DBCUST/CustDB
Original SP: Acc_CustomerSelBySAg
Revisions:  
	- 20130121@Dan: Move sp from DB053/bodb02 to DBEAS/bodb_EAS, call to bodb_AGE for Acc_CustGroup
	- 20130517@Lukas: 
			fix bug - wrong comm rate 
			add filter to reduce workload
	- 20131023@Elodie: Get more field HideVirtualSports, DisableCasinoBonus, DisableHRFixedOdds			
	- 20140120@Elodie: Hot fix to get information of disabled customer
	- 20140626@Logan:   1.Add Keno status [Redmine: #18268]
	                    2.Code aligning
    - 20140822@Logan:   Add Esports status [Redmine: #20666]
    - 20150514@Kathy: Add Gold Deluxe product [Redmine:#34486] 
    - 20150612@Kathy: Move sp from DBEAS.bodb_EAS to DBCUST.CustDB, use temp GameType [Redmine:#36216]
    - 20150825@Helen: Colossus Bet - [Redmine: #41264]
    - 20150904@Helen: commission setting for MO [Redmine #41470]
    - 20151019@Helen: Display wrong comm rate of Group A,B,C,D [Redmine: #45851]
    - 20151028@Helen: Member Information to support Muay Thai  [Redmine: #45496]
    - 20151209@Helen: Member information for Cockfighting [Redmine: #48133]
    - 20160114@Helen: Cricket - [Redmine: #50027]
	- 20160127@Billy: Member information for AllBet - [Redmine: #51713]
	- 20160411@Winnie: VoidBridge - [Redmine: #55546]
	- 20160606@Elodie: Hot fix to order list customer [Redmine: #58862]
	- 20160624@Winnie: Enhance Performance for Customer List SPs [Redmine: #59854]
	- 20160907@Elodie: Apply User Control permission of View/Access Special Site [Redmine: #63012]

exec EAS_CustomerSelByCom @GroupName='ACCDDD',@Custid=default,@Enabled=default,@Closed=default,@Suspended=default    
*/
BEGIN
    SET NOCOUNT ON

    DECLARE @tmpSuperList TABLE( custID INT, username VARCHAR(30))

	DECLARE @tmp_GameType TABLE (GameTypeID INT, GameTypeName NVARCHAR(50), IsDisabled BIT, IBCBettypeID INT)
	 
	 BEGIN TRY		
		INSERT INTO @tmp_GameType (GameTypeID, GameTypeName, IsDisabled, IBCBettypeID)
		SELECT GameTypeID, GameTypeName, IsDisabled, IBCBettypeID FROM DBAGE.bodb02.dbo.GameType WITH (NOLOCK)
	 END TRY
	 BEGIN CATCH		
		INSERT INTO @tmp_GameType (GameTypeID, GameTypeName, IsDisabled, IBCBettypeID)
		SELECT GameTypeID, GameTypeName, IsDisabled, IBCBettypeID FROM DBTXN.bodb02.dbo.GameType WITH (NOLOCK)
	 END CATCH
	 
	 DECLARE @IsMyanmarOdds BIT = 0, @IsInternalAdmin BIT = 0
	 
    INSERT INTO @tmpSuperList(CustID, username)
    SELECT custID, username 
      FROM dbo.custinfo WITH(NOLOCK)
     WHERE custid in (SELECT custid
                        from DBAGE.bodb_AGE.dbo.Acc_CustGroup WITH(nolock)
                       WHERE GroupName = @GroupName
                     )
       AND (@Custid IS NULL OR custid = @Custid)
       AND roleid = 4
       AND enabled = CASE
                       WHEN COALESCE(@Closed, @Suspended) IS NOT NULL THEN 1
                       ELSE COALESCE(@enabled, enabled)
                     END
       AND ISNULL(closed, 0) = CASE
                                 WHEN @suspended = 1 then 0
                                 ELSE COALESCE(@closed, ISNULL(closed, 0))
                               END
       AND ISNULL(reject, 0) = CASE
                                 WHEN @Closed = 0 then 0
                                 ELSE COALESCE(@suspended, ISNULL(reject, 0))
                               END

	EXEC DBPOLICY.bodb02.dbo.Acc_CustomerIsInternalAdmin @Custid = @UserID, @IsInternalAdmin = @IsInternalAdmin OUTPUT

    --------output
    -- For DCS
    DECLARE	@bitmapOrder_MuayThai		INT 
		,	@bitmapOrder_CockFighting	INT
		,	@bitmapOrder_Cricket		INT
		,	@bitmapOrder_AllBet			INT
		,	@bitmapOrder_VoidBridge		INT

    SET @bitmapOrder_MuayThai = (SELECT bitmapOrder FROM ProductStatusProfile WITH (NOLOCK) WHERE Sporttype = 44 AND Bettype = 3)
    SET @bitmapOrder_CockFighting = (SELECT bitmapOrder FROM ProductStatusProfile WITH (NOLOCK) WHERE Sporttype = 206 AND Bettype = 1003)
    SET @bitmapOrder_Cricket = (SELECT bitmapOrder FROM ProductStatusProfile WITH (NOLOCK) WHERE Sporttype = 50 AND Bettype = 501)
	SET @bitmapOrder_VoidBridge = (SELECT bitmapOrder FROM ProductStatusProfile WITH (NOLOCK) WHERE Sporttype = 212 AND Bettype = 4001)
    
	SELECT	@bitmapOrder_AllBet =	(
										SELECT	psp.bitmapOrder
										FROM	dbo.ProductStatusProfile AS psp WITH(NOLOCK)
										WHERE	psp.Sporttype = 211
											AND	psp.Bettype = 2401
									)
    
    DECLARE	@IsHidden_MuayThai		INT = 1
		,	@IsHidden_CockFighting	INT = 1
		,	@IsHidden_Cricket		INT = 1
		,	@IsHidden_AllBet		INT = 1
		,	@IsHidden_VoidBridge	INT = 1
    
    DECLARE	@SportBook2				INT = 16
		,	@CockFighting			INT = 19
		,	@Cricket				INT = 20
		,	@AllBet					INT = 21
		,	@VoidBridge				INT = 22
    
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
	
	IF EXISTS( SELECT 1 FROM dbo.f_CustSetting_SportBetTypeSettingSelect(@Cricket,4))
	BEGIN
		SET @IsHidden_Cricket = 0
	END

	IF EXISTS( SELECT TOP 1 1 FROM dbo.f_CustSetting_SportBetTypeSettingSelect(@VoidBridge,4))
	BEGIN
		SET @IsHidden_VoidBridge = 0
	END
			
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
           ci.enabled,
           ci.closed,
           ISNULL(ci.reject, 0) as suspended,
           cu.roleid,
           ISNULL(cu.firstname, '') as firstname,
           ISNULL(cu.lastname, '') as lastname,
	       
		   MAX(case when cs.bettype = 1 and cs.sporttype=1 then cs.groupa else 0 end) as groupa,
		   MAX(case when cs.bettype = 1 and cs.sporttype=1 then cs.groupb else 0 end) as groupb,
		   MAX(case when cs.bettype = 1 and cs.sporttype=1 then cs.groupc else 0 end) as groupc,
		   MAX(case when cs.bettype = 1 and cs.sporttype=1 then cs.groupd else 0 end) as groupd,

	       MAX(case
	             WHEN cs.bettype = 5 and cs.sporttype = 1 then cs.sdiscount
	             ELSE 0
	           end) as discount1x2,
	       MAX(case
	             WHEN cs.bettype = 4 and cs.sporttype = 1 then cs.sdiscount
	             ELSE 0
	           end) as discountcs,
           MAX(case
                 WHEN cs3.bettype = 81 and cs3.sporttype = 161 then cs3.sdiscount
                 ELSE 0
               end) as discountnumber,
           cu.creatdate as createdate,
           ISNULL(cu.iplogin, '') as lastloginip,
	       ci.DoubleCommLosing,
	       ISNULL(ci.DisableOutright, 0) as DisableOutright,
	       ISNULL(case
	                WHEN ci.disablehorseracing = 0 or ci.disableOpenTote = 0
	                  or ci.disable151_au = 0 or ci.disable152_uk = 0
					  or ci.disable152_au = 0 or ci.disable153_au = 0 then 0
					ELSE 1
				  end ,0) as Disable151,
	       ISNULL(ci.disablehorseracing, 0) as disable151_31,
	       ISNULL(ci.disableOpenTote, 0) as disable151_41,
	       ISNULL(ci.disable151_au, 0) as disable151_51,
	       ISNULL(ci.disable152_uk, 0) as disable152_41,
	       ISNULL(ci.disable152_au, 0) as disable152_51,
	       ISNULL(ci.disable153_au, 0) as disable153_51,
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
	       ci.HideVirtualSports,
	       ci.DisableCasinoBonus,
	       ci.DisableHRFixedOdds,
	       -- For Esports
	       ci.DisableEsports,
	       -- For Keno
	       ci.HideKeno,
	       MIN(CASE
	             WHEN g.IBCBetTypeID in (1501, 1503, 1504,
	                                     1505, 1507, 1508,
	                                     1509, 1511, 1513) THEN cg.IsDisabled
	             ELSE 1
	           END) as DisableKeno,
	       ISNULL(ci.DisableGoldDeluxe,1) AS DisableGoldDeluxe,
		   ISNULL(ci.HideGoldDeluxe,1) AS HideGoldDeluxe,
		   
		   ISNULL(ci.DisableColossusBet,1) AS DisableColossusBet,
		   ISNULL(ci.HideColossusBet,1) AS HideColossusBet,
			-- For MuayThai
			(SELECT value FROM dbo.f_CustSetting_ProductStatusSel(cps.bitmapIsDisabled, @bitmapOrder_MuayThai)) AS DisableMuayThai,
			CAST(CASE WHEN @IsHidden_MuayThai = 0 AND (SELECT value FROM dbo.f_CustSetting_ProductStatusSel(cps.bitmapIsHidden, @bitmapOrder_MuayThai)) = 0 THEN 0 ELSE 1 END AS BIT) AS HideMuayThai,
			-- For CockFighting
			(SELECT value FROM dbo.f_CustSetting_ProductStatusSel(cps.bitmapIsDisabled, @bitmapOrder_CockFighting)) AS DisableCockFighting,
			CAST(CASE WHEN @IsHidden_CockFighting = 0 AND (SELECT value FROM dbo.f_CustSetting_ProductStatusSel(cps.bitmapIsHidden, @bitmapOrder_CockFighting)) = 0 THEN 0 ELSE 1 END AS BIT) AS HideCockFighting,
			-- For AllBet
			(SELECT value FROM dbo.f_CustSetting_ProductStatusSel(cps.bitmapIsDisabled, @bitmapOrder_AllBet)) AS DisableAllBet,
			CAST(	CASE	WHEN	@IsHidden_AllBet = 0 
								--AND	MAX(sbhsc.IsHidden) = 0
								AND	(SELECT value FROM dbo.f_CustSetting_ProductStatusSel(cps.bitmapIsHidden, @bitmapOrder_AllBet)) = 0 
								THEN 0
							ELSE 1 
					END AS BIT) AS HideAllBet,
			1 AS HideAllBetUpline,
			(SELECT value FROM dbo.f_CustSetting_ProductStatusSel(cps.bitmapHasSynced, @bitmapOrder_AllBet)) AS SyncedAllBet,
			1 AS SyncedAllBetUpline,
			CASE	WHEN EXISTS	(	SELECT	1
									FROM		dbo.CustProductStatus AS cpsDownline WITH (NOLOCK)
									INNER JOIN	dbo.custInfo AS ciDownline WITH (NOLOCK)
											ON	ciDownline.custid = cpsDownline.CustID
									WHERE	ciDownline.srecommend = cu.custid
										AND	(SELECT value FROM dbo.f_CustSetting_ProductStatusSel(cpsDownline.bitmapHasSynced, @bitmapOrder_AllBet)) = 0)
						THEN 0
					ELSE 1
			END AS SyncedAllBetDownline,

		   -- For Myanmar Odds
		   CASE WHEN ac.CustId IS NOT NULL THEN 1 ELSE 0 END AS  IsMyanmarOdds,
		   ISNULL(AC.CommRate,0) AS discountMyanmarOdds,
		   
		   -- For Cricket
		   CASE WHEN cu.[site] = 'IMBC' THEN 1 ELSE 0 END AS IsIMBC,
		   (SELECT value FROM dbo.f_CustSetting_ProductStatusSel(cps.bitmapIsDisabled, @bitmapOrder_Cricket)) AS DisableCricket,
		   CAST( CASE WHEN cu.[site] = 'IMBC' AND @IsHidden_Cricket = 0 AND (SELECT value FROM dbo.f_CustSetting_ProductStatusSel(cps.bitmapIsHidden, @bitmapOrder_Cricket)) = 0 THEN 0 ELSE 1 END AS BIT) AS HideCricket,
		   ISNULL(cdm.Discount,0) AS discountCricket,	
		   -- For VoidBridge
			(SELECT value FROM dbo.f_CustSetting_ProductStatusSel(cps.bitmapIsDisabled, @bitmapOrder_VoidBridge)) AS DisableVoidBridge,
			1 AS DisableVoidBridgeUpline,
			CAST(CASE WHEN @IsHidden_VoidBridge = 0 AND (SELECT value FROM dbo.f_CustSetting_ProductStatusSel(cps.bitmapIsHidden, @bitmapOrder_VoidBridge)) = 0 THEN 0 ELSE 1 END AS BIT) AS HideVoidBridge,
			1 AS HideVoidBridgeUpline,
			(SELECT value FROM dbo.f_CustSetting_ProductStatusSel(cps.bitmapHasSynced, @bitmapOrder_VoidBridge)) AS SyncedVoidBridge,
		   1 AS SyncedVoidBridgeUpline,
			CASE	WHEN EXISTS	(	SELECT	1
									FROM		dbo.CustProductStatus AS cpsDownline WITH (NOLOCK)
									INNER JOIN	dbo.custInfo AS ciDownline WITH (NOLOCK)
											ON	ciDownline.custid = cpsDownline.CustID
									WHERE	ciDownline.srecommend = cu.custid
										AND	(SELECT value FROM dbo.f_CustSetting_ProductStatusSel(cpsDownline.bitmapHasSynced, @bitmapOrder_VoidBridge)) = 0)
						THEN 0
					ELSE 1
			END AS SyncedVoidBridgeDownline,

	       ROW_NUMBER() OVER(ORDER BY ci.enabled desc, ci.closed,
	                                  ISNULL(ci.reject,0), cu.username) as RowNumber
      FROM dbo.customer cu with(nolock)
		INNER JOIN @tmpSuperList sl on sl.custid = cu.custid
		INNER JOIN CustSuper CSuper WITH (NOLOCK) ON CSuper.Custid = sl.Custid
		INNER JOIN dbo.custinfo ci with(nolock) on ci.custid = cu.custid
		 LEFT JOIN dbo.CustSetting as cs with(NOLOCK) on cu.custid = cs.custid
		 LEFT JOIN dbo.custsetting3rd cs3 with(nolock) on cu.custid = cs3.custid
		 LEFT JOIN dbo.CustGameType cg WITH(NOLOCK) ON cu.custid = cg.CustID
		 LEFT JOIN @tmp_GameType g ON g.GameTypeID = cg.GameTypeID
													 AND g.IBCBetTypeID IN (1501, 1503, 1504,
																			1505, 1507, 1508,
																			1509, 1511, 1513)
		LEFT JOIN AgentCommRate AC WITH (NOLOCK) ON AC.CustId = CI.custid AND AC.Sporttype = 1 AND AC.Bettype = 301 																			
		LEFT JOIN CustProductStatus cps WITH (NOLOCK) ON cps.CustID = ci.custid 
		LEFT JOIN CustDiscount3rd_Agent cdm WITH (NOLOCK) ON cdm.CustID = ci.custid AND cdm.SportType = 50 AND cdm.BetType = 501 AND cu.[site] = 'IMBC' AND @IsHidden_Cricket = 0

		-- Check isHidden AllBet
		--OUTER APPLY	dbo.f_CustSetting_SportBetTypeHiddenBySiteCurrency(cu.custid, @AllBet) AS sbhsc
		   
		
     WHERE ((cs.sporttype IN (1) AND cs.bettype IN (1,5,4) AND cs3.sporttype IN (161) AND cs3.bettype IN (81))
				OR (cs.sporttype IS NULL AND cs.bettype IS NULL AND cs3.sporttype IS NULL AND cs3.bettype IS NULL))
			AND (@IsInternalAdmin = 0 OR cu.site NOT IN (SELECT site FROM @tmp ))
	  GROUP BY cu.custid, cu.username, ci.enabled, ci.closed, ci.reject, cu.roleid,
			   cu.firstname, cu.lastname, cu.creatdate, cu.iplogin,	ci.DisableOutright,
			   ci.disablehorseracing, ci.disableOpenTote, ci.disable151_au, ci.disable152_uk,
			   ci.disable152_au, ci.disable153_au, ci.disablehorseracing, ci.disableOpenTote,
			   ci.disable151_au, ci.disable152_uk, ci.disable152_au, ci.disable153_au,
			   ci.synccasino, ci.disablecasino, ci.syncBingo, ci.DisableBingo, ci.DisableNumber,
			   ci.isAutoResetP2P, ci.DisableP2P, ci.DisableFunP2P, ci.DisableLiveCasino,
			   ci.SyncLiveCasino, ci.DisableVirtualSports, ci.DoubleCommLosing, ci.HideVirtualSports,
			   ci.DisableCasinoBonus, ci.DisableHRFixedOdds, ci.HideKeno, ci.DisableEsports,
			   ci.DisableGoldDeluxe, ci.HideGoldDeluxe, ci.DisableColossusBet, ci.HideColossusBet,AC.CommRate,ac.CustId,
			   cps.bitmapIsDisabled,cps.bitmapIsHidden, cps.bitmapHasSynced,cdm.Discount,cu.[site]
	ORDER BY RowNumber
			   
END

GO
GRANT EXECUTE ON [dbo].[EAS_CustomerSelByCom] TO [bodbExtAccNet] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[EAS_CustomerSelByCom] TO [vnteam] AS [dbo]
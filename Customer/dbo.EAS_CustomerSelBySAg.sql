ALTER PROCEDURE [dbo].[EAS_CustomerSelBySAg]  
    @SRecommend int,  
    @Custid     int = null,  
    @Enabled    bit = null,  
    @Closed     bit = null,  
    @Suspended  bit = NULL, 
	@UserID		INT = NULL
AS  
/*  
Created by: Scott  
Date: 2012-12-17  
Task : Customer list by super
DB: DBCUST/CustDB
Original SP: Acc_CustomerSelBySAg
Revisions:  
	- 20130121@Dan: Move sp from DB053/bodb02 to DBEAS/bodb_EAS
	- 20130517@Lukas: add filter to reduce workload
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
	- 20160801@Elodie: NG2 Product - [Redmine: #60809]
	- 20160907@Elodie: Apply User Control permission of View/Access Special Site [Redmine: #63012]
	- 20160810@Winnie: #61733 Allbet VIP Barcarat

exec EAS_CustomerSelBySAg @SRecommend=4792246,@Custid=default,@Enabled=default,@Closed=default,@Suspended=default
*/
BEGIN
    SET NOCOUNT ON  

    DECLARE @TransferOption BIT, @IsInternalAdmin BIT = 0
	DECLARE @IsMyanmarOdds BIT = 0
	 DECLARE @tmp_GameType TABLE (GameTypeID INT, GameTypeName NVARCHAR(50), IsDisabled BIT, IBCBettypeID INT)
	 
	 BEGIN TRY		
		INSERT INTO @tmp_GameType (GameTypeID, GameTypeName, IsDisabled, IBCBettypeID)
		SELECT GameTypeID, GameTypeName, IsDisabled, IBCBettypeID FROM DBAGE.bodb02.dbo.GameType WITH (NOLOCK)
	 END TRY
	 BEGIN CATCH		
		INSERT INTO @tmp_GameType (GameTypeID, GameTypeName, IsDisabled, IBCBettypeID)
		SELECT GameTypeID, GameTypeName, IsDisabled, IBCBettypeID FROM DBTXN.bodb02.dbo.GameType WITH (NOLOCK)
	 END CATCH
 
    SELECT @TransferOption = case
                               when TransferOption = 0 then 0
                               else 1
                             end,
           @IsMyanmarOdds = IsMyanmarOdds                  
     FROM dbo.custsuper WITH(NOLOCK)
     WHERE custid = @SRecommend
	 
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
	
	IF EXISTS( SELECT 1 FROM dbo.f_CustSetting_SportBetTypeSettingSelect(@Cricket,4))
	BEGIN
		SET @IsHidden_Cricket = 0
	END

	IF EXISTS( SELECT 1 FROM dbo.f_CustSetting_SportBetTypeSettingSelect(@VoidBridge,4))
	BEGIN
		SET @IsHidden_VoidBridge = 0
	END
	IF EXISTS( SELECT 1 FROM dbo.f_CustSetting_SportBetTypeSettingSelect(@NG2,11))
	BEGIN
		SET @IsHidden_NG2 = 0
	END

	IF EXISTS (SELECT 1 FROM Customer WITH (NOLOCK) WHERE custid = @SRecommend AND [Site] = 'IMBC')
		SET @IsIMBC = 1
			
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
           isnull(ci.reject, 0) as suspended,
           cu.roleid,
           isnull(cu.firstname, '') as firstname,
           isnull(cu.lastname, '') as lastname,
	       
	       MAX(case when cs.bettype = 1 and cs.sporttype=1 then cs.groupa else 0 end) as groupa,
		   MAX(case when cs.bettype = 1 and cs.sporttype=1 then cs.groupb else 0 end) as groupb,
		   MAX(case when cs.bettype = 1 and cs.sporttype=1 then cs.groupc else 0 end) as groupc,
		   MAX(case when cs.bettype = 1 and cs.sporttype=1 then cs.groupd else 0 end) as groupd,
	       
	       max(case
	             when cs.bettype = 5 and cs.sporttype = 1 then cs.adiscount
	             else 0
	           end) as discount1x2,
	       max(case
	             when cs.bettype = 4 and cs.sporttype = 1 then cs.adiscount
	             else 0
	           end) as discountcs,   
	       max(case
	             when cs3.bettype = 81 and cs3.sporttype = 161 then cs3.adiscount
	             else 0
	           end) as discountnumber,
           cu.creatdate as createdate,
           isnull(cu.iplogin, '') as lastloginip,
	       ci.DoubleCommLosing,
	       isnull(ci.DisableOutright, 0) as DisableOutright,
	       isnull(cm.DisableAutoMPT, 0) as DisableAutoMPT,
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
	       -- For Esports
	       ci.DisableEsports,
      
	       ci.DisableCasinoBonus,
	       ci.DisableHRFixedOdds,
	       -- For Keno
	       ci.HideKeno,
	       MIN(case
	             when g.IBCBetTypeID in (1501, 1503, 1504,
	                                     1505, 1507, 1508,
	                                     1509, 1511, 1513) then cg.IsDisabled
	             else 1
	           end) as DisableKeno,
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
		   ISNULL(ci.HideVoidBridgeUpline,1) AS HideVoidBridgeUpline,		  
		   ISNULL(ci.HideVoidBridge,1) AS HideVoidBridge,
		   ISNULL(ci.SyncedVoidBridge,1) AS SyncedVoidBridge,
		   ISNULL(ci.SyncedVoidBridgeUpline,1) AS SyncedVoidBridgeUpline,
		   ISNULL(ci.SyncedVoidBridgeDownline,1) AS SyncedVoidBridgeDownline,
		   
		   ISNULL(ci.DisableNG2,1) AS DisableNG2,
		   ISNULL(ci.HideNG2Upline,1) AS HideNG2Upline,		  
		   ISNULL(ci.HideNG2,1) AS HideNG2,
		   ISNULL(ci.SyncedNG2,1) AS SyncedNG2,
		   ISNULL(ci.SyncedNG2Upline,1) AS SyncedNG2Upline,
		   ISNULL(ci.SyncedNG2Downline,1) AS SyncedNG2Downline,

		   -- For Myanmar Odds
		   CASE WHEN ac.CustId IS NOT NULL THEN 1 ELSE 0 END AS IsMyanmarOdds,
		   ISNULL(AC.CommRate,0) AS discountMyanmarOdds,
	       --transfer condition
	       @TransferOption disableTransfer,
	       -- Cricket
			ISNULL(@IsIMBC,0) AS IsIMBC,
			ISNULL(ci.DisableCricket,1) AS DisableCricket,
			ISNULL(ci.HideCricket,1) AS HideCricket,
			ISNULL(cdm.Discount,0) AS discountCricket,
			
	       ROW_NUMBER() OVER(ORDER BY ci.enabled desc, ci.closed,
	                                  isnull(ci.reject, 0), cu.username) as RowNumber
				                                  
	FROM dbo.customer AS cu with(NOLOCK)
		INNER JOIN (SELECT c.custid, c.currency, roleid, autosuspend, reject,
						closed, MatchLimit, VirtualMultiplier, Enabled, DisableHorseRacing,
						DisableFinancial, DisableCasino, SyncCasino, DisableOutright, DisableOpenTote,
						DisableBingo, DisableNumber, SyncBingo, disable151_au,
						disable152_uk, disable152_au, disable153_au, isAutoResetP2P,
						DisableP2P, DisableFunP2P, DisableLiveCasino, SyncLiveCasino,
						DisableVirtualSports, DoubleCommLosing, HideVirtualSports,
						DisableCasinoBonus, DisableHRFixedOdds, HideKeno, DisableEsports, DisableGoldDeluxe, HideGoldDeluxe,DisableColossusBet,HideColossusBet,
						-- For MuayThai						
						(SELECT value FROM dbo.f_CustSetting_ProductStatusSel(cps.bitmapIsDisabled, @bitmapOrder_MuayThai)) AS DisableMuayThai,
						CAST(CASE WHEN @IsHidden_MuayThai = 0 AND (SELECT value FROM dbo.f_CustSetting_ProductStatusSel(cps.bitmapIsHidden, @bitmapOrder_MuayThai)) = 0 THEN 0 ELSE 1 END AS BIT) AS HideMuayThai,
						-- For CockFighting						
						(SELECT value FROM dbo.f_CustSetting_ProductStatusSel(cps.bitmapIsDisabled, @bitmapOrder_CockFighting)) AS DisableCockFighting,
						CAST(CASE WHEN @IsHidden_CockFighting = 0 AND (SELECT value FROM dbo.f_CustSetting_ProductStatusSel(cps.bitmapIsHidden, @bitmapOrder_CockFighting)) = 0 THEN 0 ELSE 1 END AS BIT) AS HideCockFighting,

						-- For VoidBridge
						(SELECT value FROM dbo.f_CustSetting_ProductStatusSel(cps.bitmapIsDisabled, @bitmapOrder_VoidBridge)) AS DisableVoidBridge,
						CAST(CASE WHEN @IsHidden_VoidBridge = 0 AND (SELECT value FROM dbo.f_CustSetting_ProductStatusSel(cps.bitmapIsHidden, @bitmapOrder_VoidBridge)) = 0 THEN 0 ELSE 1 END AS BIT) AS HideVoidBridge,
						CAST(CASE WHEN @IsHidden_VoidBridge = 0 AND (SELECT value FROM dbo.f_CustSetting_ProductStatusSel(cpsUpline.bitmapIsHidden, @bitmapOrder_VoidBridge)) = 0 THEN 0 ELSE 1 END AS BIT) AS HideVoidBridgeUpline,						
						(SELECT value FROM dbo.f_CustSetting_ProductStatusSel(cps.bitmapHasSynced, @bitmapOrder_VoidBridge)) AS SyncedVoidBridge,
						(SELECT value FROM dbo.f_CustSetting_ProductStatusSel(cpsUpline.bitmapHasSynced, @bitmapOrder_VoidBridge)) AS SyncedVoidBridgeUpline,
							CASE	WHEN EXISTS	(	SELECT	1
													FROM		dbo.CustProductStatus AS cpsDownline WITH (NOLOCK)
													INNER JOIN	dbo.custInfo AS ciDownline WITH (NOLOCK)
															ON	ciDownline.custid = cpsDownline.CustID
													WHERE	ciDownline.mrecommend = c.custid
														AND	(SELECT value FROM dbo.f_CustSetting_ProductStatusSel(cpsDownline.bitmapHasSynced, @bitmapOrder_VoidBridge))=0)
										THEN 0
									ELSE 1
							END AS SyncedVoidBridgeDownline,
						
						-- For NG2
						(SELECT value FROM dbo.f_CustSetting_ProductStatusSel(cps.bitmapIsDisabled, @bitmapOrder_NG2)) AS DisableNG2,
						CAST(CASE WHEN @IsHidden_NG2 = 0 AND (SELECT value FROM dbo.f_CustSetting_ProductStatusSel(cps.bitmapIsHidden, @bitmapOrder_NG2)) = 0 THEN 0 ELSE 1 END AS BIT) AS HideNG2,
						CAST(CASE WHEN @IsHidden_NG2 = 0 AND (SELECT value FROM dbo.f_CustSetting_ProductStatusSel(cpsUpline.bitmapIsHidden, @bitmapOrder_NG2)) = 0 THEN 0 ELSE 1 END AS BIT) AS HideNG2Upline,
						(SELECT value FROM dbo.f_CustSetting_ProductStatusSel(cps.bitmapHasSynced, @bitmapOrder_NG2)) AS SyncedNG2,
						(SELECT value FROM dbo.f_CustSetting_ProductStatusSel(cpsUpline.bitmapHasSynced, @bitmapOrder_NG2)) AS SyncedNG2Upline,
						CASE	WHEN EXISTS	(	SELECT	1
												FROM		dbo.CustProductStatus AS cpsDownline WITH (NOLOCK)
												INNER JOIN	dbo.custInfo AS ciDownline WITH (NOLOCK)
														ON	ciDownline.custid = cpsDownline.CustID
												WHERE	ciDownline.mrecommend = c.custid
													AND	(SELECT value FROM dbo.f_CustSetting_ProductStatusSel(cpsDownline.bitmapHasSynced, @bitmapOrder_NG2))=0)
									THEN 0
								ELSE 1
						END AS SyncedNG2Downline,

						-- For AllBet
						(SELECT value FROM dbo.f_CustSetting_ProductStatusSel(cps.bitmapIsDisabled, @bitmapOrder_AllBet)) AS DisableAllBet,
							(SELECT value FROM dbo.f_CustSetting_ProductStatusSel(cps.bitmapIsDisabled, @bitmapOrder_AllBetVIP)) AS DisableAllBetVIP,
						CAST(	CASE	WHEN	@IsHidden_AllBet = 0 
											AND	(SELECT value FROM dbo.f_CustSetting_ProductStatusSel(cps.bitmapIsHidden, @bitmapOrder_AllBet)) = 0
											THEN 0
										ELSE 1 
								END AS BIT) AS HideAllBet,
						CAST(	CASE	WHEN	@IsHidden_AllBet = 0 
											AND	(SELECT value FROM dbo.f_CustSetting_ProductStatusSel(cpsUpline.bitmapIsHidden, @bitmapOrder_AllBet)) = 0 
											THEN 0
										ELSE 1 
								END AS BIT) AS HideAllBetUpline,
						
						(SELECT value FROM dbo.f_CustSetting_ProductStatusSel(cps.bitmapHasSynced, @bitmapOrder_AllBet)) AS SyncedAllBet,
						(SELECT value FROM dbo.f_CustSetting_ProductStatusSel(cpsUpline.bitmapHasSynced, @bitmapOrder_AllBet)) AS SyncedAllBetUpline,
						CASE	WHEN EXISTS	(	SELECT	1
												FROM		dbo.CustProductStatus AS cpsDownline WITH (NOLOCK)
												INNER JOIN	dbo.custInfo AS ciDownline WITH (NOLOCK)
														ON	ciDownline.custid = cpsDownline.CustID
												WHERE	ciDownline.mrecommend = c.custid
													AND	(SELECT value FROM dbo.f_CustSetting_ProductStatusSel(cpsDownline.bitmapHasSynced, @bitmapOrder_AllBet)) = 0)
									THEN 0
								ELSE 1
						END AS SyncedAllBetDownline,

						-- For Cricket
						(SELECT value FROM dbo.f_CustSetting_ProductStatusSel(cps.bitmapIsDisabled, @bitmapOrder_Cricket)) AS DisableCricket,
						CAST( CASE WHEN @IsIMBC = 1 AND @IsHidden_Cricket = 0 AND (SELECT value FROM dbo.f_CustSetting_ProductStatusSel(cps.bitmapIsHidden, @bitmapOrder_Cricket)) = 0 THEN 0 ELSE 1 END AS BIT) AS HideCricket

  					  FROM dbo.custinfo c with(NOLOCK)
  						LEFT JOIN CustProductStatus cps WITH (NOLOCK) ON cps.CustID = c.custid  

						-- Check isHidden AllBet
						--OUTER APPLY	dbo.f_CustSetting_SportBetTypeHiddenBySiteCurrency(c.custid, @AllBet) AS sbhsc
		
						-- Upline Status
						INNER JOIN	dbo.CustProductStatus AS cpsUpline WITH (NOLOCK)
								ON	cpsUpline.CustID =	CASE	WHEN c.roleid = 1 THEN c.recommend
																WHEN c.roleid = 2 THEN c.mrecommend
																ELSE c.srecommend
														END
		   
					 WHERE SRecommend = @SRecommend
					   AND roleid = 3
					   AND (@Custid is null or c.Custid = @Custid)
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
				   ) ci on cu.custid = ci.custid
		 LEFT JOIN dbo.CustSetting as cs with(NOLOCK) on cu.custid = cs.custid
		 LEFT JOIN dbo.custsetting3rd cs3 with(nolock) on cu.custid = cs3.custid
		 LEFT JOIN dbo.CustGameType cg WITH(NOLOCK) ON cu.custid = cg.CustID
		 LEFT JOIN @tmp_GameType g ON g.GameTypeID = cg.GameTypeID
													 AND g.IBCBetTypeID IN (1501, 1503, 1504,
																			1505, 1507, 1508,
																			1509, 1511, 1513)
		INNER JOIN dbo.CustMaster cm with(NOLOCK) on cu.custid = cm.custid
		LEFT JOIN AgentCommRate AC WITH (NOLOCK) ON AC.CustId = CI.custid AND AC.Sporttype = 1 AND AC.Bettype = 301 
		LEFT JOIN CustDiscount3rd_Agent cdm WITH (NOLOCK) ON cdm.CustID = ci.custid AND cdm.SportType = 50 AND cdm.BetType = 501 AND @IsIMBC = 1
		
	WHERE ((cs.sporttype IN (1) AND cs.bettype IN (1, 5, 4) AND cs3.sporttype IN (161) AND cs3.bettype IN (81))
				OR (cs.sporttype IS NULL AND cs.bettype IS NULL AND cs3.sporttype IS NULL AND cs3.bettype IS NULL))
			AND (@IsInternalAdmin = 0 OR cu.site NOT IN (SELECT site FROM @tmp ))
	GROUP BY cu.custid, cu.username, ci.enabled, ci.closed, ci.reject, cu.roleid,
			   cu.firstname, cu.lastname, cu.creatdate, cu.iplogin, ci.DoubleCommLosing,
			   ci.DisableOutright, cm.DisableAutoMPT,ci.disablehorseracing,ci.disableOpenTote,
			   ci.disable151_au,ci.disable152_uk,ci.disable152_au, ci.disable153_au,
			   ci.disablehorseracing, ci.disableOpenTote, ci.disable151_au, ci.disable152_uk,
			   ci.disable152_au, ci.disable153_au, ci.synccasino, ci.disablecasino,  
			   ci.syncBingo,ci.DisableBingo, ci.DisableNumber, ci.isAutoResetP2P,
			   ci.DisableP2P, ci.DisableFunP2P, ci.DisableLiveCasino, ci.SyncLiveCasino,
			   ci.DisableVirtualSports,ci.DoubleCommLosing, ci.HideVirtualSports,
			   ci.DisableCasinoBonus, ci.DisableHRFixedOdds, ci.HideKeno, ci.DisableEsports,
			   ci.DisableGoldDeluxe, ci.HideGoldDeluxe,ci.DisableColossusBet,ci.HideColossusBet,AC.CommRate,ac.CustId,ci.DisableMuayThai,ci.HideMuayThai,ci.DisableCockFighting,ci.HideCockFighting,
			   ci.DisableAllBet,ci.DisableAllBetVIP, ci.HideAllBet, ci.SyncedAllBet, ci.SyncedAllBetUpline, ci.SyncedAllBetDownline,
			   ci.DisableCricket, ci.HideCricket, cdm.Discount,
			   ci.DisableVoidBridge,ci.HideVoidBridgeUpline,ci.HideAllBetUpline, ci.HideVoidBridge,ci.SyncedVoidBridge,ci.SyncedVoidBridgeUpline, ci.SyncedVoidBridgeDownline,
			   ci.DisableNG2,ci.HideNG2Upline, ci.HideNG2,ci.SyncedNG2,ci.SyncedNG2Upline, ci.SyncedNG2Downline
	ORDER BY RowNumber
END

GO
GRANT EXECUTE ON [dbo].[EAS_CustomerSelBySAg] TO [bodbExtAccNet] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[EAS_CustomerSelBySAg] TO [vnteam] AS [dbo]
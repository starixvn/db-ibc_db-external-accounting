ALTER PROCEDURE [dbo].[EAS_CustomerSelByAg]
    @Recommend int,  
    @Custid    int = null,  
    @Enabled   bit = null,  
    @Closed    bit = null,  
    @Suspended bit = null 
 
 
AS  
/*  
Created by: Scott  
Date: 2012-12-17  
Task : Customer list by agent
DB: DBCUST.CustDB
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
	
exec EAS_CustomerSelByAg @Recommend=9367272,@Custid=default,@Enabled=default,@Closed=default,@Suspended=default	
*/  
BEGIN    
    SET NOCOUNT ON  

    DECLARE @TransferOption bit
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

	-- For DCS
    DECLARE	@bitmapOrder_MuayThai		INT 
		,	@bitmapOrder_CockFighting	INT
		,	@bitmapOrder_Cricket		INT
		,	@IsIMBC						BIT = 0
		,	@bitmapOrder_AllBet			INT
    
    SET @bitmapOrder_MuayThai = (SELECT bitmapOrder FROM ProductStatusProfile WITH (NOLOCK) WHERE Sporttype = 44 AND Bettype = 3)
    SET @bitmapOrder_CockFighting = (SELECT bitmapOrder FROM ProductStatusProfile WITH (NOLOCK) WHERE Sporttype = 206 AND Bettype = 1003)
    SET @bitmapOrder_Cricket = (SELECT bitmapOrder FROM ProductStatusProfile WITH (NOLOCK) WHERE Sporttype = 50 AND Bettype = 501)
    
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
    
    DECLARE	@SportBook2				INT = 16
		,	@CockFighting			INT = 19
		,	@Cricket				INT = 20
		,	@AllBet					INT = 21
    
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
	
	IF EXISTS (SELECT 1 FROM Customer WITH (NOLOCK) WHERE custid = @Recommend AND [Site] = 'IMBC')
		SET @IsIMBC = 1
			
	
    SELECT custinfo.custid, currency, roleid, autosuspend, reject, closed,
			MatchLimit, VirtualMultiplier, Enabled, DisableHorseRacing,
			DisableFinancial, DisableCasino, SyncCasino, DisableOutright,
			DisableOpenTote, DisableBingo, DisableNumber, SyncBingo,
			disable151_au, disable152_uk, disable152_au, disable153_au,
			isAutoResetP2P, DisableP2P, DisableFunP2P, DisableLiveCasino,
			SyncLiveCasino, DisableVirtualSports, DoubleCommLosing, Recommend,
			HideVirtualSports, DisableCasinoBonus, DisableHRFixedOdds, HideKeno,
			DisableEsports, DisableGoldDeluxe, HideGoldDeluxe,DisableColossusBet, HideColossusBet,

			-- For MuayThai
			ISNULL(dbo.f_GetProductStatus(cps.bitmapIsDisabled, @bitmapOrder_MuayThai),1) AS DisableMuayThai,
			CAST(CASE WHEN @IsHidden_MuayThai = 0 AND ISNULL(dbo.f_GetProductStatus(cps.bitmapIsHidden, @bitmapOrder_MuayThai),1) = 0 THEN 0 ELSE 1 END AS BIT) AS HideMuayThai,
			-- For CockFighting
			ISNULL(dbo.f_GetProductStatus(cps.bitmapIsDisabled, @bitmapOrder_CockFighting),1) AS DisableCockFighting,
			CAST(CASE WHEN @IsHidden_CockFighting = 0 AND ISNULL(dbo.f_GetProductStatus(cps.bitmapIsHidden, @bitmapOrder_CockFighting),1) = 0 THEN 0 ELSE 1 END AS BIT) AS HideCockFighting,
			-- For AllBet
			ISNULL(dbo.f_GetProductStatus(cps.bitmapIsDisabled, @bitmapOrder_AllBet), 1) AS DisableAllBet,
			CAST(CASE WHEN @IsHidden_AllBet = 0 AND ISNULL(dbo.f_GetProductStatus(cps.bitmapIsHidden, @bitmapOrder_AllBet), 1) = 0 THEN 0 ELSE 1 END AS BIT) AS HideAllBet
			
			-- For Cricket
			ISNULL(dbo.f_GetProductStatus(cps.bitmapIsDisabled, @bitmapOrder_Cricket),1) AS DisableCricket,
			CAST( CASE WHEN @IsIMBC = 1 AND @IsHidden_Cricket = 0 AND ISNULL(dbo.f_GetProductStatus(cps.bitmapIsHidden, @bitmapOrder_Cricket),1) = 0 THEN 0 ELSE 1 END AS BIT) AS HideCricket
			
    INTO #custinfo
    FROM dbo.custinfo WITH(NOLOCK)
		LEFT JOIN CustProductStatus cps WITH (NOLOCK) ON cps.CustID = custinfo.custid  
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
		   
		   ISNULL(ci.DisableMuayThai,1) AS DisableMuayThai,
		   ISNULL(ci.HideMuayThai,1) AS HideMuayThai,
		   
		   ISNULL(ci.DisableCockFighting,1) AS DisableCockFighting,
		   ISNULL(ci.HideCockFighting,1) AS HideCockFighting,
		   
		   ISNULL(ci.DisableAllBet,1) AS DisableAllBet,
		   ISNULL(ci.HideAllBet,1) AS HideAllBet,
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
													 AND g.IBCBetTypeID IN (1501, 1503, 1504,
																			1505, 1507, 1508,
																			1509, 1511, 1513)
		 
		LEFT JOIN CustCommRate AC WITH (NOLOCK) ON AC.CustId = CI.custid AND AC.Sporttype = 1 AND AC.Bettype = 301 AND @IsMyanmarOdds = 1		 																			
		LEFT JOIN CustDiscount3rd_Member cdm WITH (NOLOCK) ON cdm.CustID = ci.custid AND cdm.SportType = 50 AND cdm.BetType = 501 AND @IsIMBC = 1
     WHERE (cs.sporttype IN (1) AND cs.bettype IN (1, 5, 4) AND cs3.sporttype IN (161) AND cs3.bettype IN (81))
	    OR (cs.sporttype IS NULL AND cs.bettype IS NULL AND cs3.sporttype IS NULL AND cs3.bettype IS NULL)
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
			   , ci.DisableMuayThai, ci.HideMuayThai,ci.DisableCockFighting,ci.HideCockFighting, ci.DisableAllBet, ci.HideAllBet
			   , ci.HideCricket, ci.DisableCricket, cdm.AgentDiscount, cdm.PlayerDiscount

    DROP TABLE #Custinfo,
               #CustSetting,
               #custsetting3rd
END               
GO
GRANT EXECUTE ON [dbo].[EAS_CustomerSelByAg] TO [bodbExtAccNet] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[EAS_CustomerSelByAg] TO [vnteam] AS [dbo]



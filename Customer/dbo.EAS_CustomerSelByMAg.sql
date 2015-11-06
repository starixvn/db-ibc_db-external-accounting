ALTER PROCEDURE [dbo].[EAS_CustomerSelByMAg] 
    @MRecommend INT
  , @Custid     INT = NULL
  , @Enabled    BIT = NULL
  , @Closed     BIT = NULL
  , @Suspended  BIT = NULL
 
 
AS  
/*  
Created by: Scott  
Date: 2012-12-17  
Task : Customer list by MASTER
DB: DBCUST.CustDB
Original SP: Acc_CustomerSelByMAg
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
    - 20151019@Helen: Display wrong comm rate of Group A,B,C,D [Redmine: #45851]
    - 20151028@Helen: Member Information to support Muay Thai  [Redmine: #45496]

exec EAS_CustomerSelByMAg @MRecommend=4797617,@Custid=default,@Enabled=default,@Closed=default,@Suspended=default    
    
*/
BEGIN
    SET NOCOUNT ON  

    DECLARE @TransferOption BIT
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
	 
    SELECT @TransferOption = CASE
                               WHEN TransferOption = 0 THEN 0
                               ELSE 1
                             END
    FROM dbo.custmaster WITH(NOLOCK)
    WHERE custid = @MRecommend

	 -- For MuayThai
    DECLARE @bitmapOrder INT 
    SET @bitmapOrder = (SELECT bitmapOrder FROM ProductStatusProfile WITH (NOLOCK) WHERE Sporttype = 44 AND Bettype = 3)
	
	DECLARE @HideMuayThai INT = 0
    SET @HideMuayThai = (SELECT TOP 1 SettingStatus FROM ProductSettingDetail WITH (NOLOCK) WHERE sportType =44 AND BetType = 3 AND SettingType = 4)
    
    SELECT cu.custid,
           cu.username,
           ci.enabled,
           ci.closed,
           ISNULL(ci.reject, 0) suspended,
           cu.roleid,
           ISNULL(cu.firstname, '') firstname,
           ISNULL(cu.lastname, '') lastname,
	       
	       MAX(case when cs.bettype = 1 and cs.sporttype=1 then cs.groupa else 0 end) as groupa,
		   MAX(case when cs.bettype = 1 and cs.sporttype=1 then cs.groupb else 0 end) as groupb,
		   MAX(case when cs.bettype = 1 and cs.sporttype=1 then cs.groupc else 0 end) as groupc,
		   MAX(case when cs.bettype = 1 and cs.sporttype=1 then cs.groupd else 0 end) as groupd,
	      
	       MAX(CASE
	             WHEN cs.bettype = 5 and cs.sporttype = 1 THEN cs.discount
	             ELSE 0
	           END) discount1x2,
	       MAX(CASE
	             WHEN cs.bettype = 4 and cs.sporttype = 1 THEN cs.discount
	             ELSE 0
	           END) discountcs,
	       MAX(CASE
	             WHEN cs3.bettype = 81 and cs3.sporttype = 161 THEN cs3.discount
	             ELSE 0
	           END) discountnumber,
	       cu.creatdate createdate,
	       ISNULL(cu.iplogin, '') lastloginip,
	       ci.DoubleCommLosing,
	       ISNULL(ci.DisableOutright, 0) DisableOutright,
	       ISNULL(CASE
	                WHEN ci.disablehorseracing = 0 OR ci.disableOpenTote = 0
	                  OR ci.disable151_au = 0 OR ci.disable152_uk = 0
					  OR ci.disable152_au = 0 OR ci.disable153_au = 0 THEN 0
					ELSE 1
				  END ,0) Disable151,
	       ISNULL(ci.disablehorseracing, 0) disable151_31,
	       ISNULL(ci.disableOpenTote, 0) disable151_41,
	       ISNULL(ci.disable151_au, 0) disable151_51,
	       ISNULL(ci.disable152_uk, 0) disable152_41,
	       ISNULL(ci.disable152_au, 0) disable152_51,
	       ISNULL(ci.disable153_au, 0) disable153_51,
	       -- FOR casino
	       ci.synccasino,
	       ci.disablecasino,
	       ci.syncBingo,
	       ci.DisableBingo,
	       ci.DisableNumber,
	       --FOR P2P
	       ci.isAutoResetP2P,
	       ci.DisableP2P,
	       ci.DisableFunP2P,
	       -- FOR live casino
	       ci.DisableLiveCasino,
	       ci.SyncLiveCasino,
	       -- FOR VirtualSports
	       ci.DisableVirtualSports,
	       ci.DoubleCommLosing,
	       ci.HideVirtualSports,
	       -- FOR Esports
	       ci.DisableEsports,

           ci.DisableCasinoBonus,
           ci.DisableHRFixedOdds,
           -- FOR Keno
           ci.HideKeno,
           MIN(CASE
	             WHEN g.IBCBetTypeID in (1501, 1503, 1504,
	                                     1505, 1507, 1508,
	                                     1509, 1511, 1513) THEN cg.IsDisabled
	             ELSE 1
	           END) DisableKeno,
	       ISNULL(ci.DisableGoldDeluxe,1) AS DisableGoldDeluxe,
		   ISNULL(ci.HideGoldDeluxe,1) AS HideGoldDeluxe,
		   
		   ISNULL(ci.DisableColossusBet,1) AS DisableColossusBet,
		   ISNULL(ci.HideColossusBet,1) AS HideColossusBet,
		   
		   ISNULL(ci.DisableMuayThai,0) AS DisableMuayThai,
		   ISNULL(ci.HideMuayThai,0) AS HideMuayThai,
		   
		   --For Myanmar Odds
		   CASE WHEN ac.CustId IS NOT NULL THEN 1 ELSE 0 END AS  IsMyanmarOdds,
		   ISNULL(AC.CommRate,0) AS discountMyanmarOdds,
	       --transfer condition
	       @TransferOption disableTransfer,
	       ROW_NUMBER() OVER(ORDER BY ci.enabled desc, ci.closed,
	                                  ISNULL(ci.reject, 0), cu.username) RowNumber
      FROM dbo.customer cu WITH(NOLOCK)
		INNER JOIN (SELECT custinfo.custid, currency, roleid, autosuspend, reject, closed,
						   MatchLimit, VirtualMultiplier, Enabled, DisableHorseRacing,
						   DisableFinancial, DisableCasino, SyncCasino, DisableOutright,
						   DisableOpenTote, DisableBingo, DisableNumber, SyncBingo,
						   disable151_au, disable152_uk, disable152_au, disable153_au,
						   isAutoResetP2P, DisableP2P, DisableFunP2P, DisableLiveCasino,
						   SyncLiveCasino, DisableVirtualSports, DoubleCommLosing,
						   HideVirtualSports, DisableCasinoBonus, DisableHRFixedOdds,
						   HideKeno, DisableEsports, DisableGoldDeluxe, HideGoldDeluxe, DisableColossusBet,HideColossusBet
						   -- For MuayThai
						   ,dbo.f_GetProductStatus(cps.bitmapIsDisabled, @bitmapOrder)  AS DisableMuayThai
						   
						   ,CAST(CASE WHEN @HideMuayThai = 0 AND ISNULL(dbo.f_GetProductStatus(cps.bitmapIsHidden, @bitmapOrder),1) = 0 THEN 0 ELSE 1 END AS BIT) AS HideMuayThai
						   
					  FROM dbo.custinfo WITH(NOLOCK) 						
					  LEFT JOIN CustProductStatus cps WITH (NOLOCK) ON cps.CustID = custinfo.custid  
					 WHERE mRecommend = @MRecommend
					   AND roleid = 2
					   AND (@Custid IS NULL OR custinfo.Custid = @Custid)
					   AND enabled = CASE
									   WHEN COALESCE(@Closed, @Suspended) IS NOT NULL THEN 1
									   ELSE COALESCE(@enabled, enabled)
									 END
					   AND ISNULL(closed, 0) = CASE
												 WHEN @suspended = 1 THEN 0
												 ELSE COALESCE(@closed, ISNULL(closed, 0))
											   END
					   AND ISNULL(reject, 0) = CASE
												 WHEN @Closed = 0 THEN 0
												 ELSE COALESCE(@suspended, ISNULL(reject, 0))
											   END
				   ) ci ON cu.custid = ci.custid
		 LEFT JOIN dbo.CustSetting cs WITH(NOLOCK) ON cu.custid = cs.custid
		 LEFT JOIN dbo.custsetting3rd cs3 WITH(NOLOCK) ON cu.custid = cs3.custid
		 LEFT JOIN dbo.CustGameType cg WITH(NOLOCK) ON cu.custid = cg.CustID
		 LEFT JOIN @tmp_GameType g ON g.GameTypeID = cg.GameTypeID
													 AND g.IBCBetTypeID IN (1501, 1503, 1504,
																			1505, 1507, 1508,
																			1509, 1511, 1513)
		INNER JOIN dbo.Custagent cm with(NOLOCK) ON cu.custid = cm.custid  
		LEFT JOIN AgentCommRate AC WITH (NOLOCK) ON AC.CustId = CI.custid AND AC.Sporttype = 1 AND AC.Bettype = 301 
     WHERE (cs.sporttype IN (1) AND cs.bettype IN (1, 5, 4) AND cs3.sporttype IN (161) AND cs3.bettype IN (81))
	    OR (cs.sporttype IS NULL AND cs.bettype IS NULL AND cs3.sporttype IS NULL AND cs3.bettype IS NULL)
	  GROUP BY cu.custid, cu.username, ci.enabled,ci.closed,ci.reject,cu.roleid,
			cu.firstname, cu.lastname,
			cu.creatdate ,cu.iplogin,ci.DoubleCommLosing,ci.DisableOutright,  
			ci.disablehorseracing,ci.disableOpenTote,ci.disable151_au,ci.disable152_uk,ci.disable152_au,
			ci.disable153_au,ci.disablehorseracing,ci.disableOpenTote,ci.disable151_au,ci.disable152_uk,
			ci.disable152_au,ci.disable153_au,
			ci.synccasino,ci.disablecasino,  
			ci.syncBingo,ci.DisableBingo, ci.DisableNumber,  
			ci.isAutoResetP2P, ci.DisableP2P, ci.DisableFunP2P,  
			ci.DisableLiveCasino, ci.SyncLiveCasino,  
			ci.DisableVirtualSports,ci.DoubleCommLosing, ci.HideVirtualSports,	
			ci.DisableCasinoBonus, ci.DisableHRFixedOdds, ci.HideKeno, ci.DisableEsports,
			ci.DisableGoldDeluxe, ci.HideGoldDeluxe, ci.DisableColossusBet, ci.HideColossusBet,AC.CommRate,ac.CustId,ci.DisableMuayThai,ci.HideMuayThai
END
GO
GRANT EXECUTE ON [dbo].[EAS_CustomerSelByMAg] TO [bodbExtAccNet] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[EAS_CustomerSelByMAg] TO [vnteam] AS [dbo]
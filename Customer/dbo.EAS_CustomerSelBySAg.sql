USE [CustDB]
GO
/****** Object:  StoredProcedure [dbo].[EAS_CustomerSelBySAg]    Script Date: 06/12/2015 11:09:56 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/****** Object:  Stored Procedure dbo.EAS_CustomerSelBySAg    Script Date: 9/11/2014 9:52:04 AM ******/

ALTER PROCEDURE [dbo].[EAS_CustomerSelBySAg]  
    @SRecommend int,  
    @Custid     int = null,  
    @Enabled    bit = null,  
    @Closed     bit = null,  
    @Suspended  bit = null 
 
 
AS  
/*  
Created by: Scott  
Date: 2012-12-17  
Task : Customer list by super
DB: DBCUST.CustDB
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

*/
BEGIN
    SET NOCOUNT ON  

    DECLARE @TransferOption bit

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
                             end
     FROM dbo.custsuper WITH(NOLOCK)
     WHERE custid = @SRecommend

    SELECT cu.custid,
           cu.username,
           ci.enabled,
           ci.closed,
           isnull(ci.reject, 0) as suspended,
           cu.roleid,
           isnull(cu.firstname, '') as firstname,
           isnull(cu.lastname, '') as lastname,
	       max(cs.groupa) as groupa,
	       max(cs.groupb) as groupb,
	       max(cs.groupc) as groupc,
	       max(cs.groupd) as groupd,
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
		   
	       --transfer condition
	       @TransferOption disableTransfer,
	       ROW_NUMBER() OVER(ORDER BY ci.enabled desc, ci.closed,
	                                  isnull(ci.reject, 0), cu.username) as RowNumber
	FROM dbo.customer AS cu with(NOLOCK)
		INNER JOIN (SELECT custinfo.custid, currency, roleid, autosuspend, reject,
						   closed, MatchLimit, VirtualMultiplier, Enabled, DisableHorseRacing,
						   DisableFinancial, DisableCasino, SyncCasino, DisableOutright, DisableOpenTote,
						   DisableBingo, DisableNumber, SyncBingo, disable151_au,
						   disable152_uk, disable152_au, disable153_au, isAutoResetP2P,
						   DisableP2P, DisableFunP2P, DisableLiveCasino, SyncLiveCasino,
						   DisableVirtualSports, DoubleCommLosing, HideVirtualSports,
						   DisableCasinoBonus, DisableHRFixedOdds, HideKeno, DisableEsports, DisableGoldDeluxe, HideGoldDeluxe,DisableColossusBet,HideColossusBet
  					  FROM dbo.custinfo with(NOLOCK) 
					 WHERE SRecommend = @SRecommend
					   AND roleid = 3
					   AND (@Custid is null or Custid = @Custid)
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
	WHERE (cs.sporttype IN (1) AND cs.bettype IN (1, 5, 4) AND cs3.sporttype IN (161) AND cs3.bettype IN (81))
			OR (cs.sporttype IS NULL AND cs.bettype IS NULL AND cs3.sporttype IS NULL AND cs3.bettype IS NULL)
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
			   ci.DisableGoldDeluxe, ci.HideGoldDeluxe,ci.DisableColossusBet,ci.HideColossusBet
	
END

GO
GRANT EXECUTE ON [dbo].[EAS_CustomerSelBySAg] TO [bodbExtAccNet] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[EAS_CustomerSelBySAg] TO [vnteam] AS [dbo]
USE [bodb_EAS]
GO

/****** Object:  StoredProcedure [dbo].[EAS_CustomerSelByCom]    Script Date: 06/26/2014 17:06:59 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

ALTER PROCEDURE [dbo].[EAS_CustomerSelByCom]  
    @GroupName VARCHAR(50) = 'ACCTHAI',
    @Custid    int = null,
    @Enabled   bit = null,
    @Closed    bit = null,
    @Suspended bit = null
 
AS  

/*  
Created by: Scott  
Date: 2012-12-17  
Task : Customer list by company
DB: DBEAS/bodb_EAS
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
*/
BEGIN
    SET NOCOUNT ON

    DECLARE @tmpSuperList TABLE( custID INT, username VARCHAR(30))

    INSERT INTO @tmpSuperList(CustID, username)
    SELECT custID, username 
      FROM bodb02.dbo.custinfo WITH(NOLOCK)
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

    --------output
    SELECT cu.custid,
           cu.username,
           ci.enabled,
           ci.closed,
           ISNULL(ci.reject, 0) as suspended,
           cu.roleid,
           ISNULL(cu.firstname, '') as firstname,
           ISNULL(cu.lastname, '') as lastname,
	       MAX(cs.groupa) as groupa,
	       MAX(cs.groupb) as groupb,
	       MAX(cs.groupc) as groupc,
	       MAX(cs.groupd) as groupd,
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
	       ROW_NUMBER() OVER(ORDER BY ci.enabled desc, ci.closed,
	                                  ISNULL(ci.reject,0), cu.username) as RowNumber
      FROM bodb02.dbo.customer cu with(nolock)
INNER JOIN @tmpSuperList sl on sl.custid = cu.custid
INNER JOIN bodb02.dbo.custinfo ci with(nolock) on ci.custid = cu.custid
 LEFT JOIN bodb02.dbo.CustSetting as cs with(NOLOCK) on cu.custid = cs.custid
 LEFT JOIN bodb02.dbo.custsetting3rd cs3 with(nolock) on cu.custid = cs3.custid
 LEFT JOIN bodb02.dbo.CustGameType cg WITH(NOLOCK) ON cu.custid = cg.CustID
 LEFT JOIN bodb02.dbo.GameType g WITH(NOLOCK) ON g.GameTypeID = cg.GameTypeID
                                             AND g.IBCBetTypeID IN (1501, 1503, 1504,
                                                                    1505, 1507, 1508,
                                                                    1509, 1511, 1513)
     WHERE (cs.sporttype IN (1) AND cs.bettype IN (1,5,4) AND cs3.sporttype IN (161) AND cs3.bettype IN (81))
	    OR (cs.sporttype IS NULL AND cs.bettype IS NULL AND cs3.sporttype IS NULL AND cs3.bettype IS NULL)
  GROUP BY cu.custid, cu.username, ci.enabled, ci.closed, ci.reject, cu.roleid,
           cu.firstname, cu.lastname, cu.creatdate, cu.iplogin,	ci.DisableOutright,
	       ci.disablehorseracing, ci.disableOpenTote, ci.disable151_au, ci.disable152_uk,
	       ci.disable152_au, ci.disable153_au, ci.disablehorseracing, ci.disableOpenTote,
	       ci.disable151_au, ci.disable152_uk, ci.disable152_au, ci.disable153_au,
	       ci.synccasino, ci.disablecasino, ci.syncBingo, ci.DisableBingo, ci.DisableNumber,
	       ci.isAutoResetP2P, ci.DisableP2P, ci.DisableFunP2P, ci.DisableLiveCasino,
	       ci.SyncLiveCasino, ci.DisableVirtualSports, ci.DoubleCommLosing, ci.HideVirtualSports,
	       ci.DisableCasinoBonus, ci.DisableHRFixedOdds, ci.HideKeno, ci.DisableEsports
END
GO



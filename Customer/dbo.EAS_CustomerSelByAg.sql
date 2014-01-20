ALTER PROCEDURE [dbo].[EAS_CustomerSelByAg]
 @Recommend int,  
 @Custid int=null,  
 @Enabled bit = null,  
 @Closed bit=null,  
 @Suspended bit=null 
 
 
AS  
/*  
Created by: Scott  
Date: 2012-12-17  
Task : Customer list by agent
DB: DBEAS/bodb_EAS
Original SP: Acc_CustomerSelByAg
Revisions:  
	- 20130121@Dan: Move sp from DB053/bodb02 to DBEAS/bodb_EAS
	- 20130517@Lukas: 
			fix bug - wrong comm rate 
			add filter to reduce workload
	- 20131023@Elodie: Get more field HideVirtualSports, DisableCasinoBonus, DisableHRFixedOdds			
	- 20140120@Elodie: Hot fix to get information of disabled customer
*/  
SET NOCOUNT ON  

DECLARE @TransferOption bit

SELECT @TransferOption = case when TransferOption = 0 then 0 else 1 end
FROM bodb02.dbo.custagent with(nolock)
WHERE custid = @Recommend

--temp custinfo
SELECT custinfo.custid, currency, roleid, autosuspend, reject, closed, MatchLimit, VirtualMultiplier, Enabled, DisableHorseRacing,  
		DisableFinancial, DisableCasino, SyncCasino, DisableOutright, DisableOpenTote, DisableBingo, DisableNumber, SyncBingo,  
		disable151_au, disable152_uk, disable152_au, disable153_au , isAutoResetP2P, DisableP2P, DisableFunP2P,   
		DisableLiveCasino,SyncLiveCasino, DisableVirtualSports, DoubleCommLosing, Recommend, HideVirtualSports, DisableCasinoBonus, DisableHRFixedOdds     
INTO #custinfo		
FROM bodb02.dbo.custinfo WITH (NOLOCK) 						
WHERE Recommend = @Recommend AND roleid=1 and 
	(@custid is null or custid=@custid) AND
	enabled = case when coalesce(@Closed,@Suspended) is not null then 1 else coalesce(@enabled, enabled) end  AND 
	isnull(closed,0) = case when @suspended = 1 then 0 else coalesce(@closed, isnull(closed, 0)) end AND 
	isnull(reject,0) = case when @Closed = 0 then 0 else coalesce(@suspended, isnull(reject, 0))end

--temp custsetting
SELECT cs.custid,bettype, sporttype, discount,playerdiscount
INTO #CustSetting
FROM bodb02.dbo.custsetting cs WITH(NOLOCK)
	inner join #custinfo ci on cs.custid = ci.custid
WHERE bettype in (1,4,5) and sporttype = 1	

--temp custsetting3rd
SELECT cs3.custid, bettype, sporttype,discount,playerdiscount
INTO #custsetting3rd
FROM bodb02.dbo.custsetting3rd cs3 WITH(NOLOCK)
	inner join #custinfo ci on cs3.custid = ci.custid	
WHERE bettype = 81 and sporttype = 161	


SELECT cu.custid,cu.username,isnull(cu.username2,'') NickName, ci.enabled,ci.closed,isnull(ci.reject,0) as suspended,cu.roleid,isnull(cu.firstname, '') as firstname, isnull(cu.lastname, '') as lastname,	cu.ugroup,
	--agent commission
	max(case when cs.bettype = 1 and cs.sporttype=1 then cs.discount else 0 end) as discount,    
	max(case when cs.bettype = 4 and cs.sporttype=1 then cs.discount else 0 end) as discountcs,    
	max(case when cs.bettype = 5 and cs.sporttype=1 then cs.discount else 0 end) as discount1x2, 
	max(case when cs3.bettype = 81 and cs3.sporttype=161 then cs3.discount else 0 end) as discountnumber,
   	--player commission
	max(case when cs.bettype = 1 and cs.sporttype=1 then cs.playerdiscount else 0 end) as playerdiscount,    
	max(case when cs.bettype = 4 and cs.sporttype=1 then cs.playerdiscount else 0 end) as playerdiscountcs,    
	max(case when cs.bettype = 5 and cs.sporttype=1 then cs.playerdiscount else 0 end) as playerdiscount1x2, 
	max(case when cs3.bettype = 81 and cs3.sporttype=161 then cs3.playerdiscount else 0 end) as playerdiscountnumber,	
	cu.creatdate as createdate,isnull(cu.iplogin, '') as lastloginip,
	ci.DoubleCommLosing,isnull(ci.DisableOutright,0) as DisableOutright,  
	isnull( case when ci.disablehorseracing = 0 or ci.disableOpenTote = 0 or ci.disable151_au = 0 or ci.disable152_uk = 0 or ci.disable152_au = 0 or ci.disable153_au = 0 then 0 else 1 end ,0) as Disable151,  
	isnull(ci.disablehorseracing,0) as disable151_31, isnull(ci.disableOpenTote,0) as disable151_41, isnull(ci.disable151_au,0) as disable151_51,  
	isnull(ci.disable152_uk,0) as disable152_41, isnull(ci.disable152_au,0) as disable152_51, isnull(ci.disable153_au,0) as disable153_51,  
	-- For casino  
	ci.synccasino,ci.disablecasino,  
	ci.syncBingo,ci.DisableBingo, ci.DisableNumber,  
	--For P2P  
	ci.isAutoResetP2P, ci.DisableP2P, ci.DisableFunP2P,  
	-- For live casino  
	ci.DisableLiveCasino, ci.SyncLiveCasino,  
	-- For VirtualSports  
	ci.DisableVirtualSports,ci.DoubleCommLosing,  
	ci.HideVirtualSports,
	
	ci.DisableCasinoBonus,
	ci.DisableHRFixedOdds,
	--transfer condition
	@TransferOption disableTransfer,	
	ROW_NUMBER() OVER (ORDER BY ci.enabled desc, ci.closed, isnull(ci.reject,0), cu.username) as RowNumber   
FROM   bodb02.dbo.customer AS cu with (NOLOCK)  
	INNER JOIN #Custinfo ci with(nolock)	on cu.custid = ci.custid 			  
	LEFT JOIN #CustSetting as cs with (NOLOCK) on cu.custid = cs.custid  
	LEFT JOIN #custsetting3rd cs3 with(nolock) on cu.custid = cs3.custid
WHERE (cs.sporttype IN (1) AND cs.bettype IN (1,5,4) AND cs3.sporttype IN (161) AND cs3.bettype IN (81))
	OR (cs.sporttype IS NULL AND cs.bettype IS NULL AND cs3.sporttype IS NULL AND cs3.bettype IS NULL)
GROUP BY cu.custid,cu.username,cu.username2,cu.ugroup, ci.enabled,ci.closed,ci.reject,cu.roleid,
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
		ci.DisableCasinoBonus, ci.DisableHRFixedOdds

drop table #Custinfo,#CustSetting,#custsetting3rd

GO
GRANT EXECUTE ON [dbo].[EAS_CustomerSelByAg] TO [bodbExtAccNet] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[EAS_CustomerSelByAg] TO [vnteam] AS [dbo]
ALTER PROCEDURE [dbo].[EAS_CustomerSelByMAg] 
 @MRecommend int,  
 @Custid int=null,  
 @Enabled bit = null,  
 @Closed bit=null,  
 @Suspended bit=null 
 
 
AS  
/*  
Created by: Scott  
Date: 2012-12-17  
Task : Customer list by MASTER
DB: DBEAS/bodb_EAS
Original SP: Acc_CustomerSelByMAg
Revisions:  
	- 20130121@Dan: Move sp from DB053/bodb02 to DBEAS/bodb_EAS
*/  
SET NOCOUNT ON  

DECLARE @TransferOption bit

SELECT @TransferOption = case when TransferOption = 0 then 0 else 1 end
FROM bodb02.dbo.custmaster with(nolock)
WHERE custid = @MRecommend

SELECT cu.custid,cu.username, ci.enabled,ci.closed,isnull(ci.reject,0) as suspended,cu.roleid,isnull(cu.firstname, '') as firstname, isnull(cu.lastname, '') as lastname,
	max(cs.groupa) as groupa, max(cs.groupb) as groupb, max(cs.groupc) as groupc, max(cs.groupd) as groupd, 
	max(case when cs.bettype = 5 and cs.sporttype=1 then cs.adiscount else 0 end) as discount1x2,   
	max(case when cs.bettype = 4 and cs.sporttype=1 then cs.adiscount else 0 end) as discountcs,   
	max(case when cs3.bettype = 81 and cs3.sporttype=161 then cs3.adiscount else 0 end) as discountnumber,
	cu.creatdate as createdate,isnull(cu.iplogin, '') as lastloginip,
	ci.DoubleCommLosing,isnull(ci.DisableOutright,0) as DisableOutright,  
	isnull( case when ci.disablehorseracing = 0 or ci.disableOpenTote = 0 or ci.disable151_au = 0 or ci.disable152_uk = 0  
					or ci.disable152_au = 0 or ci.disable153_au = 0 then 0 else 1 end ,0) as Disable151,  
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
	--transfer condition
	@TransferOption disableTransfer,
	ROW_NUMBER() OVER (ORDER BY ci.enabled desc, ci.closed, isnull(ci.reject,0), cu.username) as RowNumber   
FROM   bodb02.dbo.customer AS cu with (NOLOCK)  
	INNER JOIN (SELECT custinfo.custid, currency, roleid, autosuspend, reject, closed, MatchLimit, VirtualMultiplier, Enabled, DisableHorseRacing,  
					DisableFinancial, DisableCasino, SyncCasino, DisableOutright, DisableOpenTote, DisableBingo, DisableNumber, SyncBingo,  
					disable151_au, disable152_uk, disable152_au, disable153_au , isAutoResetP2P, DisableP2P, DisableFunP2P,   
					DisableLiveCasino,SyncLiveCasino, DisableVirtualSports, DoubleCommLosing    
				FROM bodb02.dbo.custinfo with (NOLOCK) 						
				WHERE mRecommend = @MRecommend AND roleid=2 and 
					(@Custid is null or Custid=@Custid) AND
					enabled = case when coalesce(@Closed,@Suspended) is not null then 1 else coalesce(@enabled, enabled) end  AND 
					isnull(closed,0) = case when @suspended = 1 then 0 else coalesce(@closed, isnull(closed, 0)) end AND 
					isnull(reject,0) = case when @Closed = 0 then 0 else coalesce(@suspended, isnull(reject, 0))end
				) ci on cu.custid = ci.custid     
	INNER JOIN bodb02.dbo.CustSetting as cs with (NOLOCK) on cu.custid = cs.custid  
	INNER JOIN bodb02.dbo.custsetting3rd cs3 with(nolock) on cu.custid = cs3.custid  
	INNER JOIN bodb02.dbo.Custagent cm with(NOLOCK) on cu.custid = cm.custid   
group by cu.custid,cu.username, ci.enabled,ci.closed,ci.reject,cu.roleid,
		cu.firstname, cu.lastname,
		cu.creatdate ,cu.iplogin,ci.DoubleCommLosing,ci.DisableOutright,  
		ci.disablehorseracing,ci.disableOpenTote,ci.disable151_au,ci.disable152_uk,ci.disable152_au,
		ci.disable153_au,ci.disablehorseracing,ci.disableOpenTote,ci.disable151_au,ci.disable152_uk,
		ci.disable152_au,ci.disable153_au,
		ci.synccasino,ci.disablecasino,  
		ci.syncBingo,ci.DisableBingo, ci.DisableNumber,  
		ci.isAutoResetP2P, ci.DisableP2P, ci.DisableFunP2P,  
		ci.DisableLiveCasino, ci.SyncLiveCasino,  
		ci.DisableVirtualSports,ci.DoubleCommLosing

GO
GRANT EXECUTE ON [dbo].[EAS_CustomerSelByMAg] TO [bodbExtAccNet]
GO
GRANT VIEW DEFINITION ON [dbo].[EAS_CustomerSelByMAg] TO [vnteam]
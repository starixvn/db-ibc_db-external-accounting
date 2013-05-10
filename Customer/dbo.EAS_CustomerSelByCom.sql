ALTER PROCEDURE [dbo].[EAS_CustomerSelByCom]  
 @GroupName VARCHAR(50) = 'ACCTHAI' , 
 @Custid int=null,  
 @Enabled bit = null,  
 @Closed bit=null,  
 @Suspended bit=null  
 
AS  

/*  
Created by: Scott  
Date: 2012-12-17  
Task : Customer list by company
DB: DBEAS/bodb_EAS
Original SP: Acc_CustomerSelBySAg
Revisions:  
	- 20130121@Dan: Move sp from DB053/bodb02 to DBEAS/bodb_EAS, call to bodb_AGE for Acc_CustGroup
*/  

SET NOCOUNT ON

DECLARE @tmpSuperList TABLE( custID INT, username VARCHAR(30))

INSERT INTO @tmpSuperList(CustID, username)
SELECT custID,username 
FROM bodb02.dbo.custinfo (NOLOCK)
WHERE	custid in (SELECT custid from bodb_AGE.dbo.Acc_CustGroup WITH(nolock) WHERE GroupName = @GroupName) AND 
		(@Custid IS NULL OR custid=@Custid)	and
		roleid = 4 and
		enabled = case when coalesce(@Closed,@Suspended) is not null then 1 else coalesce(@enabled, enabled) end  AND 
		isnull(closed,0) = case when @suspended = 1 then 0 else coalesce(@closed, isnull(closed, 0)) end AND 
		isnull(reject,0) = case when @Closed = 0 then 0 else coalesce(@suspended, isnull(reject, 0))end

--------output

SELECT cu.custid,cu.username, ci.enabled,ci.closed,isnull(ci.reject,0) as suspended,cu.roleid, 
	isnull(cu.firstname, '') as firstname, isnull(cu.lastname, '') as lastname,
	max(cs.groupa) as groupa,   
	max(cs.groupb) as groupb,   
	max(cs.groupc) as groupc,   
	max(cs.groupd) as groupd, 
	max(case when cs.bettype = 5 and cs.sporttype=1 then cs.adiscount else 0 end) as discount1x2,   
	max(case when cs.bettype = 4 and cs.sporttype=1 then cs.adiscount else 0 end) as discountcs,   
    max(case when cs3.bettype = 81 and cs3.sporttype=161 then cs3.adiscount else 0 end) as discountnumber,
	cu.creatdate as createdate,isnull(cu.iplogin, '') as lastloginip,
	ci.DoubleCommLosing, 
	isnull(ci.DisableOutright,0) as DisableOutright,  	
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
	ci.DisableVirtualSports,
	
	ROW_NUMBER() OVER (ORDER BY ci.enabled desc, ci.closed, isnull(ci.reject,0), cu.username) as RowNumber   
	
FROM bodb02.dbo.customer cu with(nolock)
	INNER JOIN @tmpSuperList sl on sl.custid = cu.custid
	INNER JOIN bodb02.dbo.custinfo ci with(nolock) on ci.custid = cu.custid
	INNER JOIN bodb02.dbo.CustSetting as cs with (NOLOCK) on cu.custid = cs.custid 
	INNER JOIN bodb02.dbo.custsetting3rd cs3 with(nolock) on cu.custid = cs3.custid  
	
GROUP BY  cu.custid,cu.username, ci.enabled,ci.closed,ci.reject,cu.roleid, 
	cu.firstname, cu.lastname,cu.creatdate ,cu.iplogin,	ci.DisableOutright,  
	ci.disablehorseracing,ci.disableOpenTote,ci.disable151_au,ci.disable152_uk,ci.disable152_au,
	ci.disable153_au,ci.disablehorseracing,ci.disableOpenTote,ci.disable151_au,ci.disable152_uk,
	ci.disable152_au,ci.disable153_au,
	ci.synccasino,ci.disablecasino,  
	ci.syncBingo,ci.DisableBingo, ci.DisableNumber,  
	ci.isAutoResetP2P, ci.DisableP2P, ci.DisableFunP2P,  
	ci.DisableLiveCasino, ci.SyncLiveCasino,  
	ci.DisableVirtualSports,ci.DoubleCommLosing
	
GO
GRANT EXECUTE ON [dbo].[EAS_CustomerSelByCom] TO [bodbExtAccNet]
GO
GRANT VIEW DEFINITION ON [dbo].[EAS_CustomerSelByCom] TO [vnteam]
ALTER PROCEDURE [dbo].[EAS_CustomerSelUserInfo]  
	@custid	int = 0,
	@username varchar(30),
	@IsGetUplineInfo BIT = 0,
	@GroupName	VARCHAR(50)
AS  
/*
Created By: Dan
Created Date: 2012-11-15
Task : Get User Information and their upline info
DB: DBEAS/bodb_EAS
Original:Accounting site

Revisions:
	- 20130121@Dan: Move sp from DB053/bodb02 to DBEAS/bodb_EAS, change linked server DB06 to DBACC, call to bodb_AGE for Acc_CustGroup
	
*/	
SET NOCOUNT ON  
DECLARE @srecommend INT, 
		@mrecommend INT,
		@recommend INT,
		
		@roleID TINYINT,		
		@SuperName NVARCHAR(50),
		@MasterName NVARCHAR(50),
		@AgentName NVARCHAR(50)		 		

IF (ISNULL(@custid,0)=0)
BEGIN
	--Get CustID from DB06, where got index on Username and Username2
	EXEC @custid = DBACC.bodb02.dbo.f_GetCustIDFromUsername @username
	IF @custid is NULL
		RETURN
END	

SELECT  @username = username, @roleID=roleID, 
	@srecommend=srecommend, @mrecommend=mrecommend,@recommend=recommend
FROM bodb02.dbo.custinfo WITH (NOLOCK) 
WHERE custid = @custid

-- check belong to group 
IF NOT EXISTS (SELECT 1 FROM bodb_AGE.dbo.Acc_CustGroup (NOLOCK) WHERE CustID = @srecommend AND GroupName = @GroupName)
BEGIN
	RETURN
END

IF (@IsGetUplineInfo=1)
BEGIN
	SELECT  @SuperName = case when roleid=4 then username else @SuperName end,
			@MasterName = case when roleid=3 then username else @MasterName end,
			@AgentName = case when roleid=2 then username else @AgentName end
	FROM bodb02.dbo.custinfo WITH (NOLOCK) 
	WHERE custid IN (@srecommend, @mrecommend, @recommend)
END

SELECT @custid AS custid, @username AS username, @roleID AS roleID, 
	@srecommend AS srecommend, @mrecommend AS mrecommend, @recommend AS recommend,
	@SuperName AS SuperName, @MasterName AS MasterName, @AgentName AS AgentName

GO
GRANT EXECUTE ON [dbo].[EAS_CustomerSelUserInfo]   TO [bodbExtAccNet]
GO
GRANT VIEW DEFINITION ON [dbo].[EAS_CustomerSelUserInfo]   TO [vnteam]
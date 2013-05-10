ALTER PROCEDURE [dbo].[EAS_GroupPolicyUpd]
	@userID				INT,
	@GroupID			INT,
	@OldGroupPolicy		VARCHAR(4000) = '',
	@GroupPolicy		VARCHAR(4000) = '',
	@IP					VARCHAR(50),
	@ErrCode			INT = 0 OUTPUT,
	@ErrMsg				VARCHAR(500) = '' OUTPUT
AS
	/*
		Created: Dan
		Date: 2012-11-19
		Task: grant permission to group
		DB: DBEAS/bodb_EAS
		
		Revisions:
			
		Parameter's Explanation:
			- @Policy: contains ID's function changed and new policy 
					ex: '7,1;8,2;4,0'
	*/
SET NOCOUNT ON  

	DECLARE @startRun datetime  
		,@endRun datetime  
		,@duration int		
	
	SET @startRun=GETDATE()
	
	EXEC dbo.EAS_UserCheckPermission @UserID = @userID ,@FuncKey = 'ManageGroup', @ErrCode = @ErrCode OUTPUT, @ErrMsg = @ErrMsg OUTPUT
	
	IF @ErrCode > 0
		RETURN
	
	DECLARE @Func TABLE (FuncID INT, Policy INT)
	
	INSERT INTO @Func (funcid, policy)
		SELECT funcid,policy
		FROM dbo.f_EAS_PolicySplit (@GroupPolicy,';',',')
		
	UPDATE gp
	SET gp.Policy = t.Policy
	FROM eaGroupPolicy gp 
		INNER JOIN @Func t ON gp.groupid = @groupid AND gp.funcid = t.funcid
	
	INSERT INTO eaGroupPolicy (GroupID, FuncID, Policy)
		SELECT @GroupID, t.FuncID, t.Policy 
		FROM @Func t
			LEFT OUTER JOIN eaGroupPolicy gp WITH(NOLOCK) ON gp.groupID = @GroupID AND gp.funcID = t.FuncID
		WHERE gp.FuncID IS NULL		
	
	/**************Write to Log table for each action********************/
	
	DECLARE @LogData NVARCHAR(4000)
	
	SELECT @LogData =	'<EAS_GroupPolicyUpd>'+
								'<GroupID>'+ ISNULL(CONVERT(VARCHAR(20),@GroupID),'') + '</GroupID>'+
								'<IP>' + COALESCE(@IP,'') + '</IP>'+
								'<Permission>' + 
									'<Old>' + ISNULL(@OldGroupPolicy,'') + '</Old>' +
									'<New>' + ISNULL(@GroupPolicy,'') + '</New>' +
								'</Permission>'+ 
						'</EAS_GroupPolicyUpd>'				

	SET @endRun = getdate()  
	SET @duration  = datediff (millisecond,@startRun,@endRun)   

	EXEC DBLOG.bodb_CustomerLog.[dbo].[EAS_WriteLog_UserLog_UserControl] 
		@custID = @GroupID, 
		@TrackingValue = @LogData, 
		@userid = @userID, 
		@TypeID = 0, 
		@actionid = 20003, 
		@duration = @Duration
	
GO
GRANT VIEW DEFINITION ON [dbo].[EAS_GroupPolicyUpd] TO [vnteam]
GO
GRANT EXECUTE ON [dbo].[EAS_GroupPolicyUpd] TO [bodbExtAccNet]
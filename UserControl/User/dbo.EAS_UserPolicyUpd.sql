ALTER PROCEDURE [dbo].[EAS_UserPolicyUpd]
	 @UserID			INT,
	 @CustID			INT,
	 @OldUserPolicy		VARCHAR(4000) = '',
	 @UserPolicy		VARCHAR(4000),
	 @IP				VARCHAR(50),
	 @ErrCode			INT = 0 OUTPUT,
	 @ErrMsg			VARCHAR(500) ='' OUTPUT
AS
	/*
		Created: Dan
		Date: 2012-11-20
		Task: Update policy of user
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
	
	EXEC dbo.EAS_UserCheckPermission @UserID = @UserID ,@FuncKey = 'ManageUser', @ErrCode = @ErrCode OUTPUT, @ErrMsg = @ErrMsg OUTPUT
	
	IF @ErrCode > 0
		RETURN
	
	DECLARE @Func TABLE (FuncID INT, Policy INT)
	
	INSERT INTO @Func (funcid, policy)
		SELECT funcid,policy
		FROM dbo.f_EAS_PolicySplit (@UserPolicy,';',',')
		
		
	UPDATE u
	SET u.Policy = t.Policy
	FROM eaUserPolicy u
		INNER JOIN @Func t ON u.userid = @custid AND u.funcid = t.funcid
	
	INSERT INTO eaUserPolicy (UserID, FuncID, Policy)
	SELECT @custID, t.FuncID, t.Policy 
	FROM @Func t
		LEFT OUTER JOIN eaUserPolicy u WITH(NOLOCK) ON u.userID = @custID AND u.funcID = t.FuncID
	WHERE u.FuncID IS NULL

	/**************Write to Log table for each action********************/
	DECLARE @LogData VARCHAR(4000)
	
	SELECT @LogData = '<EAS_UserPolicyUpd>' + 
						'<CustID>'+ ISNULL(CONVERT(VARCHAR(20),@CustID),'') + '</CustID>'+
						'<IP>' + COALESCE(@IP,'') + '</IP>' +
						'<UserPolicy>' +
							'<Old>' + ISNULL(@OldUserPolicy,'') + '</Old>' +
							'<New>' + ISNULL(@UserPolicy,'') + '</New>' +
						'</UserPolicy>'+						
					'</EAS_UserPolicyUpd>'

	SET @endRun = getdate()  
	SET @duration  = datediff (millisecond,@startRun,@endRun)   

	EXEC DBLOG.bodb_CustomerLog.[dbo].[EAS_WriteLog_UserLog_UserControl] 
		@custID = @CustID, 
		@TrackingValue = @LogData, 
		@userid = @UserID, 
		@TypeID = 1, 
		@actionid = 20007, 
		@duration = @duration
		
GO
GRANT VIEW DEFINITION ON [dbo].[EAS_UserPolicyUpd] TO [vnteam]
GO
GRANT EXECUTE ON [dbo].[EAS_UserPolicyUpd] TO [bodbExtAccNet]
	 
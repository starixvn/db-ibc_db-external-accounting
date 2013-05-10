ALTER PROCEDURE [dbo].[EAS_UserInfoUpdUserGroup]
	@userID	INT,
	@CustID		INT,
	@GroupID	INT,
	@IP			VARCHAR(50),
	@ErrCode	INT = 0 OUTPUT,
	@ErrMsg		VARCHAR(500) = '' OUTPUT
AS
	/*
		Created: Dan
		Date: 2012-11-19
		Task: Update user's group
		DB: DBEAS/bodb_EAS
		
		Revisions:
			
		Parameter's Explanation:
	*/
SET NOCOUNT ON
	DECLARE @startRun datetime  
		,@endRun datetime  
		,@duration int		
	
	SET @startRun=GETDATE()
	
	EXEC dbo.EAS_UserCheckPermission @UserID = @userID ,@FuncKey = 'ManageUser', @ErrCode = @ErrCode OUTPUT, @ErrMsg = @ErrMsg OUTPUT
	
	IF @ErrCode > 0
		RETURN
	
	DECLARE @db_groupid INT
	
	SELECT @db_groupid = groupid FROM eaUserInfo WITH(NOLOCK) WHERE UserID = @CustID
	
	IF @@ROWCOUNT = 0
	BEGIN
		SELECT @ErrMsg = 'This user does not exist',
				@ErrCode = 100
		RETURN		
	END
	
	IF @GroupID = @db_groupID
		RETURN
	
	UPDATE eaUserInfo WITH(UPDLOCK,ROWLOCK) 
	SET GroupID = @GroupID
	WHERE UserID = @CustID
	
	DECLARE @LogData NVARCHAR(500)
    SELECT @LogData =	'<EAS_UserInfoUpdUserGroup>' + 
							'<GroupID>'+ 
								'<Old>' + COALESCE(CONVERT(VARCHAR(10),@db_groupid),'') + '</Old>' +
								'<New>' + COALESCE(CONVERT(VARCHAR(10),@GroupID),'') + '</New>' +
							'</GroupID>'+ 
							'<IP>' + COALESCE(@IP,'') + '</IP>' + 
						'</EAS_UserInfoUpdUserGroup>'

    SET @endRun = GETDATE();
    SET @Duration = DATEDIFF(millisecond, @startRun, @endRun);

    EXEC DBLOG.bodb_CustomerLog.[dbo].[EAS_WriteLog_UserLog_UserControl] 
		@custID = @CustID, 
		@TrackingValue = @LogData, 
		@userid = @userID, 
		@TypeID = 1, 
		@actionid = 20006, 
		@duration = @Duration
	
GO
GRANT VIEW DEFINITION ON [dbo].[EAS_UserInfoUpdUserGroup] TO [vnteam]
GO
GRANT EXECUTE ON [dbo].[EAS_UserInfoUpdUserGroup] TO [bodbExtAccNet]
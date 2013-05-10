ALTER PROCEDURE [dbo].[EAS_UserInfoUpdStatus]
	@userID	INT,
	@CustID		INT,
	@Enabled BIT, 	
	@IP			VARCHAR(50),
	@ErrCode	INT = 0 OUTPUT,
	@ErrMsg		VARCHAR(500) = '' OUTPUT
AS
	/*
		Created: Dan
		Date: 2012-11-20
		Task: Update user's enable status
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
	
	DECLARE @db_enabled BIT
	
	SELECT @db_enabled = enabled FROM eaUserInfo WITH(NOLOCK) WHERE userid = @CustID
	
	IF @@ROWCOUNT = 0
	BEGIN
		SELECT @ErrMsg = 'This user does not exist',
				@ErrCode = 100
		RETURN		
	END
	
	IF @db_enabled = @enabled
		RETURN			
	
	UPDATE eaUserInfo WITH(UPDLOCK,ROWLOCK) 
	SET Enabled = @Enabled
	WHERE UserID = @CustID
	
	DECLARE @LogData NVARCHAR(500)
    SELECT @LogData =	'<EAS_UserInfoUpdStatus>' + 
							'<Enabled>'+ 
								'<Old>' + COALESCE(CONVERT(VARCHAR(10),@db_Enabled),'') + '</Old>' +
								'<New>' + COALESCE(CONVERT(VARCHAR(10),@Enabled),'') + '</New>' +
							'</Enabled>'+ 
							'<IP>' + COALESCE(@IP,'') + '</IP>' + 
						'</EAS_UserInfoUpdStatus>'

    SET @endRun = GETDATE();
    SET @Duration = DATEDIFF(millisecond, @startRun, @endRun);

    EXEC DBLOG.bodb_CustomerLog.[dbo].[EAS_WriteLog_UserLog_UserControl] 
		@custID = @CustID, 
		@TrackingValue = @LogData, 
		@userid = @userID, 
		@TypeID = 1, 
		@actionid = 20300, 
		@duration = @Duration
	
GO
GRANT VIEW DEFINITION ON [dbo].[EAS_UserInfoUpdStatus] TO [vnteam]
GO
GRANT EXECUTE ON [dbo].[EAS_UserInfoUpdStatus] TO [bodbExtAccNet]
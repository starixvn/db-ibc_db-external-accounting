ALTER PROCEDURE [dbo].[EAS_UserInfoUpdAll]
	@userID	INT,
	@CustID		INT,		
	@firstname	NVARCHAR(50),
	@lastname	NVARCHAR(50),	
	@GroupID	INT,	
	@IP			VARCHAR(50),
	@ErrCode	INT = 0 OUTPUT,
	@ErrMsg		VARCHAR(500) = '' OUTPUT
AS
	/*
		Created: Dan
		Date: 2012-05-11
		Task: Update user info 
		DB: DBTXN/BODB02
		
		Revsisions:
			- 20130121@Dan: change linked server DB052 to DBEAS, Write log on DBTXN server in case of DBLOG server failure
			
		Parameter's Explanation:
	*/
SET NOCOUNT ON

	DECLARE @startRun datetime  
		,@endRun datetime  
		,@duration int		
	
	SET @startRun=GETDATE()
	
	EXEC DBEAS.bodb_EAS.dbo.EAS_UserCheckPermission @UserID = @userID ,@FuncKey = 'ManageUser', @ErrCode = @ErrCode OUTPUT, @ErrMsg = @ErrMsg OUTPUT
	
	IF @ErrCode > 0
		RETURN
		
	DECLARE @db_firstname	NVARCHAR(50),			
			@db_lastname	NVARCHAR(50)
	
	SELECT @db_firstname = firstname, 
		@db_lastname = lastname
	FROM Customer WITH(NOLOCK)
	WHERE CustID = @CustID
	
	IF @@ROWCOUNT = 0 
	BEGIN
		SELECT @ErrMsg = 'This user does not exist',
				@ErrCode = 100
		RETURN
	END		
		
	EXEC DBEAS.bodb_EAS.dbo.EAS_UserInfoUpdUserGroup 
		@userID = @userID,
		@CustID	 = @CustID,
		@GroupID = @GroupID,
		@IP		 = @IP,
		@ErrCode = @ErrCode OUTPUT,
		@ErrMsg	 = @ErrMsg OUTPUT
	
	IF @ErrCode > 0
		RETURN	
	
	IF @db_firstname != @firstname OR @db_lastname != @lastname
	BEGIN				
		UPDATE Customer WITH(UPDLOCK,ROWLOCK)
		SET firstname = @firstname,
			lastname = @lastname 
		WHERE CustID = @CustID
	END	
	
	DECLARE @LogData NVARCHAR(500)
	SELECT @LogData = '<EAS_UserInfoUpdAll>' + 
						'<FirstName>' + 
							'<Old>' + COALESCE(@db_firstname,'') + '</Old>' +
							'<New>' + COALESCE(@firstname,'') + '</New>' +
						'</FirstName>' + 	
						'<LastName>' + 
							'<Old>' + COALESCE(@db_lastname,'') + '</Old>' +
							'<New>' + COALESCE(@lastname,'') + '</New>' +
						'</LastName>' + 
						'<IP>' + COALESCE(@IP,'') + '</IP>' + 
					'</EAS_UserInfoUpdAll>'
				
	SET @endRun = GETDATE()  
	SET @duration  = DATEDIFF (MILLISECOND,@startRun,@endRun)   
	BEGIN TRY
		EXEC DBLOG.bodb_CustomerLog.[dbo].[EAS_WriteLog_UserLog_UserControl] 
			@custID = @CustID, 
			@TrackingValue = @LogData, 
			@userid = @userID, 
			@TypeID = 1, 
			@actionid = 20007, 
			@duration = @duration
	END TRY
	BEGIN CATCH
		SELECT @LogData = '<EAS_UserInfoUpdAll>' + 
						'<FirstName>' + 
							'<Old>' + COALESCE(@db_firstname,'') + '</Old>' +
							'<New>' + COALESCE(@firstname,'') + '</New>' +
						'</FirstName>' + 	
						'<LastName>' + 
							'<Old>' + COALESCE(@db_lastname,'') + '</Old>' +
							'<New>' + COALESCE(@lastname,'') + '</New>' +
						'</LastName>' + 
						'<IP>' + COALESCE(@IP,'') + '</IP>' + 
						'<ErrMsg>' + COALESCE(ERROR_MESSAGE(),'') + '</ErrMsg>' + 
					'</EAS_UserInfoUpdAll>'
		EXEC bodb_CustomerLog.[dbo].[EAS_WriteLog_UserLog_UserControl] 
			@custID = @CustID, 
			@TrackingValue = @LogData, 
			@userid = @userID, 
			@TypeID = 1, 
			@actionid = 20007, 
			@duration = @duration			
	END CATCH
	
GO 
GRANT VIEW DEFINITION ON [dbo].[EAS_UserInfoUpdAll] TO [vnteam]
GO 
GRANT EXECUTE ON [dbo].[EAS_UserInfoUpdAll] TO [bodbExtAccNet]
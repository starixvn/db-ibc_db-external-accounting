ALTER PROCEDURE [dbo].[EAS_UserLogin]
	@Username		VARCHAR(50),
	@Custid			INT = 0 OUTPUT,
	@GroupId		INT = 0 OUTPUT,
	@userpwd		NVARCHAR(100),
	@LoginIP		VARCHAR(50),
	@LoginDomain	NVARCHAR(253) = NULL,
	@BrowserName	NVARCHAR(255) = NULL,
	@Platform		NVARCHAR(255) = NULL,  
	@CountryCode	VARCHAR(64) = NULL,
	@ErrCode INT = 0 OUTPUT,
	@ErrMsg			NVARCHAR(200) = '' OUTPUT	
AS
	/*
		Created: Dan
		Date: 2012-11-16
		DB: DBTXN/BODB02
		Task: Admin login EAS
		
		Revisions:
			- 20130121@Dan: change linked server DB052 to DBEAS, Write log on DBTXN server in case of DBLOG server failure
		
		Parameter's Explanation:
	*/ 
SET NOCOUNT ON 

	DECLARE @Begin		DATETIME
	DECLARE @End		DATETIME
	DECLARE @Duration	INT

	SET @Begin = GETDATE()

	DECLARE @LogData nvarchar(300),
		@db_userpwd nvarchar(50),
		@failedcount tinyint,		
		@enabled bit,
		@roleid int

	SELECT @LogData = '', @ErrMsg = '', @ErrCode = 0 

	SELECT @CustID = ISNULL(c.custid,0), @db_userpwd = c.userpwd, @RoleID = roleid, 
			@failedcount = IsNull(logincount, 0), @UserName = username
	FROM dbo.customer c with (nolock)
	WHERE username = @UserName

	IF @@ROWCOUNT = 0 -- user not found
	BEGIN
		SELECT  @ErrMsg =  'Wrong username or password.',
				@ErrCode = 101,		
				@CustID = 0,
				@LogData = 'User:' + @UserName + ' Logged in to EAS SITE' + ' - ' + 'Result:Failed(User_Not_Found)'
	END
	ELSE IF @RoleID NOT IN (5,6,7,8,9,10)
	BEGIN
		SELECT  @ErrMsg = N'Wrong username or password.',
			@ErrCode = 102, 
			@LogData = 'User:' + @username + ' Logged in to EAS SITE' + ' - ' + 'Result:Failed(Not_Admin)'
	END
	ELSE IF @UserPWD <> @db_userpwd
	BEGIN
		SELECT @ErrMsg = N'Wrong username or password.',
			@ErrCode = 103,
			@LogData = 'User:' + @username + ' Logged in to EAS SITE' + ' - ' + 'Result:Failed(Password)' ,
			@failedcount = @failedcount + 1
		
		IF (@failedcount <= 255) -- max of tinyint
		BEGIN
			UPDATE customer WITH (ROWLOCK, UPDLOCK) 
			SET logincount = @failedcount 
			WHERE custid = @custid
		END
	END
	
	IF (@ErrMsg = '') AND (@LogData = '')
	BEGIN
		--Check existing in EAS
		SELECT @enabled = enabled, @GroupId = GroupId
		FROM DBEAS.bodb_EAS.dbo.eaUserInfo WITH(NOLOCK) WHERE UserID = @custid
		
		IF @@ROWCOUNT = 0 --User not admin EAS
		BEGIN
			SELECT @ErrMsg = 'Wrong username or password.',
				@ErrCode = 104,		
				@LogData = 'User:' + @UserName + ' Logged in to EAS SITE' + ' - ' + 'Result:Failed(User_Not_Permission)'	
		END
		
		IF @enabled = 0 
		BEGIN
			SELECT @ErrMsg = 'Your account has been disabled. Please contact your system administrator.',
				@ErrCode = 105,		
				@LogData = 'User:' + @UserName + ' Logged in to eas SITE' + ' - ' + 'Result:Failed(A/C_Disabled)'			
		END
		ELSE
		BEGIN
			UPDATE customer with (rowlock, updlock)
			SET logincount = 0, iplogin = @LoginIP, lastlogged = CURRENT_TIMESTAMP, on_sessionid = 0
			WHERE custid = @custid

			SET @LogData = 'User:' + @username + ' Logged in to EAS SITE' + ' - ' + 'Result:Success'		
		END
	END
	
	IF @LogData <> ''
	BEGIN		
		SET @End = GETDATE()
		SET @Duration = DATEDIFF(millisecond,@Begin,@End)		
		
		BEGIN TRY
			EXEC DBLOG.bodb_customerlog.dbo.EAS_WriteLog_UserLog_Login 
				 @UserID = @CustID, 
				 @LoginIP = @LoginIP,	
				 @ActionID = 20200,
				 @TrackingValue = @LogData,
				 @DomainName = @LoginDomain,
				 @BrowserName = @BrowserName,
				 @Platform = @Platform,
				 @CountryCode = @CountryCode,
				 @Duration = @Duration
		END TRY
		BEGIN CATCH
			SELECT @LogData = @LogData + '- ErrMsg:' + ERROR_MESSAGE()
			
			EXEC bodb_customerlog.dbo.EAS_WriteLog_UserLog_Login 
				 @UserID = @CustID, 
				 @LoginIP = @LoginIP,	
				 @ActionID = 20200,
				 @TrackingValue = @LogData,
				 @DomainName = @LoginDomain,
				 @BrowserName = @BrowserName,
				 @Platform = @Platform,
				 @CountryCode = @CountryCode,
				 @Duration = @Duration
		END CATCH		 
	END
	
GO
GRANT VIEW DEFINITION ON [dbo].[EAS_UserLogin] TO [vnteam]
GO
GRANT EXECUTE ON [dbo].[EAS_UserLogin] TO [bodbExtAccNet]

ALTER PROCEDURE [dbo].[EAS_WriteLog_UserLog_Login]
	@UserID INT,  
    @LoginIP VARCHAR(50)='', 
	@ActionID int = 0, 
    @DomainName NVARCHAR(253) = NULL,
    @TrackingValue VARCHAR(300),
    @BrowserName NVARCHAR(255) = NULL,
    @Platform NVARCHAR(255) = NULL,
    @CountryCode VARCHAR(64) = NULL,
    @Duration INT = NULL	
 AS
	/*
		Created: Dan
		Date: 2012-11-15
		Task: Write log admin login 
		DB: DBLog/bodb_CustomerLog, DBTXN/bodb_CustomerLog
		
		Revisions:
			- 20130121@Dan: add one more db DBTXN/bodb_CustomerLog
			
		Parameter's Explanations:
	*/
SET NOCOUNT ON

	INSERT INTO [dbo].[eaUserLog_Login]
           ([UserID]
           ,[IP]
           ,[LogDate]
		   ,[ActionID]
           ,[TrackingValue]
           ,[DomainName]
           ,[BrowserName]
           ,[Platform]
           ,[CountryCode]
           ,[Duration])
     VALUES
           (@UserID,
			@LoginIP,
			GETDATE(),
			@ActionID,
			@TrackingValue,
			@DomainName,
			@BrowserName,
			@Platform,
			@CountryCode,
			@Duration
			)
GO
GRANT VIEW DEFINITION ON [dbo].[EAS_WriteLog_UserLog_Login] TO [vnteam]
GO
GRANT EXECUTE ON [dbo].[EAS_WriteLog_UserLog_Login] TO [bodbExtAccNet]
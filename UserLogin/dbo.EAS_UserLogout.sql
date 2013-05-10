ALTER PROCEDURE [dbo].[EAS_UserLogout]
	@on_userid INT,
	@username  NVARCHAR(50)= NULL
AS
	/*
		Created: Dan
		Date: 2012-11-16
		Task: user log out EAS
		DB: DBEAS/bodb_EAS
		
		Revsisons:
		
		Parameter's Explanation:
	*/ 
SET NOCOUNT ON 
	
	SET NOCOUNT ON
	DECLARE @Begin		DATETIME
	DECLARE @End		DATETIME
	DECLARE @Duration	INT

	SET @Begin = GETDATE()
	
	--Write log to record user logout
	Declare @CustID int, @LoginIP varchar(15),   
			@LogData nvarchar(200)
	
	SELECT	@CustID = 0, @LoginIP = '127.0.0.0'  
	
	SELECT @CustID = custid, @LoginIP = IP 
	FROM eaOn_User WITH (nolock) WHERE on_userid = @On_UserID
		
	DELETE FROM eaOn_user WITH(ROWLOCK) WHERE on_userid = @on_userid
	
	SELECT @LogData =  'User:' + CASE WHEN ISNULL(@UserName,'') = '' THEN CAST(@custid AS VARCHAR(30)) ELSE @Username END + ' Logout Success'
	
	SET @End = GETDATE()
	SET @Duration = DATEDIFF(millisecond,@Begin,@End)

	EXEC DBLOG.bodb_customerlog.dbo.EAS_WriteLog_UserLog_Login 
		 @UserID = @CustID, 		
		 @LoginIP = @LoginIP,
		 @ActionID = 20201,	 
		 @TrackingValue = @LogData,
		 @Duration = @Duration
		 
GO 
GRANT VIEW DEFINITION ON [EAS_UserLogout] TO [vnteam]
GO
GRANT EXECUTE ON [EAS_UserLogout] TO [bodbExtAccNet]
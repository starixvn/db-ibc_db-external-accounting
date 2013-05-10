ALTER PROCEDURE [dbo].[EAS_WriteLog_UserLog_RunSP]
	@UserID			INT,
	@CustID			INT = 0,
	@ActionID		INT = NULL,
	@TrackingValue	VARCHAR(MAX) = NULL,
	@TrackingValue2 VARCHAR(MAX) = NULL,
	@Duration		INT	= NULL
AS
	/*
		Created: Dan
		Date: 2012-11-15
		Task: write log data		
		DB: DBLOG/bodb_CustomerLog, DBTXN/bodb_CustomerLog
		
		Revisions:
			- 20130121@Dan: add one more db DBTXN/bodb_CustomerLog
		Parameter's Explanation:
	*/
SET NOCOUNT ON
	
	INSERT INTO [bodb_CustomerLog].[dbo].[eaUserLog_RunSP]
           ([UserID]  
           ,[Logdate]
           ,[CustID]
           ,[ActionID]
           ,[TrackingValue]
           ,[TrackingValue2]
           ,[Duration])
     VALUES( @UserID, GETDATE(), @CustID, @ActionID, @TrackingValue, @TrackingValue2, @Duration)


GO
GRANT VIEW DEFINITION ON [dbo].[EAS_WriteLog_UserLog_RunSP] TO [vnteam]
GO
GRANT EXECUTE ON [dbo].[EAS_WriteLog_UserLog_RunSP] TO [bodbExtAccNet]
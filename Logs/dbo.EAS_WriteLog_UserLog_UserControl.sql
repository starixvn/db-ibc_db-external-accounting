ALTER PROCEDURE [dbo].[EAS_WriteLog_UserLog_UserControl]
    @CustID INT,
    @TrackingValue NVARCHAR(MAX),
    @UserID INT = NULL,
    @TypeID TINYINT=0,
    @ActionID INT=NULL,
    @Duration INT = NULL
AS
/*
Created: 20121115@Dan
Task : Write log for User Control in RMS
DB: DBLog/bodb_CustomerLog, DBTXN/bodb_CustomerLog
Original: 

Revisions:
	- 20130121@Dan: add one more db DBTXN/bodb_CustomerLog
		
Parameter's Explanation:

*/
SET NOCOUNT ON
INSERT INTO  dbo.eaUserLog_UserControl
           ([CustID]
           ,[LogDate]
           ,[UserID]
           ,[TypeID]
           ,[ActionID]
           ,[Duration]
           ,[TrackingValue])
     VALUES
            (@CustID
            ,GETDATE()
            ,@UserID
            ,@TypeID
            ,@ActionID
            ,@Duration
            ,@TrackingValue
            )

GO
GRANT VIEW DEFINITION ON [dbo].[EAS_WriteLog_UserLog_UserControl] TO [vnteam]
GO
GRANT EXECUTE ON [dbo].[EAS_WriteLog_UserLog_UserControl] TO [bodbExtAccNet]

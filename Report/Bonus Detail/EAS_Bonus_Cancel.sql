/*<info serverAlias="DBTXN-bodb02" executers="bodbExtAccNet" viewers="" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE dbo.EAS_Bonus_Cancel
(
	@TransId	BIGINT
	,@UserID	INT
	,@LoginIP	NVARCHAR(20) = ''
	,@ErrCode	INT = 0 OUTPUT
	,@ErrMsg	NVARCHAR(200) = '' OUTPUT
)
AS
/*
Created: 20210104@Malcolm
Task : Set up Bonus feature for IBCIndo
DB: DBTXN/bodb02

Revisions:
	- 20210104@Malcolm: Set up Bonus feature for IBCIndo [RedmineID: #147430]

*/
BEGIN
	SET NOCOUNT ON;
	
	DECLARE @Time INT, @CustId INT, @LogSPData VARCHAR(MAX), @StartRun DATETIME = GETDATE(), @EndRun DATETIME, @Duration INT

	SELECT @Time = (DATEDIFF(SECOND, CreatedDate, GETDATE()) - 48 * 60 * 60) FROM dbo.BonusTrans WITH(NOLOCK) WHERE BonusTransId = @TransId

	IF @Time > 0
	BEGIN
		SELECT @ErrCode = 101, @ErrMsg = 'The selected Bonus was created more than 48 hours ago. You cannot cancel it.'
		RETURN
	END

	UPDATE b WITH(ROWLOCK)
		SET b.StatusId = 1
	FROM dbo.BonusTrans b 
	WHERE BonusTransId = @TransId AND StatusId = 0

	IF @@ROWCOUNT = 0
	BEGIN
		SELECT @ErrCode = 102, @ErrMsg = 'The selected Bonus status is not Pending anymore, you cannot cancel it.'
		RETURN
	END

	SELECT @CustId = CustID FROM dbo.BonusTrans WITH(NOLOCK) WHERE BonusTransId = @TransId

	SELECT @LogSPData = '<EAS_Bonus_Cancel RefNo="'+ CONVERT(VARCHAR(30), @TransId) +'" IP="'+@LoginIP+'"/>'

	SELECT @EndRun = GETDATE(), @Duration = DATEDIFF(MILLISECOND, @StartRun, @EndRun)

	EXEC  DBLOG.bodb_CustomerLog.dbo.WriteLog_UserLog_RunSP
				 @UserID = @UserID, 
				 @CustId = @CustId,
				 @ActionID = 20402,
			     @TrackingValue = @LogSPData,
				 @duration = @duration
END
GO
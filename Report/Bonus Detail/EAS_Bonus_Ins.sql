CREATE PROCEDURE dbo.EAS_Bonus_Ins
(
	@Usernames VARCHAR(MAX)
	,@Amount	MONEY
	,@GroupName VARCHAR(50)
	,@Error		INT
	, @ErrorCode VARCHAR(100)
	,@UserId INT
)
AS
BEGIN
	
	DECLARE @Super TABLE (Username VARCHAR(30), CustId INT)

	DECLARE @Member TABLE (Username VARCHAR(30), CustId INT, Recommend INT, Mrecommend INT, Srecommend INT, RoleId TINYINT)

	DECLARE @LogSPData VARCHAR(MAX), @StartRun DATETIME = GETDATE(), @EndRun DATETIME, @Duration INT 
	-- Check validation
	SELECT @Usernames = ISNULL(@Usernames, ''), @Amount= ISNULL(@Amount, 0)

	IF @Usernames = ''
	BEGIN
		SELECT @Error = 100, @ErrorCode = 'This field is required.'
		RETURN
	END

	IF @Usernames LIKE '%\%'
	BEGIN
		SELECT @Error = 101, @ErrorCode = 'You are not allowed to input backslash ''\'' into the Username field.'
		RETURN
	END

	IF @Amount <= 0
	BEGIN
		SELECT @Error = 102, @ErrorCode = 'Amount must be a whole positive number.'
	END

	INSERT INTO @Member (Username)
	SELECT f.val AS Username FROM dbo.f_SplitString(@Usernames, ',') f OPTION (maxrecursion 0)

	UPDATE m
		SET m.CustId = l.custid, m.RoleId = m.RoleId
	FROM @Member m
	CROSS APPLY(SELECT custid, roleid FROM CustDB.dbo.Customer c WITH(NOLOCK) WHERE c.username = m.Username) AS l

	UPDATE m
		SET m.Recommend = l.Recommend, m.mrecommend = m.mrecommend, m.srecommend = l.srecommend
	FROM @Member m
	CROSS APPLY(SELECT c.recommend, c.mrecommend, c.srecommend FROM CustDB.dbo.Customer c WITH(NOLOCK) WHERE c.username = m.Username) AS l

	IF EXISTS(SELECT 1 FROM @Member m LEFT JOIN @Super s ON m.Srecommend  = s.CustId WHERE s.CustId IS NULL)
	BEGIN	
		SELECT @ErrorCode = STUFF(
									  (SELECT ',' + m.Username 
									   FROM @Member m 
								   			LEFT JOIN @Super s ON m.Srecommend  = s.CustId 
									   WHERE s.CustId IS NULL OR m.CustId IS NULL OR m.RoleId <> 1
									   FOR XML PATH('')),1,1,''
								  )	

		SELECT @Error = 104
		RETURN
	END

	INSERT INTO dbo.BonusTrans(CustID, Recommend, Mrecommend, Srecommend, Amount, StatusId, Creator, CreationDate, PaymentDate, IsComplained)
	SELECT CustId, Recommend, Mrecommend, Srecommend, @Amount, 0, @UserId, GETDATE(), NULL, NULL
	FROM @Member
 
	SET @EndRun = GETDATE()

	SET @Duration = DATEDIFF(MILLISECOND, @StartRun, @EndRun)

	EXEC  DBLOG.bodb_CustomerLog.dbo.WriteLog_UserLog_RunSP
				 @UserID = @UserID, 
				 @ActionID = 0,
			     @TrackingValue = @LogSPData,
				 @duration = @duration

END
GO
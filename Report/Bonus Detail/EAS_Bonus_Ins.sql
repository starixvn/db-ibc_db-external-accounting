/*<info serverAlias="DBTXN-bodb02" executers="bodbDownlineNet,bodbDownlineNetView" isFunction="0" isNested="0"></info>*/
CREATE PROCEDURE dbo.EAS_Bonus_Ins
(
	@Usernames VARCHAR(MAX)
	,@Amount	MONEY
	,@GroupName VARCHAR(50)
	,@UserId INT
	,@ErrCode INT = 0 OUTPUT
	,@ErrMsg NVARCHAR(200) = '' OUTPUT	
)
AS
/*
Created: 
Task : Set up Bonus feature for IBCIndo
DB: DBTXN/bodb02

Revisions:
	- 20200104@Malcolm: Set up Bonus feature for IBCIndo [RedmineID: #147430]

*/
BEGIN
	
	DECLARE @Super TABLE (Username VARCHAR(30), CustId INT)

	DECLARE @Member TABLE (ID INT IDENTITY(1,1), TransId BIGINT, Username VARCHAR(30), CustId INT, Recommend INT, Mrecommend INT, Srecommend INT, RoleId TINYINT, Amount MONEY)

	DECLARE @LogSPData VARCHAR(MAX), @StartRun DATETIME = GETDATE(), @EndRun DATETIME, @Duration INT, @NumberOfMember INT, @ID INT, @CustId INT
	-- Check validation
	SELECT @Usernames = ISNULL(@Usernames, ''), @Amount= ISNULL(@Amount, 0)

	IF @Usernames = ''
	BEGIN
		SELECT @ErrCode = 100, @ErrMsg = 'This field is required.'
		RETURN
	END

	IF @Usernames LIKE '%\%'
	BEGIN
		SELECT @ErrCode = 101, @ErrMsg = 'You are not allowed to input backslash ''\'' into the Username field.'
		RETURN
	END

	IF @Amount <= 0
	BEGIN
		SELECT @ErrCode = 102, @ErrMsg = 'Amount must be a whole positive number.'
	END

	INSERT INTO @Member (Username)
	SELECT DISTINCT f.val AS Username FROM dbo.f_SplitString(@Usernames, ',') f WHERE f.Val <> '' OPTION (maxrecursion 0)

	SELECT @NumberOfMember = COUNT(*) FROM @Member

	IF @NumberOfMember > 100
	BEGIN
		SELECT @ErrCode = 105, @ErrMsg = 'The function can only add up to 100 accounts per request'
	END

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
		SELECT @ErrMsg = STUFF(
						 		  (SELECT ',' + m.Username 
						 		   FROM @Member m 
						 	   			LEFT JOIN @Super s ON m.Srecommend  = s.CustId 
						 		   WHERE s.CustId IS NULL OR m.CustId IS NULL OR m.RoleId <> 1
						 		   FOR XML PATH('')),1,1,''
						 	  )						 
			 ,@ErrCode = 104
		RETURN
	END

	INSERT INTO dbo.BonusTrans(CustID, Recommend, Mrecommend, Srecommend, Amount, StatusId, Creator, CreationDate, PaymentDate, IsComplained)
	OUTPUT inserted.TransId, NULL, inserted.CustID, inserted.Recommend, inserted.Mrecommend, inserted.Srecommend, NULL, inserted.Amount
		INTO @Member
	SELECT CustId, Recommend, Mrecommend, Srecommend, @Amount, 0, @UserId, GETDATE(), NULL, NULL
	FROM @Member

	UPDATE m
		SET m.Username = tr.Username, m.RoleId = tr.RoleId, m.Amount = @Amount
	FROM @Member m
	CROSS APPLY (SELECT  r.RoleId, r.Username FROM @Member r WHERE r.TransId IS NULL AND r.CustId = m.CustId) AS tr
	WHERE m.TransId IS NOT NULL

	DELETE @Member WHERE TransId IS NULL

	SELECT @ID = MIN(ID) FROM @Member
 
	SELECT @EndRun = GETDATE(), @Duration = DATEDIFF(MILLISECOND, @StartRun, @EndRun)

	WHILE 1 = 1
	BEGIN
		IF NOT EXISTS(SELECT TOP 1 1 FROM @Member m WHERE m.ID = @ID)
			BREAK

		SELECT @CustId = m.CustId, @LogSPData = '<EAS_Bonus_Ins RefNo="'+ CONVERT(VARCHAR(30), TransId) +'" Member="' +Username+ '" Amount="'+CONVERT(VARCHAR(30), Amount)+'"/>'
		FROM @Member m
		WHERE ID = @ID

		EXEC  DBLOG.bodb_CustomerLog.dbo.WriteLog_UserLog_RunSP
				 @UserID = @UserID, 
				 @CustId = @CustId,
				 @ActionID = 95038,
			     @TrackingValue = @LogSPData,
				 @duration = @duration
	END
END
GO
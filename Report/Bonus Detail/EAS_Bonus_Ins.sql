/*<info serverAlias="DBTXN-bodb02" executers="bodbExtAccNet" viewers="" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE dbo.EAS_Bonus_Ins
(
	@Usernames	VARCHAR(MAX)
	,@Amount	MONEY
	,@GroupName VARCHAR(50)
	,@UserId	INT
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
	SET NOCOUNT ON
	
	DECLARE @Super TABLE (CustId INT)

	DECLARE @Member TABLE (ID INT IDENTITY(1,1), TransId BIGINT, Username VARCHAR(30), CustId INT, Recommend INT, Mrecommend INT, Srecommend INT, RoleId TINYINT, Amount MONEY)

	DECLARE @LogSPData VARCHAR(MAX), @StartRun DATETIME = GETDATE(), @EndRun DATETIME, @Duration INT, @NumberOfMember INT, @ID INT, @CustId INT

	SELECT @Usernames = ISNULL(@Usernames, ''), @Amount= ISNULL(@Amount, 0)

	INSERT INTO @Member (Username)
	SELECT DISTINCT f.val AS Username FROM dbo.f_SplitString(@Usernames, ',') f WHERE f.Val <> '' OPTION (maxrecursion 0)

	UPDATE m
		SET m.CustId = l.custid, m.RoleId = l.RoleId
	FROM @Member m
	CROSS APPLY(SELECT custid, roleid FROM CustDB.dbo.Customer c WITH(NOLOCK) WHERE c.username = m.Username) AS l

	UPDATE m
		SET m.Recommend = l.Recommend, m.mrecommend = l.mrecommend, m.srecommend = l.srecommend
	FROM @Member m
	CROSS APPLY(SELECT c.recommend, c.mrecommend, c.srecommend FROM CustDB.dbo.Customer c WITH(NOLOCK) WHERE c.username = m.Username) AS l

	INSERT INTO @Super (CustId)
	SELECT a.CustId FROM DBCust.CustDB.dbo.Acc_CustGroup a WITH(NOLOCK) WHERE a.GroupName = @GroupName

	IF EXISTS(SELECT 1 FROM @Member m LEFT JOIN @Super s ON m.Srecommend  = s.CustId WHERE s.CustId IS NULL OR m.RoleId <> 1)
	BEGIN	
		SELECT @ErrMsg = 'Invalid member: ' + STUFF(
						 							  (SELECT ',' + m.Username 
						 							   FROM @Member m 
						 	   								LEFT JOIN @Super s ON m.Srecommend  = s.CustId 
						 							   WHERE s.CustId IS NULL OR m.CustId IS NULL OR m.RoleId <> 1
						 							   FOR XML PATH('')),1,1,''
						 						   )						 
			 ,@ErrCode = 104
		RETURN
	END

	INSERT INTO dbo.BonusTrans(CustID, Recommend, Mrecommend, Srecommend, Amount, StatusId, Creator, CreatedDate, PaymentDate, IsComplained)
	OUTPUT inserted.BonusTransId, NULL, inserted.CustID, inserted.Recommend, inserted.Mrecommend, inserted.Srecommend, NULL, inserted.Amount
		INTO @Member
	SELECT CustId, Recommend, Mrecommend, Srecommend, @Amount, 0, @UserId, GETDATE(), NULL, 0
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

		SELECT @CustId = m.CustId, @LogSPData = '<EAS_Bonus_Ins RefNo="'+ CONVERT(VARCHAR(30), TransId) +'" Member="' +Username+ '" Amount="'+CONVERT(VARCHAR(30), Amount)+'" IP="'+@LoginIP+'"/>'
		FROM @Member m
		WHERE ID = @ID

		EXEC  DBLOG.bodb_CustomerLog.dbo.WriteLog_UserLog_RunSP
				 @UserID = @UserID, 
				 @CustId = @CustId,
				 @ActionID = 20401,
			     @TrackingValue = @LogSPData,
				 @duration = @duration

		SET @ID += 1
	END
END
GO
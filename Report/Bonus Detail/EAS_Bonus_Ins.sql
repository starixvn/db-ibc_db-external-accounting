CREATE PROCEDURE dbo.EAS_Bonus_Ins
(
	@Usernames VARCHAR(MAX)
	,@Amount	MONEY
	,@GroupName VARCHAR(50)
	,@Error		INT
	, @ErrorCode VARCHAR(100)
)
AS
BEGIN
	
	-- Check validation
	SELECT @Usernames = ISNULL(@Usernames, ''), @Amount= ISNULL(@Amount, 0)

	DECLARE @Member TABLE (Username VARCHAR(30), CustId INT)

	IF @Usernames = ''
	BEGIN
		SELECT @Error = 100, @ErrorCode = 'This field is required.'
		RETURN
	END

	IF @Usernames LIKE '%\%'
	BEGIN
		SELECT @Error = 101, @ErrorCode = 'You are not allowed to input backslash '\' into the Username field.'
		RETURN
	END

	IF @Amount <= 0
	BEGIN
		SELECT @Error = 102, @ErrorCode = 'Amount must be a whole positive number.'
	END

	INSERT INTO @Member (Username)
	SELECT f.val AS Username
	FROM dbo.f_SplitString(@Usernames, ',') f
	OPTION (maxrecursion 0)

	SELECT *
	FROM CUSTDB.DBO.Acc_CustGroup
END
GO
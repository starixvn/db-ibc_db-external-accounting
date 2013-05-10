ALTER PROCEDURE [dbo].[EAS_UserCheckPermission]
	@UserID		INT,
	@FuncID		INT = NULL,
	@FuncKey	VARCHAR(100),	
	@ErrCode	INT = 0 OUTPUT,
	@ErrMsg		VARCHAR(500) = '' OUTPUT
AS
	/*
		Created: Dan
		Date: 2012-11-15
		Task: Check user's permission on function (Write Only)
		DB: DBEAS/bodb_EAS
		
		Revisions:
		
		Parameter's Explanation:
	*/
SET NOCOUNT ON

	IF @funcid IS NULL
		SELECT @funcid = FuncID FROM eaFunction WITH(NOLOCK) WHERE FuncKey = @FuncKey
	
	IF NOT EXISTS (SELECT 1 FROM eaUserInfo WITH(NOLOCK) WHERE UserID = @UserID AND enabled = 1)
	BEGIN
		SELECT @ErrMsg = 'This user not have permission to access EAS',
				@ErrCode = 100
		RETURN
	END
	
	DECLARE @isAllowed TINYINT
	
	SELECT @isAllowed = CASE WHEN ISNULL(u.Policy,0) >= ISNULL(g.Policy,0) THEN ISNULL(u.Policy,0) ELSE ISNULL(g.Policy,0) END
	FROM 
	(
		SELECT FuncID, Policy
		FROM eaUserPolicy WITH(NOLOCK)
		WHERE UserID =@UserID AND FuncID = @FuncID
	) u
	FULL OUTER JOIN
	(
		SELECT FuncID, Policy
		FROM eaGroupPolicy WITH(NOLOCK) 
		WHERE groupID = (SELECT groupID FROM eaUserInfo WITH(NOLOCK) WHERE UserID =@UserID)
			AND FuncID = @FuncID 
	) g ON u.FuncID = g.FuncID 
	
	IF ISNULL(@isAllowed,0) < 2
	BEGIN
		SELECT @ErrMsg =  N'You are not authorized on this function'
				,@ErrCode = 101
		RETURN 
	END
	
GO
GRANT VIEW DEFINITION ON [dbo].[EAS_UserCheckPermission] TO [vnteam]
GO
GRANT EXECUTE ON [dbo].[EAS_UserCheckPermission] TO [bodbExtAccNet]	 
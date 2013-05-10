ALTER PROCEDURE [dbo].[EAS_UserPolicySel]
	@UserID		INT
AS
	/*
		Created: Dan
		Date: 2012-11-20
		Task: Get policy of user
		DB: DBEAS/bodb_EAS
		
		Revisions:
		
		Parameter's Explanation:
	*/ 
SET NOCOUNT ON

	SELECT f.funcid, f.funcname, f.DisplayOrder, f.ParentID, f.ParentName, ISNULL(u.policy,0) UserPolicy, ISNULL(g.policy,0) GroupPolicy
	FROM eaFunction f WITH(NOLOCK)
	LEFT JOIN 	
		(
			SELECT FuncID, Policy 
			FROM eaUserPolicy WITH(NOLOCK) 
			WHERE UserID = @UserID
		) u ON f.funcid  = u.funcid
	LEFT JOIN
		(
			SELECT FuncID, Policy
			FROM eaGroupPolicy gp WITH(NOLOCK)
				INNER JOIN eaUserInfo ui WITH(NOLOCK) ON ui.userid = @userid AND ui.groupid = gp.groupid		
		) g ON f.funcid = g.funcid
	ORDER BY f.ParentID ,f.DisplayOrder ASC

GO
GRANT VIEW DEFINITION ON [dbo].[EAS_UserPolicySel] TO [vnteam]
GO
GRANT EXECUTE ON [dbo].[EAS_UserPolicySel] TO [bodbExtAccNet]
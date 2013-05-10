ALTER PROCEDURE [dbo].[EAS_GroupPolicySel]
	@groupid	INT
AS
/*
	Created: Dan
	Date: 2012-11-16
	Task: Get group policy
	DB: DBEAS/bodb_EAS
	
	Revisions:
	
	Parameter's Explanation:
*/ 
SET NOCOUNT ON

SELECT f.FuncID, f.FuncName, f.DisplayOrder, f.ParentID, f.ParentName, ISNULL(gp.Policy,0) as Policy
FROM eaFunction f WITH(NOLOCK)
	LEFT JOIN eaGroupPolicy gp WITH(NOLOCK) ON gp.GroupID = @groupid AND gp.funcid = f.funcid	
ORDER BY f.ParentID ,f.DisplayOrder ASC

GO
GRANT VIEW DEFINITION ON [dbo].[EAS_GroupPolicySel] TO [vnteam]
GO
GRANT EXECUTE ON [dbo].[EAS_GroupPolicySel] TO [bodbExtAccNet]
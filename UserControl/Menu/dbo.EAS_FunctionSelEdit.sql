ALTER PROCEDURE [dbo].[EAS_FunctionSelEdit]
	@funcId	INT
AS
	/*
		Created: Dan
		Date: 2012-12-03
		Task: Get functions info to edit group
		DB: DBEAS/bodb_EAS
		
		Revisions:
		
		Parameter's Explanation:
	*/ 
SET NOCOUNT ON
	
	SELECT g.GroupID, g.GroupName, CASE WHEN ISNULL(Policy,0)>1 THEN 1 ELSE 0 END hasPermission
	FROM dbo.eaGroup g WITH(NOLOCK) LEFT JOIN dbo.eaGroupPolicy gp WITH(NOLOCK) ON g.GroupID=gp.GroupID	and gp.FuncID = @funcId	
	ORDER BY g.GroupName ASC
	
GO
GRANT VIEW DEFINITION ON [dbo].[EAS_FunctionSelEdit] TO [vnteam]
GO
GRANT EXECUTE ON [dbo].[EAS_FunctionSelEdit] TO [bodbExtAccNet]
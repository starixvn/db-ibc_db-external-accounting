ALTER PROCEDURE [dbo].[EAS_FunctionSel]
AS
	/*
		Created: Dan
		Date: 2012-11-20
		Task: Get functions info
		DB: DBEAS/bodb_EAS
		
		Revisions:
		
		Parameter's Explanation:
	*/ 
SET NOCOUNT ON
	
	SELECT FuncID, FuncName, FuncKey, FuncDesc, ParentID, ParentName, DisplayOrder, ModifiedDate, isTest
	FROM eaFunction WITH(NOLOCK)
	ORDER BY parentID, DisplayOrder ASC
	
GO
GRANT VIEW DEFINITION ON [dbo].[EAS_FunctionSel] TO [vnteam]
GO
GRANT EXECUTE ON [dbo].[EAS_FunctionSel] TO [bodbExtAccNet]
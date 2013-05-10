ALTER PROCEDURE [dbo].[EAS_MenuSel]
AS
	/*
		Created: Johnson
		Date: 2012-05-15
		Task: Manage menu
		DB: DBEAS/bodb_EAS
		
		Revisions:
		
		Parameter's Explanation:
	*/	
SET NOCOUNT ON

	SELECT m.MenuID, m.MenuName, m.MenuDesc, 
		m.ParentID, m.ParentName, m.URL, 
		ISNULL(f.FuncID,0) as funcid , ISNULL(f.FuncName,'') as funcname,
		m.DisplayOrder, m.ModifiedDate, m.active
	FROM eaMenu m WITH(NOLOCK)
		LEFT JOIN eaFunction f WITH(NOLOCK) ON m.funcid = f.funcid
	ORDER BY m.parentID, m.DisplayOrder ASC
GO
GRANT VIEW DEFINITION ON [dbo].[EAS_MenuSel] TO [vnteam]
GO
GRANT EXECUTE ON [dbo].[EAS_MenuSel] TO [bodbExtAccNet]
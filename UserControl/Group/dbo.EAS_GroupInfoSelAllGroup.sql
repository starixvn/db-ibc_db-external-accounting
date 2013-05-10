ALTER PROCEDURE [dbo].[EAS_GroupInfoSelAllGroup]
AS
	/*
		Created: Dan
		Date: 2012-11-19
		Task: Select all group available
		DB: DBEAS/bodb_EAS
		Revisons:
		
		Parameter's Explanation:
	*/ 
SET NOCOUNT ON

	SELECT GroupID,GroupName
	FROM eaGroup WITH(NOLOCK)
	ORDER BY groupName

GO
GRANT VIEW DEFINITION ON [dbo].[EAS_GroupInfoSelAllGroup] TO [vnteam]
GO
GRANT EXECUTE ON [dbo].[EAS_GroupInfoSelAllGroup] TO [bodbExtAccNet]
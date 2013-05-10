ALTER PROCEDURE [dbo].[EAS_GroupInfoSelByGroupID]
	@GroupID	INT
AS
	/*
		Created: Dan
		Date: 2012-11-16
		Task: get group info by id
		DB: DBEAS/bodb_EAS
		
		Revisions:
		
		Parameter's Explanation:
	*/ 
SET NOCOUNT ON

SELECT groupID, GroupName, Description
FROM eaGroup WITH(NOLOCK)
WHERE groupID = @GroupID

GO
GRANT VIEW DEFINITION ON [dbo].[EAS_GroupInfoSelByGroupID] TO [vnteam]
GO
GRANT EXECUTE ON [dbo].[EAS_GroupInfoSelByGroupID] TO [bodbExtAccNet]
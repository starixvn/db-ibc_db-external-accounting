ALTER PROCEDURE [dbo].[EAS_UserInfoSelByUserID]
	@UserID		INT
AS
	/*
		Created: Dan
		Date: 2012-11-19
		Task: Get user's info
		DB: DBEAS/bodb_EAS
		
		Revisions:
		
		Parameter's Explanation:
	*/ 
SET NOCOUNT ON
	SELECT c.custid, c.username, c.firstname, c.lastname, g.groupID, g.groupname, ui.enabled
	FROM eaUserInfo ui WITH(NOLOCK)
		INNER JOIN bodb02.dbo.Customer c WITH(NOLOCK) ON ui.UserID = c.custid
		INNER JOIN eaGroup g WITH(NOLOCK) ON ui.groupID = g.groupID
	WHERE ui.UserID = @UserID

GO
GRANT VIEW DEFINITION ON [dbo].[EAS_UserInfoSelByUserID] TO [vnteam]
GO
GRANT EXECUTE ON [dbo].[EAS_UserInfoSelByUserID] TO [bodbExtAccNet]
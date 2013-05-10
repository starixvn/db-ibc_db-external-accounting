CREATE PROCEDURE [dbo].[EAS_UserInfoSel]
	@GroupID	INT = NULL,
	@Username	VARCHAR(50) = ''
AS
	/*
		Created: Dan
		Date: 2012-11-19
		Task: Get EAS's users
		DB: DBEAS/bodb_EAS
		
		Revisions:
		
		Parameter's Explanations:
	*/ 
SET NOCOUNT ON

	SELECT c.custid, c.username, c.firstname, c.lastname, g.groupid, g.groupname, ISNULL(creator.username,'') as creator, ui.CreatedDate, ui.enabled
	FROM eaUserInfo ui WITH(NOLOCK)
		INNER JOIN bodb02.dbo.Customer c WITH(NOLOCK) ON ui.userid = c.custid
		INNER JOIN eaGroup g WITH(NOLOCK) ON ui.groupID = g.groupID
		LEFT JOIN bodb02.dbo.Customer creator WITH(NOLOCK) ON ui.creator = creator.custid
	WHERE ui.GroupID = ISNULL(@GroupID,ui.GroupID)
		AND c.username LIKE ISNULL(@Username,c.username) + '%'
	ORDER BY ui.enabled DESC, g.groupName ASC, c.username ASC
GO
GRANT VIEW DEFINITION ON [dbo].EAS_UserInfoSel TO [vnteam]
GO
GRANT EXECUTE ON [dbo].EAS_UserInfoSel TO [bodbExtAccNet]
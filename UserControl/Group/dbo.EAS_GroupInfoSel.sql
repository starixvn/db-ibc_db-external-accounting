ALTER PROCEDURE [dbo].[EAS_GroupInfoSel]	
AS
	/*
		Created: Dan
		Date: 2012-11-15
		Task: Get groups 
		DB: DBEAS/bodb_EAS
		
		Revisions:
		
		Parameter's Explanation:
			
	*/	
SET NOCOUNT ON

	SELECT g.GroupID, 
		g.GroupName, 
		ISNULL(p.Users,0) as NoUsers, 
		ISNULL(g.Description,'') as Description, 
		ISNULL(c.username,'') as Creator, 
		g.createdDate
	FROM eaGroup g WITH(NOLOCK) 
		LEFT JOIN bodb02.dbo.Customer c WITH(NOLOCK) ON g.creator = c.custid
		LEFT JOIN 
		(
			SELECT GroupID, count(1) users
			FROM eaUserInfo WITH(NOLOCK)
			GROUP BY GroupID
		) p ON g.groupID = p.groupID
	ORDER BY groupName
GO
GRANT VIEW DEFINITION ON [dbo].[EAS_GroupInfoSel] TO [vnteam]
GO
GRANT EXECUTE ON [dbo].[EAS_GroupInfoSel] TO [bodbExtAccNet]

	
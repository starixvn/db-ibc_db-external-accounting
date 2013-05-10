ALTER PROCEDURE [dbo].[EAS_GroupInfoSelExternalGroup]	
AS
	/*
		Created: Dan
		Date: 2012-11-19
		Task: Get currency groups for external admin
		DB: DBEAS/bodb_EAS
		
		Revisions:
		
		Parameter's Explanation:
			
	*/	
SET NOCOUNT ON
	SELECT g.GroupID, 
		g.GroupName
	FROM eaGroup g WITH(NOLOCK) 
		LEFT JOIN dbo.eaGroupPolicy gp(NOLOCK) ON gp.GroupID=g.GroupID and FuncID=11 -- ExternalGroup function
	WHERE ISNULL(Policy,0)<2
	--groupName LIKE 'ACC%'	
	ORDER BY groupName
GO
GRANT VIEW DEFINITION ON [dbo].[EAS_GroupInfoSelExternalGroup] TO [vnteam]
GO
GRANT EXECUTE ON [dbo].[EAS_GroupInfoSelExternalGroup] TO [bodbExtAccNet]	
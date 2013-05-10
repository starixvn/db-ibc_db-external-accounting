ALTER PROCEDURE [dbo].[EAS_MenuSelByUserID]
	@userid		INT
AS 
	/*
		Created: Dan
		Date: 2012-11-21
		Task: Get menu by userid
		DB: DBEAS/bodb_EAS
		
		Revisions:
		
		Parameter's Explanation:
	*/
SET NOCOUNT ON
	DECLARE @tmpFunction TABLE (funcid int, policy int)
	
	INSERT INTO @tmpFunction (funcid, policy)
	SELECT CASE WHEN ISNULL(u.funcid ,0) = 0 THEN g.funcid ELSE u.funcid END as FuncID,
			CASE WHEN ISNULL(u.policy,0) < ISNULL(g.policy,0) THEN ISNULL(g.policy,0) ELSE ISNULL(u.policy,0) END as Policy
	FROM
	(
		SELECT FuncID,Policy 
		FROM eaUserPolicy WITH(NOLOCK) 
		WHERE userid = @userid
	) u
	FULL OUTER JOIN
	(
		SELECT FuncID,Policy 
		FROM eaUserInfo ui WITH(NOLOCK)
		INNER JOIN eaGroupPolicy gp WITH(NOLOCK) ON ui.groupid = gp.groupid
		WHERE ui.userid = @userid
	) g ON u.funcid = g.funcid
	
	SELECT
		m.ParentID,
		m.ParentName,
		m.MenuID,
		m.MenuName,
		m.URL,
		m.DisplayOrder,
		m.FuncID
	FROM eaMenu m WITH(NOLOCK) 	
		INNER JOIN @tmpFunction p ON p.funcid = m.funcid
	WHERE m.active = 1 AND p.policy > 0
	ORDER BY m.parentID, m.displayOrder
	
	SELECT f.funcid, f.funcName, f.funckey, t.policy, f.ParentID,  isTest
	FROM @tmpFunction t
		INNER JOIN eaFunction f WITH(NOLOCK) ON t.funcid = f.funcid
	WHERE t.policy > 0
	
GO
GRANT VIEW DEFINITION ON [dbo].[EAS_MenuSelByUserID] TO [vnteam]
GO
GRANT EXECUTE ON [dbo].[EAS_MenuSelByUserID] TO [bodbExtAccNet]
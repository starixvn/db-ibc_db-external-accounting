ALTER PROCEDURE [dbo].[Acc_CustomerIsSpecialSite]
	@UserName VARCHAR(30),
	@IsSpecialSite BIT = 0 OUTPUT 
AS
/*
	Created: 20160901@Elodie
	Task: check if the customer belongs to special site
	Database: DBPOLICY/bodb02
	
	Revision:
		- 20161031@Elodie: Change a type of parameter Username NVARCHAR(30) - > VARCHAR(30)
		- 20161111@Elodie: Check more member of group headline
	Param's Explanation:
*/
BEGIN
	SET NOCOUNT ON

	SELECT @IsSpecialSite = 0

	DECLARE @CustID INT, @RoleID TINYINT, @recommend INT, @site NVARCHAR(50), @GroupID SMALLINT = NULL

	SELECT @CustID = custid, @RoleID = roleID, @recommend = recommend, @site = site FROM customer WITH (NOLOCK) WHERE username = @UserName

	SELECT @GroupID = groupID FROM dbo.custAccount WITH (NOLOCK) WHERE custid = @CustID AND IsGroupHeadLine = 1

	IF @GroupID IS NOT NULL -- Headline
	BEGIN
		SELECT custid
		INTO #tmpCustGroup
		FROM dbo.custAccount WITH(NOLOCK) 
		WHERE groupID = @GroupID

		IF EXISTS ( SELECT 1
					FROM #tmpCustGroup cg
						INNER JOIN dbo.customer c WITH (NOLOCK) ON cg.custid = c.custid
						INNER JOIN dbo.site s WITH (NOLOCK) ON s.site = c.site
					WHERE SpecialGroup = 1 AND c.roleid BETWEEN 2 AND 4)
			OR EXISTS (	SELECT 1
						FROM #tmpCustGroup cg
							INNER JOIN dbo.customer c WITH (NOLOCK) ON cg.custid = c.custid
							INNER JOIN dbo.customer ag WITH (NOLOCK) ON c.recommend = ag.custid
							INNER JOIN dbo.site s WITH (NOLOCK) ON s.site = ag.site
						WHERE SpecialGroup = 1 AND c.roleid = 1)
			SELECT @IsSpecialSite = 1
	END
	ELSE
	BEGIN
		IF @RoleID = 1
		BEGIN
			IF EXISTS (	SELECT 1 
					FROM dbo.Customer c WITH (NOLOCK)	
						INNER JOIN dbo.Site s WITH (NOLOCK) ON c.site = s.site
					WHERE c.custid = @recommend AND s.SpecialGroup = 1)
				SELECT @IsSpecialSite = 1
		END
		ELSE
		BEGIN
			IF EXISTS (	SELECT 1 
					FROM dbo.Site s WITH (NOLOCK)
					WHERE s.site = @site AND s.SpecialGroup = 1)
				SELECT @IsSpecialSite = 1
		END
	END
END

GO
GRANT EXECUTE ON [Acc_CustomerIsSpecialSite] TO [bodbAdminNet]
GO
GRANT EXECUTE ON [Acc_CustomerIsSpecialSite] TO [bodbExtAccNet]
GO
GRANT VIEW DEFINITION ON [Acc_CustomerIsSpecialSite] TO [vnteam]


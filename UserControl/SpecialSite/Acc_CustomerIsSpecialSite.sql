ALTER PROCEDURE [dbo].[Acc_CustomerIsSpecialSite]
	@UserName VARCHAR(30),
	@IsSpecialSite BIT = 0 OUTPUT 
AS
/*
	Created: 20160901@Elodie
	Task: check if the customer belongs to special site
	Database: DBCust/CustDB
	
	Revision:
		- 20161031@Elodie: Change a type of parameter Username NVARCHAR(30) - > VARCHAR(30)
	Param's Explanation:
*/
BEGIN
	SET NOCOUNT ON

	SELECT @IsSpecialSite = 0
	DECLARE @RoleID TINYINT, @recommend INT, @site NVARCHAR(50)

	SELECT @RoleID = roleID, @recommend = recommend, @site = site FROM customer WITH (NOLOCK) WHERE username = @UserName

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

GO
GRANT EXECUTE ON [Acc_CustomerIsSpecialSite] TO [bodbAdminNet]
GO
GRANT EXECUTE ON [Acc_CustomerIsSpecialSite] TO [bodbExtAccNet]
GO
GRANT VIEW DEFINITION ON [Acc_CustomerIsSpecialSite] TO [vnteam]


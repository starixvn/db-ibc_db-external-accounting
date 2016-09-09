ALTER PROCEDURE [dbo].[Acc_CustomerIsInternalAdmin]
	@CustID INT,
	@IsInternalAdmin BIT = 0 OUTPUT 
AS
/*
	Created: 20160901@Elodie
	Task: check if the account is an internal admin
	Database: DBPOLICY/bodb02
	
	Revision:
	Param's Explanation:
*/
BEGIN
	SET NOCOUNT ON

	IF EXISTS (	SELECT 1 
				FROM dbo.acccustomer_1 ac WITH (NOLOCK)
					INNER JOIN dbo.custInfo ci WITH (NOLOCK) ON ci.custid = ac.custid
				WHERE ci.roleid > 4)
		SELECT @IsInternalAdmin = 1
END

GO
GRANT EXECUTE ON [Acc_CustomerIsInternalAdmin] TO [bodbExtAccNet]
GO
GRANT VIEW DEFINITION ON [Acc_CustomerIsInternalAdmin] TO [vnteam]


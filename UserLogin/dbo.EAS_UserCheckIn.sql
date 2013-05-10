ALTER PROCEDURE [dbo].[EAS_UserCheckIn]
	@custid			INT,
	@NetSessionID	VARCHAR(50),
	@on_userid		INT OUTPUT,
	@IP				NVARCHAR(50)
AS
	/*
		Created: Dan
		Date: 2012-11-16
		Task: user check in 
		DB: DBEAS/bodb_EAS
		
		Revisions:
		
		Parameter's Explanation:
	*/
SET NOCOUNT ON 

UPDATE eaOn_User WITH(UPDLOCK,ROWLOCK) 
SET iskickedout = 1 
WHERE custid = @custid

INSERT INTO eaOn_User (custid, NetSessionID, isKickedOut, IP) 
VALUES (@custid, @NetSessionID, 0, @IP)

SELECT @on_userid = SCOPE_IDENTITY()
	
GO
GRANT VIEW DEFINITION ON [dbo].[EAS_UserCheckIn] TO [vnteam]
GO
GRANT EXECUTE ON [dbo].[EAS_UserCheckIn] TO [bodbExtAccNet]
ALTER PROCEDURE [dbo].[EAS_UserRecheckIn]
	@On_UserID		INT,
	@isKickedOut	BIT = 0 OUTPUT
AS
	/*
		Created: Dan
		Date: 2012-11-16
		Task: User re-checkin 
		DB: DBEAS/bodb_EAS
		Revisions:
		
		Paramter's Explanation:
	*/
SET NOCOUNT ON

	IF EXISTS (SELECT 1 FROM eaOn_User WITH(NOLOCK) WHERE on_userid = @on_userid AND isKickedOut = 1)
		SELECT @isKickedOut = 1
	ELSE
	BEGIN
		SELECT @isKickedOut = 0
		
		UPDATE eaOn_User WITH(UPDLOCK,ROWLOCK)
		SET reload_time = getdate()
		WHERE on_userid = @on_userid
		
		IF @@ROWCOUNT = 0
			SELECT @isKickedOut = 1
	END

GO 
GRANT VIEW DEFINITION ON [dbo].[EAS_UserRecheckIn] TO [vnteam]
GO
GRANT EXECUTE ON [dbo].[EAS_UserRecheckIn] TO [bodbExtAccNet]
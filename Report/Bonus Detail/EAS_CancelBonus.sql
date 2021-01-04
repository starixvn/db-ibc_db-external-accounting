CREATE PROCEDURE dbo.EAS_CancelBonus
(
	@TransId BIGINT
	,@ErrCode INT = 0 OUTPUT
	,@ErrMsg NVARCHAR(200) = '' OUTPUT
)
AS
BEGIN
	SET NOCOUNT ON;
	
	DECLARE @Time INT

	SELECT @Time = (DATEDIFF(SECOND, CreationDate, GETDATE()) - 48 * 60 * 60) FROM dbo.BonusTrans WITH(NOLOCK) WHERE TransId = @TransId

	IF @Time > 0
	BEGIN
		SELECT @ErrCode = 101, @ErrMsg = 'The selected Bonus was created more than 48 hours ago. You cannot cancel it.'
		RETURN
	END

	UPDATE b WITH(ROWLOCK)
		SET b.StatusId = 2
	FROM dbo.BonusTrans b 
	WHERE TransId = @TransId AND StatusId = 0

	IF @@ROWCOUNT = 0
	BEGIN
		SELECT @ErrCode = 102, @ErrMsg = 'The selected Bonus status is not Pending anymore, you cannot cancel it.'
		RETURN
	END

END
GO
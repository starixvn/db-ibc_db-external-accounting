ALTER PROCEDURE [dbo].[EAS_MenuUpdStatus]
	@UserID		INT,
	@MenuID		INT,
	@Active		BIT,	
	@IP			VARCHAR(50) = '',
	@ErrCode	INT = 0 OUTPUT,
	@ErrMsg		VARCHAR(500) = '' OUTPUT
AS
	/*
		Created: Dan
		Date: 2012-11-21
		Task: Update status of menu
		DB: DBEAS/bodb_EAS
		
		Revisions:
			
		Parameter's Explanation:
	*/
SET NOCOUNT ON
	DECLARE @startRun datetime  
		,@endRun datetime  
		,@duration int		
	
	SET @startRun=GETDATE()
	
	EXEC dbo.EAS_UserCheckPermission @UserID = @UserID ,@FuncKey = 'ManageMenu', @ErrCode = @ErrCode OUTPUT, @ErrMsg = @ErrMsg OUTPUT
	
	IF @ErrCode > 0
		RETURN
	
	DECLARE @db_Active BIT
	
	SELECT @db_Active = active FROM eaMenu WITH(NOLOCK) WHERE MenuID = @MenuID
	
	IF @@ROWCOUNT = 0 OR @db_Active = @Active
		RETURN
		
	UPDATE eaMenu WITH(UPDLOCK,ROWLOCK)
	SET active = @Active
	WHERE MenuID = @MenuID
	
	DECLARE @LogData NVARCHAR(500)
	SELECT @LogData = '<EAS_MenuUpdStatus>' +  
							'<MenuID>'+ ISNULL(CONVERT(VARCHAR(20),@MenuID),'') + '</MenuID>'+
							'<Active>'+ 
								'<Old>' + ISNULL(cast(@db_Active as varchar(10)),'') + '</Old>' +
								'<New>' + ISNULL(cast(@Active as varchar(10)),'') + '</New>' +
							'</Active>'+ 
							'<IP>' + COALESCE(@IP,'') + '</IP>'+
						'</EAS_MenuUpdStatus>'
	
	SET @endRun = GETDATE()  
	SET @duration  = DATEDIFF (MILLISECOND,@startRun,@endRun)   

	EXEC DBLOG.bodb_CustomerLog.[dbo].[EAS_WriteLog_UserLog_UserControl]
			@custID = @MenuID,
			@TrackingValue = @LogData,
			@userid = @UserID,
			@TypeID = 2,
			@actionid = 20105,
			@duration = @duration 
	
GO
GRANT VIEW DEFINITION ON [dbo].[EAS_MenuUpdStatus] TO [vnteam]
GO
GRANT EXECUTE ON [dbo].[EAS_MenuUpdStatus] TO [bodbExtAccNet]
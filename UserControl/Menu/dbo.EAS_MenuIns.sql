ALTER PROCEDURE [dbo].[EAS_MenuIns]
	@UserID		INT,
	@MenuID			INT = 0 OUTPUT,
	@MenuName		NVARCHAR(50),
	@MenuDesc		NVARCHAR(100)= NULL,
	@URL			VARCHAR(500) = NULL,
	@FuncID			INT,
	@ParentID		INT = 0,
	@ParentName		NVARCHAR(50) = '',
	@DisplayOrder	INT,
	@Active		BIT = 1,
	@IP				VARCHAR(50),
	@ErrCode		INT  = 0 OUTPUT,
	@ErrMsg			VARCHAR(500) = '' OUTPUT
AS
	/*
		Created: Dan
		Date: 2012-11-21
		Task: Edit menu info
		DB: DBEAS/bodb_EAS
		
		Revisions:
			
		Parameter's Explanations:
	*/ 
SET NOCOUNT ON
	DECLARE @startRun datetime  
		,@endRun datetime  
		,@duration int		
	
	SET @startRun=GETDATE()
	
	EXEC dbo.EAS_UserCheckPermission @UserID = @UserID ,@FuncKey = 'ManageMenu', @ErrCode = @ErrCode OUTPUT, @ErrMsg = @ErrMsg OUTPUT
	
	IF @ErrCode > 0
		RETURN
	
	IF EXISTS (SELECT 1 FROM eaMenu WITH(NOLOCK) WHERE MenuName = @MenuName)
	BEGIN
		SELECT @ErrMsg = 'This name is not available',
				@ErrCode = 101
		RETURN
	END
	
	INSERT INTO [bodb_EAS].[dbo].[eaMenu]
           ([MenuName]
           ,[MenuDesc]
           ,[Url]
           ,[FuncID]
           ,[ParentID]
           ,[ParentName]
           ,[CreatedDate]
           ,[ModifiedDate]
           ,[DisplayOrder]
           ,[Creator]
           , Modifier
           ,[active])
     VALUES(
			@MenuName, 
			@MenuDesc, 
			@URL, 
			@FuncID, 
			@ParentID, 
			@ParentName, 
			GETDATE(), 
			GETDATE(), 
			@DisplayOrder, 
			@UserID, 
			@UserID, 
			@Active
		)
	
	SELECT @MenuID = SCOPE_IDENTITY()
	
	DECLARE @LogData NVARCHAR(500)
	SELECT @LogData = '<EAS_MenuIns>' + 
						'<MenuName>' + COALESCE(@MenuName, '') + '</MenuName>' +
						'<MenuDesc>' + COALESCE(@MenuDesc, '') + '</MenuDesc>' +
						'<URL>' + COALESCE(@URL, '') + '</URL>' +
						'<FuncID>' + COALESCE(CONVERT(VARCHAR(10),@FuncID), '') + '</FuncID>' +
						'<ParentID>' + COALESCE(CONVERT(VARCHAR(10),@ParentID), '') + '</ParentID>' +
						'<ParentName>' + COALESCE(@ParentName, '') + '</ParentName>' +
						'<DisplayOrder>' + COALESCE(CONVERT(VARCHAR(10),@DisplayOrder), '') + '</DisplayOrder>' +
						'<Active>' + COALESCE(CONVERT(VARCHAR(10),@Active), '') + '</Active>' +						
						'<IP>'	+ COALESCE(@IP, '') + '</IP>' +
					'</EAS_MenuIns>'
		 
	SET @endRun = GETDATE()  
	SET @duration  = DATEDIFF (MILLISECOND,@startRun,@endRun)   

	EXEC DBLOG.bodb_CustomerLog.[dbo].[EAS_WriteLog_UserLog_UserControl]
		@custID = @MenuID,
		@TrackingValue = @LogData,
		@userid = @UserID,
		@TypeID = 2,
		@actionid = 20103,
		@duration = @duration
	
GO
GRANT VIEW DEFINITION ON [dbo].[EAS_MenuIns] TO [vnteam]
GO
GRANT EXECUTE ON [dbo].[EAS_MenuIns] TO [bodbExtAccNet] 
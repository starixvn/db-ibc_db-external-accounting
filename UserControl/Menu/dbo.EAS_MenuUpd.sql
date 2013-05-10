ALTER PROCEDURE [dbo].[EAS_MenuUpd]
	@UserID		INT,
	@MenuID			INT,
	@MenuName		NVARCHAR(50),
	@MenuDesc		NVARCHAR(100)= NULL,
	@URL			VARCHAR(500) = NULL,
	@FuncID			INT,
	@ParentID		INT,
	@ParentName		NVARCHAR(50),
	@DisplayOrder	INT,	
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
	
	IF EXISTS (SELECT 1 FROM eaMenu WITH(NOLOCK) WHERE MenuID <> @MenuID AND MenuName = @MenuName)
	BEGIN
		SELECT @ErrMsg = 'This menu''s name is in use',
			@ErrCode = 101
		RETURN
	END
	
	DECLARE @db_MenuName	NVARCHAR(50),
			@db_MenuDesc	NVARCHAR(100),
			@db_URL			VARCHAR(500),
			@db_FuncID		INT,
			@db_ParentID	INT,
			@db_ParentName	NVARCHAR(50),
			@db_DisplayOrder INT			
	
	SELECT @db_MenuName	= MenuName,
			@db_MenuDesc = MenuDesc,
			@db_URL		 = url,
			@db_FuncID	 = funcID,
			@db_ParentID = parentID,
			@db_ParentName = parentName,
			@db_DisplayOrder = DisplayOrder
	FROM eaMenu WITH(NOLOCK)
	WHERE MenuID = @MenuID
	
	IF 	@db_MenuName	= @MenuName AND
		@db_MenuDesc = @MenuDesc AND
		@db_URL		 = @url AND
		@db_FuncID	 = @funcID AND
		@db_ParentID = @parentID AND
		@db_ParentName = @parentName AND
		@db_DisplayOrder = @DisplayOrder
	RETURN
	
	UPDATE eaMenu WITH(UPDLOCK,ROWLOCK)
	SET MenuName = @MenuName,
		MenuDesc = @MenuDesc,
		URL		 = @url,
		FuncID	 = @funcID,
		ParentID = @parentID,
		ParentName = @parentName,
		DisplayOrder = @DisplayOrder,
		ModifiedDate = current_timestamp,
		Modifier = @UserID
	WHERE MenuID = @MenuID
	
	IF @db_MenuName <> @MenuName
	BEGIN
		UPDATE eaMenu WITH(UPDLOCK,ROWLOCK)
		SET ParentName = @MenuName
		WHERE ParentID = @MenuID
	END
	
	DECLARE @LogData NVARCHAR(1000)
	SELECT @LogData = '<EAS_MenuUpd>' +  
						'<MenuID>'+ ISNULL(CONVERT(VARCHAR(20),@MenuID),'') + '</MenuID>'+
						'<MenuName>'+ 
							'<Old>' + ISNULL(@db_MenuName,'') + '</Old>' +
							'<New>' + ISNULL(@MenuName,'') + '</New>' +
						'</MenuName>'+ 
						'<MenuDesc>'+ 
							'<Old>' + ISNULL(@db_MenuDesc,'') + '</Old>' +
							'<New>' + ISNULL(@MenuDesc,'') + '</New>' +
						'</MenuDesc>'+
						'<URL>'+ 
							'<Old>' + ISNULL(@db_URL,'') + '</Old>' +
							'<New>' + ISNULL(@URL,'') + '</New>' +
						'</URL>'+
						'<FuncID>'+ 
							'<Old>' + ISNULL(CONVERT(VARCHAR(20),@db_FuncID),'') + '</Old>' +
							'<New>' + ISNULL(CONVERT(VARCHAR(20),@FuncID),'') + '</New>' +							
						'</FuncID>'+
						'<ParentID>'+ 
							'<Old>' + ISNULL(CONVERT(VARCHAR(20),@db_ParentID),'') + '</Old>' +
							'<New>' + ISNULL(CONVERT(VARCHAR(20),@ParentID),'') + '</New>' +					
						'</ParentID>'+												
						'<ParentName>'+ 
							'<Old>' + ISNULL(@db_ParentName,'') + '</Old>' +
							'<New>' + ISNULL(@ParentName,'') + '</New>' +
						'</ParentName>'+					
						'<DisplayOrder>'+ 
							'<Old>' + ISNULL(CONVERT(VARCHAR(20),@db_DisplayOrder),'') + '</Old>' +
							'<New>' + ISNULL(CONVERT(VARCHAR(20),@DisplayOrder),'') + '</New>' +
						'</DisplayOrder>'+							
						'<IP>' + COALESCE(@IP,'') + '</IP>'+										
					'</EAS_MenuUpd>'
	SET @endRun = GETDATE()  
	SET @duration  = DATEDIFF (MILLISECOND,@startRun,@endRun)   

	EXEC DBLOG.bodb_CustomerLog.[dbo].[EAS_WriteLog_UserLog_UserControl]
			@custID = @MenuID,
			@TrackingValue = @LogData,
			@userid = @UserID,
			@TypeID = 2,
			@actionid = 20104,
			@duration = @duration  
		
GO
GRANT VIEW DEFINITION ON [dbo].[EAS_MenuUpd] TO [vnteam]
GO
GRANT EXECUTE ON [dbo].[EAS_MenuUpd] TO [bodbExtAccNet]
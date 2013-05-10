CREATE PROCEDURE [dbo].[EAS_FunctionUpd]
	@UserID	INT,
	@FuncID		INT,
	@FuncName	VARCHAR(50),
	@FuncDesc	VARCHAR(100),
	@ParentID	INT,
	@ParentName VARCHAR(50),
	@DisplayOrder INT,
	@OldAssigedGroupIDs VARCHAR(2000),
	@AssigedGroupIDs VARCHAR(2000)='',
	@IP			VARCHAR(50),
	@ErrCode	INT = 0 OUTPUT,
	@ErrMsg		VARCHAR(500) = '' OUTPUT	
AS
	/*
		Created: Dan
		Date: 2012-11-21
		Task: Update function info
		DB: DBEAS/bodb_EAS
		
		Revisions:
			
		Parameter's Explanation:
	*/ 
SET NOCOUNT ON

	DECLARE @startRun datetime  
		,@endRun datetime  
		,@duration int		
	
	SET @startRun=GETDATE()
	
	EXEC dbo.EAS_UserCheckPermission @UserID = @UserID ,@FuncKey = 'ManageFunction', @ErrCode = @ErrCode OUTPUT, @ErrMsg = @ErrMsg OUTPUT
	
	IF @ErrCode > 0
		RETURN
		
	DECLARE @Groups TABLE (GroupID INT)	

	DECLARE @db_FuncName	VARCHAR(50),
			@db_FuncDesc	VARCHAR(100),
			@db_ParentID	INT,
			@db_ParentName	VARCHAR(50),
			@db_DisplayOrder INT
	
	SELECT @db_FuncName	= FuncName,
			@db_ParentID = ParentID,
			@db_ParentName = ParentName,
			@db_DisplayOrder = DisplayOrder,
			@db_FuncDesc = FuncDesc
	FROM eaFunction WITH(NOLOCK)
	WHERE FuncID = @FuncID
	
	IF @@ROWCOUNT = 0
	BEGIN
		SELECT @ErrMsg = 'This function does not exist',
			@ErrCode = 101
		RETURN
	END
	
	IF @db_FuncName	= @FuncName AND
		@db_ParentID = @ParentID AND
		@db_ParentName = @ParentName AND
		@db_DisplayOrder = @DisplayOrder AND
		@db_FuncDesc = @FuncDesc AND 
		@OldAssigedGroupIDs = @AssigedGroupIDs
	RETURN
	
	IF (ISNULL(@AssigedGroupIDs,'')	<>'')
		INSERT INTO @Groups (GroupID)
		SELECT val
		FROM dbo.[f_EAS_strSplit] (@AssigedGroupIDs,',')	
		
	UPDATE eaFunction WITH(UPDLOCK,ROWLOCK)
	SET FuncName	= @FuncName,
		ParentID = @ParentID,
		ParentName = @ParentName,
		DisplayOrder = @DisplayOrder,
		ModifiedDate = current_timestamp,
		FuncDesc = @FuncDesc
	WHERE FuncID = @FuncID
	
	IF @db_FuncName <> @FuncName
	BEGIN
		UPDATE eaFunction WITH(UPDLOCK,ROWLOCK)
		SET ParentName = @FuncName
		WHERE ParentID = @FuncID
	END
	
	--assgign policy
	IF (ISNULL(@AssigedGroupIDs,'')	<>'')
	BEGIN
		UPDATE gp WITH(UPDLOCK,ROWLOCK)
		SET gp.Policy = CASE WHEN g.GroupID IS NOT NULL THEN 2 ELSE 0 END--host policy
		FROM eaGroupPolicy gp 
			LEFT JOIN @Groups g ON gp.groupid = g.groupid 
		WHERE gp.FuncID = @FuncID
		
		INSERT INTO eaGroupPolicy (GroupID, FuncID, Policy)
		SELECT g.GroupID, @FuncID, 2
		FROM @Groups g
			LEFT OUTER JOIN eaGroupPolicy gp WITH(NOLOCK) ON gp.groupID = g.GroupID  AND gp.FuncID = @FuncID
		WHERE gp.FuncID IS NULL	
	END	
		
	
	DECLARE @LogData NVARCHAR(1000)
	SELECT @LogData = '<EAS_FunctionUpd>' +  
						'<FuncID>'+ ISNULL(CONVERT(VARCHAR(20),@FuncID),'') + '</FuncID>'+
						'<FuncName>'+ 
							'<Old>' + ISNULL(@db_FuncName,'') + '</Old>' +
							'<New>' + ISNULL(@FuncName,'') + '</New>' +
						'</FuncName>'+ 
						'<FuncDesc>'+ 
							'<Old>' + ISNULL(@db_FuncDesc,'') + '</Old>' +
							'<New>' + ISNULL(@FuncDesc,'') + '</New>' +
						'</FuncDesc>'+						
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
						'<AssigedGroups>'+ 
							'<Old>' + ISNULL(@OldAssigedGroupIDs,'') + '</Old>' +
							'<New>' + ISNULL(@AssigedGroupIDs,'') + '</New>' +
						'</AssigedGroups>'+	
						'<IP>' + COALESCE(@IP,'') + '</IP>'+										
					'</EAS_FunctionUpd>'
	SET @endRun = GETDATE()  
	SET @duration  = DATEDIFF (MILLISECOND,@startRun,@endRun)   

	EXEC DBLOG.bodb_CustomerLog.[dbo].[EAS_WriteLog_UserLog_UserControl]
			@custID = @FuncID,
			@TrackingValue = @LogData,
			@userid = @UserID,
			@TypeID = 2,
			@actionid = 20101,
			@duration = @duration  
	
GO
GRANT VIEW DEFINITION ON [dbo].[EAS_FunctionUpd] TO [vnteam]
GO
GRANT EXECUTE ON [dbo].[EAS_FunctionUpd] TO [bodbExtAccNet]
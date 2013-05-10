ALTER PROCEDURE [dbo].[EAS_FunctionIns]
	@UserID			INT,
	@FuncID			INT = 0 OUTPUT,
	@FuncName		VARCHAR(50),
	@FuncDesc		NVARCHAR(100)= NULL,
	@FuncKey		NVARCHAR(100),
	@ParentID		INT = 0,
	@ParentName		VARCHAR(50) = NULL,
	@DisplayOrder	INT,	
	@isTest			BIT = 0,
	@AssigedGroupIDs VARCHAR(2000)='',
	@IP				VARCHAR(50),
	@ErrCode		INT = 0 OUTPUT,
	@ErrMsg			VARCHAR(500) = '' OUTPUT
AS
	/*
		Created: Dan
		Date: 2012-11-20
		Task: Add new funtion
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
	
	IF EXISTS (SELECT 1 FROM eaFunction WITH(NOLOCK) WHERE FuncKey = @FuncKey)
	BEGIN
		SELECT @ErrMsg = 'This function''s key not available',
				@ErrCode = 101
		RETURN
	END
	
	DECLARE @Groups TABLE (GroupID INT)	
		IF (ISNULL(@AssigedGroupIDs,'')	<>'')
			INSERT INTO @Groups (GroupID)
			SELECT val
			FROM dbo.[f_EAS_strSplit] (@AssigedGroupIDs,',')	
	
	INSERT INTO dbo.[eaFunction]
           ([FuncName]
           ,[FuncDesc]
           ,[FuncKey]
           ,[ParentID]
           ,[ParentName]
           ,[CreatedDate]
           ,[ModifiedDate]
           ,[Creator]
           ,[Modifier]
           ,[DisplayOrder]
           ,[isTest]
           )
     VALUES
           (@FuncName
           ,@FuncDesc
           ,@FuncKey
           ,@ParentID
           ,@ParentName
           ,GETDATE()
           ,GETDATE()
           ,@UserID
           ,@UserID
           ,@DisplayOrder
           ,@isTest
           )
	
	SELECT @FuncID = SCOPE_IDENTITY()
	
	--initial user policy
	INSERT INTO eaUserPolicy (UserID, FuncID, Policy)
	SELECT userid, @funcid, 0
	FROM eaUserInfo WITH(NOLOCK)
	
	--initial group policy
	INSERT INTO eaGroupPolicy (GroupID, FuncID, Policy)
	SELECT groupID, @funcid, 0
	FROM eaGroup WITH(NOLOCK)
	
	--assgign policy
	IF (ISNULL(@AssigedGroupIDs,'')	<>'')
	BEGIN
		UPDATE gp WITH(UPDLOCK,ROWLOCK)
		SET gp.Policy = 2 --host policy
		FROM eaGroupPolicy gp 
			INNER JOIN @Groups g ON gp.groupid = g.groupid AND gp.FuncID = @FuncID
	END		
	
	DECLARE @LogData NVARCHAR(500)
	SELECT @LogData = '<EAS_FunctionIns>' + 
						'<FuncName>' + COALESCE(@FuncName, '') + '</FuncName>' +
						'<FuncDesc>' + COALESCE(@FuncDesc, '') + '</FuncDesc>' +
						'<FuncKey>' + COALESCE(@FuncKey, '') + '</FuncKey>' +
						'<ParentID>' + COALESCE(CONVERT(VARCHAR(10),@ParentID), '') + '</ParentID>' +
						'<ParentName>' + COALESCE(@ParentName, '') + '</ParentName>' +
						'<DisplayOrder>' + COALESCE(CONVERT(VARCHAR(10),@DisplayOrder), '') + '</DisplayOrder>' +
						'<isTest>' + COALESCE(CONVERT(VARCHAR(10),@isTest), '') + '</isTest>' +
						'<AssigedGroup>' + COALESCE(CONVERT(VARCHAR(10),@AssigedGroupIDs), '') + '</AssigedGroup>' +
						'<IP>'	+ COALESCE(@IP, '') + '</IP>' +
					'</EAS_FunctionIns>'
		 
	SET @endRun = GETDATE()  
	SET @duration  = DATEDIFF (MILLISECOND,@startRun,@endRun)   

	EXEC DBLOG.bodb_CustomerLog.[dbo].[EAS_WriteLog_UserLog_UserControl]
		@custID = @FuncId,
		@TrackingValue = @LogData,
		@userid = @UserID,
		@TypeID = 2,
		@actionid = 20100,
		@duration = @duration

GO
GRANT VIEW DEFINITION ON [dbo].[EAS_FunctionIns] TO [vnteam]
GO
GRANT EXECUTE ON [dbo].[EAS_FunctionIns] TO [bodbExtAccNet]
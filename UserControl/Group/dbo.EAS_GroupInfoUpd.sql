ALTER PROCEDURE [dbo].[EAS_GroupInfoUpd]
	@UserID		INT,
	@GroupID		INT,
	@GroupName		NVARCHAR(100) = '',
	@Description	NVARCHAR(200) = NULL,
	@IP				VARCHAR(50),
	@ErrCode		INT = 0 OUTPUT,
	@ErrMsg			VARCHAR(500) = '' OUTPUT
AS
	/*
		Created: Dan
		Date: 2012-11-15
		Task: Update group info
		DB: DBEAS/bodb_EAS
		
		Revisions:
			
		Parameter's Explanation:
	*/
SET NOCOUNT ON

	DECLARE @startRun datetime  
		,@endRun datetime  
		,@duration int		
	
	SET @startRun=GETDATE()
	
	EXEC dbo.EAS_UserCheckPermission @UserID = @UserID ,@FuncKey = 'ManageGroup', @ErrCode = @ErrCode OUTPUT, @ErrMsg = @ErrMsg OUTPUT
	
	IF @ErrCode > 0
		RETURN
		
	DECLARE @db_GroupName VARCHAR(100),
			@db_Description VARCHAR(200)	
	
	IF EXISTS (SELECT 1 
			FROM eaGroup WITH(NOLOCK)
			WHERE GroupName = @GroupName AND GroupID <> @GroupID
	)
	BEGIN
		SELECT @ErrMsg = 'This group''s name is in use',
				@ErrCode = 100
		RETURN
	END
	
	SELECT @db_GroupName = GroupName, @db_Description = Description
	FROM eaGroup WITH(NOLOCK)
	WHERE GroupID = @GroupID
		
	UPDATE eaGroup WITH(UPDLOCK,ROWLOCK)
	SET GroupName	 = @GroupName,
		Description = @Description		
	WHERE GroupID	 = @GroupID
	
	DECLARE @LogData NVARCHAR(500)	
	
	SELECT @LogData = 
					'<EAS_GroupInfoUpd>'+
						'<Groupname>'+
							'<Old>' + ISNULL([dbo].[f_EAS_EncodeXMLValue](@db_GroupName),'') + '</Old>' +
							'<New>' + ISNULL([dbo].[f_EAS_EncodeXMLValue](@GroupName),'') + '</New>' +
						'</Groupname>'+
						'<GroupDescription>'+
							'<Old>' + ISNULL([dbo].[f_EAS_EncodeXMLValue](@db_Description),'') + '</Old>' +
							'<New>' + ISNULL([dbo].[f_EAS_EncodeXMLValue](@Description),'') + '</New>' +
						'</GroupDescription>'+
					'</EAS_GroupInfoUpd>'				

	SET @endRun = GETDATE()  
	SET @duration  = DATEDIFF (MILLISECOND,@startRun,@endRun)   

	EXEC DBLOG.bodb_CustomerLog.[dbo].[EAS_WriteLog_UserLog_UserControl]
			@custID = @GroupID,
			@TrackingValue = @LogData,
			@userid = @UserID,
			@TypeID = 0,
			@actionid = 20001,
			@duration = @Duration  
	
GO
GRANT VIEW DEFINITION ON [dbo].[EAS_GroupInfoUpd] TO [vnteam]
GO
GRANT EXECUTE ON [dbo].[EAS_GroupInfoUpd] TO [bodbExtAccNet]

	
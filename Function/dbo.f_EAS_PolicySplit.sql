ALTER FUNCTION [dbo].[f_EAS_PolicySplit]
(
	@string NVARCHAR( 4000),
	@splitter1 CHAR( 1),
	@splitter2 CHAR(1) 
)
RETURNS @res TABLE 
( 
	id		INT PRIMARY KEY, 
	funcid	VARCHAR(10),	
	policy	VARCHAR(10)
)
AS
	/*
		Created: Dan
		Date: 2012-11-19
		Task: function support to split string 
		DB: DBEAS/bodb_EAS
		Original Function: [f_RMS_PolicySplit]
		Revisions:
		
		Parameter's Explanation:
			-@string : string need to split ex: '7,1;5,2;4,0'
			-@splitter1: character to separate substring ex: ';'
			-@splitter2: character to separate funcid and policy ex: ','
	*/
BEGIN

	DECLARE @tmp TABLE (val VARCHAR(100))
	DECLARE @val		VARCHAR(100),
			@charindex	INT,
			@i			INT,
			@funcid		VARCHAR(10), 
			@policy		VARCHAR(10)
	
	SELECT @i  = 1
	
	INSERT INTO @tmp SELECT val FROM f_EAS_strSplit(@string,@splitter1)
	
	WHILE (1=1)
	BEGIN
		SELECT top 1 @val = val FROM @tmp
		
		IF @@ROWCOUNT = 0
			BREAK

		SELECT @charindex = CHARINDEX(@splitter2,@val)
		
		SELECT @funcid = SUBSTRING (@val,1,@charindex - 1),
				@policy= SUBSTRING (@val,@charindex + 1,datalength(@val) - @charindex)
		
		INSERT INTO @res (id, funcid, policy)
		VALUES (@i, @funcid, @policy)
		
		DELETE @tmp WHERE val = @val

		SET @i = @i + 1
	END

	RETURN
END
	
	
GO
GRANT VIEW DEFINITION ON [dbo].[f_EAS_PolicySplit] TO [vnteam]
GO
GRANT SELECT ON [dbo].[f_EAS_PolicySplit] TO [bodbExtAccNet]

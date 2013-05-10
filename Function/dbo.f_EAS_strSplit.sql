ALTER FUNCTION  [dbo].[f_EAS_strSplit]  
(
	@string NVARCHAR( 4000),
	@splitter CHAR( 1) 
)
RETURNS @res TABLE 
( 
	id INT PRIMARY KEY, 
	rank INT, 
	val NVARCHAR( 4000) 
)
AS
	/*
		Created: Dan
		Date: 2012-11-19
		Task: function support to split string 
		DB: DBEAS/bodb_EAS
		Original SP: [f_RMS_strSplit]
		
		Revisions:
		
		Parameter's Explanation:
	*/

BEGIN
     IF SUBSTRING ( @string, len ( @string), 1)<>@splitter
          SET @string= @string+@splitter
          
     DECLARE @start INT,
			 @word NVARCHAR(4000), 
			 @charindex INT, 
			 @i INT
			 
     SET @i=1
     SET @start=1
     SET @charindex= CHARINDEX( @splitter, @string, @start)
     
     WHILE (@charindex <> 0)
     BEGIN
          SET @word= SUBSTRING( @string, @start, @charindex - @start)
          SET @start= @charindex +1
          SET @charindex= CHARINDEX( @splitter, @string, @start)
          INSERT INTO @res  VALUES ( @start, @i, @word)
          SET @i=@i+1
     END
     RETURN
END

GO
GRANT VIEW DEFINITION ON [dbo].[f_EAS_strSplit] TO [vnteam]
GO
GRANT SELECT ON [dbo].[f_EAS_strSplit] TO [bodbExtAccNet]
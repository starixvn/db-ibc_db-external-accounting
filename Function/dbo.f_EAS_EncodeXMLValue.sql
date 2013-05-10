CREATE FUNCTION [dbo].[f_EAS_EncodeXMLValue](@value NVARCHAR(MAX))
RETURNS NVARCHAR(MAX)
AS
/* 
Created: Dan
Date: 2012-11-21
Task: ViewLog function 
DB: DBEAS/bodb_EAS
Original: DB02/bodb02/dbo/f_EncodeXMLValue

Revisions:
	
Param's Explanation:	
*/
BEGIN
	/*
		# &amp; refers to an ampersand (&) 
		# &lt; refers to a less-than symbol (<) 
		# &gt; refers to a greater-than symbol (>) 
		# &quot; refers to a double-quote mark (") 
		# &apos; refers to an apostrophe (')	
	*/
		
	SELECT @value = REPLACE(@value, '&', '&amp;')
	SELECT @value = REPLACE(@value, '<', '&lt;')
	SELECT @value = REPLACE(@value, '>', '&gt;')
	SELECT @value = REPLACE(@value, '"', '&quot;')
	SELECT @value = REPLACE(@value, '''', '&apos;')
	
	RETURN @value
END

GO
GRANT EXECUTE ON [dbo].[f_EAS_EncodeXMLValue] TO [bodbExtAccNet]
GO
GRANT VIEW DEFINITION ON [dbo].[f_EAS_EncodeXMLValue] TO [vnteam]
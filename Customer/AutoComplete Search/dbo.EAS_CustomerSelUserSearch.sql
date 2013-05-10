ALTER PROC [dbo].[EAS_CustomerSelUserSearch]
	@custid int,
	@username nvarchar(30),
	@groupname varchar(50)	
AS

/*
Created: 20121105@Dan
Task : Select downline list of custId based on query string. Used for AutoComplete by "Account Info".
DB: DBEAS/bodb_EAS
Original: [Acc_CustomerSelUserSearch]

Revisions:
    - 20130121@Dan: change linked server DB06 to DBACC, Move sp from DB053/bodb02 to DBEAS/bodb_EAS
Param's Explanation:
• @custid: User who are logging in.
• @username: part of downline's username.
*/
SET ARITHABORT ON -- don't remove it, can cause performance problem
SET NOCOUNT ON

IF ISNULL(@username,'')='' OR ISNULL(@groupname,'')='' 
	RETURN

DECLARE @tmpUsername TABLE(username VARCHAR(30),searchcount int)

INSERT INTO @tmpUsername (username,searchcount)
SELECT TOP 10 username, searchcount
FROM bodb02.dbo.CustSearch WITH (NOLOCK) 
WHERE userid=@custid 
	AND username LIKE '%' + @username  + '%'
	AND groupname = @groupname		
ORDER BY [searchcount] DESC

IF @@ROWCOUNT < 10
BEGIN
	INSERT INTO @tmpUsername (username,searchcount)
	SELECT TOP 10 username, -1 AS searchcount
	FROM DBACC.bodb02.dbo.custinfo WITH (NOLOCK)
	WHERE roleid < 5
		AND username LIKE @username  + '%'
		AND srecommend IN (SELECT custid FROM bodb_AGE.dbo.Acc_CustGroup WITH(NOLOCK) WHERE GroupName = @groupname)		
	ORDER BY username
END

SELECT TOP 10 username 
FROM 
	(	SELECT 
			username, searchcount
		FROM 
			@tmpUsername  
		WHERE 
			searchcount >= 0
		UNION ALL 
		SELECT 
			username, searchcount
		FROM  
			@tmpUsername 
		WHERE 
			username NOT IN (SELECT username FROM @tmpUsername WHERE searchcount >= 0) 
	)a
ORDER BY searchcount DESC, username

GO
GRANT EXECUTE ON [dbo].[EAS_CustomerSelUserSearch] TO [bodbExtAccNet]
GO
GRANT VIEW DEFINITION ON [dbo].[EAS_CustomerSelUserSearch] TO [vnteam]
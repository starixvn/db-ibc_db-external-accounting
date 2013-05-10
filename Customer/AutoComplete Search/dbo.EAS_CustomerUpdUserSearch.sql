ALTER PROCEDURE [dbo].[EAS_CustomerUpdUserSearch]
	@userid int,
	@search varchar(30),
	@firstname nvarchar(50) = NULL,
	@lastname nvarchar(50)=NULL,
	@groupname varchar(50)
AS
/*
Created: 20121105@Dan
Task : Update to increate number of hits of 'search' term by userid [Used for Agency Site]
DB:DBEAS/bodb_EAS
Original: [Acc_CustomerUpdUserSearch]

Revisions:
    - 20130121@Dan: change linked server DB06 to DBACC, Move sp from DB053/bodb02 to DBEAS/bodb_EAS
Param's Explanation:
• @userid: userid that currently login.
• @search: the search term.
*/

SET NOCOUNT ON

IF EXISTS (SELECT 1 FROM DBACC.bodb02.dbo.Customer WITH (NOLOCK) WHERE Username2 = @search )
RETURN
ELSE
BEGIN
	Declare @Currency int	

	SELECT @Currency = currency
	FROM bodb02.dbo.Customer with (Nolock)
	WHERE custid = @userid

	IF NOT EXISTS (SELECT userid FROM bodb02.dbo.CustSearch (NOLOCK) WHERE userid = @userid AND username=@search)
	BEGIN
		-- Check userid EXISTS or NOT in table custinfo.
		IF EXISTS (SELECT custid FROM bodb02.dbo.custinfo (NOLOCK) WHERE custid = @userid)
		BEGIN			
			--Insert
			INSERT INTO bodb02.dbo.custsearch(userid, username, searchcount, firstname, lastname, currency,groupname)
			VALUES (@userid, @search, 0, @firstname, @lastname, @Currency,@GroupName)
		END
	END
	ELSE
	BEGIN			
		--Update count
		UPDATE bodb02.dbo.custsearch WITH (ROWLOCK)
		SET [searchcount] = [searchcount] + 1
			, firstname = CASE WHEN @firstname IS NULL THEN firstname ELSE @firstname END 
			, lastname = CASE WHEN @lastname IS NULL THEN lastname ELSE @lastname END
			, currency = @Currency
			, groupname = @GroupName
		WHERE userid = @userid AND username=@search		
	END
END


GRANT EXECUTE ON [dbo].[EAS_CustomerUpdUserSearch] TO [bodbExtAccNet]
GO
GRANT VIEW DEFINITION ON [dbo].[EAS_CustomerUpdUserSearch] TO [vnteam]
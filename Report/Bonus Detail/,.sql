CREATE PROCEDURE dbo.EAS_CancelBonus
(
	@Username		VARCHAR(30) = ''
	,@FromDate		DATETIME
	,@ToDate		DATETIME
	,@StatusId		TINYINT
	,@IsComplained	BIT
	,@PageSize		INT = 0
	,@PageIndex		INT = 0
	,@TotalRows		INT = 0 OUTPUT
)
AS
BEGIN
	SET NOCOUNT ON

	DECLARE @RowStart	INT
			,@RowEnd	INT

	SELECT @PageIndex = @PageIndex - 1, @RowStart = @PageIndex * @PageSize + 1, @RowEnd = @RowStart + @PageSize - 1

	CREATE TABLE #Result(ID INT, TransId BIGINT, CustId INT ,Username VARCHAR(30) ,SuperId INT ,SuperName VARCHAR(30) ,Amount MONEY ,CreatedDate DATETIME ,StatusId TINYINT ,IsComplained BIT, PaymentDate DATE)

	INSERT INTO #Result (TransId, CustId, SuperId, Amount, CreatedDate, StatusId, IsComplained, PaymentDate)
	SELECT B.TransId, b.CustID, b.Srecommend, b.Amount, b.CreationDate, b.StatusId, b.IsComplained, PaymentDate
	FROM dbo.BonusTrans b WITH(NOLOCK)
		INNER JOIN CustDB.dbo.Customer c WITH(NOLOCK) ON c.custid = b.CustID
	WHERE b.CreationDate >= @FromDate 
		AND b.CreationDate <= @ToDate		
		AND (b.StatusId = @StatusId OR @StatusId IS NULL)
		AND (b.IsComplained = @IsComplained OR @IsComplained IS NULL)
		AND (c.username LIKE (@Username + '%') OR @Username = '')

	UPDATE r
		SET r.SuperName = c.username
	FROM #Result r
		INNER JOIN CustDB.dbo.Customer c WITH(NOLOCK) ON c.custid = r.SuperId

	UPDATE r
		SET r.ID = r.NewRowNum
	FROM 
		(
			SELECT ID,
				   ROW_NUMBER() OVER(ORDER BY CreatedDate, SuperName, CASE WHEN IsComplained IS NULL THEN 0.5 ELSE IsComplained END DESC, CASE WHEN StatusId = 1 THEN 10 ELSE StatusId END ASC) AS NewRowNum
			FROM #Result r
		) r

	DELETE #Result WHERE ID < @RowEnd OR ID > @RowEnd

	SELECT 
		CreatedDate
		,TransId 
		,SuperId 
		,SuperName
		,CustId
		,Username
		,PaymentDate
		,StatusId
		,IsComplained
	FROM #Result
	ORDER BY ID ASC

	DROP TABLE #Result
END
GO
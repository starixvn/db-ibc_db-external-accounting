/*<info serverAlias="DBTXN-bodb02" executers="bodbExtAccNet" viewers="" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE dbo.EAS_Bonus_Sel
(
	@Username		VARCHAR(30) = ''
	,@GroupName		VARCHAR(50)
	,@FromDate		DATETIME
	,@ToDate		DATETIME
	,@StatusId		TINYINT = NULL
	,@IsComplained	BIT = NULL
	,@PageSize		INT = 0
	,@PageIndex		INT = 0
	,@TotalRows		INT = 0 OUTPUT
)
AS
/*
Created: 
Task : Set up Bonus feature for IBCIndo
DB: DBTXN/bodb02

Revisions:
	- 20210104@Malcolm: Set up Bonus feature for IBCIndo [RedmineID: #147430]

*/
BEGIN
	SET NOCOUNT ON

	DECLARE @RowStart	INT
			,@RowEnd	INT

	SELECT @PageIndex = @PageIndex - 1, @RowStart = @PageIndex * @PageSize + 1, @RowEnd = @RowStart + @PageSize - 1

	SELECT @ToDate = @ToDate + CONVERT(TIME, '23:59:59')

	DECLARE @Super TABLE (CustId INT, Username VARCHAR(30))
	
	INSERT INTO @Super (CustId)
	SELECT a.CustId FROM DBCust.CustDB.dbo.Acc_CustGroup a WITH(NOLOCK) WHERE a.GroupName = @GroupName

	UPDATE s
		SET s.Username = c.username
	FROM @Super s
		INNER JOIN CustDB.dbo.custInfo c WITH(NOLOCK) ON c.custid = s.CustId

	CREATE TABLE #Result
	(
		ID				INT
		,TransId		BIGINT
		,CustId			INT 
		,Username		VARCHAR(30) 
		,SuperId		INT 
		,SuperName		VARCHAR(30) 
		,Amount			MONEY 
		,CreatedDate	DATETIME 
		,StatusId		TINYINT 
		,IsComplained	BIT
		,PaymentDate	DATE
		,CreationDate   DATE
	)

	INSERT INTO #Result (TransId, CustId, Username, SuperId, Amount, CreatedDate, StatusId, IsComplained, PaymentDate, CreationDate, SuperName)
	SELECT B.TransId, b.CustID, c.username,b.Srecommend, b.Amount, b.CreatedDate, b.StatusId, b.IsComplained, PaymentDate, CONVERT(DATE, b.CreatedDate), s.Username
	FROM dbo.BonusTrans b WITH(NOLOCK)
		INNER JOIN CustDB.dbo.custInfo c WITH(NOLOCK) ON c.custid = b.CustId
		INNER JOIN @Super s ON s.CustId = b.Srecommend
	WHERE b.CreatedDate >= @FromDate 
		AND b.CreatedDate <= @ToDate		
		AND (b.StatusId = @StatusId OR @StatusId IS NULL)
		AND (b.IsComplained = @IsComplained OR @IsComplained IS NULL)
		AND (c.username LIKE (@Username + '%') OR @Username = '')

	UPDATE r
		SET r.ID = r.NewRowNum
	FROM 
	(
		SELECT ID,
			   ROW_NUMBER() OVER(ORDER BY CreationDate DESC, SuperName, CASE WHEN IsComplained IS NULL THEN 0.5 ELSE CONVERT(INT, IsComplained) END DESC, StatusId ASC, TransId DESC) AS NewRowNum
		FROM #Result r
	) r

	SELECT @TotalRows = COUNT(*) FROM #Result

	DELETE #Result WHERE ID < @RowStart OR ID > @RowEnd

	SELECT CreatedDate, TransId, SuperId, SuperName, CustId, Username, PaymentDate, StatusId, IsComplained, Amount
	FROM #Result 
	ORDER BY ID ASC

	DROP TABLE #Result
END
GO
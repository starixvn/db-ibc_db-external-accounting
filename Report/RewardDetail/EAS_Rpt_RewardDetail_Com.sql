/*<info serverAlias="DBAGE-bodb02" executers="wsv_xnap" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[EAS_Rpt_RewardDetail_Com]  
	@GroupName VARCHAR(50) = 'ACCTEST'
	,@Username VARCHAR(30) =''
	,@Fromdate SMALLDATETIME =''
	,@Todate SMALLDATETIME =''
	,@ProgramIds VARCHAR(MAX) = ''
	,@PaymentStatus BIT = NULL
	,@PageSize		INT = 0
	,@PageIndex		INT = 0
	,@TotalRecords	INT = 0 OUTPUT

AS  
/*  
    Created: 20240918@Lewis  
    Task: Rebate and Retention for Credit Players - Report Reward Master
    DB: DBAGE-bodb02
  
    Revisions:  
        - 20240918@Lewis: Initialize SP [RedmineId: #208503]
		- 20241224@Max: Offer Direct Member for Super/Master [Redmine: #211969]
  
    Param's Explanation:  
		- @Username: '': ALL | <>'': MemberUsername  

		- @PaymentStatus: NULL: ALL | 1: Paid | 0: UnPaid -> MemberPaymentStatus
    

*/  
BEGIN  
    SET NOCOUNT ON; 

	DECLARE @RowStart	INT,
			@RowEnd		INT;
		
	SELECT	@PageIndex = @PageIndex - 1,
			@RowStart = @PageSize * @PageIndex + 1,
			@RowEnd = @RowStart + @PageSize - 1;

	-- @Username
	DECLARE @Username_CustId INT 
			,@Username_RoleId TINYINT

	IF ISNULL(@Username,'') <> '' -- @username:		='' => get all		||		<>'' => get exactly username 
	BEGIN
		SELECT @Username_CustId = custid
			  ,@Username_RoleId = roleid
		FROM customer c WITH(NOLOCK)
		WHERE c.username = @Username
	END

	--@ProgramIds
	DROP TABLE IF EXISTS #ProgramList
	CREATE TABLE #ProgramList(
		ProgramId SMALLINT
	)
	IF ISNULL(@ProgramIds,'') <> ''
	BEGIN
		INSERT INTO #ProgramList(
			ProgramId
		)
		SELECT value 
		FROM string_split(@ProgramIds,',') 
	END

	-- @GroupName
	DROP TABLE IF EXISTS #tmpSuperList;
	CREATE TABLE #tmpSuperList (custID INT PRIMARY KEY)
	
	INSERT INTO #tmpSuperList(CustID)
	SELECT cg.custID
	FROM Acc_CustGroup cg WITH(NOLOCK)
	WHERE GroupName = @GroupName

	--@Fromdate ,@Todate
	SELECT @Fromdate = IIF(ISNULL(@Fromdate,'') ='',GETDATE(),@Fromdate)
		   ,@Todate = IIF(ISNULL(@Todate,'') ='',GETDATE(),@Todate)
	
	--TODO: SabaWalletTicket
	DROP TABLE IF EXISTS #RewardReport
	CREATE TABLE #RewardReport(
		TransId BIGINT
		,CreatedDate DATETIME
		,ProgramId SMALLINT
		--mem
		--,MemberUserName VARCHAR(30)
		,CustID INT
		,MemberAmount MONEY
		,CurrencyId INT
		,MemberPaymentStatus BIT
		,MemberPaymentDate DATE
		,MemberFeedback VARCHAR(30)
		--agent
		--,AgentUserName VARCHAR(30)
		,Recommend INT
		,AgentPaymentStatus BIT
		,AgentPaymentDate DATE
		--master
		--,MasterUserName VARCHAR(30)
		,Mrecommend INT
		,MasterPaymentStatus BIT
		,MasterPaymentDate DATE
		--super
		,Srecommend INT
		,SuperPaymentStatus BIT
		,SuperPaymentDate DATE
	)
	INSERT INTO #RewardReport(
		TransId
		,CreatedDate
		,ProgramId
		--mem
		--,MemberUserName VARCHAR(30)
		,CustID
		,MemberAmount
		,CurrencyId
		,MemberPaymentStatus
		,MemberPaymentDate
		,MemberFeedback
		--agent
		--,AgentUserName VARCHAR(30)
		,Recommend
		,AgentPaymentStatus
		,AgentPaymentDate
		--master
		--,MasterUserName VARCHAR(30)
		,Mrecommend
		,MasterPaymentStatus
		,MasterPaymentDate
		--super
		,Srecommend
		,SuperPaymentStatus
		,SuperPaymentDate
	)
	SELECT 
		swt.TransId
		,swt.TransDate
		,swt.ProgramId
		--mem
		,swt.CustID
		,swt.Amount AS MemberAmount
		,swt.CurrencyId
		,CASE WHEN swt.StatusId = 1 THEN 1 ELSE 0 END AS MemberPaymentStatus
		,swt.APaymentDate AS MemberPaymentDate
		,CASE 
			  WHEN swt.StatusId = 1 AND ISNULL(swt.IsComplaint,0) = 0 THEN 0
			  WHEN swt.StatusId = 1 AND swt.IsComplaint = 1 THEN 1
		 END AS MemberFeedback
		--agent
		,swt.Recommend
		,CASE WHEN swt.PaymentStatus & 2 = 2 THEN 1 ELSE 0 END AS AgentPaymentStatus
		,swt.MPaymentDate AS AgentPaymentDate
		--master
		,swt.Mrecommend
		,CASE WHEN swt.PaymentStatus & 4 = 4 THEN 1 ELSE 0 END AS MasterPaymentStatus
		,swt.SPaymentDate AS MasterPaymentDate
		--super
		,swt.Srecommend
		,CASE WHEN swt.PaymentStatus & 8 = 8 THEN 1 ELSE 0 END AS SuperPaymentStatus
		,swt.HPaymentDate AS SuperPaymentDate

	FROM SabaWalletTicket swt WITH (NOLOCK)
	INNER JOIN #tmpSuperList s WITH (NOLOCK)
		ON swt.Srecommend = s.custID
	LEFT JOIN #ProgramList p
		ON swt.ProgramId = p.ProgramId
	WHERE swt.WalletID = 2
		AND swt.WinlostDate BETWEEN @Fromdate AND @Todate
		AND 1 = CASE 
					WHEN ISNULL(@Username,'') = '' THEN 1 --get all
					WHEN @Username_RoleId = 1 AND swt.custid = @Username_CustId THEN 1 --mem username
					WHEN @Username_RoleId = 2 AND swt.Recommend = @Username_CustId THEN 1 --agent username
					WHEN @Username_RoleId = 3 AND swt.Mrecommend = @Username_CustId THEN 1 -- master username
					WHEN @Username_RoleId = 4 AND swt.Srecommend = @Username_CustId THEN 1 -- super username
					ELSE 0 
				END
		AND (
				ISNULL(@ProgramIds,'') = '' --get all
				OR p.ProgramId IS NOT NULL
			)	
		AND (
				@PaymentStatus IS NULL --get all
				OR swt.StatusId = @PaymentStatus
			)


	--TODO: Result
	IF @TotalRecords = 0
	BEGIN
		SELECT @TotalRecords = COUNT(1)
		FROM #RewardReport rr
		INNER JOIN Customer mem WITH (NOLOCK) ON mem.custid = rr.CustID
		LEFT JOIN Customer a WITH (NOLOCK) ON a.custid = rr.Recommend
		LEFT JOIN Customer m WITH (NOLOCK) ON m.custid = rr.Mrecommend
		INNER JOIN Customer s WITH (NOLOCK) ON s.custid = rr.Srecommend
		INNER JOIN Exchange e WITH (NOLOCK) ON rr.CurrencyId = e.ExchangeId
	END

	IF ((@PageSize <= 0) AND (@PageIndex <= 0))
	BEGIN
		SELECT 
			rr.CreatedDate
			,rr.ProgramId
			--mem
			,rr.CustID
			,mem.username AS MemberUserName 
			,rr.MemberAmount
			,e.Code AS CurrencyCode
			,rr.MemberPaymentStatus
			,rr.MemberPaymentDate
			,rr.MemberFeedback
			--agent
			,rr.Recommend
			,a.username AS AgentUserName 
			,rr.AgentPaymentStatus
			,rr.AgentPaymentDate
			--master
			,rr.Mrecommend
			,m.username AS MasterUserName 
			,rr.MasterPaymentStatus
			,rr.MasterPaymentDate
			--super
			,rr.Srecommend
			,s.username AS SuperUserName 
			,rr.SuperPaymentStatus
			,rr.SuperPaymentDate

			--IsDirectMember
			,IIF(rr.Recommend < 0, 1, 0) AS IsDirectMember
		FROM #RewardReport rr
		INNER JOIN Customer mem WITH (NOLOCK) ON mem.custid = rr.CustID
		LEFT JOIN Customer a WITH (NOLOCK) ON a.custid = rr.Recommend
		LEFT JOIN Customer m WITH (NOLOCK) ON m.custid = rr.Mrecommend
		INNER JOIN Customer s WITH (NOLOCK) ON s.custid = rr.Srecommend
		INNER JOIN Exchange e WITH (NOLOCK) ON rr.CurrencyId = e.ExchangeId
		ORDER BY CreatedDate DESC
	END
	ELSE
	BEGIN
		SELECT 
			A.CreatedDate
			,A.ProgramId
			--mem
			,A.CustID
			,A.MemberUserName 
			,A.MemberAmount
			,A.CurrencyCode
			,A.MemberPaymentStatus
			,A.MemberPaymentDate
			,A.MemberFeedback
			--agent
			,A.Recommend
			,A.AgentUserName 
			,A.AgentPaymentStatus
			,A.AgentPaymentDate
			--master
			,A.Mrecommend
			,A.MasterUserName 
			,A.MasterPaymentStatus
			,A.MasterPaymentDate
			--super
			,A.Srecommend
			,A.SuperUserName 
			,A.SuperPaymentStatus
			,A.SuperPaymentDate
			--IsDirectMember
			,A.IsDirectMember
		FROM (
				SELECT 
					rr.CreatedDate
					,rr.ProgramId
					--mem
					,rr.CustID
					,mem.username AS MemberUserName 
					,rr.MemberAmount
					,e.Code AS CurrencyCode
					,rr.MemberPaymentStatus
					,rr.MemberPaymentDate
					,rr.MemberFeedback
					--agent
					,rr.Recommend
					,a.username AS AgentUserName 
					,rr.AgentPaymentStatus
					,rr.AgentPaymentDate
					--master
					,rr.Mrecommend
					,m.username AS MasterUserName 
					,rr.MasterPaymentStatus
					,rr.MasterPaymentDate
					--super
					,rr.Srecommend
					,s.username AS SuperUserName 
					,rr.SuperPaymentStatus
					,rr.SuperPaymentDate
					--IsDirectMember
					,IIF(rr.Recommend < 0, 1, 0) AS IsDirectMember
					,ROW_NUMBER() OVER (ORDER BY CreatedDate DESC) AS Rownum
				FROM #RewardReport rr
				INNER JOIN Customer mem WITH (NOLOCK) ON mem.custid = rr.CustID
				LEFT JOIN Customer a WITH (NOLOCK) ON a.custid = rr.Recommend
				LEFT JOIN Customer m WITH (NOLOCK) ON m.custid = rr.Mrecommend
				INNER JOIN Customer s WITH (NOLOCK) ON s.custid = rr.Srecommend
				INNER JOIN Exchange e WITH (NOLOCK) ON rr.CurrencyId = e.ExchangeId
			) A
		WHERE A.Rownum BETWEEN @RowStart AND @RowEnd
	END

END  
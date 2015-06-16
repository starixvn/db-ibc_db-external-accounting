ALTER PROCEDURE [dbo].[EAS_CustomerUpdTransferOption]
	@CustId INT,
	@TransferOption VARCHAR(8),
	@UserID INT = 0,
	@IP VARCHAR(15) = '',	
	@ErrCode INT = 0 OUTPUT,
	@ErrMsg NVARCHAR(200) = '' OUTPUT
AS
/*
Created: Dan
Date: 2013-02-04  
Task : Update transfer option.
DB: DBTXN/BODB02
Original: [Acc_CustomerUpdTransferOption]

Revisions:
	- 20150606@Elodie: Separate CustDB to DBCUST server (Move Acc_CustomerSelCheckEnable to DBCUST.CustDB)

Param's Explanation:
*/

SET NOCOUNT ON

declare @startRun datetime
declare @endRun datetime
declare @duration int
set @startRun = getdate()

DECLARE @Old_TransferOption TINYINT
DECLARE @roleid TINYINT
--end
--Check disable user
EXEC Acc_CustomerSelCheckEnable @custid = @custid, @ErrCode=@ErrCode OUTPUT,@ErrMsg=@ErrMsg OUTPUT
IF @ErrCode <>0 RETURN
--end

DECLARE @TransferOption_dec TINYINT

SELECT @roleid = roleid FROM custinfo WITH (NOLOCK) WHERE custid = @custid
SELECT @TransferOption_dec = dbo.F_Binary_Decimal(@TransferOption)

--update downline: 
IF (@roleid = 4) AND (@Custid >= 100)--normal super
BEGIN	
	SELECT @Old_TransferOption = TransferOption FROM CustSuper WITH (nolock) WHERE custid= @custid
	
	IF @Old_TransferOption = @TransferOption_dec RETURN
	--Update Super himself
	UPDATE CustSuper WITH (ROWLOCK, UPDLOCK) SET TransferOption = @TransferOption_dec
	WHERE custid = @custid
	
	--Update Master Level
	UPDATE CustMaster WITH (ROWLOCK, UPDLOCK) SET TransferOption = @TransferOption_dec
	WHERE custid IN (SELECT custid FROM custinfo (NOLOCK) WHERE srecommend = @custid AND roleid = 3)

	--Update Agent Level
	UPDATE CustAgent WITH (ROWLOCK, UPDLOCK) SET TransferOption = @TransferOption_dec
	WHERE custid IN (SELECT custid FROM custinfo (NOLOCK) WHERE srecommend = @custid AND roleid = 2)		
END
ELSE IF (@roleid = 3) --master
BEGIN
	select @Old_TransferOption = TransferOption from CustMaster with (nolock) where custid= @custid
	
	IF @Old_TransferOption = @TransferOption_dec RETURN

	--Update Master himself
	UPDATE CustMaster WITH (ROWLOCK, UPDLOCK) SET TransferOption = @TransferOption_dec
	WHERE custid = @custid

	--Update Agent Level
	UPDATE CustAgent WITH (ROWLOCK, UPDLOCK) SET TransferOption = @TransferOption_dec
	WHERE custid IN (SELECT custid FROM custinfo (NOLOCK) WHERE mrecommend = @custid AND roleid = 2)		
END
-- master of the agent is allowed to transfer all day 
ELSE IF (EXISTS(SELECT 1 FROM CustMaster WITH (NOLOCK) WHERE TransferOption = 0 AND custid = (SELECT mrecommend FROM custinfo WITH (NOLOCK) WHERE custid = @custid)))
BEGIN
	select @Old_TransferOption = TransferOption from CustAgent with (nolock) where custid= @custid
	
	IF @Old_TransferOption = @TransferOption_dec RETURN

	UPDATE CustAgent WITH (ROWLOCK, UPDLOCK) SET TransferOption = @TransferOption_dec
	WHERE custid = @custid
END

DECLARE @LogSPData varchar(3000), @LogEAS varchar(3000)
DECLARE @TrackingValue2 varchar(3000)

Select @LogEAS = '<EAS_CustomerUpdTransferOption>' + 
					'<CustId>' + COALESCE(CAST(@CustID AS Varchar(50)),'') + '</CustId>' +					
					'<TransferOption>'+ 
						'<Old>' + COALESCE(cast(dbo.F_Decimal_Binary(@Old_TransferOption) AS VARCHAR(8)),'') + '</Old>' +
						'<New>' + COALESCE(cast(@TransferOption AS VARCHAR(8)),'') + '</New>' +
					'</TransferOption>' +
					'<UserID>'+ coalesce(cast(@UserID as varchar(50)),'') + '</UserID>'+
					'<IP>' + COALESCE(@IP,'') + '</IP>' + 					
					'<ErrCode>'+ coalesce(cast(@ErrCode as varchar(50)),'') + '</ErrCode>'+
					'<ErrMsg>'+ coalesce(cast(@ErrMsg as varchar(400)),'')+'</ErrMsg>' +
				'</EAS_CustomerUpdTransferOption>' 

Select @LogSPData = '<EAS_CustomerUpdTransferOption CustId="'+ coalesce(cast(@CustId as varchar(50)),space(1)) + '" '+
					'TransferOption="'+ coalesce(cast(@TransferOption as varchar(8)),space(1))+'" '+
					'UserID="'+ coalesce(cast(@UserID as varchar(50)),space(1)) + '" '+
					'IP="'+ coalesce(cast(@IP as varchar(15)),space(1)) + '" '+									
					'ErrCode="'+ coalesce(cast(@ErrCode as varchar(50)),space(1)) + '" '+
					'ErrMsg="'+ coalesce(cast(@ErrMsg as varchar(400)),space(1))+'" />'
										
Select @TrackingValue2 = '<EAS_CustomerUpdTransferOption CustId="'+ coalesce(cast(@CustId as varchar(50)),space(1)) + '" '+
					'TransferOption="'+ coalesce(cast(dbo.F_Decimal_Binary(@Old_TransferOption) as varchar(8)),space(1))+'" '+
					'UserID="'+ coalesce(cast(@UserID as varchar(50)),space(1)) + '" '+
					'IP="'+ coalesce(cast(@IP as varchar(15)),space(1)) + '" '+										
					'ErrCode="'+ coalesce(cast(@ErrCode as varchar(50)),space(1)) + '" '+
					'ErrMsg="'+ coalesce(cast(@ErrMsg as varchar(400)),space(1))+'" />'

set @endRun = getdate()
set @duration  = datediff (millisecond,@startRun,@endRun)

BEGIN TRY
	--EAS
	EXEC DBLOG.bodb_CustomerLog.dbo.EAS_WriteLog_UserLog_RunSP
		@UserID			= @UserID, 
		@CustID			= @CustID,				
		@ActionID		= 20400, 
		@TrackingValue	= @LogEAS, 
		@duration		= @duration
	--IBC
	EXEC DBLOG.bodb_CustomerLog.dbo.WriteLog_UserLog_RunSP
		@UserID = @UserID,
		@CustID = @CustID,
		@ActionID = 20400,
		@TrackingValue = @LogSPData,
		@TrackingValue2 = @TrackingValue2,
		@duration = @duration	
END TRY
BEGIN CATCH
	
	Select @LogEAS = '<EAS_CustomerUpdTransferOption>' + 
					'<CustId>' + COALESCE(CAST(@CustID AS Varchar(50)),'') + '</CustId>' +					
					'<TransferOption>'+ coalesce(cast(@TransferOption AS VARCHAR(8)),'')+
						'<Old>' + COALESCE(cast(dbo.F_Decimal_Binary(@Old_TransferOption) AS VARCHAR(8)),'') + '</Old>' +
						'<New>' + COALESCE(cast(@TransferOption AS VARCHAR(8)),'') + '</New>' +
					'</TransferOption>' +
					'<UserID>'+ coalesce(cast(@UserID as varchar(50)),'') + '</UserID>'+
					'<IP>' + COALESCE(@IP,'') + '</IP>' + 					
					'<ErrCode>'+ coalesce(cast(ERROR_NUMBER() as varchar(50)),'') + '</ErrCode>'+
					'<ErrMsg>'+ coalesce(cast(ERROR_MESSAGE() as varchar(400)),'')+'</ErrMsg>' +
				'</EAS_CustomerUpdTransferOption>' 

	Select @LogSPData = '<EAS_CustomerUpdTransferOption CustId="'+ coalesce(cast(@CustId as varchar(50)),space(1)) + '" '+
						'TransferOption="'+ coalesce(cast(@TransferOption as varchar(8)),space(1))+'" '+
						'UserID="'+ coalesce(cast(@UserID as varchar(50)),space(1)) + '" '+
						'IP="'+ coalesce(cast(@IP as varchar(15)),space(1)) + '" '+									
						'ErrCode="'+ coalesce(cast(ERROR_NUMBER() as varchar(50)),space(1)) + '" '+
						'ErrMsg="'+ coalesce(cast(ERROR_MESSAGE() as varchar(400)),space(1))+'" />'
											
	Select @TrackingValue2 = '<EAS_CustomerUpdTransferOption CustId="'+ coalesce(cast(@CustId as varchar(50)),space(1)) + '" '+
						'TransferOption="'+ coalesce(cast(dbo.F_Decimal_Binary(@Old_TransferOption) as varchar(8)),space(1))+'" '+
						'UserID="'+ coalesce(cast(@UserID as varchar(50)),space(1)) + '" '+
						'IP="'+ coalesce(cast(@IP as varchar(15)),space(1)) + '" '+										
						'ErrCode="'+ coalesce(cast(ERROR_NUMBER () as varchar(50)),space(1)) + '" '+
						'ErrMsg="'+ coalesce(cast(ERROR_MESSAGE() as varchar(400)),space(1))+'" />'
	--EAS
	EXEC bodb_CustomerLog.dbo.EAS_WriteLog_UserLog_RunSP
		@UserID			= @UserID, 
		@CustID			= @CustID,				
		@ActionID		= 20400, 
		@TrackingValue	= @LogEAS, 
		@duration		= @duration

	--IBC
	EXEC bodb_CustomerLog.dbo.WriteLog_UserLog_RunSP
		@UserID = @UserID,
		@CustID = @CustID,
		@ActionID = 20400,
		@TrackingValue = @LogSPData,
		@TrackingValue2 = @TrackingValue2,
		@duration = @duration

END CATCH
	

GO
GRANT EXECUTE ON [dbo].[Acc_CustomerUpdTransferOption] TO [bodbExtAccNet]
GO
GO
GRANT VIEW DEFINITION ON [dbo].[Acc_CustomerUpdTransferOption] TO [vnteam]
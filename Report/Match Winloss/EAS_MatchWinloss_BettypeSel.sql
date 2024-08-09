/*<info serverAlias="DBAGE-bodb02" executers="wsv_xnap" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[EAS_MatchWinloss_BettypeSel]
	@ProductId	INT = 1
AS
/*  
	Created by: 20240718@Bobby
	Task : Implement match winloss reports [RedmineID : #205355]
	DB: DBAGE/bodb02

	Revisions:
		- 20240718@Bobby: Initialize SPs
*/

BEGIN
	SET NOCOUNT ON;

	----Get Sport Bettype Matrix------
	DECLARE @isTest BIT = 0
	SELECT  @isTest = dbo.f_CheckSPVersion(@@PROCID)

	SELECT DISTINCT 
		bt.typeid AS Bettype
		,bt.typenamee AS BettypeName
	FROM dbo.SportBettypeMatrix sb WITH (NOLOCK)
		INNER JOIN dbo.Products p WITH (NOLOCK)	ON p.ProductID = sb.ProductID
		LEFT JOIN dbo.f_GroupBettype() bg ON bg.bettype = sb.bettype
		INNER JOIN dbo.Bettype bt WITH (NOLOCK)	ON bt.typeid = ISNULL(bg.GroupTypeId, sb.bettype)
	WHERE p.ProductID = @ProductId
		AND sb.IsTest <= @isTest
	
	ORDER BY bt.typeid
END
GO
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

	;
	WITH CTE_Bettype AS (
		SELECT TypeId 
		FROM [dbo].[EAS_f_MatchWinloss_BettypeSel] ()
	)
	SELECT Bettype, BettypeName
	FROM (
		SELECT DISTINCT 
			ISNULL(bg.GroupTypeId, bt.typeid) AS Bettype
			,bt.typenamee AS BettypeName
		FROM dbo.SportBettypeMatrix sb WITH (NOLOCK)
			INNER JOIN CTE_Bettype cte ON cte.TypeId = sb.BetType
			INNER JOIN dbo.Bettype bt WITH (NOLOCK)	ON bt.typeid = cte.TypeId
			LEFT JOIN dbo.f_GroupBettype() bg ON bg.bettype = bt.typeid
			
		WHERE sb.ProductID = @ProductId
			AND sb.IsTest <= @isTest

		UNION ALL
		SELECT 9999, 'Others'
	) AS t
	ORDER BY CASE WHEN Bettype = 9999 THEN 1 ELSE 0 END ASC
		, Bettype
END
GO
/*<info serverAlias="DBAGE-bodb02" executers="wsv_xnap" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[EAS_MatchWinloss_SportSel]
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

	;WITH CTE_SabaSport AS (
		SELECT DISTINCT IIF(SabaGroupType = -99, 'SABA Other Sports', RefId) AS RefId,
			SabaGroupType AS Sporttype,
			ResourceId,
			SabaGroupType AS SportOrder
		FROM [dbo].[EAS_f_SabaSportSel] ()
	)
	SELECT RefId, SportType, ResourceId
	FROM (
		SELECT DISTINCT 'Normal' AS RefId
			,sb.SportType
			,sb.SportType AS SportOrder
			,sb.SportType AS ResourceId
		FROM dbo.SportBettypeMatrix sb WITH (NOLOCK)
			INNER JOIN dbo.Products p WITH (NOLOCK)	ON p.ProductID = sb.ProductID
			INNER JOIN dbo.Sports s WITH (NOLOCK)	ON s.SportType = sb.SportType
		WHERE p.ProductID = @ProductId
			AND sb.IsTest <= @isTest

		UNION ALL --SABA Sports
		SELECT RefId, SportType, SportOrder, ResourceId
		FROM CTE_SabaSport
	) AS t
	WHERE t.SportType NOT IN (27) -- Exclude old Criket
	ORDER BY 
		CASE 
			WHEN SportType IN (1,2,9,43) THEN 1
			WHEN SportType IN (5) THEN 2
			ELSE 3 END
		, CASE WHEN SportType < 0 THEN 1 ELSE 0 END
		, CASE WHEN SportType < 0 THEN SportOrder ELSE 0 END DESC
		, t.SportType

END
GO
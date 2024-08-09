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
		SELECT DISTINCT sb.SabaSportType AS SportType, sb.SportName, sb.SportOrder 
		FROM dbo.[EAS_f_SabaSportSel]() sb
		INNER JOIN dbo.[EAS_f_SabaSportSel]() sg ON sg.SabaGroupType = sb.SabaSportType
	)
	SELECT SportType, SportName, SportOrder
	FROM (
		SELECT DISTINCT 
			sb.SportType
			,s.SportName
			,sb.SportType AS SportOrder
		FROM dbo.SportBettypeMatrix sb WITH (NOLOCK)
			INNER JOIN dbo.Products p WITH (NOLOCK)	ON p.ProductID = sb.ProductID
			INNER JOIN dbo.Sports s WITH (NOLOCK)	ON s.SportType = sb.SportType
		WHERE p.ProductID = @ProductId
			AND sb.IsTest <= @isTest
		UNION ALL 
		SELECT SportType, SportName, SportOrder 
		FROM CTE_SabaSport

	) AS t
	ORDER BY t.SportOrder

END
GO
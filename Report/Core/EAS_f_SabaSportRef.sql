/*<info serverAlias="DBAGE-bodb02" selecters="wsv_xnap" viewers="" isFunction="1" isNested="1"></info>*/
ALTER FUNCTION [dbo].[EAS_f_SabaSportSel] ()
RETURNS TABLE
AS
/*
	Created by: 20240718@Bobby
	Task : Implement match winloss reports [RedmineID : #205355]
	DB: DBAGE/bodb02

	Revisions:
		- 20240718@Bobby: Initialize SPs
*/
RETURN
	SELECT RefId, Sporttype
		, LeagueGroupID	
		, CASE 
			WHEN Sporttype = 1 AND LeagueGroupID IN (42,74,108) THEN -2 --SABA Soccer & Futsal
			WHEN Sporttype = 2 AND LeagueGroupID IN (42) THEN -3 -- SABA Basketball
			WHEN Sporttype = 5 AND LeagueGroupID IN (42) THEN -4 -- SABA Tennis
			WHEN Sporttype = 1 AND LeagueGroupID IN (113) THEN -5 -- SABA Soccer PinGoal
			WHEN Sporttype = 2 AND LeagueGroupID IN (122) THEN -6 --SABA Basketball PinGoal
			WHEN Sporttype = 43 AND LeagueGroupID IN (151) THEN -7 --SABA E-Sports PinGoal
			ELSE -99
		END AS SabaGroupType -- SABA defined sports
		, ResourceId
		, ResourceId AS SportOrder
	FROM dbo.f_GetProductDetail() f
	WHERE ProductId = 1 --SB only
		AND LeagueGroupID > 0
GO

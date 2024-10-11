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
	WITH CTE_SabaSport AS (
		SELECT 1 AS ProductId, 
			'Sportsbook' AS ProductName, 
			-2 AS SabaSportType, 
			'SABA Soccer' AS SportName, 
			'SB' AS ProductCode, 
			902 AS SportOrder, 
			'{"Sporttype":1, "LeagueGroupID": [42,74]}' AS SporttypeRef,
			-2 AS SabaGroupType
		UNION ALL
		SELECT 1, 'Sportsbook', -3, 'SABA Futsal', 'SB', 903,
			'{"Sporttype":1, "LeagueGroupID": [108]}', -2
		UNION ALL
		SELECT 1, 'Sportsbook', -5, 'SABA Basketball', 'SB', 904,
			'{"Sporttype":2, "LeagueGroupID": [42]}', -5
		UNION ALL	
		SELECT 1, 'Sportsbook', -9, 'SABA Tennis', 'SB', 905,
			'{"Sporttype":5, "LeagueGroupID": [42]}', -9
		UNION ALL
		SELECT 1, 'Sportsbook', -4, 'SABA Soccer PinGoal', 'SB', 906,
			'{"Sporttype":1, "LeagueGroupID": [113]}', -4
		UNION ALL
		SELECT 1, 'Sportsbook', -6, 'SABA Basketball PinGoal', 'SB', 907,
			'{"Sporttype":2, "LeagueGroupID": [122]}', -6
		UNION ALL
		SELECT 1, 'Sportsbook', -7, 'SABA ESports PinGoal', 'SB', 908,
			'{"Sporttype":43, "LeagueGroupID": [151]}', -7
		--UNION ALL
		--SELECT 1, 'Sportsbook', -8, 'SABA Cricket', 'SB', 909,
		--	'{"Sporttype":50, "LeagueGroupID": [42]}', -99
		--UNION ALL
		--SELECT 1, 'Sportsbook', -10, 'SABA Ice Hockey', 'SB', 910, 
		--	'{"Sporttype":4, "LeagueGroupID": [42]}', -99
		--UNION ALL
		--SELECT 1, 'Sportsbook', -11, 'SABA Kabaddi', 'SB', 911, 
		--	'{"Sporttype":47, "LeagueGroupID": [42]}', -99
		UNION ALL
		SELECT 1, 'Sportsbook', -99, 'SABA Orther Sports', 'SB', 999, 
			'{"Sporttype":0, "LeagueGroupID": [0]}', -99
		
	)
	SELECT ProductID, SabaSportType, SabaGroupType, ProductName, SportName, ProductCode, SportOrder, SporttypeRef
	FROM CTE_SabaSport;
GO

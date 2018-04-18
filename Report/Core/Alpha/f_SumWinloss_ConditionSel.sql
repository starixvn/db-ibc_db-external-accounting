/*<info serverAlias="DBEXT-bodb02" selecters="bodbExtAccNet" viewers="" isFunction="1" isNested="1"></info>*/
USE [bodb02]
GO

ALTER FUNCTION [dbo].[f_SumWinloss_ConditionSel]
(
	@ProductID	VARCHAR(500) = ''
) 
/*
	Creator: Paul	
	Date: 20170110
	Task: Get sum_winloss condition
	DB: DBAGE.bodb02, DBEXT.bodb02
		
	Revisions:
		- 20170622@Percy: Add Betradar Virtual Sports [RedmineID: #78339]
		- 20170705@Percy: Add Keno Lottery [RedmineID: #78064]
		- 20170830@Percy: Add Lucky 3 [RedmineID: #76770]
		- 20171018@Percy: Add Bullfighting [RedmineID: #81664]
		- 20170419@Razor: Add Pragmatic [RedmineID: #92647]
		
	Paramters Explanation:
 		@ProductID: list of products
*/
RETURNS TABLE
RETURN
	SELECT ProductID, SportType, BetType
	FROM (
		VALUES	(1, 0, 0), --Sportsbook
				(6, 251, 71), (6, 208, 0), (6, 209, 0), (6, 210, 0), --RNG Casino
				(2, 151, 0), --Racing
				(3, 161, 0), --Number Game
				(4, 162, 0), --Live Casino
				(5, 180, 0), --Virtual Sports
				(8, 202, 0), --Keno
				(12, 255, 0), --Gold Deluxe
				(15, 204, 0), --Colossus Bets
				(21, 211, 0), --Allbet
				(22, 212, 0), --Macau Games
				(23, 213, 0), --NG2
				(24, 219, 0), --Fishing World
				(27, 190, 0), --Betradar Virtual Sports
				(28, 220, 0), -- Keno
				(26, 160, 0), -- Lucky 3
				(30, 207, 0), -- Bullfighting
				(32, 248, 0)  -- Pragmatic
		) d(ProductID, SportType, BetType)
	WHERE ',' + @ProductID + ',' LIKE '%,' + CAST(ProductID as varchar(3)) + ',%'
GO
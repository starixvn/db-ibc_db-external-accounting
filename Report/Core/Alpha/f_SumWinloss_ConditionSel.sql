/*<info serverAlias="DBAGE-bodb02" selecters="" isFunction="1" isNested="1"></info>*/
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
		- 20170828@Percy: Add Lucky 3 [RedmineID: #76770]
		- 20171020@Percy: Add Bullfighting [RedmineID: #84690]
		- 20170419@Razor: Add Pragmatic [RedmineID: #92647]
		- 20180717@Louis: Add Poker Games [RedmineID: #97785]
		- 20190627@Razor: Add CardClub [RedmineID: #115611]
		- 20190826@Percy: Remove inactive products [RedmineID: #118699]
		
	Paramters Explanation:
 		@ProductID: list of products
*/
RETURNS TABLE
RETURN
	SELECT ProductID, SportType, BetType
	FROM (
		VALUES	(1, 0, 0), --Sportsbook
				(6, 251, 71), (6, 208, 0), (6, 209, 0), (6, 210, 0), --RNG Casino
				(3, 161, 0), --Number Game
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
				(32, 248, 0), -- Pragmatic
				(34, 165, 0) -- Card Club
		) d(ProductID, SportType, BetType)
	WHERE ',' + @ProductID + ',' LIKE '%,' + CAST(ProductID as varchar(3)) + ',%'
GO
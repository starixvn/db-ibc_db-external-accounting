/*<info serverAlias="DBEXT-bodb02" selecters="bodbExtAccNet" viewers="" isFunction="1" isNested="1"></info>*/
USE [bodb02]
GO

ALTER FUNCTION [dbo].[f_SportBettypeMatrixByProduct_Sel]
(
	 @ProductID		VARCHAR(500) = ''
	,@IsTest		BIT			 = 0
) 
/*
	Creator: Paul	
	Date: 20161216
	Task: Get SportType_Bettype
	DB: DBAGE.bodb02, DBACC.bodb02, DBEXT.bodb02
		
	Revisions:
		- 20170220@Paul: Return more columns [RedmineID: #68723]
		- 20170812@Percy: Add new server: DBACC.bodb02 [RedmineID: #66992]
		- 20170830@Percy: Add new server: DBEXT.bodb02 [RedmineID: #66992]

	Paramters Explanation:
 		@ProductID: list of products
		@IsTest:
			1: Get all products and bettypes
			0: Get only products and bettypes which are not being tested
*/
RETURNS TABLE
RETURN
SELECT	DISTINCT ma.ProductID,
		ma.BetType,
		ma.EventType,
		ma.SubProduct,
		ma.RefTable,
		p.CasinoType
FROM dbo.SportBettypeMatrix ma WITH(NOLOCK)
	INNER JOIN dbo.Products p WITH(NOLOCK) ON p.ProductID = ma.ProductID
WHERE ',' + @ProductID + ',' LIKE '%,' + cast(p.ProductID as varchar(3)) + ',%'
	AND (ma.IsTest = 0 OR ma.IsTest = @IsTest)
GO
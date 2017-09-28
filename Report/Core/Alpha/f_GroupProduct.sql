/*<info serverAlias="DBEXT-bodb02" selecters="bodbExtAccNet" viewers="" isFunction="1" isNested="1"></info>*/
USE [bodb02]
GO

ALTER FUNCTION [dbo].[f_GroupProduct]
(
)
RETURNS TABLE
AS

/*
	Created by Percy
	Date: 2017-06-22
	DB: DBAGE.bodb02, DBACC.bodb02, DBEXT.bodb02
	Task: Get parent product
	
	Revisions:
		- 20170622@Percy: Create new [RedmineID: #78339]
*/

RETURN
	-- Betradar Virtual Sports and Virtual Sports
	SELECT 27 AS ProductId, 5 AS GroupProductId
	UNION ALL
	SELECT 5, 5
GO
/*<info serverAlias="DBAGE-bodb02,DBACC-bodb02" selecters="bodbAdminNet,bodbDownlineNet,bodbDownlineNetView" isFunction="1" isNested="1"></info>*/
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
	DB: DBAGE.bodb02, DBACC.bodb02
	Task: Get parent product
	
	Revisions:
		- 20170622@Percy: Create new [RedmineID: #78339]
		- 20180418@Razor: Add Pragmatic under Macau Games [RedmineID: #92647]
		- 20190612@Percy: Add Card Club under Macau Games [RedmineID: #92647]
*/

RETURN
	-- Virtual Sports: Betradar Virtual Sports, Virtual Sports
	SELECT 27 AS ProductId, 5 AS GroupProductId
	UNION ALL
	SELECT 5, 5
	
	-- Macau Games: Macau Games, Pragmatic, Card Club
	UNION ALL	
	SELECT 32, 22
	UNION ALL	
	SELECT 34, 22
	UNION ALL
	SELECT 22, 22
GO
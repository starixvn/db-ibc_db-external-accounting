/*<info serverAlias="DBEXT-bodb02" executers="bodbExtAccNet" viewers="" isFunction="1" isNested="1"></info>*/
USE [bodb02]
GO

ALTER FUNCTION [dbo].[f_AddRelatedProducts]
(
	@ProductIds VARCHAR(MAX) = ''
)
RETURNS VARCHAR(MAX)
AS

/*
	Created by Percy
	Date: 2017-06-23
	DB: DBAGE.bodb02, DBACC.bodb02, DBEXT.bodb02
	Task: Add related products

	Revisions:
		- 20170623@Percy: Create new [RedmineID: #78339]
*/

BEGIN
	DECLARE @ProductIdList VARCHAR(MAX) = ''

	SELECT @ProductIdList = @ProductIdList + COALESCE(CONVERT(VARCHAR(5), ProductId) + ',', '')
	FROM (
		SELECT DISTINCT ISNULL(p.ProductId, CONVERT(INT, val)) AS ProductId FROM dbo.strSplit(@ProductIds, ',') s
			LEFT JOIN dbo.f_GroupProduct() p ON s.val = p.GroupProductId
	) AS A

	SELECT @ProductIdList = LEFT(@ProductIdList, LEN(@ProductIdList)-1)
	
	RETURN @ProductIdList
END
GO
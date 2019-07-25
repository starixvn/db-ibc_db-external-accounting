/*<info serverAlias="DBAGE-bodb02,DBACC-bodb02" executers="bodbAdminNet,bodbDownlineNet,bodbDownlineNetView" isFunction="1" isNested="1"></info>*/
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
	DB: DBAGE.bodb02, DBEXT.bodb02, DBACC.bodb02
	Task: Add related products

	Revisions:
		- 20170623@Percy: Create new [RedmineID: #78339]
		- 20171101@Percy: Enhance Performance [RedmineID: #86200]
*/

BEGIN
	DECLARE @ProductIdList VARCHAR(MAX)

	SELECT @ProductIdList = @ProductIds + 
		ISNULL(
				(SELECT ',' + CONVERT(VARCHAR(10), ProductId)
				FROM dbo.f_GroupProduct()
				WHERE ProductId <> GroupProductId
					AND CHARINDEX(',' + CONVERT(VARCHAR(10), GroupProductId) + ',', ',' + @ProductIds + ',') > 0
				FOR XML PATH(''))
			, '')
	
	RETURN @ProductIdList
END
GO
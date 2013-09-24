SET IDENTITY_INSERT [eaFunction] ON
GO

INSERT INTO [bodb_EAS].[dbo].[eaFunction]( 
			FuncID,
			[FuncName]
           ,[FuncDesc]
           ,[FuncKey]
           ,[ParentID]
           ,[ParentName]
           ,[CreatedDate]
           ,[ModifiedDate]
           ,[Creator]
           ,[Modifier]
           ,[DisplayOrder]
           ,[isTest]
           )
SELECT 1,'Administration','Manage group & user','Administration',0,'',current_timestamp,current_timestamp,5838421,5838421,10,0--dbaAdmin
UNION ALL
SELECT 2,'Manage Group','','ManageGroup',1,'Administration',current_timestamp,current_timestamp,5838421,5838421,10,0
UNION ALL
SELECT 3,'Manage User','','ManageUser',1,'Administration',current_timestamp,current_timestamp,5838421,5838421,20,0
UNION ALL
SELECT 4,'System Configuration','Manage menu & function','SystemConfiguration',0,'',current_timestamp,current_timestamp,5838421,5838421,20,0
UNION ALL
SELECT 5,'Manage Function','','ManageFunction',4,'System Configuration',current_timestamp,current_timestamp,5838421,5838421,10,0
UNION ALL
SELECT 6,'Manage Menu','','ManageMenu',4,'System Configuration',current_timestamp,current_timestamp,5838421,5838421,20,0
UNION ALL
SELECT 7,'Reports','','Reports',0,'', current_timestamp,current_timestamp,5838421,5838421, 30,0
UNION ALL
SELECT 8,'Daily Winloss','','DailyWinloss',7,'Reports',current_timestamp,current_timestamp,5838421,5838421,10,0
UNION ALL
SELECT 9,'Winloss Detail','','WinlossDetail',7,'Reports',current_timestamp,current_timestamp,5838421,5838421,20,0
UNION ALL
SELECT 10,'Manage Customer','','ManageCustomer',0,'', current_timestamp,current_timestamp,5838421,5838421, 40,0
UNION ALL
SELECT 11,'ExternalGroup','','ExternalGroup',0,'',current_timestamp,current_timestamp,5838421,5838421,50,0

SET IDENTITY_INSERT [eaFunction] OFF
GO

SET IDENTITY_INSERT eaMenu ON
GO
INSERT INTO [bodb_EAS].[dbo].[eaMenu](
			[MenuID]
		   ,[MenuName]
           ,[MenuDesc]
           ,[Url]
           ,[FuncID]
           ,[ParentID]
           ,[ParentName]
           ,[CreatedDate]
           ,[ModifiedDate]
           ,[DisplayOrder]
           ,[Creator]
           ,[Modifier]
           ,[active])
SELECT 1,'Administration','Menu item for admin',NULL,1,0,'',current_timestamp,current_timestamp,10,5838421,5838421,1
UNION ALL
SELECT 2,'Manage Group','','~/Admin/ManageGroup',2,1,'Administration',current_timestamp,current_timestamp,10,5838421,5838421,1
UNION ALL
SELECT 3,'Manage User','','~/Admin/ManageUser',3,1,'Administration',current_timestamp,current_timestamp,20,5838421,5838421,1
UNION ALL
SELECT 4,'Manage Function','','~/Admin/ManageFunction',5,1,'Administration',current_timestamp,current_timestamp,30,5838421,5838421,1
UNION ALL
SELECT 5,'Manage Menu','','~/Admin/ManageMenu',6,1,'Administration',current_timestamp,current_timestamp,40,5838421,5838421,1
UNION ALL
SELECT 6,'Reports','Menu item for reports',NULL,7,0,'',current_timestamp,current_timestamp,20,5838421,5838421,1
UNION ALL
SELECT 7,'Daily Winloss','','~/Reports/DailyWinlost',8,6,'Reports',current_timestamp,current_timestamp,10,5838421,5838421,1
UNION ALL
SELECT 8,'Winloss Detail','','~/Reports/WinlostDetail',9,6,'Reports',current_timestamp,current_timestamp,20,5838421,5838421,1
UNION ALL
SELECT 9,'Manage Customer','Menu super','~/Admin/ManageCustomer',10,0,'',current_timestamp,current_timestamp,30,5838421,5838421,1


SET IDENTITY_INSERT eaMenu OFF
GO

--create group IT
SET IDENTITY_INSERT eaGroup ON
GO

INSERT INTO [bodb_EAS].[dbo].[eaGroup]
           ( 
			[GroupID]
		   ,[GroupName]
           ,[Description]
           ,[CreatedDate]
           ,[Creator])
SELECT 1,'IT','IT',current_timestamp,5838421

SET IDENTITY_INSERT [eaGroup] ON
GO
--Add users IT group

DECLARE @user TABLE (userid int)

INSERT INTO @user (userid)
SELECT custid
FROM bodb02.dbo.custinfo WITH(NOLOCK)
WHERE username IN ('dbaJamie','pgmKiwi','dbaLukas')

INSERT INTO [bodb_EAS].[dbo].[eaUserInfo]
           ([UserID]
           ,[GroupID]
           ,[enabled]
           ,[creator]
           ,[CreatedDate])
SELECT userid, 1, 1, 8, current_timestamp
FROM @user

-- Grant permission
INSERT INTO [bodb_EAS].[dbo].[eaGroupPolicy]
           (GroupID
           ,[FuncID]
           ,[Policy])
SELECT 1, FuncID, 2
FROM eaFunction
/*
INSERT INTO [bodb_EAS].[dbo].[eaUserPolicy]
           ([UserID]
           ,[FuncID]
           ,[Policy])
SELECT userid, FuncID, 2
FROM @user, eaFunction
*/


--create group Internal
SET IDENTITY_INSERT eaGroup ON
GO

INSERT INTO [bodb_EAS].[dbo].[eaGroup]
           ( 
			[GroupID]
		   ,[GroupName]
           ,[Description]
           ,[CreatedDate]
           ,[Creator])
SELECT 2,'Finance','Finance',current_timestamp,5838421

SET IDENTITY_INSERT [eaGroup] ON
GO

-- Grant permission
INSERT INTO [bodb_EAS].[dbo].[eaGroupPolicy]
           (GroupID
           ,[FuncID]
           ,[Policy])
SELECT 2, FuncID, 2
FROM eaFunction
WHERE [FuncID] NOT IN (4,5,6)


/* these groups will not be added in UAT */
--create external group 
--SET IDENTITY_INSERT eaGroup ON
--GO

--INSERT INTO [bodb_EAS].[dbo].[eaGroup]
--           ( 
--			[GroupID]
--		   ,[GroupName]
--           ,[Description]
--           ,[CreatedDate]
--           ,[Creator])
--SELECT 3,'ACCDDD','External DDD Admins',current_timestamp,5838421
--UNION ALL
--SELECT 4,'ACCINDO','Indo site Admin',current_timestamp,5838421
--UNION ALL
--SELECT 5,'ACCIRR','IRR Currency System',current_timestamp,5838421
--UNION ALL
--SELECT 6,'ACCNTD','NTD Admins',current_timestamp,5838421
--UNION ALL
--SELECT 7,'ACCTHAI','For THAI currency Admins',current_timestamp,5838421
--UNION ALL
--SELECT 8,'ACCYEN','YEN Admins',current_timestamp,5838421
--UNION ALL
--SELECT 9,'ACCYEN789','External YEN Admins',current_timestamp,5838421
--UNION ALL
--SELECT 10,'ACCYEN889','External YEN Admins',current_timestamp,5838421

--SET IDENTITY_INSERT [eaGroup] ON
--GO
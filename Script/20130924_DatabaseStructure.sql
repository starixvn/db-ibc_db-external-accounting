

/*
	External accounting
	Task:	- create database 
			- create users [bodbExtAccNet], [vnteam], [vnDBA]
			- tables
	
*/





USE [master]
GO

CREATE DATABASE [bodb_EAS] ON  PRIMARY 
( NAME = N'bodb_EAS', FILENAME = N'C:\IBC_DB\bodb_EAS\bodb_EAS.mdf' , SIZE = 10240KB , MAXSIZE = UNLIMITED, FILEGROWTH = 1024KB ), 
 FILEGROUP [eaIndex] 
( NAME = N'eaIndex-01', FILENAME = N'C:\IBC_DB\bodb_EAS\eaIndex-01.ndf' , SIZE = 10240KB , MAXSIZE = UNLIMITED, FILEGROWTH = 10240KB ), 
 FILEGROUP [eaLogin] 
( NAME = N'eaLogin-01', FILENAME = N'C:\IBC_DB\bodb_EAS\eaLogin-01.ndf' , SIZE = 10240KB , MAXSIZE = UNLIMITED, FILEGROWTH = 10240KB ), 
 FILEGROUP [eaUserControl] 
( NAME = N'eaUserControl-01', FILENAME = N'C:\IBC_DB\bodb_EAS\eaUserControl-01.ndf' , SIZE = 10240KB , MAXSIZE = UNLIMITED, FILEGROWTH = 10240KB )
 LOG ON 
( NAME = N'bodb_EAS_log', FILENAME = N'C:\IBC_DB\bodb_EAS\bodb_EAS_log.ldf' , SIZE = 1024KB , MAXSIZE = 2048GB , FILEGROWTH = 10%)
GO

USE [bodb_EAS]
GO
CREATE USER [bodbExtAccNet] FOR LOGIN [bodbExtAccNet] 
GO
CREATE USER [vnteam] FOR LOGIN [vnteam]
GO
CREATE USER [vnDBA] FOR LOGIN [vnDBA]
GO

/* create tables */

GO
USE [bodb_EAS]
GO
CREATE TABLE [dbo].[eaUserInfo](
	[UserID] [int] NOT NULL,
	[GroupID] [int] NOT NULL,
	[enabled] [bit] NOT NULL,
	[creator] [int] NULL,
	[createddate] [datetime] NULL,
 CONSTRAINT [PK_eaUserInfo] PRIMARY KEY CLUSTERED 
(
	[UserID] ASC
)WITH (PAD_INDEX  = OFF, STATISTICS_NORECOMPUTE  = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS  = ON, ALLOW_PAGE_LOCKS  = ON) ON [eaUserControl]
) ON [eaUserControl]
GO

USE [bodb_EAS]
GO
CREATE TABLE [dbo].[eaUserPolicy](
	[UserID] [int] NOT NULL,
	[FuncID] [int] NOT NULL,
	[Policy] [tinyint] NOT NULL,
 CONSTRAINT [PK_eaUserPolicy] PRIMARY KEY CLUSTERED 
(
	[UserID] ASC,
	[FuncID] ASC
)WITH (PAD_INDEX  = OFF, STATISTICS_NORECOMPUTE  = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS  = ON, ALLOW_PAGE_LOCKS  = ON) ON [eaUserControl]
) ON [eaUserControl]
GO


USE [bodb_EAS]
GO
CREATE TABLE [dbo].[eaGroupPolicy](
	[GroupID] [int] NOT NULL,
	[FuncID] [int] NOT NULL,
	[Policy] [tinyint] NOT NULL,
 CONSTRAINT [PK_eaGroupPolicy] PRIMARY KEY CLUSTERED 
(
	[GroupID] ASC,
	[FuncID] ASC
)WITH (PAD_INDEX  = OFF, STATISTICS_NORECOMPUTE  = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS  = ON, ALLOW_PAGE_LOCKS  = ON) ON [eaUserControl]
) ON [eaUserControl]
GO


USE [bodb_EAS]
GO
CREATE TABLE [dbo].[eaOn_User](
	[on_userid] [int] IDENTITY(1,1) NOT NULL,
	[custid] [int] NULL,
	[reload_time] [smalldatetime] NULL,
	[IP] [varchar](50) NULL,
	[iskickedout] [bit] NULL,
	[NetSessionID] [varchar](50) NULL,
 CONSTRAINT [PK_eaOnUser] PRIMARY KEY CLUSTERED 
(
	[on_userid] ASC
)WITH (PAD_INDEX  = OFF, STATISTICS_NORECOMPUTE  = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS  = ON, ALLOW_PAGE_LOCKS  = ON) ON [eaLogin]
) ON [eaLogin]
GO

USE [bodb_EAS]
GO
CREATE TABLE [dbo].[eaMenu](
	[MenuID] [int] IDENTITY(1,1) NOT NULL,
	[MenuName] [varchar](50) NOT NULL,
	[MenuDesc] [varchar](100) NULL,
	[Url] [varchar](500) NULL,
	[FuncID] [int] NULL,
	[ParentID] [int] NOT NULL,
	[ParentName] [varchar](50) NULL,
	[DisplayOrder] [int] NULL,
	[active] [bit] NULL,
	[Creator] [int] NULL,
	[CreatedDate] [datetime] NULL,
	[Modifier] [int] NULL,
	[ModifiedDate] [datetime] NULL,
 CONSTRAINT [PK_eaMenu] PRIMARY KEY CLUSTERED 
(
	[MenuID] ASC
)WITH (PAD_INDEX  = OFF, STATISTICS_NORECOMPUTE  = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS  = ON, ALLOW_PAGE_LOCKS  = ON) ON [eaUserControl]
) ON [eaUserControl]
GO

USE [bodb_EAS]
GO
CREATE TABLE [dbo].[eaFunction](
	[FuncID] [int] IDENTITY(1,1) NOT NULL,
	[FuncName] [varchar](50) NOT NULL,
	[FuncDesc] [varchar](100) NULL,
	[FuncKey] [varchar](100) NOT NULL,
	[ParentID] [int] NULL,
	[ParentName] [varchar](50) NULL,
	[CreatedDate] [datetime] NULL,
	[Creator] [int] NULL,
	[Modifier] [int] NULL,
	[ModifiedDate] [datetime] NULL,
	[DisplayOrder] [int] NULL,
	[isTest] [bit] NULL,
 CONSTRAINT [PK_eaFunction] PRIMARY KEY CLUSTERED 
(
	[FuncID] ASC
)WITH (PAD_INDEX  = OFF, STATISTICS_NORECOMPUTE  = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS  = ON, ALLOW_PAGE_LOCKS  = ON) ON [eaUserControl]
) ON [eaUserControl]
GO



USE [bodb_EAS]
GO
CREATE TABLE [dbo].[eaGroup](
	[GroupID] [int] IDENTITY(1,1) NOT NULL,
	[GroupName] [varchar](100) NOT NULL,
	[Description] [varchar](200) NULL,
	[CreatedDate] [datetime] NULL,
	[Creator] [int] NULL,
 CONSTRAINT [PK_eaGroup] PRIMARY KEY CLUSTERED 
(
	[GroupID] ASC
)WITH (PAD_INDEX  = OFF, STATISTICS_NORECOMPUTE  = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS  = ON, ALLOW_PAGE_LOCKS  = ON) ON [eaUserControl]
) ON [eaUserControl]
GO

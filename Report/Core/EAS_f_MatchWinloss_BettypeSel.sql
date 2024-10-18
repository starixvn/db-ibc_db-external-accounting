/*<info serverAlias="DBAGE-bodb02" selecters="wsv_xnap" viewers="" isFunction="1" isNested="1"></info>*/
ALTER FUNCTION [dbo].[EAS_f_MatchWinloss_BettypeSel] ()
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
	SELECT TypeId 
	FROM (
		VALUES (1),	--Handicap
		(2),	--Odd/Even
		(3),	--Over/Under
		(4),	--Correct Score
		(5),	--FT.1X2
		(6),	--Total Goal
		(7),	--1H Handicap
		(8),	--1H Over/Under
		(10),	--Outright
		(12),	--1H Odd/Even
		(15),	--1H 1X2
		(20),	--Moneyline
		(21),	--1H Moneyline
		(22),	--Next Goal
		(29),	--System Parlay
		(30),	--1H Correct Score
		(126),	--1H Total Goal
		(152),	--Half Time/Full Time Correct Score
		(153),	--Game Handicap
		(154),	--Set X Winner
		(155),	--Set X Game Handicap
		(156),	--Set x Total Game Over/Under
		(219),	--Set X Points Handicap
		(405),	--2H Correct Score
		(501),	--Match Winner
		(609),	--Quarter X Handicap
		(610),	--Quarter X Over/Under
		(611),	--Quarter X Odd/Even
		(612),	--Quarter X Moneyline
		(701),	--Match Handicap
		(704),	--Match Points Handicap
		(705),	--Match Points Over/Under
		(707),	--Game X Winner
		(708),	--Game X Points Handicap
		(709),	--Game X Points Over/Under
		(3918),	--Set X Moneyline
		(9001),	--Map X Moneyline
		(9002),	--Map X Total Kills Handicap
		(9003),	--Map X Total Kills Over/Under
		(9008),	--Map X Total Towers Handicap
		(9058),	--Map X Duration Over/Under (Mins)
		(9059),	--Map X Rounds Handicap
		(9404),	--Home Inns Runs
		(9405)	--Away Inns Runs
	) AS t(TypeId)
GO

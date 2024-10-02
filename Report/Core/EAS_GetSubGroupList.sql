/*<info serverAlias="DBPOL-NAP_UserControl" executers="wsv_xnap" isFunction="0" isNested="0"></info>*/
CREATE PROCEDURE [dbo].[EAS_GetSubGroupList] 	
	@GroupID		INT, --ID of @GroupName
	@SubGroup		VARCHAR(50) = NULL,
	@SubGroupList   NVARCHAR(MAX) = NULL OUTPUT
	--
AS
/*
	Created by: Lewis
	Date: 2024-07-31
	Task : get subgroup list
	DB: DBPOL-NAP_UserControl
	Revisions:

		- 20240729@Lewis: Scale Out DBCust - Remove Linked Server [Redmine : #206895]

	Param's Explanation:  
		
		@GroupName: main group
		@SubGroup: sub groups of main group (default get all)
*/
BEGIN
	SET NOCOUNT ON

	-- Get list of subgroup
	DROP TABLE IF EXISTS #tmpSubGroup;
	CREATE TABLE #tmpSubGroup (GroupID INT, SubGroup VARCHAR(50))
	
	INSERT INTO #tmpSubGroup
	SELECT	GroupID,GroupName
	FROM	dbo.eaGroup WITH(NOLOCK)
	WHERE	ParentID = @GroupID
			AND GroupName = ISNULL(@SubGroup,GroupName);

	SELECT @SubGroupList = (SELECT GroupID,SubGroup FROM #tmpSubGroup FOR JSON PATH)

END
GO
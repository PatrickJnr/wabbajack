USE [wabbajack_prod]
GO
/****** Object:  User [wabbajack]    Script Date: 1/25/2020 9:54:22 PM ******/
CREATE USER [wabbajack] FOR LOGIN [wabbajack] WITH DEFAULT_SCHEMA=[dbo]
GO
ALTER ROLE [db_datareader] ADD MEMBER [wabbajack]
GO
ALTER ROLE [db_datawriter] ADD MEMBER [wabbajack]
GO
/****** Object:  UserDefinedTableType [dbo].[ArchiveContentType]    Script Date: 1/25/2020 9:54:22 PM ******/
CREATE TYPE [dbo].[ArchiveContentType] AS TABLE(
	[Parent] [bigint] NOT NULL,
	[Child] [bigint] NOT NULL,
	[Path] [varchar](max) NOT NULL
)
GO
/****** Object:  UserDefinedTableType [dbo].[IndexedFileType]    Script Date: 1/25/2020 9:54:22 PM ******/
CREATE TYPE [dbo].[IndexedFileType] AS TABLE(
	[Hash] [bigint] NOT NULL,
	[Sha256] [binary](32) NOT NULL,
	[Sha1] [binary](20) NOT NULL,
	[Md5] [binary](16) NOT NULL,
	[Crc32] [int] NOT NULL,
	[Size] [bigint] NOT NULL
)
GO
/****** Object:  UserDefinedFunction [dbo].[Base64ToLong]    Script Date: 1/25/2020 9:54:22 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Author:		<Author,,Name>
-- Create date: <Create Date, ,>
-- Description:	<Description, ,>
-- =============================================
CREATE FUNCTION [dbo].[Base64ToLong] 
(
	-- Add the parameters for the function here
	@Input varchar
)
RETURNS bigint
AS
BEGIN
	-- Declare the return variable here
	DECLARE @ResultVar bigint

	-- Add the T-SQL statements to compute the return value here
	SELECT @ResultVar = CAST('string' as varbinary(max)) FOR XML PATH(''), BINARY BASE64

	-- Return the result of the function
	RETURN @ResultVar

END
GO
/****** Object:  Table [dbo].[ArchiveContent]    Script Date: 1/25/2020 9:54:22 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[ArchiveContent](
	[Parent] [bigint] NOT NULL,
	[Child] [bigint] NOT NULL,
	[Path] [varchar](max) NOT NULL,
	[PathHash]  AS (hashbytes('SHA2_256',[Path])) PERSISTED NOT NULL,
 CONSTRAINT [PK_ArchiveContent] PRIMARY KEY CLUSTERED 
(
	[Parent] ASC,
	[PathHash] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
GO
/****** Object:  View [dbo].[AllArchiveContent]    Script Date: 1/25/2020 9:54:22 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE VIEW [dbo].[AllArchiveContent]
AS
WITH AllArchiveContent(TopParent, Parent, Path, PathHash, Child, Depth) AS (SELECT        pt.Parent, pt.Parent AS Expr1, pt.Path, pt.PathHash, pt.Child, 1 AS Depth
FROM            dbo.ArchiveContent AS pt LEFT OUTER JOIN
                        dbo.ArchiveContent AS gt ON pt.Parent = gt.Child
WHERE        (gt.Child IS NULL)
UNION ALL
SELECT        pt.TopParent, ct.Parent, ct.Path, ct.PathHash, ct.Child, pt.Depth + 1 AS Expr1
FROM            dbo.ArchiveContent AS ct INNER JOIN
                        AllArchiveContent AS pt ON ct.Parent = pt.Child)
    SELECT        TopParent, Parent, Path, PathHash, Child, Depth
     FROM            AllArchiveContent AS AllArchiveContent_1
GO
/****** Object:  Table [dbo].[IndexedFile]    Script Date: 1/25/2020 9:54:22 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[IndexedFile](
	[Hash] [bigint] NOT NULL,
	[Sha256] [binary](32) NOT NULL,
	[Sha1] [binary](20) NOT NULL,
	[Md5] [binary](16) NOT NULL,
	[Crc32] [int] NOT NULL,
	[Size] [bigint] NOT NULL,
 CONSTRAINT [PK_IndexedFile] PRIMARY KEY CLUSTERED 
(
	[Hash] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  StoredProcedure [dbo].[MergeIndexedFiles]    Script Date: 1/25/2020 9:54:22 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Author:		<Author,,Name>
-- Create date: <Create Date,,>
-- Description:	<Description,,>
-- =============================================
CREATE PROCEDURE [dbo].[MergeIndexedFiles]
	-- Add the parameters for the stored procedure here
	@Files dbo.IndexedFileType READONLY,
	@Contents dbo.ArchiveContentType READONLY
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;
	BEGIN TRANSACTION;

	MERGE dbo.IndexedFile AS TARGET
    USING @Files as SOURCE
    ON (TARGET.Hash = SOURCE.HASH)
    WHEN NOT MATCHED BY TARGET
    THEN INSERT (Hash, Sha256, Sha1, Md5, Crc32, Size) 
    VALUES (Source.Hash, Source.Sha256, Source.Sha1, Source.Md5, Source.Crc32, Source.Size);

	MERGE dbo.ArchiveContent AS TARGET
	USING @Contents as SOURCE
	ON (TARGET.Parent = SOURCE.Parent AND TARGET.PathHash = HASHBYTES('SHA2_256', SOURCE.Path))
	WHEN NOT MATCHED BY TARGET
	THEN INSERT (Parent, Child, Path) 
	VALUES (Source.Parent, Source.Child, Source.Path);

	COMMIT;

END
GO

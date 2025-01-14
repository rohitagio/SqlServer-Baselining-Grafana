USE [DBA]
GO

/*
	1) Create Partition Function
	2) Create Partition Scheme
	3) Create table [dbo].[performance_counters] using Partition scheme
	4) Create dbo.perfmon_files table using Partition scheme
	5) Create table [dbo].[os_task_list] using Partition scheme
	6) Create & Populate table [dbo].[BlitzFirst_WaitStats_Categories]
	7) Create view [dbo].[vw_wait_stats_deltas] 
	8) Add/Remove Partition Boundaries
	
	Self Steps
	-----------
	1) Create a public & default mail profile. https://github.com/imajaydwivedi/SQLDBA-SSMS-Solution/blob/0c2eaecca3dcf6745e3b2d262208c2f2257008bb/SQLDBATools-Inventory/DatabaseMail_Using_GMail.sql
	2) Create sp_WhoIsActive in [master] database. https://github.com/imajaydwivedi/SQLDBA-SSMS-Solution/blob/ae2541e37c28ea5b50887de993666bc81f29eba5/BlitzQueries/SCH-sp_WhoIsActive_v12_00(Modified).sql
	3) Install Brent Ozar's First Responder Kit. https://raw.githubusercontent.com/BrentOzarULTD/SQL-Server-First-Responder-Kit/dev/Install-All-Scripts.sql
			Install-DbaFirstResponderKit -SqlInstance workstation -Force -Verbose
	4) Install PowerShell modules
		Update-Module -Force -ErrorAction Continue -Verbose
		Update-Help -Force -ErrorAction Continue -Verbose
		Install-Module dbatools, enhancedhtml2, sqlserver, poshrsjob -Scope AllUsers -Force -ErrorAction Continue -Verbose

*/

-- Partition function & scheme for [datetime2]
create partition function pf_dba (datetime2)
as range right for values ('2022-03-25 00:00:00.0000000')
go

create partition scheme ps_dba as partition pf_dba all to ([primary])
go

-- Partition function & scheme for [datetime]
create partition function pf_dba_datetime (datetime)
as range right for values ('2022-03-25 00:00:00.000')
go

create partition scheme ps_dba_datetime as partition pf_dba_datetime all to ([primary])
go

/* ***** 3) Create table [dbo].[performance_counters] using Partition scheme ***************** */
-- drop table [dbo].[performance_counters]
create table [dbo].[performance_counters]
(
	[collection_time_utc] [datetime2](7) NOT NULL,
	[host_name] [varchar](255) NOT NULL,
	[path] [nvarchar](2000) NOT NULL,
	[object] [varchar](255) NOT NULL,
	[counter] [varchar](255) NOT NULL,
	[value] numeric(38,10) NULL,
	[instance] [nvarchar](255) NULL
) on ps_dba ([collection_time_utc])
go

create clustered index ci_performance_counters on [dbo].[performance_counters] 
	([collection_time_utc], [host_name], object, counter, [instance], [value]) on ps_dba ([collection_time_utc])
go
create nonclustered index nci_counter_collection_time_utc
	on [dbo].[performance_counters] ([counter],[collection_time_utc]) on ps_dba ([collection_time_utc])
GO

/* ***** 4) Create dbo.perfmon_files table using Partition scheme ***************** */
-- drop table [dbo].[perfmon_files]
CREATE TABLE [dbo].[perfmon_files]
(
	[host_name] [varchar](255) NOT NULL,
	[file_name] [varchar](255) NOT NULL,
	[file_path] [varchar](255) NOT NULL,
	[collection_time_utc] [datetime2](7) NOT NULL default sysutcdatetime(),
	CONSTRAINT [pk_perfmon_files] PRIMARY KEY CLUSTERED 
	(
		[file_name] ASC,
		[collection_time_utc] ASC
	) on ps_dba ([collection_time_utc])
) on ps_dba ([collection_time_utc])
GO

/* ***** 5) Create table [dbo].[os_task_list] using Partition scheme ***************** */
-- drop table [dbo].[os_task_list]
CREATE TABLE [dbo].[os_task_list]
(	
	[collection_time_utc] [datetime2](7) NOT NULL,
	[host_name] [varchar](255) NOT NULL,
	[task_name] [nvarchar](100) not null,
	[pid] bigint not null,
	[session_name] [varchar](20) null,
	[memory_kb] bigint NULL,
	[status] [varchar](30) NULL,
	[user_name] [varchar](200) NOT NULL,
	[cpu_time] [char](10) NOT NULL,
	[cpu_time_seconds] bigint NOT NULL,
	[window_title] [nvarchar](2000) NULL
) on ps_dba ([collection_time_utc])
go

create clustered index ci_os_task_list on [dbo].[os_task_list] ([collection_time_utc], [host_name], [task_name]) on ps_dba ([collection_time_utc])
go
create nonclustered index nci_user_name on [dbo].[os_task_list] ([collection_time_utc], [host_name], [user_name]) on ps_dba ([collection_time_utc])
go
create nonclustered index nci_window_title on [dbo].[os_task_list] ([collection_time_utc], [host_name], [window_title]) on ps_dba ([collection_time_utc])
go
create nonclustered index nci_cpu_time_seconds on [dbo].[os_task_list] ([collection_time_utc], [host_name], [cpu_time_seconds]) on ps_dba ([collection_time_utc])
go
create nonclustered index nci_memory_kb on [dbo].[os_task_list] ([collection_time_utc], [host_name], [memory_kb]) on ps_dba ([collection_time_utc])
go

-- drop table [dbo].[wait_stats]
CREATE TABLE [dbo].[wait_stats]
(
	[collection_time_utc] datetime2 not null,
	[wait_type] [nvarchar](60) NOT NULL,
	[waiting_tasks_count] [bigint] NOT NULL,
	[wait_time_ms] [bigint] NOT NULL,
	[max_wait_time_ms] [bigint] NOT NULL,
	[signal_wait_time_ms] [bigint] NOT NULL
) on ps_dba ([collection_time_utc])
GO

--create clustered index ci_wait_stats on [dbo].[wait_stats] ([collection_time_utc], [wait_type]) on ps_dba ([collection_time_utc])
--go

alter table [dbo].[wait_stats] add primary key ([collection_time_utc], [wait_type]) on ps_dba ([collection_time_utc])
go



/****** Object:  Table [dbo].[BlitzFirst_WaitStats_Categories]    Script Date: 4/23/2022 2:26:59 AM ******/
CREATE TABLE [dbo].[BlitzFirst_WaitStats_Categories]
(
	[WaitType] [nvarchar](60) NOT NULL,
	[WaitCategory] [nvarchar](128) NOT NULL,
	[Ignorable] [bit] NULL,
PRIMARY KEY CLUSTERED 
(
	[WaitType] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO

ALTER TABLE [dbo].[BlitzFirst_WaitStats_Categories] ADD  DEFAULT ((0)) FOR [Ignorable]
GO

IF OBJECT_ID('[dbo].[BlitzFirst_WaitStats_Categories]') IS NOT NULL AND NOT EXISTS (SELECT 1 FROM [dbo].[BlitzFirst_WaitStats_Categories])
BEGIN
	--TRUNCATE TABLE [dbo].[BlitzFirst_WaitStats_Categories];
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('ASYNC_IO_COMPLETION','Other Disk IO',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('ASYNC_NETWORK_IO','Network IO',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('BACKUPIO','Other Disk IO',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('BROKER_CONNECTION_RECEIVE_TASK','Service Broker',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('BROKER_DISPATCHER','Service Broker',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('BROKER_ENDPOINT_STATE_MUTEX','Service Broker',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('BROKER_EVENTHANDLER','Service Broker',1);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('BROKER_FORWARDER','Service Broker',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('BROKER_INIT','Service Broker',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('BROKER_MASTERSTART','Service Broker',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('BROKER_RECEIVE_WAITFOR','User Wait',1);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('BROKER_REGISTERALLENDPOINTS','Service Broker',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('BROKER_SERVICE','Service Broker',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('BROKER_SHUTDOWN','Service Broker',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('BROKER_START','Service Broker',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('BROKER_TASK_SHUTDOWN','Service Broker',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('BROKER_TASK_STOP','Service Broker',1);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('BROKER_TASK_SUBMIT','Service Broker',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('BROKER_TO_FLUSH','Service Broker',1);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('BROKER_TRANSMISSION_OBJECT','Service Broker',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('BROKER_TRANSMISSION_TABLE','Service Broker',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('BROKER_TRANSMISSION_WORK','Service Broker',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('BROKER_TRANSMITTER','Service Broker',1);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('CHECKPOINT_QUEUE','Idle',1);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('CHKPT','Tran Log IO',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('CLR_AUTO_EVENT','SQL CLR',1);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('CLR_CRST','SQL CLR',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('CLR_JOIN','SQL CLR',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('CLR_MANUAL_EVENT','SQL CLR',1);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('CLR_MEMORY_SPY','SQL CLR',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('CLR_MONITOR','SQL CLR',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('CLR_RWLOCK_READER','SQL CLR',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('CLR_RWLOCK_WRITER','SQL CLR',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('CLR_SEMAPHORE','SQL CLR',1);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('CLR_TASK_START','SQL CLR',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('CLRHOST_STATE_ACCESS','SQL CLR',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('CMEMPARTITIONED','Memory',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('CMEMTHREAD','Memory',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('CXPACKET','Parallelism',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('CXCONSUMER','Parallelism',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('DBMIRROR_DBM_EVENT','Mirroring',1);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('DBMIRROR_DBM_MUTEX','Mirroring',1);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('DBMIRROR_EVENTS_QUEUE','Mirroring',1);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('DBMIRROR_SEND','Mirroring',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('DBMIRROR_WORKER_QUEUE','Mirroring',1);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('DBMIRRORING_CMD','Mirroring',1);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('DIRTY_PAGE_POLL','Other',1);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('DIRTY_PAGE_TABLE_LOCK','Replication',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('DISPATCHER_QUEUE_SEMAPHORE','Other',1);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('DPT_ENTRY_LOCK','Replication',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('DTC','Transaction',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('DTC_ABORT_REQUEST','Transaction',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('DTC_RESOLVE','Transaction',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('DTC_STATE','Transaction',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('DTC_TMDOWN_REQUEST','Transaction',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('DTC_WAITFOR_OUTCOME','Transaction',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('DTCNEW_ENLIST','Transaction',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('DTCNEW_PREPARE','Transaction',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('DTCNEW_RECOVERY','Transaction',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('DTCNEW_TM','Transaction',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('DTCNEW_TRANSACTION_ENLISTMENT','Transaction',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('DTCPNTSYNC','Transaction',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('EE_PMOLOCK','Memory',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('EXCHANGE','Parallelism',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('EXTERNAL_SCRIPT_NETWORK_IOF','Network IO',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('FCB_REPLICA_READ','Replication',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('FCB_REPLICA_WRITE','Replication',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('FT_COMPROWSET_RWLOCK','Full Text Search',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('FT_IFTS_RWLOCK','Full Text Search',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('FT_IFTS_SCHEDULER_IDLE_WAIT','Idle',1);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('FT_IFTSHC_MUTEX','Full Text Search',1);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('FT_IFTSISM_MUTEX','Full Text Search',1);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('FT_MASTER_MERGE','Full Text Search',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('FT_MASTER_MERGE_COORDINATOR','Full Text Search',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('FT_METADATA_MUTEX','Full Text Search',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('FT_PROPERTYLIST_CACHE','Full Text Search',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('FT_RESTART_CRAWL','Full Text Search',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('FULLTEXT GATHERER','Full Text Search',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('HADR_AG_MUTEX','Replication',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('HADR_AR_CRITICAL_SECTION_ENTRY','Replication',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('HADR_AR_MANAGER_MUTEX','Replication',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('HADR_AR_UNLOAD_COMPLETED','Replication',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('HADR_ARCONTROLLER_NOTIFICATIONS_SUBSCRIBER_LIST','Replication',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('HADR_BACKUP_BULK_LOCK','Replication',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('HADR_BACKUP_QUEUE','Replication',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('HADR_CLUSAPI_CALL','Replication',1);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('HADR_COMPRESSED_CACHE_SYNC','Replication',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('HADR_CONNECTIVITY_INFO','Replication',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('HADR_DATABASE_FLOW_CONTROL','Replication',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('HADR_DATABASE_VERSIONING_STATE','Replication',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('HADR_DATABASE_WAIT_FOR_RECOVERY','Replication',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('HADR_DATABASE_WAIT_FOR_RESTART','Replication',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('HADR_DATABASE_WAIT_FOR_TRANSITION_TO_VERSIONING','Replication',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('HADR_DB_COMMAND','Replication',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('HADR_DB_OP_COMPLETION_SYNC','Replication',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('HADR_DB_OP_START_SYNC','Replication',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('HADR_DBR_SUBSCRIBER','Replication',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('HADR_DBR_SUBSCRIBER_FILTER_LIST','Replication',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('HADR_DBSEEDING','Replication',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('HADR_DBSEEDING_LIST','Replication',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('HADR_DBSTATECHANGE_SYNC','Replication',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('HADR_FABRIC_CALLBACK','Replication',1);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('HADR_FILESTREAM_BLOCK_FLUSH','Replication',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('HADR_FILESTREAM_FILE_CLOSE','Replication',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('HADR_FILESTREAM_FILE_REQUEST','Replication',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('HADR_FILESTREAM_IOMGR','Replication',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('HADR_FILESTREAM_IOMGR_IOCOMPLETION','Replication',1);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('HADR_FILESTREAM_MANAGER','Replication',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('HADR_FILESTREAM_PREPROC','Replication',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('HADR_GROUP_COMMIT','Replication',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('HADR_LOGCAPTURE_SYNC','Replication',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('HADR_LOGCAPTURE_WAIT','Replication',1);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('HADR_LOGPROGRESS_SYNC','Replication',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('HADR_NOTIFICATION_DEQUEUE','Replication',1);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('HADR_NOTIFICATION_WORKER_EXCLUSIVE_ACCESS','Replication',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('HADR_NOTIFICATION_WORKER_STARTUP_SYNC','Replication',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('HADR_NOTIFICATION_WORKER_TERMINATION_SYNC','Replication',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('HADR_PARTNER_SYNC','Replication',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('HADR_READ_ALL_NETWORKS','Replication',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('HADR_RECOVERY_WAIT_FOR_CONNECTION','Replication',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('HADR_RECOVERY_WAIT_FOR_UNDO','Replication',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('HADR_REPLICAINFO_SYNC','Replication',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('HADR_SEEDING_CANCELLATION','Replication',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('HADR_SEEDING_FILE_LIST','Replication',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('HADR_SEEDING_LIMIT_BACKUPS','Replication',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('HADR_SEEDING_SYNC_COMPLETION','Replication',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('HADR_SEEDING_TIMEOUT_TASK','Replication',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('HADR_SEEDING_WAIT_FOR_COMPLETION','Replication',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('HADR_SYNC_COMMIT','Replication',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('HADR_SYNCHRONIZING_THROTTLE','Replication',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('HADR_TDS_LISTENER_SYNC','Replication',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('HADR_TDS_LISTENER_SYNC_PROCESSING','Replication',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('HADR_THROTTLE_LOG_RATE_GOVERNOR','Log Rate Governor',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('HADR_TIMER_TASK','Replication',1);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('HADR_TRANSPORT_DBRLIST','Replication',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('HADR_TRANSPORT_FLOW_CONTROL','Replication',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('HADR_TRANSPORT_SESSION','Replication',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('HADR_WORK_POOL','Replication',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('HADR_WORK_QUEUE','Replication',1);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('HADR_XRF_STACK_ACCESS','Replication',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('INSTANCE_LOG_RATE_GOVERNOR','Log Rate Governor',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('IO_COMPLETION','Other Disk IO',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('IO_QUEUE_LIMIT','Other Disk IO',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('IO_RETRY','Other Disk IO',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('LATCH_DT','Latch',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('LATCH_EX','Latch',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('LATCH_KP','Latch',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('LATCH_NL','Latch',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('LATCH_SH','Latch',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('LATCH_UP','Latch',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('LAZYWRITER_SLEEP','Idle',1);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('LCK_M_BU','Lock',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('LCK_M_BU_ABORT_BLOCKERS','Lock',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('LCK_M_BU_LOW_PRIORITY','Lock',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('LCK_M_IS','Lock',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('LCK_M_IS_ABORT_BLOCKERS','Lock',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('LCK_M_IS_LOW_PRIORITY','Lock',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('LCK_M_IU','Lock',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('LCK_M_IU_ABORT_BLOCKERS','Lock',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('LCK_M_IU_LOW_PRIORITY','Lock',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('LCK_M_IX','Lock',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('LCK_M_IX_ABORT_BLOCKERS','Lock',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('LCK_M_IX_LOW_PRIORITY','Lock',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('LCK_M_RIn_NL','Lock',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('LCK_M_RIn_NL_ABORT_BLOCKERS','Lock',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('LCK_M_RIn_NL_LOW_PRIORITY','Lock',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('LCK_M_RIn_S','Lock',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('LCK_M_RIn_S_ABORT_BLOCKERS','Lock',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('LCK_M_RIn_S_LOW_PRIORITY','Lock',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('LCK_M_RIn_U','Lock',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('LCK_M_RIn_U_ABORT_BLOCKERS','Lock',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('LCK_M_RIn_U_LOW_PRIORITY','Lock',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('LCK_M_RIn_X','Lock',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('LCK_M_RIn_X_ABORT_BLOCKERS','Lock',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('LCK_M_RIn_X_LOW_PRIORITY','Lock',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('LCK_M_RS_S','Lock',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('LCK_M_RS_S_ABORT_BLOCKERS','Lock',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('LCK_M_RS_S_LOW_PRIORITY','Lock',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('LCK_M_RS_U','Lock',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('LCK_M_RS_U_ABORT_BLOCKERS','Lock',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('LCK_M_RS_U_LOW_PRIORITY','Lock',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('LCK_M_RX_S','Lock',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('LCK_M_RX_S_ABORT_BLOCKERS','Lock',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('LCK_M_RX_S_LOW_PRIORITY','Lock',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('LCK_M_RX_U','Lock',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('LCK_M_RX_U_ABORT_BLOCKERS','Lock',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('LCK_M_RX_U_LOW_PRIORITY','Lock',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('LCK_M_RX_X','Lock',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('LCK_M_RX_X_ABORT_BLOCKERS','Lock',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('LCK_M_RX_X_LOW_PRIORITY','Lock',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('LCK_M_S','Lock',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('LCK_M_S_ABORT_BLOCKERS','Lock',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('LCK_M_S_LOW_PRIORITY','Lock',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('LCK_M_SCH_M','Lock',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('LCK_M_SCH_M_ABORT_BLOCKERS','Lock',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('LCK_M_SCH_M_LOW_PRIORITY','Lock',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('LCK_M_SCH_S','Lock',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('LCK_M_SCH_S_ABORT_BLOCKERS','Lock',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('LCK_M_SCH_S_LOW_PRIORITY','Lock',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('LCK_M_SIU','Lock',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('LCK_M_SIU_ABORT_BLOCKERS','Lock',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('LCK_M_SIU_LOW_PRIORITY','Lock',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('LCK_M_SIX','Lock',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('LCK_M_SIX_ABORT_BLOCKERS','Lock',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('LCK_M_SIX_LOW_PRIORITY','Lock',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('LCK_M_U','Lock',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('LCK_M_U_ABORT_BLOCKERS','Lock',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('LCK_M_U_LOW_PRIORITY','Lock',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('LCK_M_UIX','Lock',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('LCK_M_UIX_ABORT_BLOCKERS','Lock',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('LCK_M_UIX_LOW_PRIORITY','Lock',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('LCK_M_X','Lock',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('LCK_M_X_ABORT_BLOCKERS','Lock',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('LCK_M_X_LOW_PRIORITY','Lock',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('LOG_RATE_GOVERNOR','Tran Log IO',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('LOGBUFFER','Tran Log IO',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('LOGMGR','Tran Log IO',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('LOGMGR_FLUSH','Tran Log IO',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('LOGMGR_PMM_LOG','Tran Log IO',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('LOGMGR_QUEUE','Idle',1);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('LOGMGR_RESERVE_APPEND','Tran Log IO',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('MEMORY_ALLOCATION_EXT','Memory',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('MEMORY_GRANT_UPDATE','Memory',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('MSQL_XACT_MGR_MUTEX','Transaction',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('MSQL_XACT_MUTEX','Transaction',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('MSSEARCH','Full Text Search',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('NET_WAITFOR_PACKET','Network IO',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('ONDEMAND_TASK_QUEUE','Idle',1);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('PAGEIOLATCH_DT','Buffer IO',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('PAGEIOLATCH_EX','Buffer IO',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('PAGEIOLATCH_KP','Buffer IO',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('PAGEIOLATCH_NL','Buffer IO',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('PAGEIOLATCH_SH','Buffer IO',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('PAGEIOLATCH_UP','Buffer IO',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('PAGELATCH_DT','Buffer Latch',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('PAGELATCH_EX','Buffer Latch',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('PAGELATCH_KP','Buffer Latch',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('PAGELATCH_NL','Buffer Latch',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('PAGELATCH_SH','Buffer Latch',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('PAGELATCH_UP','Buffer Latch',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('PARALLEL_REDO_DRAIN_WORKER','Replication',1);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('PARALLEL_REDO_FLOW_CONTROL','Replication',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('PARALLEL_REDO_LOG_CACHE','Replication',1);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('PARALLEL_REDO_TRAN_LIST','Replication',1);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('PARALLEL_REDO_TRAN_TURN','Replication',1);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('PARALLEL_REDO_WORKER_SYNC','Replication',1);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('PARALLEL_REDO_WORKER_WAIT_WORK','Replication',1);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('POOL_LOG_RATE_GOVERNOR','Log Rate Governor',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('PREEMPTIVE_ABR','Preemptive',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('PREEMPTIVE_CLOSEBACKUPMEDIA','Preemptive',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('PREEMPTIVE_CLOSEBACKUPTAPE','Preemptive',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('PREEMPTIVE_CLOSEBACKUPVDIDEVICE','Preemptive',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('PREEMPTIVE_CLUSAPI_CLUSTERRESOURCECONTROL','Preemptive',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('PREEMPTIVE_COM_COCREATEINSTANCE','Preemptive',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('PREEMPTIVE_COM_COGETCLASSOBJECT','Preemptive',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('PREEMPTIVE_COM_CREATEACCESSOR','Preemptive',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('PREEMPTIVE_COM_DELETEROWS','Preemptive',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('PREEMPTIVE_COM_GETCOMMANDTEXT','Preemptive',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('PREEMPTIVE_COM_GETDATA','Preemptive',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('PREEMPTIVE_COM_GETNEXTROWS','Preemptive',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('PREEMPTIVE_COM_GETRESULT','Preemptive',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('PREEMPTIVE_COM_GETROWSBYBOOKMARK','Preemptive',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('PREEMPTIVE_COM_LBFLUSH','Preemptive',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('PREEMPTIVE_COM_LBLOCKREGION','Preemptive',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('PREEMPTIVE_COM_LBREADAT','Preemptive',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('PREEMPTIVE_COM_LBSETSIZE','Preemptive',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('PREEMPTIVE_COM_LBSTAT','Preemptive',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('PREEMPTIVE_COM_LBUNLOCKREGION','Preemptive',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('PREEMPTIVE_COM_LBWRITEAT','Preemptive',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('PREEMPTIVE_COM_QUERYINTERFACE','Preemptive',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('PREEMPTIVE_COM_RELEASE','Preemptive',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('PREEMPTIVE_COM_RELEASEACCESSOR','Preemptive',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('PREEMPTIVE_COM_RELEASEROWS','Preemptive',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('PREEMPTIVE_COM_RELEASESESSION','Preemptive',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('PREEMPTIVE_COM_RESTARTPOSITION','Preemptive',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('PREEMPTIVE_COM_SEQSTRMREAD','Preemptive',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('PREEMPTIVE_COM_SEQSTRMREADANDWRITE','Preemptive',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('PREEMPTIVE_COM_SETDATAFAILURE','Preemptive',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('PREEMPTIVE_COM_SETPARAMETERINFO','Preemptive',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('PREEMPTIVE_COM_SETPARAMETERPROPERTIES','Preemptive',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('PREEMPTIVE_COM_STRMLOCKREGION','Preemptive',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('PREEMPTIVE_COM_STRMSEEKANDREAD','Preemptive',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('PREEMPTIVE_COM_STRMSEEKANDWRITE','Preemptive',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('PREEMPTIVE_COM_STRMSETSIZE','Preemptive',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('PREEMPTIVE_COM_STRMSTAT','Preemptive',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('PREEMPTIVE_COM_STRMUNLOCKREGION','Preemptive',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('PREEMPTIVE_CONSOLEWRITE','Preemptive',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('PREEMPTIVE_CREATEPARAM','Preemptive',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('PREEMPTIVE_DEBUG','Preemptive',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('PREEMPTIVE_DFSADDLINK','Preemptive',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('PREEMPTIVE_DFSLINKEXISTCHECK','Preemptive',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('PREEMPTIVE_DFSLINKHEALTHCHECK','Preemptive',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('PREEMPTIVE_DFSREMOVELINK','Preemptive',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('PREEMPTIVE_DFSREMOVEROOT','Preemptive',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('PREEMPTIVE_DFSROOTFOLDERCHECK','Preemptive',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('PREEMPTIVE_DFSROOTINIT','Preemptive',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('PREEMPTIVE_DFSROOTSHARECHECK','Preemptive',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('PREEMPTIVE_DTC_ABORT','Preemptive',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('PREEMPTIVE_DTC_ABORTREQUESTDONE','Preemptive',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('PREEMPTIVE_DTC_BEGINTRANSACTION','Preemptive',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('PREEMPTIVE_DTC_COMMITREQUESTDONE','Preemptive',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('PREEMPTIVE_DTC_ENLIST','Preemptive',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('PREEMPTIVE_DTC_PREPAREREQUESTDONE','Preemptive',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('PREEMPTIVE_FILESIZEGET','Preemptive',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('PREEMPTIVE_FSAOLEDB_ABORTTRANSACTION','Preemptive',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('PREEMPTIVE_FSAOLEDB_COMMITTRANSACTION','Preemptive',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('PREEMPTIVE_FSAOLEDB_STARTTRANSACTION','Preemptive',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('PREEMPTIVE_FSRECOVER_UNCONDITIONALUNDO','Preemptive',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('PREEMPTIVE_GETRMINFO','Preemptive',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('PREEMPTIVE_HADR_LEASE_MECHANISM','Preemptive',1);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('PREEMPTIVE_HTTP_EVENT_WAIT','Preemptive',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('PREEMPTIVE_HTTP_REQUEST','Preemptive',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('PREEMPTIVE_LOCKMONITOR','Preemptive',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('PREEMPTIVE_MSS_RELEASE','Preemptive',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('PREEMPTIVE_ODBCOPS','Preemptive',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('PREEMPTIVE_OLE_UNINIT','Preemptive',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('PREEMPTIVE_OLEDB_ABORTORCOMMITTRAN','Preemptive',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('PREEMPTIVE_OLEDB_ABORTTRAN','Preemptive',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('PREEMPTIVE_OLEDB_GETDATASOURCE','Preemptive',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('PREEMPTIVE_OLEDB_GETLITERALINFO','Preemptive',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('PREEMPTIVE_OLEDB_GETPROPERTIES','Preemptive',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('PREEMPTIVE_OLEDB_GETPROPERTYINFO','Preemptive',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('PREEMPTIVE_OLEDB_GETSCHEMALOCK','Preemptive',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('PREEMPTIVE_OLEDB_JOINTRANSACTION','Preemptive',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('PREEMPTIVE_OLEDB_RELEASE','Preemptive',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('PREEMPTIVE_OLEDB_SETPROPERTIES','Preemptive',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('PREEMPTIVE_OLEDBOPS','Preemptive',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('PREEMPTIVE_OS_ACCEPTSECURITYCONTEXT','Preemptive',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('PREEMPTIVE_OS_ACQUIRECREDENTIALSHANDLE','Preemptive',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('PREEMPTIVE_OS_AUTHENTICATIONOPS','Preemptive',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('PREEMPTIVE_OS_AUTHORIZATIONOPS','Preemptive',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('PREEMPTIVE_OS_AUTHZGETINFORMATIONFROMCONTEXT','Preemptive',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('PREEMPTIVE_OS_AUTHZINITIALIZECONTEXTFROMSID','Preemptive',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('PREEMPTIVE_OS_AUTHZINITIALIZERESOURCEMANAGER','Preemptive',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('PREEMPTIVE_OS_BACKUPREAD','Preemptive',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('PREEMPTIVE_OS_CLOSEHANDLE','Preemptive',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('PREEMPTIVE_OS_CLUSTEROPS','Preemptive',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('PREEMPTIVE_OS_COMOPS','Preemptive',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('PREEMPTIVE_OS_COMPLETEAUTHTOKEN','Preemptive',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('PREEMPTIVE_OS_COPYFILE','Preemptive',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('PREEMPTIVE_OS_CREATEDIRECTORY','Preemptive',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('PREEMPTIVE_OS_CREATEFILE','Preemptive',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('PREEMPTIVE_OS_CRYPTACQUIRECONTEXT','Preemptive',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('PREEMPTIVE_OS_CRYPTIMPORTKEY','Preemptive',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('PREEMPTIVE_OS_CRYPTOPS','Preemptive',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('PREEMPTIVE_OS_DECRYPTMESSAGE','Preemptive',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('PREEMPTIVE_OS_DELETEFILE','Preemptive',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('PREEMPTIVE_OS_DELETESECURITYCONTEXT','Preemptive',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('PREEMPTIVE_OS_DEVICEIOCONTROL','Preemptive',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('PREEMPTIVE_OS_DEVICEOPS','Preemptive',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('PREEMPTIVE_OS_DIRSVC_NETWORKOPS','Preemptive',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('PREEMPTIVE_OS_DISCONNECTNAMEDPIPE','Preemptive',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('PREEMPTIVE_OS_DOMAINSERVICESOPS','Preemptive',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('PREEMPTIVE_OS_DSGETDCNAME','Preemptive',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('PREEMPTIVE_OS_DTCOPS','Preemptive',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('PREEMPTIVE_OS_ENCRYPTMESSAGE','Preemptive',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('PREEMPTIVE_OS_FILEOPS','Preemptive',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('PREEMPTIVE_OS_FINDFILE','Preemptive',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('PREEMPTIVE_OS_FLUSHFILEBUFFERS','Preemptive',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('PREEMPTIVE_OS_FORMATMESSAGE','Preemptive',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('PREEMPTIVE_OS_FREECREDENTIALSHANDLE','Preemptive',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('PREEMPTIVE_OS_FREELIBRARY','Preemptive',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('PREEMPTIVE_OS_GENERICOPS','Preemptive',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('PREEMPTIVE_OS_GETADDRINFO','Preemptive',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('PREEMPTIVE_OS_GETCOMPRESSEDFILESIZE','Preemptive',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('PREEMPTIVE_OS_GETDISKFREESPACE','Preemptive',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('PREEMPTIVE_OS_GETFILEATTRIBUTES','Preemptive',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('PREEMPTIVE_OS_GETFILESIZE','Preemptive',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('PREEMPTIVE_OS_GETFINALFILEPATHBYHANDLE','Preemptive',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('PREEMPTIVE_OS_GETLONGPATHNAME','Preemptive',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('PREEMPTIVE_OS_GETPROCADDRESS','Preemptive',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('PREEMPTIVE_OS_GETVOLUMENAMEFORVOLUMEMOUNTPOINT','Preemptive',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('PREEMPTIVE_OS_GETVOLUMEPATHNAME','Preemptive',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('PREEMPTIVE_OS_INITIALIZESECURITYCONTEXT','Preemptive',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('PREEMPTIVE_OS_LIBRARYOPS','Preemptive',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('PREEMPTIVE_OS_LOADLIBRARY','Preemptive',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('PREEMPTIVE_OS_LOGONUSER','Preemptive',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('PREEMPTIVE_OS_LOOKUPACCOUNTSID','Preemptive',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('PREEMPTIVE_OS_MESSAGEQUEUEOPS','Preemptive',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('PREEMPTIVE_OS_MOVEFILE','Preemptive',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('PREEMPTIVE_OS_NETGROUPGETUSERS','Preemptive',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('PREEMPTIVE_OS_NETLOCALGROUPGETMEMBERS','Preemptive',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('PREEMPTIVE_OS_NETUSERGETGROUPS','Preemptive',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('PREEMPTIVE_OS_NETUSERGETLOCALGROUPS','Preemptive',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('PREEMPTIVE_OS_NETUSERMODALSGET','Preemptive',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('PREEMPTIVE_OS_NETVALIDATEPASSWORDPOLICY','Preemptive',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('PREEMPTIVE_OS_NETVALIDATEPASSWORDPOLICYFREE','Preemptive',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('PREEMPTIVE_OS_OPENDIRECTORY','Preemptive',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('PREEMPTIVE_OS_PDH_WMI_INIT','Preemptive',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('PREEMPTIVE_OS_PIPEOPS','Preemptive',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('PREEMPTIVE_OS_PROCESSOPS','Preemptive',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('PREEMPTIVE_OS_QUERYCONTEXTATTRIBUTES','Preemptive',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('PREEMPTIVE_OS_QUERYREGISTRY','Preemptive',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('PREEMPTIVE_OS_QUERYSECURITYCONTEXTTOKEN','Preemptive',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('PREEMPTIVE_OS_REMOVEDIRECTORY','Preemptive',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('PREEMPTIVE_OS_REPORTEVENT','Preemptive',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('PREEMPTIVE_OS_REVERTTOSELF','Preemptive',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('PREEMPTIVE_OS_RSFXDEVICEOPS','Preemptive',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('PREEMPTIVE_OS_SECURITYOPS','Preemptive',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('PREEMPTIVE_OS_SERVICEOPS','Preemptive',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('PREEMPTIVE_OS_SETENDOFFILE','Preemptive',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('PREEMPTIVE_OS_SETFILEPOINTER','Preemptive',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('PREEMPTIVE_OS_SETFILEVALIDDATA','Preemptive',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('PREEMPTIVE_OS_SETNAMEDSECURITYINFO','Preemptive',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('PREEMPTIVE_OS_SQLCLROPS','Preemptive',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('PREEMPTIVE_OS_SQMLAUNCH','Preemptive',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('PREEMPTIVE_OS_VERIFYSIGNATURE','Preemptive',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('PREEMPTIVE_OS_VERIFYTRUST','Preemptive',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('PREEMPTIVE_OS_VSSOPS','Preemptive',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('PREEMPTIVE_OS_WAITFORSINGLEOBJECT','Preemptive',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('PREEMPTIVE_OS_WINSOCKOPS','Preemptive',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('PREEMPTIVE_OS_WRITEFILE','Preemptive',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('PREEMPTIVE_OS_WRITEFILEGATHER','Preemptive',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('PREEMPTIVE_OS_WSASETLASTERROR','Preemptive',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('PREEMPTIVE_REENLIST','Preemptive',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('PREEMPTIVE_RESIZELOG','Preemptive',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('PREEMPTIVE_ROLLFORWARDREDO','Preemptive',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('PREEMPTIVE_ROLLFORWARDUNDO','Preemptive',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('PREEMPTIVE_SB_STOPENDPOINT','Preemptive',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('PREEMPTIVE_SERVER_STARTUP','Preemptive',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('PREEMPTIVE_SETRMINFO','Preemptive',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('PREEMPTIVE_SHAREDMEM_GETDATA','Preemptive',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('PREEMPTIVE_SNIOPEN','Preemptive',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('PREEMPTIVE_SOSHOST','Preemptive',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('PREEMPTIVE_SOSTESTING','Preemptive',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('PREEMPTIVE_SP_SERVER_DIAGNOSTICS','Preemptive',1);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('PREEMPTIVE_STARTRM','Preemptive',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('PREEMPTIVE_STREAMFCB_CHECKPOINT','Preemptive',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('PREEMPTIVE_STREAMFCB_RECOVER','Preemptive',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('PREEMPTIVE_STRESSDRIVER','Preemptive',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('PREEMPTIVE_TESTING','Preemptive',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('PREEMPTIVE_TRANSIMPORT','Preemptive',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('PREEMPTIVE_UNMARSHALPROPAGATIONTOKEN','Preemptive',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('PREEMPTIVE_VSS_CREATESNAPSHOT','Preemptive',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('PREEMPTIVE_VSS_CREATEVOLUMESNAPSHOT','Preemptive',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('PREEMPTIVE_XE_CALLBACKEXECUTE','Preemptive',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('PREEMPTIVE_XE_CX_FILE_OPEN','Preemptive',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('PREEMPTIVE_XE_CX_HTTP_CALL','Preemptive',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('PREEMPTIVE_XE_DISPATCHER','Preemptive',1);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('PREEMPTIVE_XE_ENGINEINIT','Preemptive',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('PREEMPTIVE_XE_GETTARGETSTATE','Preemptive',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('PREEMPTIVE_XE_SESSIONCOMMIT','Preemptive',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('PREEMPTIVE_XE_TARGETFINALIZE','Preemptive',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('PREEMPTIVE_XE_TARGETINIT','Preemptive',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('PREEMPTIVE_XE_TIMERRUN','Preemptive',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('PREEMPTIVE_XETESTING','Preemptive',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('PWAIT_HADR_ACTION_COMPLETED','Replication',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('PWAIT_HADR_CHANGE_NOTIFIER_TERMINATION_SYNC','Replication',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('PWAIT_HADR_CLUSTER_INTEGRATION','Replication',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('PWAIT_HADR_FAILOVER_COMPLETED','Replication',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('PWAIT_HADR_JOIN','Replication',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('PWAIT_HADR_OFFLINE_COMPLETED','Replication',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('PWAIT_HADR_ONLINE_COMPLETED','Replication',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('PWAIT_HADR_POST_ONLINE_COMPLETED','Replication',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('PWAIT_HADR_SERVER_READY_CONNECTIONS','Replication',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('PWAIT_HADR_WORKITEM_COMPLETED','Replication',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('PWAIT_HADRSIM','Replication',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('PWAIT_RESOURCE_SEMAPHORE_FT_PARALLEL_QUERY_SYNC','Full Text Search',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('QDS_ASYNC_QUEUE','Other',1);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('QDS_CLEANUP_STALE_QUERIES_TASK_MAIN_LOOP_SLEEP','Other',1);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('QDS_PERSIST_TASK_MAIN_LOOP_SLEEP','Other',1);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('QDS_SHUTDOWN_QUEUE','Other',1);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('QUERY_TRACEOUT','Tracing',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('REDO_THREAD_PENDING_WORK','Other',1);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('REPL_CACHE_ACCESS','Replication',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('REPL_HISTORYCACHE_ACCESS','Replication',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('REPL_SCHEMA_ACCESS','Replication',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('REPL_TRANFSINFO_ACCESS','Replication',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('REPL_TRANHASHTABLE_ACCESS','Replication',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('REPL_TRANTEXTINFO_ACCESS','Replication',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('REPLICA_WRITES','Replication',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('REQUEST_FOR_DEADLOCK_SEARCH','Idle',1);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('RESERVED_MEMORY_ALLOCATION_EXT','Memory',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('RESOURCE_SEMAPHORE','Memory',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('RESOURCE_SEMAPHORE_QUERY_COMPILE','Compilation',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('SLEEP_BPOOL_FLUSH','Idle',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('SLEEP_BUFFERPOOL_HELPLW','Idle',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('SLEEP_DBSTARTUP','Idle',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('SLEEP_DCOMSTARTUP','Idle',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('SLEEP_MASTERDBREADY','Idle',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('SLEEP_MASTERMDREADY','Idle',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('SLEEP_MASTERUPGRADED','Idle',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('SLEEP_MEMORYPOOL_ALLOCATEPAGES','Idle',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('SLEEP_MSDBSTARTUP','Idle',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('SLEEP_RETRY_VIRTUALALLOC','Idle',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('SLEEP_SYSTEMTASK','Idle',1);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('SLEEP_TASK','Idle',1);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('SLEEP_TEMPDBSTARTUP','Idle',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('SLEEP_WORKSPACE_ALLOCATEPAGE','Idle',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('SOS_SCHEDULER_YIELD','CPU',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('SOS_WORK_DISPATCHER','Idle',1);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('SP_SERVER_DIAGNOSTICS_SLEEP','Other',1);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('SQLCLR_APPDOMAIN','SQL CLR',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('SQLCLR_ASSEMBLY','SQL CLR',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('SQLCLR_DEADLOCK_DETECTION','SQL CLR',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('SQLCLR_QUANTUM_PUNISHMENT','SQL CLR',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('SQLTRACE_BUFFER_FLUSH','Idle',1);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('SQLTRACE_FILE_BUFFER','Tracing',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('SQLTRACE_FILE_READ_IO_COMPLETION','Tracing',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('SQLTRACE_FILE_WRITE_IO_COMPLETION','Tracing',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('SQLTRACE_INCREMENTAL_FLUSH_SLEEP','Idle',1);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('SQLTRACE_PENDING_BUFFER_WRITERS','Tracing',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('SQLTRACE_SHUTDOWN','Tracing',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('SQLTRACE_WAIT_ENTRIES','Idle',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('THREADPOOL','Worker Thread',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('TRACE_EVTNOTIF','Tracing',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('TRACEWRITE','Tracing',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('TRAN_MARKLATCH_DT','Transaction',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('TRAN_MARKLATCH_EX','Transaction',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('TRAN_MARKLATCH_KP','Transaction',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('TRAN_MARKLATCH_NL','Transaction',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('TRAN_MARKLATCH_SH','Transaction',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('TRAN_MARKLATCH_UP','Transaction',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('TRANSACTION_MUTEX','Transaction',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('UCS_SESSION_REGISTRATION','Other',1);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('WAIT_FOR_RESULTS','User Wait',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('WAIT_XTP_OFFLINE_CKPT_NEW_LOG','Other',1);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('WAITFOR','User Wait',1);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('WRITE_COMPLETION','Other Disk IO',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('WRITELOG','Tran Log IO',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('XACT_OWN_TRANSACTION','Transaction',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('XACT_RECLAIM_SESSION','Transaction',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('XACTLOCKINFO','Transaction',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('XACTWORKSPACE_MUTEX','Transaction',0);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('XE_DISPATCHER_WAIT','Idle',1);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('XE_LIVE_TARGET_TVF','Other',1);
	INSERT INTO [dbo].[BlitzFirst_WaitStats_Categories](WaitType, WaitCategory, Ignorable) VALUES ('XE_TIMER_EVENT','Idle',1);
END
GO


-- DROP VIEW [dbo].[vw_wait_stats_deltas];
CREATE VIEW [dbo].[vw_wait_stats_deltas] 
WITH SCHEMABINDING 
AS
WITH RowDates as ( 
	SELECT ROW_NUMBER() OVER (ORDER BY [collection_time_utc]) ID, [collection_time_utc]
	FROM [dbo].[wait_stats] 
	--WHERE [collection_time_utc] between @start_time and @end_time
	GROUP BY [collection_time_utc]
)
, collection_time_utcs as
(	SELECT ThisDate.collection_time_utc, LastDate.collection_time_utc as Previouscollection_time_utc
    FROM RowDates ThisDate
    JOIN RowDates LastDate
    ON ThisDate.ID = LastDate.ID + 1
)
--select * from collection_time_utcs
SELECT w.collection_time_utc, w.wait_type, COALESCE(wc.WaitCategory, 'Other') AS WaitCategory, COALESCE(wc.Ignorable,0) AS Ignorable
, DATEDIFF(ss, wPrior.collection_time_utc, w.collection_time_utc) AS ElapsedSeconds
, (w.wait_time_ms - wPrior.wait_time_ms) AS wait_time_ms_delta
, (w.wait_time_ms - wPrior.wait_time_ms) / 60000.0 AS wait_time_minutes_delta
, (w.wait_time_ms - wPrior.wait_time_ms) / 1000.0 / DATEDIFF(ss, wPrior.collection_time_utc, w.collection_time_utc) AS wait_time_minutes_per_minute
, (w.signal_wait_time_ms - wPrior.signal_wait_time_ms) AS signal_wait_time_ms_delta
, (w.waiting_tasks_count - wPrior.waiting_tasks_count) AS waiting_tasks_count_delta
FROM [dbo].[wait_stats] w
--INNER HASH JOIN collection_time_utcs Dates
INNER JOIN collection_time_utcs Dates
ON Dates.collection_time_utc = w.collection_time_utc
INNER JOIN [dbo].[wait_stats] wPrior ON w.wait_type = wPrior.wait_type AND Dates.Previouscollection_time_utc = wPrior.collection_time_utc
LEFT OUTER JOIN [dbo].[BlitzFirst_WaitStats_Categories] wc ON w.wait_type = wc.WaitType
WHERE [w].[wait_time_ms] >= [wPrior].[wait_time_ms]
--ORDER BY w.collection_time_utc, wait_time_ms_delta desc
GO

CREATE SCHEMA [bkp]
GO
CREATE SCHEMA [poc]
GO
CREATE SCHEMA [stg]
GO
CREATE SCHEMA [tst]
GO

-- Set DBA database trustworthy
declare @dbname nvarchar(255)
set @dbname=quotename(db_name())
exec('alter database '+@dbname+' set trustworthy on');
go


-- drop procedure usp_extended_results
create procedure usp_extended_results @processor_name nvarchar(500) = null output, @host_distribution nvarchar(500) = null output
with execute as owner
as
begin
	set nocount on;
	
	-- Processor Name
	exec xp_instance_regread 'HKEY_LOCAL_MACHINE', 'HARDWARE\DESCRIPTION\System\CentralProcessor\0', 'ProcessorNameString', @value = @processor_name output;

	-- Windows Version
	EXEC xp_instance_regread 'HKEY_LOCAL_MACHINE', 'SOFTWARE\Microsoft\Windows NT\CurrentVersion', 'ProductName', @value = @host_distribution OUTPUT;
	
end
go


/* Validate Partition Data */
SELECT SCHEMA_NAME(o.schema_id)+'.'+ o.name as TableName,
	pf.name as PartitionFunction,
	ds.name AS PartitionScheme, 
	p.partition_number AS PartitionNumber, 
	CASE pf.boundary_value_on_right WHEN 1 THEN 'RIGHT' ELSE 'LEFT' END AS PartitionFunctionRange, 
	prv_left.value AS LowerBoundaryValue, 
	prv_right.value AS UpperBoundaryValue, 
	fg.name AS FileGroupName,
	p.[row_count] as TotalRows,
	CONVERT(DECIMAL(12,2), p.reserved_page_count*8/1024.0) as ReservedSpaceMB,
	CONVERT(DECIMAL(12,2), p.used_page_count*8/1024.0) as UsedSpaceMB
FROM sys.dm_db_partition_stats AS p (NOLOCK)
	INNER JOIN sys.indexes AS i (NOLOCK) ON i.[object_id] = p.[object_id] AND i.index_id = p.index_id
	INNER JOIN sys.data_spaces AS ds (NOLOCK) ON ds.data_space_id = i.data_space_id
	INNER JOIN sys.objects AS o (NOLOCK) ON o.object_id = p.object_id
	INNER JOIN sys.partition_schemes AS ps (NOLOCK) ON ps.data_space_id = ds.data_space_id
	INNER JOIN sys.partition_functions AS pf (NOLOCK) ON pf.function_id = ps.function_id
	INNER JOIN sys.destination_data_spaces AS dds2 (NOLOCK) ON dds2.partition_scheme_id = ps.data_space_id AND dds2.destination_id = p.partition_number
	INNER JOIN sys.filegroups AS fg (NOLOCK) ON fg.data_space_id = dds2.data_space_id
	LEFT OUTER JOIN sys.partition_range_values AS prv_left (NOLOCK) ON ps.function_id = prv_left.function_id AND prv_left.boundary_id = p.partition_number - 1
	LEFT OUTER JOIN sys.partition_range_values AS prv_right (NOLOCK) ON ps.function_id = prv_right.function_id AND prv_right.boundary_id = p.partition_number
WHERE
	OBJECTPROPERTY(p.[object_id], 'IsMSShipped') = 0
ORDER BY p.partition_number;	
go

/* Add boundaries to partition. 1 boundary per hour */
set nocount on;
declare @partition_boundary datetime2;
declare @target_boundary_value datetime2; /* 3 months back date */
set @target_boundary_value = DATEADD(mm,DATEDIFF(mm,0,GETDATE())-3,0);
set @target_boundary_value = '2022-03-25 19:00:00.000'

declare cur_boundaries cursor local fast_forward for
		select convert(datetime2,prv.value) as boundary_value
		from sys.partition_range_values prv
		join sys.partition_functions pf on pf.function_id = prv.function_id
		where pf.name = 'pf_dba' and convert(datetime2,prv.value) < @target_boundary_value
		order by prv.value asc;

open cur_boundaries;
fetch next from cur_boundaries into @partition_boundary;
while @@FETCH_STATUS = 0
begin
	--print @partition_boundary
	alter partition function pf_dba() merge range (@partition_boundary);

	fetch next from cur_boundaries into @partition_boundary;
end
CLOSE cur_boundaries
DEALLOCATE cur_boundaries;
go


/* Remove boundaries with retention of 3 months */
set nocount on;
declare @current_boundary_value datetime2;
declare @target_boundary_value datetime2; /* last day of new quarter */
set @target_boundary_value = DATEADD (dd, -1, DATEADD(qq, DATEDIFF(qq, 0, GETDATE()) +2, 0));

select top 1 @current_boundary_value = convert(datetime2,prv.value)
from sys.partition_range_values prv
join sys.partition_functions pf on pf.function_id = prv.function_id
where pf.name = 'pf_dba'
order by prv.value desc;

select [@current_boundary_value] = @current_boundary_value, [@target_boundary_value] = @target_boundary_value;

while (@current_boundary_value < @target_boundary_value)
begin
	set @current_boundary_value = DATEADD(hour,1,@current_boundary_value);
	--print @current_boundary_value
	alter partition scheme ps_dba next used [primary];
	alter partition function pf_dba() split range (@current_boundary_value);	
end
go

select * from [dbo].[os_task_list]
go
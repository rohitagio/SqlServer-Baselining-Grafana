use [master]
go
create login [grafana] with password=N'grafana', default_database=[DBA], check_expiration=off, check_policy=off
go

create user [grafana] for login [grafana]
go
grant view any definition to [grafana]
go
grant view server state to [grafana]
go

use [DBA]
go
create user [grafana] for login [grafana]
go
alter role [db_datareader] add member [grafana]
go
grant view database state to [grafana]
go
grant execute on object::usp_extended_results to [grafana]
go


# woodknotlabeler.azurewebsites.net

source("secret.R")

conn_info <- list(
  Driver="{ODBC Driver 13 for SQL Server}",
  Server="tcp:jichangserver.database.windows.net,1433",
  Database="woodknots",
  Uid=secret$Uid,
  Pwd=secret$Pwd,
  Encrypt="yes",
  TrustServerCertificate="no",
  `Connection Timeout`="30;"
)

conn_str <- paste(paste(names(conn_info), conn_info, sep="="), collapse=";")


library(RODBC)
dbhandle <- odbcDriverConnect(conn_str)
sql <- function(q) sqlQuery(dbhandle, q) # same syntax as sqldf

sql("SELECT * FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_TYPE='BASE TABLE'")

sql("SELECT top 5 * FROM UserKnotLabel")


user_knot_labels <- sql("SELECT substring(userid, 1, 7) as user_id, knotname, label_value + '_knot' as knot_class 
                          FROM UserKnotLabel ukl JOIN Label ON ukl.labelid = Label.label_id
                            WHERE ukl.labeltime > DATEADD(HH,-1, GETDATE())
                            ORDER BY user_id, ukl.labeltime")

# CONVERT(datetime, '2017-11-21 00:00:00', 120)

write.csv(user_knot_labels, sprintf("user_knot_labels_%s.csv", format(Sys.Date(), format="%Y%m%d")), row.names=FALSE, quote=FALSE)

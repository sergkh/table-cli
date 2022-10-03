# Table CLI tool
The **table-cli** is a simple tool to transform table data in CSV or SQL/CQL output format.

If you have a SQL output like that

```
+----+------------+-----------+-----------+
| id | first_name | last_name | available |
+----+------------+-----------+-----------+
|  1 | John       | Smith     |         1 |
|  2 | Mary       | McAdams   |         0 |
|  3 | Steve      | Pitt      |         1 |
...
```

you can easilly get a list of available only users:

```bash 
$ table-cli in.sql --print '${first_name} ${last_name}' --filter available=1
John Smith
Steve Pitt
...
```
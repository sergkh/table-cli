# Table CLI tool

![main workflow](https://github.com/sergkh/table-cli/actions/workflows/build-test.yaml/badge.svg)

The **table** is a simple tool to transform table data in CSV or SQL/CQL output format.

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
$ table in.sql --filter available=1
╭────┬────────────┬───────────┬───────────╮
│ id │ first_name │ last_name │ available │
├────┼────────────┼───────────┼───────────┤
│ 1  │ John       │ Smith     │ 1         │
│ 3  │ Steve      │ Pitt      │ 1         │
│ 4  │ Mark       │ Cousins   │ 1         │
...
```

Also in CSV form:

```bash
$ table in.sql --filter available=1 --as csv
```

Or in a custom text format:

```bash 
$ table in.sql --print '${first_name} ${last_name}' --filter available=1
John Smith
Steve Pitt
...
```

# Features 

* Parsing table data from CSV (with simple automatic delimeter detection), SQL or Cassandra outputs
* Filtering columns based on certain criteria. Filter attempts to correctly interpret numbers (but not floating point numbers yet), instead of using only string to string comparison. Multiple filters can be applied
* Overriding table header to a custom one
* Moving/removing columns
* Dynamically adding new columns from a shell script output based on row data
* Custom formatting for table rows
* Automatically naming columns: col1, col2, col3 etc. if header is not specified.
* Joining of multiple table inputs
* Showing only distinct data for a column
* Sorting by the specified columns
* Data generation
* Diffing two tables by the specified columns

# Installation

Using homebrew on OSX or Linux: 
```bash
$ brew tap sergkh/tap
$ brew install table-cli
```

# Available builds

Currently tool is built for OSX (both Intel and Apple silicon) and Linux.

# Cookbook

* Transform SQL output from the clipboard into CSV:

OSX:

```bash
pbcopy | table
```

Linux:

```bash
xsel -b | table
```

* Filter CSV rows and show first 5 matches:

```bash
table in.csv --filter 'in_stock>=10' --limit 5
```

* Show only specified CSV columns:

```bash
table in.csv --columns 'name,last_name'
```

* Append a new column that has result of multiplication of two other columns. To substitute column value in the command `${column name}` format should be used. New column gets name 'newColumn1':

```bash
table in.csv --add sum='#{echo "${cost} + ${amount}" | bc}'
```

* Joining two CSV files by a common column. Joins on the column named 'id' in the first file that should match 'product_id' in the second file:

```bash
table file1.csv --join file2.csv --on 'id=product_id'
```

* Sort columns first descending by the 'available' column and then ascending by the 'id' column:

```bash
table ./test-data/table-format.out --sort "!available,id"
```

* Convert SELECT output into INSERT statements:
```bash
table select.txt --print 'INSERT INTO table (%{header}) VALUES (%{values(true)});'
```

* Diff two tables by the 'id' column:

```bash
table file1.csv --diff file2.csv --on 'id=id'
```
Produces:

```
╭────┬────────────┬───────────┬───────────╮
│ id │ first_name │ last_name │ _source   │
├────┼────────────┼───────────┼───────────┤
│ 2  │ Mary       │ McAdams   │ left      │
╰────┴────────────┴───────────┴───────────╯
```

* Generate table with test data

```bash
table --generate 10 --add id='%{uuid()}' --add status='%{randomChoice(on,off)}' --add amount='%{random(1,10)}'
```
Produces:

```
╭──────────────────────────────────────┬────────┬────────╮
│ id                                   │ status │ amount │
├──────────────────────────────────────┼────────┼────────┤
│ BFF8907B-1559-476C-9DA6-5D95384E650C │ on     │ 9      │
│ B5E9868F-C5A6-4B79-A7F9-9D7BBEB06B33 │ on     │ 1      │
│ 68D9A14F-9428-485F-8C0B-558D0743F761 │ off    │ 4      │
╰──────────────────────────────────────┴────────┴────────╯
```

* Generate insert statements with test data

```bash
table --print 'INSERT INTO orders (id, amound, status) VALUES (\'%{uuid()}\', %{random(1, 1000)}, \'%{randomChoice(ok,pending,failed)}\');' --generate 3
```

Outputs:

```
INSERT INTO orders (id, amound, status) VALUES ('BCDABED0-A4EB-4C90-9423-4AA0269A39D7', 266, 'pending');
INSERT INTO orders (id, amound, status) VALUES ('64FC986A-93A1-4579-B7F5-896CD7757AE8', 462, 'failed');
INSERT INTO orders (id, amound, status) VALUES ('74CB99C8-D23F-4081-901B-8634187E4269', 529, 'ok');
```

* For working with JSONL files (one JSON object per line) it can be combined with the `jq` tool (no nesting yet):

```bash
cat objects.jsonl | jq --slurp -r '(map(keys) | add | unique) as $cols | map(. as $row | $cols | map($row[.])) as $rows | $cols, $rows[] | @csv' | table
```

## Building from source

```bash
swift build -c release
```

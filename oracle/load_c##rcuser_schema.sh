#!/bin/sh

ORACLE_SID=ORCLCDB
export ORACLE_SID

sqlplus c##rcuser/rcpwd@ORCLPDB1 <<- EOF
  create table C##RCUSER.EMP(
  empno         number(10,0),
  fname         varchar2(30),
  lname         varchar2(30),
  job           varchar2(40),
  mgr           number(4,0),
  hiredate      date,
  sal           number(10,4),
  comm          number(10,4),
  dept          number(4,0),
  constraint pk_emp primary key (empno)
  );

  ALTER TABLE C##RCUSER.EMP ADD SUPPLEMENTAL LOG DATA (ALL) COLUMNS;
  SELECT table_name, owner, LOGICAL_REPLICATION FROM all_tables WHERE owner='C##RCUSER' AND table_name='EMP';
  select count(*) from C##RCUSER.EMP;

  create table C##RCUSER.JSON_TRANS(
  id    number(8)       not null primary key,
  json_data     clob
  );

  ALTER TABLE C##RCUSER.JSON_TRANS ADD SUPPLEMENTAL LOG DATA (ALL) COLUMNS;
  SELECT table_name, owner, LOGICAL_REPLICATION FROM all_tables WHERE owner='C##RCUSER' AND table_name='JSON_TRANS';
  select count(*) from C##RCUSER.JSON_TRANS;

  exit;
EOF

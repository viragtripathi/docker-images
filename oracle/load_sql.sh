#!/usr/bin/env bash

help()
{
   # Display help
   echo "Load SQL scripts to Oracle PDB."
   echo "Usage: [-h|insert|update|delete]"
   echo "options:"
   echo "-h: Print this help message and exit."
   echo "insert: Inserts rows in the database table."
   echo "update: Update rows in the database table."
   echo "delete: Delete rows from database table."
   echo -------------------------------
   echo
}

echo -------------------------------

while [ $# -eq 0 ] || [ $# -gt 0 ]
do
options="$1"
case ${options} in
-h)
help
exit;;
insert1k_emp)
  sqlldr c##rcuser/rcpwd@orclpdb1 control=/tmp/emp.ctl
break;;
*)
help
exit;;

esac
done

echo "done"
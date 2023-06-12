. "${HOME}"/sqllib/db2profile

cd "${HOME}"/sqllib/bin || return

db2 -stvmf /var/tmp/create_emp_table.sql | tee /var/tmp/create_emp_table.out
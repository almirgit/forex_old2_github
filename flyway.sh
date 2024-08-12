flyway -url=jdbc:postgresql://db1.kodera.hr:5432/forex -schemas=fx -user=forex_user -password=$(cat ~/.pgpass |grep '53072.*forex' | cut -d: -f 5) -locations=filesystem:./db-migrations $1
#flyway -url=jdbc:postgresql://localhost:53072/forex -schemas=fx -user=forex_user -password=$(cat ~/.pgpass |grep '53072.*forex' | cut -d: -f 5) -locations=filesystem:./db-migrations $1

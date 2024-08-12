drop table healthcheck_info;

create table healthcheck_code(
  id serial primary key,
  name text not null unique,
  description text
);

insert into healthcheck_code(name, description)
  values ('PROXY_SERVERS_AVAILABLE_NR', 'Number of proxy server available at last check');

create table healthcheck_info(
  healthcheck_code int references healthcheck_code(id) primary key,
  status text not null
);

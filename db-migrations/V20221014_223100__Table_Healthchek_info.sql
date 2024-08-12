create table healthcheck_info(
  id serial primary key,
  healthcheck_name text not null unique,
  status text not null
);

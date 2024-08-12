--
-- Name: update_availability_check(bigint, timestamp without time zone); Type: FUNCTION; Schema: fx; Owner: forex_user
--

CREATE or replace FUNCTION fx.update_availability_check(p_id bigint,
  p_last_check timestamp without time zone DEFAULT NULL::timestamp without time zone) -- this argument currently indicates that check was successful
  RETURNS text
    LANGUAGE plpgsql
    AS $$
declare
  l_function_name text := 'fx.update_availability_check';
  l_ddl text;
  l_time_proxy_consider_live int;
  l_max_availability_check_count int;
  l_cnt int;
  l_now timestamp;
begin

  l_now := now();
  l_time_proxy_consider_live     := fx.get_config_parameter('time_proxy_consider_live', '7200')::int;
  l_max_availability_check_count := fx.get_config_parameter('max_availability_check_count', '5')::int;

  update fx.proxy_list set
    last_availability_check = l_now,
    last_availability_check_status = case when extract (epoch from (l_now - last_success_check_date)::interval) <= l_time_proxy_consider_live then true else false end,
    last_success_check_date =        case when p_last_check is not null then l_now else last_success_check_date end,
    last_failure_check_date =        case when p_last_check is     null then l_now else last_failure_check_date end,
    availability_check_count = availability_check_count + 1,
    processed_by = null
  where id = p_id;

  -- select count(*)
  -- into l_cnt
  -- from fx.config co
  -- where co.loader_id = 0 and co.name = 'max_availability_check_count';
  --
  -- if l_cnt = 0 then
  --   l_max_availability_check_count := 5;
  --   perform fx.log_message(l_function_name, 'No parameter set: l_max_availability_check_count', 'WARNING');
  -- else
  --   select co.value::int
  --   into l_max_availability_check_count
  --   from fx.config co
  --   where co.loader_id = 0 and co.name = 'max_availability_check_count';
  -- end if;

  --perform fx.log_message(l_function_name, 'Debug: l_max_availability_check_count: ' || l_max_availability_check_count::text);

  create table if not exists fx.proxy_list_archive as
    select * from fx.proxy_list
    where 1 = 2;

  insert into proxy_list_archive
    select * from proxy_list
    where
    (
          last_availability_check is not null
      and last_success_check_date is not null
      and extract (epoch from (l_now - last_success_check_date)::interval) > l_time_proxy_consider_live
      and extract (epoch from (l_now - last_availability_check)::interval) > l_time_proxy_consider_live
    )
    --or
    and
    availability_check_count > l_max_availability_check_count;

  delete from proxy_list
    where
    (
          last_availability_check is not null
      and last_success_check_date is not null
      and extract (epoch from (l_now - last_success_check_date)::interval) > l_time_proxy_consider_live
      and extract (epoch from (l_now - last_availability_check)::interval) > l_time_proxy_consider_live
    )
    --or
    and
    availability_check_count > l_max_availability_check_count;

  return p_id::text;

end;
$$;

--
-- Name: check_proxy_list_action(); Type: FUNCTION; Schema: fx; Owner: forex_user
--


CREATE or replace FUNCTION fx.check_proxy_list_action() RETURNS text
    LANGUAGE plpgsql
    AS $$
declare
  l_function_name text := 'fx.check_proxy_list_action';
  l_now timestamp;
  l_value text;
  l_row_cnt int;
  l_cnt int;
  l_interval_text text;
  l_debug_entdate timestamp;
  l_error_msg text;
  l_msg text;
begin
  -- Function is being called from modules/call_scrapy - check_proxy_list_action
  --
  select count(*) into l_cnt
  from fx.proxy_list
  where last_availability_check is not null;

  perform fx.healthcheck_update('PROXY_SERVERS_AVAILABLE_NR', l_cnt::text);
  -- update fx.config
  --   set value = l_cnt::text
  -- where name = 'proxy_servers_available_nr'
  -- and (value is null or value != l_cnt::text);


  l_now := now();

  select value
  into l_value
  from fx.config
  where name = 'proxy_list_interval'
  and loader_id = (select id from config_loader where name = 'default');

  l_interval_text := (l_value || ' minutes');

  GET DIAGNOSTICS l_row_cnt = ROW_COUNT;
  if l_row_cnt = 0 then
    perform fx.log_message(l_function_name, 'No config: proxy_list_interval', 'ERROR');
    return 'No config: proxy_list_interval';
  end if;

  select count(*) into l_row_cnt
  from fx.proxy_list
  where entdate > l_now - l_interval_text::interval;

  select entdate into l_debug_entdate
  from fx.proxy_list
  order by id desc
  limit 1;

  -- If we have loaded at least 1 new proxy, wait until x minutes has passed (in this context we call it 'interval')
  if l_row_cnt > 0 then
    l_msg := 'Nothing to do -> '
    || 'Number of latest records in interval: ' || l_row_cnt::text
    || '; interval: ' || l_interval_text
    || '; l_now: ' || l_now::text
    || '; l_debug_entdate (latest entdate): ' || l_debug_entdate::text
    ;
    perform fx.log_message(l_function_name, l_msg);
    return l_msg;
  end if;

  -- Not sure if this is needed:
  -- GET DIAGNOSTICS l_row_cnt = ROW_COUNT;
  -- if l_row_cnt > 1 then
  --   l_error_msg := 'More than 1 rows updated';
  --   perform fx.log_message(l_function_name, l_error_msg, 'FATAL');
  --   return l_error_msg;
  -- end if;

  -- vacuum proxy_list; -- VACUUM cannot run inside a transaction block

  -- x minutes has passed, go load some new proxies:
  l_msg := 'Load new proxies!';
  perform fx.log_message(l_function_name, l_msg);
  return l_msg;

end;
$$;

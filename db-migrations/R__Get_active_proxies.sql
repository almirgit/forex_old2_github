CREATE or replace FUNCTION fx.get_active_proxies(p_node_name text)
  RETURNS TABLE(proxy_ip text, proxy_port text, id text)
    LANGUAGE plpgsql
    AS $$
declare
  l_function_name text := 'fx.get_active_proxies';
  l_mark_records_nr int := 10;
  rec record;
  l_context text;
  l_pid int;
begin

  select pg_backend_pid() into l_pid;

  if p_node_name is null or trim(p_node_name) = '' then
    perform fx.log_message(l_function_name,
          'p_node_name not defined',
          'ERROR');
    return;
  end if;

  for rec in (
    select pl.id, pl.proxy_ip
    from fx.proxy_list pl
    where processed_by is null
    order by
      availability_check_count asc nulls first,
      to_char(pl.last_availability_check, 'YYYYMMDDHH24') desc nulls first,
      to_char(pl.entdate, 'YYYYMMDDHH24') asc
    --limit l_mark_records_nr
    limit 10
    for update
  )
  loop
    update fx.proxy_list pl2
      set processed_by = p_node_name
    where pl2.id = rec.id;
    perform fx.log_message(l_function_name, 'p_node_name: ' || p_node_name::text
      || '; l_pid: ' || l_pid::text
      || '; Checking proxy: ' || rec.proxy_ip
    );
  end loop;

  return query
    select pl.proxy_ip::text, pl.proxy_port::text, pl.id::text
    from fx.proxy_list pl
    where pl.processed_by = p_node_name;

EXCEPTION WHEN OTHERS THEN
  GET STACKED DIAGNOSTICS l_context = PG_EXCEPTION_CONTEXT;
  perform fx.log_message(l_function_name,
    SQLERRM::text || '; ' ||
    'context: ' || l_context,
    'ERROR');

end;
$$;

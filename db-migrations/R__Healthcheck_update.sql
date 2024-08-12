CREATE or replace FUNCTION fx.healthcheck_update(p_healthcheck_name text,
  p_status text default 'OK'::text) RETURNS void
    LANGUAGE plpgsql
    AS $$
declare
  l_rc int;
  l_function_name text := 'fx.healthcheck_update';
begin

  update fx.healthcheck_info
    set status = p_status
  where
    healthcheck_code = (select id from fx.healthcheck_code where name = p_healthcheck_name)
    or status is null
    or (status is not null and status != p_status);

  get diagnostics l_rc := row_count;
  if l_rc = 0 then
    insert into fx.healthcheck_info(healthcheck_code, status)
      values((select id from healthcheck_code where name = p_healthcheck_name), p_status);
  end if;

EXCEPTION WHEN OTHERS THEN
  perform fx.log_message(l_function_name,
          SQLERRM::text || ', ' ||
          SQLSTATE::text,
          'ERROR');  -- not autonomous transaction
end;
$$;

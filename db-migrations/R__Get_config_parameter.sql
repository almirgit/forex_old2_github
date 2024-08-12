CREATE or replace FUNCTION fx.get_config_parameter(
  p_config_name text,
  p_config_default_value text
)
  RETURNS text
    LANGUAGE plpgsql
AS
$$
declare
  l_function_name text := 'fx.get_config_parameter';
  l_context text;
  l_cnt int;
  l_ret_val text;
begin

  select count(*)
  into l_cnt
  from fx.config co
  where co.loader_id = 0
  and co.name = p_config_name;

  if l_cnt = 0 then
    perform fx.log_message(l_function_name, 'No parameter set: "' || p_config_name || '". Returning default: ' || p_config_default_value, 'WARNING');
    return p_config_default_value;
  else
    select co.value
    into l_ret_val
    from fx.config co
    where co.loader_id = 0
    and co.name = p_config_name;

    return l_ret_val;
  end if;

exception when others then
  GET STACKED DIAGNOSTICS l_context = PG_EXCEPTION_CONTEXT;
  perform fx.log_message(l_function_name,
    SQLERRM::text || '; ' ||
    'context: ' || l_context,
    'ERROR');

  return l_context;

end;
$$;

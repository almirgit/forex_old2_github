--
-- PostgreSQL database dump
--

-- Dumped from database version 12.11
-- Dumped by pg_dump version 13.8 (Debian 13.8-1.pgdg100+1)

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: data; Type: SCHEMA; Schema: -; Owner: forex_user
--

CREATE SCHEMA data;


ALTER SCHEMA data OWNER TO forex_user;

--
-- Name: fx; Type: SCHEMA; Schema: -; Owner: forex_user
--

CREATE SCHEMA fx;


ALTER SCHEMA fx OWNER TO forex_user;

--
-- Name: SCHEMA fx; Type: COMMENT; Schema: -; Owner: forex_user
--

COMMENT ON SCHEMA fx IS 'Forex software';


--
-- Name: add_proxy(text, integer, text, text); Type: FUNCTION; Schema: fx; Owner: forex_user
--

CREATE FUNCTION fx.add_proxy(p_proxy_ip text, p_proxy_port integer, p_proxy_type text, p_loading_source text) RETURNS text
    LANGUAGE plpgsql
    AS $$
declare
  l_function_name text := 'add_proxy';
begin
  insert into fx.proxy_list(proxy_ip, proxy_port, proxy_type, loading_source)
    values(p_proxy_ip::inet, p_proxy_port, p_proxy_type, p_loading_source);
  return '';
exception
  when unique_violation then
    perform fx.log_message(l_function_name, 'Debug: ' || sqlerrm::text);
    return '';
  when others then
    perform fx.log_message(l_function_name, sqlerrm::text, 'ERROR');
    return '';
end;
$$;


ALTER FUNCTION fx.add_proxy(p_proxy_ip text, p_proxy_port integer, p_proxy_type text, p_loading_source text) OWNER TO forex_user;

--
-- Name: add_proxy(text, integer, text, text, text); Type: FUNCTION; Schema: fx; Owner: forex_user
--

CREATE FUNCTION fx.add_proxy(p_proxy_ip text, p_proxy_port integer, p_proxy_type text, p_loading_source text, p_country text DEFAULT NULL::text) RETURNS text
    LANGUAGE plpgsql
    AS $$
declare
  l_function_name text := 'add_proxy';
begin
  insert into fx.proxy_list(proxy_ip, proxy_port, proxy_type, loading_source, country)
    values(p_proxy_ip::inet, p_proxy_port, p_proxy_type, p_loading_source, p_country);
  return '';
exception
  when unique_violation then
    --perform fx.log_message(l_function_name, 'Debug: ' || sqlerrm::text);
    return '';
  when others then
    perform fx.log_message(l_function_name, sqlerrm::text, 'ERROR');
    return '';
end;
$$;


ALTER FUNCTION fx.add_proxy(p_proxy_ip text, p_proxy_port integer, p_proxy_type text, p_loading_source text, p_country text) OWNER TO forex_user;

--
-- Name: calculate_atr(text, text, timestamp without time zone); Type: FUNCTION; Schema: fx; Owner: forex_user
--

CREATE FUNCTION fx.calculate_atr(p_instrument text, p_resolution text, p_cs_opening_time timestamp without time zone) RETURNS numeric
    LANGUAGE plpgsql
    AS $_$
declare
  --https://en.wikipedia.org/wiki/Average_true_range
  l_function_name text := 'calculate_atr';
  l_dml text;
  l_cnt int;
  l_atr numeric;
begin

  l_dml := format('
    select
    count(*)
    from %s
    where cs_opening_time < $1 and resolution = $2
    limit 14
  ', get_chart_table_name(p_instrument));

  execute l_dml
    using p_cs_opening_time, p_resolution
    into l_cnt;

  if l_cnt < 14 then
    return null;
  end if;

  l_dml := format('
    select avg(tr) from (
      select
      tr
      from %s
      where cs_opening_time < $1 and resolution = $2
      order by cs_opening_time desc
      limit 14
    ) x
  ', get_chart_table_name(p_instrument));

  execute l_dml
    using p_cs_opening_time, p_resolution
    into l_atr;

  return l_atr;

end;
$_$;


ALTER FUNCTION fx.calculate_atr(p_instrument text, p_resolution text, p_cs_opening_time timestamp without time zone) OWNER TO forex_user;

--
-- Name: calculate_tr(text, numeric, numeric, text, timestamp without time zone); Type: FUNCTION; Schema: fx; Owner: forex_user
--

CREATE FUNCTION fx.calculate_tr(p_instrument text, p_high numeric, p_low numeric, p_resolution text, p_cs_opening_time timestamp without time zone) RETURNS numeric
    LANGUAGE plpgsql
    AS $_$
declare
  --https://en.wikipedia.org/wiki/Average_true_range
  l_function_name text := 'calculate_tr';
  l_dml text;
  l_tr numeric;
  l_prev_cs_close numeric;
begin

  -- l_dml := format('
  --   select close from (
  --     select
  --       row_number() OVER (PARTITION BY resolution ORDER BY cs_opening_time DESC) rn,
  --       t.*
  --     from %s t
  --     where cs_opening_time <= $1 and resolution = $2
  --     limit 2
  --   ) x
  --   where x.rn = 2', fx.get_chart_table_name(p_instrument));  -- TODO: ne valja, jer možda još nema loadanog rekorda - mora se tražiti cs_opening_time - 15m, ako nema onda 0

  l_dml := format('
    select close
    from %s
    where cs_opening_time = to_timestamp(EXTRACT(EPOCH FROM $1) - $2) and resolution = $3
  ', get_chart_table_name(p_instrument));

  execute l_dml
    using p_cs_opening_time, fx.get_seconds_from_resolution(p_resolution), p_resolution
    into l_prev_cs_close;

  if l_prev_cs_close is not null then
    l_tr := GREATEST((p_high-p_low), abs(p_high-l_prev_cs_close), abs(p_low-l_prev_cs_close));
  else
    l_tr := GREATEST(p_high-p_low);
  end if;

  perform fx.log_message(l_function_name,
       'p_instrument: ' || coalesce(p_instrument, 'unknown')
    || ': p_resolution: ' || coalesce(p_resolution, 'unknown')
    || '; p_cs_opening_time: ' || coalesce(p_cs_opening_time::text, 'unknown')
    || ': l_tr: ' || coalesce(l_tr::text, 'unknown')
    || ': l_prev_cs_close: ' || coalesce(l_prev_cs_close::text, 'unknown')
  );

  return l_tr;

end;
$_$;


ALTER FUNCTION fx.calculate_tr(p_instrument text, p_high numeric, p_low numeric, p_resolution text, p_cs_opening_time timestamp without time zone) OWNER TO forex_user;

--
-- Name: check_is_market_open(); Type: FUNCTION; Schema: fx; Owner: forex_user
--

CREATE FUNCTION fx.check_is_market_open() RETURNS text
    LANGUAGE plpgsql
    AS $_$
declare
  l_function_name text := 'check_is_market_open';
  l_ddl text;
  l_dml text;
  l_table_name text;
  l_table_name_schema text;
  l_cnt int;
  rec record;
begin

  -- for rec in (select id, name from instrument)
  -- loop
  --   l_table_name := 'forex_chart_data_' || rec.name;
  --   l_table_name_schema := 'fx.' || l_table_name;
  --   l_dml := 'select count(*) from pg_tables
  --     where schemaname = ''public''
  --     and tablename = $1;';
  --   execute l_dml into l_cnt using l_table_name;
  --
  --   if l_cnt = 0 then
  --     perform fx.log_message(l_function_name, 'No table found: ' || l_table_name);
  --     continue;
  --   end if;
  --
  --   l_dml := 'select count(*) from ' || l_table_name_schema || ' where for_date > now() - ''10 minutes''::interval ';
  --   execute l_dml into l_cnt;
  --
  --   if l_cnt = 0 then
  --     -- Market is closed
  --     update instrument set
  --         market_is_open = false,
  --         last_market_check = now()
  --       where id = rec.id;
  --       perform fx.log_message(l_function_name, 'Market is closed - ' || rec.name);
  --   else
  --     update instrument set
  --         market_is_open = true,
  --         last_market_check = now()
  --       where id = rec.id;
  --       perform fx.log_message(l_function_name, 'Market is open - ' || rec.name);
  --   end if;
  --
  -- end loop;

  return '';

exception when others then
  perform fx.log_message(l_function_name, SQLERRM::text, 'ERROR');
  return SQLERRM::text;
end;
$_$;


ALTER FUNCTION fx.check_is_market_open() OWNER TO forex_user;

--
-- Name: check_proxy_list_action(); Type: FUNCTION; Schema: fx; Owner: forex_user
--

CREATE FUNCTION fx.check_proxy_list_action() RETURNS text
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
begin
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

  if l_row_cnt > 0 then
    return 'Nothing to do -> '
    || 'Number of latest records in interval: ' || l_row_cnt::text
    || '; interval: ' || l_interval_text
    || '; l_now: ' || l_now::text
    || '; l_debug_entdate: ' || l_debug_entdate::text
    ;
  end if;

  select count(*) into l_cnt
  from fx.proxy_list
  where last_availability_check is not null;

  update fx.config
    set value = l_cnt::text
  where name = 'proxy_servers_available_nr'
  and (value is null or value != l_cnt::text);

  GET DIAGNOSTICS l_row_cnt = ROW_COUNT;
  if l_row_cnt > 1 then
    l_error_msg := 'More than 1 rows updated';
    perform fx.log_message(l_function_name, l_error_msg, 'FATAL');
    return l_error_msg;
  end if;

  create table if not exists fx.proxy_list_archive as
    select * from fx.proxy_list
    where 1 = 2;

  -- vacuum proxy_list; -- VACUUM cannot run inside a transaction block

  return 'Load new proxies!';

end;
$$;


ALTER FUNCTION fx.check_proxy_list_action() OWNER TO forex_user;

--
-- Name: create_chart_data_table(text, text); Type: FUNCTION; Schema: fx; Owner: forex_user
--

CREATE FUNCTION fx.create_chart_data_table(p_instrument text, p_resolution text) RETURNS text
    LANGUAGE plpgsql
    AS $$
declare
  l_ddl text;
  l_table_name text;
  l_table_name_schema text;
begin

  select get_chart_table_name(p_instrument) into l_table_name;
  --l_table_name := 'forex_chart_data_' || p_instrument; -- || '_' || p_resolution;
  --l_table_name_schema := 'fx.' || l_table_name;

  l_ddl := 'create table if not exists data.' || l_table_name || '(
    resolution      text not null,
    cs_opening_time timestamp not null,
    open            numeric not null,
    high            numeric not null,
    low             numeric not null,
    close           numeric not null,
    entdate         timestamp default now(),
    source_id       int,
    instrument_id   int,
    cs_color        char(1) not null,
    cs_type         text,
    tr              numeric,
    atr             numeric,
    sma             numeric,
    UNIQUE(cs_opening_time, resolution)
  )';

  EXECUTE l_ddl;

  --l_ddl := 'create index if not exists ' || l_table_name || '_for_date__idx1 on ' || l_table_name_schema || '(for_date);';
  --EXECUTE l_ddl;

  return l_table_name;

end;
$$;


ALTER FUNCTION fx.create_chart_data_table(p_instrument text, p_resolution text) OWNER TO forex_user;

--
-- Name: get_candlestick_type(numeric, numeric, numeric, numeric, text, text, timestamp without time zone); Type: FUNCTION; Schema: fx; Owner: forex_user
--

CREATE FUNCTION fx.get_candlestick_type(p_open numeric, p_high numeric, p_low numeric, p_close numeric, p_instrument text, p_resolution text, p_cs_opening_time timestamp without time zone) RETURNS text
    LANGUAGE plpgsql
    AS $_$
declare
  l_function_name text := 'get_candlestick_type';
  l_green_red text;
  l_dml text;
  l_prev_cs_open numeric;
  l_prev_cs_high numeric;
  l_prev_cs_low numeric;
  l_prev_cs_close numeric;
  l_prev_green_red text;
  l_ret_val text := '';
begin

  select
    CASE WHEN p_close >= p_open THEN 'G'
    ELSE 'R'
  END
  into l_green_red;

  if l_green_red = 'G' then
    if p_open >= p_low+(abs(p_high-p_low)*(1-0.382)) then
      l_ret_val := l_ret_val || ',' || 'LONG_WICK_GREEN_38.2%'; -- "Hammer" - simple reversal pattern (to the upside)
    --elsif p_open >= p_low+(abs(p_high-p_low)*(1-0.5)) then
    --  return 'LONG_WICK_GREEN_50%';
    elsif p_close <= p_low+(abs(p_high-p_low)*(0.382)) then
      l_ret_val := l_ret_val || ',' || 'LONG_WICK_GREEN_INVERTED_38.2%'; -- "Inverted Hammer" - simple reversal pattern (to the upside)
    --elsif p_open <= p_low+(abs(p_high-p_low)*(0.5)) then
    --  return 'LONG_WICK_GREEN_INVERTED_50%';
    end if;

  else
    -- RED:
    if p_open <= p_low+(abs(p_high-p_low)*(0.382)) then
      l_ret_val := l_ret_val || ',' || 'LONG_WICK_RED_38.2%'; -- "Shooting Star"
    --elsif p_open <= p_low+(abs(p_high-p_low)*(0.5)) then
    --  return 'LONG_WICK_RED_50%';
    elsif p_close >= p_low+(abs(p_high-p_low)*(1-0.382)) then
      l_ret_val := l_ret_val || ',' || 'LONG_WICK_RED_INVERTED_38.2%'; -- "Hanging Man"
    end if;

  end if;

  -- l_dml := format('
  --   select open, high, low, close from (
  --     select
  --       row_number() OVER (PARTITION BY resolution ORDER BY cs_opening_time DESC) rn,
  --       t.*
  --     from %s t
  --     where cs_opening_time = to_timestamp(EXTRACT(EPOCH FROM $1) - $2) and resolution = $3
  --     limit 2
  --   ) x
  --   where x.rn = 2', get_chart_table_name(p_instrument));

  l_dml := format('
    select open, high, low, close
    from %s
    where cs_opening_time = to_timestamp(EXTRACT(EPOCH FROM $1) - $2) and resolution = $3
  ', get_chart_table_name(p_instrument));

  execute l_dml
    using p_cs_opening_time, fx.get_seconds_from_resolution(p_resolution), p_resolution
    into l_prev_cs_open, l_prev_cs_high, l_prev_cs_low, l_prev_cs_close;

  if l_prev_cs_close is not null then

    select
      CASE WHEN l_prev_cs_close >= l_prev_cs_open THEN 'G'
      ELSE 'R'
    END
    into l_prev_green_red;

    if l_green_red = 'G' then
      if l_prev_green_red = 'R' and (p_close >= l_prev_cs_high and p_open <= l_prev_cs_low) then
        l_ret_val := l_ret_val || ',' || 'BULLISH_ENGULFING';
      end if;
    else
      --l_green_red = 'R'
      if l_prev_green_red = 'G' and (p_open >= l_prev_cs_high and p_close <= l_prev_cs_low) then
        l_ret_val := l_ret_val || ',' || 'BEARISH_ENGULFING';
      end if;
    end if;

  end if;

  return l_ret_val;



end;
$_$;


ALTER FUNCTION fx.get_candlestick_type(p_open numeric, p_high numeric, p_low numeric, p_close numeric, p_instrument text, p_resolution text, p_cs_opening_time timestamp without time zone) OWNER TO forex_user;

--
-- Name: get_chart_table_name(text); Type: FUNCTION; Schema: fx; Owner: forex_user
--

CREATE FUNCTION fx.get_chart_table_name(p_instrument text) RETURNS text
    LANGUAGE plpgsql
    AS $$
declare
begin
  return 'forex_chart_data_' || p_instrument;
end;
$$;


ALTER FUNCTION fx.get_chart_table_name(p_instrument text) OWNER TO forex_user;

--
-- Name: get_latest_instrument_price(text, numeric); Type: FUNCTION; Schema: fx; Owner: forex_user
--

CREATE FUNCTION fx.get_latest_instrument_price(p_instrument text, p_rec_id numeric) RETURNS numeric
    LANGUAGE plpgsql
    AS $_$
declare
  l_function_name text := 'get_latest_instrument_price';
  l_sql text;
  l_price numeric;
begin
  -- l_sql := format('select price from %s where id = $1', 'data.' || fx.get_realtime_table_name(p_instrument));
  --
  -- execute l_sql
  --   using p_rec_id
  --   into l_price;
  --
  -- return l_price;
  return 0;
end;
$_$;


ALTER FUNCTION fx.get_latest_instrument_price(p_instrument text, p_rec_id numeric) OWNER TO forex_user;

--
-- Name: get_realtime_table_name(text); Type: FUNCTION; Schema: fx; Owner: forex_user
--

CREATE FUNCTION fx.get_realtime_table_name(p_instrument text) RETURNS text
    LANGUAGE plpgsql
    AS $$
declare
begin
  return 'forex_realtime_data_' || p_instrument;
end;
$$;


ALTER FUNCTION fx.get_realtime_table_name(p_instrument text) OWNER TO forex_user;

--
-- Name: get_seconds_from_resolution(text); Type: FUNCTION; Schema: fx; Owner: forex_user
--

CREATE FUNCTION fx.get_seconds_from_resolution(p_resolution text) RETURNS integer
    LANGUAGE plpgsql
    AS $$
declare
  l_function_name text := 'get_seconds_from_resolution';
  l_resolution_sec int := 0;
begin

  if p_resolution = '5m' then     l_resolution_sec := 300;
  elsif p_resolution = '15m' then l_resolution_sec := 900;
  elsif p_resolution = '30m' then l_resolution_sec := 1800;
  elsif p_resolution = '1h' then  l_resolution_sec := 3600;
  elsif p_resolution = '4h' then  l_resolution_sec := 14400;
  elsif p_resolution = '1d' then  l_resolution_sec := 86400;
  elsif p_resolution = '1w' then  l_resolution_sec := 604800;
  else
    perform fx.log_message(l_function_name, 'Cannot calculate resolution in seconds', 'ERROR');
  end if;

  return l_resolution_sec;

end;
$$;


ALTER FUNCTION fx.get_seconds_from_resolution(p_resolution text) OWNER TO forex_user;

--
-- Name: is_market_open(text); Type: FUNCTION; Schema: fx; Owner: forex_user
--

CREATE FUNCTION fx.is_market_open(p_instrument text) RETURNS text
    LANGUAGE plpgsql
    AS $$
declare
  l_function_name text := 'is_market_open';
  l_market_is_open boolean := false;
begin

    select market_is_open
    into l_market_is_open
    from instrument
    where name = p_instrument;

    if l_market_is_open then
      return 'Yes';
    else
      perform fx.log_message(l_function_name, 'Market is closed; Instrument: ' || p_instrument);
      return 'No';
    end if;

exception when others then
  perform fx.log_message(l_function_name, SQLERRM::text, 'ERROR');
  return SQLERRM::text;
end;
$$;


ALTER FUNCTION fx.is_market_open(p_instrument text) OWNER TO forex_user;

--
-- Name: json_array_test(); Type: FUNCTION; Schema: fx; Owner: forex_user
--

CREATE FUNCTION fx.json_array_test() RETURNS text
    LANGUAGE plpgsql
    AS $$
declare
  l_function_name text := 'json_array_test';

  v_sqlstate text;
  v_message text;
  v_context text;
  rec record;
  l_quantity numeric;
  l_ret_val_array text[];
  l_ret_val text := '';
  l_ret_val_json json;

  l_json1 json;
  l_json2 json;
  l_json_array json;
begin

  -- select id
  -- into l_instrument_id
  -- from instrument
  -- where name = p_instrument;
  --
  -- GET DIAGNOSTICS l_rc := ROW_COUNT;
  --
  -- for rec in (select rs_value, deviation from fx.rs_level
  --   where instrument_id = l_instrument_id and resolution = p_resolution
  -- )
  -- loop
  --   -- perform fx.log_message(l_function_name, 'debug: rec.rs_value: '
  --   --   || coalesce(rec.rs_value::text, 'unknown')
  --   --   || ': l_instrument_id: ' || coalesce(l_instrument_id::text, 'unknown')
  --   --   || ': p_resolution: ' || coalesce(p_resolution, 'unknown')
  --   -- );
  --   if rec.rs_value >= p_low and rec.rs_value <= p_high then
  --     l_ret_val := l_ret_val || ';Entered ' || p_instrument || ' resistance level ' || rec.rs_value::text;
  --     select quantity
  --     into l_quantity
  --     from position
  --     where instrument = p_instrument;
  --     l_ret_val := l_ret_val || ';Position parameters: ' || l_quantity::text;
  --     perform array_append(l_ret_val_array, l_ret_val);
  --   end if;
  -- end loop;


  l_json1 := json_build_object(
    'foo1', '1',
    'foo2', '2'
  );
  l_json2 := json_build_object(
    'foo3', '3',
    'foo4', '4'
  );

  l_json_array := json_build_array(l_json1, l_json2);


  perform fx.log_message(l_function_name,
    --coalesce(l_operation, 'unknown')
    ''
    -- || ': p_resolution: ' || coalesce(p_resolution, 'unknown')
    -- || '; p_instrument: ' || coalesce(p_instrument, 'unknown')
    -- || '; p_timestamp_text: ' || coalesce(p_timestamp_text, 'unknown')
    -- || '; l_ret_val: ' || coalesce(l_ret_val, 'unknown')
    || '; l_json_array: ' || coalesce(l_json_array::text, 'unknown')
    || '!'
  );

  l_ret_val := l_json_array::text;
  return l_json_array;


exception when others then
  GET STACKED DIAGNOSTICS
       v_sqlstate = returned_sqlstate,
       v_message = message_text,
       v_context = pg_exception_context;
  perform fx.log_message(l_function_name, SQLERRM::text || '; ' || v_message || '; ' || v_context, 'ERROR');
  return SQLERRM::text;
end;
$$;


ALTER FUNCTION fx.json_array_test() OWNER TO forex_user;

--
-- Name: load_chart_data(text, text, text, numeric, numeric, numeric, numeric, text); Type: FUNCTION; Schema: fx; Owner: forex_user
--

CREATE FUNCTION fx.load_chart_data(p_instrument text, p_resolution text, p_timestamp_text text, p_open numeric, p_high numeric, p_low numeric, p_close numeric, p_source text) RETURNS text
    LANGUAGE plpgsql
    AS $_$
declare
  l_function_name text := 'load_chart_data';
  l_dml_insert text;
  l_dml_update text;
  l_dml_select text;
  l_operation text;
  l_instrument_id int;
  l_table_name text;
  l_cs_opening_time timestamp;
  l_new_data boolean;
  l_cs_color text; -- cs - candlestick color (red or green - R/G)
  l_cnt int;
  l_rc int;
  l_tr numeric;
  l_atr numeric;

  -- https://www.investopedia.com/terms/m/movingaverage.asp
  l_sma numeric; -- Simple Moving Average
  -- ​SMA = (A1​+A2​+…+An)/n
  -- ​​where
  -- A = Average in period n
  -- n =Number of time periods​
  --
  v_sqlstate text;
  v_message text;
  v_context text;
  rec record;
  l_quantity numeric;
  l_ret_val_array text[];
  l_ret_val text := '';
  l_ret_val_json json;
begin

  select id
  into l_instrument_id
  from instrument
  where name = p_instrument;

  GET DIAGNOSTICS l_rc := ROW_COUNT;

  if l_rc = 0 then
    insert into instrument(name)
      values(p_instrument)
    returning id into l_instrument_id;
  end if;

  select fx.create_chart_data_table(p_instrument, p_resolution) into l_table_name;


  -- select count(*)
  -- into l_cnt
  -- from rs_level
  --   where instrument_id = l_instrument_id and resolution = p_resolution;
  -- perform fx.log_message(l_function_name,
  --   'debug: l_cnt: ' || coalesce(l_cnt::text, 'unknown')
  --   || ': l_instrument_id: ' || coalesce(l_instrument_id::text, 'unknown')
  --   || ': p_resolution: ' || coalesce(p_resolution, 'unknown')
  -- );


  if p_resolution = '5m' then
    l_sma := (p_high-p_low)/2;
  end if;

  select
    CASE WHEN p_close >= p_open THEN 'G'
    ELSE 'R'
  END
  into l_cs_color;

  l_dml_insert := 'insert into data.' || l_table_name ||'(
    resolution, cs_opening_time,
    open, high, low, close,
    source_id,
    instrument_id,
    cs_color, cs_type, tr, sma,
    atr
  )
  values (
    $1, $2,
    $3, $4, $5, $6,
    (select id from fx.config_loader where name = $7),
    (select id from fx.instrument where name = $8),
    $9, $10, $11, $12,
    $13
  )';

  l_dml_update := 'update data.' || l_table_name ||' set
    open = $3,
    high = $4,
    low = $5,
    close = $6,
    source_id = (select id from fx.config_loader where name = $7),
    instrument_id = (select id from fx.instrument where name = $8),
    cs_color = $9,
    cs_type = $10,
    tr = $11,
    sma = $12,
    atr = $13
  where resolution = $1 and cs_opening_time = $2';

  l_cs_opening_time := to_timestamp(substring(p_timestamp_text from 1 for 10)::int);
  if p_resolution = '1d' then
    l_cs_opening_time := ((to_timestamp(substring(p_timestamp_text from 1 for 10)::int))::date)::timestamp;
  end if;

  l_tr := fx.calculate_tr(p_instrument, p_high, p_low, p_resolution, l_cs_opening_time);
  l_atr := fx.calculate_atr(p_instrument, p_resolution, l_cs_opening_time);

  l_new_data := true;

  l_dml_select := 'select count(*) from data.' || l_table_name || ' where (resolution = $1 and cs_opening_time = $2) limit 1';
  execute l_dml_select into l_cnt using p_resolution, l_cs_opening_time;

  if l_cnt = 0 then
    l_operation := 'Insert';
    EXECUTE l_dml_insert
    --into l_this_cs_id
      USING
        p_resolution, l_cs_opening_time,
        p_open, p_high, p_low, p_close,
        p_source,
        p_instrument,
        l_cs_color,
        get_candlestick_type(p_open, p_high, p_low, p_close, p_instrument, p_resolution, l_cs_opening_time),
        l_tr, l_sma, l_atr;
  else
    --l_operation := 'NoNewInsert'; -- to reduce sequence generation
    l_dml_select := 'select count(*) from data.'|| l_table_name
      || ' where (resolution = $1 and cs_opening_time = $2) '
      || ' and open  != $3 '
      || ' and high  != $4 '
      || ' and low   != $5 '
      || ' and close != $6 '
      || ' limit 1 '
    ; -- TODO: take this values in query above
    execute l_dml_select
    into l_cnt
    using
      p_resolution, l_cs_opening_time,
      p_open, p_high, p_low, p_close;

    if l_cnt > 0 then
      l_operation := 'Update';
      EXECUTE l_dml_update
        USING
          p_resolution, l_cs_opening_time,
          p_open, p_high, p_low, p_close,
          p_source,
          p_instrument,
          l_cs_color,
          get_candlestick_type(p_open, p_high, p_low, p_close, p_instrument, p_resolution, l_cs_opening_time),
          l_tr, l_sma, l_atr;
    else
      l_new_data := false;
      l_operation := 'NoUpdateNeeded';
    end if;
  end if;

  -- Check signals and alarms:
  -- TODO: commit tables: rs_level & position


  for rec in (select rs_value, deviation from fx.rs_level
    where instrument_id = l_instrument_id and resolution = p_resolution
  )
  loop
    -- perform fx.log_message(l_function_name, 'debug: rec.rs_value: '
    --   || coalesce(rec.rs_value::text, 'unknown')
    --   || ': l_instrument_id: ' || coalesce(l_instrument_id::text, 'unknown')
    --   || ': p_resolution: ' || coalesce(p_resolution, 'unknown')
    -- );
    if rec.rs_value >= p_low and rec.rs_value <= p_high then
      l_ret_val := l_ret_val || ';Entered ' || p_instrument || ' resistance level ' || rec.rs_value::text;
      select quantity
      into l_quantity
      from position
      where instrument = p_instrument;
      l_ret_val := l_ret_val || ';Position parameters: ' || l_quantity::text;
      perform array_append(l_ret_val_array, l_ret_val);
    end if;
  end loop;

  perform fx.log_message(l_function_name, coalesce(l_operation, 'unknown')
    || ': p_resolution: ' || coalesce(p_resolution, 'unknown')
    || '; p_instrument: ' || coalesce(p_instrument, 'unknown')
    || '; p_timestamp_text: ' || coalesce(p_timestamp_text, 'unknown')
    || '; l_ret_val: ' || coalesce(l_ret_val, 'unknown')
    --|| '; l_ret_val_array: ' || coalesce(l_ret_val_array::text, 'unknown')
    || '!'
  );

  -- l_ret_val_json := json_build_object(
  --   'foo1', '1',
  --   'foo2', '2'
  -- );

  --l_ret_val := l_ret_val_json::text;
  return l_ret_val;


exception when others then
  GET STACKED DIAGNOSTICS
       v_sqlstate = returned_sqlstate,
       v_message = message_text,
       v_context = pg_exception_context;
  perform fx.log_message(l_function_name, SQLERRM::text || '; ' || v_message || '; ' || v_context, 'ERROR');
  return SQLERRM::text;
end;
$_$;


ALTER FUNCTION fx.load_chart_data(p_instrument text, p_resolution text, p_timestamp_text text, p_open numeric, p_high numeric, p_low numeric, p_close numeric, p_source text) OWNER TO forex_user;

--
-- Name: load_forex_data__create_alarm_v3(text, text, text, numeric, bigint, integer, numeric, integer, numeric); Type: FUNCTION; Schema: fx; Owner: forex_user
--

CREATE FUNCTION fx.load_forex_data__create_alarm_v3(p_source text, p_instrument text, p_alarm_type text, p_price numeric, p_rec_id bigint, p_alarm_id integer, p_diff numeric DEFAULT NULL::numeric, p_sec_elapsed integer DEFAULT NULL::integer, p_comparing_price numeric DEFAULT NULL::numeric) RETURNS text
    LANGUAGE plpgsql
    AS $$
declare
  l_function_name text := 'load_forex_data__create_alarm_v3';
  l_alarm_active_since timestamp;
  l_alarm_creation_pause int; -- seconds
  l_next_alarm_not_before timestamp;
  l_alarm_max_repeat int;
  l_alarm_repeat_counter int;
  l_now timestamp;
  l_ret_val text;
begin

  -- if p_alarm_type = 'Threshold' then
  --   select alarm_active_since, alarm_creation_pause, alarm_max_repeat, alarm_repeat_counter
  --   into l_alarm_active_since, l_alarm_creation_pause, l_alarm_max_repeat, l_alarm_repeat_counter
  --   from fx.alarm_threshold_def
  --   where id = p_alarm_id;
  --
  --   if l_alarm_active_since is not null then
  --     l_next_alarm_not_before := l_alarm_active_since + (l_alarm_creation_pause::text || ' seconds')::interval;
  --     -- perform fx.log_message(l_function_name,
  --     --     'l_next_alarm_not_before: ' || l_next_alarm_not_before::text
  --     --   || '; now: ' || now()::text);
  --
  --     if l_next_alarm_not_before > now() then
  --        perform fx.log_message(l_function_name, 'Skiping alarm creation due to alarm delay/pause');
  --        return null;
  --     end if;
  --   end if;
  -- end if;

  l_now := now();

  perform fx.log_message(l_function_name, 'Creating alarm at ' || l_now::time);

  insert into fx.alarm(source_id, instrument, alarm_type, price,
    record_id, alarm_id)
  values (
    (select id from config_loader where name = p_source),
    p_instrument,
    p_alarm_type,
    p_price,
    p_rec_id,
    p_alarm_id
  );

  update fx.alarm_threshold_def
    set alarm_active_since = l_now
    where id = p_alarm_id;

  -- if p_alarm_type = 'Threshold' then
  --   if l_alarm_repeat_counter >= l_alarm_max_repeat-1 then
  --     update fx.alarm_threshold_def
  --       set alarm_active_since = null, -- TODO (not urgent): solve with separate check for every alarm definition at the beginning of loader funcion
  --         alarm_repeat_counter = 0
  --       where id = p_alarm_id;
  --   else
  --     update fx.alarm_threshold_def
  --       set alarm_active_since = now(),
  --         --alarm_repeat_counter = coalesce(alarm_repeat_counter, 1) + 1 -- coalesce not needed anymore :)
  --         alarm_repeat_counter = alarm_repeat_counter + 1
  --       where id = p_alarm_id;
  --   end if;
  -- end if;

  l_ret_val := format('Alarm type: %s; Instrument: %s; Price: %s; Time: %s;',
  p_alarm_type::text, p_instrument::text, p_price::text, now()::text);
  --return 'Test';
  --perform fx.log_message(l_function_name, 'l_ret_val: ' || l_ret_val);
  return l_ret_val;

end;
$$;


ALTER FUNCTION fx.load_forex_data__create_alarm_v3(p_source text, p_instrument text, p_alarm_type text, p_price numeric, p_rec_id bigint, p_alarm_id integer, p_diff numeric, p_sec_elapsed integer, p_comparing_price numeric) OWNER TO forex_user;

--
-- Name: load_forex_data__create_alarm_v3(text, text, text, numeric, bigint, integer, text, numeric, integer, numeric); Type: FUNCTION; Schema: fx; Owner: forex_user
--

CREATE FUNCTION fx.load_forex_data__create_alarm_v3(p_source text, p_instrument text, p_alarm_type text, p_price numeric, p_rec_id bigint, p_alarm_id integer, p_alarm_description text, p_diff numeric DEFAULT NULL::numeric, p_sec_elapsed integer DEFAULT NULL::integer, p_comparing_price numeric DEFAULT NULL::numeric) RETURNS text
    LANGUAGE plpgsql
    AS $$
declare
  l_function_name text := 'load_forex_data__create_alarm_v3';
  l_alarm_active_since timestamp;
  l_alarm_creation_pause int; -- seconds
  l_next_alarm_not_before timestamp;
  l_alarm_max_repeat int;
  l_alarm_repeat_counter int;
  l_now timestamp;
  l_ret_val text;
begin

  -- if p_alarm_type = 'Threshold' then
  --   select alarm_active_since, alarm_creation_pause, alarm_max_repeat, alarm_repeat_counter
  --   into l_alarm_active_since, l_alarm_creation_pause, l_alarm_max_repeat, l_alarm_repeat_counter
  --   from fx.alarm_threshold_def
  --   where id = p_alarm_id;
  --
  --   if l_alarm_active_since is not null then
  --     l_next_alarm_not_before := l_alarm_active_since + (l_alarm_creation_pause::text || ' seconds')::interval;
  --     -- perform fx.log_message(l_function_name,
  --     --     'l_next_alarm_not_before: ' || l_next_alarm_not_before::text
  --     --   || '; now: ' || now()::text);
  --
  --     if l_next_alarm_not_before > now() then
  --        perform fx.log_message(l_function_name, 'Skiping alarm creation due to alarm delay/pause');
  --        return null;
  --     end if;
  --   end if;
  -- end if;

  l_now := now();

  perform fx.log_message(l_function_name, 'Creating alarm at ' || l_now::time);

  insert into fx.alarm(source_id, instrument, alarm_type, price,
    record_id, alarm_id)
  values (
    (select id from config_loader where name = p_source),
    p_instrument,
    p_alarm_type,
    p_price,
    p_rec_id,
    p_alarm_id
  );

  update fx.alarm_threshold_def
    set alarm_active_since = l_now
    where id = p_alarm_id;

  -- if p_alarm_type = 'Threshold' then
  --   if l_alarm_repeat_counter >= l_alarm_max_repeat-1 then
  --     update fx.alarm_threshold_def
  --       set alarm_active_since = null, -- TODO (not urgent): solve with separate check for every alarm definition at the beginning of loader funcion
  --         alarm_repeat_counter = 0
  --       where id = p_alarm_id;
  --   else
  --     update fx.alarm_threshold_def
  --       set alarm_active_since = now(),
  --         --alarm_repeat_counter = coalesce(alarm_repeat_counter, 1) + 1 -- coalesce not needed anymore :)
  --         alarm_repeat_counter = alarm_repeat_counter + 1
  --       where id = p_alarm_id;
  --   end if;
  -- end if;

  l_ret_val := format('Alarm: %s, Alarm type: %s; Instrument: %s; Price: %s; Time: %s;',
  p_alarm_description, p_alarm_type::text, p_instrument::text, p_price::text, now()::text);
  --return 'Test';
  --perform fx.log_message(l_function_name, 'l_ret_val: ' || l_ret_val);
  return l_ret_val;

end;
$$;


ALTER FUNCTION fx.load_forex_data__create_alarm_v3(p_source text, p_instrument text, p_alarm_type text, p_price numeric, p_rec_id bigint, p_alarm_id integer, p_alarm_description text, p_diff numeric, p_sec_elapsed integer, p_comparing_price numeric) OWNER TO forex_user;

--
-- Name: load_forex_data__insert_data_v2(text, numeric, numeric, numeric, numeric, numeric, numeric, text); Type: FUNCTION; Schema: fx; Owner: forex_user
--

CREATE FUNCTION fx.load_forex_data__insert_data_v2(p_instrument text, p_buy numeric, p_change numeric, p_high numeric, p_low numeric, p_price numeric, p_sell numeric, p_source text) RETURNS bigint
    LANGUAGE plpgsql
    AS $_$
declare
  l_id bigint;
  l_sql text;
begin

  l_sql := 'insert into fx.forex_data_' || p_instrument
  || ' (buy, change, high, low, price, sell, source)'
  || ' values ($1, $2, $3, $4, $5, $6, $7)'
  || ' returning id';

  EXECUTE l_sql
  INTO
   l_id
  USING
    p_buy, p_change, p_high, p_low,
    p_price, p_sell, p_source;

  return l_id;

end;
$_$;


ALTER FUNCTION fx.load_forex_data__insert_data_v2(p_instrument text, p_buy numeric, p_change numeric, p_high numeric, p_low numeric, p_price numeric, p_sell numeric, p_source text) OWNER TO forex_user;

--
-- Name: load_forex_data__inspect_data_v2(bigint, numeric, integer, numeric, text); Type: FUNCTION; Schema: fx; Owner: forex_user
--

CREATE FUNCTION fx.load_forex_data__inspect_data_v2(p_id bigint, p_price numeric, p_seeking_back_seconds integer, p_seeking_prc numeric, p_instrument text) RETURNS TABLE(rec_found integer, rec_entdate timestamp without time zone, sec_elapsed integer, diff numeric, comparing_price numeric)
    LANGUAGE plpgsql
    AS $_$
declare
  l_function_name text := 'load_forex_data__inspect_data_v2';
  l_price numeric;
  l_diff numeric;
  l_diff_abs numeric;
  l_back_rec_cnt int :=0;
  l_entdate timestamp;
  l_sec_elapsed int;
  l_now timestamp;
  l_last_price numeric;
  l_last_entdatae timestamp;
  l_last_sec_elapsed int := 0;
  l_rec_found int := 0;
  --l_instrument text;
  l_row_cnt int;
  l_sql text;
begin

  l_sql := 'select entdate, price, entdate from fx.forex_data_' || p_instrument
    || ' where id = $1';

  execute l_sql
    into l_now, l_last_price, l_last_entdatae
    using p_id;

  loop
      l_back_rec_cnt := l_back_rec_cnt + 1;

      l_sql := 'select price, entdate from fx.forex_data_' || p_instrument
        || ' where id = $1';

      execute l_sql
        into l_price, l_entdate
        using p_id - l_back_rec_cnt;

      GET DIAGNOSTICS l_row_cnt = ROW_COUNT;
      --perform log_message(l_function_name, 'Row count: ' || l_row_cnt::text);
      if l_row_cnt = 0 then
        exit;
      end if;

      l_sec_elapsed := round(extract(epoch from l_now - l_entdate));

      l_diff := (p_price-l_price)/l_price*100;
      l_diff_abs := abs(l_diff);

      l_last_sec_elapsed := l_sec_elapsed;
      l_last_entdatae := l_entdate;

      if l_diff_abs >= p_seeking_prc then
        l_rec_found := 1;
        exit;
      end if;

      if l_sec_elapsed >= p_seeking_back_seconds then
        exit;
      end if;

  end loop;

  return query
    select l_rec_found, l_last_entdatae, l_last_sec_elapsed, l_diff, l_price;
end;
$_$;


ALTER FUNCTION fx.load_forex_data__inspect_data_v2(p_id bigint, p_price numeric, p_seeking_back_seconds integer, p_seeking_prc numeric, p_instrument text) OWNER TO forex_user;

--
-- Name: load_forex_data__write_statistics(integer, numeric, timestamp without time zone); Type: FUNCTION; Schema: fx; Owner: forex_user
--

CREATE FUNCTION fx.load_forex_data__write_statistics(p_instrument_id integer, p_price numeric, p_now timestamp without time zone) RETURNS integer
    LANGUAGE plpgsql
    AS $$
declare
  l_function_name text := 'load_forex_data__write_statistics';
  l_high numeric;
  l_low numeric;
  l_row_cnt int;
  l_id bigint;
begin
  select id, high, low
    from statistic
    into l_id, l_high, l_low
  where instrument_id = p_instrument_id
  and date_day = p_now::date
  and minute = (extract(hour from p_now)*60 + extract(minute from p_now));

  GET DIAGNOSTICS l_row_cnt = ROW_COUNT;

  if l_row_cnt = 0 then
    insert into statistic (instrument_id, high, low)
      values(p_instrument_id, p_price, p_price);

  elsif l_row_cnt = 1 then

    if p_price > l_high then
      l_high := p_price;
    end if;
    if p_price < l_low then
      l_low := p_price;
    end if;

    update statistic set
      high = l_high,
      low = l_low,
      avg = (l_high+l_low)/2
    where id = l_id;

  else
    perform fx.log_message(l_function_name, 'Row count > 1 !! ', 'ERROR');
  end if;

  return 0;

end;
$$;


ALTER FUNCTION fx.load_forex_data__write_statistics(p_instrument_id integer, p_price numeric, p_now timestamp without time zone) OWNER TO forex_user;

--
-- Name: load_forex_data_v2(text, numeric, numeric, numeric, numeric, numeric, numeric, text); Type: FUNCTION; Schema: fx; Owner: forex_user
--

CREATE FUNCTION fx.load_forex_data_v2(p_instrument text, p_buy numeric, p_change numeric, p_high numeric, p_low numeric, p_price numeric, p_sell numeric, p_source text) RETURNS TABLE(message text, direction text, diff numeric, alarm_type text)
    LANGUAGE plpgsql
    AS $$
declare
    l_function_name text := 'load_forex_data_v2';
    l_id bigint;
    l_rec_found int := 0;
    l_entdate timestamp;
    l_sec_elapsed int;
    l_ret_val text;
    l_diff numeric;
    l_comparing_price numeric;
    l_instrument text;
    l_now timestamp;
    rec record;
begin

    l_now := now();

    drop table if exists load_forex_data_v2_output;
    create temporary table if not exists load_forex_data_v2_output (
       message text,
       direction text,
       diff numeric,
       alarm_type text
    )
    on commit delete rows;

    truncate table load_forex_data_v2_output; -- TODO check records

    --return 'Test';
    if p_source is null then
        perform fx.log_message(
          l_function_name, 'No source value. Invalid record.', 'ERROR'
        );
    else
      update fx.config_loader
        set last_contact = l_now
        where name = p_source;
    end if;

    select fx.load_forex_data__insert_data_v2(
      p_instrument, p_buy, p_change, p_high, p_low,
      p_price, p_sell, p_source
    ) into l_id;


    for rec in (select id, seeking_back_seconds, seeking_prc, instrument, active_since, ad.alarm_type
      from fx.alarm_def ad
      where valid
        and instrument = p_instrument
      order by seeking_back_seconds, seeking_prc desc
    ) loop
        if rec.alarm_type = 'Change' then
          select rec_found, rec_entdate, sec_elapsed, f1.diff, comparing_price
          into l_rec_found, l_entdate, l_sec_elapsed, l_diff, l_comparing_price
          from fx.load_forex_data__inspect_data_v2(
            l_id, p_price, rec.seeking_back_seconds, rec.seeking_prc, p_instrument) f1;

          if l_rec_found = 1 then
            --perform fx.log_message(l_function_name, 'l_entdate: ' || l_entdate::text);
            if (rec.active_since is null) or (rec.active_since is not null and l_entdate > rec.active_since) then
              select fx.load_forex_data__create_alarm_v2(
                p_source, p_instrument, l_diff, l_sec_elapsed,
                l_id, p_price, l_comparing_price, rec.id, l_entdate
              )
              into l_ret_val;
              insert into load_forex_data_v2_output (message, direction, diff, alarm_type)
                values (l_ret_val, case when l_diff > 0 then 'UP' else 'DOWN' end, l_diff, 'Diff');
            end if;
          end if;
        end if;
    end loop;

    -- Clear inactive alarms
    for rec in (select id, description--, threshold_lower_bound, threshold_upper_bound
      from fx.alarm_threshold_def
      where valid
      and instrument = p_instrument
      and alarm_active_since is not null
      and (
        not (p_price between threshold_lower_bound and threshold_upper_bound)
        or
        (alarm_active_since + (alarm_creation_pause::text || ' seconds')::interval) < l_now
      )
    )
    loop
      update fx.alarm_threshold_def
        set alarm_active_since = null
        where id = rec.id;

        perform fx.log_message(l_function_name, 'Clear alarm at ' || l_now::text);
    end loop;


    -- Check for new alarms:
    for rec in (select id, description, threshold_lower_bound, threshold_upper_bound
      from fx.alarm_threshold_def
      where valid
      and instrument = p_instrument
      and p_price between threshold_lower_bound and threshold_upper_bound
      and alarm_active_since is null
    )
    loop
      perform fx.log_message(l_function_name,
        format('Loaded: price: %s; threshold_lower_bound: %s, threshold_upper_bound: %s',
          p_price::text, rec.threshold_lower_bound::text, rec.threshold_upper_bound::text)
      );

      select fx.load_forex_data__create_alarm_v3(
        p_source, p_instrument, 'Threshold', p_price, l_id, rec.id, rec.description
      )
      into l_ret_val;

      if l_ret_val is not null then
        insert into load_forex_data_v2_output (message, direction, diff, alarm_type)
          values (l_ret_val, null, null, 'Threshold');
      end if;
    end loop;

    --return 'Test';
    -- l_ret_val := format('Loaded: price: %s; ID: %s, time: %s',
    --  p_price::text, l_id::text, now()::text);
    -- return l_ret_val;
    return query
      select lo.message, lo.direction, lo.diff, lo.alarm_type from load_forex_data_v2_output lo;


-- EXCEPTION WHEN OTHERS THEN
--   perform fx.log_message(l_function_name,
--           SQLERRM::text || ', ' ||
--           SQLSTATE::text,
--           'ERROR');  -- not autonomous transaction
--   raise exception '%: %', l_function_name, sqlerrm::text;
--   --RETURN null;

end;
$$;


ALTER FUNCTION fx.load_forex_data_v2(p_instrument text, p_buy numeric, p_change numeric, p_high numeric, p_low numeric, p_price numeric, p_sell numeric, p_source text) OWNER TO forex_user;

--
-- Name: load_forex_data_v4(text, numeric, numeric, numeric, numeric, numeric, numeric, text); Type: FUNCTION; Schema: fx; Owner: forex_user
--

CREATE FUNCTION fx.load_forex_data_v4(p_instrument text, p_buy numeric, p_change numeric, p_high numeric, p_low numeric, p_price numeric, p_sell numeric, p_source text) RETURNS TABLE(alarm_type text, message text)
    LANGUAGE plpgsql
    AS $$
declare
    l_function_name text := 'load_forex_data_v4';
    l_id bigint;
    l_rec_found int := 0;
    l_entdate timestamp;
    l_sec_elapsed int;
    l_ret_val text;
    l_diff numeric;
    l_comparing_price numeric;
    l_instrument text;
    l_instrument_id int;
    l_now timestamp;
    rec record;
begin

    l_now := now();

    drop table if exists load_forex_data_v4_output;
    create temporary table if not exists load_forex_data_v4_output (
       alarm_type text,
       message text
    )
    on commit delete rows;

    truncate table load_forex_data_v4_output; -- TODO check records

    --return 'Test';
    if p_source is null then
        perform fx.log_message(
          l_function_name, 'No source value. Invalid record.', 'ERROR'
        );
    else
      update fx.config_loader
        set last_contact = l_now
        where name = p_source;
    end if;

    select fx.load_forex_data__insert_data_v2(
      p_instrument, p_buy, p_change, p_high, p_low,
      p_price, p_sell, p_source
    ) into l_id;

    select id from instrument
    into l_instrument_id
    where name = p_instrument;

    perform fx.load_forex_data__write_statistics(
      l_instrument_id, p_price, l_now
    );


    -- -- Clear inactive alarms
    -- for rec in (select id, description--, threshold_lower_bound, threshold_upper_bound
    --   from fx.alarm_threshold_def
    --   where valid
    --   and instrument = p_instrument
    --   and alarm_active_since is not null
    --   and (
    --     not (p_price between threshold_lower_bound and threshold_upper_bound)
    --     or
    --     (alarm_active_since + (alarm_creation_pause::text || ' seconds')::interval) < l_now
    --   )
    -- )
    -- loop
    --   update fx.alarm_threshold_def
    --     set alarm_active_since = null
    --     where id = rec.id;
    --
    --     perform fx.log_message(l_function_name, 'Clear alarm at ' || l_now::text);
    -- end loop;
    --
    --
    -- -- Check for new alarms:
    -- for rec in (select id, description, threshold_lower_bound, threshold_upper_bound
    --   from fx.alarm_threshold_def
    --   where valid
    --   and instrument = p_instrument
    --   and p_price between threshold_lower_bound and threshold_upper_bound
    --   and alarm_active_since is null
    -- )
    -- loop
    --   perform fx.log_message(l_function_name,
    --     format('Loaded: price: %s; threshold_lower_bound: %s, threshold_upper_bound: %s',
    --       p_price::text, rec.threshold_lower_bound::text, rec.threshold_upper_bound::text)
    --   );
    --
    --   select fx.load_forex_data__create_alarm_v3(
    --     p_source, p_instrument, 'Threshold', p_price, l_id, rec.id, rec.description
    --   )
    --   into l_ret_val;
    --
    --   if l_ret_val is not null then
    --     insert into load_forex_data_v2_output (message, direction, diff, alarm_type)
    --       values (l_ret_val, null, null, 'Threshold');
    --   end if;
    -- end loop;

    --return 'Test';
    -- l_ret_val := format('Loaded: price: %s; ID: %s, time: %s',
    --  p_price::text, l_id::text, now()::text);
    -- return l_ret_val;

    return query
      select lo.alarm_type, lo.message from load_forex_data_v4_output lo;


-- EXCEPTION WHEN OTHERS THEN
--   perform fx.log_message(l_function_name,
--           SQLERRM::text || ', ' ||
--           SQLSTATE::text,
--           'ERROR');  -- not autonomous transaction
--   raise exception '%: %', l_function_name, sqlerrm::text;
--   --RETURN null;

end;
$$;


ALTER FUNCTION fx.load_forex_data_v4(p_instrument text, p_buy numeric, p_change numeric, p_high numeric, p_low numeric, p_price numeric, p_sell numeric, p_source text) OWNER TO forex_user;

--
-- Name: load_realtime_data__insert_data_v5(text, numeric, numeric, numeric, numeric, numeric, numeric, text); Type: FUNCTION; Schema: fx; Owner: forex_user
--

CREATE FUNCTION fx.load_realtime_data__insert_data_v5(p_instrument text, p_buy numeric, p_change numeric, p_high numeric, p_low numeric, p_price numeric, p_sell numeric, p_source text) RETURNS bigint
    LANGUAGE plpgsql
    AS $_$
declare
  --l_id bigint;
  l_instrument_id int;
  l_table_name text;
  l_ddl text;
  l_dml text;
  l_rc int;
begin

  -- begin
  --   insert into instrument(name)
  --     values(p_instrument);
  -- exception when unique_violation then
  --   null;
  -- end;

  select id
  into l_instrument_id
  from instrument
  where name = p_instrument;

  GET DIAGNOSTICS l_rc := ROW_COUNT;

  if l_rc = 0 then
    insert into instrument(name)
      values(p_instrument);
  end if;

  l_table_name := 'data.forex_realtime_data_' || p_instrument;

  l_ddl := 'create table if not exists ' || l_table_name || '(
        id        bigserial not null primary key,
        buy       numeric,
        change    numeric,
        high      numeric,
        low       numeric,
        price     numeric,
        sell      numeric,
        entdate   timestamp default now(),
        source_id int      not null
  )';
  EXECUTE l_ddl;

  l_ddl := 'create index if not exists forex_realtime_data_' || p_instrument || '_entdate_index
    on data.forex_realtime_data_' || p_instrument || ' (entdate)';
  EXECUTE l_ddl;

  l_dml := 'insert into ' || l_table_name
  || ' (buy, change, high, low, price, sell, source_id)'
  || ' values ($1, $2, $3, $4, $5, $6, (select id from fx.config_loader where name = $7))';

  EXECUTE l_dml
  USING
    p_buy, p_change, p_high, p_low,
    p_price, p_sell, p_source;

  return 44;

end;
$_$;


ALTER FUNCTION fx.load_realtime_data__insert_data_v5(p_instrument text, p_buy numeric, p_change numeric, p_high numeric, p_low numeric, p_price numeric, p_sell numeric, p_source text) OWNER TO forex_user;

--
-- Name: load_realtime_data__insert_data_v6(text, numeric, numeric, numeric, numeric, numeric, numeric, text); Type: FUNCTION; Schema: fx; Owner: forex_user
--

CREATE FUNCTION fx.load_realtime_data__insert_data_v6(p_instrument text, p_buy numeric, p_change numeric, p_high numeric, p_low numeric, p_price numeric, p_sell numeric, p_source text) RETURNS bigint
    LANGUAGE plpgsql
    AS $_$
declare
  l_id bigint;
  l_instrument_id int;
  l_table_name text;
  l_ddl text;
  l_dml text;
  l_rc int;
begin

  -- begin
  --   insert into instrument(name)
  --     values(p_instrument);
  -- exception when unique_violation then
  --   null;
  -- end;

  select id
  into l_instrument_id
  from instrument
  where name = p_instrument;

  GET DIAGNOSTICS l_rc := ROW_COUNT;

  if l_rc = 0 then
    insert into instrument(name)
      values(p_instrument);
  end if;

  l_table_name := 'data.forex_realtime_data_' || p_instrument;

  l_ddl := 'create table if not exists ' || l_table_name || '(
        id        bigserial not null primary key,
        buy       numeric,
        change    numeric,
        high      numeric,
        low       numeric,
        price     numeric,
        sell      numeric,
        entdate   timestamp default now(),
        source_id int      not null
  )';
  EXECUTE l_ddl;

  l_ddl := 'create index if not exists forex_realtime_data_' || p_instrument || '_entdate_index
    on data.forex_realtime_data_' || p_instrument || ' (entdate)';
  EXECUTE l_ddl;

  l_dml := 'insert into ' || l_table_name
  || ' (buy, change, high, low, price, sell, source_id)'
  || ' values ($1, $2, $3, $4, $5, $6, (select id from fx.config_loader where name = $7))'
  || ' returning id';

  EXECUTE l_dml
  into
    l_id
  USING
    p_buy, p_change, p_high, p_low,
    p_price, p_sell, p_source;

  return l_id;

end;
$_$;


ALTER FUNCTION fx.load_realtime_data__insert_data_v6(p_instrument text, p_buy numeric, p_change numeric, p_high numeric, p_low numeric, p_price numeric, p_sell numeric, p_source text) OWNER TO forex_user;

--
-- Name: load_realtime_data_v5(text, numeric, numeric, numeric, numeric, numeric, numeric, text); Type: FUNCTION; Schema: fx; Owner: forex_user
--

CREATE FUNCTION fx.load_realtime_data_v5(p_instrument text, p_buy numeric, p_change numeric, p_high numeric, p_low numeric, p_price numeric, p_sell numeric, p_source text) RETURNS TABLE(alarm_type text, message text)
    LANGUAGE plpgsql
    AS $$
declare
    l_function_name text := 'load_forex_data_v4';
    l_id bigint;
    l_rec_found int := 0;
    l_entdate timestamp;
    l_sec_elapsed int;
    l_ret_val text;
    l_diff numeric;
    l_comparing_price numeric;
    l_instrument text;
    l_instrument_id int;
    l_now timestamp;
    rec record;
begin

    l_now := now();

    drop table if exists load_realtime_data_v5_output;
    create temporary table if not exists load_realtime_data_v5_output (
       alarm_type text,
       message text
    )
    on commit delete rows;

    truncate table load_realtime_data_v5_output; -- TODO check records

    --return 'Test';
    if p_source is null then
        perform fx.log_message(
          l_function_name, 'No source value. Invalid record.', 'ERROR'
        );
    else
      update fx.config_loader
        set last_contact = l_now
        where name = p_source;
    end if;

    select fx.load_realtime_data__insert_data_v5(
      p_instrument, p_buy, p_change, p_high, p_low,
      p_price, p_sell, p_source
    ) into l_id;


    --perform fx.load_forex_data__write_statistics(
    --  l_instrument_id, p_price, l_now
    --);



    -- -- Clear inactive alarms
    -- for rec in (select id, description--, threshold_lower_bound, threshold_upper_bound
    --   from fx.alarm_threshold_def
    --   where valid
    --   and instrument = p_instrument
    --   and alarm_active_since is not null
    --   and (
    --     not (p_price between threshold_lower_bound and threshold_upper_bound)
    --     or
    --     (alarm_active_since + (alarm_creation_pause::text || ' seconds')::interval) < l_now
    --   )
    -- )
    -- loop
    --   update fx.alarm_threshold_def
    --     set alarm_active_since = null
    --     where id = rec.id;
    --
    --     perform fx.log_message(l_function_name, 'Clear alarm at ' || l_now::text);
    -- end loop;
    --
    --
    -- -- Check for new alarms:
    -- for rec in (select id, description, threshold_lower_bound, threshold_upper_bound
    --   from fx.alarm_threshold_def
    --   where valid
    --   and instrument = p_instrument
    --   and p_price between threshold_lower_bound and threshold_upper_bound
    --   and alarm_active_since is null
    -- )
    -- loop
    --   perform fx.log_message(l_function_name,
    --     format('Loaded: price: %s; threshold_lower_bound: %s, threshold_upper_bound: %s',
    --       p_price::text, rec.threshold_lower_bound::text, rec.threshold_upper_bound::text)
    --   );
    --
    --   select fx.load_forex_data__create_alarm_v3(
    --     p_source, p_instrument, 'Threshold', p_price, l_id, rec.id, rec.description
    --   )
    --   into l_ret_val;
    --
    --   if l_ret_val is not null then
    --     insert into load_forex_data_v2_output (message, direction, diff, alarm_type)
    --       values (l_ret_val, null, null, 'Threshold');
    --   end if;
    -- end loop;

    --return 'Test';
    -- l_ret_val := format('Loaded: price: %s; ID: %s, time: %s',
    --  p_price::text, l_id::text, now()::text);
    -- return l_ret_val;

    return query
      select lo.alarm_type, lo.message from load_realtime_data_v5_output lo;


-- EXCEPTION WHEN OTHERS THEN
--   perform fx.log_message(l_function_name,
--           SQLERRM::text || ', ' ||
--           SQLSTATE::text,
--           'ERROR');  -- not autonomous transaction
--   raise exception '%: %', l_function_name, sqlerrm::text;
--   --RETURN null;

end;
$$;


ALTER FUNCTION fx.load_realtime_data_v5(p_instrument text, p_buy numeric, p_change numeric, p_high numeric, p_low numeric, p_price numeric, p_sell numeric, p_source text) OWNER TO forex_user;

--
-- Name: load_realtime_data_v6(text, numeric, numeric, numeric, numeric, numeric, numeric, text); Type: FUNCTION; Schema: fx; Owner: forex_user
--

CREATE FUNCTION fx.load_realtime_data_v6(p_instrument text, p_buy numeric, p_change numeric, p_high numeric, p_low numeric, p_price numeric, p_sell numeric, p_source text) RETURNS TABLE(message text, alarm_type text, instrument text)
    LANGUAGE plpgsql
    AS $_$
declare
    l_function_name text := 'load_realtime_data_v6';
    v_sqlstate text;
    v_message text;
    v_context text;

    l_id bigint;
    l_instrument_id int;
    l_now timestamp;

    rec record;
    l_sql text;
    l_current_price numeric;
    l_seeking_price numeric;
    l_up_down text;

    l_cnt int;
begin

    drop table if exists load_realtime_data_v6_output;
    create temporary table if not exists load_realtime_data_v6_output (
       message text,
       alarm_type text,
       instrument text
    )
    on commit delete rows;

    -- Make sure temporary doesn't contain records:
    select count(*)
    into l_cnt
    from load_realtime_data_v6_output;

    if l_cnt > 0 then
      perform fx.log_message(l_function_name, 'Temporary table not ready');
      return query select null, null, null;
    end if;
    --truncate table load_realtime_data_v6_output;


    l_now := now();
    --return 'Test';

    if p_source is null then
        perform fx.log_message(
          l_function_name, 'No source value. Invalid record.', 'ERROR'
        );
    else
      update fx.config_loader
        set last_contact = l_now
        where name = p_source;
    end if;

    select fx.load_realtime_data__insert_data_v6(
      p_instrument, p_buy, p_change, p_high, p_low,
      p_price, p_sell, p_source
    ) into l_id;


    select id from instrument
    into l_instrument_id
    where name = p_instrument;


    -- Check thresholds:
    for rec in (
      select id, instrument_id, instrument_name, description, target_th_value,
        th_desired_crossing_direction, current_value_position, alert_active_since
      from fx.alert_price_treshold
      where instrument_id = l_instrument_id
      and active
    )
    loop
      perform fx.log_message(l_function_name,
        'rec.instrument_name: ' || rec.instrument_name
        || '; rec.th_value: ' || rec.target_th_value::text
        || '; p_price: ' || p_price::text
      );


      if (
        rec.alert_active_since is null
        and rec.th_desired_crossing_direction = 'UP'
        and rec.current_value_position in (null, 'BELOW')
        and p_price > rec.target_th_value
      ) then -- Activate alarm:
        update fx.alert_price_treshold set
          current_value_position = 'ABOVE',
          alert_active_since = l_now
          where id = rec.id;

          insert into load_realtime_data_v6_output (message, alarm_type, instrument)
            values (
              'Alarm created for threshold: ' || rec.target_th_value::text
              || '; p_price: ' || p_price::text,
              || '; Crossing direction: ' || rec.th_desired_crossing_direction::text,
              || '; Time: ' || l_now::text,
              'price_treshold',
              p_instrument
            );

      elsif (
        rec.alert_active_since is not null
        and rec.th_desired_crossing_direction = 'UP'
        and rec.current_value_position in ('ABOVE')
        and p_price < rec.target_th_value
      ) then -- Deactivate alarm
        update fx.alert_price_treshold set
          current_value_position = 'BELOW',
          alert_active_since = null
          where id = rec.id;

      elsif (
        rec.alert_active_since is null
        and rec.th_desired_crossing_direction = 'DOWN'
        and rec.current_value_position in (null, 'ABOVE')
        and p_price < rec.target_th_value
      ) then -- Activate alarm:
        update fx.alert_price_treshold set
          current_value_position = 'BELOW',
          alert_active_since = l_now
          where id = rec.id;

      elsif (
        rec.alert_active_since is not null
        and rec.th_desired_crossing_direction = 'DOWN'
        and rec.current_value_position in ('BELOW')
        and p_price > rec.target_th_value
      ) then -- Deactivate alarm
        update fx.alert_price_treshold set
          current_value_position = 'ABOVE',
          alert_active_since = null
          where id = rec.id;

      end if;


      -- insert into load_realtime_data_v6_output (message, alarm_type, instrument)
      --   values (
      --     'rec.target_th_value: ' || rec.target_th_value::text || '; p_price: ' || p_price::text,
      --     'price_treshold',
      --     p_instrument
      --   );

    end loop;

    -- l_json_array_element_nr := 0;
    -- -- Check alert for price moves (percentage)
    -- for rec in (
    --   select id, price_percentage, time_range_seconds
    --     from alert_price_move
    --   where active
    --   and instrument_id = l_instrument_id
    --   order by time_range_seconds
    -- )
    -- loop
    --   l_sql := format('select price from %s where id = $1', 'data.' || fx.get_realtime_table_name(p_instrument));
    --   execute l_sql
    --     using l_id
    --     into l_current_price;
    --
    --   l_sql := format('select
    --       price,
    --       case
    --         when sign(price - $6) = 1 then ''UP''
    --         else ''DOWN''
    --       end up_down
    --     from %s
    --     where 1 = 1
    --       and id < $1
    --       and entdate > $2 - ($3::text || '' seconds'')::interval
    --       and ((price - $4) * 100 / price) > $5
    --     order by id desc limit 1;'
    --   , 'data.' || fx.get_realtime_table_name(p_instrument));
    --
    --   execute l_sql using
    --     l_id,
    --     l_now,
    --     rec.time_range_seconds,
    --     l_current_price,
    --     rec.price_percentage,
    --     l_current_price
    --   into
    --     l_seeking_price,
    --     l_up_down;
    --
    --   -- l_json1 := json_build_object(
    --   --   'lastId', l_id,
    --   --   'instrument', p_instrument,
    --   --   'currentPrice', l_current_price,
    --   --   'intervalSeconds', rec.time_range_seconds,
    --   --   'seekingPrice', l_seeking_price,
    --   --   'directionUpDown', l_up_down
    --   -- );
    --   -- --l_json_array := json_build_array(l_json1, l_json2);
    --   -- --perform array_append(l_json_array, l_json1);
    --   --
    --   -- l_json_array_element_nr := l_json_array_element_nr + 1;
    --   -- l_json_array[l_json_array_element_nr] := l_json1;
    --
    -- end loop;
    --
    -- perform fx.log_message(l_function_name, 'l_json_array: ' || l_json_array::text);

    return query
      select lo.message, lo.alarm_type, lo.instrument from load_realtime_data_v6_output lo;

-- EXCEPTION WHEN OTHERS THEN
--   perform fx.log_message(l_function_name,
--           SQLERRM::text || ', ' ||
--           SQLSTATE::text,
--           'ERROR');  -- not autonomous transaction
--   raise exception '%: %', l_function_name, sqlerrm::text;
--   --RETURN null;

exception when others then
  GET STACKED DIAGNOSTICS
       v_sqlstate = returned_sqlstate,
       v_message = message_text,
       v_context = pg_exception_context;
  perform fx.log_message(l_function_name, SQLERRM::text || '; ' || v_message || '; ' || v_context, 'ERROR');
  return query select SQLERRM::text message, null, null;

end;
$_$;


ALTER FUNCTION fx.load_realtime_data_v6(p_instrument text, p_buy numeric, p_change numeric, p_high numeric, p_low numeric, p_price numeric, p_sell numeric, p_source text) OWNER TO forex_user;

--
-- Name: log_message(text, text, text); Type: FUNCTION; Schema: fx; Owner: forex_user
--

CREATE FUNCTION fx.log_message(p_function_name text, p_message text, p_log_level text DEFAULT 'DEBUG'::text) RETURNS void
    LANGUAGE plpgsql
    AS $$
declare
begin
  insert into fx.db_log (function_name, message, log_level)
    values (p_function_name, p_message, p_log_level);
end;
$$;


ALTER FUNCTION fx.log_message(p_function_name text, p_message text, p_log_level text) OWNER TO forex_user;

--
-- Name: new_forex_data_table(text); Type: FUNCTION; Schema: fx; Owner: forex_user
--

CREATE FUNCTION fx.new_forex_data_table(p_instrument text) RETURNS text
    LANGUAGE plpgsql
    AS $$
declare
  l_ddl text;
begin

  l_ddl := 'create table fx.forex_data_' || p_instrument || '(
    id      bigserial not null primary key,
    buy     numeric,
    change  numeric,
    high    numeric,
    low     numeric,
    price   numeric,
    sell    numeric,
    entdate timestamp default now(),
    source  text      not null
  )';

  EXECUTE l_ddl
  USING
    p_instrument;

  return p_instrument;

end;
$$;


ALTER FUNCTION fx.new_forex_data_table(p_instrument text) OWNER TO forex_user;

--
-- Name: node_registration(text); Type: FUNCTION; Schema: fx; Owner: forex_user
--

CREATE FUNCTION fx.node_registration(p_name text) RETURNS text
    LANGUAGE plpgsql
    AS $$
declare
  l_row_cnt int;
begin

  update fx.config_loader set -- node_config would be more appropriate
    last_contact = now()
  where name = p_name;

  GET DIAGNOSTICS l_row_cnt := ROW_COUNT;

  if l_row_cnt = 1 then
    return 'OK';
  end if;

  if l_row_cnt = 0 then
    insert into fx.config_loader(name, last_contact)
      values (p_name, now());
    return 'OK';
  end if;

  -- should never get here :)

end;
$$;


ALTER FUNCTION fx.node_registration(p_name text) OWNER TO forex_user;

--
-- Name: set_instrument_name_from_id(); Type: FUNCTION; Schema: fx; Owner: forex_user
--

CREATE FUNCTION fx.set_instrument_name_from_id() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
declare
  l_id int;
begin

  select id
  into l_id
  from fx.instrument
  where name = new.instrument;


  if (tg_op = 'UPDATE') then
    new.instrument_id := l_id;
    return new;
  elsif (tg_op = 'INSERT') then
    new.instrument_id := l_id;
    return new;
  end if;
  --return null; -- result is ignored since this is an after trigger
end;
$$;


ALTER FUNCTION fx.set_instrument_name_from_id() OWNER TO forex_user;

--
-- Name: update_availability_check(bigint, timestamp without time zone); Type: FUNCTION; Schema: fx; Owner: forex_user
--

CREATE FUNCTION fx.update_availability_check(p_id bigint, p_last_check timestamp without time zone DEFAULT NULL::timestamp without time zone) RETURNS text
    LANGUAGE plpgsql
    AS $$
declare
  l_function_name text := 'update_availability_check';
  l_ddl text;
  l_max_availability_check_count int;
  l_cnt int;
begin

  update fx.proxy_list set
    last_availability_check = p_last_check,
    availability_check_count = availability_check_count+1
  where id = p_id;

  create table if not exists fx.proxy_list_archive as
    select * from fx.proxy_list
    where 1 = 2;

  select count(*)
  into l_cnt
  from fx.config co
  where co.loader_id = 0 and co.name = 'max_availability_check_count';

  if l_cnt = 0 then
    l_max_availability_check_count := 5;
  else
    select co.value::int
    into l_max_availability_check_count
    from fx.config co
    where co.loader_id = 0 and co.name = 'max_availability_check_count';
  end if;

  perform fx.log_message(l_function_name, 'Debug: l_max_availability_check_count: ' || l_max_availability_check_count::text);

  insert into proxy_list_archive
    select * from proxy_list
    where 1 = 1
    and last_availability_check is null
    and availability_check_count > l_max_availability_check_count;

  delete from proxy_list
    where 1 = 1
    and last_availability_check is null
    and availability_check_count > l_max_availability_check_count;


  return p_id::text;

end;
$$;


ALTER FUNCTION fx.update_availability_check(p_id bigint, p_last_check timestamp without time zone) OWNER TO forex_user;

--
-- Name: validate_alert_price_move_data(); Type: FUNCTION; Schema: fx; Owner: forex_user
--

CREATE FUNCTION fx.validate_alert_price_move_data() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
declare
    l_id int;
    l_cnt int;
    rec record;
begin

    if (tg_op = 'UPDATE' or tg_op = 'INSERT') then
        select count(*)
        into l_cnt
        from instrument
        where name = new.instrument_name;

        if l_cnt = 0 then
            raise notice 'No instrument name defined in instrument table: %', new.instrument_name;
            return null;
        end if;

        select id
        into new.instrument_id
        from instrument
        where name = new.instrument_name;

    end if;
    -- TODO: delete
    --return null; -- result is ignored since this is an after trigger
    return new;
end;
$$;


ALTER FUNCTION fx.validate_alert_price_move_data() OWNER TO forex_user;

--
-- Name: validate_config_data(); Type: FUNCTION; Schema: fx; Owner: forex_user
--

CREATE FUNCTION fx.validate_config_data() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
declare
  l_id int;
  l_cnt int;
  rec record;
begin

  if (tg_op = 'UPDATE' or tg_op = 'INSERT') then
    -- Prevent entering non existant instrument into config table
    for rec in (
      select co.value
      from fx.config co
      where co.name = 'instrument'
    )
    loop
      l_cnt := 0;
      select count(*)
      into l_cnt
      from instrument
      where name = rec.value;

      if l_cnt = 0 then
        raise notice 'No instrument defined in instrument table: %', rec.value;
        return null;
      end if;

    end loop;
  end if;

  -- TODO: delete 

  --return null; -- result is ignored since this is an after trigger
  return new;
end;
$$;


ALTER FUNCTION fx.validate_config_data() OWNER TO forex_user;

--
-- Name: validate_instrument_id_and_name(); Type: FUNCTION; Schema: fx; Owner: forex_user
--

CREATE FUNCTION fx.validate_instrument_id_and_name() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
declare
    l_id int;
    l_cnt int;
    rec record;
begin

    if (tg_op = 'UPDATE' or tg_op = 'INSERT') then
        select count(*)
        into l_cnt
        from instrument
        where name = new.instrument_name;

        if l_cnt = 0 then
            raise notice 'No instrument name defined in instrument table: %', new.instrument_name;
            return null;
        end if;

        select id
        into new.instrument_id
        from instrument
        where name = new.instrument_name;

    end if;
    -- TODO: delete
    --return null; -- result is ignored since this is an after trigger
    return new;
end;
$$;


ALTER FUNCTION fx.validate_instrument_id_and_name() OWNER TO forex_user;

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: forex_realtime_data_copper; Type: TABLE; Schema: data; Owner: forex_user
--

CREATE TABLE data.forex_realtime_data_copper (
    id bigint NOT NULL,
    buy numeric,
    change numeric,
    high numeric,
    low numeric,
    price numeric,
    sell numeric,
    entdate timestamp without time zone DEFAULT now(),
    source_id integer NOT NULL
);


ALTER TABLE data.forex_realtime_data_copper OWNER TO forex_user;

--
-- Name: forex_realtime_data_copper_id_seq; Type: SEQUENCE; Schema: data; Owner: forex_user
--

CREATE SEQUENCE data.forex_realtime_data_copper_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE data.forex_realtime_data_copper_id_seq OWNER TO forex_user;

--
-- Name: forex_realtime_data_copper_id_seq; Type: SEQUENCE OWNED BY; Schema: data; Owner: forex_user
--

ALTER SEQUENCE data.forex_realtime_data_copper_id_seq OWNED BY data.forex_realtime_data_copper.id;


--
-- Name: forex_realtime_data_gold; Type: TABLE; Schema: data; Owner: forex_user
--

CREATE TABLE data.forex_realtime_data_gold (
    id bigint NOT NULL,
    buy numeric,
    change numeric,
    high numeric,
    low numeric,
    price numeric,
    sell numeric,
    entdate timestamp without time zone DEFAULT now(),
    source_id integer NOT NULL
);


ALTER TABLE data.forex_realtime_data_gold OWNER TO forex_user;

--
-- Name: forex_realtime_data_gold_id_seq; Type: SEQUENCE; Schema: data; Owner: forex_user
--

CREATE SEQUENCE data.forex_realtime_data_gold_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE data.forex_realtime_data_gold_id_seq OWNER TO forex_user;

--
-- Name: forex_realtime_data_gold_id_seq; Type: SEQUENCE OWNED BY; Schema: data; Owner: forex_user
--

ALTER SEQUENCE data.forex_realtime_data_gold_id_seq OWNED BY data.forex_realtime_data_gold.id;


--
-- Name: forex_realtime_data_oil; Type: TABLE; Schema: data; Owner: forex_user
--

CREATE TABLE data.forex_realtime_data_oil (
    id bigint NOT NULL,
    buy numeric,
    change numeric,
    high numeric,
    low numeric,
    price numeric,
    sell numeric,
    entdate timestamp without time zone DEFAULT now(),
    source_id integer NOT NULL
);


ALTER TABLE data.forex_realtime_data_oil OWNER TO forex_user;

--
-- Name: forex_realtime_data_oil_id_seq; Type: SEQUENCE; Schema: data; Owner: forex_user
--

CREATE SEQUENCE data.forex_realtime_data_oil_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE data.forex_realtime_data_oil_id_seq OWNER TO forex_user;

--
-- Name: forex_realtime_data_oil_id_seq; Type: SEQUENCE OWNED BY; Schema: data; Owner: forex_user
--

ALTER SEQUENCE data.forex_realtime_data_oil_id_seq OWNED BY data.forex_realtime_data_oil.id;


--
-- Name: alarm; Type: TABLE; Schema: fx; Owner: forex_user
--

CREATE TABLE fx.alarm (
    id bigint NOT NULL,
    source_id integer,
    instrument text NOT NULL,
    direction text,
    percentage numeric,
    duration integer,
    entdate timestamp without time zone DEFAULT now() NOT NULL,
    record_id bigint,
    price numeric,
    comparing_price numeric,
    alarm_id integer,
    alarm_type text
);


ALTER TABLE fx.alarm OWNER TO forex_user;

--
-- Name: alarm_def; Type: TABLE; Schema: fx; Owner: forex_user
--

CREATE TABLE fx.alarm_def (
    id integer NOT NULL,
    description text NOT NULL,
    instrument text NOT NULL,
    seeking_prc numeric NOT NULL,
    seeking_back_seconds integer,
    valid boolean DEFAULT true NOT NULL,
    active_since timestamp without time zone,
    alarm_type text NOT NULL
);


ALTER TABLE fx.alarm_def OWNER TO forex_user;

--
-- Name: alarm_def_v4; Type: TABLE; Schema: fx; Owner: forex_user
--

CREATE TABLE fx.alarm_def_v4 (
    id integer NOT NULL,
    description text NOT NULL,
    instrument_id integer NOT NULL,
    alarm_type_id integer NOT NULL,
    value_low numeric,
    value_high numeric,
    valid boolean DEFAULT false NOT NULL,
    alarm_active_since timestamp without time zone,
    alarm_repeat_rate integer DEFAULT 200 NOT NULL,
    alarm_max_repeat integer DEFAULT 10 NOT NULL,
    alarm_repeat_counter integer DEFAULT 0 NOT NULL,
    time_low integer,
    time_high integer
);


ALTER TABLE fx.alarm_def_v4 OWNER TO forex_user;

--
-- Name: COLUMN alarm_def_v4.alarm_repeat_rate; Type: COMMENT; Schema: fx; Owner: forex_user
--

COMMENT ON COLUMN fx.alarm_def_v4.alarm_repeat_rate IS 'Alarm creation pause (seconds)';


--
-- Name: COLUMN alarm_def_v4.time_low; Type: COMMENT; Schema: fx; Owner: forex_user
--

COMMENT ON COLUMN fx.alarm_def_v4.time_low IS 'Number of seconds';


--
-- Name: alarm_def_v4_id_seq; Type: SEQUENCE; Schema: fx; Owner: forex_user
--

CREATE SEQUENCE fx.alarm_def_v4_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE fx.alarm_def_v4_id_seq OWNER TO forex_user;

--
-- Name: alarm_def_v4_id_seq; Type: SEQUENCE OWNED BY; Schema: fx; Owner: forex_user
--

ALTER SEQUENCE fx.alarm_def_v4_id_seq OWNED BY fx.alarm_def_v4.id;


--
-- Name: alarm_id_seq; Type: SEQUENCE; Schema: fx; Owner: forex_user
--

CREATE SEQUENCE fx.alarm_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE fx.alarm_id_seq OWNER TO forex_user;

--
-- Name: alarm_id_seq; Type: SEQUENCE OWNED BY; Schema: fx; Owner: forex_user
--

ALTER SEQUENCE fx.alarm_id_seq OWNED BY fx.alarm_def.id;


--
-- Name: alarm_threshold_def; Type: TABLE; Schema: fx; Owner: forex_user
--

CREATE TABLE fx.alarm_threshold_def (
    id integer NOT NULL,
    description text NOT NULL,
    instrument text NOT NULL,
    threshold_lower_bound numeric NOT NULL,
    threshold_upper_bound numeric NOT NULL,
    valid boolean DEFAULT false NOT NULL,
    alarm_active_since timestamp without time zone,
    alarm_creation_pause integer NOT NULL,
    alarm_max_repeat integer NOT NULL,
    alarm_repeat_counter integer DEFAULT 0 NOT NULL
);


ALTER TABLE fx.alarm_threshold_def OWNER TO forex_user;

--
-- Name: COLUMN alarm_threshold_def.alarm_creation_pause; Type: COMMENT; Schema: fx; Owner: forex_user
--

COMMENT ON COLUMN fx.alarm_threshold_def.alarm_creation_pause IS 'Repeat rate in seconds';


--
-- Name: alarm_threshold_def_id_seq; Type: SEQUENCE; Schema: fx; Owner: forex_user
--

CREATE SEQUENCE fx.alarm_threshold_def_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE fx.alarm_threshold_def_id_seq OWNER TO forex_user;

--
-- Name: alarm_threshold_def_id_seq; Type: SEQUENCE OWNED BY; Schema: fx; Owner: forex_user
--

ALTER SEQUENCE fx.alarm_threshold_def_id_seq OWNED BY fx.alarm_threshold_def.id;


--
-- Name: alarm_type; Type: TABLE; Schema: fx; Owner: forex_user
--

CREATE TABLE fx.alarm_type (
    id integer NOT NULL,
    name text
);


ALTER TABLE fx.alarm_type OWNER TO forex_user;

--
-- Name: alarm_type_id_seq; Type: SEQUENCE; Schema: fx; Owner: forex_user
--

CREATE SEQUENCE fx.alarm_type_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE fx.alarm_type_id_seq OWNER TO forex_user;

--
-- Name: alarm_type_id_seq; Type: SEQUENCE OWNED BY; Schema: fx; Owner: forex_user
--

ALTER SEQUENCE fx.alarm_type_id_seq OWNED BY fx.alarm_type.id;


--
-- Name: alert_price_move; Type: TABLE; Schema: fx; Owner: forex_user
--

CREATE TABLE fx.alert_price_move (
    id integer NOT NULL,
    description text,
    instrument_id integer NOT NULL,
    instrument_name text NOT NULL,
    active boolean DEFAULT true NOT NULL,
    price_range numeric,
    price_percentage numeric,
    time_range_seconds integer NOT NULL,
    last_alarm_occurance timestamp without time zone,
    send_alarm boolean DEFAULT true NOT NULL,
    pause_alarm_sec integer DEFAULT 200 NOT NULL
);


ALTER TABLE fx.alert_price_move OWNER TO forex_user;

--
-- Name: alert_price_move_id_seq; Type: SEQUENCE; Schema: fx; Owner: forex_user
--

CREATE SEQUENCE fx.alert_price_move_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE fx.alert_price_move_id_seq OWNER TO forex_user;

--
-- Name: alert_price_move_id_seq; Type: SEQUENCE OWNED BY; Schema: fx; Owner: forex_user
--

ALTER SEQUENCE fx.alert_price_move_id_seq OWNED BY fx.alert_price_move.id;


--
-- Name: alert_price_treshold; Type: TABLE; Schema: fx; Owner: forex_user
--

CREATE TABLE fx.alert_price_treshold (
    id integer NOT NULL,
    instrument_id integer NOT NULL,
    instrument_name text NOT NULL,
    description text NOT NULL,
    target_resolution text,
    target_th_value numeric NOT NULL,
    th_desired_crossing_direction text NOT NULL,
    current_value_position text,
    alert_active_since timestamp without time zone,
    alert_send_interval_sec integer DEFAULT 300 NOT NULL,
    alert_send_count integer DEFAULT 0 NOT NULL,
    alert_last_sent timestamp without time zone,
    alert_max_send_nr integer DEFAULT 10,
    alert_clear_since timestamp without time zone,
    active boolean DEFAULT true NOT NULL,
    CONSTRAINT alert_price_treshold__current_value_position CHECK ((current_value_position = ANY (ARRAY[NULL::text, 'ABOVE'::text, 'BELOW'::text]))),
    CONSTRAINT alert_price_treshold__th_desired_crossing_direction CHECK ((th_desired_crossing_direction = ANY (ARRAY['UP'::text, 'DOWN'::text])))
);


ALTER TABLE fx.alert_price_treshold OWNER TO forex_user;

--
-- Name: COLUMN alert_price_treshold.th_desired_crossing_direction; Type: COMMENT; Schema: fx; Owner: forex_user
--

COMMENT ON COLUMN fx.alert_price_treshold.th_desired_crossing_direction IS 'UP or DOWN';


--
-- Name: COLUMN alert_price_treshold.current_value_position; Type: COMMENT; Schema: fx; Owner: forex_user
--

COMMENT ON COLUMN fx.alert_price_treshold.current_value_position IS 'ABOVE or BELOW';


--
-- Name: alert_price_treshold_id_seq; Type: SEQUENCE; Schema: fx; Owner: forex_user
--

CREATE SEQUENCE fx.alert_price_treshold_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE fx.alert_price_treshold_id_seq OWNER TO forex_user;

--
-- Name: alert_price_treshold_id_seq; Type: SEQUENCE OWNED BY; Schema: fx; Owner: forex_user
--

ALTER SEQUENCE fx.alert_price_treshold_id_seq OWNED BY fx.alert_price_treshold.id;


--
-- Name: analysis_log; Type: TABLE; Schema: fx; Owner: forex_user
--

CREATE TABLE fx.analysis_log (
    id integer NOT NULL,
    source text DEFAULT 'fortrade'::text NOT NULL,
    description text,
    analysis_date date,
    entdate timestamp without time zone DEFAULT now() NOT NULL,
    source_web text,
    name text
);


ALTER TABLE fx.analysis_log OWNER TO forex_user;

--
-- Name: analysis_log_id_seq; Type: SEQUENCE; Schema: fx; Owner: forex_user
--

CREATE SEQUENCE fx.analysis_log_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE fx.analysis_log_id_seq OWNER TO forex_user;

--
-- Name: analysis_log_id_seq; Type: SEQUENCE OWNED BY; Schema: fx; Owner: forex_user
--

ALTER SEQUENCE fx.analysis_log_id_seq OWNED BY fx.analysis_log.id;


--
-- Name: config; Type: TABLE; Schema: fx; Owner: forex_user
--

CREATE TABLE fx.config (
    id integer NOT NULL,
    name text NOT NULL,
    value text,
    loader_id integer,
    description text
);


ALTER TABLE fx.config OWNER TO forex_user;

--
-- Name: config_id_seq; Type: SEQUENCE; Schema: fx; Owner: forex_user
--

CREATE SEQUENCE fx.config_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE fx.config_id_seq OWNER TO forex_user;

--
-- Name: config_id_seq; Type: SEQUENCE OWNED BY; Schema: fx; Owner: forex_user
--

ALTER SEQUENCE fx.config_id_seq OWNED BY fx.config.id;


--
-- Name: config_loader; Type: TABLE; Schema: fx; Owner: forex_user
--

CREATE TABLE fx.config_loader (
    id integer NOT NULL,
    name text NOT NULL,
    last_contact timestamp without time zone
);


ALTER TABLE fx.config_loader OWNER TO forex_user;

--
-- Name: config_loader_id_seq; Type: SEQUENCE; Schema: fx; Owner: forex_user
--

CREATE SEQUENCE fx.config_loader_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE fx.config_loader_id_seq OWNER TO forex_user;

--
-- Name: config_loader_id_seq; Type: SEQUENCE OWNED BY; Schema: fx; Owner: forex_user
--

ALTER SEQUENCE fx.config_loader_id_seq OWNED BY fx.config_loader.id;


--
-- Name: db_log; Type: TABLE; Schema: fx; Owner: forex_user
--

CREATE TABLE fx.db_log (
    id bigint NOT NULL,
    log_date timestamp with time zone DEFAULT now() NOT NULL,
    log_level character varying(10) DEFAULT 'DEBUG'::character varying NOT NULL,
    function_name character varying(200),
    message character varying(4000)
);


ALTER TABLE fx.db_log OWNER TO forex_user;

--
-- Name: db_log_id_seq; Type: SEQUENCE; Schema: fx; Owner: forex_user
--

CREATE SEQUENCE fx.db_log_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE fx.db_log_id_seq OWNER TO forex_user;

--
-- Name: db_log_id_seq; Type: SEQUENCE OWNED BY; Schema: fx; Owner: forex_user
--

ALTER SEQUENCE fx.db_log_id_seq OWNED BY fx.db_log.id;


--
-- Name: event_id_seq; Type: SEQUENCE; Schema: fx; Owner: forex_user
--

CREATE SEQUENCE fx.event_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE fx.event_id_seq OWNER TO forex_user;

--
-- Name: event_id_seq; Type: SEQUENCE OWNED BY; Schema: fx; Owner: forex_user
--

ALTER SEQUENCE fx.event_id_seq OWNED BY fx.alarm.id;


--
-- Name: flyway_schema_history; Type: TABLE; Schema: fx; Owner: forex_user
--

CREATE TABLE fx.flyway_schema_history (
    installed_rank integer NOT NULL,
    version character varying(50),
    description character varying(200) NOT NULL,
    type character varying(20) NOT NULL,
    script character varying(1000) NOT NULL,
    checksum integer,
    installed_by character varying(100) NOT NULL,
    installed_on timestamp without time zone DEFAULT now() NOT NULL,
    execution_time integer NOT NULL,
    success boolean NOT NULL
);


ALTER TABLE fx.flyway_schema_history OWNER TO forex_user;

--
-- Name: instrument; Type: TABLE; Schema: fx; Owner: forex_user
--

CREATE TABLE fx.instrument (
    id integer NOT NULL,
    name text,
    last_market_check timestamp without time zone DEFAULT now(),
    market_is_open boolean DEFAULT false
);


ALTER TABLE fx.instrument OWNER TO forex_user;

--
-- Name: instrument_id_seq; Type: SEQUENCE; Schema: fx; Owner: forex_user
--

CREATE SEQUENCE fx.instrument_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE fx.instrument_id_seq OWNER TO forex_user;

--
-- Name: instrument_id_seq; Type: SEQUENCE OWNED BY; Schema: fx; Owner: forex_user
--

ALTER SEQUENCE fx.instrument_id_seq OWNED BY fx.instrument.id;


--
-- Name: instrument_parameter; Type: TABLE; Schema: fx; Owner: forex_user
--

CREATE TABLE fx.instrument_parameter (
    id integer NOT NULL,
    instrument text NOT NULL,
    instrument_id integer,
    chart_resolution text NOT NULL
);


ALTER TABLE fx.instrument_parameter OWNER TO forex_user;

--
-- Name: instrument_parameter_id_seq; Type: SEQUENCE; Schema: fx; Owner: forex_user
--

CREATE SEQUENCE fx.instrument_parameter_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE fx.instrument_parameter_id_seq OWNER TO forex_user;

--
-- Name: instrument_parameter_id_seq; Type: SEQUENCE OWNED BY; Schema: fx; Owner: forex_user
--

ALTER SEQUENCE fx.instrument_parameter_id_seq OWNED BY fx.instrument_parameter.id;


--
-- Name: instrument_parameter_value; Type: TABLE; Schema: fx; Owner: forex_user
--

CREATE TABLE fx.instrument_parameter_value (
    id bigint NOT NULL,
    instrument_parameter_id integer NOT NULL,
    name text NOT NULL,
    value text,
    entdate timestamp without time zone DEFAULT now(),
    value_text text,
    value_numeric numeric,
    value_date timestamp without time zone
);


ALTER TABLE fx.instrument_parameter_value OWNER TO forex_user;

--
-- Name: instrument_parameter_value_id_seq; Type: SEQUENCE; Schema: fx; Owner: forex_user
--

CREATE SEQUENCE fx.instrument_parameter_value_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE fx.instrument_parameter_value_id_seq OWNER TO forex_user;

--
-- Name: instrument_parameter_value_id_seq; Type: SEQUENCE OWNED BY; Schema: fx; Owner: forex_user
--

ALTER SEQUENCE fx.instrument_parameter_value_id_seq OWNED BY fx.instrument_parameter_value.id;


--
-- Name: position; Type: TABLE; Schema: fx; Owner: forex_user
--

CREATE TABLE fx."position" (
    id integer NOT NULL,
    instrument text NOT NULL,
    instrument_id integer NOT NULL,
    quantity numeric NOT NULL,
    range numeric,
    range_quantity_price numeric,
    entdate timestamp without time zone DEFAULT now() NOT NULL,
    moddate timestamp without time zone
);


ALTER TABLE fx."position" OWNER TO forex_user;

--
-- Name: COLUMN "position".range; Type: COMMENT; Schema: fx; Owner: forex_user
--

COMMENT ON COLUMN fx."position".range IS 'Used for unit price';


--
-- Name: position_id_seq; Type: SEQUENCE; Schema: fx; Owner: forex_user
--

CREATE SEQUENCE fx.position_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE fx.position_id_seq OWNER TO forex_user;

--
-- Name: position_id_seq; Type: SEQUENCE OWNED BY; Schema: fx; Owner: forex_user
--

ALTER SEQUENCE fx.position_id_seq OWNED BY fx."position".id;


--
-- Name: proxy_list; Type: TABLE; Schema: fx; Owner: forex_user
--

CREATE TABLE fx.proxy_list (
    id bigint NOT NULL,
    proxy_ip inet NOT NULL,
    proxy_port integer NOT NULL,
    entdate timestamp without time zone DEFAULT now() NOT NULL,
    proxy_type text,
    loading_source text,
    country text,
    last_availability_check timestamp without time zone,
    availability_check_count integer DEFAULT 0
);


ALTER TABLE fx.proxy_list OWNER TO forex_user;

--
-- Name: proxy_list_archive; Type: TABLE; Schema: fx; Owner: forex_user
--

CREATE TABLE fx.proxy_list_archive (
    id bigint,
    proxy_ip inet,
    proxy_port integer,
    entdate timestamp without time zone,
    proxy_type text,
    loading_source text,
    country text,
    last_availability_check timestamp without time zone,
    availability_check_count integer
);


ALTER TABLE fx.proxy_list_archive OWNER TO forex_user;

--
-- Name: proxy_list_id_seq; Type: SEQUENCE; Schema: fx; Owner: forex_user
--

CREATE SEQUENCE fx.proxy_list_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE fx.proxy_list_id_seq OWNER TO forex_user;

--
-- Name: proxy_list_id_seq; Type: SEQUENCE OWNED BY; Schema: fx; Owner: forex_user
--

ALTER SEQUENCE fx.proxy_list_id_seq OWNED BY fx.proxy_list.id;


--
-- Name: signal_definition; Type: TABLE; Schema: fx; Owner: forex_user
--

CREATE TABLE fx.signal_definition (
    id integer NOT NULL,
    instrument_text text,
    instrument_id integer NOT NULL,
    name text NOT NULL,
    description text,
    chart text
);


ALTER TABLE fx.signal_definition OWNER TO forex_user;

--
-- Name: signal_definition_id_seq; Type: SEQUENCE; Schema: fx; Owner: forex_user
--

CREATE SEQUENCE fx.signal_definition_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE fx.signal_definition_id_seq OWNER TO forex_user;

--
-- Name: signal_definition_id_seq; Type: SEQUENCE OWNED BY; Schema: fx; Owner: forex_user
--

ALTER SEQUENCE fx.signal_definition_id_seq OWNED BY fx.signal_definition.id;


--
-- Name: signal_value; Type: TABLE; Schema: fx; Owner: forex_user
--

CREATE TABLE fx.signal_value (
    id integer NOT NULL,
    signal_id integer NOT NULL,
    value_type text,
    value_text text,
    value_numeric numeric,
    value_date timestamp without time zone
);


ALTER TABLE fx.signal_value OWNER TO forex_user;

--
-- Name: signal_value_id_seq; Type: SEQUENCE; Schema: fx; Owner: forex_user
--

CREATE SEQUENCE fx.signal_value_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE fx.signal_value_id_seq OWNER TO forex_user;

--
-- Name: signal_value_id_seq; Type: SEQUENCE OWNED BY; Schema: fx; Owner: forex_user
--

ALTER SEQUENCE fx.signal_value_id_seq OWNED BY fx.signal_value.id;


--
-- Name: statistic; Type: TABLE; Schema: fx; Owner: forex_user
--

CREATE TABLE fx.statistic (
    id bigint NOT NULL,
    date_day date DEFAULT (now())::date NOT NULL,
    minute integer DEFAULT ((date_part('hour'::text, CURRENT_TIMESTAMP) * (60)::double precision) + date_part('minute'::text, CURRENT_TIMESTAMP)) NOT NULL,
    instrument_id integer NOT NULL,
    high numeric,
    low numeric,
    avg numeric
);


ALTER TABLE fx.statistic OWNER TO forex_user;

--
-- Name: statistic_id_seq; Type: SEQUENCE; Schema: fx; Owner: forex_user
--

CREATE SEQUENCE fx.statistic_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE fx.statistic_id_seq OWNER TO forex_user;

--
-- Name: statistic_id_seq; Type: SEQUENCE OWNED BY; Schema: fx; Owner: forex_user
--

ALTER SEQUENCE fx.statistic_id_seq OWNED BY fx.statistic.id;


--
-- Name: forex_realtime_data_copper id; Type: DEFAULT; Schema: data; Owner: forex_user
--

ALTER TABLE ONLY data.forex_realtime_data_copper ALTER COLUMN id SET DEFAULT nextval('data.forex_realtime_data_copper_id_seq'::regclass);


--
-- Name: forex_realtime_data_gold id; Type: DEFAULT; Schema: data; Owner: forex_user
--

ALTER TABLE ONLY data.forex_realtime_data_gold ALTER COLUMN id SET DEFAULT nextval('data.forex_realtime_data_gold_id_seq'::regclass);


--
-- Name: forex_realtime_data_oil id; Type: DEFAULT; Schema: data; Owner: forex_user
--

ALTER TABLE ONLY data.forex_realtime_data_oil ALTER COLUMN id SET DEFAULT nextval('data.forex_realtime_data_oil_id_seq'::regclass);


--
-- Name: alarm id; Type: DEFAULT; Schema: fx; Owner: forex_user
--

ALTER TABLE ONLY fx.alarm ALTER COLUMN id SET DEFAULT nextval('fx.event_id_seq'::regclass);


--
-- Name: alarm_def id; Type: DEFAULT; Schema: fx; Owner: forex_user
--

ALTER TABLE ONLY fx.alarm_def ALTER COLUMN id SET DEFAULT nextval('fx.alarm_id_seq'::regclass);


--
-- Name: alarm_def_v4 id; Type: DEFAULT; Schema: fx; Owner: forex_user
--

ALTER TABLE ONLY fx.alarm_def_v4 ALTER COLUMN id SET DEFAULT nextval('fx.alarm_def_v4_id_seq'::regclass);


--
-- Name: alarm_threshold_def id; Type: DEFAULT; Schema: fx; Owner: forex_user
--

ALTER TABLE ONLY fx.alarm_threshold_def ALTER COLUMN id SET DEFAULT nextval('fx.alarm_threshold_def_id_seq'::regclass);


--
-- Name: alarm_type id; Type: DEFAULT; Schema: fx; Owner: forex_user
--

ALTER TABLE ONLY fx.alarm_type ALTER COLUMN id SET DEFAULT nextval('fx.alarm_type_id_seq'::regclass);


--
-- Name: alert_price_move id; Type: DEFAULT; Schema: fx; Owner: forex_user
--

ALTER TABLE ONLY fx.alert_price_move ALTER COLUMN id SET DEFAULT nextval('fx.alert_price_move_id_seq'::regclass);


--
-- Name: alert_price_treshold id; Type: DEFAULT; Schema: fx; Owner: forex_user
--

ALTER TABLE ONLY fx.alert_price_treshold ALTER COLUMN id SET DEFAULT nextval('fx.alert_price_treshold_id_seq'::regclass);


--
-- Name: analysis_log id; Type: DEFAULT; Schema: fx; Owner: forex_user
--

ALTER TABLE ONLY fx.analysis_log ALTER COLUMN id SET DEFAULT nextval('fx.analysis_log_id_seq'::regclass);


--
-- Name: config id; Type: DEFAULT; Schema: fx; Owner: forex_user
--

ALTER TABLE ONLY fx.config ALTER COLUMN id SET DEFAULT nextval('fx.config_id_seq'::regclass);


--
-- Name: config_loader id; Type: DEFAULT; Schema: fx; Owner: forex_user
--

ALTER TABLE ONLY fx.config_loader ALTER COLUMN id SET DEFAULT nextval('fx.config_loader_id_seq'::regclass);


--
-- Name: db_log id; Type: DEFAULT; Schema: fx; Owner: forex_user
--

ALTER TABLE ONLY fx.db_log ALTER COLUMN id SET DEFAULT nextval('fx.db_log_id_seq'::regclass);


--
-- Name: instrument id; Type: DEFAULT; Schema: fx; Owner: forex_user
--

ALTER TABLE ONLY fx.instrument ALTER COLUMN id SET DEFAULT nextval('fx.instrument_id_seq'::regclass);


--
-- Name: instrument_parameter id; Type: DEFAULT; Schema: fx; Owner: forex_user
--

ALTER TABLE ONLY fx.instrument_parameter ALTER COLUMN id SET DEFAULT nextval('fx.instrument_parameter_id_seq'::regclass);


--
-- Name: instrument_parameter_value id; Type: DEFAULT; Schema: fx; Owner: forex_user
--

ALTER TABLE ONLY fx.instrument_parameter_value ALTER COLUMN id SET DEFAULT nextval('fx.instrument_parameter_value_id_seq'::regclass);


--
-- Name: position id; Type: DEFAULT; Schema: fx; Owner: forex_user
--

ALTER TABLE ONLY fx."position" ALTER COLUMN id SET DEFAULT nextval('fx.position_id_seq'::regclass);


--
-- Name: proxy_list id; Type: DEFAULT; Schema: fx; Owner: forex_user
--

ALTER TABLE ONLY fx.proxy_list ALTER COLUMN id SET DEFAULT nextval('fx.proxy_list_id_seq'::regclass);


--
-- Name: signal_definition id; Type: DEFAULT; Schema: fx; Owner: forex_user
--

ALTER TABLE ONLY fx.signal_definition ALTER COLUMN id SET DEFAULT nextval('fx.signal_definition_id_seq'::regclass);


--
-- Name: signal_value id; Type: DEFAULT; Schema: fx; Owner: forex_user
--

ALTER TABLE ONLY fx.signal_value ALTER COLUMN id SET DEFAULT nextval('fx.signal_value_id_seq'::regclass);


--
-- Name: statistic id; Type: DEFAULT; Schema: fx; Owner: forex_user
--

ALTER TABLE ONLY fx.statistic ALTER COLUMN id SET DEFAULT nextval('fx.statistic_id_seq'::regclass);


--
-- Name: forex_realtime_data_copper forex_realtime_data_copper_pkey; Type: CONSTRAINT; Schema: data; Owner: forex_user
--

ALTER TABLE ONLY data.forex_realtime_data_copper
    ADD CONSTRAINT forex_realtime_data_copper_pkey PRIMARY KEY (id);


--
-- Name: forex_realtime_data_gold forex_realtime_data_gold_pkey; Type: CONSTRAINT; Schema: data; Owner: forex_user
--

ALTER TABLE ONLY data.forex_realtime_data_gold
    ADD CONSTRAINT forex_realtime_data_gold_pkey PRIMARY KEY (id);


--
-- Name: forex_realtime_data_oil forex_realtime_data_oil_pkey; Type: CONSTRAINT; Schema: data; Owner: forex_user
--

ALTER TABLE ONLY data.forex_realtime_data_oil
    ADD CONSTRAINT forex_realtime_data_oil_pkey PRIMARY KEY (id);


--
-- Name: alarm_def_v4 alarm_def_v4_pkey; Type: CONSTRAINT; Schema: fx; Owner: forex_user
--

ALTER TABLE ONLY fx.alarm_def_v4
    ADD CONSTRAINT alarm_def_v4_pkey PRIMARY KEY (id);


--
-- Name: alarm_def alarm_pkey; Type: CONSTRAINT; Schema: fx; Owner: forex_user
--

ALTER TABLE ONLY fx.alarm_def
    ADD CONSTRAINT alarm_pkey PRIMARY KEY (id);


--
-- Name: alarm_threshold_def alarm_threshold_def_pkey; Type: CONSTRAINT; Schema: fx; Owner: forex_user
--

ALTER TABLE ONLY fx.alarm_threshold_def
    ADD CONSTRAINT alarm_threshold_def_pkey PRIMARY KEY (id);


--
-- Name: alarm_type alarm_type_name_unique; Type: CONSTRAINT; Schema: fx; Owner: forex_user
--

ALTER TABLE ONLY fx.alarm_type
    ADD CONSTRAINT alarm_type_name_unique UNIQUE (name);


--
-- Name: alarm_type alarm_type_pkey; Type: CONSTRAINT; Schema: fx; Owner: forex_user
--

ALTER TABLE ONLY fx.alarm_type
    ADD CONSTRAINT alarm_type_pkey PRIMARY KEY (id);


--
-- Name: alert_price_move alert_price_move_pkey; Type: CONSTRAINT; Schema: fx; Owner: forex_user
--

ALTER TABLE ONLY fx.alert_price_move
    ADD CONSTRAINT alert_price_move_pkey PRIMARY KEY (id);


--
-- Name: alert_price_treshold alert_price_treshold_pkey; Type: CONSTRAINT; Schema: fx; Owner: forex_user
--

ALTER TABLE ONLY fx.alert_price_treshold
    ADD CONSTRAINT alert_price_treshold_pkey PRIMARY KEY (id);


--
-- Name: config_loader config_loader_pkey; Type: CONSTRAINT; Schema: fx; Owner: forex_user
--

ALTER TABLE ONLY fx.config_loader
    ADD CONSTRAINT config_loader_pkey PRIMARY KEY (id);


--
-- Name: alarm event_pkey; Type: CONSTRAINT; Schema: fx; Owner: forex_user
--

ALTER TABLE ONLY fx.alarm
    ADD CONSTRAINT event_pkey PRIMARY KEY (id);


--
-- Name: flyway_schema_history flyway_schema_history_pk; Type: CONSTRAINT; Schema: fx; Owner: forex_user
--

ALTER TABLE ONLY fx.flyway_schema_history
    ADD CONSTRAINT flyway_schema_history_pk PRIMARY KEY (installed_rank);


--
-- Name: instrument instrument_name_unique; Type: CONSTRAINT; Schema: fx; Owner: forex_user
--

ALTER TABLE ONLY fx.instrument
    ADD CONSTRAINT instrument_name_unique UNIQUE (name);


--
-- Name: instrument_parameter instrument_parameter_instrument_key; Type: CONSTRAINT; Schema: fx; Owner: forex_user
--

ALTER TABLE ONLY fx.instrument_parameter
    ADD CONSTRAINT instrument_parameter_instrument_key UNIQUE (instrument);


--
-- Name: instrument_parameter instrument_parameter_pkey; Type: CONSTRAINT; Schema: fx; Owner: forex_user
--

ALTER TABLE ONLY fx.instrument_parameter
    ADD CONSTRAINT instrument_parameter_pkey PRIMARY KEY (id);


--
-- Name: instrument_parameter_value instrument_parameter_value_pkey; Type: CONSTRAINT; Schema: fx; Owner: forex_user
--

ALTER TABLE ONLY fx.instrument_parameter_value
    ADD CONSTRAINT instrument_parameter_value_pkey PRIMARY KEY (id);


--
-- Name: instrument instrument_pkey; Type: CONSTRAINT; Schema: fx; Owner: forex_user
--

ALTER TABLE ONLY fx.instrument
    ADD CONSTRAINT instrument_pkey PRIMARY KEY (id);


--
-- Name: position position_pk; Type: CONSTRAINT; Schema: fx; Owner: forex_user
--

ALTER TABLE ONLY fx."position"
    ADD CONSTRAINT position_pk PRIMARY KEY (id);


--
-- Name: proxy_list proxy_list_pkey; Type: CONSTRAINT; Schema: fx; Owner: forex_user
--

ALTER TABLE ONLY fx.proxy_list
    ADD CONSTRAINT proxy_list_pkey PRIMARY KEY (id);


--
-- Name: proxy_list proxy_list_proxy_ip_proxy_port_key; Type: CONSTRAINT; Schema: fx; Owner: forex_user
--

ALTER TABLE ONLY fx.proxy_list
    ADD CONSTRAINT proxy_list_proxy_ip_proxy_port_key UNIQUE (proxy_ip, proxy_port);


--
-- Name: signal_definition signal_definition_pkey; Type: CONSTRAINT; Schema: fx; Owner: forex_user
--

ALTER TABLE ONLY fx.signal_definition
    ADD CONSTRAINT signal_definition_pkey PRIMARY KEY (id);


--
-- Name: signal_value signal_value_pkey; Type: CONSTRAINT; Schema: fx; Owner: forex_user
--

ALTER TABLE ONLY fx.signal_value
    ADD CONSTRAINT signal_value_pkey PRIMARY KEY (id);


--
-- Name: statistic statistic_pkey; Type: CONSTRAINT; Schema: fx; Owner: forex_user
--

ALTER TABLE ONLY fx.statistic
    ADD CONSTRAINT statistic_pkey PRIMARY KEY (id);


--
-- Name: forex_realtime_data_copper_entdate_index; Type: INDEX; Schema: data; Owner: forex_user
--

CREATE INDEX forex_realtime_data_copper_entdate_index ON data.forex_realtime_data_copper USING btree (entdate);


--
-- Name: forex_realtime_data_gold_entdate_index; Type: INDEX; Schema: data; Owner: forex_user
--

CREATE INDEX forex_realtime_data_gold_entdate_index ON data.forex_realtime_data_gold USING btree (entdate);


--
-- Name: forex_realtime_data_oil_entdate_index; Type: INDEX; Schema: data; Owner: forex_user
--

CREATE INDEX forex_realtime_data_oil_entdate_index ON data.forex_realtime_data_oil USING btree (entdate);


--
-- Name: config_loader_id_name_uindex; Type: INDEX; Schema: fx; Owner: forex_user
--

CREATE UNIQUE INDEX config_loader_id_name_uindex ON fx.config USING btree (loader_id, name);


--
-- Name: config_loader_name_uindex; Type: INDEX; Schema: fx; Owner: forex_user
--

CREATE UNIQUE INDEX config_loader_name_uindex ON fx.config_loader USING btree (name);


--
-- Name: db_log__idx1; Type: INDEX; Schema: fx; Owner: forex_user
--

CREATE INDEX db_log__idx1 ON fx.db_log USING btree (log_date);


--
-- Name: flyway_schema_history_s_idx; Type: INDEX; Schema: fx; Owner: forex_user
--

CREATE INDEX flyway_schema_history_s_idx ON fx.flyway_schema_history USING btree (success);


--
-- Name: position__index1; Type: INDEX; Schema: fx; Owner: forex_user
--

CREATE UNIQUE INDEX position__index1 ON fx."position" USING btree (instrument, quantity);


--
-- Name: alert_price_move alert_price_move_trigger1; Type: TRIGGER; Schema: fx; Owner: forex_user
--

CREATE TRIGGER alert_price_move_trigger1 BEFORE INSERT OR UPDATE ON fx.alert_price_move FOR EACH ROW EXECUTE FUNCTION fx.validate_instrument_id_and_name();


--
-- Name: alert_price_treshold alert_price_treshold_trigger1; Type: TRIGGER; Schema: fx; Owner: forex_user
--

CREATE TRIGGER alert_price_treshold_trigger1 BEFORE INSERT OR UPDATE ON fx.alert_price_treshold FOR EACH ROW EXECUTE FUNCTION fx.validate_instrument_id_and_name();


--
-- Name: config config_trigger1; Type: TRIGGER; Schema: fx; Owner: forex_user
--

CREATE TRIGGER config_trigger1 BEFORE INSERT OR UPDATE ON fx.config FOR EACH ROW EXECUTE FUNCTION fx.validate_config_data();


--
-- Name: position instrument_trigger2; Type: TRIGGER; Schema: fx; Owner: forex_user
--

CREATE TRIGGER instrument_trigger2 BEFORE INSERT OR UPDATE ON fx."position" FOR EACH ROW EXECUTE FUNCTION fx.set_instrument_name_from_id();


--
-- Name: alarm alarm_alarm_id_fkey; Type: FK CONSTRAINT; Schema: fx; Owner: forex_user
--

ALTER TABLE ONLY fx.alarm
    ADD CONSTRAINT alarm_alarm_id_fkey FOREIGN KEY (alarm_id) REFERENCES fx.alarm_def(id);


--
-- Name: alarm_def_v4 alarm_def_v4_alarm_type_id_fkey; Type: FK CONSTRAINT; Schema: fx; Owner: forex_user
--

ALTER TABLE ONLY fx.alarm_def_v4
    ADD CONSTRAINT alarm_def_v4_alarm_type_id_fkey FOREIGN KEY (alarm_type_id) REFERENCES fx.alarm_type(id);


--
-- Name: alarm_def_v4 alarm_def_v4_instrument_id_fkey; Type: FK CONSTRAINT; Schema: fx; Owner: forex_user
--

ALTER TABLE ONLY fx.alarm_def_v4
    ADD CONSTRAINT alarm_def_v4_instrument_id_fkey FOREIGN KEY (instrument_id) REFERENCES fx.instrument(id);


--
-- Name: alert_price_move alert_price_move_instrument_id_fkey; Type: FK CONSTRAINT; Schema: fx; Owner: forex_user
--

ALTER TABLE ONLY fx.alert_price_move
    ADD CONSTRAINT alert_price_move_instrument_id_fkey FOREIGN KEY (instrument_id) REFERENCES fx.instrument(id);


--
-- Name: alert_price_treshold alert_price_treshold_instrument_id_fkey; Type: FK CONSTRAINT; Schema: fx; Owner: forex_user
--

ALTER TABLE ONLY fx.alert_price_treshold
    ADD CONSTRAINT alert_price_treshold_instrument_id_fkey FOREIGN KEY (instrument_id) REFERENCES fx.instrument(id);


--
-- Name: config config_config_loader_id_fk; Type: FK CONSTRAINT; Schema: fx; Owner: forex_user
--

ALTER TABLE ONLY fx.config
    ADD CONSTRAINT config_config_loader_id_fk FOREIGN KEY (loader_id) REFERENCES fx.config_loader(id);


--
-- Name: alarm event_source_id_fkey; Type: FK CONSTRAINT; Schema: fx; Owner: forex_user
--

ALTER TABLE ONLY fx.alarm
    ADD CONSTRAINT event_source_id_fkey FOREIGN KEY (source_id) REFERENCES fx.config_loader(id);


--
-- Name: instrument_parameter instrument_parameter_instrument_id_fkey; Type: FK CONSTRAINT; Schema: fx; Owner: forex_user
--

ALTER TABLE ONLY fx.instrument_parameter
    ADD CONSTRAINT instrument_parameter_instrument_id_fkey FOREIGN KEY (instrument_id) REFERENCES fx.instrument(id);


--
-- Name: instrument_parameter_value instrument_parameter_value_instrument_parameter_id_fkey; Type: FK CONSTRAINT; Schema: fx; Owner: forex_user
--

ALTER TABLE ONLY fx.instrument_parameter_value
    ADD CONSTRAINT instrument_parameter_value_instrument_parameter_id_fkey FOREIGN KEY (instrument_parameter_id) REFERENCES fx.instrument_parameter(id);


--
-- Name: position position_instrument_id_fk; Type: FK CONSTRAINT; Schema: fx; Owner: forex_user
--

ALTER TABLE ONLY fx."position"
    ADD CONSTRAINT position_instrument_id_fk FOREIGN KEY (instrument_id) REFERENCES fx.instrument(id);


--
-- Name: signal_definition signal_definition_instrument_id_fkey; Type: FK CONSTRAINT; Schema: fx; Owner: forex_user
--

ALTER TABLE ONLY fx.signal_definition
    ADD CONSTRAINT signal_definition_instrument_id_fkey FOREIGN KEY (instrument_id) REFERENCES fx.instrument(id);


--
-- Name: signal_value signal_value_signal_id_fkey; Type: FK CONSTRAINT; Schema: fx; Owner: forex_user
--

ALTER TABLE ONLY fx.signal_value
    ADD CONSTRAINT signal_value_signal_id_fkey FOREIGN KEY (signal_id) REFERENCES fx.signal_definition(id);


--
-- Name: statistic statistic_instrument_id_fkey; Type: FK CONSTRAINT; Schema: fx; Owner: forex_user
--

ALTER TABLE ONLY fx.statistic
    ADD CONSTRAINT statistic_instrument_id_fkey FOREIGN KEY (instrument_id) REFERENCES fx.instrument(id);


--
-- Name: SCHEMA fx; Type: ACL; Schema: -; Owner: forex_user
--

REVOKE ALL ON SCHEMA fx FROM postgres;
REVOKE ALL ON SCHEMA fx FROM PUBLIC;
GRANT ALL ON SCHEMA fx TO forex_user;
GRANT ALL ON SCHEMA fx TO PUBLIC;


--
-- Name: TABLE alarm; Type: ACL; Schema: fx; Owner: forex_user
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE fx.alarm TO forex_bl;


--
-- Name: TABLE alarm_def; Type: ACL; Schema: fx; Owner: forex_user
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE fx.alarm_def TO forex_bl;


--
-- Name: TABLE alarm_threshold_def; Type: ACL; Schema: fx; Owner: forex_user
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE fx.alarm_threshold_def TO forex_bl;


--
-- Name: TABLE analysis_log; Type: ACL; Schema: fx; Owner: forex_user
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE fx.analysis_log TO forex_bl;


--
-- Name: TABLE config; Type: ACL; Schema: fx; Owner: forex_user
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE fx.config TO forex_bl;


--
-- Name: TABLE config_loader; Type: ACL; Schema: fx; Owner: forex_user
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE fx.config_loader TO forex_bl;


--
-- Name: TABLE db_log; Type: ACL; Schema: fx; Owner: forex_user
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE fx.db_log TO forex_bl;


--
-- PostgreSQL database dump complete
--


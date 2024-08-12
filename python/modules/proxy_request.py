import random
import requests
import sys
import time

import write

class ProxyRequest:
    def __init__(self, par):
        self._par = par
        self._db = par.db
        self._proxy_timeout = int(self._db.get_config('proxy_time_out'))

    def get_proxies(self):
        sql = "select proxy_ip, proxy_port, id from fx.get_active_proxies(%s)"
        self._db.cursor.execute(sql, (self._par.node_name, ))
        self._fetched_proxies = self._db.cursor.fetchall()

    def check_availability(self):
        for proxy_server in self._fetched_proxies:
            write.msg("Debug: {}".format(self._par.cfg_secret['EMAIL']['USER']))
            #print('Checking proxy: ', proxy_server, 'timeout: ', self._proxy_timeout)
            write.msg('Checking proxy: {}; timeout: {}'.format(proxy_server, self._proxy_timeout))
            sys.stdout.flush()

            host = proxy_server[0]
            port = proxy_server[1]
            host_id = proxy_server[2]

            proxies = {
                'http' : 'http://{}:{}'.format(host, port),
                'https': 'http://{}:{}'.format(host, port),
            }
            headers = {
                'User-Agent': 'Mozilla/5.0 (X11; Linux x86_64; rv:78.0) Gecko/20100101 Firefox/78.0',
            }

            ok = False
            try:
                endpoint = self._db.get_config('proxy_test_endpoint', default_value='https://static.kodera.hr')
                r = requests.get(endpoint, proxies=proxies, timeout=self._proxy_timeout, headers=headers)
                ok = True
                write.msg('Proxy OK: {}'.format(proxy_server))
            except requests.exceptions.ConnectTimeout:
                print('ConnectTimeout')
            except requests.exceptions.ProxyError:
                print('ProxyError')
            except Exception:
                e = sys.exc_info()
                print(e)

            if ok:
                print('OK')
                sql = "select fx.update_availability_check(%s::bigint, now()::timestamp)"
            else:
                sql = "select fx.update_availability_check(%s)"

            self._db.cursor.execute(sql, (host_id, ))
            self._db.transaction_commit()

            sys.stdout.flush()
            sys.stderr.flush()

    def get_running_proxies(self):
        sql = "select proxy_ip, proxy_port, id from fx.proxy_list where 1 = 1 and last_availability_check is not null"
        self._db.cursor.execute(sql)
        return self._db.cursor.fetchall()

    def get_random_proxy(self):
        while True:
            try:
                return random.choice(self.get_running_proxies())
            except Exception:
                e = sys.exc_info()
                print(e)
                sys.stderr.write("Cannot return proxy! Sleeping for 1 minute... Exception: {}\n".format(e))
                #ret_val = ['0.0.0.0', '0', '0']
                #print('sleep!')
                sys.stdout.flush()
                time.sleep(1*60)

import requests
import sys

from proxy_request import ProxyRequest

class QueryCapexData():
    def __init__(self, par):
        self.par = par
        self._db = self.par.db
        self.instrument = self._db.get_config('instrument', loader_name=self.par.loader_name)
        self._endpoint_base_chart = self._db.get_config('endpoint_base_chart')
        self._endpoint_base_realtime = self._db.get_config('endpoint_base_realtime')
        self._get_forex_data_timeout = int(self._db.get_config('get_forex_data_timeout', default_value=10))
        
    def is_market_open(self):
        # Get config value:
        try:
            sql = "select fx.is_market_open(%s)"
            self._db.cursor.execute(sql, (self.instrument, ))
            fetchone = self._db.cursor.fetchone()
            #print('debug', fetchone)
            self._db.transaction_commit()
            return fetchone[0]
        except:
            sys.stderr.write('Error fetching data: fx.is_market_open({})\n'.format(self.instrument))
            e = sys.exc_info()
            sys.stderr.write(str(e))
            sys.stderr.flush()

    def set_query_data_params(self, resolution=None):
        if not self.instrument:
            sys.stderr.write('Instrument not defined. Exit.\n')
            sys.stderr.flush()
            exit(2)
        else:
            sys.stdout.write('Instrument defined: {}\n'.format(self.instrument))
            sys.stdout.flush()


        if resolution:
            self._endpoint = ((self._db.get_config('endpoint_base', 
                loader_name=self.par.loader_name, default_value=self._endpoint_base_chart)).replace(
                '__INSTRUMENT__', self.instrument)).replace(
                    '__RESOLUTION__', resolution)
        else:
            self._endpoint = (self._db.get_config('endpoint_base', 
                loader_name=self.par.loader_name, default_value=self._endpoint_base_realtime)).replace(
                '__INSTRUMENT__', self.instrument)

    def query_forex_data(self):
        pr = ProxyRequest(self._db)
        if not self._endpoint:
            sys.stderr.write('No endpoint_base defined!\n')
            sys.stderr.flush()
            return

        #print('endpoint ======================>', self._endpoint)
        #sys.stdout.flush()
        #return

        ok = False
        while not ok:
            random_proxy = pr.get_random_proxy()
            proxy_server = random_proxy

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

            try:
                print('Trying endpoint:', self._endpoint, 'Using proxy:', proxy_server)
                resp = requests.post(self._endpoint, proxies=proxies, timeout=self._get_forex_data_timeout, headers=headers)
                print('Fetched from endpoint:', self._endpoint, 'Using proxy:', proxy_server)
                # Request to Forex API:
                resp = resp.json()
                print('Fetched data:', resp)
                #sys.stdout.flush()
                return resp
                ok = True
            #except requests.exceptions.ConnectTimeout:
            #    pass
            #    print('ConnectTimeout')
            #except requests.exceptions.ProxyError:
            #    print('ProxyError')
            except Exception:
                e = sys.exc_info()
                #sys.stderr.write(str(e)) # No good - $ docker inspect get_forex_realtime_data_1 |grep err   ->  "AttachStderr": false
                sys.stdout.write(str(e))
                
    #def write_2_db(self, resolution, json_data):
    def write_chart_data_2_db(self, resolution, json_data):
        try:
            sql = """select fx.load_chart_data(%s, %s, %s::text, %s, 
                %s, %s, %s, %s)"""
            #TODO: Nice to have: sorted items by element nr. 0, but it looks like it's alwaysw sorted from the capex.com
            for element in json_data:
                #print(element)
                self._db.cursor.execute(sql, (self.instrument, resolution, element[0], element[1], 
                    element[2], element[3], element[4], self.par.loader_name))
                fetchone = self._db.cursor.fetchone()
                #if fetchone[0]:
                #print('==========================> debug', fetchone)
                self._db.transaction_commit()
        except Exception:
            e = sys.exc_info()
            sys.stdout.write('Error at write_chart_data_2_db: ' + str(e))

            
    def write_realtime_data_2_db(self, json_data):
        try:
            data = json_data[self.instrument]
            print('write_realtime_data_2_db: json_data:', json_data)

            # testing _v6 with gold:
            if self.instrument == 'gold': 
                sql = """select message, alarm_type, instrument from fx.load_realtime_data_v6(%s, %s, %s, %s, 
                    %s, %s, %s, %s)"""
            else:
                sql = """select fx.load_realtime_data_v5(%s, %s, %s, %s, 
                    %s, %s, %s, %s)"""

            self._db.cursor.execute(sql, (
                self.instrument,
                data['buy'],
                data['change'].strip('%'),
                data['high'],
                data['low'],
                data['price'],
                data['sell'],
                self.par.loader_name,
                ))

            all_rows = self._db.cursor.fetchall()
            for row in all_rows:
                print('row:', row)
                sys.stdout.flush()
                send_email = self._db.get_config('send_email', loader_name='default')

            self._db.transaction_commit()
        except Exception:
            e = sys.exc_info()
            sys.stdout.write('Error at write_realtime_data_2_db: ' + str(e))
            print('json_data:', json_data)

            

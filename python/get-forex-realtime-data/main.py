#!/usr/bin/env python3
import argparse
import calendar
import os
import sentry_sdk
import sys
import time
import yaml

from datetime import datetime

script_dir = os.path.dirname(__file__)
module_dir = os.path.join(script_dir, '..', 'modules')
sys.path.append(module_dir)
#import mymodule
#mymodule.say_hello()
from forexdb import DB
from proxy_request import ProxyRequest
from query_capex_data import QueryCapexData


class Params:
    pass


class Main:

    def __init__(self):
        ##BASE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
        self.BASE_DIR = os.path.dirname(os.path.realpath(__file__))
        self.BASE_DIR = self.BASE_DIR + '/'
        #exec(open(SETTING_FILE).read())

    def _action(self, par):
        cd = QueryCapexData(par)
        cd.set_query_data_params()
        json_data = cd.query_forex_data()
        cd.write_realtime_data_2_db(json_data)

    def calculate_sleep_time(self, prev_start_time, wait_time):
        utctime = datetime.utcnow()
        utcnow = calendar.timegm(utctime.utctimetuple())
        next_start_time_calc = prev_start_time + wait_time
        if next_start_time_calc <= utcnow:
            return 0
        return next_start_time_calc - utcnow


    def main(self):
        parser = argparse.ArgumentParser()
        parser.add_argument("-c", "--config-file", help="Configuration file", type=str)
        args = parser.parse_args()

        par = Params()
        par.loader_name = (os.getenv('CONTAINER_NAME') + '@' + os.getenv('HOST_HOSTNAME'))

        if 'dev' in par.loader_name:
            sentry_project = "https://c360a5e2974e4b6cb220bd4c7cfedbf5@sentry.kodera.hr/5"
        else:
            sentry_project = "https://84515b11ab3a4f98adf0c83234bb42eb@sentry.kodera.hr/7"

        sentry_sdk.init(
            sentry_project,
            traces_sample_rate=1.0
        )

        # Read configuration file:
        if args.config_file:
            config_file = args.config_file
        else:
            config_file = self.BASE_DIR + 'config.yml'

        try:
            with open(config_file) as fh:
                par.cfg = yaml.load(fh, Loader=yaml.SafeLoader)
        except IOError:
            sys.stderr.write("ERROR: Cannot open configuration file: {}\n".format(config_file))
            sys.exit(2)

        par.db = DB(par)

        print('par.loader_name:', par.loader_name)
        sys.stdout.flush()

        par.db.node_registration(par.loader_name)
        par.db.transaction_commit()
        
        par.sleep_interval_sec = int(par.db.get_config('data_load_interval', par.loader_name, default_value=10))

        #utctime = datetime.utcnow()
        #utcnow = calendar.timegm(utctime.utctimetuple())
        ##print(utcnow)
        #print(self.calculate_sleep_time(utcnow-2, 1))
        #exit(0)

        #instrument = par.db.get_config('instrument', loader_name=par.loader_name)
        while True:
            utctime = datetime.utcnow()
            ## TODO: is market open - quick workaround for forex:
            ##if instrument in ['btcfutures', 'ethereum']:
            #if False:
            #    pass
            #else:
            if utctime.weekday() in [5, 6]:
                time.sleep(par.sleep_interval_sec)
                print('Weekend!')
                sys.stdout.flush()
                continue

            start_time = calendar.timegm(utctime.utctimetuple())

            self._action(par)
            sleep_time = self.calculate_sleep_time(start_time, par.sleep_interval_sec)

            # New start time:
            utctime = datetime.utcnow()
            start_time = calendar.timegm(utctime.utctimetuple())

            if sleep_time > 0:
                print('Sleep time:', sleep_time)
                time.sleep(sleep_time)
            else:
                print('No sleep!')
            sys.stdout.flush()


        return 0


mp = Main()
exit(mp.main())


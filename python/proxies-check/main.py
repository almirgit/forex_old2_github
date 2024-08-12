#!/usr/bin/env python3
import argparse
import os
import sys
import time
import yaml

import sentry_sdk

script_dir = os.path.dirname(__file__)
module_dir = os.path.join(script_dir, '..', 'modules')
sys.path.append(module_dir)
#import mymodule
#mymodule.say_hello()

import write

from forexdb import DB
from proxy_request import ProxyRequest


class Params:
    pass


class Main:

    def __init__(self):
        ##BASE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
        self.BASE_DIR = os.path.dirname(os.path.realpath(__file__))
        self.BASE_DIR = self.BASE_DIR + '/'
        #exec(open(SETTING_FILE).read())

    def _action(self, par):
        par.db.node_registration(par.node_name)
        par.db.transaction_commit()

        pr = ProxyRequest(par)
        pr.get_proxies()
        pr.check_availability()

    def main(self):
        parser = argparse.ArgumentParser()
        parser.add_argument("-c", "--config-file", help="Configuration file", type=str)
        parser.add_argument("-s", "--secret-file", help="Configuration file with secrets", type=str)
        args = parser.parse_args()

        par = Params()

        par.node_name = (os.getenv('CONTAINER_NAME') + '@' + os.getenv('HOST_HOSTNAME'))

        if 'dev' in par.node_name:
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

        # Read configuration file with secrets
        if args.secret_file:
            secret_file = args.secret_file

        try:
            with open(config_file) as fh:
                par.cfg = yaml.load(fh, Loader=yaml.SafeLoader)
            with open(secret_file) as fh:
                par.cfg_secret = yaml.load(fh, Loader=yaml.SafeLoader)

        except IOError:
            sys.stderr.write("ERROR: Cannot open configuration file: {}\n".format(config_file))
            sys.exit(2)

        par.db = DB(par)

        while True:
            try:
                self._action(par)
            except Exception:
                e = sys.exc_info()
                write.err("Exception: {}. Sleeping for 1 minute...".format(e))
                time.sleep(1*60)
                par.db = DB(par) # Not sure what this is

        return 0


mp = Main()
exit(mp.main())


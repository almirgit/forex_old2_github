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
from call_scrapy import CallScrapy


class Params:
    pass


class Main:

    def __init__(self):
        ##BASE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
        self.BASE_DIR = os.path.dirname(os.path.realpath(__file__))
        self.BASE_DIR = self.BASE_DIR + '/'
        #exec(open(SETTING_FILE).read())

    def _action(self, par):
        par.db.node_registration(par.loader_name)
        par.db.transaction_commit()

        cs = CallScrapy()
        res = cs.check_proxy_list_action(par.db)
        #print('What to do: ', res)
        sys.stdout.write('What to do: ' + str(res) + '\n')
        sys.stdout.flush()
        if res == 'Load new proxies!':
            cs.call_scrapy(cwd=self.BASE_DIR)
            

    def main(self):
        parser = argparse.ArgumentParser()
        parser.add_argument("-c", "--config-file", help="Configuration file", type=str)
        parser.add_argument("-s", "--secret-file", help="Configuration file with secrets", type=str)
        args = parser.parse_args()

        par = Params()

        par.loader_name = (os.getenv('CONTAINER_NAME') + '@' + os.getenv('HOST_HOSTNAME'))

        if 'dev' in par.loader_name:
            sentry_project = "https://3e644e1db2f4403e8d9739b662ddc981@sentry.planbventure.de/4",
        else:
            sentry_project = "https://b869eb6a9c804d269196eda3416488f2@sentry.planbventure.de/5",

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
                write.err("Exception: {}. Sleeping for 10 minutes...".format(e))
                par.db = DB(par)
            write.msg('Sleep!')
            time.sleep(10*60)

        return 0


mp = Main()
exit(mp.main())


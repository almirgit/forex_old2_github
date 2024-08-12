import os
import subprocess
import sys

class CallScrapy:
    def check_proxy_list_action(self, db):
        sql = "select fx.check_proxy_list_action()"
        db.cursor.execute(sql)

        fetchone = db.cursor.fetchone()

        db.transaction_commit() # Needed to fetch latest results :-|  ??

        if not fetchone:
            return 'No results'
        return fetchone[0]
    
    def call_scrapy(self, cwd):
        #orig_wd = os.getcwd()
        orig_wd = cwd
        os.chdir(orig_wd + '/../get-proxies-scrapy')
        #scrapy_cmd = '/home/almir/.venv-forex/bin/scrapy'
        result = subprocess.run(["scrapy", "crawl", "proxy_list"], check=True)
        print(result)
        sys.stdout.flush()

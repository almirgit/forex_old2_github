# -*- coding: utf-8 -*-

# Define your item pipelines here
#
# Don't forget to add your pipeline to the ITEM_PIPELINES setting
# See: http://doc.scrapy.org/en/latest/topics/item-pipeline.html

#import time
#import free_proxy_list_net.settings
import psycopg2

from scrapy.exceptions import DropItem
#from scrapy.exporters  import CsvItemExporter

class FreeProxyListNetPipeline(object):
    #def __init__(self, csv_dump_dir, csv_dump_file):
    #    #name = 'proxy-test-output-file.' + time.strftime('%y%m%d') + time.strftime('%H%M%S')
    #    #f = open('{}.csv'.format(name), 'wb')
    #    #f = open(self.settings.CSV_DUMP_DIR + '/' + self.settings.CSV_DUMP_FILE, 'wb')
    #    f = open(csv_dump_dir + '/' + csv_dump_file, 'wb')
    #    #f = open('/tmp/test.csv', 'wb')
    #    self.exporter = CsvItemExporter(f, include_headers_line=False, fields_to_export=['ip_address', 'port'], delimiter=':')
        
    #def __init__(self, db_host, db_name, db_user, db_pass, db_cmt_int, log=None):
    def __init__(self, db_host, db_name, db_user, db_pass, log=None):
        self._db_host = db_host
        self._db_name = db_name
        self._db_user = db_user
        self._db_pass = db_pass
        #self._db_commit_interval = db_cmt_int
        #self._db_commit_counter = 0
        #self.log = log
        #self._snapshot_time = time.strftime('%y%m%d') + time.strftime('%H%M%S')

    @classmethod
    def from_crawler(cls, crawler):
        #return cls(
        #    csv_dump_dir  = crawler.settings.get('CSV_DUMP_DIR'),
        #    csv_dump_file = crawler.settings.get('CSV_DUMP_FILE')
        #)
        return cls(
            db_host=crawler.settings.get('DB_HOST'),
            db_name=crawler.settings.get('DB_NAME'),
            db_user=crawler.settings.get('DB_USER'),
            db_pass=crawler.settings.get('DB_PASS'),
            #log=crawler.log
        )

    def open_spider(self, spider):
        #self.exporter.start_exporting()
        self._connection = psycopg2.connect("dbname='{}' user='{}' host='{}' password='{}'".format(
            self._db_name, 
            self._db_user, 
            self._db_host, 
            self._db_pass))
        self._cursor = self._connection.cursor()

    def close_spider(self, spider):
        #self.exporter.finish_exporting()
        self._cursor.close()
        self._connection.commit()
        self._connection.close()

    def process_item(self, item, spider):
        #print('item:' + str(item))
        if item['anonymity'] != 'elite proxy':
            raise DropItem("Not an elite proxy: %s" % item)
            #return 
        #self.exporter.export_item(item)
        #self._cursor.execute("insert into fx.proxy_list (proxy_ip, proxy_port) values(%s::inet, %s)", (
        self._cursor.execute("select fx.add_proxy(%s, %s, %s, %s, %s)", (
            item.get('ip_address'), 
            item.get('port'),
            item.get('anonymity'),
            # ADD LATER: Source
            'unknown',
            item.get('country'),
            ))
        self._connection.commit()
        return item

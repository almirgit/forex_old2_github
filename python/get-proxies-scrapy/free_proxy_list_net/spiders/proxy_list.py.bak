# -*- coding: utf-8 -*-
import time
import scrapy

from free_proxy_list_net.items import FreeProxyListNetItem

class ProxySpider(scrapy.Spider):

    import sentry_sdk
    sentry_sdk.init(
        #"https://65cf787da5cd4bbb85895d1d49503c15@sentry.kodera.hr/4",
        "https://c360a5e2974e4b6cb220bd4c7cfedbf5@sentry.kodera.hr/5",
        traces_sample_rate=1.0
    )

    name = 'proxy_list'
    allowed_domains = ['free-proxy-list.net']
    start_urls = ['http://free-proxy-list.net/']

    def parse(self, response):
        for row in response.xpath('//table/tbody/tr'):
            columns = row.xpath('td/text()').extract()
            #print(columns)
            len_columns = len(columns)
            if len_columns == 0:
                self.logger.warning('columns list length: {}'.format(len(columns)))
            else:
                item = FreeProxyListNetItem()
                self.logger.debug('columns list length: {}'.format(len(columns)))
                #try:
                if len_columns == 8:
                    item['ip_address'] = columns[0]
                    item['port'] = columns[1]
                    item['country'] = columns[3]
                    item['anonymity'] = columns[4]
                    item['last_checked'] = columns[7]
                elif len_columns == 7: 
                    #self.logger.error('IndexError: list index out of range: {}. Fixing...'.format(columns))
                    #self.logger.debug('IndexError: list index out of range: {}. Fixing...'.format(columns))
                    item['ip_address'] = columns[0]
                    item['port'] = columns[1]
                    item['country'] = columns[3]
                    item['anonymity'] = columns[4]
                    item['last_checked'] = columns[6]
                #except IndexError:

                yield item


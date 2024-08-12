import psycopg2
import sys
import time

class DB:
    def __init__(self, par):
        while True:
            try:
                self._connect_str = "dbname='{}' user='{}' host='{}' password='{}' sslmode=disable".format(
                    par.cfg_secret['DATABASE']['NAME'],
                    par.cfg_secret['DATABASE']['USER'],
                    par.cfg_secret['DATABASE']['HOST'],
                    par.cfg_secret['DATABASE']['PASS'],
                    )
                self.conn = None
                self.cursor = None
                self.open_connection()
                self.open_cursor()
                return
            except Exception:
                e = sys.exc_info()
                sys.stderr.write("Exception: {}. Sleeping for 1 second...\n".format(e))
                sys.stderr.flush()
                time.sleep(1)

    def open_connection(self):
        if not self.conn:
            self.conn = psycopg2.connect(self._connect_str)

    def transaction_commit(self):
        self.conn.commit()

    def open_cursor(self):
        if not self.cursor:
            self.cursor = self.conn.cursor()

    def close_cursor(self):
        if self.cursor:
            self.cursor.close()

    def node_registration(self, loader_name):
        sql = "select fx.node_registration(%s)"
        self.cursor.execute(sql, (loader_name, ))
        self.transaction_commit()

    def get_config(self, config_name, loader_name='default', default_value=None, return_error=None):
        # Get config value:
        try:
            sql = "select value from fx.config where name = %s and loader_id = (select id from fx.config_loader where name = %s)"
            self.cursor.execute(sql, (config_name, loader_name, ))
            fetchone = self.cursor.fetchone()
            self.transaction_commit()
            if not fetchone:
                sys.stdout.write('No config value found: {}; Returning default: {}\n'.format(config_name, default_value))
                sys.stdout.flush()
                if return_error is None:
                    return default_value
                #return ''
            sys.stdout.write('Debug: Fetched from DB: {}\n'.format(fetchone[0]))
            sys.stdout.flush()
            return fetchone[0]
        except:
            sys.stderr.write('Error fetching config: {}, loader name: {}\n'.format(config_name, loader_name))
            sys.stderr.flush()
            return default_value
            



import logging

# Note: TEST module 
def fxlog(msg, log_level='debug'):
    if log_level == 'info':
        logging.info(msg)
    elif log_level == 'debug':
        print(msg)
        logging.debug(msg)
    else:
        logging.debug(msg)

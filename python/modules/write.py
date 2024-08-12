import sys

def msg(message):
    sys.stdout.write(message + '\n')
    sys.stdout.flush()
    
def err(message):
    sys.stderr.write(message + '\n')
    sys.stderr.flush()

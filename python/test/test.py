#!/usr/bin/env python3

import os
import sys

script_dir = os.path.dirname(__file__)
module_dir = os.path.join(script_dir, '..', 'modules')
sys.path.append(module_dir)

from fxlogger import fxlog

fxlog('This is a test!')


# ne radi:
import logging
logging.debug('This is a debug message')

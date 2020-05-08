import sys
import os


sys.path.insert(0, os.path.abspath('..'))


master_doc = 'index'

source_suffix = '.rst'

project = u'Cartridge'

# |release| The full version, including alpha/beta/rc tags.
release = "2.0.1"
# |version| The short X.Y version.
version = '2.0'

exclude_patterns = [
    'conf.py'
]

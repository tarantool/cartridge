import sys
import os

sys.path.insert(0, os.path.abspath('..'))

master_doc = 'index'

source_suffix = '.rst'

project = u'Cartridge'

# |release| The full version, including alpha/beta/rc tags.
release = "2.1.2"
# |version| The short X.Y version.
version = '2.1'

exclude_patterns = [
    'conf.py',
    'images',
    'requirements.txt',
    'locale',
    'topics/*'
]

language = 'en'
locale_dirs = ['./locale']
gettext_compact = False
gettext_location = False

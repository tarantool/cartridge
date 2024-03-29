import sys
import os

sys.path.insert(0, os.path.abspath('.'))

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
    'cartridge_api/modules/cartridge.test-helpers.rst',
    'topics/*'
]

extensions = [
    'TarantoolSessionLexer',
]

language = 'en'
locale_dirs = ['./locale']
gettext_additional_targets = ['literal-block']
gettext_compact = False
gettext_location = True

rst_epilog = """

.. |nbsp| unicode:: 0xA0
   :trim:
   
"""

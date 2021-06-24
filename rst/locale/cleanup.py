#! /usr/bin/env python3
import argparse
from glob import glob
from polib import pofile, POFile, _BaseFile, POEntry

parser = argparse.ArgumentParser(description='Cleanup PO and POT files')
parser.add_argument('extension', type=str, choices=['po', 'pot', 'both'],
                    help='cleanup files with extension: po, pot or both')


class PoFile(POFile):

    def __unicode__(self):
        return _BaseFile.__unicode__(self)

    def metadata_as_entry(self):
        class M:
            def __unicode__(self, _):
                return ''
        return M()


def cleanup_files(extension):
    mask = f'**/*.{extension}'
    for file_path in glob(mask, recursive=True):
        print(f'cleanup {file_path}')
        po_file: POFile = pofile(file_path, klass=PoFile)
        po_file.header = ''
        po_file.metadata = {}
        po_file.metadata_is_fuzzy = False

        for item in po_file:
            # item: POEntry = item
            item.occurrences = None

        po_file.save()


if __name__ == "__main__":

    args = parser.parse_args()

    if args.extension in ['po', 'both']:
        cleanup_files('po')

    if args.extension in ['pot', 'both']:
        cleanup_files('pot')

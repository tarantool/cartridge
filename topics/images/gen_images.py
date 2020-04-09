#!/usr/bin/python

import os
import sys
import codecs

if sys.version_info >= (3, 0):
    from urllib.request import urlopen, Request, HTTPError
    from urllib.parse import quote

    def decode(s):
        return s
else:
    from urllib import quote
    from urllib2 import urlopen, Request, HTTPError

    def decode(b):
        return b.decode('utf-8')

API_BASE = "http://yuml.me/diagram"

scheme_type = 'class'
style = 'plain'
fmt = 'svg'

source_dir = "."
out_dir = "../../doc/images"

def out_filename(source):
    file_name = ("%s.%s") % (source.split('/')[-1].split('.')[0], fmt)
    topic_name = source.split('/')[-2]
    return file_name, topic_name

def build_paths(source):
    objects = os.listdir(source)
    res = []

    for obj in objects:
        path = os.path.join(source, obj)
        if os.path.isdir(path):
            files_in_dir = build_paths(path)
            for file in files_in_dir:
                res.append(file)
        else:
            if path.split('.')[-1] == 'uml':
                res.append(path)

    return res

def create_diagram(source):
    if os.path.exists(source):
        body = decode(open(source, 'r').read())
    else:
        raise IOError("File %s not found" % source)

    diagram_name, topic = out_filename(source)

    out_topic_dir = "%s/%s" % (out_dir, topic)
    if not os.path.exists(out_topic_dir):
        os.makedirs(out_topic_dir)

    out_path = os.path.join(out_topic_dir, diagram_name)
    out = open(out_path, 'wb')

    body = [x.strip() for x in body.splitlines() if x.strip()]
    dsl_text = ', '.join(body).encode('utf-8')

    url = "%s/%s;dir:TB/%s/%s.%s" % (API_BASE, style, scheme_type, quote(dsl_text), fmt)

    try:
        req = Request(url, headers={'User-Agent': 'wandernauta/yuml v0.2'})
        response = urlopen(req).read()

        out.write(response)
    except HTTPError as exception:
        if exception.code == 500:
            sys.exit(1)
        else:
            raise

if __name__ == "__main__":

    files = build_paths(source_dir)

    for file in files:
        create_diagram(file)


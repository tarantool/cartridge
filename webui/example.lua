local http = require('http.server')
box.cfg{}

local httpd = http.new('localhost', 8080)
httpd:start()


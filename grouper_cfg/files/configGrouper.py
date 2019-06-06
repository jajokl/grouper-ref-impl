#!/usr/bin/python


import os
import sys
import cgi
import time

result = ""
result += "\n"
result += "#\n"
result += "# ITAP Grouper Reference Implementation Configuration File\n"
result += "#\n"
result += "# "
result += time.strftime("%Y-%m-%d %H:%M:%S")
result += "\n"
result += "#\n"
result += "\n"

form = cgi.FieldStorage()
for field in form:
    result += "export %s=\"%s\"\n" % (field, form.getvalue(field).strip())

result += "\n"
result += "\n"
print "Content-Type: text/plain; charset=us-ascii"
print "Content-Disposition: attachment; filename=\"grouper_config.dat\""
print "Content-Length: %d" % len(result)
print ""
print result
sys.exit(0)


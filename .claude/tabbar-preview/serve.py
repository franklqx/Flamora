import os, sys
os.chdir('/Users/frankli/Desktop/\u5173\u7fbd\u4e0e\u5415\u5e03/Flamora app/.claude/tabbar-preview')
port = int(os.environ.get('PORT', 7890))
from http.server import HTTPServer, SimpleHTTPRequestHandler
httpd = HTTPServer(('', port), SimpleHTTPRequestHandler)
print(f'Serving on port {port}', flush=True)
httpd.serve_forever()

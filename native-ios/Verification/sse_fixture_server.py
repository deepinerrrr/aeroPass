from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import time, json

class Handler(BaseHTTPRequestHandler):
    protocol_version = 'HTTP/1.1'
    def log_message(self, *args): pass
    def do_GET(self):
        if self.path == '/unauthorized':
            self.send_response(401); self.send_header('Content-Length', '0'); self.end_headers(); return
        self.send_response(200)
        self.send_header('Content-Type', 'text/event-stream')
        self.send_header('Transfer-Encoding', 'chunked')
        self.end_headers()
        content = json.dumps({'choices':[{'delta':{'content':'你好航空✈️，海平面温度15℃。'}}]}, ensure_ascii=False)
        packets = ('data: {"choices":[{"delta":{"reasoning_content":"不应展示的推理"}}]}\r\n\r\n' + 'data: '+ content + '\r\n\r\n' + 'data: [DONE]\r\n\r\n').encode()
        if self.path == '/empty': packets = b'data: [DONE]\n\n'
        if self.path == '/malformed': packets = b'data: {bad json}\n\n'
        if self.path == '/eof': packets = ('data: '+content).encode()
        try:
            # Deliberately split every Chinese character into separate network bytes.
            for byte in packets:
                data = bytes([byte])
                self.wfile.write(b'1\r\n'+data+b'\r\n'); self.wfile.flush()
                if self.path == '/slow': time.sleep(.015)
            self.wfile.write(b'0\r\n\r\n'); self.wfile.flush()
        except (BrokenPipeError, ConnectionResetError): pass

ThreadingHTTPServer(('127.0.0.1', 18764), Handler).serve_forever()

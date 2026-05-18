import http.server
import ssl
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
WEB_ROOT = ROOT / "frontend" / "smart_healthcare" / "build" / "web"
CERT = ROOT / "certs" / "local-cert.pem"
KEY = ROOT / "certs" / "local-key.pem"


class Handler(http.server.SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=str(WEB_ROOT), **kwargs)


server = http.server.ThreadingHTTPServer(("0.0.0.0", 8444), Handler)
context = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
context.load_cert_chain(certfile=str(CERT), keyfile=str(KEY))
server.socket = context.wrap_socket(server.socket, server_side=True)
print("Serving HTTPS frontend at https://0.0.0.0:8444")
server.serve_forever()

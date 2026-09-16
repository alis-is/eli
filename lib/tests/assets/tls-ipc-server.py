import socket
import ssl
import subprocess
import tempfile


with tempfile.TemporaryDirectory() as directory:
    cert = directory + "/cert.pem"
    key = directory + "/key.pem"
    subprocess.run([
        "openssl", "req", "-x509", "-newkey", "rsa:2048", "-nodes",
        "-keyout", key, "-out", cert, "-days", "1", "-subj", "/CN=localhost",
    ], check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    context = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
    context.load_cert_chain(cert, key)
    with socket.socket() as listener:
        listener.bind(("127.0.0.1", 0))
        listener.listen(2)
        listener.settimeout(5)
        print(listener.getsockname()[1], flush=True)
        for _ in range(2):
            with listener.accept()[0] as peer:
                peer.settimeout(5)
                with context.wrap_socket(peer, server_side=True) as tls:
                    tls.sendall(b"ok:" + tls.recv(16))

#!/usr/bin/env python3
"""Servidor de controle da jornada móvel (host). Pausa/recria a API real no Compose e aciona o
dispositivo via adb. Sem segredos: o segredo rotacionado é gerado aqui e nunca impresso.
Escuta só no loopback do host: o emulador Android alcança esse loopback por 10.0.2.2.

Uso: control_server.py --api-dir <coopvote-api> --project <compose -p> --device <adb serial>
     --evidence <dir> [--port 18099] [--bad-port 18081] [--api-port 18080] [--db-port 15432]
"""
import argparse
import os
import secrets
import subprocess
import threading
import time
import urllib.request
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import parse_qs, urlparse

ARGS = argparse.Namespace()
HITS = {"count": 0}
STATE = {"secret": None, "callback": "good"}


def sh(*cmd, env=None):
    merged = dict(os.environ, **(env or {}))
    return subprocess.run(cmd, check=True, capture_output=True, text=True, env=merged).stdout.strip()


def api_container():
    return f"{ARGS.project}-api-1"


def wait_api():
    for _ in range(90):
        try:
            if urllib.request.urlopen(f"http://127.0.0.1:{ARGS.api_port}/actuator/health", timeout=2).status == 200:
                return True
        except Exception:
            pass
        time.sleep(2)
    return False


def recreate(callback, secret):
    STATE["callback"] = callback
    env = {
        "API_PORT": str(ARGS.api_port),
        "DB_PORT": str(ARGS.db_port),
        "AUTH_LOCAL_SEED": "true",
        "CALLBACK_BASE_URL": f"http://10.0.2.2:{ARGS.bad_port if callback == 'bad' else ARGS.api_port}",
    }
    if secret == "rotate":
        STATE["secret"] = secrets.token_urlsafe(48)
    if STATE["secret"]:
        env["AUTH_JWT_SECRET"] = STATE["secret"]
    sh("docker", "compose", "-p", ARGS.project, "up", "-d", "--no-build", "--force-recreate", "api", env=env)
    return "api recriada (callback=%s, secret=%s, healthy=%s)" % (callback, secret, wait_api())


class Control(BaseHTTPRequestHandler):
    def log_message(self, *_):
        pass

    def reply(self, body, code=200):
        data = body.encode()
        self.send_response(code)
        self.send_header("Content-Type", "text/plain; charset=utf-8")
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    def do_GET(self):
        url = urlparse(self.path)
        q = {k: v[0] for k, v in parse_qs(url.query).items()}
        try:
            if url.path == "/api/pause":
                sh("docker", "pause", api_container()); body = "api pausada"
            elif url.path == "/api/unpause":
                sh("docker", "unpause", api_container()); body = "api retomada"
            elif url.path == "/api/recreate":
                body = recreate(q.get("callback", "good"), q.get("secret", "keep"))
            elif url.path == "/api/drop":
                # Queda da API antes de processar o que estava enfileirado (contêiner pausado ou não).
                sh("docker", "rm", "-f", api_container())
                body = "api derrubada; " + recreate(STATE["callback"], "keep")
            elif url.path == "/hits":
                body = str(HITS["count"])
            elif url.path == "/device/home":
                sh("adb", "-s", ARGS.device, "shell", "input", "keyevent", "KEYCODE_HOME"); body = "home"
            elif url.path == "/device/resume":
                sh("adb", "-s", ARGS.device, "shell", "am", "start", "-n", ARGS.activity); body = "resumido"
            elif url.path == "/device/font-scale":
                sh("adb", "-s", ARGS.device, "shell", "settings", "put", "system", "font_scale", q["value"])
                body = "font_scale=" + q["value"]
            elif url.path == "/device/screenshot":
                name = "".join(c for c in q["name"] if c.isalnum() or c in "-_")
                path = os.path.join(ARGS.evidence, f"{name}.png")
                with open(path, "wb") as f:
                    f.write(subprocess.run(["adb", "-s", ARGS.device, "exec-out", "screencap", "-p"],
                                           check=True, capture_output=True).stdout)
                body = os.path.basename(path)
            else:
                return self.reply("rota desconhecida", 404)
            self.reply(body)
        except subprocess.CalledProcessError as err:
            self.reply(f"falha: {err.stderr.strip()[:300]}", 500)


class BadOrigin(BaseHTTPRequestHandler):
    """Qualquer requisição aqui prova que o app enviou algo à origem estranha."""

    def log_message(self, *_):
        pass

    def _hit(self):
        HITS["count"] += 1
        self.send_response(404); self.end_headers()

    do_GET = do_POST = _hit


def main():
    p = argparse.ArgumentParser()
    p.add_argument("--api-dir", required=True)
    p.add_argument("--project", required=True)
    p.add_argument("--device", required=True)
    p.add_argument("--evidence", required=True)
    p.add_argument("--activity", default="com.felipericarte.coopvote/.MainActivity")
    p.add_argument("--bind", default="127.0.0.1")
    p.add_argument("--port", type=int, default=18099)
    p.add_argument("--bad-port", type=int, default=18081)
    p.add_argument("--api-port", type=int, default=18080)
    p.add_argument("--db-port", type=int, default=15432)
    p.parse_args(namespace=ARGS)
    os.chdir(ARGS.api_dir)
    os.makedirs(ARGS.evidence, exist_ok=True)
    # Estado conhecido no início: callbacks na origem certa e o segredo padrão do Compose,
    # para que uma execução anterior interrompida não deixe tokens de outro segredo.
    print(recreate("good", "keep"), flush=True)
    bad = ThreadingHTTPServer((ARGS.bind, ARGS.bad_port), BadOrigin)
    threading.Thread(target=bad.serve_forever, daemon=True).start()
    print(f"controle em :{ARGS.port}, origem estranha em :{ARGS.bad_port}", flush=True)
    ThreadingHTTPServer((ARGS.bind, ARGS.port), Control).serve_forever()


if __name__ == "__main__":
    main()

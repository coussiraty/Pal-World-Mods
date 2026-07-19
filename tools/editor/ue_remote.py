"""
Cliente de Python Remote Execution do Unreal (oficial da Epic, UE 5.1).

Permite executar Python DENTRO do editor que ja esta aberto, a partir daqui.
Nao precisa de plugin de terceiro nem de compilar nada: usa o
remote_execution.py que vem junto com o PythonScriptPlugin da engine.

Uso:
    python ue_remote.py -c "unreal.log('oi')"     # statement solto
    python ue_remote.py arquivo.py                # roda um arquivo inteiro
    python ue_remote.py --ping                    # so descobre o editor

Requer no DefaultEngine.ini do projeto:
    [/Script/PythonScriptPlugin.PythonScriptPluginSettings]
    bRemoteExecution=True
...e o editor REINICIADO depois disso (a porta so abre no boot).
"""

import sys
import time
import os

ENGINE_PY = (r"C:\Program Files\Epic Games\UE_5.1\Engine\Plugins"
             r"\Experimental\PythonScriptPlugin\Content\Python")
if ENGINE_PY not in sys.path:
    sys.path.append(ENGINE_PY)

try:
    import remote_execution as remote
except ImportError:
    print("ERRO: nao achei remote_execution.py em:\n  " + ENGINE_PY)
    sys.exit(2)

DISCOVERY_TIMEOUT = 8.0     # segundos esperando o editor anunciar


def connect():
    """Descobre o editor no multicast e abre o canal de comando."""
    cfg = remote.RemoteExecutionConfig()
    cfg.multicast_group_endpoint = ("239.0.0.1", 6766)
    cfg.multicast_bind_address = "127.0.0.1"
    cfg.multicast_ttl = 0

    r = remote.RemoteExecution(cfg)
    r.start()

    deadline = time.time() + DISCOVERY_TIMEOUT
    while time.time() < deadline:
        if r.remote_nodes:
            break
        time.sleep(0.25)

    if not r.remote_nodes:
        r.stop()
        print("ERRO: nenhum editor respondeu em %.0fs." % DISCOVERY_TIMEOUT)
        print("Checar: (1) o editor esta aberto?  (2) bRemoteExecution=True no")
        print("DefaultEngine.ini?  (3) o editor foi REINICIADO depois disso?")
        return None

    node = r.remote_nodes[0]
    node_id = node["node_id"] if isinstance(node, dict) else node.node_id
    r.open_command_connection(node)
    print("conectado ao editor: %s" % node_id)
    return r


def run(r, command, mode):
    """Executa e imprime a saida do editor de volta aqui."""
    res = r.run_command(command, unattended=True, exec_mode=mode, raise_on_failure=False)
    for entry in res.get("output") or []:
        print("  [%s] %s" % (entry.get("type", "Log"), entry.get("output", "").rstrip()))
    if not res.get("success", False):
        print("  !! FALHOU: %s" % res.get("result"))
        return False
    if res.get("result") not in (None, "None", ""):
        print("  -> %s" % res.get("result"))
    return True


def main():
    args = sys.argv[1:]
    if not args:
        print(__doc__)
        return 1

    r = connect()
    if r is None:
        return 1
    try:
        if args[0] == "--ping":
            return 0 if run(r, "unreal.log('[remote] pong')",
                            remote.MODE_EXEC_STATEMENT) else 1
        if args[0] == "-c":
            return 0 if run(r, " ".join(args[1:]),
                            remote.MODE_EXEC_STATEMENT) else 1
        path = os.path.abspath(args[0])
        if not os.path.isfile(path):
            print("ERRO: arquivo nao existe: " + path)
            return 1
        print("executando arquivo: " + path)
        return 0 if run(r, path, remote.MODE_EXEC_FILE) else 1
    finally:
        r.stop()


if __name__ == "__main__":
    sys.exit(main())

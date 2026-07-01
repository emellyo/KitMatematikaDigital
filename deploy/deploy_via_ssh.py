import os
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / ".deploydeps"))

import paramiko


def require_env(name: str) -> str:
    value = os.environ.get(name)
    if not value:
        raise SystemExit(f"Missing environment variable: {name}")
    return value


def run(client: paramiko.SSHClient, command: str, password: str | None = None) -> None:
    stdin, stdout, stderr = client.exec_command(command, get_pty=bool(password))
    if password:
        stdin.write(password + "\n")
        stdin.flush()

    out = stdout.read().decode("utf-8", errors="replace")
    err = stderr.read().decode("utf-8", errors="replace")
    code = stdout.channel.recv_exit_status()

    if out.strip():
        print(out)
    if err.strip():
        print(err, file=sys.stderr)
    if code != 0:
        raise SystemExit(f"Command failed ({code}): {command}")


def main() -> None:
    host = require_env("DEPLOY_HOST")
    username = require_env("DEPLOY_USER")
    password = require_env("DEPLOY_PASSWORD")
    domain = os.environ.get("DEPLOY_DOMAIN", host)

    root = Path(__file__).resolve().parents[1]
    archive = root / "publish" / "kitmatematika.tar.gz"
    installer = root / "deploy" / "install-ubuntu24.sh"

    if not archive.exists():
        raise SystemExit(f"Missing archive: {archive}")
    if not installer.exists():
        raise SystemExit(f"Missing installer: {installer}")

    client = paramiko.SSHClient()
    client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    print(f"Connecting to {username}@{host}...")
    client.connect(
        hostname=host,
        username=username,
        password=password,
        look_for_keys=False,
        allow_agent=False,
        timeout=30,
    )

    try:
        print("Uploading application archive...")
        with client.open_sftp() as sftp:
            sftp.put(str(archive), "/tmp/kitmatematika.tar.gz")
            sftp.put(str(installer), "/tmp/install-ubuntu24.sh")

        print("Running installer on server...")
        run(client, "chmod +x /tmp/install-ubuntu24.sh", None)
        run(client, f"sudo -S /tmp/install-ubuntu24.sh {domain}", password)

        print("Checking service and HTTP endpoint...")
        run(client, "systemctl is-active kitmatematika", None)
        run(client, "curl -I --max-time 10 http://127.0.0.1:5000", None)
    finally:
        client.close()


if __name__ == "__main__":
    main()

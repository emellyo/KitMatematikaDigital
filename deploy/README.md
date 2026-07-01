# Deployment

Target server: Ubuntu 24.04 with Nginx and systemd.

Local publish command:

```powershell
dotnet publish .\KitMatematikaDigital.csproj -c Release -r linux-x64 --self-contained true -o .\publish\linux-x64
tar -czf .\publish\kitmatematika.tar.gz -C .\publish\linux-x64 .
```

Upload and install:

```powershell
scp .\publish\kitmatematika.tar.gz root@SERVER_IP:/tmp/kitmatematika.tar.gz
scp .\deploy\install-ubuntu24.sh root@SERVER_IP:/tmp/install-ubuntu24.sh
ssh root@SERVER_IP "chmod +x /tmp/install-ubuntu24.sh && sudo /tmp/install-ubuntu24.sh DOMAIN_OR_IP"
```

Service checks:

```bash
systemctl status kitmatematika --no-pager
journalctl -u kitmatematika -f
curl -I http://127.0.0.1:5000
```

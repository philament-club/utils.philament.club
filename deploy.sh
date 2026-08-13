#!/usr/bin/env bash
# utils.philament.club sur cmos : nginx + fcgiwrap en conteneur, derrière le kamal-proxy
# partagé (voir janroudaut/hetzner-server, docs/http-tls.md).
#   ./deploy.sh          → route en HTTP seul (avant bascule DNS)
#   TLS=1 ./deploy.sh    → + Let's Encrypt (le DNS doit DÉJÀ pointer sur le serveur,
#                          l'ACME est en HTTP-01 et échoue sinon)
set -euo pipefail

SERVER="${SERVER:-root@philament.club}"
REMOTE=/opt/utils-web
SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/"

ssh "$SERVER" "mkdir -p $REMOTE"
rsync -az --delete --exclude '.git' "$SRC" "$SERVER:$REMOTE/"

tls_flag=""
[[ "${TLS:-0}" == 1 ]] && tls_flag="--tls"

ssh "$SERVER" bash -s <<EOF
set -euo pipefail
docker build -q -t utils-web:latest -f $REMOTE/deploy/Dockerfile $REMOTE

# Réseau à part, --internal : depuis le bridge « kamal » un shell obtenu ici verrait
# alta-db, l'app de prod, le SSH de l'hôte et un Postfix qui relaie vers le monde entier
# (mynetworks couvre 172.18.0.0/16). Ici il ne voit rien, pas même l'internet sortant.
# ⚠️ kamal-proxy y est rattaché à la main : un déploiement Kamal qui le recrée perd
# l'attachement et utils tombe en 502 — relancer ce script. Même piège que la route
# « philament » (hetzner-server, docs/http-tls.md).
docker network inspect utils >/dev/null 2>&1 || docker network create --internal utils
docker network connect utils kamal-proxy 2>/dev/null || true

docker rm -f utils-web >/dev/null 2>&1 || true
# Du shell CGI ouvert au monde : sans privilège ni capability, rootfs en lecture seule,
# /tmp en tmpfs pour seul espace inscriptible et non exécutable. Les plafonds bornent ce
# qu'une rafale distribuée — que le limit_req par IP ne voit pas — peut voler à la prod.
docker run -d --name utils-web --restart unless-stopped --network utils \\
  --read-only --tmpfs /tmp:rw,nosuid,nodev,noexec,size=16m \\
  --cap-drop ALL --security-opt no-new-privileges \\
  --pids-limit 128 --memory 256m --memory-swap 256m --cpus 0.5 \\
  --log-opt max-size=10m --log-opt max-file=3 \\
  utils-web:latest

# --health-check-path / : le défaut de kamal-proxy est /up, que nginx renvoie en 404,
# ce qui ferait échouer le déploiement.
docker exec kamal-proxy kamal-proxy deploy utils \\
  --target utils-web:8080 \\
  --host utils.philament.club \\
  --health-check-path / $tls_flag

docker exec kamal-proxy kamal-proxy list
EOF

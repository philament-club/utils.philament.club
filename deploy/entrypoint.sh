#!/bin/sh
set -eu

# -p attend un chemin exact, pas un préfixe de dossier : la liste blanche se construit
# script par script. Elle neutralise un SCRIPT_FILENAME fabriqué si la conf nginx venait
# à se relâcher. Les _*.sh sont des includes sourcés, jamais des points d'entrée.
set --
for w in /var/www/utils/wrappers/*; do
    case "${w##*/}" in _*) continue ;; esac
    [ -x "$w" ] && set -- "$@" -p "$w"
done

# fcgiwrap n'a pas de gestionnaire de processus : il ouvre lui-même sa socket et meurt
# avec le conteneur.
fcgiwrap -f -c 4 "$@" -s unix:/tmp/fcgiwrap.sock &

# nginx se connecte à la socket à la première requête : sans cette attente, un client
# arrivé dans la milliseconde du démarrage prendrait un 502.
i=0
while [ ! -S /tmp/fcgiwrap.sock ] && [ $i -lt 50 ]; do i=$((i + 1)); sleep 0.1; done

exec nginx -g 'daemon off;'

FROM debian:trixie-slim

# nginx-light n'est qu'un méta-paquet : depuis bookworm tout Debian partage le même binaire,
# realip et limit_req compris. fortunes-off et fortunes-spam ont quitté main, elles sautent.
RUN apt-get update && apt-get install -y --no-install-recommends \
      nginx fcgiwrap fortune-mod fortunes fortune-anarchism pwgen rig \
 && rm -rf /var/lib/apt/lists/*

COPY index.html /var/www/utils/
COPY wrappers/ /var/www/utils/wrappers/
COPY deploy/nginx.conf /etc/nginx/nginx.conf
COPY deploy/entrypoint.sh /usr/local/bin/entrypoint

RUN chmod 0755 /usr/local/bin/entrypoint /var/www/utils/wrappers/*

USER www-data
EXPOSE 8080
ENTRYPOINT ["/usr/local/bin/entrypoint"]

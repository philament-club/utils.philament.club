# "misc utils & random unix command wrappers"

Old school but nonetheless still functional Web 1.0, CGI-style "utils" relying on good ol' Unix tools.

Live at **<https://utils.philament.club>**.

## Deployment

Runs on `cmos` as a container — nginx + `fcgiwrap`, behind the shared `kamal-proxy`
(see [`janroudaut/hetzner-server`](https://github.com/janroudaut/hetzner-server),
`docs/http-tls.md`).

```sh
./deploy.sh          # HTTP only
TLS=1 ./deploy.sh    # + Let's Encrypt, once utils.philament.club points at the server
```

| Path | What |
|---|---|
| `index.html` | the page |
| `wrappers/` | the CGI scripts, served under `/u/` |
| `deploy/` | image, nginx config, entrypoint |
| `deploy.sh` | rsync + build + run + route, from your laptop |

Adding a util: drop an executable `wrappers/<name>` sourcing `_200-headers.sh`, list it in
`index.html`, redeploy. **Whatever it prints, the world reads** — no shell interpolation of
`QUERY_STRING`, ever.

The container is unprivileged, read-only and capability-less, capped at 256 MB / 0.5 CPU /
128 PIDs, `/u/` is rate limited to 2 req/s per IP, and `fcgiwrap` only executes what is
listed under `wrappers/`. It sits on its own `--internal` docker network: from there,
nothing on the host is reachable — no database, no SMTP, not even the outbound internet.
`kamal-proxy` is attached to that network by `deploy.sh`; **if the proxy is ever recreated,
run `deploy.sh` again** or the site 502s.

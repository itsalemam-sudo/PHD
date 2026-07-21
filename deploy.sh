#!/usr/bin/env bash
# Deploy the PHD Software static site to this VPS.
#
# Usage (as root):
#   curl -fsSL https://raw.githubusercontent.com/itsalemam-sudo/PHD/claude/high-tech-company-website-dnjn5t/deploy.sh | bash
#
# Safe to re-run. Only touches phdsowftware.com's server block and docroot;
# leaves other nginx sites (ember, marmaragold, etc.) untouched.

set -euo pipefail

DOMAIN="phdsowftware.com"
REPO_URL="https://github.com/itsalemam-sudo/PHD.git"
BRANCH="claude/high-tech-company-website-dnjn5t"
EMAIL="hello@${DOMAIN}"
DOCROOT="/var/www/${DOMAIN}"

log() { printf "\n\033[1;36m==>\033[0m %s\n" "$*"; }
warn() { printf "\n\033[1;33m!!\033[0m  %s\n" "$*" >&2; }
die() { printf "\n\033[1;31mxx\033[0m  %s\n" "$*" >&2; exit 1; }

[[ $EUID -eq 0 ]] || die "Run as root (sudo bash deploy.sh)."

# Clean up an older, misnamed deploy (missing 'w') if we made one earlier.
OLD_DOMAIN="phdsoftware.com"
if [[ -e "/etc/nginx/sites-enabled/${OLD_DOMAIN}" || -e "/etc/nginx/sites-available/${OLD_DOMAIN}" || -d "/var/www/${OLD_DOMAIN}" ]]; then
  log "Removing stale ${OLD_DOMAIN} config from earlier attempt"
  rm -f "/etc/nginx/sites-enabled/${OLD_DOMAIN}" "/etc/nginx/sites-available/${OLD_DOMAIN}"
  rm -rf "/var/www/${OLD_DOMAIN}"
fi

log "Installing prerequisites"
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get install -y -qq nginx certbot python3-certbot-nginx git ca-certificates >/dev/null

log "Fetching site files from ${BRANCH}"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
git clone --quiet --depth 1 --branch "$BRANCH" "$REPO_URL" "$TMP"

for f in index.html styles.css app.js; do
  [[ -f "$TMP/$f" ]] || die "$f missing from repo — branch may be wrong"
done

mkdir -p "$DOCROOT"
install -m 0644 -o www-data -g www-data \
  "$TMP/index.html" "$TMP/styles.css" "$TMP/app.js" "$DOCROOT/"

log "Writing nginx server block for ${DOMAIN}"
CONF="/etc/nginx/sites-available/${DOMAIN}"
cat > "$CONF" <<NGINX_CONF
server {
    listen 80;
    listen [::]:80;
    server_name ${DOMAIN} www.${DOMAIN};

    root ${DOCROOT};
    index index.html;

    location / {
        try_files \$uri \$uri/ =404;
    }

    location = /favicon.ico { access_log off; log_not_found off; }
    location ~ /\.(?!well-known) { deny all; }
}
NGINX_CONF

ln -sf "$CONF" "/etc/nginx/sites-enabled/${DOMAIN}"
nginx -t
systemctl reload nginx
log "nginx reloaded"

log "Checking DNS before requesting certificate"
VPS_IP="$(curl -fsS https://api.ipify.org || true)"
DNS_IP="$(dig +short "$DOMAIN" @1.1.1.1 | tail -n1)"
DNS_WWW_IP="$(dig +short "www.${DOMAIN}" @1.1.1.1 | tail -n1)"

echo "  VPS public IP     : ${VPS_IP:-unknown}"
echo "  ${DOMAIN} A record : ${DNS_IP:-none}"
echo "  www.${DOMAIN} A rec: ${DNS_WWW_IP:-none}"

if [[ -z "$VPS_IP" || -z "$DNS_IP" || "$DNS_IP" != "$VPS_IP" || "$DNS_WWW_IP" != "$VPS_IP" ]]; then
  warn "DNS is not (yet) pointing both apex and www at this VPS."
  warn "Site is now served over HTTP once DNS updates."
  warn "After DNS shows the VPS IP, request the cert with:"
  echo
  echo "  certbot --nginx -d ${DOMAIN} -d www.${DOMAIN} \\"
  echo "    --non-interactive --agree-tos -m ${EMAIL} --redirect"
  echo
  exit 0
fi

log "Requesting Let's Encrypt certificate"
certbot --nginx -d "${DOMAIN}" -d "www.${DOMAIN}" \
  --non-interactive --agree-tos -m "${EMAIL}" --redirect --keep-until-expiring

log "Done. https://${DOMAIN}/ is live."

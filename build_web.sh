#!/usr/bin/env bash
#
# Build the customer app for the web and package it for the server.
#
#   ./build_web.sh                        # uses the sslip hosts below
#   API_BASE_URL=https://api.example.com/api ./build_web.sh
#   VENDOR_APP_URL=https://vendor.example.com ./build_web.sh
#
# Produces build/web/ and homeservice-web.tar.gz next to it. Upload steps are
# printed at the end; see home_service_backend/deploy/README.md.

set -euo pipefail

# The API address is COMPILED IN. A web build points at whatever host was given
# here, for ever -- there is no runtime setting to change afterwards. Pointing
# a production build at a laptop is the classic way to ship a site that works
# on the machine that built it and nowhere else.
API_BASE_URL="${API_BASE_URL:-https://13-200-180-192.sslip.io/api}"

# Where the "Become a vendor" row in Profile sends people. Compiled in for the
# same reason as the API address, and separate from it because the two are not
# the same host and need not stay on the same domain.
VENDOR_APP_URL="${VENDOR_APP_URL:-https://vendor.13-200-180-192.sslip.io}"

cd "$(dirname "$0")"

case "$API_BASE_URL" in
    https://*) ;;
    *)
        echo "Refusing to build: API_BASE_URL is not https." >&2
        echo "  got: $API_BASE_URL" >&2
        echo "A page served over https cannot call a plain-http API -- browsers" >&2
        echo "block it as mixed content, and the app loads then does nothing." >&2
        exit 1
        ;;
esac

echo "==> Building against $API_BASE_URL"
echo "==> Vendor site: $VENDOR_APP_URL"
flutter build web --release \
    --dart-define=API_BASE_URL="$API_BASE_URL" \
    --dart-define=VENDOR_APP_URL="$VENDOR_APP_URL"

# Flutter copies web/ into build/web/ but SKIPS dotfiles, so .htaccess never
# arrives on its own. Only Apache hosts (Hostinger, cPanel) read it; nginx
# ignores it harmlessly, so it is always included rather than made conditional.
if [ -f web/.htaccess ]; then
    cp web/.htaccess build/web/.htaccess
    echo "==> Copied .htaccess (Flutter does not)"
fi

echo "==> Packaging"
rm -f homeservice-web.tar.gz
# The leading "." includes dotfiles; a glob would drop .htaccess again.
tar -czf homeservice-web.tar.gz -C build/web .

SIZE=$(du -h homeservice-web.tar.gz | cut -f1)
echo ""
echo "==> Built: homeservice-web.tar.gz ($SIZE)"
echo ""
echo "Upload and install it with:"
echo ""
echo "  scp -i C:/keys/homeservice-key.pem homeservice-web.tar.gz ubuntu@13.200.180.192:/tmp/"
echo ""
echo "  ssh -i C:/keys/homeservice-key.pem ubuntu@13.200.180.192"
echo "  sudo mkdir -p /srv/homeservice-web"
echo "  sudo tar -xzf /tmp/homeservice-web.tar.gz -C /srv/homeservice-web"
echo "  sudo chown -R www-data:www-data /srv/homeservice-web"
echo "  rm /tmp/homeservice-web.tar.gz"
echo ""

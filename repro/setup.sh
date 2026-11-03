#!/usr/bin/env bash
# Builds a disposable WordPress + Kit (formerly ConvertKit) 3.4.9 lab and runs the PoC.
# Requires docker and curl. Everything binds to 127.0.0.1 only.
set -eu
P=ck349
PORT=8093
B="http://127.0.0.1:$PORT"
cd "$(dirname "$0")"

mkdir -p zips
[ -f zips/3.4.9.zip ] || curl -4 -sL "https://downloads.wordpress.org/plugin/convertkit.3.4.9.zip" -o zips/3.4.9.zip

docker compose -p $P up -d
echo "waiting for the database..."
for i in $(seq 1 60); do
  docker compose -p $P exec -T db mariadb -uwp -pwppw -e "select 1" wp >/dev/null 2>&1 && break
  sleep 2
done

WP="docker compose -p $P exec -T cli wp"
$WP core install --url="$B" --title="Paywall Test" --admin_user=admin \
    --admin_password=Adm1n-pass-9931 --admin_email=admin@test.local --skip-email
$WP plugin install /zips/3.4.9.zip --activate
$WP plugin list --fields=name,status,version | grep -i convertkit

# Put the plugin in the normal API-connected state. Without both tokens the paywall
# never engages, because can_view_post() returns true immediately.
$WP option update _wp_convertkit_settings --format=json \
  '{"access_token":"dummy-access-token-for-lab","refresh_token":"dummy-refresh-token-for-lab","token_expires":9999999999}'
$WP option update convertkit_products --format=json \
  '{"1":{"id":1,"name":"Paid Newsletter","url":"https://example.com/p/paid","published":true}}'

BODY="SECRET-TOKEN-7731 This is the opening of the paid article that only paying members are supposed to read. It continues with a long run of subscriber only analysis so that the default fifty five word excerpt cannot possibly cover the whole thing, which lets us tell the difference between a truncated excerpt and the complete body. We keep adding sentences here purely so the article is comfortably longer than the default excerpt window that WordPress applies when no manual excerpt exists on the post. END-OF-PAID-BODY"
PID=$($WP post create --post_type=post --post_status=publish \
      --post_title="Members only briefing" --post_content="$BODY" --porcelain)
$WP post meta update "$PID" _wp_convertkit_post_meta --format=json \
  '{"restrict_content":"product_1","form":"0","landing_page":"","tag":""}'

echo
echo "lab ready. restricted post id = $PID at $B"
echo "$PID" > post_id.txt
echo "now run: ./run_poc.sh"

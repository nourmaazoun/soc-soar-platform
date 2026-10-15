#!/bin/bash
# =============================================================================
#  Snort -> Shuffle watcher
#  Lit les alertes Snort et transmet les alertes importantes au webhook Shuffle,
#  qui déclenche la réponse automatique (blocage pfSense + alerte TheHive).
#
#  Configuration : définir l'adresse du webhook Shuffle avant le lancement
#    export SHUFFLE_WEBHOOK_URL="http://<IP_SHUFFLE>:3001/api/v1/hooks/<WEBHOOK_ID>"
# =============================================================================
set -u

ALERT_FILE="/var/log/snort/alert"
HOOK_URL="${SHUFFLE_WEBHOOK_URL:?Définir SHUFFLE_WEBHOOK_URL}"
STATE_DIR="/var/lib/snort-shuffle"
LOG_FILE="/var/log/snort/snort-shuffle-watcher.log"
DEDUPE_SECONDS=60

mkdir -p "$STATE_DIR"
touch "$LOG_FILE"

# Alertes qui déclenchent une réponse automatique
is_soc_alert() {
  case "$1" in
    *"Nmap SYN scan detected"*|*"TCP SYN port scan detected"*|\
    *"Telnet brute force detected"*|*"SSH brute force detected"*|*"FTP brute force detected"*|\
    *"ICMP ping flood detected"*|*"ICMP ping detected"*|*"PING vers Metasploitable detecte"*|\
    *"HTTP flood detected"*|*"SQL injection"*|*"SQLmap scan detected"*|\
    *"Web XSS attempt detected"*|*"Command injection attempt detected"*) return 0 ;;
    *) return 1 ;;
  esac
}

extract_msg() {
  printf '%s\n' "$1" | sed -n 's/.*\[\*\*\] \(.*\) \[\*\*\].*/\1/p'
}

extract_src() {
  local line="$1" src
  src="$(printf '%s\n' "$line" | sed -n 's/.*{[A-Z]*} \([0-9][0-9.]*\):[0-9][0-9]* -> .*/\1/p')"
  [ -n "$src" ] || src="$(printf '%s\n' "$line" | sed -n 's/.*{[A-Z]*} \([0-9][0-9.]*\) -> .*/\1/p')"
  printf '%s' "$src"
}

tail -n 0 -F "$ALERT_FILE" | while IFS= read -r line; do
  is_soc_alert "$line" || continue

  sid="$(printf '%s\n' "$line" | sed -n 's/.*\[1:\([0-9][0-9]*\):[0-9][0-9]*\].*/\1/p')"
  src="$(extract_src "$line")"

  # Machines du laboratoire à ne jamais bloquer
  case "$src" in
    10.1.2.1|10.1.2.100|10.1.2.101|10.1.2.102|10.1.2.105|10.1.1.1|10.1.1.150|192.168.1.103|192.168.233.135|192.168.1.33)
      printf '%s ignored infrastructure src=%s\n' "$(date -Is)" "$src" >> "$LOG_FILE"
      continue ;;
  esac

  msg="$(extract_msg "$line" | sed 's/^\[1:[0-9][0-9]*:[0-9][0-9]*\] *//')"
  [ -n "$msg" ] || msg="selected_snort_alert"

  if [ -z "$sid" ] || [ -z "$src" ]; then
    printf '%s parse_failed line=%s\n' "$(date -Is)" "$line" >> "$LOG_FILE"
    continue
  fi

  # Une seule alerte par attaquant et par minute
  key="$STATE_DIR/last_${src}"
  now="$(date +%s)"
  last=0
  [ -f "$key" ] && last="$(cat "$key" 2>/dev/null || echo 0)"
  if [ $((now - last)) -lt "$DEDUPE_SECONDS" ]; then
    printf '%s dedupe sid=%s src=%s msg=%s\n' "$(date -Is)" "$sid" "$src" "$msg" >> "$LOG_FILE"
    continue
  fi
  echo "$now" > "$key"

  # Message envoyé à Shuffle
  payload="$(python3 -c 'import json,sys; print(json.dumps({"attacker_ip": sys.argv[1], "sid": sys.argv[2], "alert": sys.argv[3], "blocked_ips": [sys.argv[1]], "event_id": sys.argv[1] + "-" + sys.argv[2] + "-" + sys.argv[4]}))' "$src" "$sid" "$msg" "$now")"

  response="$(curl -sS -m 15 -X POST "$HOOK_URL" -H 'Content-Type: application/json' -d "$payload" 2>&1)"
  rc=$?
  printf '%s sent sid=%s src=%s msg=%s rc=%s response=%s\n' "$(date -Is)" "$sid" "$src" "$msg" "$rc" "$response" >> "$LOG_FILE"
done

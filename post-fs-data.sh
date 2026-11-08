#!/system/bin/sh
#
# Personal module - mutes the ongoing notification channels of the
# device-admin / device-owner app on my own phones, so the status bar
# isn't permanently taken up. Runs before SystemUI so the setting is
# already in place when NotificationManager reads it.

MODDIR=${0%/*}
POLICY=/data/system/notification_policy.xml
DP=/data/system/device_policies.xml

i=0
while [ ! -f "$POLICY" ] && [ $i -lt 30 ]; do sleep 1; i=$((i+1)); done
[ -f "$POLICY" ] || exit 0

[ -f "$MODDIR/notification_policy.orig.xml" ] || cp "$POLICY" "$MODDIR/notification_policy.orig.xml" 2>/dev/null

TARGETS=""
if [ -f "$DP" ]; then
  TARGETS="$TARGETS $(grep -oE 'name="[A-Za-z0-9._]+/' "$DP" 2>/dev/null | sed -e 's/name="//' -e 's|/$||')"
  TARGETS="$TARGETS $(grep -oE 'package="[A-Za-z0-9._]+"' "$DP" 2>/dev/null | sed -e 's/package="//' -e 's/"$//')"
fi
if [ -f "$MODDIR/targets.txt" ]; then
  TARGETS="$TARGETS $(grep -vE '^[[:space:]]*#' "$MODDIR/targets.txt" 2>/dev/null | grep -oE '[A-Za-z0-9._]+\.[A-Za-z0-9._]+')"
fi
TARGETS=$(echo "$TARGETS" | tr ' ' '\n' | grep -E '\.' | sort -u | tr '\n' ' ')
[ -z "$(echo $TARGETS)" ] && exit 0

NORM="$MODDIR/.np_norm"
OUT="$MODDIR/.np_out"
sed 's/>[[:space:]]*</>\n</g' "$POLICY" > "$NORM" 2>/dev/null

awk -v targets="$TARGETS" '
BEGIN { n=split(targets,a," "); for(k=1;k<=n;k++) t[a[k]]=1; inside=0 }
{
  line=$0
  if (line ~ /<package[ \t]+name="/) {
    s=line; sub(/^.*<package[ \t]+name="/,"",s); sub(/".*/,"",s)
    inside = (s in t) ? 1 : 0
  }
  if (inside && line ~ /<channel[ \t]/) {
    gsub(/importance="[0-9]+"/,"importance=\"0\"",line)
    if (line ~ /locked="[0-9]+"/) gsub(/locked="[0-9]+"/,"locked=\"4\"",line)
    else sub(/\/>[ \t\r]*$/,"locked=\"4\" />",line)
  }
  if (line ~ /<\/package>/) inside=0
  print line
}
' "$NORM" > "$OUT" 2>/dev/null

OBYTES=$(wc -c < "$POLICY" 2>/dev/null)
NBYTES=$(wc -c < "$OUT" 2>/dev/null)
if [ -s "$OUT" ] && grep -q "channel\|package\|notification" "$OUT" && [ "${NBYTES:-0}" -ge $(( ${OBYTES:-0} / 2 )) ]; then
  cat "$OUT" > "$POLICY"
fi
rm -f "$NORM" "$OUT"
exit 0

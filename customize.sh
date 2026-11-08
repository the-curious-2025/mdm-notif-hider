#!/sbin/sh

ui_print "- MDM Notification Hider"
ui_print "- Mutes device-admin / device-owner notification channels"
ui_print "- Add extra packages in targets.txt if needed"
ui_print "- Reboot once or twice for it to settle"

set_perm_recursive "$MODPATH" 0 0 0755 0644
set_perm "$MODPATH/post-fs-data.sh" 0 0 0755

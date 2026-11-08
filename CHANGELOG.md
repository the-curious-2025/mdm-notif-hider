# Changelog

## v1.0
- First version. On each boot (post-fs-data, before SystemUI) it sets the
  notification channels of device-admin / device-owner apps to importance 0
  and marks them user-locked in notification_policy.xml, so the management
  app's permanent notification stops showing. Auto-detects admins/owner,
  plus targets.txt for anything that isn't a device admin.
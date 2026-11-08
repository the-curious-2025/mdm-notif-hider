# MDM Notification Hider

Personal Magisk module I use on my own phones.

Some of my devices run a management app (device admin / device owner) that
keeps a notification pinned in the status bar permanently. You can't swipe it
away, and turning notifications off for the app in Settings doesn't help
because it's a foreground-service notification. This module mutes those
channels so the thing goes away. The app keeps running and doing its job - I
just stop seeing the notification.

## How it works

Every app's notification-channel settings live in
`/data/system/notification_policy.xml`. On each boot, before SystemUI starts,
the module sets the channels of the management app to importance 0 and marks
them user-locked, so the app can't flip them back. Same thing you'd do by hand
in Settings, just automatic and sticky. Because it runs in `post-fs-data`
(before NotificationManager reads the file) there's no flicker and nothing
clobbers it at runtime.

It picks the apps to mute by reading who's registered as a device admin /
device owner in `device_policies.xml` - that's the management app on all of my
phones. If one is a plain app that isn't a device admin, add its package name
to `targets.txt`.

## Install

1. Build the zip: zip up `module.prop`, `post-fs-data.sh`, `customize.sh` and
   `targets.txt` at the root (or grab it from Releases).
2. Magisk app -> Modules -> Install from storage -> pick the zip.
3. Reboot. Give it one or two reboots to settle (a brand-new channel only gets
   caught from the next boot, since it isn't in the file yet the first time).

Needs root (Magisk). Tested on Android 11 (MTK / AOSP-based, e.g. Qin F21).

## Undo

Remove the module in Magisk and reboot. The channels stay muted after that
(the setting lives in Android, not in the module), so to actually get the
notification back, re-enable it in Settings -> Apps -> (the app) ->
Notifications. The first run also saves a copy of the original
`notification_policy.xml` into the module folder.

## Note

This only hides the notification. It does not disable or change what the
management app does - it keeps working exactly as before. It's just a
status-bar cleanup on my own devices.

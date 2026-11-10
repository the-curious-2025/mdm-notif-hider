# Changelog

## Unreleased
- Add `systemui-qs-footer/`: documents and provides the smali patches for the
  on-screen "managed device" indicators that the notification script cannot
  reach, because SystemUI draws them itself rather than posting them as app
  notifications:
  - the Quick Settings "device belongs to your organization" disclosure footer
    (`QSSecurityFooter`), and
  - the VPN key icon in the status bar (`StatusBarSignalPolicy`).
  Both are small, cosmetic, ROM-specific patches, built and deployed as one
  Magisk overlay module. The management apps and the VPN keep running.
  Built and tested on the Qin F21 Pro; the indicators are standard AOSP, so the
  patches are not tied to any particular MDM.
- `systemui-qs-footer/README.md`: note that the prebuilt module is Qin F21 Pro
  only, and add a porting guide for other devices, including the signing-key
  prerequisite that decides whether the method is possible at all.
- README: add a section pointing to the above, with the device-scope note.

## v1.1
- Fix the write-guard: it used `grep -q 'a\|b\|c'`, which toybox grep (on some
  ROMs) treats as a literal string, so the edit was silently skipped and nothing
  got muted. Now uses `grep -qE`.
- Freeze `notification_policy.xml` with `chattr +i` right after writing, and
  unfreeze it at the start of the next boot before rewriting. This stops the
  live NotificationManager from re-persisting the un-muted channels during a
  session. Note: once a channel carries importance 0 + user-locked, it is
  self-sustaining across reboots anyway, so the freeze is belt-and-suspenders.
- Known limit: some management apps create extra channels at runtime (e.g. an
  "app store" / "app updates" foreground service) and clear the user-lock when
  they do. Those can't be held via notification_policy.xml; they usually post
  transiently and self-dismiss.

## v1.0
- First version. On each boot (post-fs-data, before SystemUI) it sets the
  notification channels of device-admin / device-owner apps to importance 0
  and marks them user-locked in notification_policy.xml, so the management
  app's permanent notification stops showing. Auto-detects admins/owner,
  plus targets.txt for anything that isn't a device admin.
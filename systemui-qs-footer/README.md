# SystemUI management indicators

This is the companion to the notification script in the repo root. It covers the
on-screen "managed device" indicators that the script cannot reach, because they
are drawn by SystemUI itself rather than posted as app notifications.

Two patches live here, both small and both cosmetic:

1. The Quick Settings disclosure footer (`QSSecurityFooter`).
2. The VPN key icon in the status bar (`StatusBarSignalPolicy`).

Neither touches the device owner, the VPN, or any filter; they only hide labels.

## Device support

**The prebuilt module in this repo is for the Qin F21 Pro only.** It is a patched
copy of that one ROM's `MtkSystemUI.apk`, re-signed with that ROM's platform key.
Do not flash it on any other device; it will not match and can bootloop.

Tested on:

- Qin F21 Pro (model F21), Android 11, MediaTek, AOSP-based ROM.
- With a SafeCore device-owner and its always-on filtering VPN active.

The MDM does not matter. Both indicators are standard AOSP: the footer shows for
*any* device owner, and the key icon shows for *any* active VPN. The patches hide
them at the SystemUI level no matter which management app is installed, so there
is nothing SafeCore-specific here. What is specific is the ROM and its signing
key, as covered under porting below.

## Quick Settings management footer

### What it is

When a device owner or device admin is active, SystemUI draws a disclosure line
at the bottom of the Quick Settings panel, for example:

> This device belongs to your organization and is connected to ...

That line is **not** an app notification and **not** a notification channel. It
is drawn by SystemUI itself (`QSSecurityFooter`) whenever a device owner is
present. Nothing in `notification_policy.xml` controls it, so the root-level
`post-fs-data.sh` script has no way to hide it. The only clean fix is a small
patch to SystemUI.

This is a UI change only. It hides the on-screen label. It does not disable or
weaken the device owner, the admin, or any filter they run; all of that keeps
working exactly as before.

### The patch

In `com.android.systemui.qs.QSSecurityFooter`, the method `handleRefreshState()`
computes whether the footer should show and stores the result in the
`mIsVisible` field. A separate `Runnable` reads `mIsVisible` and sets the footer
view to `VISIBLE` (0x0) or `GONE` (0x8).

Forcing `mIsVisible` to `false` makes the footer `GONE` on every refresh, while
leaving all of the text-building logic untouched. That is the whole change: one
instruction inserted right before the field is written.

See `QSSecurityFooter.smali.patch` for the exact diff.

```smali
    .line 156
    :cond_3
    :goto_1
    # force QS security footer hidden (device-managed disclosure)
    const/4 v3, 0x0

    iput-boolean v3, p0, Lcom/android/systemui/qs/QSSecurityFooter;->mIsVisible:Z
```

The register name (`v3` here) is whatever `handleRefreshState()` assigns to
`mIsVisible` on your build. Open the method, find the single
`iput-boolean <reg>, p0, ...->mIsVisible:Z`, and set that same register to `0`
on the line above. Nothing else changes.

## Status bar VPN key icon

### What it is

Android shows a small key icon in the status bar (next to the signal and SIM
icons) whenever a VPN tunnel is active. A management app that filters traffic
through an always-on VPN keeps this icon on permanently. Like the footer, it is
drawn by SystemUI, not posted by an app.

### The patch

On this build the icon is handled in
`com.android.systemui.statusbar.phone.StatusBarSignalPolicy`, method
`updateVpn()` (AOSP keeps this in `PhoneStatusBarPolicy`; MTK moved it next to
the signal icons). It reads `isVpnEnabled()` and passes that boolean straight to
`setIconVisibility(mSlotVpn, ...)`. Forcing that boolean to `false` right before
the call keeps the icon hidden. The drawable is still assigned, it just never
shows.

See `StatusBarSignalPolicy.smali.patch` for the exact diff.

```smali
    iget-object p0, p0, Lcom/android/systemui/statusbar/phone/StatusBarSignalPolicy;->mSlotVpn:Ljava/lang/String;

    # force VPN status-bar key icon hidden
    const/4 v0, 0x0

    invoke-interface {v1, p0, v0}, Lcom/android/systemui/statusbar/phone/StatusBarIconController;->setIconVisibility(Ljava/lang/String;Z)V
```

The VPN still runs and still filters; only its status-bar indicator is hidden.

## Build and deploy

This follows the same APK patch-and-resign pipeline used for the other F21
system mods. In short:

1. Pull the live SystemUI from the device:
   `adb pull /system/system_ext/priv-app/MtkSystemUI/MtkSystemUI.apk`
   (pulling the live file keeps any mods already on the device).
2. `apktool d -r` to decompile smali only (the `-r` keeps `resources.arsc`
   untouched and avoids the aapt2 recompile wall).
3. Apply the one-line edits above (both patches live in the same APK).
4. `apktool b`, then `zipalign -p 4`, then sign with the platform key:
   `apksigner sign --key platform.pk8 --cert platform.x509.pem` (or any signer
   fed the same key/cert). Verify the resulting signer certificate matches the
   ROM's platform key, or SystemUI will not load.
5. Package as a Magisk module that overlays the patched APK at
   `system/system_ext/priv-app/MtkSystemUI/MtkSystemUI.apk`, flash in Magisk,
   reboot.

## Porting to another device

The patches themselves are reusable, but the built APK is not. To do this on a
different phone you rebuild from that phone's own SystemUI. It is realistic on
devices close to this one and much harder as they diverge.

**Prerequisite — the signing key.** This is the step that decides whether it is
possible at all. Editing SystemUI means re-signing it, and Android only loads a
system app signed with the platform key. This ROM uses the **public AOSP test
key**, which anyone has, so re-signing works. Most retail phones use the OEM's
**private** platform key, which you do not have; there a re-signed SystemUI will
not load. Check first: pull the device's `SystemUI`/`MtkSystemUI` APK and read
its signer certificate. If it is the AOSP test key (or any key you hold), you can
proceed. If it is an OEM key, you cannot, and that is the end of the road for
this method on that device.

**Steps, per device:**

1. Confirm root (Magisk) and the signing-key check above.
2. Find and pull the live SystemUI. The package is usually `com.android.systemui`
   (`pm path com.android.systemui`); the file may be `SystemUI.apk` or, on MTK,
   `MtkSystemUI.apk`, under `/system/...` or `/system/system_ext/...`. Pull the
   live file so any mods already on the device are kept.
3. `apktool d -r` on that APK (the `-r` keeps `resources.arsc` untouched).
4. Apply the equivalent of each patch for that build:
   - Footer: in `QSSecurityFooter`, find where `mIsVisible` is written in
     `handleRefreshState()` and force that register to `0`. On Android 12+ this
     class was reworked into `QSSecurityFooterUtils`, so the exact spot differs;
     the idea (force the footer view to `GONE`) still applies.
   - VPN icon: find `updateVpn()` (in `StatusBarSignalPolicy` here, in
     `PhoneStatusBarPolicy` on stock AOSP) and force the visibility boolean
     passed to `setIconVisibility(mSlotVpn, ...)` to `0`.
   The two `.smali.patch` files here are a reference for what the edit looks
   like, not a drop-in for other builds — registers and line numbers will differ.
5. `apktool b`, `zipalign -p 4`, then sign with that device's platform key
   (`apksigner sign --key platform.pk8 --cert platform.x509.pem`). Verify the
   signer matches the key the ROM expects.
6. Package as a Magisk module overlaying the APK at its real path, flash, reboot.

In practice this is straightforward on another Android 11 AOSP/MTK phone with a
public key, and progressively harder on newer Android versions or OEM skins
(Samsung, Xiaomi, etc.), where SystemUI is restructured and the key is private.

## Reversibility

It ships as a Magisk overlay module; disabling or removing the module in Magisk
restores the original SystemUI. Nothing in `/system` is written directly.

-- Volume, brightness, keyboard backlight, and touchpad controls.
o.bind("XF86AudioRaiseVolume", "Volume up", "omarchy-audio-output-volume raise", { locked = true, repeating = true })
o.bind("XF86AudioLowerVolume", "Volume down", "omarchy-audio-output-volume lower", { locked = true, repeating = true })
o.bind("XF86AudioMute", "Mute", "omarchy-audio-output-volume mute-toggle", { locked = true })
o.bind("XF86AudioMicMute", "Mute microphone", "omarchy-audio-input-mute", { locked = true })
o.bind("XF86MonBrightnessUp", "Brightness up", "omarchy-brightness-display +5%", { locked = true, repeating = true })
o.bind("XF86MonBrightnessDown", "Brightness down", "omarchy-brightness-display 5%-", { locked = true, repeating = true })
-- Keyboard backlight on Shift, because Apple laptop keyboards have no dedicated keys for it: the
-- Mac function row emits only KEY_BRIGHTNESSUP/DOWN (F1/F2), and KEY_KBDILLUMUP/DOWN never arrive,
-- so the XF86KbdBrightness* binds below could not fire on this hardware. The pre-quattro Mac fork
-- solves it the same way. SHIFT + XF86MonBrightness* is therefore spoken for, and the
-- "Brightness maximum/minimum" binds that used to sit on it are gone - they would shadow these.
o.bind("SHIFT + XF86MonBrightnessUp", "Keyboard brightness up", "omarchy-brightness-keyboard up", { locked = true, repeating = true })
o.bind("SHIFT + XF86MonBrightnessDown", "Keyboard brightness down", "omarchy-brightness-keyboard down", { locked = true, repeating = true })
-- Kept for external keyboards that do emit the dedicated keys.
o.bind("XF86KbdBrightnessUp", "Keyboard brightness up", "omarchy-brightness-keyboard up", { locked = true, repeating = true })
o.bind("XF86KbdBrightnessDown", "Keyboard brightness down", "omarchy-brightness-keyboard down", { locked = true, repeating = true })
o.bind("XF86KbdLightOnOff", "Keyboard backlight cycle", "omarchy-brightness-keyboard cycle", { locked = true })
o.bind_toggle("XF86TouchpadToggle", "Toggle touchpad", "touchpad", { locked = true })
o.bind("XF86TouchpadOn", "Enable touchpad", "omarchy-toggle-touchpad on", { locked = true })
o.bind("XF86TouchpadOff", "Disable touchpad", "omarchy-toggle-touchpad off", { locked = true })

-- Precise volume and brightness controls.
o.bind("ALT + XF86AudioRaiseVolume", "Volume up precise", "omarchy-audio-output-volume +1", { locked = true, repeating = true })
o.bind("ALT + XF86AudioLowerVolume", "Volume down precise", "omarchy-audio-output-volume -1", { locked = true, repeating = true })
o.bind("ALT + XF86MonBrightnessUp", "Brightness up precise", "omarchy-brightness-display +1%", { locked = true, repeating = true })
o.bind("ALT + XF86MonBrightnessDown", "Brightness down precise", "omarchy-brightness-display 1%-", { locked = true, repeating = true })

-- Media controls.
o.bind("XF86AudioNext", "Next track", "omarchy-shell media next", { locked = true })
o.bind("ALT + XF86AudioPlay", "Next track", "omarchy-shell media next", { locked = true })
o.bind("XF86AudioPause", "Pause", "omarchy-shell media playPause", { locked = true })
o.bind("XF86AudioPlay", "Play", "omarchy-shell media playPause", { locked = true })
o.bind("XF86AudioPrev", "Previous track", "omarchy-shell media previous", { locked = true })
o.bind("ALT + SHIFT + XF86AudioPlay", "Previous track", "omarchy-shell media previous", { locked = true })

o.bind("SHIFT + XF86AudioMute", "Switch audio output", "omarchy-audio-output-switch", { locked = true })
o.bind("SHIFT + XF86AudioPause", "Switch media source", "omarchy-audio-source-switch", { locked = true })
o.bind("SHIFT + XF86AudioPlay", "Switch media source", "omarchy-audio-source-switch", { locked = true })

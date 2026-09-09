-- LOCAL Mac: delete an entry to let Parsec/macOS handle that shortcut normally.
-- Both left and right Command match. The Wispr modifier-only chord is untouched.
return {
    {mods = {'cmd'}, key = 'w', action = 'CLOSE_WINDOW'},
    {mods = {'cmd'}, key = 'q', action = 'QUIT_APP'},
    {mods = {'cmd', 'shift'}, key = '4', action = 'SCREENSHOT_REGION'},
}

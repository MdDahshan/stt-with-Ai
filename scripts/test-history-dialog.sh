HISTORY_CONTENT="🕒 07:11 ➜ Okay this image here
🕒 07:11 ➜ في إهياد يعبيت
🕒 07:11 ➜ ما لي يا عمي أتعلق بينك منذ الخامسة عشر.
🕒 07:13 ➜ <think> Okay, let's see. The user is asking about Prometh, probably"

if command -v zenity >/dev/null 2>&1; then
    printf '%s\n' "$HISTORY_CONTENT" | zenity --text-info --title="History" --width=800 --height=600 &
elif command -v rofi >/dev/null 2>&1; then
    rofi -e "$HISTORY_CONTENT" -theme-str 'window {width: 800px;}' &
fi

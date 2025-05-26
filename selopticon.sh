#!/bin/bash

# Asetukset
CODING_APPS=("xed" "kate" "geany" "gedit")  # lisää omat suosikkieditorit
POLL_INTERVAL=10                            # kuinka usein haluaa nähdä tilapäivityksiä (1-30s)
AUTH_TOKEN=                                 # testaustime auth token 
SHOW_FILE=true                              # true/false, näytä projektin/kansion lisäksi tiedoston nimi
#HIDE_PROJECT=false                         # true/false, (ei toimi vielä)

declare -A EXT_TO_LANG=(                    # vaihda kieliin joita käytät
    ["rb"]="Ruby"
    ["sh"]="Shell"
    ["asm"]="Assembly"
    ["cob"]="Cobol"
    ["cbl"]="Cobol"
    ["jcl"]="JCL"
    ["html"]="HTML"
    ["css"]="CSS"
    ["pl"]="Perl"
    ["hs"]="Haskell")

# internal parameters
IDLE_LIMIT=30 # sekuntia
last_hb=0
total_time=0
last_check=$(date +%s)

sleep 5
stty -echoctl
    
is_coding_window() {
    for app in "${CODING_APPS[@]}"; do
        if [[ "${prog,,}" == *"${app,,}"* ]]; then
            return 0
        fi
    done
    return 1
}

is_active() {
    (( idle_sec < POLL_INTERVAL ))
}

is_idle() {
    (( idle_sec > POLL_INTERVAL ))
}

is_gone() {
    (( idle_sec >= IDLE_LIMIT )) || (( current_time - last_check >= IDLE_LIMIT ))
}

send_heartbeat() {
    json_data="{
        \"language\": \"$language\",
        \"hostname\": \"$host\",
        \"editor_name\": \"$prog\",
        \"project_name\": \"$project$name\",
        \"hidden\": $HIDE_PROJECT}"

    curl --silent --show-error --output /dev/null --request POST 'https://api.testaustime.fi/activity/update' \
    --header "Authorization: Bearer $AUTH_TOKEN" \
    --header 'Content-Type: application/json' \
    --data-raw "$json_data"
}

flush() {
    curl --request POST 'https://api.testaustime.fi/activity/flush' \
    --header "Authorization: Bearer $AUTH_TOKEN"
}

cleanup() {
    flush
    echo "☠️  🌊"
    stty echoctl
    exit 0
}
trap cleanup SIGINT

for cmd in xdotool xprintidle; do
    if ! command -v "$cmd" &>/dev/null; then
        echo "Error: '$cmd' is not found, Selopticon needs it to work."
        exit 1
    fi
done

while true; do
    current_time=$(date +%s)

    win_id=$(xdotool getactivewindow 2>/dev/null)
    pid=$(xdotool getwindowpid "$win_id")

    if [ -z "$win_id" ] || [ -z "$pid" ]; then
        echo "Uhh oh, try again."
        exit 1
    fi

    prog=$(ps -p "$pid" -o comm=)
    title=$(xdotool getwindowname "$win_id")
    filename=$(echo "$title" | grep -oE '\w.*\.[a-zA-Z0-9]+') 
    if git=$(git rev-parse --show-toplevel 2>/dev/null); then
        project=$(basename "$git")
    else
        path=$(echo "$title" | grep -oE '/[^ ]+(/[^ ]+)*')
        project=$(basename "$path")
    fi

    if [[ "$SHOW_FILE" == "true" ]]; then
        name="/${filename##*/}"
    fi

    lang="${filename##*.}"
    #it yells if window doesn't have a language. most windows don't.
    language=$( { echo "${EXT_TO_LANG[$lang]:-Unknown}"; } 2>/dev/null)
    host=$(hostname)

    idle_ms=$(xprintidle 2>/dev/null)
    idle_sec=$(( idle_ms / 1000 ))


    if [[ "$state" == "gone" ]]; then
        if is_active && is_coding_window; then
            state="coding_now"
        else
        :
        fi
    elif is_coding_window && is_active; then
        state="coding_now"
    elif is_coding_window && is_idle; then
        state="idle"
    elif ! is_coding_window && is_active; then
        state="peeking_docs"
    elif ! is_coding_window && is_idle; then
        state="idle"
    fi

    case $state in
    "coding_now")

    if (( current_time - last_hb >= 30 )); then
        send_heartbeat
        echo -e "\u2764\uFE0F"
        last_hb=$current_time
    fi

    duration=$(( current_time - last_check ))
    total_time=$(( total_time + duration ))
    echo "✅ Coding: $((total_time / 60)) min $((total_time % 60)) sec"
    last_check=$current_time
    ;;
    "peeking_docs")
    echo "📚 Checking documentation"
    if is_gone; then
        flush
        echo "📚 🌊 .. too long"
        state="gone"
        last_check=$current_time
    fi
    ;;
    "gone")
    :
    ;;
    "idle")
    echo "⌛ Idle"
    if is_gone; then
        flush
        echo "⌛ 🌊 .. too long"
        state="gone"
        last_check=$current_time
    fi
    ;;
    esac
    
    sleep "$POLL_INTERVAL"

done

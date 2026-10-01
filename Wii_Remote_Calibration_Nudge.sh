#!/bin/bash

# Wii Remote Calibration Nudge for MiSTer FPGA
# Version 0.1.0 - Wii Remote calibration nudges for MiSTer cores.

CONFIG_DIR="${MISTER_CONFIG_DIR:-/media/fat/config}"
BACKUP_SUFFIX=".wii-nudge-original"
FINE=5
COARSE=25

FILES=()
SELECTED=""
PENDING=0

screen() {
	clear
	# Blank top margin keeps text inside a CRT's visible safe area.
	printf "\n\n\n"
}

size_of() {
	wc -c < "$1" 2>/dev/null | tr -d '[:space:]'
}

read_cal() {
	local values
	[ -f "$1" ] || return 1
	[ "$(size_of "$1")" = "16" ] || return 1
	values="$(od -An -v -N16 -t d4 "$1" 2>/dev/null)" || return 1
	set -- $values
	[ "$#" -eq 4 ] || return 1
	# MiSTer stores vertical (Y) first, then horizontal (X).
	YMIN="$1"; YMAX="$2"; XMIN="$3"; XMAX="$4"
}

write_i32_le() {
	local v="$1" u b0 b1 b2 b3 text
	if [ "$v" -lt 0 ]; then u=$((v + 4294967296)); else u="$v"; fi
	b0=$((u & 255))
	b1=$(((u >> 8) & 255))
	b2=$(((u >> 16) & 255))
	b3=$(((u >> 24) & 255))
	text="\\$(printf '%03o' "$b0")\\$(printf '%03o' "$b1")\\$(printf '%03o' "$b2")\\$(printf '%03o' "$b3")"
	printf '%b' "$text"
}

write_cal() {
	local file="$1" temp="${1}.tmp.$$"
	{
		write_i32_le "$2"
		write_i32_le "$3"
		write_i32_le "$4"
		write_i32_le "$5"
	} > "$temp" || { rm -f "$temp"; return 1; }
	[ "$(size_of "$temp")" = "16" ] || { rm -f "$temp"; return 1; }
	mv -f "$temp" "$file" || { rm -f "$temp"; return 1; }
	sync
}

ensure_backup() {
	local backup="${SELECTED}${BACKUP_SUFFIX}"
	if [ -e "$backup" ]; then
		[ "$(size_of "$backup")" = "16" ]
		return
	fi
	cp -p "$SELECTED" "$backup" || return 1
	[ "$(size_of "$backup")" = "16" ] || { rm -f "$backup"; return 1; }
	sync
}

get_offsets() {
	local current_y="$YMIN" current_x="$XMIN" backup="${SELECTED}${BACKUP_SUFFIX}"
	Y_OFFSET="0"
	X_OFFSET="0"
	if [ -f "$backup" ] && read_cal "$backup"; then
		Y_OFFSET=$((current_y - YMIN))
		X_OFFSET=$((current_x - XMIN))
	fi
	read_cal "$SELECTED" >/dev/null 2>&1
}

format_offsets() {
	if [ "$Y_OFFSET" -gt 0 ]; then
		Y_TEXT="UP $Y_OFFSET"
	elif [ "$Y_OFFSET" -lt 0 ]; then
		Y_TEXT="DOWN $((-Y_OFFSET))"
	else
		Y_TEXT="UP/DOWN 0"
	fi
	if [ "$X_OFFSET" -gt 0 ]; then
		X_TEXT="LEFT $X_OFFSET"
	elif [ "$X_OFFSET" -lt 0 ]; then
		X_TEXT="RIGHT $((-X_OFFSET))"
	else
		X_TEXT="LEFT/RIGHT 0"
	fi
}

read_key() {
	local one two
	KEY=""
	if ! IFS= read -r -s -n 1 KEY; then KEY="q"; return; fi
	if [ "$KEY" = $'\033' ]; then
		IFS= read -r -s -n 1 -t 0.15 one || one=""
		IFS= read -r -s -n 1 -t 0.15 two || two=""
		KEY="${KEY}${one}${two}"
	fi
}

find_files() {
	local file
	FILES=()
	for file in \
		"$CONFIG_DIR"/*_gun_cal_057e_0306_v2.cfg \
		"$CONFIG_DIR"/*_gun_cal_057e_0330_v2.cfg
	do
		[ -f "$file" ] || continue
		[ "$(size_of "$file")" = "16" ] || continue
		FILES+=("$file")
	done
}

choose_file() {
	local answer file label page=0 per_page=6 start end count shown i choice
	find_files
	if [ "${#FILES[@]}" -eq 0 ]; then
		screen
		echo "     WII AIM NUDGE 0.1"
		echo
		echo "     NO CAL FILE"
		echo
		echo "     Run F10 setup"
		echo "     in a core first."
		sleep 6
		return 1
	fi
	while true; do
		count="${#FILES[@]}"
		start=$((page * per_page))
		end=$((start + per_page))
		[ "$end" -gt "$count" ] && end="$count"
		shown=$((end - start))
		screen
		echo "     CHOOSE CALIBRATED CORE"
		echo
		i="$start"
		choice=1
		while [ "$i" -lt "$end" ]; do
			file="${FILES[$i]}"
			label="$(basename "$file")"
			label="${label%%_gun_cal_*}"
			printf "     %d) %.18s\n" "$choice" "$label"
			i=$((i + 1))
			choice=$((choice + 1))
		done
		echo
		if [ "$count" -gt "$per_page" ]; then
			printf "     PAGE %d/%d  N NEXT  P PREV\n" "$((page + 1))" "$(((count + per_page - 1) / per_page))"
		fi
		printf "     Number or Q: "
		read -r answer
		case "$answer" in
			q|Q) return 1 ;;
			n|N)
				if [ "$end" -lt "$count" ]; then page=$((page + 1)); fi
				;;
			p|P)
				if [ "$page" -gt 0 ]; then page=$((page - 1)); fi
				;;
			''|*[!0-9]*) ;;
			*)
				if [ "$answer" -ge 1 ] && [ "$answer" -le "$shown" ]; then
					SELECTED="${FILES[$((start + answer - 1))]}"
					return 0
				fi
				;;
		esac
	done
}

saved_screen() {
	screen
	echo "     CHANGE SAVED"
	echo
	echo "     POINTER $1 $2"
	echo "     TOTAL $3"
	echo "     TOTAL $4"
	echo
	echo "     NOT ACTIVE YET"
	echo
	echo "     B = REBOOT/APPLY"
	echo "     U/D = NUDGE MORE"
	echo
	echo "     Returning in 4..."
	sleep 4
}

nudge() {
	local amount="$1" direction new_min new_max
	read_cal "$SELECTED" || return
	ensure_backup || return
	new_min=$((YMIN + amount))
	new_max=$((YMAX + amount))
	[ "$new_min" -lt -4096 ] && return
	[ "$new_max" -gt 4096 ] && return
	[ "$new_min" -ge "$new_max" ] && return
	write_cal "$SELECTED" "$new_min" "$new_max" "$XMIN" "$XMAX" || return
	read_cal "$SELECTED"
	get_offsets
	format_offsets
	PENDING=1
	if [ "$amount" -gt 0 ]; then direction="UP"; else direction="DOWN"; amount=$((-amount)); fi
	saved_screen "$direction" "$amount" "$Y_TEXT" "$X_TEXT"
}

nudge_horizontal() {
	local amount="$1" direction new_min new_max
	read_cal "$SELECTED" || return
	ensure_backup || return
	new_min=$((XMIN + amount))
	new_max=$((XMAX + amount))
	[ "$new_min" -lt -4096 ] && return
	[ "$new_max" -gt 4096 ] && return
	[ "$new_min" -ge "$new_max" ] && return
	write_cal "$SELECTED" "$YMIN" "$YMAX" "$new_min" "$new_max" || return
	read_cal "$SELECTED"
	get_offsets
	format_offsets
	PENDING=1
	if [ "$amount" -gt 0 ]; then direction="LEFT"; else direction="RIGHT"; amount=$((-amount)); fi
	saved_screen "$direction" "$amount" "$Y_TEXT" "$X_TEXT"
}

restore_original() {
	local backup="${SELECTED}${BACKUP_SUFFIX}"
	[ -f "$backup" ] || return
	screen
	echo "     RESTORE ORIGINAL?"
	echo
	echo "     Y = YES"
	echo "     N = NO"
	echo
	printf "     Press Y or N: "
	read_key
	case "$KEY" in
		y|Y)
			cp -p "$backup" "$SELECTED" && sync
			PENDING=1
			screen
			echo "     ORIGINAL SAVED"
			echo
			echo "     REBOOT TO APPLY"
			sleep 4
			;;
	esac
}

reboot_apply() {
	screen
	echo "     REBOOT TO APPLY?"
	echo
	echo "     Y = REBOOT NOW"
	echo "     N = GO BACK"
	echo
	printf "     Press Y or N: "
	read_key
	case "$KEY" in
		y|Y)
			screen
			echo "     SAVED"
			echo "     REBOOTING..."
			sync
			sleep 1
			reboot
			;;
	esac
}

quit_menu() {
	[ "$PENDING" -eq 0 ] && exit 0
	while true; do
		screen
		echo "     SAVED-NOT ACTIVE"
		echo
		echo "     B = REBOOT/APPLY"
		echo "     Q = QUIT FOR NOW"
		echo
		printf "     Press B or Q: "
		read_key
		case "$KEY" in
			b|B) reboot_apply; return ;;
			q|Q) exit 0 ;;
		esac
	done
}

control_menu() {
	local label
	while true; do
		read_cal "$SELECTED" || return
		get_offsets
		format_offsets
		label="$(basename "$SELECTED")"
		label="${label%%_gun_cal_*}"
		screen
		echo "     WII AIM NUDGE 0.1"
		echo
		printf "     %-13s%s\n" "U  UP 5" "D  DOWN 5"
		printf "     %-13s%s\n" "L  LEFT 5" "R  RIGHT 5"
		printf "     %-13s%s\n" "3  UP 25" "4  DOWN 25"
		printf "     %-13s%s\n" "C  CORE" "B  APPLY"
		printf "     %-13s%s\n" "O  ORIGINAL" "Q  QUIT"
		echo
		printf "     CORE: %.16s\n" "$label"
		echo "     TOTAL: $Y_TEXT"
		echo "     TOTAL: $X_TEXT"
		if [ "$PENDING" -eq 1 ]; then
			echo "     SAVED-NOT ACTIVE"
		else
			echo "     READY"
		fi
		echo
		printf "     Press key: "
		read_key
		case "$KEY" in
			$'\033[A'|u|U|1) nudge "$FINE" ;;
			$'\033[B'|d|D|2) nudge "$((-FINE))" ;;
			$'\033[D'|l|L) nudge_horizontal "$FINE" ;;
			$'\033[C'|r|R) nudge_horizontal "$((-FINE))" ;;
			3) nudge "$COARSE" ;;
			4) nudge "$((-COARSE))" ;;
			c|C) return ;;
			b|B) reboot_apply ;;
			o|O) restore_original ;;
			q|Q) quit_menu ;;
		esac
	done
}

if [ ! -d "$CONFIG_DIR" ]; then
	screen
	echo "     CONFIG NOT FOUND"
	sleep 5
	exit 1
fi

while choose_file; do control_menu; done
exit 0

#!/bin/sh
# Copyleft 2026 Efenstor
# revision 2026.04-1

# OPTIONS
drive=/dev/sr0  # CD drive to use
pregap=1        # Add a 2-second pregap before the first track
cdrdao_opts="--eject --speed 0"

cleanup() {
  if [ -f "$cue" ]; then
    rm "$cue"
  fi
}

# Ctrl+C trap
trap_func() {
  cleanup
  exit 1
}          

# Help
if [ $# -lt 1 ]; then
  echo "
burn-cdda.sh
--
Burns .wav files from a directory using cdrdao onto an Audio CD with CD-TEXT.

Usage: burn.sh <dir> [cd-text]

cd-text: A plain-text file of the format:
  Performer Name
  Album Title
  
  Track Name
  Track Name
  ...
"
  exit
fi

# Find files
files=$(find "$1" -maxdepth 1 -type f -iname "*.wav" | sort -f)
if [ ! "$files" ]; then
  echo "No .wav files found in the specified directory"
  cleanup
  exit
fi

# Optional arguments
if [ "$2" ]; then
  cdt=$(cat "$2" | sed "/^$/d")
else
  cdt=
fi

# Prepare the temporary files
echo "Preparing the temporary files"
cue=$(mktemp --suffix=.cue)
if [ $? -ne 0 ]; then
  echo "Cannot create a temporary CUE file"
  cleanup
  exit
fi
if [ "$cdt" ]; then
  # Add info for CD-TEXT
  performer=$(echo "$cdt" | sed -n "1p")
  album=$(echo "$cdt" | sed -n "2p")
  echo "PERFORMER \"$performer\"" >> "$cue"
  echo "TITLE \"$album\"" >> "$cue"
fi

# Create the file list and the CUE file
echo "Creating the file list and the CUE sheet"
tn=1
cl=3
while [ 1 ]
do
  file=$(echo "$files" | sed -n "$tn"p)
  if [ ! "$file" ]; then
    break
  fi
  rfile=$(realpath "$file")

  # CUE: Add general track info 
  echo "FILE \"$rfile\" WAVE" >> "$cue"
  tnp=$(printf "%0*d" 2 $tn)
  echo "  TRACK $tnp AUDIO" >> "$cue"
  if [ "$cdt" ]; then
    track=$(echo "$cdt" | sed -n "$cl"p)
    if [ ! "$track" ]; then
      echo "Not enough tracks in the CD-Text file"
      cleanup
      exit
    fi
    echo "    TITLE \"$track\"" >> "$cue"
    echo "    PERFORMER \"$performer\"" >> "$cue"
  fi
  
  # CUE: Add pregap
  if [ "$pregap" -eq 1 ] && [ "$tn" -eq 1 ]; then
    echo "    PREGAP 00:02:00" >> "$cue"
  fi
  
  # CUE: Track index
  echo "    INDEX 01 00:00:00" >> "$cue"
  
  tn=$(( $tn + 1 ))
  cl=$(( $cl + 1 ))
done

# Burn the disk
echo "Burning the disk"
trap "trap_func" INT
diskinfo=$(cdrdao disk-info --device $drive)
if echo "$diskinfo" | grep "CD-RW *: yes" > /dev/null; then
  if echo "$diskinfo" | grep "CD-R empty *: no" > /dev/null; then
    echo "Disk is a non-blank CD-RW"
    cdrdao blank --device $drive
  fi
fi
eval cdrdao write --device $drive $cdrdao_opts "$cue"
trap - INT

cleanup


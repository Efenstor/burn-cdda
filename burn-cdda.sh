#!/bin/sh
# Copyleft 2026 Efenstor
# revision 2026.04-2

# OPTIONS
drive=/dev/sr0  # CD drive to use
fpregap=2       # Default pregap before the first track
opregap=0       # Default pregap before other tracks
cdrdao_opts="--eject --speed 0"

cleanup() {
  if [ ! "$savecue" ] && [ -f "$cue" ]; then
    rm "$cue"
  fi
}

# Ctrl+C trap
trap_func() {
  cleanup
  exit 1
}          

# Parse the named parameters
optstr="?hf:p:s:"
while getopts $optstr opt; do
  case "$opt" in
    f) fpregap=$OPTARG ;;
    p) opregap=$OPTARG ;;
    s) savecue=$OPTARG ;;
    :) echo "Missing argument for -$OPTARG" >&2
       exit 1
       ;;
  esac
done

# Parse the unnamed parameters
shift $((OPTIND - 1))    

# Help
if [ $# -lt 1 ]; then
  echo "
burn-cdda.sh
--
Burns .wav files from a directory using cdrdao onto an Audio CD with CD-TEXT.

Usage:
  burn.sh [options] <dir_or_cue> [cd-text]

Options:
  -f <len>: pregap before the first track in seconds (default = 2).
  -p <len>: pregap before all other tracks in seconds (default = 0).
  -s <file>: save the CUE sheet file and exit.

dir:
  directory with .wav files or a CUE sheet file.

cd-text:
  Plain-text file of the format:
  
    Performer Name
    Album Title
  
    Track Name
    Track Name
    ...
"
  exit
fi

# Mandatory parameters
if [ -f "$1" ]; then
  # Directly specified CUE file
  cue="$1"
else
  # Find .wav files
  files=$(find "$1" -maxdepth 1 -type f -iname "*.wav" | sort -f)
  if [ ! "$files" ]; then
    echo "No .wav files found in the specified directory"
    cleanup
    exit
  fi

  # Optional arguments
  if [ "$2" ]; then
    cdt=$(cat "$2" | sed "/^$/d; s/^ *//g; s/ *$//g")
  else
    cdt=
  fi

  if [ ! "$savecue" ]; then
    # Prepare the temporary CUE file
    echo "Using a temporary CUE file"
    cue=$(mktemp --suffix=.cue)
    if [ $? -ne 0 ]; then
      echo "Cannot create a temporary CUE file"
      cleanup
      exit
    fi
  else
    # Save CUE
    echo "Saving CUE sheet to \"$savecue\""
    cue="$savecue"
    if [ -f "$cue" ]; then
      rm "$cue"
      if [ $? -ne 0 ]; then
        echo "Error saving the CUE file"
        cleanup
        exit
      fi
    fi
  fi
  if [ "$cdt" ]; then
    # Add info for CD-TEXT
    performer=$(echo "$cdt" | sed -n "1p")
    album=$(echo "$cdt" | sed -n "2p")
    echo "PERFORMER \"$performer\"" >> "$cue"
    echo "TITLE \"$album\"" >> "$cue"
  fi
  cuedir=$(dirname "$cue")

  # Create the file list and the CUE file
  echo "Creating the file list and the CUE sheet"
  cl=3
  tn=1
  while [ 1 ]
  do
    file=$(echo "$files" | sed -n "$tn"p)
    if [ ! "$file" ]; then
      break
    fi
    rfile=$(realpath -s --relative-base="$cuedir" "$file")

    # General track info 
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
    
    # Pregap
    if [ $tn -eq 1 ] && [ "$fpregap" -gt 0 ]; then
      pregap="$fpregap"
    elif [ $tn -gt 1 ] && [ "$opregap" -gt 0 ]; then
      pregap="$opregap"
    else
      pregap=0
    fi
    if [ $pregap -gt 0 ]; then
      pgmin=$(( $pregap / 60 ))
      pgsec=$(( $pregap - ($pgmin * 60) ))
      pgminp=$(printf "%0*d" 2 $pgmin)
      pgsecp=$(printf "%0*d" 2 $pgsec)
      echo "    PREGAP $pgminp:$pgsecp:00" >> "$cue"
    fi

    # Index
    echo "    INDEX 01 00:00:00" >> "$cue"
    
    tn=$(( $tn + 1 ))
    cl=$(( $cl + 1 ))
  done

  # Exit if just saving CUE
  if [ "$savecue" ]; then
    cleanup
    exit
  fi
fi

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


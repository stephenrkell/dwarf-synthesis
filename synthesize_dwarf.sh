#!/bin/bash

###############################################################################
USAGE="$0 <binary_input_file> [<binary_output_file>]"

HELP_TEXT="synthesize_dwarf.sh
Script that sticks all the parts of dwarf-synthesis together.

Usage: $USAGE

The provided <binary_input_file> is expected **NOT** to have any .eh_frame
section.

If <binary_output_file> is provided, a binary file equivalent to
<binary_input_file> that contains an .eh_frame ELF section will be written as
<binary_output_file>.

If not, the input file will be overwriten with such a file.

If the environment variable TIMERS is set to anything non-empty, the process
will print timestamps at various locations to find out the time spent in
the various steps.
"
###############################################################################

function timer_probe {
    if [ -z "$TIMERS" ] ; then
        return
    fi
    timer_name="$1"
    >&2 echo "~~TIME~~ $timer_name [$(date +%s.%N)]"
}

function find_ml_dwarf_write {
    out=$(which "ml_dwarf_write.bin" 2>/dev/null)
    if [ -n "$out" ] ; then
        echo $out
        return 0
    fi
    for location in . "$(dirname "$BASH_SOURCE")" "$(dirname $0)" ; do
        echo "Trying location $location" 1>&2
        out="$location/ml_dwarf_write.bin"
        if [ -x "$( readlink -f "$out" )" ] ; then
            echo $out
            return 0
        else
            echo "$out is not executable" 1>&2
        fi
    done
    return 1
}

function bap_synth {
    timer_arg=""
    if [ -n "$TIMERS" ]; then
        timer_arg='--dwarfsynth-timers'
    fi
    # `--no-optimization`: it's actually faster without
    bap "$INPUT_FILE" \
        $timer_arg \
        --no-optimization \
        --no-byteweight -p dwarfsynth \
        --dwarfsynth-output "$TMP_DIR/marshal" $BAP_ARGS \
        > /dev/null
    return $?
}

function dwarf_write_synth {
    echo "ML_DWARF_WRITE is $ML_DWARF_WRITE" 1>&2
#    $ML_DWARF_WRITE "$TMP_DIR/marshal" "$INPUT_FILE" "$TMP_DIR/eh_frame" \
#        > /dev/null
    echo "Doing: " $ML_DWARF_WRITE "$TMP_DIR/marshal" "$INPUT_FILE" "$TMP_DIR/eh_frame"
    $ML_DWARF_WRITE "$TMP_DIR/marshal" "$INPUT_FILE" "$TMP_DIR/eh_frame"
    return $?
}

function dwarf_plug {
    objcopy \
        --remove-section '.eh_frame' --remove-section '.eh_frame_hdr' \
        --add-section .eh_frame="$TMP_DIR/eh_frame" \
        "$INPUT_FILE" "$OUTPUT_FILE"
    return $?
}

ML_DWARF_WRITE=$(find_ml_dwarf_write)
if [ $? -ne 0 ] ; then
    echo -e "Cannot find ml_dwarf_write" 1>&2
    exit 1
fi


echo "basename is $(basename -- "$0")" 1>&2
case "$(basename -- "$0")" in
	(synthesize_dwarf.sh)

if [ "$#" -lt "1" ] ; then
    >&2 echo -e "Missing argument.\n\n$HELP_TEXT"
    exit 1
fi


INPUT_FILE="$1"
OUTPUT_FILE="$2"

if ! [ -f "$INPUT_FILE" ] ; then
    echo -e "$INPUT_FILE: no such file.\n\n$HELP_TEXT" 1>&2
fi

if [ -z "$OUTPUT_FILE" ] ; then
    OUTPUT_FILE="$INPUT_FILE"
fi

TMP_DIR="$(mktemp -d)"

timer_probe "bap startup" \
    && bap_synth \
    && timer_probe "write DWARF table" \
    && dwarf_write_synth \
    && timer_probe "insert DWARF table in binary" \
    && dwarf_plug \
    && timer_probe "finish"

rm -rf "$TMP_DIR"

;;

(*)
    echo "Set INPUT_FILE, OUTPUT_FILE and TMP_DIR before doing bap_synth" 1>&2
    set -v
    true
;;
esac

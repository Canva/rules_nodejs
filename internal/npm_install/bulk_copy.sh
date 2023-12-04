#!/bin/sh

set -eu -o pipefail

# The list of files to copy, relative to base so directories are preserved
input_files_list="$1"
# The base path which input files will be resolved from
input_files_base="$2"
# Destination directory for files
out_dir="$3"

tar --create --file - --directory "$input_files_base"  --files-from "$input_files_list"| tar --extract --file - --directory "$out_dir"

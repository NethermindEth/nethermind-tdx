#!/bin/bash

for phase in post pre; do
    for dir in "$phase"/*; do
        if [ -d "$dir" ]; then
            for file in "$dir"/*.old; do
                base_name=$(basename "${file%.old}")
                new_file="$dir/$base_name.new"
                patch_file="$dir/$base_name.patch"

                echo "Generating patch for $base_name in $phase"

                diff -u "$file" "$new_file" > "$patch_file" || true
            done
        fi
    done
done

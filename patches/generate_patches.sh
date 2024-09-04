#!/bin/bash

cd "$(dirname "$0")" || exit 1

for phase in post pre; do
    for dir in "$phase"/*; do
        if [ -d "$dir" ]; then
            for file in "$dir"/*.old; do
                base_name=$(basename "${file%.old}")
                new_file="$dir/$base_name.new"
                patch_file="$dir/$base_name.patch"

                echo "Processing $base_name in $phase"

                if [ -f "$patch_file" ]; then
                    should_skip=false

                    temp_file=$(mktemp)
                    patch -s -f "$file" "$patch_file" -o "$temp_file"
                    cmp -s "$temp_file" "$new_file" && should_skip=true
                    rm "$temp_file"

                    if [ "$should_skip" = true ]; then
                        echo "Patch for $base_name is up to date"
                        continue
                    fi
                fi

                echo "Generating patch for $base_name"
                diff -u "$file" "$new_file" > "$patch_file" || true
            done
        fi
    done
done

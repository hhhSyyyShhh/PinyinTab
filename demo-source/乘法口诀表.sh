#!/usr/bin/env bash

for ((row = 1; row <= 9; row++)); do
    for ((column = 1; column <= row; column++)); do
        printf '%d×%d=%2d\t' "$column" "$row" "$((column * row))"
    done
    printf '\n'
done

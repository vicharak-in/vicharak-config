#!/usr/bin/env bash
# shellcheck shell=bash

if git status &>/dev/null && [[ -f "$PWD/usr/bin/vicharak-config" ]]
then
    ROOT_PATH="${ROOT_PATH:-"$PWD"}"
else
    ROOT_PATH="${ROOT_PATH:-"$PWD"}/src"
fi


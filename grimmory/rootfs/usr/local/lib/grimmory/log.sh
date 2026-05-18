# shellcheck shell=bash

grimmory::log::info()  { echo "[grimmory] INFO  $*"; }
grimmory::log::warn()  { echo "[grimmory] WARN  $*" >&2; }
grimmory::log::error() { echo "[grimmory] ERROR $*" >&2; }
grimmory::log::die()   { grimmory::log::error "$*"; exit 1; }

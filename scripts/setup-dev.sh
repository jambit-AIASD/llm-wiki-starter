#!/usr/bin/env bash
set -e

if [ ! -f .qmd/index.sqlite ]; then
  echo "Initializing qmd..."
  qmd init
  qmd collection add wiki/
fi

qmd update
qmd embed
echo "qmd ready."

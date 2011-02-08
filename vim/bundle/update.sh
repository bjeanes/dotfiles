#!/bin/sh

for i in `find . -type d -depth 1`; do
  cd $i
  git pull origin master &
  cd ..
done

#!/bin/bash

if [ "$#" -ne 2 ]; then
    echo "Usage: ./clean-database-dump.sh <INPUT_FILENAME> <OUTPUT_FILENAME>"
    exit 1
fi

input=$1
output=$2

cp $1 $2

echo "[1/5] Fixing CHARSET..."
sed -i "s/CHARSET=.*\;/CHARSET=utf8\;/g" $2

echo "[2/5] Fixing CHARACTER SET..."
sed -i "s/CHARACTER\ SET\ [^\ ]*/CHARACTER\ SET\ utf8/" $2

echo "[3/5] Fixing COLLATION..."
sed -i "s/SET\ collation_connection.*=\ [^@].*\ \*/SET\ collation_connection\ =\ utf8_unicode_ci\ \*/" $2

echo "[4/5] Remove CREATE DATABASE..."
sed -i "s/CREATE\ DATABASE.*//" $2

echo "[5/5] Remove USE..."
sed -i "s/USE\ \`.*//" $2
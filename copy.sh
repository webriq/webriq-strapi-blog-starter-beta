#!/bin/bash
#
# Copies database source to target source
# 
set -euo pipefail
set -x

if [[ -z "${MONGODB_URI}"] ]; then
    echo "${MONGODB_URI}"
    TARGET_DB="${MONGODB_URI}"
else
    echo "MongoDB URI is not set"
    TARGET_DB="mongodb://dbuser:dbpass123@ds263307.mlab.com:63307/testtoday-091419-045311"
fi

SOURCE_DB="mongodb://heroku_k1d6v8cm:87s99al8t2uuqrilm7t6g4fvpg@ds029705.mlab.com:29705/heroku_k1d6v8cm"

getDBParts() {
    local DB_STRING=$1
    local DB_PART=$2

    if [ "$DB_PART" == "USERNAME" ]; then
        echo $DB_STRING | cut -d":" -f2 | cut -c 3-
    fi

    if [ "$DB_PART" == "PASSWORD" ]; then
        echo $DB_STRING | cut -d":" -f3 | cut -d"@" -f1
    fi

    if [ "$DB_PART" == "HOSTNAME" ]; then
        echo $DB_STRING | cut -d":" -f3 | cut -d"@" -f2
    fi

    if [ "$DB_PART" == "NAME" ]; then
        echo $DB_STRING | cut -d":" -f4 | cut -d"/" -f2
    fi

    if [ "$DB_PART" == "PORT" ]; then
        echo $DB_STRING | cut -d":" -f4 | cut -d"/" -f1
    fi
}

echo $SOURCE_DB
getDBParts $SOURCE_DB "USERNAME"
getDBParts $SOURCE_DB "PASSWORD"
getDBParts $SOURCE_DB "HOSTNAME"
getDBParts $SOURCE_DB "NAME"
getDBParts $SOURCE_DB "PORT"

TMP_DIR="./$(getDBParts $SOURCE_DB NAME)/"
echo "Create temporary directory at $TMP_DIR..."
mkdir -p $TMP_DIR

echo "mongodump -h $(getDBParts $SOURCE_DB HOSTNAME):$(getDBParts $SOURCE_DB PORT) -d $(getDBParts $SOURCE_DB NAME) -u $(getDBParts $SOURCE_DB USERNAME) -p $(getDBParts $SOURCE_DB PASSWORD) -o $TMP_DIR"
mongodump -h $(getDBParts $SOURCE_DB HOSTNAME):$(getDBParts $SOURCE_DB PORT) -d $(getDBParts $SOURCE_DB NAME) -u $(getDBParts $SOURCE_DB USERNAME) -p $(getDBParts $SOURCE_DB PASSWORD) -o $TMP_DIR

if [ "$?" != "0" ]; then
    echo "Dumping database failed..."
    exit 1
fi

echo "mongorestore -h $(getDBParts $TARGET_DB HOSTNAME):$(getDBParts $TARGET_DB PORT) -d $(getDBParts $TARGET_DB NAME) -u $(getDBParts $TARGET_DB USERNAME) -p $(getDBParts $TARGET_DB PASSWORD) $TMP_DIR$(getDBParts $SOURCE_DB NAME)/"
mongorestore -h $(getDBParts $TARGET_DB HOSTNAME):$(getDBParts $TARGET_DB PORT) -d $(getDBParts $TARGET_DB NAME) -u $(getDBParts $TARGET_DB USERNAME) -p $(getDBParts $TARGET_DB PASSWORD) $TMP_DIR$(getDBParts $SOURCE_DB NAME)/

if [ "$?" != "0" ]; then
    echo "Restoring database failed..."
    exit 1
fi

rm -rf $TMP_DIR

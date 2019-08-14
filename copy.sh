#!/bin/bash
#
# Copies database source to target source, expects two environment variable
# MONGODB_URI as target database
# MONGODB_URI_SRC as source database
MONGODB_TARGET_URL=${MONGODB_URI:-}
if [ ! -z ${MONGODB_TARGET_URL} ]; then
    echo "TARGET_DB: ${MONGODB_TARGET_URL}"
    TARGET_DB="${MONGODB_TARGET_URL}"
else
    echo "Target database is not set!"
    exit 1
fi

MONGODB_SOURCE_URL=${MONGODB_URI_SRC:-}
if [ ! -z ${MONGODB_SOURCE_URL} ]; then
    echo "SOURCE_DB: ${MONGODB_SOURCE_URL}"
    SOURCE_DB="${MONGODB_SOURCE_URL}"
else
    echo "Source database is not set!"
    exit 1
fi

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

# Checking whether we have data already on the database so we can skip
TMP_DIR_FOR_SRC="./$(getDBParts $TARGET_DB NAME)/"
echo "mongodump -h $(getDBParts $TARGET_DB HOSTNAME):$(getDBParts $TARGET_DB PORT) -c strapi_administrator -d $(getDBParts $TARGET_DB NAME) -u $(getDBParts $TARGET_DB USERNAME) -p $(getDBParts $TARGET_DB PASSWORD) -o $TMP_DIR_FOR_SRC"
mongodump -h $(getDBParts $TARGET_DB HOSTNAME):$(getDBParts $TARGET_DB PORT) -c strapi_administrator -d $(getDBParts $TARGET_DB NAME) -u $(getDBParts $TARGET_DB USERNAME) -p $(getDBParts $TARGET_DB PASSWORD) -o $TMP_DIR_FOR_SRC 2>&1
if [ "$?" == "0" ]; then
    echo "Skipping, database already restored..."
    rm -rf $TMP_DIR_FOR_SRC
    exit 0
fi

set -euo pipefail
set -x

echo "[Good] Empty database, begin now..."

TMP_DIR="./$(getDBParts $SOURCE_DB NAME)/"
echo "Create temporary directory at $TMP_DIR..."

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
 
echo "End copy database..."
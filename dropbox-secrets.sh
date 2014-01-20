#!/bin/sh

files="iphone/ActDropboxParams.h iphone/resources/Activities-Info.plist"

if [ $# -ne 2 ]; then
  echo "$0 APP-KEY APP-SECRET"
fi

app_key=$1
app_secret=$2

sed_commands="
  s/APP_KEY/${app_key}/g
  s/APP_SECRET/${app_secret}/g"

for f in $files; do
  sed -e "$sed_commands" <$f.src >$f || exit 1
done

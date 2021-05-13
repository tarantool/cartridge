#!/usr/bin/env bash

BRANCH=$BRANCH_NAME
ENDPOINT_URL=$S3_ENDPOINT_URL
S3_PATH=$S3_UPLOAD_PATH

# don't upload the '*.pickle' files
find .docoutput -name '*.pickle' -delete

# upload json and images
aws s3 sync .docoutput/json $S3_PATH/$BRANCH/json --endpoint-url=$ENDPOINT_URL --delete --include "*" --exclude "*.jpg" --exclude "*.png" --exclude "*.svg"
aws s3 sync .docoutput/json/_build_en/json/_images $S3_PATH/$BRANCH/images_en --endpoint-url=$ENDPOINT_URL --delete --size-only
aws s3 sync .docoutput/json/_build_ru/json/_images $S3_PATH/$BRANCH/images_ru --endpoint-url=$ENDPOINT_URL --delete --size-only

curl --data '{"update_key":"'"$TARANTOOL_UPDATE_KEY"'"}' --header "Content-Type: application/json" --request POST "$TARANTOOL_UPDATE_URL""$BRANCH"/

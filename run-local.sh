#!/usr/bin/env bash -e

# move to script path
cd `dirname $0`

# script to run and test hubot locally
# specify $PORT before using this

export HUBOT_LOG_LEVEL="debug"
export HUBOT_URL="http://localhost:$PORT"

export FEED_CHECK_INTERVAL=60

./node_modules/.bin/hubot

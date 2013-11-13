#!/usr/bin/env bash -e

# move to script path
cd `dirname $0`

# set the following env var before running this script
# * HUBOT_DOMAIN
# * HUBOT_GITHUB_TOKEN

export HUBOT_LOG_LEVEL="debug"

export HUBOT_IRC_ROOMS="#easyrpg"
export HUBOT_IRC_SERVER="irc.freenode.net"
export HUBOT_IRC_NICK="easyrpg-hubot"
export HUBOT_IRC_DEBUG=On
export HUBOT_IRC_UNFLOOD=100
export HUBOT_URL="http://${HUBOT_DOMAIN}/"

export FEED_CHECK_INTERVAL=60

# npm update

./node_modules/coffee-script/bin/coffee ./update.coffee
./node_modules/hubot/bin/hubot -a irc

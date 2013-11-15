# Description:
#   self pinger to avoid heroku idle
#
# Dependencies:
#   'request': '*'
#
# Configuration:
#   HUBOT_URL
#   HUBOT_SELF_PING_INTERVAL(optional, in seconds, default interval is 10 minute)
#
# Author:
#   Takeshi Watanabe

request = require 'request'

module.exports = (robot) ->
  ping_interval = null

  robot.brain.on 'loaded', ->
    interval = parseInt(process.env.HUBOT_SELF_PING_INTERVAL)
    interval = isNaN interval? 1000 * 60 * 10 : interval

    ping_interval = setInterval ->
      request.get process.env.HUBOT_URL, (e, r, body) ->
        robot.logger.debug "sent ping to #{process.env.HUBOT_URL}"
    , interval

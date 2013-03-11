# Description:
#   Feed Checker
#
# Dependencies:
#   'feedparser': '*'
#
# Configuration:
#   FEED_CHECK_INTERVAL
#
# Commands:
#   hubot check_feed <url> - add url to feed checker
#   hubot check_feed stop <url> - remove url from feed checker
#   hubot checking_feed - list all the checking urls
#
# Author:
#   take_cheeze

feedparser = require 'feedparser'

module.exports = (robot) ->
  feed_check_interval = null

  is_new = (articles, guid) ->
    ret = true
    articles.forEach (v) ->
      if v.guid == guid
        ret = false
    ret

  robot.brain.on 'loaded', ->
    if process.env.FEED_CHECK_INTERVAL? and isNaN parseInt(process.env.FEED_CHECK_INTERVAL)
      robot.logger.error 'Invalid feed check interval: ' + process.env.FEED_CHECK_INTERVAL

    robot.brain.data.feed_check ||= {}
    feed_check_interval = setInterval ->
      user = {}

      for url, prev of robot.brain.data.feed_check
        try
          feedparser.parseUrl url, (err, m, next) ->
            if err
              robot.logger.warning 'feed parsing error in (' + url + '): ' + err

            if prev.length != 0
              next.forEach (article) ->
                if is_new prev, article.guid
                  robot.send user, article.title + ' ' + article.link

            robot.brain.data.feed_check[url] = next
        catch err
          robot.logger.warning 'feed parsing error in (' + url + '): ' + err
    , 1000 * parseInt(process.env.FEED_CHECK_INTERVAL || (60 * 5).toString())

  robot.respond /check_feed (h[^ ]+)/i, (msg) ->
    url = msg.match[1]
    robot.brain.data.feed_check[url] = []
    msg.reply 'Subscribing to ' + url

  robot.respond /check_feed stop ([^ ]+)/i, (msg) ->
    url = msg.match[1]
    if robot.brain.data.feed_check[url]?
      msg.reply 'Unsubscribing from ' + url
      delete robot.brain.data.feed_check[url]
    else
      msg.reply url + ' isn`t subscribed'

  robot.respond /checking_feed/i, (msg) ->
    keys = Object.keys robot.brain.data.feed_check
    if keys.length == 0
      msg.reply 'No feed subscribed'
    else
      msg.reply 'Subscribed: ' + keys.join(' , ')

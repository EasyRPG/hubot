# Description:
#   Feed Checker
#
# Dependencies:
#   'feedparser': '*'
#   'request': '*'
#   'underscore': '*'
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
#   Takeshi Watanabe

FeedParser = require 'feedparser'
request = require 'request'
_ = require 'underscore'

module.exports = (robot) ->
  feed_check_interval = null

  # article with same guid not found
  is_new = (articles, guid) ->
    articles.every (v) ->
      v.guid != guid

  send_message = (feed_url, msg) ->
    usrs = robot.brain.data.feed_check_user[feed_url]
    sent = []
    for usr in usrs
      is_room = usr.room?
      continue if _.contains sent, (if is_room then usr.room else usr.id)

      if is_room
        robot.messageRoom usr.room, msg
      else
        robot.send usr, msg
      sent.push (if is_room then usr.room else usr.id)

  robot.brain.on 'loaded', ->
    interval = parseInt process.env.FEED_CHECK_INTERVAL
    interval = 60 * 5 if isNaN interval

    robot.logger.debug "setting feed check interval to: #{interval}"

    robot.brain.data.feed_check ||= {}
    robot.brain.data.feed_check_user ||= {}
    feed_check_interval = setInterval ->
      _.each robot.brain.data.feed_check, (prev, url) ->
        robot.logger.debug "checking feed: #{url}"

        next = []
        request.get(url).pipe(new FeedParser())
          .on 'error', (err) ->
            robot.logger.warning "feed parsing error in #{url}: #{err}"
          # ignore meta
          # .on 'meta', (meta) ->
          .on 'readable', ->
            while item = @read() then next.push item
          # all article parsed
          .on 'end', ->
            if prev.length != 0 then next.forEach (article) ->
              if is_new prev, article.guid
                send_message url, "new article: #{article.title} #{article.link} (from #{url})"
                send_message url, "summary: #{article.summary}" if article.summary?

            # save feed
            robot.brain.data.feed_check[url] = next
    , 1000 * interval

  robot.respond /check_feed (h[^ ]+)/i, (msg) ->
    url = msg.match[1]
    robot.brain.data.feed_check[url] ||= []
    robot.brain.data.feed_check_user[url] ||= []
    robot.brain.data.feed_check_user[url].push msg.message.user
    msg.reply "Subscribing to #{url}"

  robot.respond /check_feed stop ([^ ]+)/i, (msg) ->
    url = msg.match[1]
    if robot.brain.data.feed_check[url]?
      msg.reply "Unsubscribing from #{url}"
      delete robot.brain.data.feed_check[url]
      delete robot.brain.data.feed_check_user[url]
    else
      msg.reply "#{url} isn`t subscribed"

  robot.respond /checking_feed/i, (msg) ->
    keys = Object.keys robot.brain.data.feed_check
    if keys.length == 0
      msg.reply 'No feed subscribed'
    else
      msg.reply "Subscribed: #{keys.join(' , ')}"

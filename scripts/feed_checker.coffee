# Description:
#   Feed Checker
#
# Dependencies:
#   'feedparser': '*'
#   'request': '*'
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

module.exports = (robot) ->
  feed_check_interval = null

  # article with same guid not found
  is_new = (articles, guid) ->
    articles.every (v) ->
      v.guid != guid

  robot.brain.on 'loaded', ->
    interval = parseInt process.env.FEED_CHECK_INTERVAL
    if isNaN interval then interval = 60 * 5

    robot.logger.debug "setting feed check interval to: #{interval}"

    robot.brain.data.feed_check ||= {}
    feed_check_interval = setInterval ->
      user = {}

      for url, prev of robot.brain.data.feed_check
        robot.logger.debug "checking feed: #{url}"

        next = []
        request.get(url).pipe(new FeedParser())
          .on 'error', (err) ->
            robot.logger.warning "feed parsing error in #{url}: #{err}"
          # ignore meta
          # .on 'meta', (meta) ->
          .on 'readable', ->
            while item = this.read() then next.push item
          .on 'end', ->
            if prev.length != 0 then next.forEach (article) ->
              if is_new prev, article.guid
                robot.send user, "new article: #{article.title} #{article.link}"
                if article.summary? then robot.send user, "summary: #{article.summary}"

            # save feed
            robot.brain.data.feed_check[url] = next
    , 1000 * interval

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

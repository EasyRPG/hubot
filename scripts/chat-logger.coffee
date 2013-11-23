# Description:
#   Chat logger with web interface like help command.
#
# Commands:
#   hubot log today - returns today's log URL
#   hubot log yesterday - returns yesterday's log URL
#   hubot log [<year>/]<month>/<date> - returns log URL of specific day
#   hubot log search <regex> - returns search url of specific regex
#   hubot log feed - returns log feed URL
#
# Dependencies
#   feed: "*"
#   underscore: "*"
#   linkify: "*"
#   escape-html: "*"
#
# Configuration:
#   HUBOT_URL
#
# URLS:
#   /hubot/log/<room>
#   /hubot/log/<room>/feed
#   /hubot/log/<room>/search?q=<QUERY>
#   /hubot/log/<room>/<year>/
#   /hubot/log/<room>/<year>/<month>
#   /hubot/log/<room>/<year>/<month>/date
#
# Notes:
#   UTC time is used
#   feed type is atom
#   search finds last 50 matched text

QS = require 'querystring'
Feed = require 'feed'
_ = require 'underscore'
linkify = require 'linkify'
escape_html = require 'escape-html'
sprintf = require 'sprintf'

ITEM_COUNT = 50
FEED_DIVIDE_THRESHOLD = 1000 * 60 * 10 # 10 minutes

render = (title, lines) ->

  """
<html>
  <head>
    <title>#{title}</title>
    <style type="text/css">
      body {
        background: #ffffff;
        color: #000000;
      }

      p {
        border-bottom: 1px solid
      }
      p {
        border: 0;
      }
    </style>
  </head>

  <body>
    <div class="commands">
      #{lines.join("\n")}
    </div>
  </body>
</html>
  """

module.exports = (robot) ->
  escape_room = (room) ->
    room.replace(/[^\w]/, '-', 'g').replace(/-+(.*)-+/, '$1')

  message_type = (msg) ->
    ret =
      if msg instanceof LeaveMessage then 'leave'
      else if msg instanceof EnterMessage then 'enter'
      else if msg instanceof TopicMessage then 'topic'
      else if msg instanceof TextMessage then 'text'
      else 'other'

  chat_data = -> robot.brain.data.chat_logger

  date_url = (room, year, month, date) ->
    "#{process.env.HUBOT_URL}/#{robot.name}/log/#{escape_room room}/#{year}/#{month}/#{date}"

  # brain
  robot.brain.on 'loaded', =>
    robot.brain.data.logger ||= {}

  # commands
  robot.respond /log\s+today$/, (msg) ->
    now = new Date()
    msg.reply date_url(msg.envelope.room, now.getUTCFullYear(), now.getUTCMonth(), now.getUTCDate())

  robot.respond /log\s+yesterday$/, (msg) ->
    yest = new Date(Date.yest() - 1000 * 60 * 60 * 24)
    msg.reply date_url(msg.envelope.room, yest.getUTCFullYear(), yest.getUTCMonth(), yest.getUTCDate())

  robot.respond /log\s+([1-9]\d{3})?\/([1-9]\d{0,1})\/([1-9]\d{0,1})/, (msg) ->
    msg.reply date_url(msg.envelope.room, msg.match[1] || new Date().getUTCFullYear(), msg.match[2], msg.match[3])

  robot.respond /log\s+search (.*)$/, (msg) ->
    msg.reply "#{process.env.HUBOT_URL}/#{robot.name}/log/#{escape_room msg.envelope.room}/search?#{QS.stringify { q: msg.match[1]}}"

  robot.respond /log\s+search (.*)$/, (msg) ->
    msg.reply "#{process.env.HUBOT_URL}/#{robot.name}/log/#{escape_room msg.envelope.room}/feed"

  # events
  log_message = (msg) ->
    unless msg.room
      robot.logger.debug "msg without room: #{msg}"
      return

    room = msg.room
    msg_data =
      nick: msg.user.name
      type: message_type msg
      date: Date.now()
    msg_data['text'] = msg.text if msg instanceof TextMessage

    t = new Date msg_data.date
    data = chat_data()[room] ||= {}
    data = data[t.getUTCFullYear()] ||= []
    data = data[t.getUTCMonth()] ||= []
    data = data[t.getUTCDate()] ||= []
    data.push msg_data

  robot.enter (msg) -> log_message msg
  robot.leave (msg) -> log_message msg
  robot.topic (msg) -> log_message msg
  robot.hear /.*/, (msg) -> log_message msg

  # web interface
  search_items = (query) ->

  generate_time_string = (d) ->
    d = new Date d if d instanceof Number
    sprintf '%02d:%02d.%04d', d.getUTCMinutes(), d.getUTCSeconds(), d.getUTCMilliseconds()

  render_item = (item) ->
    switch item.type
      when 'text' then msg = "> #{item.text}"
      when 'topic' then msg = "changed topic: #{item.text}"
      when 'enter' then msg = "entered the room"
      when 'leave' then msg = "leaved the room"
      when 'other' then msg = "unknown message type: #{item}"
    time_str = generate_time_string item.date
    "<p id=\"#{time_str}\">#{time_str} #{item.name} #{linkify escape_html(msg), 'html'}</p>"

  render_items = (title, items) ->

  render_links = (title, base, items) ->
    render title, items.map (v) ->
      "<p><a href=\"#{process.env.HUBOT_URL}/#{base}/#{v}\">#{v}</a></p>"

  not_found = (res) ->
    res.type 'text/plain'
    res.send 404, 'not found'

  send_links = (res, title, base, links) ->
    if links.length == 0 then not_found res
    else
      res.type 'text/html'
      res.send render_links base, links

  list_feed_item = (room) ->
    src = chat_data()[room]
    years = _.keys(src).sort().reverse()

    result = []

    try
      for year in years
        year.reduceRight (prev, month) ->
          month.reduceRight (prev, day) ->
            day.reduceRight (result, msg) ->
              if result.length == 0 or _.first(_.first result).date - msg.date >= FEED_DIVIDE_THRESHOLD
                result.unshift [msg]
              else
                _.last(result).unshift msg

              throw "break" if result.length > ITEM_COUNT
            , result

    result.slice(0, ITEM_COUNT).map (v) ->
      f = _.first(v)
      d = new Date f.date

      title: d.toUTCString()
      link: "#{process.env.HUBOT_URL}/#{robot.name}/log/#{room}/#{d.getUTCFullYear()}/#{d.getUTCMonth()}/#{d.getUTCDate()}\##{generate_time_string d}"
      description:
        v.map (v) -> render_item v
        .reduce (ret, v) ->
          ret + v
        , ''
      date: new Date f.date

  robot.router.get "/#{robot.name}/log/:room/feed", (req, res) ->
    feed = new Feed
      title: 'hubot log'
      description: "log of room: #{req.param.room}"
      link: "#{process.env.HUBOT_URL}/#{robot.name}/log/#{req.param.room}/feed"
    feed.item v for v in list_feed_item req.param.room if chat_data()[req.param.room]
    res.type 'application/atom+xml'
    res.send feed.render 'atom-1.0'

  robot.router.get "/#{robot.name}/log/:room/search", (req, res) ->
    res.type 'text/html'
    res.send render_items search_items req.query.q

  robot.router.get "/#{robot.name}/log/:room", (req, res) ->
    room = req.param.room

    # years
    years = _.keys(chat_data()[room]).sort()
    links = years

    if chat_data()[room]?
      # months of last year
      last_year = _.last(years)
      for idx,v in chat_data()[room][last_year]
        links.push "#{last_year}/#{idx}" if v

      # days of last month
      last_month = chat_data()[room][last_year].length - 1
      for idx,v in chat_data()[room][last_year][last_month]
        links.push "#{last_year}/#{last_month}/#{idx}" if v

    send_links res, "#{robot.name}/log/#{room}", links

  robot.router.get "/#{robot.name}/log/:room/:year", (req, res) ->
    links = []
    year = parseInt req.param.year
    if chat_data()[room]?[year]?
      links.push "#{idx}" if v for idx,v in chat_data()[room][year]
    send_links res, "#{year}", "/#{robot.name}/log/#{room}/#{year}", links

  robot.router.get "/#{robot.name}/log/:room/:year/:month", (req, res) ->
    links = []
    year = parseInt req.param.year
    month = parseInt req.param.month
    if chat_data()[room]?[year]?[month]?
      links.push "#{idx}" if v for idx,v in chat_data()[room][year][month]
    send_links res, "#{year}/#{month}", "#{robot.name}/log/#{room}/#{year}/#{month}", links

  robot.router.get "/#{robot.name}/log/:room/:year/:month/:date", (req, res) ->
    room = req.param.room
    year = req.param.year
    month = parseInt req.param.month
    date = parseInt req.param.date
    if chat_data()[room]?[year]?[month]?[date]?
      res.type 'text/html'
      res.send render_items "#{year}/#{month}/#{date}", chat_data()[room]?[year]?[month]?[date]?
    else not_found res

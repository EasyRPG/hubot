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

      strong {
        background: #ffff00;
      }

      p {
        border-bottom: 1px solid;
        border-bottom-color: #000000;
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
    room.replace(/[^\w]/, '-', 'g').replace(/^-*(.*)-*$/, '$1')

  chat_data = -> robot.brain.data.chat_logger

  base_path = "#{robot.name}/log"
  base_url = "#{process.env.HUBOT_URL.replace /\/*$/, ''}/#{base_path}"

  date_url = (room, year, month, date) ->
    "#{base_url}/#{escape_room room}/#{year}/#{month}/#{date}"

  # brain
  robot.brain.on 'loaded', =>
    robot.brain.data.chat_logger ||= {}

  # commands
  robot.respond /log\s+today/, (msg) ->
    now = new Date()
    msg.reply date_url(msg.envelope.room, now.getUTCFullYear(), now.getUTCMonth() + 1, now.getUTCDate())

  robot.respond /log\s+yesterday/, (msg) ->
    yest = new Date(Date.now() - 1000 * 60 * 60 * 24)
    msg.reply date_url(msg.envelope.room, yest.getUTCFullYear(), yest.getUTCMonth() + 1, yest.getUTCDate())

  robot.respond /log\s+([1-9]\d{3})?\/([1-9]\d{0,1})\/([1-9]\d{0,1})/, (msg) ->
    msg.reply date_url(msg.envelope.room, msg.match[1] || new Date().getUTCFullYear(), msg.match[2], msg.match[3])

  robot.respond /log\s+search (.*)$/, (msg) ->
    msg.reply "#{base_url}/#{escape_room msg.envelope.room}/search?#{QS.stringify { q: msg.match[1]}}"

  robot.respond /log\s+feed/, (msg) ->
    msg.reply "#{base_url}/#{escape_room msg.envelope.room}/feed"

  # events
  log_message = (t, msg) ->
    unless msg.envelope.room?
      robot.logger.debug "envelope without room: #{JSON.stringify msg.envelope}"
      return

    room = escape_room msg.envelope.room
    msg_data =
      nick: msg.envelope.user.name
      type: t
      date: Date.now()
    msg_data['text'] = msg.message.text if msg.message.text?

    t = new Date msg_data.date
    data = chat_data()[room] ||= {}
    data = data[t.getUTCFullYear()] ||= []
    data = data[t.getUTCMonth() + 1] ||= []
    data = data[t.getUTCDate()] ||= []
    data.push msg_data

    robot.logger.debug "adding #{room} #{t.toUTCString()}: #{JSON.stringify msg_data}"

  robot.enter (msg) -> log_message 'enter', msg
  robot.leave (msg) -> log_message 'leave', msg
  robot.topic (msg) -> log_message 'topic', msg
  robot.hear /.*/, (msg) -> log_message 'text', msg

  # web interface
  search_items = (room, query) ->
    src = chat_data()[room]
    query = new RegExp query, 'gi'
    result = []

    try
      for year in _.keys(src).sort().reverse()
        src[year].reduceRight (prev, month) ->
          return unless month
          month.reduceRight (prev, day) ->
            return unless day
            day.reduceRight (prev, msg) ->
              result.push msg if query.test JSON.stringify msg
              throw "break" if result.length >= ITEM_COUNT
            , null
          , null
        , null
    catch e
      throw e if e != "break"

    result

  generate_time_string = (d) ->
    d = new Date d unless d instanceof Date
    sprintf '%02d:%02d:%02d.%04d', \
      d.getUTCHours(), d.getUTCMinutes(), d.getUTCSeconds(), d.getUTCMilliseconds()

  render_item = (item, room, query) ->
    switch item.type
      when 'text' then msg = "> #{item.text}"; color = 'black'
      when 'topic' then msg = "changed topic: #{item.text}"; color = 'gray'
      when 'enter' then msg = "entered the room"; color = 'blue'
      when 'leave' then msg = "leaved the room"; color = 'pink'
      else msg = "unknown message type: #{item}"; color = 'yellow'
    d = new Date item.date
    time_str = generate_time_string d
    time_txt = "<a href=\"#{base_url}/#{room}/#{d.getUTCFullYear()}/#{d.getUTCMonth() + 1}/#{d.getUTCDate()}\##{time_str}\">#{time_str}</a>"
    txt = escape_html msg
    txt = txt.replace new RegExp("(#{query})", 'gi'), '<strong>$1</strong>' if query
    "<p id=\"#{time_str}\" style=\"color:#{color}\">#{time_txt} <b>#{item.nick}</b> #{linkify txt, 'html'}</p>"

  render_items = (title, room, items, query) ->
    render title, items.map (v) -> render_item v, room, query

  render_links = (base, items) ->
    render "#{base_path}/#{base}", items.map (v) ->
      "<p><a href=\"#{base_url}/#{base}/#{v}\">#{v}</a></p>"

  not_found = (res) ->
    res.type 'text/plain'
    res.send 404, 'not found'

  send_links = (res, base, links) ->
    if links.length == 0 then not_found res
    else
      res.type 'text/html'
      res.send render_links base, links

  list_feed_item = (room) ->
    src = chat_data()[room]
    result = []

    try
      for year in _.keys(src).sort().reverse()
        src[year].reduceRight (prev, month) ->
          month && month.reduceRight (prev, day) ->
            day && day.reduceRight (prev, msg) ->
              if result.length == 0 or _.last(_.last result).date - msg.date >= FEED_DIVIDE_THRESHOLD
                result.push [msg]
              else
                _.first(result).unshift msg

              throw "break" if result.length > ITEM_COUNT
            , null
          , null
        , null
    catch e
      throw e if e != "break"

    result.slice(0, ITEM_COUNT).reverse().map (v) ->
      title = _.last(v)
      d = new Date title.date

      title: d.toUTCString()
      author:
        name: title.nick
      link: "#{base_url}/#{room}/#{d.getUTCFullYear()}/#{d.getUTCMonth() + 1}/#{d.getUTCDate()}\##{generate_time_string d}"
      description:
        v.map (msg) ->
          render_item msg, room
        .join "\n"
      date: d

  robot.router.get "/#{base_path}/:room/feed", (req, res) ->
    feed = new Feed
      title: 'hubot log'
      description: "log of room: #{req.params.room}"
      author:
        name: robot.name
        link: base_url
      link: "#{base_url}/#{req.params.room}/feed"
    if chat_data()[req.params.room]?
      list_feed_item(req.params.room).forEach (v) -> feed.addItem v
    res.type 'application/atom+xml'
    res.send feed.render 'atom-1.0'

  robot.router.get "/#{base_path}/:room/search", (req, res) ->
    if chat_data()[req.params.room]?
      res.type 'text/html'
      res.send render_items \
        "Search result of #{req.query.q}", req.params.room, \
        search_items(req.params.room, req.query.q), req.query.q
    else not_found

  robot.router.get "/#{base_path}/:room", (req, res) ->
    room = req.params.room
    links = []

    if chat_data()[room]?
      # years
      years = _.keys(chat_data()[room]).sort()
      links = years

      # months of last year
      last_year = _.last(years)
      for idx,v of chat_data()[room][last_year]
        links.push "#{last_year}/#{idx}" if v

      # days of last month
      last_month = chat_data()[room][last_year].length - 1
      for idx,v of chat_data()[room][last_year][last_month]
        links.push "#{last_year}/#{last_month}/#{idx}" if v

    send_links res, "#{room}", links

  robot.router.get "/#{base_path}/:room/:year", (req, res) ->
    links = []
    room = req.params.room
    year = parseInt req.params.year
    if chat_data()[room]?[year]?
      for idx,v of chat_data()[room][year]
        links.push "#{year}/#{idx}" if v
    send_links res, "#{room}", links

  robot.router.get "/#{base_path}/:room/:year/:month", (req, res) ->
    links = []
    room = req.params.room
    year = parseInt req.params.year
    month = parseInt(req.params.month)
    if chat_data()[room]?[year]?[month]?
      for idx,v of chat_data()[room][year][month]
        links.push "#{year}/#{month}/#{idx}" if v
    send_links res, "#{room}", links

  robot.router.get "/#{base_path}/:room/:year/:month/:date", (req, res) ->
    room = req.params.room
    year = req.params.year
    month = parseInt(req.params.month)
    date = parseInt req.params.date
    if chat_data()[room]?[year]?[month]?[date]?
      res.type 'text/html'
      res.send render_items "#{year}/#{month}/#{date}", room, chat_data()[room][year][month][date]
    else not_found res

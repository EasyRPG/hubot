#!/usr/bin/env coffee

request = require 'request'
fs = require 'fs'

hubot_files = [
  "events", "google-images", "help", "httpd",
  "maps", "math", "ping", "pugme",
  "roles", "rules", "storage", "translate",
  "youtube",
]

hubot_script_files = [ "redis-brain", "octospy", ]

SCRIPT_PATH = __dirname + "/scripts"

fs.mkdirSync SCRIPT_PATH if not fs.existsSync SCRIPT_PATH

hubot_files.forEach (v) ->
  request.get "https://github.com/github/hubot/raw/master/src/scripts/#{v}.coffee", (e, r, b) ->
    if e
      console.error(e)
      throw e
    console.log "downloading: #{v}"
    fs.writeFileSync "#{SCRIPT_PATH}/#{v}.coffee", b

hubot_script_files.forEach (v) ->
  request.get "https://github.com/github/hubot-scripts/raw/master/src/scripts/#{v}.coffee", (e, r, b) ->
    if e
      console.error(e)
      throw e
    console.log "downloading: #{v}"
    fs.writeFileSync "#{SCRIPT_PATH}/#{v}.coffee", b

# Description:
#   Logs all messages on an irc channel
#
# Dependencies:
#   Tempus
#   mkdirp
#   express
#   jade
#
# Configuration:
#   IRCLOGS_FOLDER
#   HUBOT_LOGGER_HTTP_LOGIN
#   HUBOT_LOGGER_HTTP_PASSWORD
#
# Commands:
#   hubot otr - not yer implemented
#
# Author:
#   adragomir

# CREATE TABLE IF NOT EXISTS chanlog (id INTEGER PRIMARY KEY, ts INTEGER, chan VARCHAR(32), user VARCHAR(100), message TEXT);
{Robot, Adapter, TextMessage, EnterMessage, LeaveMessage, CatchAllMessage} = require 'hubot'
express = require "express"
fs = require "fs"
path = require "path"
sys = require "sys"
util = require "util"
Tempus = require "Tempus"
mkdirp = require("mkdirp").sync

log_streams = {}

log_message = (root, date, type, channel, meta) ->
  mkdirp(path.resolve root, channel)
  log_file = path.resolve root, channel, date.toString("%Y-%m-%d") + '.txt'
  meta.date = date
  meta.channel = channel
  meta.type = type
  fs.appendFile log_file, JSON.stringify(meta) + '\n', (err) ->
    if err
      throw err

render_log = (req, res, channel, file, date, dates, latest) ->
  stream = fs.createReadStream(file, { encoding: 'utf8' })
  buffer = ''
  events = []
  pad2 = (n) ->
    return '0' + n if n < 10
    return '' + n

  parse_events = (last) ->
    rows = buffer.split('\n')
    if last
      until_row = rows.length - 1
    else
      until_row = rows.length

    i = 0
    while i < until_row
      json = rows[i]
      i++
      continue unless json?

      event = null
      try
        event = JSON.parse(json)
      catch e
        null
      
      continue unless event?

      event.date = new Tempus(event.date)
      event.time = event.date.toString("%H:%M:%S")
      event.timestamp = event.date.toString("%H:%M:%S:%L")
      continue unless event.date?

      events.push(event)

    if !last
      buffer = rows[rows.length - 1] || ''
    else
      buffer = ''

  stream.on 'data', (data) ->
    buffer += data
    parse_events(false)

  stream.on 'end', () ->
    parse_events(true)
    indexPosition = dates.indexOf(date)
    res.render('log', {
      events: events,
      channel: channel,
      page: date,
      previous: dates[indexPosition - 1],
      next: dates[indexPosition + 1],
      isLatest: latest
    })

  stream.on 'error', (err) ->
    stream.destroy()
    res.send('' + err, 404)

module.exports = (robot) ->
    # init logging
    util.puts(util.inspect(robot))
    util.puts(util.inspect(robot.adapter.bot))
    util.puts(util.inspect(robot.adapter.bot.opt.channels))
    logs_root = process.env.IRCLOGS_FOLDER || "/var/irclogs/logs"
    mkdirp(logs_root)

    # robot.adapter.bot.on 'pm', (nick, text, message) ->
    #   util.puts("PM--------------")
    #   util.puts(util.inspect(message))

    # robot.adapter.bot.on 'ctcp', (nick, text, message) ->
    #   util.puts("CTCP--------------")
    #   util.puts(util.inspect(message))

    # robot.adapter.bot.on 'raw', (message) ->
    #   util.puts("RAW--------------")
    #   util.puts(util.inspect(message))

    robot.adapter.bot.on 'message', (nick, to, text, message) ->
      result = (text + '').match(/^\x01ACTION (.*)\x01$/)
      if !result
        log_message(logs_root, new Tempus(), "message", to, {nick: nick, message: text, raw: message })
      else
        log_message(logs_root, new Tempus(), "action", to, {nick: nick, action: result[1], raw: message })
    
    robot.adapter.bot.on 'nick', (oldnick, newnick, channels, message) ->
      for channel in channels
        log_message(logs_root, new Tempus(), "nick", channel, {nick: oldnick, new_nick: newnick })
        
    robot.adapter.bot.on 'topic', (channel, topic, nick, message) ->
      log_message(logs_root, new Tempus(), "topic", channel, {nick: nick, topic: topic })

    robot.adapter.bot.on 'join', (channel, nick, message) ->
      log_message(logs_root, new Tempus(), "join", channel, { nick: nick })

    robot.adapter.bot.on 'part', (channel, nick, reason, message) ->
      log_message(logs_root, new Tempus(), "part", channel, { nick: nick, reason: reason })

    robot.adapter.bot.on 'quit', (nick, reason, channels, message) ->
      for channel in channels
        log_message(logs_root, new Tempus(), "quit", channel, { nick: nick, reason: reason })

    # robot.logger_orig_receive = robot.receive
    # robot.receive = (message) ->
    #   util.puts(util.inspect(message))
    #   robot.logger_orig_receive(message)

    # robot.hear /.*$/i, (msg) ->
    #   util.puts(util.inspect(msg))

    # init app
    port = process.env.IRCLOGS_PORT || 8086
    robot.logger_app = express()
    robot.logger_app.configure( ->
      robot.logger_app.set 'views', __dirname + '/../views'
      robot.logger_app.set 'view options', { layout: true }
      robot.logger_app.set 'view engine', 'jade'
      robot.logger_app.use express.bodyParser()
      robot.logger_app.use express.methodOverride()
      if process.env.HUBOT_LOGGER_HTTP_LOGIN? && process.env.HUBOT_LOGGER_HTTP_PASSWORD?
        robot.logger_app.use express.basicAuth process.env.HUBOT_LOGGER_HTTP_LOGIN, process.env.HUBOT_LOGGER_HTTP_PASSWORD
      robot.logger_app.use robot.logger_app.router
    )

    robot.logger_app.get "/irclogs", (req, res) ->
      res.redirect "/irclogs/channels"

    robot.logger_app.get "/irclogs/channels", (req, res) ->
      files = fs.readdirSync(logs_root)
      res.render('channels.jade', {
        channels: files,
        title: 'channel index'
      })

    robot.logger_app.get "/irclogs/:channel/index", (req, res) ->
      channel = req.params.channel
      fs.readdir logs_root + "/" + channel, (err, filenames) ->
        if err
          res.send '' + err, 404

        dates = filenames.map (filename) ->
          filename.replace(/\..*$/, '')
        dates.sort().reverse()

        res.render('index.jade', {
          dates: dates,
          channel: channel,
          page: 'index'
        })

    robot.logger_app.get "/irclogs/:channel/latest", (req, res) ->
      channel = req.params.channel
      fs.readdir logs_root + "/" + channel, (err, filenames) ->
        if err
          res.send '' + err, 404

        dates = filenames.map (filename) ->
          filename.replace(/\..*$/, '')
        dates.sort()

        date = dates[dates.length - 1] 
        render_log(req, res, channel, path.resolve(logs_root, channel, date + ".txt"), date, dates, true)

    robot.logger_app.get "/irclogs/:channel/:date", (req, res) ->
      channel = req.params.channel
      fs.readdir logs_root + "/" + channel, (err, filenames) ->
        if err
          res.send '' + err, 404

        dates = filenames.map (filename) ->
          filename.replace(/\..*$/, '')
        dates.sort()

        date = req.params.date
        render_log(req, res, channel, path.resolve(logs_root, channel, date + ".txt"), date, dates, true)

    robot.logger_app.listen(port)

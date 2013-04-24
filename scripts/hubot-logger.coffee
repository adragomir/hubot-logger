# CREATE TABLE IF NOT EXISTS chanlog (id INTEGER PRIMARY KEY, ts INTEGER, chan VARCHAR(32), user VARCHAR(100), message TEXT);
{Robot, Adapter, TextMessage, EnterMessage, LeaveMessage, CatchAllMessage} = require 'hubot'
fs = require "fs"
path = require "path"
sys = require "sys"
util = require "util"
Tempus = require "Tempus"
mkdirp = require "mkdirp"

views_location = path.resolve __dirname, 'views'

log_streams = {}

log_message = (root, date, type, room, user, text) ->
  stream = get_stream(root, date, room)
  stream.write JSON.stringify({"date": date, "type": type, "room": room, "user": user, "text": text}) + '\n'

get_stream = (root, date, room) -> 
  if log_streams.hasOwnProperty room
    if log_streams[room].date.toString("%Y-%m-%d") != date.toString("%Y-%m-%d")
      log_streams[room].stream.end()
      log_streams[room].stream = create_stream root, date, room
      log_streams[room].date = date
  else
    log_streams[room].stream = create_stream root, date, room
    log_streams[room].date = date
  log_streams[room].stream

create_stream = (root, date, room) ->
  log_file = path.resolve root, room, date + '.txt'
  fs.createWriteStream(logFile, {
    flags: 'a+',
    mode: '0666',
    encoding: 'utf8'
  })


module.exports = (robot) ->
    logs_location = process.env.IRCLOGS_FOLDER || "/var/irclogs/logs"
    mkdirp.sync(logs_location)

    robot.sms_orig_receive = robot.receive
    robot.receive = (message) ->
        if message instanceof TextMessage
            room = message.room
            text = message.text
            user = message.user.name
            type = "message"
        if message instanceof LeaveMessage
            room = message.room
            user = message.user.name
            text = util.format("%s has left %s", user, room)
            type = "quit"
        if message instanceof EnterMessage
            room = message.room
            user = message.user.name
            text = util.format("%s has joined %s", user, room)
            type = "enter"
        now = new Tempus().UTCDate()
        log_message logs_location, now, type, room, user, text
        robot.sms_orig_receive(message)

    robot.router.set "view engine", "jade"

    robot.router.get "/irclogs", (req, res) ->
      res.redirect "/irclogs/channels"

    robot.router.get "/irclogs/channels", (req, res) ->
      files = fs.readdirSync(logs_location)
      res.render(path.resolve(views_location, 'channels.jade'), {
        channels: files,
        title: 'channel index'
      })

    robot.router.get "/irclogs/:room", (req, res) ->
        d = new Date()
        room = req.params.room

    robot.router.get "/irclogs/:room/:date", (req, res) ->
        start_date = new Tempus(new Date(req.params.date))
        end_date = start_date.clone().addDate(1)
        util.puts("from: " + start_date)
        util.puts("to: " + end_date)
        room = req.params.room

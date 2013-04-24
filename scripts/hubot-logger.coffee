# CREATE TABLE IF NOT EXISTS chanlog (id INTEGER PRIMARY KEY, ts INTEGER, chan VARCHAR(32), user VARCHAR(100), message TEXT);
{Robot, Adapter, TextMessage, EnterMessage, LeaveMessage, CatchAllMessage} = require 'hubot'
sys = require "sys"
util = require "util"

Tempus = require "Tempus"
sqlite = require "sqlite3"

module.exports = (robot) ->
    location = process.env.SQLITE_LOGS || "/var/irclogs/irclogs.sqlite"
    db = new sqlite.Database location
    robot.sms_orig_receive = robot.receive
    robot.receive = (message) ->
        if message instanceof TextMessage
            room = message.room
            text = message.text
            user = message.user.name
        if message instanceof LeaveMessage
            room = message.room
            user = message.user.name
            text = util.format("%s has left %s", user, room)
        if message instanceof EnterMessage
            room = message.room
            user = message.user.name
            text = util.format("%s has joined %s", user, room)
        db.run("insert into chanlog(ts, chan, user, message) VALUES (?, ?, ?, ?)", new Date, room, user, text) if room? and user? and text?
        robot.sms_orig_receive(message)

    robot.router.get "/irclogs/:room", (req, res) ->
        d = new Date()
        room = req.params.room
        db.all "select * from chanlog where chan = ? order by ts asc limit 10000", room, (err, rows) ->
            s = ""
            for row in rows
                s += "[" + new Tempus(row.ts).toString("%Y-%m-%d %H:%M:%S") + "] <" + row.user + "> " + row.message + "\n"
            res.end s

    robot.router.get "/irclogs/:room/:date", (req, res) ->
        start_date = new Tempus(new Date(req.params.date))
        end_date = start_date.clone().addDate(1)
        room = req.params.room
        db.all "select * from chanlog where chan = ? and ts between ? and ? order by ts asc limit 10000", [room, start_date, end_date], (err, rows) ->
            s = ""
            for row in rows
                s += "[" + new Tempus(row.ts).toString("%Y-%m-%d %H:%M:%S") + "] <" + row.user + "> " + row.message + "\n"
            res.end s

#vim:set expandtab sw=4 ts=4

# Description:
#   Personal Time Tracker
#
# Commands:
#   hubot tt start <project>/<task> - Start tracking on project/task
#   hubot tt stop - Stop current tracking
#   hubot tt report - Report tracking data of you
#   hubot tt reset - Reset database (Clear all trackings of you)
#
# Notes:
#   All tracking data are stored only in memory.
#   That is, those are lost when bot exits.
#
# Author:
#   Jin Araki <jinzam.rock@gmail.com>

class Track

  constructor: (track) ->
    {@project, @task, @timeIn, @timeOut, @timeHours} = track
    @project ?= 'no data'
    @task ?= 'no data'
    @timeIn ?= null
    @timeOut ?= null
    @timeHours ?= 0
    @taskId = "#{@project}/#{@task}"


class TimeTracker

  constructor: (@robot) ->
    @isTracking = false
    @db = []

  start: (now, track) ->
    @stop now if @isTracking
    @isTracking = true
    track.timeIn = now
    @db.push(track)

  stop: (now) ->
    if @isTracking
      t = @db[@db.length - 1]
      t.timeOut = now
      t.timeHours = (now.getTime() - t.timeIn.getTime()) / 1000 / 60 / 60
      @isTracking = false

  list: (opt) ->

    if opt.filterBy is 'today'
      now = new Date
      today = now.toDateString()
      list = (t for t in @db when t.timeIn.toDateString() is today)
    else
      list = @db[..]

    if opt.groupBy is 'task'
      taskIds = new Set(t.taskId for t in @db)
      merged_list = []
      taskIds.forEach (taskId) ->
        track = list.filter (t) ->
            t.taskId is taskId
          .reduce (x, y) ->
            x.project = y.project
            x.task = y.task
            x.timeHours ?= 0
            x.timeHours += y.timeHours
            x
          , {}
        merged_track = new Track track
        merged_list.push(merged_track)
      list = merged_list
    list

  reset: ->
    @isTracking = false
    @db = []


module.exports = (robot) ->

  # {'username': [Track, ...], ...}
  time_tracker_db = {}

  # Start tracking
  robot.respond /tt start (.+)\/(.+)/i, (res) ->

    username = res.message.user.name
    if time_tracker_db[username]?
      tt = time_tracker_db[username]
    else
      tt = time_tracker_db[username] = new TimeTracker robot

    project = res.match[1]
    task = res.match[2]
    track = new Track project: project, task: task

    now = new Date
    tt.start now, track
    res.send "#{username} started #{project}/#{task}"

  # Stop tracking
  robot.respond /tt stop/i, (res) ->

    username = res.message.user.name
    tt = time_tracker_db[username]
    tt?.stop new Date
    res.send "#{username} stopped tracking"

  # Report tracking data
  robot.respond /tt report/i, (res) ->

    username = res.message.user.name
    tt = time_tracker_db[username]

    list = tt?.list filterBy: 'today', groupBy: 'task' or []
    md_manhour = list.map (t) ->
        "|#{t.project}|#{t.task}|#{t.timeHours.toFixed(2)}|"
      .join '\n'

    list = tt?.list filterBy: 'today' or []
    md_timesheet = list.map (t) ->
        "|#{t.timeIn.toLocaleTimeString()}|#{t.timeOut?.toLocaleTimeString() or ''}|#{t.timeHours.toFixed(2)}|#{t.project}|#{t.task}|"
      .join '\n'

    md_contents = """
    ### #{new Date().toDateString()} -- #{username}
    #### Man-hour

    | Project | Task | Hours |
    | ------- | ---- | ----- |
    #{md_manhour}

    #### Time-sheet

    | In | Out | Hours | Project | Task |
    | -- | --- | ----- | ------- |----- |
    #{md_timesheet}
    """
    res.send md_contents

  # Reset database
  robot.respond /tt reset/i, (res) ->

    username = res.message.user.name
    tt = time_tracker_db[username]
    tt?.reset()
    res.send "Clear tracking data of #{username}"
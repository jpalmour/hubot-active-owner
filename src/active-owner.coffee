# Description
#   Let Hubot keep track of who is on AO duty for each team
#
# Configuration:
#   LIST_OF_ENV_VARS_TO_SET
#
# Commands:
#   hubot show|list AOs - displays the current active owner for each team
#   hubot assign [team]-AO to @[user] - assign an active owner role to a user
#   hubot I'm [team]-AO - assign an active owner role to yourself
moment = require 'moment'

module.exports = (robot) ->

  nameRegEx = '[a-z0-9 -]+'

  robot.brain.data.teams ||= {}

  robot.respond /(list|show) (active owners|AO's|AOs)/i, (msg) ->
    teams = robot.brain.data['teams']
    if Object.keys(teams).length == 0
      response = "Sorry, I'm not keeping track of any teams or their AO's.\n" +
      "Get started with 'add <team_name> to teams'."
      return msg.send response
    aoStatus = (teamName, team) ->
      if team.aoUserId?
        aoName = robot.brain.userForId(team.aoUserId).name
        return "#{aoName} has been active owner on #{teamName} for #{moment(team.aoUserAssignedDt).fromNow(true)}"
      else
        "* #{teamName} has no active owner! Use: 'assign <user> as AO for <team>'"
    aoStatusList = (aoStatus(teamName, team) for teamName, team of teams)
    msg.send "AOs:\n" + aoStatusList.join("\n")

  robot.respond /add ([a-z0-9 ]+) to teams/i, (msg) ->
    team_name = msg.match[1].toString().toLowerCase()
    if robot.brain.data.teams[team_name]
      return msg.send "#{team_name} already being tracked"
    robot.brain.data.teams[team_name] = new Team()
    msg.send "#{team_name} added"

  robot.respond /(delete|remove) ([a-z0-9 ]+) from teams/i, (msg) ->
    team_name = msg.match[2].toString().toLowerCase()
    if robot.brain.data.teams[team_name]
      delete robot.brain.data.teams[team_name]
      return msg.send "removed #{team_name} from tracked teams"
    msg.send "I wasn't tracking #{team_name}"

  robot.respond /assign ([a-z0-9 -]+) as AO for ([a-z0-9 ]+)/i, (msg) ->
    userId = robot.brain.userForName(msg.match[1])?.id
    teamName = msg.match[2].toString().toLowerCase()
    assignTeam userId, teamName, msg
  
  robot.respond /I'm AO for ([a-z0-9 ]+)/i, (msg) ->
    teamName = msg.match[1].toString().toLowerCase()
    assignTeam msg.message.user.id, teamName, msg

  assignTeam  = (userId, teamName, msg) ->
    team = robot.brain.data.teams[teamName]
    return msg.send 'never heard of that team, maybe you should add it' unless team
    return msg.send "I have no idea who you're talking about" unless userId
    team.assignAo(userId)
    msg.send 'got it'

class Team
  constructor: ->
    @members = []
    @aoUserId = undefined
    @aoUserAssignedDt = undefined

  assignAo: (userId) ->
    @aoUserId = userId
    @aoUserAssignedDt = new Date()

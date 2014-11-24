Team = require './Team'

class ActiveOwnerHelper
  constructor: (@robot) ->

  assignTeam: (userId, teamName, msg) ->
    team = @getTeam(teamName)
    return msg.send "Never heard of that team. You can add a team with 'Add <team name> to teams'." unless team
    return msg.send "I have no idea who you're talking about." unless userId
    team.assignAo(userId)
    msg.send 'Got it.'

  getTeam: (name) ->
    return @robot.brain.data.teams[name.toLowerCase()]

  removeTeam: (name) ->
    delete @robot.brain.data.teams[name.toLowerCase()]

  addTeam: (name) ->
    @robot.brain.data.teams[name.toLowerCase()] = new Team(name)

  messageAOs: (message) ->
    @messageAO(team, message) for teamName, team of @robot.brain.data.teams

  messageAO: (team, message) ->
    if team.aoUserId
      aoUser = @robot.brain.userForId(team.aoUserId)
      @robot.send(aoUser, message)

module.exports = ActiveOwnerHelper

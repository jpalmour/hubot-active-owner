# Description
#   Let Hubot keep track of who is on AO duty for each team
#
# Configuration:
#  HUBOT_GITHUB_TOKEN (for notifying AOs of PRs with rr-needs-review in private repos) 
#  HUBOT_REVIEW_NEEDED_LABEL (Hubot messages all AOs when PR gets this label) 
#
# Commands:
#   hubot show|list AOs - displays the current active owner for each team
#   hubot assign [user] as AO for [team] - assign a user as AO for a team
#   hubot I'm AO for [team]- assign yourself as AO for a team
moment = require 'moment'
_ = require 'lodash'
GitHubApi = require 'github'

module.exports = (robot) ->

  robot.brain.data.teams ||= {}
  robot.brain.data.prsForReview ||= []

  robot.on 'review-needed', (pullRequest) ->
    registerNewPrForReview(pullRequest)

  # TODO this is dumb, use a repo that listens to GitHub webhooks instead
  robot.hear /labeled .*pull request (\d+).*([a-zA-Z_.-]+)\/([a-zA-Z_.-])/, (msg) ->
    prNumber = msg.match[1]
    org = msg.match[2]
    repo = msg.match[3]
    github = new GitHubApi
      version: '3.0.0'
    github.authenticate
      type: 'oauth'
      token: process.env.HUBOT_GITHUB_TOKEN
    github.issues.getIssueLabels {
      user: org
      repo: repo
      number: prNumber
    }, (err, res) ->
      return if err
      if _.some(res, (label) -> label.name == process.env.HUBOT_REVIEW_NEEDED_LABEL)
        robot.emit 'review-needed',
          url: "http://www.github.com/#{org}/#{repo}/pull/#{prNumber}"

  robot.respond /(list|show) (active owners|AO's|AOs)/i, (msg) ->
    teams = robot.brain.data['teams']
    if Object.keys(teams).length == 0
      response = "Sorry, I'm not keeping track of any teams or their AOs.\n" +
      "Get started with 'Add <team name> to teams'."
      return msg.send response
    aoStatus = (team) ->
      if team.aoUserId?
        aoName = robot.brain.userForId(team.aoUserId).name
        return "#{aoName} has been active owner on #{team.name} for #{moment(team.aoUserAssignedDt).fromNow(true)}"
      else
        "* #{team.name} has no active owner! Use: 'Assign <user> as AO for <team>'."
    aoStatusList = (aoStatus(team) for teamName, team of teams)
    msg.send "AOs:\n" + aoStatusList.join("\n")

  robot.respond /add ([a-z0-9 ]+) to teams/i, (msg) ->
    teamName = msg.match[1]
    if getTeam(teamName)
      return msg.send "#{teamName} already being tracked."
    addTeam(teamName)
    msg.send "#{teamName} added."

  robot.respond /(delete|remove) ([a-z0-9 ]+) from teams/i, (msg) ->
    teamName = msg.match[2]
    if getTeam(teamName)
      removeTeam(teamName)
      return msg.send "Removed #{teamName} from tracked teams."
    msg.send "I wasn't tracking #{teamName}."

  robot.respond /assign ([a-z0-9 -]+) as AO for ([a-z0-9 ]+)/i, (msg) ->
    userId = robot.brain.userForName(msg.match[1])?.id
    teamName = msg.match[2]
    assignTeam userId, teamName, msg
  
  robot.respond /I'm AO for ([a-z0-9 ]+)/i, (msg) ->
    teamName = msg.match[1]
    assignTeam msg.message.user.id, teamName, msg

  assignTeam  = (userId, teamName, msg) ->
    team = getTeam(teamName)
    return msg.send "Never heard of that team. You can add a team with 'Add <team name> to teams'." unless team
    return msg.send "I have no idea who you're talking about." unless userId
    team.assignAo(userId)
    msg.send 'Got it.'

  getTeam = (name) ->
    return robot.brain.data.teams[name.toLowerCase()]
  
  removeTeam = (name) ->
    delete robot.brain.data.teams[name.toLowerCase()]

  addTeam = (name) ->
    robot.brain.data.teams[name.toLowerCase()] = new Team(name)
  
  registerNewPrForReview = (pullRequest) ->
    #TODO: keep track of PRs in need of review and enable list to be viewed
    #pullRequest = new PullRequest(pullRequest)
    #robot.brain.data.prsForReview.push(pullRequest)
    messageAOs(pullRequest)
    
  messageAOs = (pullRequest) ->
    messageAO(team, pullRequest) for teamName, team of robot.brain.data.teams 

  messageAO = (team, pullRequest) ->
    if team.aoUserId 
      aoUser = robot.brain.userForId(team.aoUserId)
      message = "Rapid Response needs a review of #{pullRequest.url}"
      robot.send(aoUser, message)
    
class Team
  constructor: (name) ->
    @name = name
    @members = []
    @aoUserId = undefined
    @aoUserAssignedDt = undefined

  assignAo: (userId) ->
    @aoUserId = userId
    @aoUserAssignedDt = new Date()

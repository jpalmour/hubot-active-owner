path = require 'path'
chai = require 'chai'
sinon = require 'sinon'
chai.use require 'sinon-chai'
Robot = require 'hubot/src/robot'
Brain = require 'hubot/src/brain'
TextMessage = require('hubot/src/message').TextMessage

expect = chai.expect

describe 'active-owner script', ->
  beforeEach ->
    @robot =
      respond: sinon.spy()
      hear: sinon.spy()
      brain: data: {}
    require('../src/active-owner')(@robot)

  it 'registers respond listeners', ->
    expect(@robot.respond).to.have.been.calledWith(/(list|show) (active owners|AO's|AOs)/i)

describe 'Hubot with active-owner script', ->
  robot = null
  user = null
  adapter = null
	
  beforeEach (done) ->
    robot = new Robot null, 'mock-adapter', true, 'TestHubot'
    robot.adapter.on 'connected', ->
      robot.loadFile path.resolve('.', 'src'), 'active-owner.coffee'
      robot.loadFile path.resolve('.', 'node_modules', 'hubot-help', 'src'), 'help.coffee'
      user = robot.brain.userForId '1', {
        name: 'Gary'
        room: '1'
      }
      robot.brain.userForId '2', {
        name: 'Charlie'
        room: '1'
      }
      adapter = robot.adapter
      waitForHelp = ->
        if robot.helpCommands().length > 0
          do done
        else
          setTimeout waitForHelp, 100
      do waitForHelp
    do robot.run

  afterEach ->
    robot.server.close()
    robot.shutdown

  describe 'help', ->
    it 'should have 5 options', ->
      expect(robot.helpCommands()).to.have.length 5

    it 'should reply to help', (done) ->
      adapter.on 'send', (envelope, strings) ->
        expect(strings[0]).to.equal """
	TestHubot I\'m [team]-AO - assign an active owner role to yourself
	TestHubot assign [team]-AO to @[user] - assign an active owner role to a user
	TestHubot help - Displays all of the help commands that TestHubot knows about.
	TestHubot help <query> - Displays all help commands that match <query>.
	TestHubot show|list AOs - displays the current active owner for each team
        """
        do done
      adapter.receive new TextMessage user, 'TestHubot help'

  describe 'teams', ->
    it 'should add a new team', (done) ->
      adapter.on 'send', (envelope, strings) ->
        expect(strings[0]).to.equal('team america added')
        expect(robot.brain.data.teams['team america']?).to.be.true
        do done
      adapter.receive new TextMessage user, 'TestHubot add Team America to teams'

    it 'should not add a duplicate team', (done) ->
      adapter.on 'send', (envelope, strings) ->
        if strings[0] == 'team america already being tracked'
          do done
      adapter.receive new TextMessage user, 'TestHubot add Team America to teams'
      adapter.receive new TextMessage user, 'TestHubot add Team America to teams'

    it 'should delete a team', (done) ->
      adapter.on 'send', (envelope, strings) ->
        if strings[0] == 'removed team america from tracked teams'
          expect(robot.brain.data.teams['team america']?).to.be.false
          do done
      adapter.receive new TextMessage user, 'TestHubot add Team America to teams'
      adapter.receive new TextMessage user, 'TestHubot delete Team America from teams'

  describe 'assign AO', ->
    beforeEach ->
      adapter.receive new TextMessage user, 'TestHubot add Team America to teams'

    it 'should assign a known person to a known team', (done) ->
      adapter.on 'send', (envelope, strings) ->
        expect(strings[0]).to.equal('got it')
        aoId = robot.brain.data.teams['team america'].aoUserId
        expect(robot.brain.userForId(aoId).name).to.equal('Gary')
        do done
      adapter.receive new TextMessage user, 'TestHubot assign Gary as AO for Team America'
    
    it 'should assign sender of message to a team', (done) ->
      adapter.on 'send', (envelope, strings) ->
        expect(strings[0]).to.equal('got it')
        aoId = robot.brain.data.teams['team america'].aoUserId
        expect(robot.brain.userForId(aoId).name).to.equal('Gary')
        do done
      adapter.receive new TextMessage user, "TestHubot I'm AO for Team America"

    it 'should not assign an unknown person to a team', (done) ->
      adapter.on 'send', (envelope, strings) ->
        expect(strings[0]).to.equal("I have no idea who you're talking about")
        do done
      adapter.receive new TextMessage user, "TestHubot assign Kim Jong as AO for Team America"

    it 'should not assign a person to an unknown team', (done) ->
      adapter.on 'send', (envelope, strings) ->
        expect(strings[0]).to.equal("never heard of that team, maybe you should add it")
        do done
      adapter.receive new TextMessage user, "TestHubot assign Gary as AO for the Braves"

  describe 'show AOs', ->
    it 'should know when none exist', (done) ->
      adapter.on 'send', (envelope, strings) ->
        expResp = "Sorry, I'm not keeping track of any teams or their AO's.\n" +
          "Get started with 'add <team_name> to teams'."
        expect(strings[0]).to.equal(expResp)
        do done
      adapter.receive new TextMessage user, 'TestHubot show AOs'
    
    it 'should list all AOs', (done) ->
      adapter.receive new TextMessage user, 'TestHubot add Team America to teams'
      adapter.receive new TextMessage user, 'TestHubot add The Mighty Ducks to teams'
      adapter.receive new TextMessage user, 'TestHubot add Team Knight Rider to teams'
      adapter.receive new TextMessage user, "TestHubot I'm AO for Team America"
      adapter.receive new TextMessage user, "TestHubot assign Charlie as AO for The Mighty Ducks"
      adapter.on 'send', (envelope, strings) ->
        expResp = """
	AOs:
	Gary has been active owner on team america for a few seconds
	Charlie has been active owner on the mighty ducks for a few seconds
	* team knight rider has no active owner! Use: 'assign <user> as AO for <team>'
	"""
        expect(strings[0]).to.equal(expResp)
        do done
      adapter.receive new TextMessage user, 'TestHubot show AOs'

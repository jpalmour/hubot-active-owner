path = require 'path'
chai = require 'chai'
sinon = require 'sinon'
chai.use require 'sinon-chai'
_ = require 'lodash'
Robot = require 'hubot/src/robot'
Brain = require 'hubot/src/brain'
TextMessage = require('hubot/src/message').TextMessage

expect = chai.expect

# to avoid EventEmitter memory leak warning
process.setMaxListeners(20)

describe 'active-owner script', ->
  beforeEach ->
    @robot =
      respond: sinon.spy()
      hear: sinon.spy()
      brain:
        data: {}
        on: sinon.spy()
      on: sinon.spy()
      router: post: sinon.spy()
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
      robot.loadFile path.resolve('.', 'src'), 'review-needed-handler.coffee'
      robot.loadFile path.resolve('.', 'src'), 'review-complete-handler.coffee'
      robot.loadFile path.resolve('.', 'src'), 'webhook-listener.coffee'
      robot.loadFile path.resolve('.', 'node_modules', 'hubot-help', 'src'), 'help.coffee'
      user = robot.brain.userForId '1', {
        name: '@Gary'
        room: '1'
      }
      robot.brain.userForId '2', {
        name: 'Charlie'
        room: '1'
      }
      adapter = robot.adapter
      waitForHelp = ->
        if robot.helpCommands().length > 0
          robot.brain.set 'forceBrainLoadedEvent', 'thisIsDumb'
          done()
        else
          setTimeout waitForHelp, 100
      waitForHelp()
    robot.run()

  afterEach ->
    robot.server.close()
    robot.shutdown

  describe 'help', ->
    it 'should have 5 options', ->
      expect(robot.helpCommands()).to.have.length 5

  describe 'teams', ->
    it 'should add a new team', (done) ->
      adapter.on 'send', (envelope, strings) ->
        expect(strings[0]).to.equal('Team America added.')
        expect(robot.brain.data.teams['team america']?).to.be.true
        done()
      adapter.receive new TextMessage user, 'TestHubot add Team America to teams'

    it 'should not add a duplicate team', (done) ->
      adapter.on 'send', (envelope, strings) ->
        if strings[0] == 'Team America already being tracked.'
          done()
      adapter.receive new TextMessage user, 'TestHubot add Team America to teams'
      adapter.receive new TextMessage user, 'TestHubot add Team America to teams'

    it 'should delete a team', (done) ->
      adapter.on 'send', (envelope, strings) ->
        if strings[0] == 'Removed Team America from tracked teams.'
          expect(robot.brain.data.teams['team america']?).to.be.false
          done()
      adapter.receive new TextMessage user, 'TestHubot add Team America to teams'
      adapter.receive new TextMessage user, 'TestHubot delete Team America from teams'

  describe 'assign AO', ->
    beforeEach ->
      adapter.receive new TextMessage user, 'TestHubot add Team America to teams'

    it 'should assign a known person to a known team', (done) ->
      adapter.on 'send', (envelope, strings) ->
        expect(strings[0]).to.equal('Got it.')
        aoId = robot.brain.data.teams['team america'].aoUserId
        expect(robot.brain.userForId(aoId).name).to.equal('@Gary')
        done()
      adapter.receive new TextMessage user, 'TestHubot assign @Gary as AO for Team America'
    
    it 'should assign sender of message to a team', (done) ->
      adapter.on 'send', (envelope, strings) ->
        expect(strings[0]).to.equal('Got it.')
        aoId = robot.brain.data.teams['team america'].aoUserId
        expect(robot.brain.userForId(aoId).name).to.equal('@Gary')
        done()
      adapter.receive new TextMessage user, "TestHubot I'm AO for Team America"

    it 'should not assign an unknown person to a team', (done) ->
      adapter.on 'send', (envelope, strings) ->
        expect(strings[0]).to.equal("I have no idea who you're talking about.")
        done()
      adapter.receive new TextMessage user, "TestHubot assign Kim Jong as AO for Team America"

    it 'should not assign a person to an unknown team', (done) ->
      adapter.on 'send', (envelope, strings) ->
        expect(strings[0]).to.equal("Never heard of that team. You can add a team with 'Add <team name> to teams'.")
        done()
      adapter.receive new TextMessage user, "TestHubot assign @Gary as AO for the Braves"

  describe 'show AOs', ->
    it 'should know when none exist', (done) ->
      adapter.on 'send', (envelope, strings) ->
        expResp = "Sorry, I'm not keeping track of any teams or their AOs.\n" +
          "Get started with 'Add <team name> to teams'."
        expect(strings[0]).to.equal(expResp)
        done()
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
	@Gary has been active owner on Team America for a few seconds
	Charlie has been active owner on The Mighty Ducks for a few seconds
	* Team Knight Rider has no active owner! Use: \'Assign <user> as AO for <team>\'.
        """
        expect(strings[0]).to.equal(expResp)
        done()
      adapter.receive new TextMessage user, 'TestHubot show AOs'

  describe 'show needed reviews', ->
    it 'should show needed reviews', (done) ->
      adapter.on 'send', (envelope, strings) ->
        expResp = """
        PRs in need of review:
        Added a few seconds ago: http://www.github.com/a/b/pull/1
        Added a few seconds ago: http://www.github.com/a/b/pull/2
        """
        expect(strings[0]).to.equal(expResp)
        done()
      robot.emit 'review-needed',
        url: 'http://www.github.com/a/b/pull/1'
        repo: 'a/b'
        number: 1
      robot.emit 'review-needed',
        url: 'http://www.github.com/a/b/pull/2'
        repo: 'a/b'
        number: 2
      adapter.receive new TextMessage user, 'TestHubot show needed reviews'
    it 'knows when no reviews are needed', (done) ->
      adapter.on 'send', (envelope, strings) ->
        expResp = """
        Nothing needs review as far as I know.
        """
        expect(strings[0]).to.equal(expResp)
        done()
      adapter.receive new TextMessage user, 'TestHubot show needed reviews'

  describe 'on review-needed events', ->
    it 'should message AOs with PR link', (done) ->
      adapter.receive new TextMessage user, 'TestHubot add Team America to teams'
      adapter.receive new TextMessage user, 'TestHubot add The Mighty Ducks to teams'
      adapter.receive new TextMessage user, 'TestHubot add Team Knight Rider to teams'
      adapter.receive new TextMessage user, "TestHubot I'm AO for Team America"
      adapter.receive new TextMessage user, "TestHubot assign Charlie as AO for The Mighty Ducks"
      verifyAlertedUsers = ->
        if alertedUsers.indexOf('1') >= 0 && alertedUsers.indexOf('2') >= 0
          done()
      finished = _.after 2, verifyAlertedUsers
      alertedUsers = []

      adapter.on 'send', (envelope, strings) ->
        expect(strings[0]).to.equal("Rapid Response needs a review of http://www.github.com/a/b/pull/1")
        alertedUsers.push(envelope.id)
        finished()
      robot.emit 'review-needed',
        url: 'http://www.github.com/a/b/pull/1'
        repo: 'a/b'
        number: 1

    it 'should persist the PR needing review', (done) ->
      adapter.receive new TextMessage user, 'TestHubot add Team America to teams'
      adapter.receive new TextMessage user, "TestHubot I'm AO for Team America"
      adapter.on 'send', (envelope, strings) ->
        expect(robot.brain.data.prsForReview).to.contain.keys('a/b/1')
        expect(robot.brain.data.prsForReview['a/b/1'].url).to.equal('http://www.github.com/a/b/pull/1')
        expect(robot.brain.data.prsForReview['a/b/1'].repo).to.equal('a/b')
        expect(robot.brain.data.prsForReview['a/b/1'].number).to.equal(1)
        done()
      robot.emit 'review-needed',
        url: 'http://www.github.com/a/b/pull/1'
        repo: 'a/b'
        number: 1

  describe 'on review-complete events', ->
    beforeEach ->
      adapter.receive new TextMessage user, 'TestHubot add Team America to teams'
      adapter.receive new TextMessage user, 'TestHubot add The Mighty Ducks to teams'
      adapter.receive new TextMessage user, "TestHubot I'm AO for Team America"
      robot.emit 'review-needed',
        url: 'http://www.github.com/a/b/pull/1'
        repo: 'a/b'
        number: 1

    it 'should message AOs that review is no longer needed, with PR link', (done) ->
      adapter.receive new TextMessage user, "TestHubot assign Charlie as AO for The Mighty Ducks"
      verifyAlertedUsers = ->
        if alertedUsers.indexOf('1') >= 0 && alertedUsers.indexOf('2') >= 0
          done()
      finished = _.after 2, verifyAlertedUsers
      alertedUsers = []
      adapter.on 'send', (envelope, strings) ->
        expect(strings[0]).to.equal("Review no longer needed for http://www.github.com/a/b/pull/1. The PR either was closed or review label was removed.")
        alertedUsers.push(envelope.id)
        finished()
      robot.emit 'review-complete',
        url: 'http://www.github.com/a/b/pull/1'
        repo: 'a/b'
        number: 1

    it 'should remove the PR that is no longer in need of review', (done) ->
      adapter.on 'send', (envelope, strings) ->
        expect(robot.brain.data.prsForReview).not.to.contain.keys('a/b/1')
        done()
      robot.emit 'review-complete',
        url: 'http://www.github.com/a/b/pull/1'
        repo: 'a/b'
        number: 1

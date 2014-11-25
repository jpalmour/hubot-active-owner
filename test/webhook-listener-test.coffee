path = require 'path'
chai = require 'chai'
sinon = require 'sinon'
chai.use require 'sinon-chai'
Robot = require 'hubot/src/robot'
Brain = require 'hubot/src/brain'
request = require 'supertest'
expect = chai.expect
Review = require '../src/Review'
AOHelper = require '../src/ActiveOwnerHelper'

process.setMaxListeners(25)

describe 'Hubot with webhook-listener script', ->
  robot = null
  user = null
  adapter = null
  beforeEach (done) ->
    robot = new Robot null, 'mock-adapter', true, 'TestHubot'
    robot.adapter.on 'connected', ->
      robot.loadFile path.resolve('.', 'src', 'robot-scripts'), 'webhook-listener.coffee'
      robot.loadFile path.resolve('.', 'node_modules', 'hubot-help', 'src'), 'help.coffee'
      robot.brain.data.reviews ||= {}
      adapter = robot.adapter
      waitForHelp = ->
        if robot.helpCommands().length > 0
          done()
        else
          setTimeout waitForHelp, 100
      waitForHelp()
    robot.run()

  afterEach ->
    robot.server.close()
    robot.shutdown

  it 'should raise a review-needed event with a Review object when a PR gets labeled as REVIEW_NEEDED', (done) ->
    process.env.HUBOT_REVIEW_NEEDED_LABEL = 'rr-review-needed'
    json = require('./webhook-json/label-added')
    robot.on 'review-needed', (review) ->
      expect(review.repo).to.equal('jpalmour/hubot-active-owner')
      expect(review.url).to.equal('https://github.com/jpalmour/hubot-active-owner/pull/2')
      expect(review.number).to.equal(2)
      expect(review.key).to.equal('jpalmour/hubot-active-owner/2')
      done()
    request(robot.router)
      .post('/hubot/gh')
      .send(json)
      .expect(200, ->)
  
  it 'should raise a review-complete event with a Review object when a REVIEW_NEEDED label is removed from a PR', (done) ->
    process.env.HUBOT_REVIEW_NEEDED_LABEL = 'rr-review-needed'
    json = require('./webhook-json/label-removed')
    robot.on 'review-complete', (review) ->
      expect(review.repo).to.equal('jpalmour/hubot-active-owner')
      expect(review.url).to.equal('https://github.com/jpalmour/hubot-active-owner/pull/2')
      expect(review.number).to.equal(2)
      expect(review.key).to.equal('jpalmour/hubot-active-owner/2')
      done()
    request(robot.router)
      .post('/hubot/gh')
      .send(json)
      .expect(200, ->)

  it 'should raise a review-complete event with a Review object when a PR in the review list is closed', (done) ->
    json = require './webhook-json/pr-closed'
    review = new Review(require './webhook-json/label-added')
    helper = new AOHelper robot
    helper.addReview review
    robot.on 'review-complete', (review) ->
      expect(review.repo).to.equal('jpalmour/hubot-active-owner')
      expect(review.url).to.equal('https://github.com/jpalmour/hubot-active-owner/pull/2')
      expect(review.number).to.equal(2)
      expect(review.key).to.equal('jpalmour/hubot-active-owner/2')
      done()
    request(robot.router)
      .post('/hubot/gh')
      .send(json)
      .expect(200, ->)

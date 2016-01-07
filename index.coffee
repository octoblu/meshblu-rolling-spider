'use strict';
util           = require 'util'
{EventEmitter} = require 'events'
debug          = require('debug')('meshblu-rolling-spider')
Drone = require('rolling-spider')


MESSAGE_SCHEMA =
  type: 'object'
  properties:
    command:
      type: 'string'
      enum: [
        'connect'
        'disconnect'
        'takeOff'
        'land'
        'up'
        'down'
        'forward'
        'backward'
        'turnLeft'
        'turnRight'
        'tiltLeft'
        'tiltRight'
        'frontFlip'
        'backFlip'
        'leftFlip'
        'rightFlip'
        'emergency'
        'flatTrim'
        'release'
      ]
      required: true
    specific:
      title: 'Message specific drone? (if swarm)'
      type: 'boolean'
      default: false
    memberId:
      title: 'Drone name or UUID (Leave blank to send to all connected)'
      type: 'string'

OPTIONS_SCHEMA =
  type: 'object'
  properties:
    swarm:
      title: 'Enable swarm?'
      type: 'boolean'
      default: false
    drones:
      title: 'Add as many drones as you like. If left blank the first(or all if swarm) available will be chosen'
      type: "array"
      items:
        title: "BLE UUID or localName"
        type: "string"




class Plugin extends EventEmitter
  spider = {}

  constructor: ->
    @options = {}
    @messageSchema = MESSAGE_SCHEMA
    @optionsSchema = OPTIONS_SCHEMA

  ACTIVE = false
  STEPS = 2

  cooldown: () =>
    ACTIVE = false
    setTimeout ->
      ACTIVE = true
    , STEPS * 12

  onMessage: (message) =>
    payload = message.payload
    @droneCommand(payload)

  droneCommand: (payload) =>
    { command, memberId, specific } = payload

    if ACTIVE
      if command == 'disconnect'
        @disconnectDrone() unless @options.swarm == true
        spider.release()
      else if command == 'takeOff'
        if @options.swarm == true && specific == true
          spider.at(memberId).flatTrim()
          spider.at(memberId).takeOff()
          @cooldown()
        else
          spider.flatTrim()
          spider.takeOff()
          @cooldown()
      else if command == 'land'
        spider.land()
      else
        spider[command] steps: STEPS unless @options.swarm == true && specific == true
        spider.at(memberId)[command] steps: STEPS
        @cooldown()
    else if !ACTIVE
      if command == 'connect'
        @connectDrone(@options.drones[0]) unless @options.swarm == true
        @connectSwarm(@options.drones)


  onConfig: (device) =>
    @setOptions device.options

  connectDrone: (droneOptions={}) =>
    spider =  new Drone(droneOptions)

    spider.connect ->
      spider.setup ->
        console.log 'Configured for Rolling Spider! ', spider.name
        spider.flatTrim()
        spider.startPing()
        spider.flatTrim()

        setTimeout (->
          console.log 'ready for flight'
          ACTIVE = true
        ), 1000

   connectSwarm: (members) =>
     spider = new Drone.Swarm({membership: members, timeout: 20});

     spider.assemble()

     spider.on 'assembled', ->
      setTimeout (->
        console.log 'ready for flight'
        ACTIVE = true
      ), 1000

    disconnectDrone: () =>
      spider.disconnect() ->
        console.log 'disconnected drone'

      ACTIVE = false

  setOptions: (options={}) =>
    @options = options

module.exports =
  messageSchema: MESSAGE_SCHEMA
  optionsSchema: OPTIONS_SCHEMA
  Plugin: Plugin

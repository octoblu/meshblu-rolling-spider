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
      ]
      required: true

OPTIONS_SCHEMA =
  type: 'object'
  properties:
    localName:
      title: 'BLE UUID or localName (leave blank to find first available)'
      type: 'string'
      required: false

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
    @droneCommand(payload.command)

  droneCommand: (command) =>
      if ACTIVE
        if command == 'disconnect'
          @disconnectDrone()
        else if command == 'takeOff'
          spider.flatTrim()
          spider.takeOff()
          @cooldown()
        else if command == 'land'
          spider.land()
        else
          spider[command] steps: STEPS
          @cooldown()
      else if !ACTIVE
        if command == 'connect'
          @connectDrone(@options.localName)


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

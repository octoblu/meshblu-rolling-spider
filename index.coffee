'use strict';
util           = require 'util'
{EventEmitter} = require 'events'
debug          = require('debug')('meshblu-rolling-spider')

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
  constructor: ->
    @options = {}
    @messageSchema = MESSAGE_SCHEMA
    @optionsSchema = OPTIONS_SCHEMA

  ACTIVE = false
  STEPS = 2

  cooldown = ->
    ACTIVE = false
    setTimeout (->
      ACTIVE = true
    ), STEPS * 12

  onMessage: (message) =>
    payload = message.payload

  droneCommand: (command) =>
      if ACTIVE
        if command == 'connect'
          response =
            devices: ['*']
            payload: 'already_active'
          @emit 'message', response
        else if command == 'disconnect'
          disconnectDrone()
        else if command == 'takeOff'
          d.flatTrim()
          d.takeOff()
          d.cooldown()
        else if command == 'land'
          d.land()
        else
          d[command]()
          cooldown()
      else
        if command == 'connect'
          connectDrone(@options.localName)


  onConfig: (device) =>
    @setOptions device.options

  connectDrone: (droneOptions) =>
    droneOptions = droneOptions || {}
    d = new Drone(droneOptions)
    d.connect ->
      d.setup ->
        console.log 'Configured for Rolling Spider! ', d.name
        d.flatTrim()
        d.startPing()
        d.flatTrim()

        d.on 'stateChange', ->
          response =
            devices: ['*']
            payload: d.status.flying then '-- flying' else '-- down'
          @emit 'message', response

        setTimeout (->
          console.log 'ready for flight'
          response =
            devices: ['*']
            payload: 'flight_ready'
          @emit 'message', response
          ACTIVE = true
        ), 1000

    disconnectDrone: () =>
      d.disconnect()
      ACTIVE = false

  setOptions: (options={}) =>
    @options = options

module.exports =
  messageSchema: MESSAGE_SCHEMA
  optionsSchema: OPTIONS_SCHEMA
  Plugin: Plugin

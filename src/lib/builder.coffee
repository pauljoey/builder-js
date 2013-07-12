
shell = require('shelljs')

base = require('./base')
util = require('./util')
cmd = require('./cmd')

targets = require('./targets')

exports.watch = cmd.watch
exports.run = cmd.run
exports.importProject = cmd.importProject

exports.Node = base.Node
exports.Buffer = base.Buffer

exports.Target = targets.Target

exports.target = base.target
exports.project = base.project

exports.lastProject = base.lastProject
exports.firstProject = base.firstProject
exports.getProject =  base.getProject

exports.debug = util.debug
exports.info = util.info
exports.warn = util.warn
exports.error = util.error

exports.abort = util.abort
exports.notify = util.notify

exports.changeExtension = util.changeExtension
exports.changeDirectory = util.changeDirectory
exports.shell = shell






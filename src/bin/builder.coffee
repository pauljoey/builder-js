#!/usr/bin/env coffee

path = require('path')
fs   = require('fs')
lib  = path.join(path.dirname(fs.realpathSync(__filename)), '../lib')

require(lib + '/cmd').runBuilderFile()


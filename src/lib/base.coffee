

shell  = require('shelljs')

fs     = require 'fs'
path   = require 'path'
exists = fs.existsSync || path.existsSync

util    = require './util'

error   = util.error
warn    = util.warn
info    = util.info
debug   = util.debug

notify  = util.notify
abort   = util.abort

mkdir   = util.mkdir
uuid4   = util.uuid4

try
	less = require 'less'
catch err
	less = undefined


#command = require('common-node').subprocess.command

tsort   = require('./tsort').tsort


# Target: 
#	Name: 'All'
#	Dependencies/Sources: app.js.min
#	Build: Do nothing. Just build dependencies

# Target: 
#	Name: app.js.min
#	Dependencies/Sources: app.js
# 	Build: minimize [sources]

# Target:
#	Name: app.js
#	Dependencies/Sources: [script1.coffee script2.coffee]
#	

# Sources that are not defined as targets are assumes to be files and should exist.
# Targets can be sources

# A "Target" is a special kind of Source/Node that can be built. 




###
# This currently isn't used.

current_level = 0

levelUp = () ->
	current_level += 1
	
levelDown = () ->
	current_level -= 1
	current_level = 0 if current_level < 0
	
levelReset = () ->
	current_level = 0
###


# When executing a target, build depency list like so from all dependent nodes stemming from target

###
edges = [
    ['test.js', 's1.js'],
    ['test.js', 's2.js'],
    ['all', 'test.js'],
    ['s1.js', 'time.js']
]


console.log(tsort(edges))
###

class ProjectManager
	
	# Hacks
	@first = null
	@last = null
	
	@PROJECTS = {}

	@getProject: (name) ->
		return ProjectManager.PROJECTS[name]
		
	@createProject: (name, options, nodes) ->
		if project = ProjectManager.getProject(project)
			# Set options, add nodes
		else
			project = ProjectManager.PROJECTS[name] = new Project(name, options)
			#p2 = project
			#debug 'Nodes time!'
			#nodes()
		
		unless ProjectManager.last?
			ProjectManager.first = project
			
		ProjectManager.last = project
		return project


class NodeManager

	_nodes = null
	_targets = null
	
	@STATUS_UPTODATE = 0
	@STATUS_NEEDSUPDATE = 10
	@STATUS_UPDATING = 20
	
	constructor: (options) ->
		# All targets are nodes. Not all nodes are targets.
		@_nodes = {}
		@_targets = {}
	
	createTarget: (name, sources, build_function) ->
		#debug 'NodeManager:createTarget()', 'called args=', JSON.stringify(i for i in arguments)
		if node = @getNode(name)
			if node.is_target == true
				warn 'NodeManager:createTarget()', 'Re-defining target ' + name
		else
			node = @createNode(name)
			
		@_targets[name] = node
			
		node.build_function = build_function
		node.is_target = true
		
		for source_name in sources
			# If string, resolve node
			if typeof source_name == 'string'
				source = @createNode(source_name)
			# Otherwise assume it is a node object (eg, imported from another project)
			else
				source = source_name
			source.is_source = true
			node.addSource(source)
		
		return node

	getNode: (name) ->
		return @_nodes[name]

	getTarget: (name) ->
		return @getNode(name)
		
	getTargets: () ->
		return @_targets
		
	getSource: (name) ->
		return @getNode(name)
		
	createNode: (name) ->
		unless node = @_nodes[name]
			node = @_nodes[name] = new Node(@, name)		
		return node


class Project extends NodeManager
	name = ''
	staging_dir = '=staging/'
	build_dir = '=build/'
	source_dir = './'
	base_dir = './'
	
	@instance = null

	constructor: (name, options) ->
		@name = name
		@setOptions(options) if options?
		super()
		
	setOptions: (options) ->
		@build_dir = options.build_dir if options.build_dir? 
		@staging_dir = options.staging_dir if options.staging_dir? 
		@source_dir = options.source_dir if options.source_dir? 
		@base_dir = options.base_dir if options.base_dir?


class Buffer
	contents = null
	length = 0
	type = 0

	@TYPE_EMPTY = 0
	@TYPE_SOURCE = 10
	@TYPE_FILEPATH = 20
	@TYPE_STRING = 30
	
	@TEMP_FILES = []
	
	# Class method
	
	@registerTempFile: (file) ->
		debug 'Registering temp file ' + file
		Buffer.TEMP_FILES.push(file)
		
	@deleteTempFiles: () ->
		if Buffer.TEMP_FILES.length
			debug 'Deleting temp files... '
			for f in Buffer.TEMP_FILES
				try
					fs.unlinkSync(f)
				catch err
					debug 'Error deleting temp file: ' + err
				
				
		Buffer.TEMP_FILES = []
	
	constructor: (node) ->
		@node = node
		@clear()


	clear: () ->
		@contents = null
		@length = 0
		@type = Buffer.TYPE_EMPTY


	toString: () ->
		###
		if @type == Buffer.TYPE_SOURCE 
			debug 'Source->String conversion ', @contents
			contents = new Array(@length)
			for source, index in @contents then do (source, index) =>
				f = @node.findSourcePath(source.file)
				contents[index] = fs.readFileSync "#{f}", 'utf8'
			@type = Buffer.TYPE_STRING
			@contents = contents
			return @contents
		###
		switch @type 
			when Buffer.TYPE_STRING
				return @contents
			when Buffer.TYPE_FILEPATH
				contents = new Array(@length)
				for data, index in @contents then do (data, index) =>
					debug 'Reading ' + data
					contents[index] = fs.readFileSync "#{data}", 'utf8'
				@type = Buffer.TYPE_STRING
				@contents = contents
				return @contents

	toFile: () ->
		###
		if @type == Buffer.TYPE_SOURCE 
			debug 'Source->File conversion ' 
			contents = new Array(@length)
			for source, index in @contents then do (source, index) =>
				contents[index] = @node.findSourcePath(source.file)
			@type = Buffer.TYPE_FILEPATH
			@contents = contents
			return @contents
		###

		switch @type
			when Buffer.TYPE_STRING
				contents = new Array(@length)
				for i in [0...@length]
					filename = @getTempFile()
					fs.writeFileSync filename, @contents[i], 'utf8'
					contents[i] = filename
				@type = Buffer.TYPE_FILEPATH
				@contents = contents
				return @contents
			when Buffer.TYPE_FILEPATH
				return @contents

	getFile: () ->
		# assume we're built and up to date..

		switch @type
			when Buffer.TYPE_STRING
				contents = new Array(@length)
				for i in [0...@length]
					filename = @getTempFile()
					fs.writeFileSync filename, @contents[i], 'utf8'
					contents[i] = filename
				return contents
				
			when Buffer.TYPE_FILEPATH 
				return @contents.slice(0)
			
			else
				warn 'Unknown buffer type'
				return null

	getString: () ->
	
		switch @type
			when Buffer.TYPE_STRING
				return @contents.slice(0)
				
			when Buffer.TYPE_FILEPATH 
				contents = new Array(@length)
				for data, index in @contents then do (data, index) =>
					debug 'Reading ' + data
					contents[index] = fs.readFileSync "#{data}", 'utf8'
				return contents
			else
				warn 'Unknown buffer type'
				return null
		
	pop: () ->
		removed = @contents.pop()
		@length = @contents.length
		return removed

	shift: () ->
		removed = @contents.shift()
		@length = @contents.length
		return removed

	getTempFile: (file) ->
		file = path.join @node.project.staging_dir, '~_tmp_' + @node.name.replace(path.sep,'_') + '.' + uuid4()
		# Make sure path exists
		#mkdir path.dirname(file)
		shell.mkdir('-p', path.dirname(file))
		Buffer.registerTempFile(file)
		return file


exports.Buffer = Buffer

# Status
# 
class Node extends NodeManager
	name = null
	file = null
	sources = null
	targets = null
	buffer = null
	build_function = null
	is_target = null
	is_source = null
	is_building = false
	first_build_completed = false
	is_file_source = false
	is_watched = false
	build_requested = false
	last_modified = 0
	project = null
	last_updated = 0
	depth = 0
	
	constructor: (project, name) ->
		#debug 'Node:New()', 'called args=', JSON.stringify(i for i in arguments)
		@project = project 
		@name = name
		@file = name
		@sources = []
		@targets = []
		@buffer = new Buffer(@)
		@last_modified = 0
		@last_updated = 0
		@depth = 0
		
		# Default build_function action:
		@build_function = @buildFile

	addSource: (source) ->
		@sources.push(source) if @sources.indexOf(source) < 0 
		source.targets.push(@) if source.targets.indexOf(@) < 0 
		
	removeSource: (source) ->
		ind = @sources.indexOf(source)
		if ind? and -1 < ind
			@sources.splice(ind, 1)
		else
			warn "Could not find source #{source.name} in target #{@name}"
			
		ind = source.targets.indexOf(@)
		if ind? and -1 < ind
			source.targets.splice(ind, 1)
		else
			warn "Could not find target #{@name} in source #{source.name}"
			
	buildSources: (options) ->
		@is_building = true
		for source in @sources
			source.build(options)


	checkSourceBuilds: (options) ->
		if @build_requested
			#debug 'checkSourceBuilds() ' + @name 
			for source in @sources
				if source.is_building or ! source.first_build_completed
					return
			@buildSelf(options)
			
		return
	
	
	watch: () ->
		@build({watch: true})
	
	build: (options) ->
		#debug 'Node:build()', 'called args=', JSON.stringify(i for i in arguments)
		@build_requested = true

		# If the target has sources, build them.
		# They will trigger the building of the target as 
		# they complete by calling checkSourceBuilds()
		if 0 < @sources.length 
			info 'Building dependencies ' + @name
			@buildSources(options)
		else
			@buildSelf(options)
	
	buildSelf: (options) ->


		if @first_build_completed 
			#debug 'buildSelf() ' + @name + ' ' + new Date(@last_modified)
			stale = false
			for source in @sources
				if @last_modified < source.last_modified
					#debug 'newer ' + source.name + ' ' + new Date(source.last_modified)
					stale = true
					break
				else
					#debug 'older ' + source.name + ' ' + new Date(source.last_modified)
		else
			stale = true


		unless stale
			info 'Up to date ' + @name
			@done(options)
		else
			info 'Building ' + @name
			if @build_function
				#debug 'buildSelf()', 'calling build_function'
				# Fork here and wait until build_function is done
				@is_building = true
				#if @sources
				#	@buffer = new Buffer(@sources, @project.staging_dir)
				@start(options)
				@build_function(options)
				# Serial execution
				@done(options)
			else
				#debug 'buildSelf()', 'no build_function'   
				@is_building = false
				#if @sources
				#	@buffer = new Buffer(@sources, @project.staging_dir)
				@start(options)
				@done(options)
				
	###				
	getFile: () ->
		unless @first_build_completed
			@build()
		return @findSourcePath(@file)

		
	getContents: () ->
		unless @first_build_completed
			@build()
		p = @findSourcePath(@file)
		contents = fs.readFileSync p, 'utf8'
		return contents
	###
	
	# Copy sources into buffer	
	start: (options) ->
		@buffer.clear()
		
		# May make this an explicit build command?
		# @buffer.contents = @sources
		# @buffer.length = @sources.length
		# @buffer.type = Buffer.TYPE_SOURCE
		
	done: (options) ->
		@first_build_completed = true
		@is_building = false
		unless @is_file_source
			@last_modified = (new Date()).getTime()
		
		# Copy self into buffer if we have no sources or rule - ie, a leaf node
		# ... I think this makes sense to do ...
		#if @sources.length < 1
		#	@buffer = @
		debug 'Done ' + @name
		# Tell parents that we're done building
		for target in @targets
			target.checkSourceBuilds(options)
	
	findSourcePath: (rel_path) ->
		dirs = [@project.source_dir, @project.staging_dir, @project.build_dir, @project.base_dir, '.']

		for d in dirs
			p = path.normalize path.join d, rel_path
			if exists p
				return p
		
		warn 'Could not locate source ' + rel_path		
		return rel_path

	
	getFile: () ->
		# assume we're built and up to date..
		return @buffer.getFile()


	getString: () ->
		# assume we're built and up to date..
		return @buffer.getString()

				
	buildFile: (options) ->

		# resolve path
			
		p = @findSourcePath(@name)
		debug 'Found file/target ' + p
		@is_file_source = true
		
		try
			stats = fs.statSync(p)
		catch err
			abort "No target/file named '#{@name}'"

		if stats.isDirectory()
			abort "Implicit target '#{@name}' located at '#{p}' is a directory. Only files are allowed."
			
		@last_modified = (new Date(stats.mtime)).getTime()
		
		@file = p
		@buffer.type = Buffer.TYPE_FILEPATH 
		@buffer.contents = [p]
		@buffer.length = 1
		
		if options? and options.watch? and options.watch and ! @is_watched
			info 'watching ' + p
			fs.watchFile(p, (curr, prev) => @fileChanged(options, curr, prev)) 

	fileChanged: (options, curr, prev) ->

		@last_modified = (new Date(curr.mtime)).getTime()
		info '--> ' + @name + ' changed. ' + new Date(@last_modified)
			
		@first_build_completed = true
		@is_building = false
		
		# Catch errors to ensure compilation continues
		try
			# Tell parents that we're done building
			for target in @targets
				target.checkSourceBuilds(options)	
		catch err
			try
				abort err
			catch err
				donothing = true
		
		# This may break things...		
		Buffer.deleteTempFiles()

exports.Node = Node



# Want to be able to 'map' targets.
# ie, 'jquery' -> '/src/vendor/jquery/jquery.js'
#
# This will be important for linked packages
# Perhaps need a 'Package' declaration? Thus all targets become package-specific.
#
# Probably going to need a dependency tree of some kind for asynchronous building...

# May wish to chain targets... as in.. target becomes source for following entry.
# Typical chain
# All -> app.min.js -> (minify) app.js -> (coffee2js) app.coffee -> (cat) file1.coffee, file2.coffee

# How to distinguish build ->
#	@cat <- operates on sources
#	@coffee2js <-- operates on output




###
target = (name, sources, build_function) ->
	if Project.instance
		project = Project.instance
	else 
		project = Project.instance = new Project()
	return NodeManager.createTarget(project, name, sources, build_function)

project = (options) ->
	if Project.instance
		Project.instance.setOptions(options)
		return Project.instance
	else
		return Project.instance = new Project(options)
###

target = (name, sources, build_function) ->
	project = ProjectManager.last
	unless project
		abort 'No project declared'
	else 
		return project.createTarget(name, sources, build_function)

project = ProjectManager.createProject


exports.lastProject = -> return ProjectManager.last
exports.firstProject = -> return ProjectManager.first
exports.getProject = (name) -> return ProjectManager.getProject(name)

exports.target = target
exports.project = project


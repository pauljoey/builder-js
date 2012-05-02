
cmd_coffee = (sources, output) ->
	"coffee --output #{output} --compile #{sources}"
	
cmd_minify = (sources, output) ->
	"yui-compressor --type js -o #{output}  #{sources}"


shell = require('shelljs')
exports.ls = shell.ls

coffee = require 'coffee-script'
fs	 = require 'fs'
path = require 'path'
exec = require('child_process').exec
util   = require 'util'
#mini = 'yui-compressor -o'



#command = require('common-node').subprocess.command

tsort   = require('./tsort').tsort

dirsep = '/'

uuid4 = (a, b) ->
  b = a = ""
  while a++ < 36
    b += (if a * 51 & 52 then (if a ^ 15 then 8 ^ Math.random() * (if a ^ 20 then 16 else 4) else 4).toString(16) else "-")
  b

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


DEBUG = () ->
	if arguments.length == 1 then console.log(arguments[0]) else console.log((i for i in arguments).join(',\t'))

error = () ->
	if arguments.length == 1 then console.error(arguments[0]) else console.error((i for i in arguments).join(',\t'))
	throw arguments
	
warn = () ->
	if arguments.length == 1 then console.warn(arguments[0]) else console.warn((i for i in arguments).join(',\t'))
	
info = () ->
	if arguments.length == 1 then console.info(arguments[0]) else console.info((i for i in arguments).join(',\t'))
	
# When executing a target, build depency list like so from all dependent nodes stemming from target
edges = [
    ['test.js', 's1.js'],
    ['test.js', 's2.js'],
    ['all', 'test.js'],
    ['s1.js', 'time.js']
]


console.log(tsort(edges))


class ProjectManager
	
	# Hack
	@latest = null
	@PROJECTS = {}

	@getProject: (name) ->
		return ProjectManager.PROJECTS[name]
		
	@createProject: (name, options, nodes) ->
		if project = ProjectManager.getProject(project)
			# Set options, add nodes
		else
			project = ProjectManager.PROJECTS[name] = new Project(name, options)
			#p2 = project
			#DEBUG 'Nodes time!'
			#nodes()
		
		ProjectManager.latest = project
		return project


class NodeManager

	__unresolved_nodes = null

	#@targets = {}
	@STATUS_UPTODATE = 0
	@STATUS_NEEDSUPDATE = 10
	@STATUS_UPDATING = 20
	
	constructor: (options) ->
		@__unresolved_nodes = {}
	
	createTarget: (name, sources, build_function) ->
		#DEBUG 'NodeManager:createTarget()', 'called args=', JSON.stringify(i for i in arguments)
		if node = @getNode(name)
			if node.is_target == true
				warn 'NodeManager:createTarget()', 'Re-defining target ' + name
		else
			node = @createNode(name)
			
		node.build_function = build_function
		node.is_target = true
		
		for source_name in sources
			source = @createNode(source_name)
			source.is_source = true
			node.addSource(source)
		
		return node


	getNode: (name) ->
		return @__unresolved_nodes[name]
		
	createNode: (name) ->
		unless node = @__unresolved_nodes[name]
			node = @__unresolved_nodes[name] = new Node(@, name)		
		return node


class Project extends NodeManager
	name = ''
	staging_dir = '=staging/'
	build_dir = '=build/'
	source_dir = './'
	@instance = null

	constructor: (name, options) ->
		@name = name
		@setOptions(options) if options?
		super()
		
	setOptions: (options) ->
		@build_dir = options.build_dir if options.build_dir? 
		@staging_dir = options.staging_dir if options.staging_dir? 
		@source_dir = options.source_dir if options.source_dir? 


class Buffer
	contents = null
	length = 0
	type = 0

	@TYPE_EMPTY = 0
	@TYPE_SOURCE = 10
	@TYPE_FILEPATH = 20
	@TYPE_STRING = 30
	
	@TEMP_FILES = []
	
	constructor: (node) ->
		@node = node
		@clear()


	clear: () ->
		@contents = null
		@length = 0
		@type = Buffer.TYPE_EMPTY


	toString: () ->
		if @type == Buffer.TYPE_SOURCE 
			contents = new Array(@length)
			
			for source, index in @contents then do (source, index) =>
				f = @node.findSourcePath(source.file)
				DEBUG 'Reading ' + f
				contents[index] = fs.readFileSync "#{f}", 'utf8'
			@type = Buffer.TYPE_STRING
			@contents = contents
			return @contents
		else if @type == Buffer.TYPE_FILEPATH 
			contents = new Array(@length)
			for data, index in @contents then do (data, index) =>
				contents[index] = fs.readFileSync "#{data}", 'utf8'
			@type = Buffer.TYPE_STRING
			@contents = contents
			return @contents
		else if @type == Buffer.TYPE_STRING
			return @contents

	toFile: () ->
		if @type == Buffer.TYPE_SOURCE 
			contents = new Array(@length)
			for source, index in @contents then do (source, index) =>
				contents[index] = @node.findSourcePath(source.file)
			@type = Buffer.TYPE_FILEPATH
			@contents = contents
			return @contents
		else if @type == Buffer.TYPE_STRING
			contents = new Array(@length)
			for i in [0...@length]
				filename = @getTempFile()
				fs.writeFileSync filename, @contents[i], 'utf8'
				contents[i] = filename
			@type = Buffer.TYPE_FILEPATH
			@contents = contents
			return @contents
		else if @type == Buffer.TYPE_FILEPATH
			return @contents

		
	pop: () ->
		removed = @contents.pop()
		@length = @contents.length
		return removed

	shift: () ->
		removed = @contents.shift()
		@length = @contents.length
		return removed

	getTempFile: (file) ->
		file = path.join @node.project.staging_dir, '._tmp_' + @node.name.replace(dirsep,'_') + '.' + uuid4()
		# Make sure path exists
		mkdirP path.dirname(file)
		Buffer.registerTempFile(file)
		return file

	@registerTempFile: (file) ->
		DEBUG 'Registering temp file ' + file
		Buffer.TEMP_FILES.push(file)
		
	@deleteTempFiles: () ->
		DEBUG 'Deleting temp files... '
		for f in Buffer.TEMP_FILES
			fs.unlinkSync(f)

	

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
	is_up_to_date = false
	project = null
	last_updated = 0
	
	constructor: (project, name) ->
		#DEBUG 'Node:New()', 'called args=', JSON.stringify(i for i in arguments)
		@project = project 
		@name = name
		@file = name
		@sources = []
		@targets = []
		@buffer = new Buffer(@)
		
		# Default build_function action:
		@build_function = @checkFile

	addSource: (source) ->
		@sources.push(source) if @sources.indexOf(source) < 0 
		source.targets.push(@) if source.targets.indexOf(@) < 0 

	buildSources: () ->
		@is_building = true
		for source in @sources
			source.build()
			
	checkSourceBuilds: () ->
		for source in @sources
			unless source.is_up_to_date and not source.is_building
				return
		@buildSelf()
		return
	
	build: () ->
		#DEBUG 'Node:build()', 'called args=', JSON.stringify(i for i in arguments)
		if 0 < @sources.length 
			info 'Building dependencies ' + @name
			@buildSources()
		else
			@buildSelf()
	
	buildSelf: () ->
		if @is_up_to_date
			info 'Up to date ' + @name
		else
			info 'Building ' + @name
			if @build_function
				DEBUG 'Node:build()', 'calling build_function'
				# Fork here and wait until build_function is done
				@is_building = true
				#if @sources
				#	@buffer = new Buffer(@sources, @project.staging_dir)
				@start()
				@build_function()
				# Serial execution
				@done()
			else
				DEBUG 'Node:build()', 'no build_function'
				@is_building = false
				#if @sources
				#	@buffer = new Buffer(@sources, @project.staging_dir)
				@start()
				@done()
				
	###				
	getFile: () ->
		unless @is_up_to_date
			@build()
		return @findSourcePath(@file)

		
	getContents: () ->
		unless @is_up_to_date
			@build()
		p = @findSourcePath(@file)
		contents = fs.readFileSync p, 'utf8'
		return contents
	###
	
	# Copy sources into buffer	
	start: () ->
		@buffer.clear()
		
		# May make this an explicit build command?
		# @buffer.contents = @sources
		# @buffer.length = @sources.length
		# @buffer.type = Buffer.TYPE_SOURCE
		
	done: () ->
		@is_up_to_date = true
		@is_building = false
		
		# Copy self into buffer if we have no sources or rule - ie, a leaf node
		# ... I think this makes sense to do ...
		if @sources.length < 1
			@buffer = @
		
		# Tell parents that we're done building
		for target in @targets
			target.checkSourceBuilds()
	
	findSourcePath: (rel_path) ->
		p = path.normalize path.join @project.build_dir, rel_path
		if path.existsSync p
			return p
		p = path.normalize path.join @project.staging_dir, rel_path
		if path.existsSync p
			return p
		p = path.normalize path.join @project.source_dir, rel_path
		if path.existsSync p
			return p
		else
			return rel_path
			
			
	checkFile: () ->
		p = @findSourcePath(@file)
		fs.statSync(p)
	
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

Target = Node

			
Target::options = (options) ->
	for key, val of options
		@options[key] = val
		
Target::read = () ->

	# May make this an explicit build command?
	@buffer.contents = @sources
	@buffer.length = @sources.length
	@buffer.type = Buffer.TYPE_SOURCE

Target::pop = () ->

	@buffer.pop()


Target::shift = () ->

	@buffer.shift()


Target::cat = () ->
	
	@buffer.toString()
	
	if 1 < @buffer.length
		@buffer.contents = @buffer.contents.join('\n')
		@buffer.length = 1
	
	DEBUG "Concatenated files"


# Writes buffer contents to output directory (using target name as the filename)
Target::write = (filenames) ->
	
	@buffer.toString()
	
	if filenames? and filenames
		if typeof filenames == 'string'
			filenames = [filenames]
	else
		filenames = [@name]
	
	unless @buffer.length == filenames.length
		error 'Cannot write files -- buffer length and filenames are different sizes'
	
	for i in [0...@buffer.length]
	
		loc = path.join @project.build_dir, filenames[i]
	
		# Make sure directory exists
		mkdirP path.dirname loc
	
		fs.writeFileSync loc, @buffer.contents[i], 'utf8'
	
		DEBUG "Writing #{loc}"
	
# Writes buffer contents to staging directory (using target name as the filename)
Target::writeTmp = (filenames) ->
	
	@buffer.toString()
	
	if filenames? and filenames
		if typeof filenames == 'string'
			filenames = [filenames]
	else
		filenames = [@name]
	
	unless @buffer.length == filenames.length
		error 'Cannot write files -- buffer length and filenames are different sizes'
	
	for i in [0...@buffer.length]
	
		loc = path.join @project.staging_dir, filenames[i]
	
		# Make sure directory exists
		mkdirP path.dirname loc
	
		fs.writeFileSync loc, @buffer.contents[i], 'utf8'
	
		DEBUG "Writing #{loc}"
	

Target::coffee2js = () ->
	###
	@buffer.toFile()
	
	for i in [0...@buffer.length]
		file = @buffer.contents[i]
		file_out = changeExtension(file, 'coffee','js')
		file_out = path.join @project.staging_dir, file_out
		
		DEBUG 'here ', file, file_out
		exec cmd_coffee(file, file_out), (err, stdout, stderr) ->
			if err
				error("coffee #{file} failed: " + err) 
			else
				info "Compiled #{file} to #{file_out}"
	###
	
	@buffer.toString()

	for i in [0...@buffer.length]
		c = @buffer.contents[i]
		compiled = coffee.compile(c)
		@buffer.contents[i] = compiled

		
Target::minify = () ->
	@buffer.toFile()
	
	input = @buffer.contents[0]
	output = path.join @project.build_dir, @name

	result = shell.exec cmd_minify(input, output)
	
	info "Minified #{output}"
	
	@buffer.contents[0] = output

Target::appendFile = (file) ->

	@buffer.toString()
	
	info "Append " + file
	
	file = @findSourcePath(file)
	
	contents = fs.readFileSync file, 'utf8'
	unless contents
		error 'Could not read file ' + file
		
	for i in [0...@buffer.length]
		@buffer.contents[i] = @buffer.contents[i] + '\n' + contents

Target::prependFile = (file) ->

	@buffer.toString()
	
	info "Prepend " + file
	
	file = @findSourcePath(file)
	
	contents = fs.readFileSync file, 'utf8'
	unless contents
		error 'Could not read file ' + file
		
	for i in [0...@buffer.length]
		@buffer.contents[i] = contents + '\n' + @buffer.contents[i]
			
		
Target::append = (append_string) ->
		
	@buffer.toString()
	
	for i in [0...@buffer.length]
		@buffer.contents[i] = @buffer.contents[i] + '\n' + append_string
		

Target::prepend = (prepend_string) ->
			
	@buffer.toString()
	
	for i in [0...@buffer.length]
		@buffer.contents[i] = prepend_string + '\n' + @buffer.contents[i]
	

changeDirectory = (filenames, destination) ->

	string = false
	if typeof filenames == 'string'
		string = true
		filenames = [filenames]
		
	output = new Array(filenames.length)

	for i in [0...filenames.length]
		output[i] = path.join destination, path.basename filenames[i]
	
	if string
		return output[0]
	else
		return output

changeExtension = (filenames, oldext, newext) ->
	r = new RegExp('\.' + oldext + '$', 'i')
	
	string = false
	if typeof filenames == 'string'
		string = true
		filenames = [filenames]
		
	output = new Array(filenames.length)

	for i in [0...filenames.length]
		if filenames[i].match(r)
			output[i] = filenames[i].replace(r, '.' + newext)
		else
			output[i] = filenames[i] + '.' + newext
	
	if string
		return output[0]
	else
		return output
		
timestamp = (time) ->

	year = time.getFullYear()
	hour = time.getHours()
	min = time.getMinutes()
	month = time.getMonth()
	day = time.getDate()

	ret = String(year)
	if month+1 < 10
		ret = ret + '0' + (month+1)
	else
		ret = ret + (month+1)
	if day < 10
		ret = ret + '0' + day
	else
		ret = ret +  day
	
	if hour < 10
		ret = hour + '0' + hour
	else
		ret = ret + hour
		
	if min < 10
		ret = min + '0' + min
	else
		ret = ret + min

mkdirP = (p, mode) ->
	p = path.normalize(p)
	# Quick check and return
	if path.existsSync(p)
		return true

	parts = p.split(dirsep)
	# Search backward to find first non-missing directory.
	dirs = parts.length
	pos = dirs
	missing_pos = 1
	while 0 < pos
		if path.existsSync(parts[0...pos].join(dirsep))
			missing_pos = pos + 1
			break
		else
		pos -= 1

	# Create directories recursively from there.
	pos = missing_pos
	while pos <= dirs
		DEBUG 'mkdirP() Creating ' + parts[0...pos].join(dirsep)
		fs.mkdirSync parts[0...pos].join(dirsep)
		pos += 1


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
	project = ProjectManager.latest
	unless project
		error 'No project declared'
	else 
		return project.createTarget(name, sources, build_function)

exports.debug = DEBUG
exports.changeExtension = changeExtension
exports.changeDirectory = changeDirectory

project = ProjectManager.createProject

exports.target = target
exports.project = project


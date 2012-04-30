
cmd_coffee = (sources, output) ->
	"coffee --output #{output} --compile #{sources}"
	
cmd_minify = (sources, output) ->
	"yui-compressor  -o #{output}  #{sources}"

fs	 = require 'fs'
path = require 'path'
{exec} = require 'child_process'
util   = require 'util'
#mini = 'yui-compressor -o'

tsort   = (require './tsort').tsort

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


class Project
	staging_dir = '=staging/'
	output_dir = '=build/'
	@instance = null

	constructor: (options) ->
		DEBUG 'Constructor'
		@setOptions(options) if options?
		
	setOptions: (options) ->
		DEBUG 'Setoptions'
		@output_dir = options.output_dir if options.output_dir? 
		@staging_dir = options.output_dir if options.output_dir? 

class Buffer
	input_files = null
	output_files = null
	contents = null
	staging_dir = null
	length = 0
	type = 0
	
	@TYPE_SOURCE = 10
	@TYPE_FILEPATH = 20
	@TYPE_STRING = 30
	
	constructor: (sources, staging_dir) ->
		@staging_dir = staging_dir
		files = new Array(@length)
		for source, index in sources then do (source, index) =>
			files[index] = source.file
		@input_files = files
		@output_files = files
		@contents = sources
		@length = sources.length
		@type = Buffer.TYPE_SOURCE
		
		
	toString: () ->
		if @type == Buffer.TYPE_SOURCE 
			contents = new Array(@length)
	
			for source, index in @contents then do (source, index) =>
				#fs.readFile "#{source.file}", 'utf8', (err, fileContents) =>
				#	wait_for = true and error(err) if err
				#	@buffer[index] = source.getFileContents()
				#	if --remaining is 0
				#		DEBUG 'done reading'
				#		wait_for = true 
				contents[index] = fs.readFileSync "#{source.file}", 'utf8'
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
				contents[index] = source.file
			@type = Buffer.TYPE_FILEPATHS
			@contents = contents
			return @contents
		else if @type == Buffer.TYPE_STRING
			contents = new Array(@length)
			for i in [0...@length]
				filename = uuid4()
				filename = path.join(@staging_dir, filename)
				fs.writeFileSync filename, @contents[i], 'utf8'
				contents[i] = filename
			@type = Buffer.TYPE_FILEPATHS
			@contents = contents
			return @contents
		else if @type == Buffer.TYPE_FILEPATHS
			return @contents
	
	pop: () ->
		removed = @contents.pop()
		@length = @contents.length
		return removed

	shift: () ->
		removed = @contents.shift()
		@length = @contents.length
		return removed



class NodeManager
	@unresolved_nodes = {}
	#@targets = {}
	@STATUS_UPTODATE = 0
	@STATUS_NEEDSUPDATE = 10
	@STATUS_UPDATING = 20
	
	@createTarget: (project, name, sources, build_function) ->
		DEBUG 'NodeManager:createTarget()', 'called args=', JSON.stringify(i for i in arguments)
		if node = NodeManager.getNode(name)
			if node.is_target == true
				warn 'NodeManager:createTarget()', 'Re-defining target ' + name
		else
			node = NodeManager.createNode(project, name)
			
		node.build_function = build_function
		node.is_target = true
		
		for source_name in sources
			source = NodeManager.createNode(project, source_name)
			source.is_source = true
			node.addSource(source)
		
		return node


	@getNode: (name) ->
		return NodeManager.unresolved_nodes[name]
		
	@createNode: (project, name) ->
		unless node = NodeManager.unresolved_nodes[name]
			node = NodeManager.unresolved_nodes[name] = new Node(project, name)		
		return node

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
		DEBUG 'Node:New()', 'called args=', JSON.stringify(i for i in arguments)
		@project = project 
		@name = name
		@file = name
		@sources = []
		@targets = []
		#@buffer = new Buffer(@sources, @project.staging_dir)
		
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
				if @sources
					@buffer = new Buffer(@sources, @project.staging_dir)
				@build_function()
				# Serial execution
				@done()
			else
				DEBUG 'Node:build()', 'no build_function'
				@is_building = false
				if @sources
					@buffer = new Buffer(@sources, @project.staging_dir)
				@done()
				
	
	done: () ->
		@is_up_to_date = true
		@is_building = false
		for target in @targets
			target.checkSourceBuilds()
	
	checkFile: () ->
		fs.statSync(@file)
	
	getFileContents: () ->
		@buffer = fs.readFileSync "#{@file}", 'utf8'

			
"""
	getFileContents: () ->
		fs.readFile "#{@name}", 'utf8', (err, file_contents) =>
			if err
				error("readFile #{@name} failed: " + err) 
			else
				DEBUG "Read file #{@name}"
			@buffer = file_contents
			@done()
"""
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
		
Target::cat = () ->
	
	@buffer.toString()
	
	if 1 < @buffer.length
		@buffer.contents = @buffer.contents.join('\n')
		@buffer.length = 1
	
	DEBUG "Concatenated files"


Target::write = () ->
	
	@buffer.toString()
	
	if 1 < @buffer.length
		@buffer.contents = @buffer.contents.join('\n')
		@buffer.length = 1
		
	fs.writeFileSync path.join(@project.output_dir, @name), @buffer.contents, 'utf8'
	
	DEBUG "Writing #{path.join(@project.output_dir, @name)}"
	
	
Target::read = (files) ->
	
	@buffer.toString()
	if files? and files
		@buffer = new Buffer(files, @project.staging_dir)



Target::coffee2js = () ->
	exec cmd_coffee(@sources, @name), (err, stdout, stderr) ->
		if err
			error("coffee #{@name} failed: " + err) 
		else
			info "Compiled #{@name}"
		
		
Target::minify = () ->
	@buffer.toFile()

	exec cmd_minify(@buffer.contents[0], @name), (err, stdout, stderr) => 
		if err
			error("Minify #{@name} failed: " + err) 
		else
			info "Minified #{@name}"

Target::appendFile = (file) ->
	
	appendFileContents = fs.readFileSync file, 'utf8'
	unless appendFileContents
		error 'Could not read file ' + file
		
	@buffer.toString()
	
	if 1 < @buffer.length
		@buffer.contents = @buffer.contents.join('\n') + '\n' + appendFileContents
		@buffer.length = 1

Target::prependFile = (file) ->
	
	prependFileContents = fs.readFileSync file, 'utf8'
	unless prependFileContents
		error 'Could not read file ' + file
		
	@buffer.toString()
	
	if 1 < @buffer.length
		@buffer.contents = prependFileContents + '\n' + @buffer.contents.join('\n')
		@buffer.length = 1


Target::append = (append_string) ->
		
	@buffer.toString()
	
	if 1 < @buffer.length
		@buffer.contents = @buffer.contents.join('\n') + '\n' + append_string
		@buffer.length = 1
		

Target::prepend = (prepend_string) ->
			
	@buffer.toString()
	
	if 1 < @buffer.length
		@buffer.contents = prepend_string + '\n' + @buffer.contents.join('\n')
		@buffer.length = 1

	
	
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
	

target = (name, sources, build_function) ->
	project = if Project.instance then Project.instance else new Project()
	DEBUG project
	return NodeManager.createTarget(project, name, sources, build_function)
	
project = (options) ->
	if Project.instance
		Project.instance.setOptions(options)
		return Project.instance
	else
		return project = new Project(options)

exports.target = target
exports.project = project


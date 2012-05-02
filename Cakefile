
# Bootstrap Builder file :)
builder   = require './src/cs/builder'

target  = builder.target
project = builder.project

test = project('builder', 
	build_dir: './=build'
	staging_dir: './=staging'
	source_dir: './src'
)

#coffee_files = builder.ls(test.source_dir + '/coffee/*.coffee')
coffee_files = ['cs/tsort.coffee', 'cs/builder.coffee']

all = target 'All', ['coffeescripts','package.json']


target 'coffeescripts', coffee_files, ->
	@read()
	@write(builder.changeDirectory(coffee_files, './'))


target 'package.json', ['package.json.tmpl'], ->
	@read()
	@write()
	

task 'build', 'Build Project', ->
	all.build()
	builder.debug coffee_files
	


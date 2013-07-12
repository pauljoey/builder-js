

#####################################################################
# Required Builder setup
#####################################################################

# Bootstrap Builder file :)
builder   = require './src/lib/builder'
target    = builder.target
project   = builder.project

option('-t', '--target [TARGET]', 'Target to build (default: "build").');

task 'build', 'Build project', (options) ->
	options.target = 'build' unless options.target? 
	builder.run(options.target, builder.lastProject())
	
task 'watch', 'Build project and watch for changes', (options) ->
	options.target = 'build' unless options.target? 
	builder.watch(options.target, builder.lastProject())
#####################################################################


builderProject = project('builder', 
	build_dir: './=build'
	staging_dir: './=staging'
	source_dir: './src'
)

#coffee_files = builder.ls(test.source_dir + '/coffee/*.coffee')
coffee_files = ['lib/tsort.coffee', 'lib/base.coffee', 'lib/cmd.coffee', 'lib/util.coffee', 'lib/targets.coffee', 'lib/builder.coffee']
coffee_files_out = coffee_files

target 'build', ['coffeescripts','package.json']


target 'coffeescripts', coffee_files, ->
	@read()
	@write(coffee_files_out)

target 'install', ['build'], ->
	curr = builder.shell.pwd()
	builder.shell.cd builderProject.build_dir
	try
		builder.shell.exec 'sudo npm -g install'
	catch err
		builder.shell.cd curr
		throw err
	builder.shell.cd curr


target 'test', ['build'], ->
	builder.debug('Test test bleep blorp')

target 'package.json', ['package.json.tmpl'], ->
	@read()
	@write()


target 'clean', [], ->
	builder.shell.rm('-rf', @project.build_dir + '/*')
	builder.shell.rm('-rf', @project.staging_dir + '/*')



builder-js
==========

**BuilderJS** is a Make-like build system for Node. Allows you to build (and re-build) your projects YOUR way (with help if you want it). It features lazy evaluation of dependencies, file watching and a tonne of high-level helper functions to speed things up for you.

**BuilderJS** is inspired by *Cake*, *Jake*, *Make* and innumerable other build systems. Why another build system, you ask? **BuilderJS** was designed to be:

 1. Highly customizable with no assumptions as to how you "should" build or structure your projects
 2. Quick/Easy to put into use for building web projects (lots of high-level helper functions)
 3. Able to continuously watch and build projects efficiently

This is omega (pre-alpha) software, meaning it could spell your doom. It is currently being developed to be made suitable for broader use. If you actually get it working and get some use out of it, let me know!! It would make my day. Feedback welcome.

Prerequisites
-------------

Since this is a node-based build system.. you must have a recent ```node``` and ```npm``` installed. 

Installation
------------

**BuilderJS** is not currently available in the NPM repository. You must build it yourself.



1. Clone this repository.

```
    git clone git@github.com:pauljoey/builder-js.git builder-js.git
    cd builder-js.git
```

2. Install dependencies

```
    npm install coffee-script shelljs uglify-js crypto growl
```

3. Build BuilderJS (this will install BuilderJS globally, requires sudo privileges)

```
    ./src/bin/builder install
```


Usage
-----

To use **BuilderJS**, place a filed named ```Builderfile``` in the root of your project, which works like a Coffeescript-style ```Cakefile```. ```Builderfile``` understands two commands: 

1. ```project (project_name, options) ``` - creates a project namespace and defines build options
2. ```target (target_name, sources, build_function)``` - defines build rules which are placed inside the most recently declared project). 

Additionally, there is also a ```builder``` object that can be used to access additional features / options. 

Build functions have access to a host of high-level helper functions. These helper functions typically transform a buffer object in sequence which is ultimately either written to file or passed through to another rule.

A ```Builderfile``` looks like this:

``` coffeescript
#!/usr/bin/env builder


project('builder', 
	build_dir: './=build'
	staging_dir: './=staging'
	source_dir: './src'        # Read 
)

coffee_files = builder.shell.ls('./src/coffee/*.coffee')

# This is the default target
target 'build', ['js/app.js.min']

target 'js/app.js.min', ['app.coffee'], ->
	@read()
	@coffee2js()
	@write('js/app.js') # For debugging! :)
	@minifyJS()
	@prepend('*/')
	@prependFile('LICENSE')
	@prepend('/*')
	@write()
	

target 'app.coffee', coffee_files, ->
	@read()
	@cat()
	@writeTmp() # Useful for debugging

target 'clean', [], ->
	# These calls are dangerous!
	builder.shell.rm('-rf', test_project.build_dir + '/*')
	builder.shell.rm('-rf', test_project.staging_dir + '/*')
```

Once you've created a ```Builderfile```, you can build a defined target by running the command (anywhere inside your project directory):

```
	builder [-w --watch] <target>
```

If you specify ```-w```, the dependent files will be watched for changes and continuously re-built. Calling ```builder``` without a target lists all defined targets.

It is common for **BuilderJS** targets to make extensive use of the ```ShellJS``` library, which is made conveniently accessible via the ```builder.shell``` object.

Build function helpers
----------------------

Basic:
 - ```@read([sources])``` Read ```[sources]``` into the buffer. Can be a file in the source directory or another named target. If undefined, then the target's sources are used. This is usually called first.
 - ```@write([filenames])``` Write the contents of the buffer to [filenames] in the build directory. If [filenames] is empty, then the name of the target is used. This is often the last function called in a build rule.
 - ```@writeTmp([filenames])``` Write the contents of the buffer to [filenames] in the staging. If [filenames] is empty, then the name of the target is used.
 
Transformations:
 - ```@cat()``` Concatenate buffer into a single string.
 - ```@coffee2js()``` Read the contents of ```file``` and prepend it to the buffer.
 - ```@replace(match, replace)``` Search for instances of ```match``` in the buffer and replace them with ```replace```.
 - ```@minifyJS()``` Minifies buffer using uglifyjs (binary must be installed).
 - ```@minifyCSS()``` Minifies buffer using yui-compressor (binary must be installed).
 - ```@append(string)``` Appends ```string``` to the buffer.
 - ```@prepend(string)``` Prepends ```string``` to the buffer.
 - ```@appendFile(file)``` Read the contents of ```file``` and append it to the buffer.
 - ```@prependFile(file)``` Read the contents of ```file``` and prepend it to the buffer.


Other:
 - ```@find(pattern)``` Find ```pattern``` in the buffer and return the result
 - ```@sha256()``` Returns sha256 checksum of buffer


Philosophy
----------

 - Source directory != Build directory
 - 
 - Support common tasks with helper functions
 
 
Testing
-------

Try this:

```
    cd examples/simple
    builder build
```


To-do
-----

Todo:

 - Lots
 - Documentation (in progress)
 - Unit testing (in progress)
 - Implement modularized plugin system for adding target functions
 - Support for variable/changing sources (directories of files, etc)
 - Browserify-like rule for auto-building node files and their dependencies, LESS scripts, etc
 - Code clean-up

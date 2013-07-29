Importer
========

Importer adds an `#import` statement to JavaScript based languages including CoffeeScript that works like 
`#include` in C-based languages.  It compiles files into JavaScript, concatenates them together in the 
places you've defined, generates [source maps](https://docs.google.com/document/d/1U1RGAehQwRypUTovF1KRlpiOFze0b-_2gc6fAH0KY0k), 
and manages recompilation for only those files that have changed, speeding up builds for large projects.

```coffeescript
#import "name"
#import "another.coffee"
#import "somefile.js"
    
# some code using the imported files here...
```
    
In JavaScript, the `//import` directive can be used instead of `#import`.  

## Features

* Import statements can be placed anywhere and the dependency source code will replace it.
* Compiling CoffeeScript and JavaScript source files are included out of the box.  You can add more 
  to the `importer.extensions` object.
* Support for generating [source maps](https://docs.google.com/document/d/1U1RGAehQwRypUTovF1KRlpiOFze0b-_2gc6fAH0KY0k).
* Support for framework or library dependencies in a search path as well as relative paths.
* File extensions are optional and will be automatically resolved if not included.  
* Files will only be included once in the resulting code, regardless of how many times a file is imported.
* If used as a server, only modified files will be recompiled on subsequent requests.
* Can be used to run the compiled code directly on the command line or `require`d in a Node module.
  
## Command line usage

When installed with `npm install importer -g`, a command line tool called `importer` will be made available.

1. To start a server to host your compiled code, run `importer mainfile.coffee --port 8080`
2. To output to a file, run `importer mainfile.coffee main.js`
3. To compile and execute, run `importer mainfile.coffee`

The command line options include:

    -p, --port        Port to start server on       
    -f, --frameworks  Path to frameworks directory    [default: "./frameworks"]
    -m, --minify      Minifies the output JavaScript  [boolean]
    -s, --source-map  Whether to output a source map  [boolean]

## Node module usage

```coffeescript
importer = require 'importer'
pkg = importer.createPackage './path/to/main/file',
    frameworkPath: '/path/to/frameworks'
    sync: false               # whether compilation should be synchronous (default: false)
    sourceMap: 'out.js.map'   # filename/url of the output sourcemap (default: null)
    minify: false             # whether to minify the output with UglifyJS
        
# if asynchronous...
pkg.build (err, result) ->
    # result is an object containing 
    # {code: 'compiled js', map: 'sourcemap if requested'}
        
# if synchronous...
try
    result = pkg.build()
catch err
    # do something
        
# to load and run the result as a node module...
moduleExports = pkg.require()

# or, without creating a package
moduleExports = importer.require './path/to/main/file',
    frameworkPath: '/path/to/frameworks'
```

## Connect/Express middleware

```coffeescript
# options supports all options documented above, plus the `url`
# attribute giving the route to use to access the compiled JS.
# Defaults to `"/#{path.basename(main, path.extname(main))}.js"`
# Sourcemaps are automatically generated at "#{url}.js.map" unless
# you turn them off by setting the `sourceMap` option to `false`.
app.use importer.middleware('main.coffee', options)
```
    
## Adding additional languages

Currently, importing CoffeeScript and JavaScript files are supported but you can extend that to other languages that compile to
JavaScript by adding an entry to the `importer.extensions` object.

```coffeescript
importer.extensions['.lua'] = (code, generateSourceMap) -> 
    return lua.compile(code)
```
        
If a language compiler supporting source maps is used, you should first check the `generateSourceMap` option to be sure that
they are desired by the user, and if so, return an object containing `{code: 'compiled js', map: 'sourcemap'}`.  Otherwise, 
return a string.
    
## License

The `importer` module is licensed under the MIT license.
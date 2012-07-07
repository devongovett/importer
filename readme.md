Client side build tool with dependency management
=================================================

Ever wanted to have an `#import` statement in your favorite language which
compiles into JavaScript that works like `#include` in other languages?
Well now you have one! Importing files and concatenating them in the right
place is now as easy as:

    #import "some_js_file"
    #import "another_one"
    #import "even_coco_is_supported"
    #import "and_livescript"
    
    # some code using the imported files here...
    
In JavaScript, the `//import` directive is used instead of `#import`.  

Be sure to install the languages you wish to use with `npm install -g`.

## Features

* File extensions are optional and will be automatically resolved if not
  included.
  - In fact it is recommended to never use file extensions when importing.
* Files will only be included once in the resulting code, regardless of how
  many times a file is imported.
* If used as a server, only modified files will be recompiled on subsequent
  requests.
* Compiling CoffeeScript, JavaScript, Coco, and LiveScript source files are
  included out of the box.  You can add more to the `compile.extensions` object.
  - Or add support to the bottom of src/import.coffee and submit a pull request.
  
## Command line usage

When installed with `npm install import -g`, a command line tool called
`import` will be made available.

Usage: import input_file [output_file] [options]

Available options:
  -h, --help          shows this help section
  -p, --port NUMBER   start a server to serve the file on this port
  -b, --bare          compile without a top-level function wrapper

If an output file is not provided, a server will be started at
the port provided by the --port or -p option or 8080 by default.

## Server example

```coffee
  http = require 'http'
  compile = require 'import'

  server = http.createServer (req, res) ->
   res.writeHead(200)
  
   compile 'mainfile', (err, code) ->
     if err
       res.end 'throw unescape("' + escape(err.toString()) + '");'
     else
       res.end code
  
  server.listen(8080)
```

## Out-of-the-box supported languages

 * JavaScript
 * Coffee-Script
 * LiveScript
 * Coco

To add out-of-the-box support for another language, add it to the bottom of
src/import.coffee and submit a pull request.

To add support by wrapping the code, add an entry to the `compile.extensions`
object:

```coffee
  compile.extensions['.lua'] =
    compile: (code) -> lua.compile(code)
    import_re: /^--import (".+")$/gm
```

## Developing import

To compile and watch:

    coffee -wco . src/

To run the tests:

    npm test
    
## License

The `import` module is licensed under the MIT license.

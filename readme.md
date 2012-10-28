File Importing for CoffeeScript and JavaScript
==============================================

Ever wanted to have an `#import` statement in CoffeeScript or JavaScript that works like `#include` in other languages?
Well now you have one!  Importing files and concatenating them in the right place is now as easy as:

    #import "name"
    #import "another.coffee"
    #import "somefile.js"
    
    # some code using the imported files here...
    
In JavaScript, the `//import` directive is used instead of `#import`.  

## Features

* File extensions are optional and will be automatically resolved if not included.  
* Files will only be included once in the resulting code, regardless of how many times a file is imported.
* If used as a server, only modified files will be recompiled on subsequent requests.
* Import statements can be placed anywhere and the dependency source code will replace it.
* Compiling CoffeeScript and JavaScript source files are included out of the box.  You can add more 
  to the `importer.extensions` object.
  
## Command line usage

When installed with `npm install importer -g`, a command line tool called `importer` will be made available.

1. To start a server to host your compiled code, run `importer mainfile.coffee --port 8080`
2. To output to a file, run `importer mainfile.coffee main.js`
3. To compile and execute, run `importer mainfile.coffee`

## Server example

    http = require 'http'
    importer = require 'importer'

    server = http.createServer (req, res) ->
        res.writeHead(200)
    
        importer.build 'mainfile.coffee', (err, code) ->
            if err
                res.end 'throw "' + (err).replace(/"/g, "\\\"") + '"'
            else
                res.end code
    
    server.listen(8080)

Currently, importing CoffeeScript and JavaScript files are supported but you can extend that to other languages that compile to
JavaScript by adding an entry to the `importer.extensions` object.

    importer.extensions['.lua'] = (code) -> lua.compile(code)
    
## License

The `importer` module is licensed under the MIT license.
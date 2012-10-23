importer = require './importer'
http = require 'http'
fs = require 'fs'

{argv} = require('optimist')
    .usage('Usage: importer input_file [output_file] [options]')
     # require input_file
    .demand(1)
    # describe port option
    .alias('p', 'port')
    .describe('p', 'Port to start server on')
    .default('p', 8080)
    # describe frameworks option
    .alias('f', 'frameworks')
    .describe('f', 'Path to frameworks directory')
    .default('f', './frameworks')
            
[input_file, output_file] = argv._
importer.frameworkPath = argv.frameworks

if output_file
    importer.build input_file, (err, code) ->
        throw err if err
        fs.writeFile(output_file, code)
        
else
    server = http.createServer (req, res) ->
        res.writeHead(200)
        
        importer.build input_file, (err, code) ->
            if err
                res.end 'throw "' + (err).replace(/"/g, "\\\"") + '"'
            else
                res.end code
                
    server.listen(argv.port)
    console.log 'Server listening at port ' + argv.port
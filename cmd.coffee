importer = require './importer'
http = require 'http'
fs = require 'fs'

{argv} = require('optimist')
    .usage('''
        Usage: $0 input_file [output_file] [options]
        
        If called with no options, input_file will be compiled and executed.
    ''')
    
     # require input_file
    .demand(1)
    
    # describe port option
    .alias('p', 'port')
    .describe('p', 'Port to start server on')
    
    # describe frameworks option
    .alias('f', 'frameworks')
    .describe('f', 'Path to frameworks directory')
    .default('f', './frameworks')
            
[input_file, output_file] = argv._
importer.frameworkPath = argv.frameworks

# output to file
if output_file
    importer.build input_file, (err, code) ->
        throw err if err
        fs.writeFile(output_file, code)
        
# start a server
else if argv.port
    server = http.createServer (req, res) ->
        res.writeHead(200)
        
        importer.build input_file, (err, code) ->
            if err
                res.end 'throw "' + err.message.replace(/"/g, "\\\"") + '"'
            else
                res.end code
                
    server.listen(argv.port)
    console.log 'Server listening at port ' + argv.port
    
# execute
else
    importer.require input_file
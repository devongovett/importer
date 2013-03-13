importer = require './importer'
http = require 'http'
fs = require 'fs'
path = require 'path'

usage = '''
    Usage: $0 input_file [output_file] [options]
        
    If called with no options, input_file will be compiled and executed.
'''

{argv} = require('optimist')
    .usage(usage)
    
     # require input_file
    .demand(1)
    
    # describe port option
    .alias('p', 'port')
    .describe('p', 'Port to start server on')
    
    # describe frameworks option
    .alias('f', 'frameworks')
    .describe('f', 'Path to frameworks directory')
    .default('f', './frameworks')
    
    # describe minify option
    .alias('m', 'minify')
    .describe('m', 'Minifies the output JavaScript')
    .boolean('m')
    
    # describe source-map option
    .alias('s', 'source-map')
    .describe('s', 'Whether to output a source map')
    .boolean('s')
            
[input_file, output_file] = argv._

pkg = importer.createPackage input_file,
    frameworkPath: argv.frameworks
    minify: argv.minify
    sourceMap: argv['source-map']

# output to file
if output_file
    if argv['source-map']
        pkg.sourceMap = "#{output_file}.map"
        
    pkg.build (err, built) ->
        throw err if err
        
        fs.writeFile(output_file, built.code)
        fs.writeFile(pkg.sourceMap, built.map) if built.map
        
# start a server
else if argv.port
    if argv['source-map']
        pkg.sourceMap = "#{path.basename(input_file)}.map"
    
    server = http.createServer (req, res) ->
        res.writeHead(200)

        pkg.build (err, built) ->
            if err
                res.end 'throw "' + err.message.replace(/"/g, "\\\"") + '"'
            else if req.url is "/#{pkg.sourceMap}"
                res.end built.map
            else
                res.end built.code
                
    server.listen(argv.port)
    console.log 'Server listening at port ' + argv.port
    
# execute
else
    pkg.require()
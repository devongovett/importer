#!/usr/bin/env node

var http = require('http'),
    compile = require('./import'),
    fs = require('fs');
    
var mainfile = process.argv[2],
    output = process.argv[3];
    
if (!mainfile) {
    console.log('\x1b[1mUsage\x1b[0m: import input_file [output_file] [options]\n');
    console.log('If an output file is not provided, a server will be started at');
    console.log('at the port provided by the --port or -p option or port 8080 by default.')
    process.exit();
}

if (output && output != '-p' && output != '--port') {
    compile(mainfile, function(err, code) {
        if (err) throw err;
        fs.writeFile(output, code);
    });
}
else {
    var port = output == '-p' || output == '--port' ? +process.argv[4] : 8080;
    
    http.createServer(function(req, res) {
        res.writeHead(200);
    
        compile(mainfile, function(err, code) {
            if (err)
                res.end('throw "' + (err).replace(/"/g, "\\\"") + '"');
            else
                res.end(code);
        });
        
    }).listen(port);
    
    console.log('Server listening at port ' + port);
}
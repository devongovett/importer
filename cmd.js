#!/usr/local/bin/node

var http = require('http'),
    compile = require('./import'),
    fs = require('fs'),
    optparse = require('optparse');

var switches = [
    ['-h', '--help', "shows this help section"],
    ['-p', '--port NUMBER', "start a server to serve the file on this port"],
];

var parser = new optparse.OptionParser(switches);

var printUsage = function() {
    parser.banner = "Usage: import input_file [output_file] [options]"
    console.log(parser.toString());
    console.log('\nIf an output file is not provided, a server will be started at');
    console.log('at the port provided by the --port or -p option or port 8080 by default.')
};

parser.on('help', function() {
    printUsage();
    process.exit(1);
});

var mainfile;
parser.on(0, function(arg) {
    mainfile = arg;
});

var output;
parser.on(1, function(arg) {
    output = arg;
});

var port;
parser.on("port", function(name, value) {
    port = value;
});

parser.parse(process.argv.splice(2));

if (!mainfile) {
    printUsage();
    process.exit(1);
}

if (output) {
    compile(mainfile, function(err, code) {
        if (err) throw err;
        fs.writeFile(output, code);
    });
}

if (port || !output) {
    port = port || 8080;
    
    http.createServer(function(req, res) {
        res.writeHead(200);
    
        compile(mainfile, function(err, code) {
            if (err)
                res.end('throw "' + (err).replace(/"/g, "\\\"") + '"');
            else
                res.end(code);
        });
        
    }).listen(port);
    
    console.log("Server listening at http://localhost:" + port);
}

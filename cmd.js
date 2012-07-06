#!/usr/local/bin/node

var http = require('http'),
    compile = require('./import'),
    fs = require('fs'),
    optparse = require('optparse');

var switches = [
    ['-h', '--help', "shows this help section"],
    ['-p', '--port NUMBER', "start a server to serve the file on this port"],
    ['-b', '--bare', "compile without a top-level function wrapper"],
];

var parser = new optparse.OptionParser(switches);

var printUsage = function() {
    parser.banner = "Usage: import input_file [output_file] [options]"
    console.log(parser.toString());
    console.log('\nIf an output file is not provided, a server will be started at');
    console.log('the port provided by the --port or -p option or 8080 by default.')
};

parser.on('help', function() {
    printUsage();
    process.exit(1);
});

var options = {};
parser.on(0, function(arg) {
    options.mainfile = arg;
});

var output;
parser.on(1, function(arg) {
    output = arg;
});

var port;
parser.on("port", function(name, value) {
    port = value;
});

var options = {};
parser.on("bare", function() {
    options.bare = true;
});

parser.parse(process.argv.splice(2));

if (!options.mainfile) {
    printUsage();
    process.exit(1);
}

if (output) {
    compile(options, function(err, code) {
        if (err) throw err;
        fs.writeFile(output, code);
    });
}

if (port || !output) {
    port = port || 8080;
    
    http.createServer(function(req, res) {
        res.writeHead(200);
    
        compile(options, function(err, code) {
            if (err)
                res.end('throw unescape("' + escape(err.toString()) + '");');
            else
                res.end(code);
        });
        
    }).listen(port);
    
    console.log("Server listening at http://localhost:" + port);
}

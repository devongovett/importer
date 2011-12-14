(function() {
  var File, coffee, compile, fs, path;

  coffee = require('coffee-script');

  fs = require('fs');

  path = require('path');

  File = (function() {
    var check, imported, resolve;

    function File(filename) {
      this.filename = filename;
      this.dependancies = [];
      this.compiled = '';
    }

    File.files = {};

    imported = {};

    File.load = function(filename, isImport) {
      var file;
      if (!isImport) imported = {};
      if (this.files[filename]) return this.files[filename];
      file = new File(filename);
      this.files[filename] = file;
      return file;
    };

    File.extensions = {
      '.coffee': function(code) {
        return coffee.compile(code, {
          bare: true
        });
      },
      '.js': function(code) {
        return code;
      }
    };

    resolve = function(filename, callback) {
      var ext, exts, fullname, proceed;
      fullname = path.resolve(filename);
      if ((ext = path.extname(fullname)) in File.extensions) {
        return check(filename, fullname, ext, callback);
      }
      exts = Object.keys(File.extensions);
      return (proceed = function() {
        if (exts.length) {
          ext = exts.shift();
          return check(filename, fullname + ext, ext, callback, proceed);
        } else {
          return callback('"' + filename + '" could not be found.');
        }
      })();
    };

    check = function(filename, filepath, ext, callback, proceed) {
      return fs.stat(filepath, function(err, stat) {
        if (err || stat.isDirectory()) {
          if (proceed) return proceed();
          return callback('"' + filename + '" could not be found.');
        }
        return fs.realpath(filepath, function(err, realpath) {
          return callback(err, realpath, ext, stat);
        });
      });
    };

    File.prototype.load = function(callback) {
      var _this = this;
      return resolve(this.filename, function(err, path, ext, stat) {
        _this.ext = ext;
        if (err) return callback(err, _this);
        if (+stat.mtime === _this.mtime && path === _this.path) {
          return callback(null, _this);
        }
        _this.path = path;
        return fs.readFile(_this.path, 'utf8', function(err, code) {
          if (err) return callback(err);
          try {
            _this.compiled = File.extensions[_this.ext](code);
          } catch (err) {
            return callback("" + err + " in " + _this.path, _this);
          }
          _this.mtime = +stat.mtime;
          return _this.parse(code, callback);
        });
      });
    };

    File.prototype.parse = function(code, callback) {
      var importRe, proceed;
      var _this = this;
      importRe = /^(?:#|\/\/)import "(.+)"$/gm;
      this.dependancies = [];
      return (proceed = function() {
        var file, filename, result;
        if (result = importRe.exec(code)) {
          filename = result[1];
          if (filename[0] !== '/') {
            filename = path.join(path.dirname(_this.path), filename);
          }
          file = File.load(filename, true);
          return file.load(function(err, file) {
            _this.dependancies.push(file);
            if (err) return callback(err, _this);
            return proceed();
          });
        } else {
          return callback(null, _this);
        }
      })();
    };

    File.prototype.compile = function(callback) {
      var _this = this;
      imported[this.path] = true;
      return this.load(function(err) {
        var code, deps, proceed;
        if (err) return callback(err);
        code = [];
        deps = _this.dependancies.slice();
        return (proceed = function() {
          var dep;
          if (deps.length) {
            dep = deps.shift();
            if (imported[dep.path]) return proceed();
            return dep.compile(function(err, depCode) {
              if (err) return callback(err);
              code.push(depCode);
              return proceed();
            });
          } else {
            code.push(_this.compiled);
            return callback(null, code.join('\n'));
          }
        })();
      });
    };

    return File;

  })();

  compile = function(mainFile, fn) {
    return File.load(mainFile).compile(fn);
  };

  compile.extensions = File.extensions;

  module.exports = compile;

}).call(this);

{exec} = require("child_process")
fs = require("fs")
path = require("path")
async = require("async")
temp = require("temp")

tests_dir = "./tests/"
tmp_js_file = "./.test_out.tmp.js"
msg = ""
pass_count = 0
fail_count = 0
fs.readdir tests_dir, (err, files) ->
  doTest = (test_dir, testDone) ->
    main_file = path.join(tests_dir, test_dir, "test")
    expect_file = path.join(tests_dir, test_dir, "expected.txt")

    do (exec_result=null, expected_output=null) ->
      execTest = (cb) ->
        temp.open "", (err, tmp_js_file) ->
          exec "node ./cmd.js #{main_file} #{tmp_js_file.path}", (err, stdout, stderr) ->
            if stderr.length > 0
              exec_result =
                compile: false
                msg: stderr
              cb()

            exec "node #{tmp_js_file.path}", (err, stdout, stderr) ->
              fs.close tmp_js_file.fd, ->
                fs.unlink tmp_js_file.path

              if stderr.length > 0
                exec_result =
                  compile: true
                  run: false
                  msg: stderr
              else
                exec_result =
                  compile: true
                  run: true
                  output: stdout
              cb()

      readExpected = (cb) -> fs.readFile expect_file, 'utf8', (err, out) ->
        expected_output = out
        cb()

      async.parallel [execTest, readExpected], ->
        if exec_result.compile
          if exec_result.run
            if exec_result.output is expected_output
              process.stdout.write(".")
              pass_count += 1
            else
              process.stdout.write("F")
              fail_count += 1
              msg += """\n
                ======== #{test_dir} failed =========
                -------- Expected Output:   ---------
                #{expected_output}
                -------------------------------------
                -------- Actual Output:     ---------
                #{exec_result.output}
                -------------------------------------
                """
          else
            process.stdout.write("E")
            fail_count += 1
            msg += """\n
              ======== #{test_dir} crashed ========
              -------- stderr:            ---------
              #{exec_result.msg}
              -------------------------------------
              """
        else
          process.stdout.write("X")
          fail_count += 1
          msg += """\n
            ======== #{test_dir} compile error ==
            -------- stderr:            ---------
            #{exec_result.msg}
            -------------------------------------
            """

        testDone()

  async.map files, doTest, ->
    if msg.length > 0
      process.stdout.write(msg)
    process.stdout.write "\n#{pass_count} passed, #{fail_count} failed.\n"
    fs.unlink tmp_js_file

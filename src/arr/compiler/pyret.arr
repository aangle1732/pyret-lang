#lang pyret

import cmdline as C
import file as F
import pathlib as P
import render-error-display as RED
import string-dict as D
import system as SYS
import simple-function-log as SFL
import file("cli-module-loader.arr") as CLI
import file("compile-lib.arr") as CL
import file("compile-structs.arr") as CS
import file("locators/builtin.arr") as B
import file("server.arr") as S
import file("autogenerate.arr") as AG

# this value is the limit of number of steps that could be inlined in case body
DEFAULT-INLINE-CASE-LIMIT = 5

success-code = 0
failure-code = 1

fun main(args :: List<String>) -> Number block:

  this-pyret-dir = P.dirname(P.resolve(C.file-name))

  options = [D.string-dict:
    "serve",
      C.flag(C.once, "Start the Pyret server"),
    "port",
      C.next-val-default(C.String, "1701", none, C.once, "Port to serve on (default 1701)"),
    "build-standalone",
      C.next-val(C.String, C.once, "DEPRECATED: use build-runnable instead"),
    "build-runnable",
      C.next-val(C.String, C.once, "Main Pyret (.arr) file to build as a standalone"),
    "require-config",
      C.next-val(C.String, C.once, "JSON file to use for requirejs configuration of build-runnable"),
    "outfile",
      C.next-val(C.String, C.once, "Output file for build-runnable"),
    "build",
      C.next-val(C.String, C.once, "Pyret (.arr) file to build"),
    "run",
      C.next-val(C.String, C.once, "Pyret (.arr) file to compile and run"),
    "standalone-file",
      C.next-val-default(C.String, "src/js/base/handalone.js", none, C.once, "Path to override standalone JavaScript file for main"),
    "builtin-js-dir",
      C.next-val(C.String, C.many, "Directory to find the source of builtin js modules"),
    "builtin-arr-dir",
      C.next-val(C.String, C.many, "Directory to find the source of builtin arr modules"),
    "allow-builtin-overrides",
      C.flag(C.once, "Allow overlapping builtins defined between builtin-js-dir and builtin-arr-dir"),
    "no-display-progress",
      C.flag(C.once, "Skip printing the \"Compiling X/Y\" progress indicator"),
    "compiled-dir",
      C.next-val-default(C.String, "compiled", none, C.once, "Directory to save compiled files to"),
    "library",
      C.flag(C.once, "Don't auto-import basics like list, option, etc."),
    "module-load-dir",
      C.next-val-default(C.String, ".", none, C.once, "Base directory to search for modules"),
    "check-all",
      C.flag(C.once, "Run checks all modules (not just the main module)"),
    "no-check-mode",
      C.flag(C.once, "Skip checks"),
    "allow-shadow",
      C.flag(C.once, "Run without checking for shadowed variables"),
    "improper-tail-calls",
      C.flag(C.once, "Run without proper tail calls"),
    "collect-times",
      C.flag(C.once, "Collect timing information about compilation"),
    "type-check",
      C.flag(C.once, "Type-check the program during compilation"),
    "inline-case-body-limit",
      C.next-val-default(C.Number, DEFAULT-INLINE-CASE-LIMIT, none, C.once, "Set number of steps that could be inlined in case body"),
    "deps-file",
      C.next-val(C.String, C.once, "Provide a path to override the default dependencies file"),
    "html-file",
      C.next-val(C.String, C.once, "Name of the html file to generate that includes the standalone (only makes sense if deps-file is the result of browserify)"),
    "no-module-eval",
      C.flag(C.once, "Produce modules as literal functions, not as strings to be eval'd (may break error source locations)"),
    "auto-generate",
      C.flag(C.once, "When true, create all auto-generated files"),
    "trace",
      C.flag(C.once, "Show evaluation steps as the program runs"),
  ]

  params-parsed = C.parse-args(options, args)

  fun err-less(e1, e2):
    if (e1.loc.before(e2.loc)): true
    else if (e1.loc.after(e2.loc)): false
    else: tostring(e1) < tostring(e2)
    end
  end

  cases(C.ParsedArguments) params-parsed block:
    | success(r, rest) =>
      check-mode = not(r.has-key("no-check-mode") or r.has-key("library"))
      allow-shadowed = r.has-key("allow-shadow")
      libs =
        if r.has-key("library"): CS.minimal-imports
        else: CS.standard-imports end
      module-dir = r.get-value("module-load-dir")
      inline-case-body-limit = r.get-value("inline-case-body-limit")
      check-all = r.has-key("check-all")
      type-check = r.has-key("type-check")
      trace = r.has-key("trace")
      when trace:
        SFL.subscribe()
      end
      tail-calls = not(r.has-key("improper-tail-calls"))
      compiled-dir = r.get-value("compiled-dir")
      standalone-file = r.get-value("standalone-file")
      display-progress = not(r.has-key("no-display-progress"))
      html-file = if r.has-key("html-file"):
            some(r.get-value("html-file"))
          else:
            none
          end
      module-eval = not(r.has-key("no-module-eval"))
      when r.has-key("builtin-js-dir"):
        B.set-builtin-js-dirs(r.get-value("builtin-js-dir"))
      end
      when r.has-key("builtin-arr-dir"):
        B.set-builtin-arr-dirs(r.get-value("builtin-arr-dir"))
      end
      when r.has-key("allow-builtin-overrides"):
        B.set-allow-builtin-overrides(r.get-value("allow-builtin-overrides"))
      end
      if not(is-empty(rest)) block:
        print-error("Passing command line arguments without compiling standalone no longer supported\n")
        failure-code
      else:
        if r.has-key("auto-generate") block:
          AG.write-ast-visitors()
          success-code
        else if r.has-key("build-runnable"):
          outfile = if r.has-key("outfile"):
            r.get-value("outfile")
          else:
            r.get-value("build-runnable") + ".jarr"
          end
          CLI.build-runnable-standalone(
              r.get-value("build-runnable"),
              r.get-value("require-config"),
              outfile,
              CS.default-compile-options.{
                this-pyret-dir: this-pyret-dir,
                standalone-file: standalone-file,
                check-mode : check-mode,
                type-check : type-check,
                trace : trace,
                allow-shadowed : allow-shadowed,
                collect-all: false,
                collect-times: r.has-key("collect-times") and r.get-value("collect-times"),
                ignore-unbound: false,
                proper-tail-calls: tail-calls,
                compiled-cache: compiled-dir,
                display-progress: display-progress,
                inline-case-body-limit: inline-case-body-limit,
                deps-file: r.get("deps-file").or-else(CS.default-compile-options.deps-file),
                html-file: html-file,
                module-eval: module-eval
              })
          success-code
        else if r.has-key("serve"):
          port = r.get-value("port")
          S.serve(port)
          success-code
        else if r.has-key("build-standalone"):
          print-error("Use build-runnable instead of build-standalone\n")
          failure-code
          #|
          CLI.build-require-standalone(r.get-value("build-standalone"),
              CS.default-compile-options.{
                check-mode : check-mode,
                type-check : type-check,
                allow-shadowed : allow-shadowed,
                collect-all: false,
                collect-times: r.has-key("collect-times") and r.get-value("collect-times"),
                ignore-unbound: false,
                proper-tail-calls: tail-calls,
                compiled-cache: compiled-dir,
                display-progress: display-progress
              })
           |#
        else if r.has-key("build"):
          result = CLI.compile(r.get-value("build"),
            CS.default-compile-options.{
              check-mode : check-mode,
              type-check : type-check,
              trace : trace,
              allow-shadowed : allow-shadowed,
              collect-all: false,
              ignore-unbound: false,
              proper-tail-calls: tail-calls,
              compile-module: false,
              display-progress: display-progress
            })
          failures = filter(CS.is-err, result.loadables)
          if is-link(failures) block:
            for each(f from failures) block:
              for lists.each(e from f.errors) block:
                print-error(tostring(e))
                print-error("\n")
              end
              print-error("There were compilation errors\n")
            end
            failure-code
          else:
            success-code
          end
        else if r.has-key("run"):
          run-args =
            if is-empty(rest):
              empty
            else:
              rest.rest
            end
          result = CLI.run(r.get-value("run"), CS.default-compile-options.{
              standalone-file: standalone-file,
              display-progress: display-progress,
              check-all: check-all,
              trace: trace
            }, run-args)
          _ = print(result.message + "\n")
          result.exit-code
        else:
          print-error(C.usage-info(options).join-str("\n"))
          print-error("Unknown command line options\n")
          failure-code
        end
      end
    | arg-error(message, partial) =>
      block:
        print-error(message + "\n")
        print-error(C.usage-info(options).join-str("\n") + "\n")
        failure-code
      end
  end
end

exit-code = main(C.args)
SYS.exit-quiet(exit-code)

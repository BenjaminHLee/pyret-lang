provide *
import builtin-modules as B
import either as E
import load-lib as L
import string-dict as SD
import runtime-lib as R
import pathlib as P
import render-error-display as RED
import file("../../../src/arr/compiler/js-of-pyret.arr") as JSP
import file("../../../src/arr/compiler/compile-lib.arr") as CL
import file("../../../src/arr/compiler/cli-module-loader.arr") as CLI
import file("../../../src/arr/compiler/compile-structs.arr") as CS

fun make-fresh-module-testing-context():
  modules = SD.make-mutable-string-dict()
  compiled = SD.make-mutable-string-dict()

  fun get-loadable(located, max-dep-times) -> Option<CL.Loadable>:
    locuri = located.locator.uri()
    compiled.get-now(locuri).and-then(lam({ saved-time; has-static; static-stuff; dyn-stuff }):
      # If the compiled file was cached BEFORE the most recently-updated
      # dependency, don't return any loadable (the cache is stale)
      if (saved-time < max-dep-times.get-value(locuri)):
        none
      else:
        # NOTE(joe/ben): We don't differentiate between static and dynamic here
        # b/c the strings in memory ought to be the same (e.g. we assume
        # pyret-to-js-static() and pyret-to-js-runnable() produce the same static
        # contents). This saves having to differentiate pure-js and arr-js cached
        # copies, which we only distinguish anyway because we don't want to load
        # multi-MB generated code from files, but here it's all in memory already
        raw = B.builtin-raw-locator-from-str(dyn-stuff)
        provs = CS.provides-from-raw-provides(locuri, {
          uri: locuri,
          modules: raw-array-to-list(raw.get-raw-module-provides()),
          values: raw-array-to-list(raw.get-raw-value-provides()),
          aliases: raw-array-to-list(raw.get-raw-alias-provides()),
          datatypes: raw-array-to-list(raw.get-raw-datatype-provides())
        })
        some(CS.module-as-string(provs, CS.no-builtins, CS.computed-none, CS.ok(JSP.ccp-string(dyn-stuff))))
      end
    end)
  end

  fun set-loadable(locator, loadable) block:
    locuri = loadable.provides.from-uri
    cases(CS.CompileResult) loadable.result-printer block:
      | ok(ccp) =>
        cases(JSP.CompiledCodePrinter) ccp block:
          | ccp-dict(dict) =>
            compiled.set-now(locuri, {
              time-now();
              true;
              ccp.pyret-to-js-static();
              ccp.pyret-to-js-runnable();
            })
          | else =>
            compiled.set-now(locuri, {
              time-now();
              false;
              "";
              ccp.pyret-to-js-runnable();
            })
        end
      | err(_) => ""
    end
    loadable
  end



  fun name-to-locator(name :: String) block:
    when not(modules.has-key-now(name)):
      raise("Cannot find module in test-modules: " + name)
    end
    {
      method needs-compile(self, provs): true end,
      method get-module(self): CL.pyret-string(modules.get-value-now(name).{0}) end,
      method get-extra-imports(self): CS.standard-imports end,
      method get-modified-time(self): modules.get-value-now(name).{1} end,
      method get-options(self, options): options end,
      method get-native-modules(self): empty end,
      method get-dependencies(self): CL.get-standard-dependencies(self.get-module(), self.uri()) end,
      method get-globals(self): CS.standard-globals end,
      method uri(self): "file://" + name end,
      method name(self): name end,
      method set-compiled(self, ctxt, provs): nothing end,
      method get-compiled(self): none end,
      method _equals(self, that, rec-eq): rec-eq(self.uri(), that.uri()) end
    }
  end

  fun dfind(ctxt, dep):
    cases(CS.Dependency) dep block:
      | builtin(modname) =>
        CLI.module-finder(ctxt, dep)
      | else =>
        CL.located(name-to-locator(dep.arguments.get(0)), ctxt)
    end
  end

  fun compile-mod(name):
    loc = name-to-locator(name)
    wlist = CL.compile-worklist(dfind, loc, CLI.default-test-context)
    starter-modules = CL.modules-from-worklist(wlist, get-loadable)
    result = CL.compile-program-with(wlist, starter-modules, CS.default-compile-options.{
      on-compile: lam(locator, loadable, trace): set-loadable(locator, loadable) end
    })
    errors = result.loadables.filter(CL.is-error-compilation)
    cases(List) errors:
      | empty =>
        E.right(result.loadables)
      | link(_, _) =>
        E.left(errors.map(_.result-printer))
    end
  end

  fun get-compile-errs(str):
    cases(E.Either) compile-mod(str):
      | right(ans) =>
        empty
      | left(errs) =>
        errs.map(_.problems).foldr(_ + _, empty)
    end
  end

  fun compile-error-messages(str):
    for lists.map(err from get-compile-errs(str)):
      RED.display-to-string(err.render-reason(), torepr, empty)
    end
  end

  {
    add-module: lam(name, program-str):
      modules.set-now(name, { program-str; time-now() })
    end,
    dfind: dfind,
    name-to-locator: name-to-locator,
    compile-mod: compile-mod,
    get-compile-errs: get-compile-errs,
    compile-error-messages: compile-error-messages
  }
end

fun error-with(errs, str):
  lists.any(lam(x): string-contains(x, str) end, errs)
end

check:
  m = make-fresh-module-testing-context()
  m.add-module("a", ```
provide:
  * hiding (j, pos2d),
end
data MyPosn:
  | pos2d(x, y)
  | pos3d(x, y, z)
end
  ```)

  errs = m.compile-error-messages("a")   
  errs is%(error-with) "j"
end

check:
  m = make-fresh-module-testing-context()
  m.add-module("a", ```
provide:
  data MyPosn hiding (j, pos2d),
end
data MyPosn:
  | pos2d(x, y)
  | pos3d(x, y, z)
end
  ```)

  errs = m.compile-error-messages("a")   
  errs is%(error-with) "j"
end

check:
  m = make-fresh-module-testing-context()
  m.add-module("a", ```
provide:
  data * hiding (pos2d, MyPosn, YourPosn),
end
data MyPosn:
  | pos2d(x, y)
  | pos3d(x, y, z)
end
data YourPosn:
  | y-pos2d(x, y)
  | y-pos3d(x, y, z)
end
  ```)

  errs = m.compile-error-messages("a")   
  errs is empty
end

check:
  m = make-fresh-module-testing-context()
  m.add-module("a", ```
provide:
  data * hiding (not-a-pos2d),
end
data MyPosn:
  | pos2d(x, y)
  | pos3d(x, y, z)
end
data YourPosn:
  | y-pos2d(x, y)
  | y-pos3d(x, y, z)
end
  ```)

  errs = m.compile-error-messages("a")   
  errs is%(error-with) "not-a-pos2d"
end


check:
  m = make-fresh-module-testing-context()
  m.add-module("a", ```
provide:
  data MyPosn hiding (is-pos2d),
end
data MyPosn:
  | pos2d(x, y)
  | pos3d(x, y, z)
end
data YourPosn:
  | y-pos2d(x, y)
  | y-pos3d(x, y, z)
end
  ```)

  errs = m.compile-error-messages("a")   
  errs is empty
end

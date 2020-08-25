/* eslint-disable */

const csv = require('csv-parse/lib/sync');
const assert = require('assert');
const immutable = require('immutable');
export const stopify = require('@stopify/stopify');
const browserFS = require('./browserfs-setup.ts');

(window as any).stopify = stopify;

const { fs } = browserFS;
const { path } = browserFS;

const nodeModules = {
  assert,
  'csv-parse/lib/sync': csv,
  fs: browserFS.fs,
  immutable,
};

/**
  This wrapping is necessary because otherwise require, exports, and module
  will be interpreted as *global* by stopify. However, these really need to
  be module-local as they have context like the working directory, and
  exports/module are per-module even though they “act” like a global
  variable.

  We still set these fields on runner.g (g is the global field for
  stopify), but immediately apply the function to the values we just set
  before it evaluates and goes on to process any more requires. Stopify
  then won't compile uses of module/exports/require within the generated
  function to use .g, and each module gets its own copy.
*/
function wrapContent(content: string): string {
  return `(function(require, exports, module) { ${content} })(require, exports, module);`;
}

export const makeRequireAsync = (basePath: string): ((importPath: string) => Promise<any>
  ) => {
  let currentRunner: any = null;
  const cache : {[key:string]: any} = {};

  const requireAsyncMain = (importPath: string) => new Promise(((resolve, reject) => {
    if (importPath in nodeModules) {
      return (nodeModules as any)[importPath];
    }
    const nextPath = path.join(basePath, importPath);
    const cwd = path.parse(nextPath).dir;
    const stoppedPath = `${nextPath}.stopped.main`;
    // Get the absolute path to uniquely identify modules
    // Cache modules based upon the absolute path for singleton modules
    const cachePath = path.resolve(stoppedPath);
    if (cachePath in cache) {
      resolve(cache[cachePath]);
      return;
    }
    if (!fs.existsSync(nextPath)) {
      throw new Error(`Path did not exist in requireAsyncMain: ${nextPath}`);
    }
    let runner: any = null;
    const contents = String(fs.readFileSync(nextPath));

    const toStopify = wrapContent(contents);
    runner = stopify.stopifyLocally(toStopify, { newMethod: 'direct' });
    if (runner.kind !== 'ok') { reject(runner); }
    fs.writeFileSync(stoppedPath, runner.code);
    const stopifyModuleExports = {
      exports: {
        __pyretExports: nextPath,
      },
    };

    runner.g = Object.assign(runner.g, {
      document,
      Number,
      Math,
      Array,
      Object,
      RegExp,
      stopify,
      Error,
      Image,
      JSON,
      Date,
      decodeURIComponent,
      require: requireAsyncFromDir(cwd),
      module: stopifyModuleExports,
      // TS 'export' syntax desugars to 'exports.name = value;'
      exports: stopifyModuleExports.exports,
      String,
      $STOPIFY: runner,
      setTimeout,
      clearTimeout,
      console,
      parseFloat,
      isNaN,
      isFinite,
    });
    runner.path = nextPath;
    currentRunner = runner;

    resolve({
      run: new Promise((resolve, reject) => runner.run((result : any) => {
        if (result.type !== 'normal') {
          reject(result);
        } else {
          const toReturn = runner.g.module.exports;
          cache[cachePath] = toReturn;
          resolve(toReturn);
        }
      })),
      pause: (callback: (line: number) => void): void => {
        runner.pause(callback);
      },
      resume: (): void => {
        runner.resume();
      },
    });
  }));

  const requireAsyncFromDir = (requiringWd : string) => {
    return (importPath: string) => {
      if (importPath in nodeModules) {
        return (nodeModules as any)[importPath];
      }
      const nextPath = path.join(requiringWd, importPath);
      const cwd = path.parse(nextPath).dir;
      const stoppedPath = `${nextPath}.stopped`;
      // Get the absolute path to uniquely identify modules
      // Cache modules based upon the absolute path for singleton modules
      const cachePath = path.resolve(stoppedPath);
      if (cachePath in cache) { return cache[cachePath]; }
      if (!fs.existsSync(nextPath)) {
        throw new Error(`Path did not exist in requireSync: ${nextPath}`);
      }
      currentRunner.pauseK((kontinue: (result: any) => void) => {
        const lastPath = currentRunner.path;
        const module = {
          exports: {
            __pyretExports: nextPath,
          },
        };
        const lastModule = currentRunner.g.module;
        // Note: It's important that module.exports is an alias of exports, and
        // that both module and exports are available globals. This has to do
        // with differing patterns in how e.g. TypeScript, best-practice JS
        // code, and so on generate export code.
        currentRunner.g.module = module;
        currentRunner.g.exports = module.exports;
        currentRunner.g.require = requireAsyncFromDir(cwd);
        currentRunner.path = nextPath;
        let stopifiedCode = '';
        if (fs.existsSync(stoppedPath) && (fs.statSync(stoppedPath).mtime > fs.statSync(nextPath).mtime)) {
          stopifiedCode = String(fs.readFileSync(stoppedPath));
        } else {
          const contents = String(fs.readFileSync(nextPath));
          stopifiedCode = currentRunner.compile(wrapContent(contents));
          fs.writeFileSync(stoppedPath, stopifiedCode);
        }
        currentRunner.evalCompiled(stopifiedCode, (result: any) => {
          if (result.type !== 'normal') {
            kontinue(result);
            return;
          }
          const toReturn = currentRunner.g.module.exports;
          currentRunner.path = lastPath;
          // g.exports and g.module may be overwritten by JS code. Need to restore
          currentRunner.g.module = lastModule;
          // Need to set 'exports' global to work with TS export desugaring
          currentRunner.g.exports = lastModule.exports;
          cache[cachePath] = toReturn;
          kontinue({ type: 'normal', value: toReturn });
        });
      });
    };
  }
  return requireAsyncMain;
};

export const makeRequire = (basePath: string): ((importPath: string) => any) => {
  const cache : {[key:string]: any} = {};
  let cwd = basePath;
  /*
    Recursively eval (with this definition of require in scope) all of the
    described JavaScript.

    Note that since JS code is generated/written with the assumption that
    require() is sync, we can only use sync versions of the FS function here;
    require must be entirely one synchronous run of the code.

    Future use of stopify could enable the definition of requireAsync, which
    could pause the stack while requiring and then resume.
  */
  const requireSync = (importPath: string) => {
    if (importPath in nodeModules) {
      return (nodeModules as any)[importPath];
    }
    const oldWd = cwd;
    const nextPath = path.join(cwd, importPath);
    if (nextPath in cache) { return cache[nextPath]; }
    cwd = path.parse(nextPath).dir;
    if (!fs.existsSync(nextPath)) {
      throw new Error(`Path did not exist in requireSync: ${nextPath}`);
    }
    const contents = fs.readFileSync(nextPath);
    // TS 'export' syntax desugars to 'exports.name = value;'
    // Adding an 'exports' parameter simulates the global 'exports' variable
    // Also, the comment below has meaning to eslint and makes it ignore the
    // use of the Function constructor (which we do intend)
    // eslint-disable-next-line
    const f = new Function("require", "module", "exports", contents);
    const module = {
      exports: {
        __pyretExports: nextPath,
      },
    };
    const result = f(requireSync, module, module.exports);
    const toReturn = module.exports ? module.exports : result;
    cwd = oldWd;
    cache[nextPath] = toReturn;
    return toReturn;
  };

  return requireSync;
};

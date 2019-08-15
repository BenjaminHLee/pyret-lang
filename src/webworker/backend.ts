const runner = require("./runner.ts");

export interface CompileOptions {
  program: string,
  baseDir: string,
  builtinJSDir: string,
  typeCheck: boolean,
  checks: string,
}

export enum RunKind {
  Sync = "SYNC",
  Async = "ASYNC",
}

export interface RunResult {
  time: number,
  result: any,
}

export function compileProgram(compilerWorker, options: CompileOptions) {
  let message = {
    _parley: true,
    options: {
      program: options.program,
      "base-dir": options.baseDir,
      "builtin-js-dir": options.builtinJSDir,
      checks: options.checks,
      'type-check': options.typeCheck,
    }
  };

  compilerWorker.postMessage(message);
}

export function runProgram(baseDir: string, program: string, runKind: RunKind): Promise<RunResult> {
  if (runKind === RunKind.Sync) {
    const start = window.performance.now();
    const result = runner.makeRequire(baseDir)(program);
    // const result = runner.makeRequire("/compiled/project")("program.arr.js");
    const end = window.performance.now();

    return Promise.resolve({
        time: end - start,
        result: result
      });
  } else if (runKind === RunKind.Async) {
    const entry = runner.makeRequireAsync(baseDir);
    // const entry = runner.makeRequireAsync("/compiled/project");
    const resultP = entry(program);

    let wrapper = async function() {
      const start = window.performance.now();
      let result = await resultP();
      const end = window.performance.now();

      return {
        time: end - start,
        result: result,
      };
    };

    return wrapper();
  }
}

const {compileToStringSync} = require("node-elm-compiler");

const elmCode = compileToStringSync(['./src/Benchmarks.elm'], {optimize: true});
eval(elmCode);

const app = this.Elm.Benchmarks.init();

app.ports.sendOutput.subscribe((output) => {
    console.log(JSON.stringify(output, null, 2));
});

const {Elm} = require('./elm.js');

const app = Elm.Benchmarks.init();

app.ports.sendOutput.subscribe((output) => {
    console.log(JSON.stringify(output, null, 2));
});

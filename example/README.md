This example directory simulates somebody tweaking the `List.Extra.remove` function.
They've made two directories: `old` with the current implementation, and `new` with the proposed new one.
To find out if the new implementation is faster, they run a benchmark:

```bash
$ elm-bench -v old -v new remove 42 "List.range 0 1000"
Benchmarking function remove with args 42 and List.range 0 1000.
  old   ████████████████████   316 ns/run   baseline
  new   ████████████████       254 ns/run   20% faster
```

The new implementation is 20% faster, so they decide to submit a pull request.

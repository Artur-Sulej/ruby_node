# Ruby Node

Code for the talk _Ruby as a Node on Code BEAM America 2024_

* [Talk info](https://codebeamamerica.com/participants/artur-sulej/)
* [Slides](Code_BEAM_America_2024_Slides.pdf)

It contains two solutions:

* Erlang Distribution Protocol in Ruby: [erldp](erldp)
* Elixir proxy with Port: [port](port)

## Erlang Distribution Protocol in Ruby

This is an implementation of ErlDP handshake in Ruby.
How to run it:

Start Elixir node:

```bash
iex --sname elixir_node
```

Start Ruby node:

```bash
ruby erldp/run.rb
```

In Elixir node, you can check that Ruby node is connected:

```elixir
Node.list()
```

Call from Elixir node (although it's not fully implemented):

```elixir
:rpc.call(:"ruby_node@Artur-Sulej-MacBook-Pro", Reverse, :reverse, ["No palindromes!"], 5000)
```

## Elixir proxy with Port

Run Elixir proxy node:

```bash
elixir --sname elixir_proxy -S mix run --no-halt
```

Run the other node:

```bash
iex --sname other_node
```

In the other node send the RPC:

```elixir
:rpc.call(:"elixir_proxy@Artur-Sulej-MacBook-Pro", Reverse, :reverse, ["No palindromes!"], 5000)
```

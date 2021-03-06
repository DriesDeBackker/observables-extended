defmodule Observables.Obs do
  alias Observables.GenObservable
  alias Observables.Operator.{
    Switch,
    SwitchRepeat,
    FromEnum,
    Range,
    Zip,
    ZipN,
    ZipVar,
    Merge,
    Rotate,
    Map,
    Distinct,
    Novel,
    Each,
    Filter,
    StartsWith,
    Buffer,
    Chunk,
    Delay,
    Scan,
    Take,
    CombineLatest,
    CombineLatestN,
    CombineLatestVar,
    CombineLatestSilent,
    CombineLatestSilentBuffered,
    CombineLatestSilentBufferedPropagating,
  }

  alias Enum
  require Logger
  alias Logger

  # GENERATORS ###################################################################

  @doc """
  from_pid/1 can be considered to be a subject. Any process that implements the GenObservable interface can be used as a subject, actually.
  Example:
  Spawn a subject using the `Subject` module.
  {:ok, pid1} = GenObservable.spawn_supervised(Subject, 0)

  Print out each value that the subject produces.
  ```
  Obs.from_pid(pid1)
  |> Obs.print()
  ```

  Send an event to the subject.
  GenObservable.send_event(pid1, :value)

  More information: http://reactivex.io/documentation/subject.html
  """
  def from_pid(producer) do
    {fn consumer ->
       GenObservable.send_to(producer, consumer)
     end, producer}
  end

  @doc """
  Takes an enumerable and turns it into an observable that produces a value
  for each value of the enumerable.
  If the enum is consumed, returns done.

  More information: http://reactivex.io/documentation/operators/from.html
  """
  def from_enum(coll, delay \\ 1000) do
    {:ok, pid} = GenObservable.start(FromEnum, [coll, delay])

    Process.send_after(pid, {:event, :spit}, delay)

    {fn observer ->
       GenObservable.send_to(pid, observer)
     end, pid}
  end

  @doc """
  Returns the last emitted value of the Observable.
  """
  def last({_obs_fn, obs_pid}) do
    GenObservable.get_last(obs_pid)
  end

  @doc """
  Range creates an observable that will start at the given integer and run until the last integer.
  If no second argument is given, the stream is infinite.
  One can use :infinity as the end for an infinite stream (see: https://elixirforum.com/t/infinity-in-elixir-erlang/7396)

  More information: http://reactivex.io/documentation/operators/range.html
  """
  def range(first, last, delay \\ 1000) do
    {:ok, pid} = GenObservable.start(Range, [first, last, delay])

    Process.send_after(pid, {:event, :tick}, delay)

    {fn observer ->
       GenObservable.send_to(pid, observer)
     end, pid}
  end

  @doc """
  repeat takes a function as argument and an optional interval.
  The function will be repeatedly executed, and the result will be emitted as an event.

  More information: http://reactivex.io/documentation/operators/repeat.html
  """
  def repeat(f, opts \\ []) do
    interval = Keyword.get(opts, :interval, 1000)
    times = Keyword.get(opts, :times, :infinity)

    range(1, times, interval)
    |> map(fn _ ->
      f.()
    end)
  end

  # CONSUMER AND PRODUCER ########################################################

  @doc """
  Combine the emissions of multiple Observables together 
  and emit single items for each combination.

  More information: http://reactivex.io/documentation/operators/zip.html
  """
  def zip(l, r) do
    # We tag each value from left and right with their respective label.
    {f_l, _pid_l} =
      l
      |> map(fn v -> {:left, v} end)

    {f_r, _pid_r} =
      r
      |> map(fn v -> {:right, v} end)

    # Start our zipper observable.
    {:ok, pid} = GenObservable.start(Zip, [])

    # Make left and right send to us.
    f_l.(pid)
    f_r.(pid)

    # Create the continuation.
    {fn observer ->
       GenObservable.send_to(pid, observer)
     end, pid}
  end

  @doc """
  Unzip an observable whose values are tuples {left, right}.
  """
  def unzip(obs) do
    lobs =
      obs
      |> map(fn {l, _r} -> l end)
    robs = 
      obs
      |> map(fn {_l, r} -> r end)
    {lobs, robs}
  end

  @doc """
  Combine the emissions of a list of observables together 
  and emit single items for each combination.
  """
  def zip_n(obss) do
    # We tag each value from an observee with its respective index
    indices = 0..(length(obss)-1)
    tagged = Enum.zip(obss, indices)
      |> Enum.map(fn {obs, index} -> obs
        #|> Observables.Obs.inspect()
        |> map(fn v -> {index, v} end) end)

    # Start our ZipN observable.
    {:ok, pid} = GenObservable.start(ZipN, [length(obss)])

    # Make the observees send to us.
    tagged |> Enum.each(fn {obs_f, _obs_pid} -> obs_f.(pid) end)

    # Create the continuation.
    {fn observer ->
       GenObservable.send_to(pid, observer)
     end, pid}
  end

  @doc """
  Combine the emissions of a list of observables together 
  and emit single items for each combination.

  Takes an extra higher order observable carrying new observables to zip with.
  """
  def zip_var(obs, obss) do
    # We tag each value from an observee with a :newval tag and its respective index
    inds = 0..(length(obss)-1)
    tagged = Enum.zip(obss, inds)
      |> Enum.map(fn {obs, ind} -> obs
        #|> Observables.Obs.inspect()
        |> map(fn v -> {:newval, ind, v} end) end)

    # We tag each observable from the higher-order observable with a :newobs tag.
    {tho_f, tho_pid} = obs
      |> map(fn obs -> {:newobs, obs} end)

    # We create args.
    pids = tagged
      |> Enum.map(fn {_, obs_pid} -> obs_pid end)
    pids_inds = Enum.zip(pids, inds)

    # Start our ZipVar observable.
    {:ok, pid} = GenObservable.start(ZipVar, [pids_inds, tho_pid])

    # Make the observees send to us.
    tagged |> Enum.each(fn {obs_f, _obs_pid} -> obs_f.(pid) end)
    tho_f.(pid)

    # Create the continuation.
    {fn observer ->
       GenObservable.send_to(pid, observer)
     end, pid}
  end

  @doc """
  Combine two observables into a single observable that will emit the events 
  produced by the inputs in a fifo fashion.

  More information: http://reactivex.io/documentation/operators/merge.html
  """
  def merge({observable_fn_1, _parent_pid_1}, {observable_fn_2, _parent_pid_2}) do
    {:ok, pid} = GenObservable.start_link(Merge, [])

    observable_fn_1.(pid)
    observable_fn_2.(pid)

    # Create the continuation.
    {fn observer ->
       GenObservable.send_to(pid, observer)
     end, pid}
  end

  @doc """
  Combine a list of observables into a single observable that will emit the events 
  produced by the inputs in a fifo fashion.
  """
  def merge([{_obs_fn, _ppid} = obssh | []]), do: obssh
  def merge([{_obs_fn, _ppid} = obssh | obsst]), do: merge(obssh, merge(obsst))

  @doc """
  Combine a list of observables into a single observable that will emit the events
  produced by the inputs in a round-robin fashion.
  """
  def rotate(obss) do
    n = length(obss)
    # Tag all the observables with an index and a :newvalue tag.
    tobss = obss
    |> Enum.zip(0..n-1)
    |> Enum.map(
      fn {obs, i} ->
        obs 
        |> map(fn v -> {:newvalue, i, v} end) 
      end)

    # Start our Rotate observable.
    {:ok, pid} = GenObservable.start_link(Rotate, [n])

    # Make the observables send to us.
    tobss 
    |> Enum.each(fn {obs_f, _obs_pid} -> obs_f.(pid) end)

    #Create the continuation
    {fn observer -> 
      GenObservable.send_to(pid, observer) 
    end, pid}
  end

  @doc """
  Applies a given function to each value produces by the dependency observable.

  More information: http://reactivex.io/documentation/operators/map.html
  """
  def map({observable_fn, _parent_pid}, f) do
    {:ok, pid} = GenObservable.start_link(Map, [f])

    observable_fn.(pid)

    # Create the continuation.
    {fn observer ->
       GenObservable.send_to(pid, observer)
     end, pid}
  end

  @doc """
  Filters out values that have already been produced by any given observable.
  
  Uses the default `==` function as a comparator if none is given. 
  Any supplied comparator function should take 2 arguments, 
  and return a boolean, indicating equality.

  More information: http://reactivex.io/documentation/operators/distinct.html
  """
  def distinct({observable_fn, _parent_pid}, f \\ fn x, y -> x == y end) do
    {:ok, pid} = GenObservable.start_link(Distinct, [f])

    observable_fn.(pid)

    # Create the continuation.
    {fn observer ->
       GenObservable.send_to(pid, observer)
     end, pid}
  end

  @doc """
  Filters out values that are equal to the most recently produced value.
  
  Uses the default `==` function as a comparator if none is given. 
  Any supplied comparator function should take 2 arguments, 
  and return a boolean, indicating equality.
  """
  def novel({observable_fn, _parent_pid}, f \\ fn x, y -> x == y end) do
    {:ok, pid} = GenObservable.start_link(Novel, [f])

    observable_fn.(pid)

    # Create the continuation.
    {fn observer ->
       GenObservable.send_to(pid, observer)
     end, pid}
  end


  @doc """
  Same as map, but returns the original value. Typically used for side effects.

  More information: http://reactivex.io/documentation/operators/subscribe.html
  """
  def each({observable_fn, _parent_pid}, f) do
    {:ok, pid} = GenObservable.start_link(Each, [f])

    observable_fn.(pid)

    # Create the continuation.
    {fn observer ->
       GenObservable.send_to(pid, observer)
     end, pid}
  end

  @doc """
  Filters out the values that do not satisfy the given predicate. 

  The expection function should take 1 arguments and return a boolean value. 
  True if the value should be produced, false if the value should be discarded.

  More information: http://reactivex.io/documentation/operators/filter.html
  """
  def filter({observable_fn, _parent_pid}, f) do
    {:ok, pid} = GenObservable.start_link(Filter, [f])
    observable_fn.(pid)
    # Create the continuation.
    {fn observer ->
       GenObservable.send_to(pid, observer)
     end, pid}
  end

  @doc """
  Prepends any observable with a list of values provided here in the form of a list.

  More information: http://reactivex.io/documentation/operators/startwith.html
  """
  def starts_with({observable_fn, _parent_pid}, start_vs) do
    # Start the producer/consumer server.
    {:ok, pid} = GenObservable.start_link(StartsWith, [])

    # After the subscription has been made, send all the start values to the producers
    # so he can start pushing them out to our dependees.
    GenObservable.delay(pid, 500)

    # We send each value to the observable, such that it can then forward them to its dependees.
    for v <- start_vs do
      GenObservable.send_event(pid, v)
    end

    observable_fn.(pid)

    # Creat the continuation.
    {fn consumer ->
       # This sets the observer as our dependency.
       GenObservable.send_to(pid, consumer)
     end, pid}
  end

  @doc """
  Convert an Observable that emits Observables into a single Observable that 
  emits the items emitted by the most-recently-emitted of those Observables.

  ## It is possible to supply an Observable as the start Observable.

  More information: http://reactivex.io/documentation/operators/switch.html
  """
  def switch(initial_obs \\ nil, {observable_fn, _parent_pid}) do
    # Start the producer/consumer server.
    {:ok, pid} = GenObservable.start_link(Switch, [initial_obs])

    observable_fn.(pid)

    # Create the continuation.
    {fn observer ->
       GenObservable.send_to(pid, observer)
     end, pid}
  end

  @doc """
  Convert an Observable that emits Observables into a single Observable that 
  emits the items emitted by the most-recently-emitted of those Observables.
  Emits the last value of the new Observable if not nil upon switching.

  ## It is possible to supply an initial Observable as the first argument.

  More information: http://reactivex.io/documentation/operators/switch.html
  """
  def switch_repeat(initial_obs \\ nil, {observable_fn, _parent_pid}) do
    # Start the producer/consumer server.
    {:ok, pid} = GenObservable.start_link(SwitchRepeat, [initial_obs])

    observable_fn.(pid)

    # Create the continuation.
    {fn observer ->
       GenObservable.send_to(pid, observer)
     end, pid}
  end

  @doc """
  Takes two Observables and a 'switch' Observable.
  Emits the values of the first Observable until the switch Observable emits a value,
  at which point the resulting Observable switches and only emits values from the second Observable.  
  """

  def until(obs1, obs2, obs_switch) do
    {:ok, pid} = GenObservable.start_link(Switch, [obs1])

    #Transform the switch observable into an observable that emits only one value, namely the second observable
    {switch_fn, _switch_pid} = obs_switch
    |> take(1)
    |> map(fn _ -> obs2 end)

    switch_fn.(pid)

    # Create the continuation.
    {fn observer ->
       GenObservable.send_to(pid, observer)
     end, pid}
  end

  @doc """
  Takes two Observables and a 'switch' Observable.
  Emits the values of the first Observable until the switch Observable emits a value,
  at which point the resulting Observable switches and only emits values from the second Observable.
  Emits the last value of the second Observable if not nil upon switching.
  """

  def until_repeat(obs1, obs2, obs_switch) do
    {:ok, pid} = GenObservable.start_link(SwitchRepeat, [obs1])

    #Transform the switch observable into an observable that emits only one value, namely the second observable
    {switch_fn, _switch_pid} = obs_switch
    |> take(1)
    |> map(fn _ -> obs2 end)

    switch_fn.(pid)

    # Create the continuation.
    {fn observer ->
       GenObservable.send_to(pid, observer)
     end, pid}
  end

  @doc """
  Chunks items produces by the observable together bounded in time. 
  As soon as the set delay has been passed, the observable emits an enumerable
  with the elements gathered up to that point. Does not emit the empty list.

  Works in the same vein as the buffer observable, but that one is bound by number,
  and not by time.

  Source: http://reactivex.io/documentation/operators/buffer.html
  """
  def chunk({observable_fn, _parent_pid}, interval) do
    {:ok, pid} = GenObservable.start_link(Chunk, [interval])

    observable_fn.(pid)

    Process.send_after(pid, {:event, :flush}, interval)

    # Create the continuation.
    {fn observer ->
       GenObservable.send_to(pid, observer)
     end, pid}
  end

  @doc """
  Periodically gather items emitted by an Observable into bundles of size `size` and emit
  these bundles rather than emitting the items one at a time.

  Source: http://reactivex.io/documentation/operators/buffer.html
  """
  def buffer({observable_fn, _parent_pid}, size) do
    {:ok, pid} = GenObservable.start_link(Buffer, [size])

    observable_fn.(pid)

    # Create the continuation.
    {fn observer ->
       GenObservable.send_to(pid, observer)
     end, pid}
  end

  @doc """
  Delays each produced item by the given interval.
  """
  def delay({observable_fn, _parent_pid}, interval) do
    {:ok, pid} = GenObservable.start_link(Delay, [interval])

    observable_fn.(pid)

    # Create the continuation.
    {fn observer ->
       GenObservable.send_to(pid, observer)
     end, pid}
  end

  @doc """
  Applies a given procedure to an observable's value, and its previous result. 
  Works in the same way as the Enum.scan function:

  Enum.scan(1..10, fn(x,y) -> x + y end) 
  => [1, 3, 6, 10, 15, 21, 28, 36, 45, 55]

  More information: http://reactivex.io/documentation/operators/scan.html
  """
  def scan({observable_fn, _parent_pid}, f, default \\ nil) do
    {:ok, pid} = GenObservable.start_link(Scan, [f, default])

    observable_fn.(pid)

    # Creat the continuation.
    {fn observer ->
       GenObservable.send_to(pid, observer)
     end, pid}
  end

  def count(obs, default \\ 0) do
    scan(obs, fn _v, n -> n + 1 end, default)
  end

  @doc """
  Takes the n first element of the observable, and then stops.

  More information: http://reactivex.io/documentation/operators/take.html
  """
  def take({observable_fn, _parent_pid}, n) do
    {:ok, pid} = GenObservable.start_link(Take, [n])

    observable_fn.(pid)

    # Creat the continuation.
    {fn observer ->
       GenObservable.send_to(pid, observer)
     end, pid}
  end

  @doc """
  Given two observables, merges them together and always merges the last result of on of both, and
  reuses the last value from the other.

  E.g.
  ```
  1 -> 2 ------> 3
  A -----> B ------> C 
  =
  1A --> 2A -> 2B -> 3B -> 3C
  ```

  More information: http://reactivex.io/documentation/operators/combinelatest.html
  """
  def combinelatest(l, r, opts \\ [left: nil, right: nil]) do
    left_initial = Keyword.get(opts, :left)
    right_initial = Keyword.get(opts, :right)

    # We tag each value from left and right with their respective label.
    {f_l, _pid_l} =
      l
      #|> Observables.Obs.inspect()
      |> map(fn v -> {:left, v} end)

    {f_r, _pid_r} =
      r
      #|> Observables.Obs.inspect()
      |> map(fn v -> {:right, v} end)

    # Start our combinelatest2 observable.
    {:ok, pid} = GenObservable.start(CombineLatest, [left_initial, right_initial])

    # Make left and right send to us.
    f_l.(pid)
    f_r.(pid)

    # Creat the continuation.
    {fn observer ->
       GenObservable.send_to(pid, observer)
     end, pid}
  end

  @doc """
  Generalization of Combinelatest2 to an unspecified number n of observees.
  Takes a list of observables and merges them together 
  by combining the newly received value of an observable with the latest values from the others.
  """
  def combinelatest_n(obss, opts \\ [inits: nil]) do
    inds = 0..(length(obss)-1)
    #Create list of nils as initial values when no initial values given as option.
    inits = Keyword.get(opts, :inits)
    inits = 
      if inits == nil do
        inds |> Enum.map(fn _ -> nil end)
      else
        inits
      end

    # We tag each value from an observee with its respective index
    tagged = Enum.zip(obss, inds)
      |> Enum.map(fn {obs, index} -> obs
        #|> Observables.Obs.inspect()
        |> map(fn v -> {index, v} end) end)

    # Start our CombineLatestn observable.
    {:ok, pid} = GenObservable.start(CombineLatestN, [inits])

    # Make the observees send to us.
    tagged |> Enum.each(fn {obs_f, _obs_pid} -> obs_f.(pid) end)

    # Create the continuation.
    {fn observer ->
       GenObservable.send_to(pid, observer)
     end, pid}
  end

  @doc """
  Generalization of Combinelatestn to a number of observables that can be subject to change.
  Takes a list of initial observables and one higher order observable.
  Values of the latter are tuples `{observable, initial_value}`. 
  We add these observables as new incoming dependencies and initialize them with the given value..
  At any given moment, we combine the newly received value of an observable with the latest values of other current observables.
  """
  def combinelatest_var(obs, obss, opts \\ [inits: nil]) do
    inds = 0..(length(obss)-1)
    # Create list of nils as initial values when no initial values given as option.
    inits = Keyword.get(opts, :inits)
    inits = 
      if inits == nil do
        inds|> Enum.map(fn _ -> nil end)
      else
        inits
      end

    # We tag each value from an observee with a :newval tag and its respective index
    tagged = Enum.zip(obss, inds)
      |> Enum.map(fn {obs, ind} -> obs
        #|> Observables.Obs.inspect()
        |> map(fn v -> {:newval, ind, v} end) end)
    # We tag each observable from the higher-order observable with a :newobs tag.
    {tho_f, tho_pid} = obs
      |> map(fn {obs, init} -> {:newobs, obs, init} end)

    # Create the args.
    pids = tagged
      |> Enum.map(fn {_, obs_pid} -> obs_pid end)
    pids_inds = Enum.zip(pids, inds)
    inds_inits = Enum.zip(inds, inits)

    # Start our CombineLatestVar observable.
    {:ok, pid} = GenObservable.start(CombineLatestVar, [pids_inds, inds_inits, tho_pid])

    # Make the observees send to us.
    tagged |> Enum.each(fn {obs_f, _obs_pid} -> obs_f.(pid) end)
    tho_f.(pid)

    # Create the continuation.
    {fn observer ->
       GenObservable.send_to(pid, observer)
     end, pid}
  end

  @doc """
  Given two observables, merges them together by zipping the values of one with the latest value from the other.
  The zip observable will trigger an update if there is a value for the combine observable, otherwise the zip value will be lost.
  The combine observable will never trigger the production of a new value, but will instead update 'silently'.

  E.g.
  ```
  1 ---> 2 -------> 3 ------>
  A -------> B -----------> C 
  =
  1A ---> 2A -----> 3B ----->
  ```

  More information: http://reactivex.io/documentation/operators/combinelatest.html
  """
  def combinelatestsilent(cobs, zobs, opts \\ [init: nil, silent: :right]) do
    init = Keyword.get(opts, :init, nil)

    # We tag each value from the c-observable and the z-observable with their respective labels.
    {f_c, _pid_c} =
      cobs
      #|> Observables.Obs.inspect()
      |> map(fn v -> {:c, v} end)

    {f_z, _pid_z} =
      zobs
      #|> Observables.Obs.inspect()
      |> map(fn v -> {:z, v} end)

    # Start our combine_1_zip_1 observable.
    {:ok, pid} = GenObservable.start(CombineLatestSilent, [init])

    # Make left and right send to us.
    f_c.(pid)
    f_z.(pid)

    # Create the continuation.
    {fn observer ->
       GenObservable.send_to(pid, observer)
     end, pid}
  end

  @doc """
  Generalization of combinelatestsilent to n observables to 'combine latest' and m observables to zip.

  E.g.
  ```
  c1: -------------> 1 ----------> 2 ------> 3 -->
  c2: ------> A --------> B -------------------> C 
  z1: a -------> b----------- c --------> d ----->
  z2: --> @ ------> $ ----> % -----> & ---------->
  =
  r:  ------------------------>1Bc%------->2Bd& ->
  ```

  More information: http://reactivex.io/documentation/operators/combinelatest.html
  """
  def combinelatest_n_zip_m(cobss, zobss, opts \\ [inits: nil]) do
    # Process optional initial values
    inits = Keyword.get(opts, :inits, nil)
    init = case inits do
      nil   -> nil
      [_|_] -> List.to_tuple(inits)
    end

    # Build this primitive by composing simpler ones
    cobs = combinelatest_n(cobss, opts)
    zobs = zip_n(zobss)
    combinelatestsilent(cobs, zobs, [init: init])
      |> map(fn {cv, zv} -> 
        List.to_tuple(Tuple.to_list(cv) ++ Tuple.to_list(zv)) end)
  end

  @doc """
  Given two observables, merges them together by zipping the values of one with the latest value from the other.
  The zip observable will trigger an update if there is a value for the combine observable, otherwise it will add this value to a buffer.
  When updating, we always take the first value of the zip buffer.
  The combine observable will never trigger an update, but will instead update 'silently' by replacing its latest value.

  E.g.
  ```
  1 -> 2 ------> 3 ---> 4
  -----> A ------> C --->
  =
  -------------> 1A -> 2C
  ```
  """
  def combinelatestsilent_buffered(cobs, zobs, opts \\ [init: nil]) do
    init = Keyword.get(opts, :init, nil)

    # We tag each value from the c-observable and the z-observable with their respective labels.
    {f_c, _pid_c} =
      cobs
      #|> Observables.Obs.inspect()
      |> map(fn v -> {:c, v} end)

    {f_z, _pid_z} =
      zobs
      #|> Observables.Obs.inspect()
      |> map(fn v -> {:z, v} end)

    # Start our combine_1_zip_1 observable.
    {:ok, pid} = GenObservable.start(CombineLatestSilentBuffered, [init])

    # Make left and right send to us.
    f_c.(pid)
    f_z.(pid)

    # Create the continuation.
    {fn observer ->
       GenObservable.send_to(pid, observer)
     end, pid}
  end

  @doc """
  Generalization of combinelatestsilent_silent_buffered to n observables to 'combine latest' and m observables to zip.

  E.g.
  ```
  c1: -------------> 1 --------------> 2 --------------------> 3
  c2: ------> A --------> B --------------------> C ----------->
  z1: a -------> b-----------------> c --------------> d ------>
  z2: --> @ ------> $ ------> % -------------> & -------------->
  =
  r:  -----------------------------> 1Ba@ -----------> 2Cb$ --->
  ```
  """
  def combinelatest_n_zip_m_buffered(cobss, zobss, opts \\ [init: nil]) do
    # Process optional initial values
    inits = Keyword.get(opts, :inits, nil)
    init = case inits do
      nil   -> nil
      [_|_] -> List.to_tuple(inits)
    end

    # Build this primitive by composing simpler ones
    cobs = combinelatest_n(cobss, opts)
    zobs = zip_n(zobss)
    combinelatestsilent_buffered(cobs, zobs, [init: init])
      |> map(fn {cv, zv} ->
        List.to_tuple(Tuple.to_list(cv) ++ Tuple.to_list(zv)) end)
  end

  @doc """
  Given two observables, merges them together by zipping the values of one with the latest value from the other.
  The zip observable will trigger an update if there is a value for the combine observable, otherwise it will add this value to a buffer.
  The combine observable will in steady state not trigger an update, but will instead update 'silently' by replacing its latest value.
  If however a value for the combine observable is received for the first time in the presence of a zip buffer,
  We will combine the whole zip buffer at once with this combine value.

  E.g.
  ```
  1 -> 2 ------> 3 ---> 4
  -----> A --> C -------->
  =
  -----> 1A-2A --> 3C -> 4C
  ```
  """
  def combinelatestsilent_buffered_propagating(cobs, zobs, opts \\ [init: nil]) do
    init = Keyword.get(opts, :init, nil)

    # We tag each value from the c-observable and the z-observable with their respective labels.
    {f_c, _pid_c} =
      cobs
      #|> Observables.Obs.inspect()
      |> map(fn v -> {:c, v} end)

    {f_z, _pid_z} =
      zobs
      #|> Observables.Obs.inspect()
      |> map(fn v -> {:z, v} end)

    # Start our combine_silent_buffered_propagating observable.
    {:ok, pid} = GenObservable.start(CombineLatestSilentBufferedPropagating, [init])

    # Make left and right send to us.
    f_c.(pid)
    f_z.(pid)

    # Create the continuation.
    {fn observer ->
       GenObservable.send_to(pid, observer)
     end, pid}
  end

  @doc """
  Generalization of combinelatestsilent_buffered_propagating to n observables to 'combine latest' and m observables to zip.

  E.g.
  ```
  c1: ----------------> 1 ------------------------> 2 ---------------> 3
  c2: ------> A ------------------> B --------------------> C --------->
  z1: a -------> b-------------------------> c --------------> d ------>
  z2: --> @ ------> $ ---------------> % -------------> & ------------->
  =
  r:  -----------------> 1Aa@ 1Ab$ --------> 1Bc% -----------> 2Cd& --->
  ```

  More information: http://reactivex.io/documentation/operators/combinelatest.html
  """
  def combinelatest_n_zip_m_buffered_propagating(cobss, zobss, opts \\ [init: nil]) do
    # Process optional initial values
    inits = Keyword.get(opts, :inits, nil)
    init = case inits do
      nil   -> nil
      [_|_] -> List.to_tuple(inits)
    end

    # Build this primitive by composing simpler ones
    cobs = combinelatest_n(cobss, opts)
    zobs = zip_n(zobss)
    combinelatestsilent_buffered(cobs, zobs, [init: init])
      |> map(fn {cv, zv} -> 
        List.to_tuple(Tuple.to_list(cv) ++ Tuple.to_list(zv)) end)
  end

  # TERMINATORS ##################################################################

  @doc """
  Prints out the values produces by this observable. Keep in mind that this only works
  for values that are actually printable. If not sure, use inspect/1 instead.
  """
  def print({observable_fn, parent_pid}) do
    map({observable_fn, parent_pid}, fn v ->
      IO.puts(v)
      v
    end)
  end

  @doc """
  Same as the print/1 function, but uses inspect to print instead of puts.
  """
  def inspect({observable_fn, parent_pid}) do
    map({observable_fn, parent_pid}, fn v ->
      IO.inspect(v)
      v
    end)
  end
end

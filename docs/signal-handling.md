# Signal Handling

The master and worker processes will respond to the following signals as
documented.

## Master Process

- `QUIT` and `INT` - Quickly shutdown.
- `TERM` - Gracefully shutdown, this will wait for the workers to finish their
  current requests and gracefully timeout.
- `TTIN` - Increases the worker count by one.
- `TTOU` - Decreases the worker count by one.

### Example

TTIN and TTOU signals can be sent to the master to increase or decrease the number of workers.

To increase the worker count by one, where $PID is the PID of the master process.

```
$ kill -TTIN $PID
```

To decrease the worker count by one:

```
$ kill -TTOU $PID
```

## Worker Process

You may send signals directly to a worker process.

- `QUIT` and `INT` - Quickly shutdown.
- `TERM` - Gracefully shutdown.

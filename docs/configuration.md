# Configuration

Curassow provides you with an API, and a command line interface for configuration.

## Server Socket

### bind

The socket to bind to. This may either be in the form `HOST:PORT` or
`unix:PATH` where any valid IP is acceptable for `HOST`.

```shell
$ curassow --bind 127.0.0.1:9000
[INFO] Listening at http://127.0.0.1:9000 (940)
```

```shell
$ curassow --bind unix:/tmp/helloworld.sock
[INFO] Listening at unix:/tmp/helloworld.sock (940)
```

## Worker Processes

### workers

The number of worker processes for handling requests.

```shell
$ curassow --workers 3
[INFO] Listening at http://0.0.0.0:8000 (940)
[INFO] Booting worker process with pid: 941
[INFO] Booting worker process with pid: 942
[INFO] Booting worker process with pid: 943
```

By default, the value of the environment variable `WEB_CONCURRENCY` will be
used. If the environment variable is not set, `1` will be the default.

### worker-type

The type of worker to use. This defaults to `sync`. Currently the only
supported value is `sync`, there may be an async and gcd worker in the future.

```
$ curassow --worker-type sync
```


## timeout

By default, Curassow will kill and restart workers after 30 seconds if it
hasn't responded to the master process.

```
$ curassow --timeout 30
```

You can set the timeout to `0` to disable worker timeout handling.

## Server

### daemon

Daemonize the Curassow process. Detaches the server from the controlling
terminal and enters the background.

```shell
$ curassow --daemon
```

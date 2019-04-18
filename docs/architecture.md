# Curassow Architecture

This document outlines the architecture and design of the Curassow HTTP server.

Curassow uses the pre-fork worker model, which means that HTTP requests are
handled independently inside child worker processes. These worker processes are
automatically handled by Curassow, for example if a request causes a crash it
will be isolated to the single worker process which (which by default is
configured to handle a single request at a time) which means that if a request
causes a crash, it is isolated to that single request and does not cause
cascading failures. We leave balancing between the worker processes to the
kernel. Similar to the design of
[unicorn](https://bogomips.org/unicorn/DESIGN.html).

## Arbiter

The arbiter is the master process that manages the children worker processes.
It has a simple loop that listens for signals sent to the master process and
handles these signals. It manages worker processes, detects when a worker has
timed out or has crashed and recovers from these failures.

### Signals

The arbiter will watch for system signals and perform actions when it receives
them.

#### SIGQUIT and SIGINT

The quit and interrupt signals can be used to quickly shutdown Curassow.

#### SIGTERM

The termination signal can be used to gracefully shutdown Curassow. The arbiter
will wait for worker processes to finish handling their current requests or
gracefully timeout.

#### TTIN

Increment the amount of worker processes by one.

#### TTOU

Decrement the amount of worker processes by one.

## Worker

The worker process is responsible for handling HTTP requests.

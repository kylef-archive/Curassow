# Curassow Architecture

This document outlines the architecture and design of the Curassow HTTP server.

Curassow uses the pre-fork worker model, which means that HTTP requests are
handled independently inside child worker processes.

## Arbiter

The arbiter is the master process that manages the children worker processes.
It has a simple loop that listens for signals sent to the master process and
handles these signals.

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

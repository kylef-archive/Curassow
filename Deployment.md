# Deployment

When it comes to deploying your Curassow server to production, it's highly
recommended to run Curassow behind a HTTP proxy such as
[nginx](http://nginx.org/).

It's important to use a proxy server that can buffer slow clients when using
Curassow. Without buffering slow clients, Curassow will be easily be
susceptible to denial-of-service attacks.

**NOTE**: *Platforms such as Heroku already sit your HTTP server behind a proxy
so this does not apply on these types of platforms.*

## nginx

We highly recommend [nginx](http://nginx.org/), you can find
an example configuration below.

```nginx
worker_processes 1;

events {
  # Increase for higher clients
  worker_connections 1024;

  # Switch 'on' if Nginx's worker processes is more than one.
  accept_mutex off;

  # If you're on Linux
  # use epoll;

  #If you're on FreeBSD or OS X
  # use kqueue;
}

http {
  upstream curassow {
    # Change IP and port for your Curassow server
    server 127.0.0.1:8000 fail_timeout=0;
  }

  server {
    listen 80;

    # On Linux, instead use:
    # listen 80 deferred;

    # On FreeBSD instead use:
    # listen 80 accept_filter=httpready;

    client_max_body_size 1G;

    # Change to your host(s)
    server_name curassow.com www.curassow.com;

    keepalive_timeout 5;

    # Path to look for static resources and assets
    root /location/of/static/resources;

    location / {
      # Let's check for a static file locally before forwarding to Curassow.
      try_files $uri @proxy_to_app;
    }

    location @proxy_to_app {
      proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
      proxy_set_header Host $http_host;
      proxy_set_header X-Forwarded-Proto $scheme;

      proxy_redirect off;
      proxy_pass http://curassow;
    }
  }
}
```

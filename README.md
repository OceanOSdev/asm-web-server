## Simple Assembly WebServer

This project is just a simple tcp webserver written in assembly

#### Credit

- Tsoding: [Web in Native Assembly (Linux x86_64)](https://youtu.be/b-q4QBy52AA?si=ho78wbTjJ2K29o-2)

#### Dependencies

You need to have FASM installed

#### Building

Run the following in your terminal:

```sh
$ make
```

By default, FASM won't make the binary executable, so then just run:

```sh
$ chmod +x webserver
```

#### Running

Run the following in your terminal:

```sh
$ ./webserver
```

The server will be listening on `http://localhost:6969`

Optionally, you can also specify a port:

```sh
$ ./webserver -d 1234
```

And the server will be listening on `http://localhost:1234`

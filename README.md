# fluent-plugin-pg-query

[Fluentd](https://fluentd.org/) plugins to communicate with postgresql.


## Installation

### RubyGems

```
$ gem install fluent-plugin-pg-query
```

### Bundler

Add following line to your Gemfile:

```ruby
gem "fluent-plugin-pg-query"
```

And then execute:

```
$ bundle
```


## plugin : pg_query

### Behavior

### Parameters

#### tag

*tag* to emit event on.

Default is *pg_query*.

#### interval

*interval* between execution of the queries.

Default is *300*.

#### host

pg *host* to connect to.

Default is *localhost*.

#### port

pg *port* to connect to.

Default is *5432*.

#### database

*database* is equivalent to pg *dbname*.

No default, is mandatory.

#### user

*user* is equivalent to pg *user*.

Default to nil / empty.

#### password

*password* is equivalent to pg *password*.

Default to nil / empty.

#### sslmode

*sslmode* is equivalent to pg sslmode.

Values are :
- disable (default): No SSL.
- allow: Tries SSL, falls back to non-SSL.
- prefer: Tries non-SSL first, then SSL.
- require: SSL required (does not verify certificate).
- verify-ca: Requires SSL and verifies the certificate authority.
- verify-full: Requires SSL and verifies both the CA and the server hostname.

#### connect_timeout

*connect_timeout" is equivalent to pg *connect_timeout*.

Default to 10.

#### try_count

*try_count* is attempt count to run each SQL query.

Default to 3.

#### try_delay

*try_delay* is the delay between each attempt for a given SQL query.

Default to 5.

#### ca_cert

*ca_cert* is equivalent to pg *sslrootcert*.

Default is nil.

#### query

Each query is structured with :
- sql
- tag

*sql* is for the query string to execute.

*tag* is a specific subtag that will be concatenated to common tag, to
generate the tag, that will used to emit records returned by the query.

### Example

Configuration example:

```
<source>
  @type pg_query

  database test
  user test
  password test

  interval 5

  <query>
    sql select name, age from test
    tag query1
  </query>
</source>
```

So records returned by the sql query `select name, age from test`,
will be emitted on tag `test.query1`.


## Copyright

* Copyright(c) 2025- Thomas Tych
* License
  * Apache License, Version 2.0

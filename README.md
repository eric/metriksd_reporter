# Metriks Server Reporter

A reporter to send metrics from [metriks][] to [metriks_server][].


## Usage

Add the gem to your `Gemfile`:

``` ruby
gem 'metriks_server_reporter'
```

Use the reporter:

``` ruby
  reporter = MetriksServerReporter.new(:host => 'metriks_server.local', :port => 3331)
```


# License

Copyright (c) 2012 Eric Lindvall

Published under the MIT License, see LICENSE

[metriks]: https://github.com/eric/metriks
[metriks_server]: https://github.com/eric/metriks_server

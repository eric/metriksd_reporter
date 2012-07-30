# Metriks Server Reporter

A reporter to send metrics from [metriks][] to [metriksd][].


## Usage

Add the gem to your `Gemfile`:

``` ruby
gem 'metriksd_reporter'
```

Use the reporter:

``` ruby
  reporter = MetriksdReporter.new(:host => 'metriksd.local', :port => 3331)
```


# License

Copyright (c) 2012 Eric Lindvall

Published under the MIT License, see LICENSE

[metriks]: https://github.com/eric/metriks
[metriksd]: https://github.com/eric/metriksd

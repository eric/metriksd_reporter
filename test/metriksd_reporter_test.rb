require 'test_helper'
require 'metriks'

class MetriksdReporterTest < Test::Unit::TestCase
  def setup
    @registry = Metriks::Registry.new
    @reporter = MetriksdReporter.new(:host => '127.0.0.1', :port => 8372, :registry => @registry)
  end

  def test_basic
    @reporter.start
    @registry.timer('testing').update(4)
    @reporter.stop
  end
end

module MetriksdReporter
  VERSION = '0.5.0'

  def self.new(*args)
    Reporter.new(*args)
  end
end

require 'metriksd_reporter/reporter'

module MetriksdReporter
  VERSION = '0.5.1'

  def self.new(*args)
    Reporter.new(*args)
  end
end

require 'metriksd_reporter/reporter'

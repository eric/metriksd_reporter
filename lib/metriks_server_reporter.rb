module MetriksServerReporter
  VERSION = '0.5.0'

  def self.new(*args)
    Reporter.new(*args)
  end
end

require 'metriks_server_reporter/reporter'

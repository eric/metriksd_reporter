require 'metriks/time_tracker'
require 'snappy'
require 'msgpack'

module MetriksServerReporter
  class Reporter
    def initialize(options = {})
      missing_keys = %w(port host) - options.keys.map(&:to_s)
      unless missing_keys.empty?
        raise ArgumentError, "Missing required options: #{missing_keys * ', '}"
      end

      @port = options[:port]
      @host = options[:host]

      @client_id = options[:client_id] || "#{Socket.gethostname}:#{$$}"

      @extras = options[:extras] || {}

      @max_packet_size = options[:max_packet_size] || 1000

      @registry     = options[:registry] || Metriks::Registry.default
      @time_tracker = Metriks::TimeTracker.new(options[:interval] || 60)
      @on_error     = options[:on_error] || proc { |ex| }
    end

    def start
      @socket ||= UDPSocket.new

      @thread ||= Thread.new do
        loop do
          @time_tracker.sleep

          begin
            write
          rescue Exception => ex
            @on_error[ex] rescue nil
          end
        end
      end
    end

    def stop
      if @thread
        @thread.exit
        @thread = nil
      end

      flush

      if @socket
        @socket.close
        @socket = nil
      end
    end

    def join
      if @thread
        @thread.join
      end
    end

    def restart
      stop
      start
    end

    def flush
      write
    end

    def write
      @registry.each do |name, metric|
        case metric
        when Metriks::Meter
          write_metric name, 'meter', metric, [
            :count, :one_minute_rate, :five_minute_rate,
            :fifteen_minute_rate, :mean_rate
          ]
        when Metriks::Counter
          write_metric name, 'counter', metric, [
            :count
          ]
        when Metriks::UtilizationTimer
          write_metric name, 'utilization_timer', metric, [
            :count, :one_minute_rate, :five_minute_rate,
            :fifteen_minute_rate, :mean_rate,
            :min, :max, :mean, :stddev,
            :one_minute_utilization, :five_minute_utilization,
            :fifteen_minute_utilization, :mean_utilization,
          ], [
            :median, :get_95th_percentile
          ]
        when Metriks::Timer
          write_metric name, 'timer', metric, [
            :count, :one_minute_rate, :five_minute_rate,
            :fifteen_minute_rate, :mean_rate,
            :min, :max, :mean, :stddev
          ], [
            :median, :get_95th_percentile
          ]
        when Metriks::Histogram
          write_metric name, 'histogram', metric, [
            :count, :min, :max, :mean, :stddev
          ], [
            :median, :get_95th_percentile
          ]
        end
      end

      flush_packet
    end

    def append_to_packet(data)
      @packet ||= ''
      @packet << data.to_msgpack
      flush_packet_if_full
    end

    def flush_packet_if_full
      if @packet && @packet.length > @max_packet_size
        flush_packet
      end
    end

    def flush_packet
      if @packet && @packet.length > 0
        @socket.send(Snappy.deflate(@packet), 0, @host, @port)
        @packet = ''
      end
    end

    def extract_from_metric(metric, *keys)
      h = {}

      keys.flatten.collect do |key|
        name = key.to_s.gsub(/^get_/, '')
        h[name] = metric.send(key)
      end
      
      h
    end

    def write_metric(name, type, metric, keys, snapshot_keys = [])
      message = @extras.merge(
        :client_id => @client_id,
        :time => Time.now.to_i,
        :name => name,
        :type => type
      )

      message.merge!(extract_from_metric(metric, keys))

      unless snapshot_keys.empty?
        snapshot = metric.snapshot
        message.merge!(extract_from_metric(snapshot, snapshot_keys))
      end

      append_to_packet(message)
    end
  end
end

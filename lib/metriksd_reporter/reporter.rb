require 'snappy'
require 'msgpack'

module MetriksdReporter
  class Reporter
    def initialize(options = {})
      missing_keys = %w(port host) - options.keys.map(&:to_s)
      unless missing_keys.empty?
        raise ArgumentError, "Missing required options: #{missing_keys * ', '}"
      end

      @port = options[:port]
      @host = options[:host]

      @client_id       = options[:client_id] || "#{Socket.gethostname}:#{$$}"
      @extras          = options[:extras] || {}
      @registry        = options[:registry] || Metriks::Registry.default

      @max_packet_size = options[:max_packet_size] || 1000
      @interval        = options[:interval] || 60
      @interval_offset = options[:interval_offset] || 0
      @flush_delay     = options[:flush_delay] || 0.6

      @on_error        = options[:on_error] || proc { |ex| }
    end

    def start
      @socket ||= UDPSocket.new

      @thread ||= Thread.new do
        loop do
          sleep_until_deadline

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
      if @packet && @packet.length > 0 && @packet.length > max_packet_size_with_compression_ratio
        flush_packet
        sleep_for_up_to(0.6)
      end
    end

    def flush_packet
      if @packet && @packet.length > 0
        compressed = Snappy.deflate(@packet)

        # Calculate the compression ratio
        @compression_ratio = @packet.length / compressed.length

        # Send the packet
        @socket.send(compressed, 0, @host, @port)
        @packet = ''
      end
    end

    def max_packet_size_with_compression_ratio
      if @compression_ratio
        @max_packet_size * @compression_ratio * 0.9
      else
        @max_packet_size
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

    def sleep_until_deadline
      # Ensure we round up when we should
      now = Time.now.to_f + @interval_offset

      rounded      = now - (now % @interval)
      next_rounded = rounded + @interval - @interval_offset
      sleep_time   = next_rounded - Time.now.to_f

      if sleep_time > 0
        sleep(sleep_time)
      end
    end

    def sleep_for_up_to(duration)
      duration *= rand
      if duration > 0
        sleep(duration)
      end
    end
  end
end

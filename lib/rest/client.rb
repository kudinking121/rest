require 'json'
require 'logger'

# This is a simple wrapper that can use different http clients depending on what's installed.
# The purpose of this is so that users who can't install binaries easily (like windoze users) can have fallbacks that work

module Rest

  class ClientError < StandardError

  end


  class TimeoutError < ClientError
    def initialize(msg=nil)
      msg ||= "HTTP Request Timed out."
      super(msg)
    end
  end


  def self.gem=(g)
    @gem = g
  end

  def self.gem
    @gem
  end

  begin
    require 'typhoeus'
    Rest.gem = :typhoeus
    require_relative 'wrappers/typhoeus_wrapper'
  rescue LoadError => ex
    puts "Could not load typhoeus, falling back to rest-client. Please install 'typhoeus' gem for best performance."
    require 'rest_client'
    Rest.gem = :rest_client
    require_relative 'wrappers/rest_client_wrapper'
  end


  class Client

    attr_accessor :options
    # options:
    # - :gem => specify gem explicitly
    #
    def initialize(options={})
      @logger = Logger.new(STDOUT)
      @logger.level=Logger::INFO
      @options = options

      Rest.gem = options[:gem] if options[:gem]

      if Rest.gem == :typhoeus
        @wrapper = Rest::Wrappers::TyphoeusWrapper.new
      else
        @wrapper = Rest::Wrappers::RestClientWrapper.new
      end

    end

    def get(url, req_hash={})
      max_retries = @options[:retries] || 0
      current_retry = 0
      success = false
      while current_retry <= max_retries do
        #fmt.Println(num, "Pushing", i, "try", currentRetry, "total:", TotalCount)
        res = @wrapper.get(url, req_hash)
        if current_retry >= max_retries
          return res
        end
        if res.code == 503
          pow = (4 ** current_retry) * 100 # milliseconds
          puts 'pow=' + pow.to_s
          s = Random.rand * pow
          puts 's=' + s.to_s
          sleep_secs = 1.0 * s / 1000.0
          puts 'sleep for ' + sleep_secs.to_s
          sleep sleep_secs
        else
          success = true
          break
        end
        current_retry += 1
      end

      # req_hash options:
      # - :body => post body
      #
      def post(url, req_hash={})
        @wrapper.post(url, req_hash)
      end

      def put(url, req_hash={})
        @wrapper.put(url, req_hash)
      end

      def delete(url, req_hash={})
        @wrapper.delete(url, req_hash)
      end
    end
  end
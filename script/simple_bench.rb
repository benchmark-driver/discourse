#!/usr/bin/env ruby
#
# Usage:
#   script/simple_bench.rb 100
#

ENV['RAILS_ENV'] ||= 'profile'
require_relative '../config/boot'
require 'bundler/setup'
require_relative '../config/environment'

module SimpleBench
  PERCENTILES = [
    50,
    75,
    90,
    99,
  ]

  class << self
    def percentile(times)
      app = Rack::MockRequest.new(Rails.application)
      api_key = fetch_api_key

      path = '/'
      params = { api_key: api_key, api_username: 'admin1' }
      full_path = "#{path}?#{params.to_query}"
      headers = {}

      # benchmark
      durations = []
      i = 0
      while i < times
        started_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        app.get(full_path, headers)
        duration = Process.clock_gettime(Process::CLOCK_MONOTONIC) - started_at

        durations << duration
        i += 1
        print "\rbenchmark: #{i}/#{times}"
      end

      puts "\n\nGET #{path}:"
      show_percentiles(durations)
    end

    def profile
      require 'stackprof'

      app = Rack::MockRequest.new(Rails.application)
      api_key = fetch_api_key

      path = '/'
      params = { api_key: api_key, api_username: 'admin1' }
      full_path = "#{path}?#{params.to_query}"
      headers = {}

      5.times { app.get(full_path, headers) } # warmup

      StackProf.run(mode: :wall, interval: 100, out: 'stackprof.dump') do
        i = 0
        while i < 10
          app.get(full_path, headers)
          i += 1
        end
      end
    end

    private

    def fetch_api_key
      `bundle exec rake api_key:get`.split("\n")[-1]
      #"e5f4e98cc916bea219cb3b3395d85a5aa42118e45ca4b195d47e2ef80bbe4d22"
    end

    def show_percentiles(durations)
      percentiles = PERCENTILES.dup
      results = {}

      durations.sort.each_with_index do |duration, index|
        percentile = (index / durations.size.to_f) * 100
        matched, percentiles = percentiles.partition { |threshold| percentile >= threshold }

        matched.each do |match|
          results[match] = duration
        end
        break if percentiles.empty?
      end

      results.each do |percentile, duration|
        puts "  #{percentile}: #{"%.1f" % (duration * 1000)}ms"
      end
      puts
    end
  end
end

# todo: mkdir -p tmp/letter_avatars

SimpleBench.percentile(Integer(ARGV.first || 100))
#SimpleBench.profile

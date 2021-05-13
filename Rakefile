# frozen_string_literal: true

require_relative 'lib/fetcher'
require_relative 'lib/analyzer'
require_relative 'lib/metricsexporter'
require_relative 'lib/metricsloader'

namespace :run do
  # Fetch
  desc "Fetch combined files from the bucket"
  task :fetch do
    start_date = ENV.fetch('RAKE_START_DATE', '')
    bucket_name = ENV.fetch('RAKE_BUCKET_NAME', '')
    Fetcher.new(start_date, bucket_name).fetch
  end

  # Load/Analyze 
  desc "Load, analyze, and export results"
  task :analyze do
    Analyzer.new
  end

  # Export/load metrics 
  namespace :metrics do
    desc "Export metrics from findings"
    task :export do
      MetricsExporter.new
    end
    desc "Load metrics into viz"
    task :load do
      MetricsLoader.new
    end
  end
  # All Metrics
  desc "run metrics export and load"
  task :metrics => ["metrics:export", "metrics:load"]

  # All Steps
  desc "Run fetch, load, metrics"
  task :all => ["fetch", "analyze", "metrics:export", "metrics:load"]
end

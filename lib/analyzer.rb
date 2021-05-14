# frozen_string_literal: true

require 'pry'
require 'redisgraph'
require 'parallel'
require 'json'
require 'fast_jsonparser'
require 'rspec'
require 'rspec/core'
require 'rspec/core/formatters/base_formatter'
require_relative 'spec/formatters/custom_formatter'
require_relative 'spec/support/db_helper'
require_relative 'spec/support/redisgraph_helper'
require_relative 'asset/asset_router'

class Analyzer

  def initialize
     puts "Loader/Analyzer"

     db_config = { url: 'redis://localhost:6379' }
     @db ||= RedisGraph.new('opencspm', db_config)
     list_to_load = get_list_to_load
     load_findings(list_to_load)
  end

  private

  def load_findings(list_to_load)

    # for each missing findings file,
    list_to_load.each do |load_date|
       # Get combined file path
       load_file = get_load_file_path(load_date)
       next unless File.exists?(load_file)

       #  Clear redisgraph contents
       clear_redisgraph

       #  Load data
       loop_over_asset_lines(load_file, load_date)

       #  Analyze results
       run_analysis

       findings_file = get_findings_file_path(load_date)
       generate_findings(findings_file)
    end
  end

  def run_analysis
    puts "Analyzing results"
    begin
      RSpec.world.reset
      RSpec.reset
      RSpec.clear_examples

      custom_formatter = CspmFormatter.new(StringIO.new)
      reporter = RSpec::Core::Reporter.new(custom_formatter) 

      options = []
      options << Dir['../opencspm-controls/**/controls_spec.rb'].reject { |f| f.start_with?('../opencspm-controls/_') }
      options << '-fCspmFormatter'
      RSpec::Core::Runner.run(options)

      RSpec.clear_examples
      RSpec.world.reset
      RSpec.reset

    rescue StandardError => e
      puts "#Analysis failed - #{e.class} #{e.message} (#{e.backtrace[0]})"
      raise e
    end

  end

  # Batch load file, send each line to asset router
  def loop_over_asset_lines(file_name, load_date)
    import_id = DateTime.parse(load_date).to_time.to_i
    line_count = 0
    puts "Loading #{file_name}"
    batch_size = 25000
    File.open(file_name) do |file|
      file.each_slice(batch_size) do |lines|
        Parallel.each(lines, in_processes: 8) do |line|
        #lines.each do |line|
          asset_json = FastJsonparser.parse(line, symbolize_keys: false)
          AssetRouter.new(asset_json, import_id, @db)
        end
      end
      file.rewind
      puts "Done loading #{file_name}. (#{file.readlines.size} lines)"
    end

  end

  def get_load_file_path(load_date)
    "#{Dir.pwd}/data/combined/#{load_date}.json"
  end

  def get_findings_file_path(load_date)
    "#{Dir.pwd}/data/findings/#{load_date}.findings"
  end

  def get_list_to_load
     # look up combined export directory, get list of files not in the findings data directory
     combined_list = Dir.glob('./data/combined/*.json').map {|item| File.basename(item).gsub(/.json$/,"") }
     findings_list = Dir.glob('./data/findings/*.findings').map {|item| File.basename(item).gsub(/.findings$/,"") }
     # Return an array of the diff/missing findings dates
     combined_list.sort - findings_list.sort
  end

  def clear_redisgraph
    puts "Clearing the 'opencspm' graph"
    query = %(
      MATCH (n) DETACH DELETE (n)
    )
    @db.query(query)
  end

  def generate_findings(findings_file)
    puts 'Generating findings...'
    pack_base_dir = '../opencspm-controls/**/config.yaml'
    results_file = '/tmp/results'
    output_file = findings_file
    @results = []
    @results = JSON.parse(File.read(results_file))

    controls = []
    raw_results = {
      summary: {},
      version: '4.0.0',
      results: []
    }

    # load control packs
    Dir[pack_base_dir].each do |file|
      next if file.start_with?('../opencspm-controls/_')

      controls.push(JSON.parse(YAML.safe_load(File.read(file)).to_json, object_class: OpenStruct).controls)
    end

    # flatten
    controls = controls.flatten

    # iterate over results, push onto raw_results
    @results.each_with_index do |result, idx|
      cid = result['control_id']
      ctrl = controls.find { |c| c.id == cid }

      #puts "Finding #{idx + 1} - #{cid}"

      raw_results[:results].push({
                                   version: '4',
                                   control: cid,
                                   finding: idx + 1,
                                   platform: ctrl.platform,
                                   category: ctrl.category,
                                   resource: ctrl.resource,
                                   title: ctrl.title,
                                   description: ctrl.description,
                                   validation: ctrl.validation,
                                   remediation: ctrl.remediation,
                                   severity: ctrl.impact ? ctrl.impact / 10.0 : 0.999,
                                   effort: ctrl.effort ? ctrl.effort / 10.0 : 0.999,
                                   resources: result['resources'].map do |r|
                                                {
                                                  resource: r['name'],
                                                  status: r['status']
                                                }
                                              end,
                                   references: ctrl.refs.map do |r|
                                                 {
                                                   text: r.text,
                                                   url: r.url,
                                                   ref: 'link'
                                                 }
                                               end,
                                   result: {
                                     status: result['resources'].filter { |r| r['status'] == 'failed' }.length.positive? ? 'failed' : 'passed',
                                     passed: result['resources'].filter { |r| r['status'] == 'passed' }.count,
                                     total: result['resources'].count
                                   }
                                 })
    end

    # write raw findings
    File.open(output_file, 'w') { |file| file.write(raw_results.to_json) }
    puts "Wrote raw findings to #{output_file}"
  end

end

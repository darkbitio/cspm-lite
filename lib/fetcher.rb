# frozen_string_literal: true

require 'time'
require 'google/cloud/storage'
require 'pry'

class Fetcher
  def initialize(start_date, project_id, bucket_name)
    # If start_date isn't passed in via "YYYY-MM-DD", use "yesterday"
    @start_date = start_date.empty? ? Time.now.utc.to_date.prev_day : Date.parse(start_date)
    # We need a bucket passed
    raise "project_id must be specified" if project_id.empty?
    raise "bucket_name must be specified" if bucket_name.empty?
    # Get the bucket connection object
    storage = Google::Cloud::Storage.new(project_id: project_id)
    @bucket = storage.bucket(bucket_name)
  end

  def fetch
    manifests = fetch_manifests
    file_list = create_file_list(manifests)
    download_manifests(file_list)
  end

  private

  def fetch_manifests
    # Get a list of manifest.txt files in the cai/, iam/, and k8s/ prefixes
    manifests = []
    %w{cai iam k8s}.each do |prefix|
      files = @bucket.files prefix: "#{prefix}/"
      files.all do |file|
        manifests << file.gapi.name if file.gapi.name =~ /.*manifest.txt$/
      end
    end
    manifests
  end 

  def create_file_list(manifest_list)
    # Build a hash that holds the last files exported each day for each type of export
    file_list = {}
    manifest_list.each do |manifest|
      files = @bucket.files prefix: manifest
      bucket_folder = File.dirname(manifest)
      files.all do |file|
        generations = file.generations
        # filter down to begin at start date until yesterday
        file_generations = generations.delete_if {|gen| gen.gapi.time_created < @start_date }.delete_if {|gen| gen.gapi.time_created.to_date > Time.now.utc.to_date.prev_day }
        file_generations.each do |f|
          puts "#{f.name} #{f.gapi.time_created.to_s} #{f.gapi.generation}"
          export_date = f.gapi.time_created.to_date.to_s
          file_list[export_date] = {} if file_list[export_date].nil?
          file_list[export_date][bucket_folder] = {} if file_list[export_date][bucket_folder].nil?
          normalized_manifest = File.basename(f.gapi.name.gsub(/^[0-9]+\_/,"")).gsub(/\.txt$/,"")
          file_list[export_date][bucket_folder][normalized_manifest] = [] if file_list[export_date][bucket_folder][normalized_manifest].nil?
          downloaded = f.download
          downloaded.rewind
          contents = downloaded.read.lines.map(&:chomp)
          list = []
          contents.each do |export_name|
            list << "#{bucket_folder}/#{export_name}"  
          end
          file_list[export_date][bucket_folder][normalized_manifest] = list
        end
      end
    end
    file_list
  end

  def download_manifests(file_list)
    # Download combined export json files locally from a desired list of manifests/files
    manifest_dir = "#{Dir.pwd}/data/combined"
    file_list.keys.each do |export_date|
      # Per-day file name is to be deterministic
      combined_export = "#{manifest_dir}/#{export_date}.json"

      # Skip if we already downloaded this file
      next if File.exists?(combined_export)

      # Iterate over hash keys of the date "YYYY-MM-DD"
      file_list[export_date].keys.each do |export_prefix|
        # Iterate over hash keys of the export type: "cai", "iam", "k8s"
        file_list[export_date][export_prefix].keys.each do |export_manifest|
          # Iterate over hash keys of the base manifest name: manifest.txt, prod_cluster_manifest.txt
          file_list[export_date][export_prefix][export_manifest].each do |export_file|
            # Download/append to ./manifests/YYYY-MM-DD-combined.json
            downloaded_file = @bucket.file(export_file).download
            downloaded_file.rewind
            puts "Writing #{export_file} to #{combined_export}"
            File.open(combined_export, "a") do |file| 
              file.puts downloaded_file.read if downloaded_file.length > 0
            end
          end
        end
      end
    end 
  end

end

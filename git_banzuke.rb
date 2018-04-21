#!/usr/bin/env ruby

require "optparse"

require_relative "./git_leaderboard.rb"

class BanzukeEntry
	attr_reader :git_repository_path
	attr_reader :normalized_email_addresses
	attr_reader :normalized_names
	attr_reader :banned_email_addresses
	attr_reader :banned_paths
	attr_reader :output_path

	def initialize(
		git_repository_path:,
		normalized_email_addresses:,
		normalized_names:,
		banned_email_addresses:,
		banned_paths:,
		output_path:
	)
		@git_repository_path = git_repository_path
		@normalized_email_addresses = normalized_email_addresses
		@normalized_names = normalized_names
		@banned_email_addresses = banned_email_addresses
		@banned_paths = banned_paths
		@output_path = output_path
	end
end

class Banzuke
	attr_reader :author_summaries

	def initialize()
		@author_summaries = {}
	end

	def append(author_summaries_to_append)
		for (author_email, author_summary) in author_summaries_to_append
			if banzuke_author_summary = @author_summaries[author_email]
				new_author_summary = AuthorSummary.new(
					author_name: banzuke_author_summary.author_name,
					author_email: author_email,
					number_of_commits: banzuke_author_summary.number_of_commits + author_summary.number_of_commits,
					number_of_additions: banzuke_author_summary.number_of_additions + author_summary.number_of_additions,
					number_of_deletions: banzuke_author_summary.number_of_deletions + author_summary.number_of_deletions,
					number_of_files_modified: banzuke_author_summary.number_of_files_modified + author_summary.number_of_files_modified,
					)

				@author_summaries[author_email] = new_author_summary
			else
				@author_summaries[author_email] = author_summary
			end
		end
	end
end

class BanzukeScriptOptions
	attr_reader :entries
	attr_reader :output_path
	attr_reader :output_raw
	attr_reader :verbose

	def initialize(
		args:,
		option_parser:
	)
		@entries = []
		@output_raw = true
		@verbose = true

		option_parser.accept(JSON) do |option_json|
			if File.file?(option_json)
				json_string = File.read(option_json)
				JSON.parse(json_string)
			else
				JSON.parse(option_json)
			end
		end

		option_parser.on(
			"--configuration-file PATH",
			"Path to the configuration file.",
			JSON,
			) do |option_json|
				entries = []

				for row in option_json
					if git_repository_path = row["git_repository_path"]
						if normalized_email_addresses = row["normalized_email_addresses"]
							if normalized_email_addresses.is_a?(String) and File.file?(File.expand_path(normalized_email_addresses))
								json_string = File.read(File.expand_path(normalized_email_addresses))
								normalized_email_addresses = JSON.parse(json_string)
							elsif !normalized_email_addresses.is_a?(Hash)
								normalized_email_addresses = {}
							end
						else
							normalized_email_addresses = {}
						end

						if normalized_names = row["normalized_names"]
							if normalized_names.is_a?(String) and File.file?(File.expand_path(normalized_names))
								json_string = File.read(File.expand_path(normalized_names))
								normalized_names = JSON.parse(json_string)
							elsif !normalized_names.is_a?(Hash)
								normalized_names = {}
							end
						else
							normalized_names = {}
						end

						if banned_email_addresses = row["banned_email_addresses"]
							if banned_email_addresses.is_a?(String) and File.file?(File.expand_path(banned_email_addresses))
								json_string = File.read(File.expand_path(banned_email_addresses))
								banned_email_addresses = JSON.parse(json_string)
							elsif !banned_email_addresses.is_a?(Array)
								banned_email_addresses = []
							end
						else
							banned_email_addresses = []
						end

						if banned_paths = row["banned_paths"]
							if banned_paths.is_a?(String) and File.file?(File.expand_path(banned_paths))
								json_string = File.read(File.expand_path(banned_paths))
								banned_paths = JSON.parse(json_string)
							elsif !banned_paths.is_a?(Array)
								banned_paths = []
							end
						else
							banned_paths = []
						end

						output_path = row["output_path"]

						entry = BanzukeEntry.new(
							git_repository_path: git_repository_path,
							normalized_email_addresses: normalized_email_addresses,
							normalized_names: normalized_names,
							banned_email_addresses: banned_email_addresses,
							banned_paths: banned_paths,
							output_path: output_path
						)
						entries.push(entry)
					end
				end

				@entries = entries
		end

		option_parser.on(
			"--output-path PATH",
			String,
			"The path that the script should save its output to.",
			"The output will be a comma-separated values text file and as such will automatically have \".csv\" appended to it."
			) do |output_path|
				@output_path = output_path
		end

		option_parser.on(
			"--output-raw BOOL",
			"A switch to determine if the unfiltered leaderboard should also be outputted for every respository.",
			"Defaults to true.",
			TrueClass
			) do |flag|
				@verbose = flag
		end

		option_parser.on(
			"--verbose BOOL",
			"A switch to determine if actions taken should be outputted to the console.",
			"Defaults to true.",
			TrueClass
			) do |flag|
				@verbose = flag
		end

		option_parser.parse(args)
	end
end

if __FILE__ == $PROGRAM_NAME
	ARGV << "--help" if ARGV.empty?

	script_options = BanzukeScriptOptions.new(
		args: ARGV, 
		option_parser: OptionParser.new
	)

	banzuke = Banzuke.new
	raw_banzuke = Banzuke.new

	for entry in script_options.entries do
		if script_options.verbose
			puts "Computing the leaderboard for #{entry.git_repository_path}"
		end

		Dir.chdir(File.expand_path(entry.git_repository_path)) do
			`git fetch`
			`git checkout master`
		end

		author_summaries = author_summaries_for(
			git_repository_path: entry.git_repository_path,
			normalized_email_addresses: entry.normalized_email_addresses,
			normalized_names: entry.normalized_names,
			banned_email_addresses: entry.banned_email_addresses,
			banned_paths: entry.banned_paths,
			verbose: script_options.verbose
		)

		process(
			author_summaries: author_summaries,
			output_path: entry.output_path,
			verbose: script_options.verbose
		)

		banzuke.append(author_summaries)

		if script_options.output_raw and entry.output_path.nil? == false
			if script_options.verbose
				puts "Computing the raw leaderboard for #{entry.git_repository_path}"
			end

			raw_author_summaries = author_summaries_for(
				git_repository_path: entry.git_repository_path,
				verbose: false
			)

			process(
				author_summaries: raw_author_summaries,
				output_path: "#{entry.output_path}_raw",
				verbose: false
			)

			raw_banzuke.append(raw_author_summaries)
		end
	end

	process(
		author_summaries: banzuke.author_summaries,
		output_path: script_options.output_path,
		verbose: script_options.verbose
	)

	if script_options.output_raw and script_options.output_path.nil? == false
		process(
			author_summaries: raw_banzuke.author_summaries,
			output_path: "#{script_options.output_path}_raw",
			verbose: script_options.verbose
		)
	end
end

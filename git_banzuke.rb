#!/usr/bin/env ruby

require "optparse"

require_relative "./git_leaderboard.rb"

class BanzukeEntry
	attr_reader :git_repository_path
	attr_reader :normalized_names
	attr_reader :banned_names
	attr_reader :banned_paths
	attr_reader :output_path

	def initialize(git_repository_path, normalized_names, banned_names, banned_paths, output_path)
		@git_repository_path = git_repository_path
		@normalized_names = normalized_names
		@banned_names = banned_names
		@banned_paths = banned_paths
		@output_path = output_path
	end
end

class BanzukeScriptOptions
	attr_reader :entries
	attr_reader :verbose

	def initialize(args, option_parser)
		@entries = []
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

						if banned_names = row["banned_names"]
							if banned_names.is_a?(String) and File.file?(File.expand_path(banned_names))
								json_string = File.read(File.expand_path(banned_names))
								banned_names = JSON.parse(json_string)
							elsif !banned_names.is_a?(Array)
								banned_names = []
							end
						else
							banned_names = []
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

						entry = BanzukeEntry.new(git_repository_path, normalized_names, banned_names, banned_paths, output_path)
						entries.push(entry)
					end
				end

				@entries = entries
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

	script_options = BanzukeScriptOptions.new(ARGV, OptionParser.new)

	banzuke_author_summaries = {}

	for entry in script_options.entries do
		if script_options.verbose
			puts "Computing the leaderboard for #{entry.git_repository_path}"
		end

		author_summaries = author_summaries_for(
			git_repository_path: entry.git_repository_path,
			normalized_names: entry.normalized_names,
			banned_names: entry.banned_names,
			banned_paths: entry.banned_paths,
			verbose: script_options.verbose
		)

		process(
			author_summaries: author_summaries,
			output_path: entry.output_path,
			verbose: script_options.verbose
		)

		for (author_name, author_summary) in author_summaries
			if banzuke_author_summary = banzuke_author_summaries[author_name]
				new_author_summary = AuthorSummary.new(
					author_name: author_name,
					number_of_commits: banzuke_author_summary.number_of_commits + author_summary.number_of_commits,
					number_of_additions: banzuke_author_summary.number_of_additions + author_summary.number_of_additions,
					number_of_deletions: banzuke_author_summary.number_of_deletions + author_summary.number_of_deletions,
					number_of_files_modified: banzuke_author_summary.number_of_files_modified + author_summary.number_of_files_modified,
					)

				banzuke_author_summaries[author_name] = new_author_summary
			else
				banzuke_author_summaries[author_name] = author_summary
			end
		end
	end

	process(
			author_summaries: banzuke_author_summaries,
			output_path: "./_Banzuke",
			verbose: script_options.verbose
		)
end

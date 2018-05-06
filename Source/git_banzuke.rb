#!/usr/bin/env ruby

require "optparse"

require_relative "./git_leaderboard.rb"

module Scripts
	# {BanzukeEntry} represents a single row from the configuration file that is passed into the git_banzuke.rb script.
	class BanzukeEntry
		# @return [String] the value of the "git_repository_path" field.
		attr_reader :git_repository_path
		# @return [Hash{String => String}] the value of the "normalized_email_addresses" field.
		attr_reader :normalized_email_addresses
		# @return [Hash{String => String}] the value of the "normalized_names" field.
		attr_reader :normalized_names
		# @return [Array<String>] the value of the "banned_email_addresses" field.
		attr_reader :banned_email_addresses
		# @return [Array<String>] the value of the "banned_paths" field.
		attr_reader :banned_paths
		# @return [String] the value of the "output_path" field.
		attr_reader :output_path

		# Initializes a new instance of {BanzukeEntry}.
		#
		# @param [String] git_repository_path The path to the git repository.
		# @param [Hash{String => String}] normalized_email_addresses A hash where the keys are a author's email address and the values are what that email address should be normalized to.
		# @param [Hash{String => String}] normalized_names A hash where the keys are an author's email address and the values are what that author's name should be normalized to.
		# @param [Array<String>] banned_email_addresses An array of email addresses for authors whose commits should be ignored.
		# @param [Array<String>] banned_paths An array of regular expressions that will be evaluated against file modification paths to determine if the file modification should be ignored or not.
		# @param [String] output_path The path where a comma-separated values text file should be outtputed to. The extension \".csv\" will automatically be  appended.
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

	# The {BanzukeOptions} class encapsulates all of the options that can be passed into the git_banzuke.rb script via the command line.
	class BanzukeOptions
		# @return [Array<BanzukeEntry>] an array of banzuke entries parsed from the "--configuration-file" option.
		attr_reader :entries
		# @return [String, nil] the value of the "--output-path" option.
		attr_reader :output_path
		# @return [Boolean] the value of the "--output-unfiltered" option.
		attr_reader :output_unfiltered
		# @return [Boolean] the value of the "--verbose" option.
		attr_reader :verbose

		# Initializes a new instance of {BanzukeOptions}.
		#
		# The option_parser will parse the args parameter and use the results to populate all of the attributes.
		#
		# @param [Array<String>] args The arguments that were passed in to the command line.
		# @param [OptionParser] option_parser An OptionParser that will consume the args parameter.
		def initialize(
			args:,
			option_parser:
		)
			@entries = []
			@output_unfiltered = true
			@verbose = true

			option_parser.on(
				"--configuration-file PATH",
				"Path to the configuration file.",
				String,
				) do |option_path|
					configuration_file_contents = File.read(option_path)
					configuration_file_json = JSON.parse(configuration_file_contents)
					configuration_file_directory = File.dirname(option_path)

					entries = []

					for row in configuration_file_json
						if git_repository_path = row["git_repository_path"]
							if normalized_email_addresses = row["normalized_email_addresses"]
								if normalized_email_addresses.is_a?(String) and path = File.expand_path(normalized_email_addresses, configuration_file_directory) and File.file?(path)
									json_string = File.read(path)
									normalized_email_addresses = JSON.parse(json_string)
								elsif !normalized_email_addresses.is_a?(Hash)
									normalized_email_addresses = {}
								end
							else
								normalized_email_addresses = {}
							end

							if normalized_names = row["normalized_names"]
								if normalized_names.is_a?(String) and path = File.expand_path(normalized_names, configuration_file_directory) and File.file?(path)
									json_string = File.read(path)
									normalized_names = JSON.parse(json_string)
								elsif !normalized_names.is_a?(Hash)
									normalized_names = {}
								end
							else
								normalized_names = {}
							end

							if banned_email_addresses = row["banned_email_addresses"]
								if banned_email_addresses.is_a?(String) and path = File.expand_path(banned_email_addresses, configuration_file_directory) and File.file?(path)
									json_string = File.read(path)
									banned_email_addresses = JSON.parse(json_string)
								elsif !banned_email_addresses.is_a?(Array)
									banned_email_addresses = []
								end
							else
								banned_email_addresses = []
							end

							if banned_paths = row["banned_paths"]
								if banned_paths.is_a?(String) and path = File.expand_path(banned_paths, configuration_file_directory) and File.file?(path)
									json_string = File.read(path)
									banned_paths = JSON.parse(json_string)
								elsif !banned_paths.is_a?(Array)
									banned_paths = []
								end
							else
								banned_paths = []
							end

							output_path = File.expand_path(row["output_path"], configuration_file_directory)

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
				"The path that the script should write its output to.",
				"The output will be a comma-separated values text file and as such will automatically have \".csv\" appended to it."
				) do |output_path|
					@output_path = output_path
			end

			option_parser.on(
				"--output-unfiltered BOOL",
				"A switch to determine if an unfiltered leaderboard should also be outputted for every respository. The email addresses and names will still be normalized.",
				"Defaults to true.",
				TrueClass
				) do |flag|
					@output_unfiltered = flag
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

	# {Banzuke} is an accumulator class designed to gather author summaries for a number of git repositories and merge ones that have the same author together.
	class Banzuke
		# @return [Hash{String => AuthorSummary}] a hash where the keys are author email addresses and the values are author summaries for that email address.
		attr_reader :author_summaries

		def initialize()
			@author_summaries = {}
		end

		# Merges an array of {Git::AuthorSummary} into the Banzuke.
		#
		# @param [Array<AuthorSummary>] author_summaries_to_append An array of {Git::AuthorSummary} to add to the Banzuke.
		def append(author_summaries_to_append)
			for (author_email, author_summary) in author_summaries_to_append
				if banzuke_author_summary = @author_summaries[author_email]
					new_author_summary = Git::AuthorSummary.new(
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
end

if __FILE__ == $PROGRAM_NAME
	ARGV << "--help" if ARGV.empty?

	script_options = Scripts::BanzukeOptions.new(
		args: ARGV, 
		option_parser: OptionParser.new
	)

	banzuke = Scripts::Banzuke.new
	unfiltered_banzuke = Scripts::Banzuke.new

	for entry in script_options.entries do
		if script_options.verbose
			puts "Computing the leaderboard for #{entry.git_repository_path}"
		end

		Dir.chdir(File.expand_path(entry.git_repository_path)) do
			`git fetch`
			`git checkout master`
		end

		author_summaries = Git.author_summaries_for(
			git_repository_path: entry.git_repository_path,
			normalized_email_addresses: entry.normalized_email_addresses,
			normalized_names: entry.normalized_names,
			banned_email_addresses: entry.banned_email_addresses,
			banned_paths: entry.banned_paths,
			verbose: false
		)

		Git.output_leaderboard_for(
			author_summaries: author_summaries,
			output_path: entry.output_path,
			verbose: script_options.verbose
		)

		banzuke.append(author_summaries)

		if script_options.output_unfiltered and entry.output_path.nil? == false
			if script_options.verbose
				puts "Computing the unfiltered leaderboard for #{entry.git_repository_path}"
			end

			unfiltered_author_summaries = Git.author_summaries_for(
				git_repository_path: entry.git_repository_path,
				normalized_email_addresses: entry.normalized_email_addresses,
				normalized_names: entry.normalized_names,
				verbose: false
			)

			Git.output_leaderboard_for(
				author_summaries: unfiltered_author_summaries,
				output_path: "#{entry.output_path}_unfiltered",
				verbose: false
			)

			unfiltered_banzuke.append(unfiltered_author_summaries)
		end
	end

	Git.output_leaderboard_for(
		author_summaries: banzuke.author_summaries,
		output_path: script_options.output_path,
		verbose: script_options.verbose
	)

	if script_options.output_unfiltered and script_options.output_path.nil? == false
		Git.output_leaderboard_for(
			author_summaries: unfiltered_banzuke.author_summaries,
			output_path: "#{script_options.output_path}_unfiltered",
			verbose: script_options.verbose
		)
	end
end

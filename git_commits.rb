#!/usr/bin/env ruby

require "json"
require "optparse"

# The Git module contains classes and methods to interact with git repositories.
#
# Not all interactions will map directly to git commands. There will be a number of classes and methods that exist solely to facilate functionality of the Git Leaderboard project.
module Git
	# An immutable class that represents information associated with a commit in git.
	class Commit
		# An immutable class that represents information associated with a file modification in git.
		class FileModification
			# @return [String] the relative path of the file.
			attr_reader :path
			# @return [String, nil] the original path of the file if it was a move/rename, otherwise nil.
			attr_reader :original_path
			# @return [Integer] the total number of lines added to the file.
			attr_reader :number_of_additions
			# @return [Integer] the total number of lines deleted from the file.
			attr_reader :number_of_deletions

			# Initializes a new instance of {FileModification}.
			#
			# @param [String] path The relative path of the file that was modified.
			# @param [String, nil] original_path The original path of the file if it was a move/rename.
			# @param [Integer] number_of_additions The total number of lines that were added to the file.
			# @param [Integer] number_of_deletions The total number of lines that were deleted from the file.
			def initialize(
				path:, 
				original_path:, 
				number_of_additions:, 
				number_of_deletions:
			)
				@path = path
				@original_path = original_path
				@number_of_additions = number_of_additions
				@number_of_deletions = number_of_deletions
			end

			# @return [String] a human readable string representation of the file modification.
			def to_s
				return "+#{@number_of_additions}\t-#{@number_of_deletions}\t#{@path}"
			end
		end

		# @return [String] the name of the author of the commit.
		attr_reader :author_name
		# @return [String] the email of the author of the commit.
		attr_reader :author_email
		# @return [String] the 40-character SHA-1 hash of the commit.
		attr_reader :hash
		# @return [Array<FileModification>] an array of the file modifications that occured in the commit.
		attr_reader :file_modifications
		# @return [Integer] the total number of lines added across all file modifications in the commit.
		attr_reader :number_of_additions
		# @return [Integer] the total number of lines deleted across all file modifications in the commit.
		attr_reader :number_of_deletions

		# Initializes a new instance of {Commit}.
		#
		# @param [String] author_name The name of the author of the commit.
		# @param [String] author_email The email of the author of the commit.
		# @param [String] hash The 40-character SHA-1 hash of the commit.
		# @param [Array<FileModification>] file_modifications An array of the file modifications that occured in the commit.
		def initialize(
			author_name:, 
			author_email:, 
			hash:, 
			file_modifications:
		)
			@author_name = author_name
			@author_email = author_email
			@hash = hash
			@file_modifications = file_modifications
			@number_of_additions = 0
			@number_of_deletions = 0

			file_modifications.each do |file_modification|
				@number_of_additions += file_modification.number_of_additions
				@number_of_deletions += file_modification.number_of_deletions
			end
		end

		# @return [String] a human readable string representation of the commit.
		def to_s
			return "Author: #{@author_name}\nEmail: #{author_email}\nHash: #{@hash}\nAdditions: #{@number_of_additions}\nDeletions: #{@number_of_deletions}\n#{@file_modifications.join("\n")}"
		end
	end

	# Generates an array of {Commit} objects for a git repository.
	#
	# These Commit objects may be sanitized if any of the normalization or filtering parameters are provided. By default the Commit objects will match the raw information provided by "git log".
	#
	# @param [String] git_repository_path The path to the root of the git repository to generate commits from.
	# @param [Hash{String => String}] normalized_email_addresses A hash where the keys are an author's email address and the values are what that email address should be normalized to. Defaults to an empty hash.
	# @param [Hash{String => String}] normalized_names A hash where the keys are an author's email address and the values are what that author's name should be normalized to. This mapping is applied after the email addresses have already been normalized by the normalized_email_addresses parameter so you should typically have to only normalize an author's name once. Defaults to an empty hash.
	# @param [Array<String>] banned_email_addresses An array of email addresses for authors whose commits should be ignored. Defaults to an empty array.
	# @param [Array<String>] banned_paths An array of regular expressions that will be evaluated against file modification paths to determine if the file modification should be omitted or not. Defaults to an empty array.
	# @param [Boolean] verbose A flag indicating if actions should be outputted to the console. Defaults to false.
	#
	# @return [Array<Commit>] An array of commit objects.
	def self.commits_for(
		git_repository_path:,
		normalized_email_addresses: {},
		normalized_names: {},
		banned_email_addresses: [],
		banned_paths: [],
		verbose: false
	)
		commits = []

		# We assume the banned paths are all regular expressions so we union them together to make checking for any matches easier.
		banned_paths_regexp = Regexp.union(banned_paths.map { |string| Regexp.new(string) })

		# Change to the directory that contains the git repository.
		# Changing directly to the directory is easier than calling commands on specific paths. It is easier to assume inside a certain scope you will always be working in the correct directory.
		Dir.chdir(File.expand_path(git_repository_path)) do
			# We are using git log because we are going to parse each individual commit log and extract the information we need. This is probably much easier than trying to parse the underlying git file system.
			# --numstat because the output is more machine friendly and easier to parse with regular expressions. It also doesn't munge the paths so it is much easier to identify when a file was renamed which is critical for when we are searching for paths that have been banned.
			# --no-merges because we want to ignore all merge commits.
			# --pretty=format:'Author: %an%nEmail: %aE%nHash: %H' outputs the author name, email and commit hash in a way that is easily parsable by a regular expression.
			# -z separates the commits with NULs instead of with new newlines. Again, this just makes things easier to parse with regular expressions. Rather that trying to figure out what newlines mean new commits versus new file modifications we can just look for NULs instead.
			git_log_output = `git log --numstat --no-merges --pretty=format:'Author: %an%nEmail: %aE%nHash: %H' -z`

			# This regular expression extracts the author name, email, commit hash and a string that repesents all of the file modifications for that commit.
			git_log_output.scan(/Author: (.*)\nEmail: (.*)\nHash: (.*)[\n]?(.*)\x0/).each do |git_commit_info|
				author_name = git_commit_info[0]
				author_email = git_commit_info[1]
				commit_hash = git_commit_info[2]
				file_modifications_string = git_commit_info[3]

				if verbose
					puts "==============================\nAuthor: #{author_name}\nEmail: #{author_email}\nHash: #{commit_hash}"
				end

				# Normalize the author's email address if it exists in the mapping that was provided.
				if normalized_author_email = normalized_email_addresses[author_email]
					if verbose
						puts "NORMALIZED '#{author_email}' to '#{normalized_author_email}'"
					end

					author_email = normalized_author_email
				end

				# Normalize the author's name if it exists in the mapping that was provided.
				if normalized_author_name = normalized_names[author_email]
					if verbose
						puts "NORMALIZED '#{author_name}' to '#{normalized_author_name}'"
					end

					author_name = normalized_author_name
				end

				# Compare the author's email to the list of banned authors and skip the commit if a match is found.
				if banned_email_addresses.include? author_email
					if verbose
						puts "BANNED #{author_email}"
					end

					next
				end

				# The file modifications string that is extracted is a strange beast.
				# Each file modification is seperated by a NUL so that is something we can easily split on to get an array of all the file modifications. It should give us an array of strings that follow the format: (number_of_additions)\t(number_of_deletions)\t(path)
				# The one problem with this is that, for a reason I cannot fathom, if a file has been renamed its old and new paths are also seperated by a NUL. This leads us to a scenario where we may have an entry in the array that is just two numbers representing the number of additions and deletions and then the next two elements in the array represent the new path and the original path of the file that is being moved.
				# This is why we use a while loop to iterate over all of the file modifications. If we encounter this strange scenario we can easily consume the next two elements in the array and increment our iterator counter accordingly.
				file_modifications = []
				file_modifications_array = file_modifications_string.split("\x0")
				i = 0
				while i < file_modifications_array.length
					file_modification_string = file_modifications_array[i]

					if file_match_data = file_modification_string.match(/^(\d+)\t+(\d+)\t(.*)/)
						number_of_additions = file_match_data[1].to_i
						number_of_deletions = file_match_data[2].to_i
						path = file_match_data[3]
						original_path = nil

						if path.empty?
							i += 2
							path = file_modifications_array[i]
							original_path = file_modifications_array[i - 1]
						end

						if path.match(banned_paths_regexp).nil? == true
							file_modification = Commit::FileModification.new(
								path: path, 
								original_path: original_path, 
								number_of_additions: number_of_additions, 
								number_of_deletions: number_of_deletions
							)
							file_modifications.push(file_modification)

							if verbose
								puts file_modification
							end
						elsif verbose
							puts "IGNORED #{path}"
						end
					end

					i += 1
				end

				commit = Commit.new(
					author_name: author_name, 
					author_email: author_email, 
					hash: commit_hash, 
					file_modifications: file_modifications
				)
				commits.push(commit)
			end
		end

		return commits
	end
end

# The Scripts module contains classes and methods that are leveraged when the Git Leaderboard project is accessed via the command line.
#
# This module should only be used if you are building a command line tool. Otherwise, everything that you need should be in the {Git} module.
module Scripts
	# The {CommitsOptions} class encapsulates all of the options that can be passed into the git_commits.rb script via the command line.
	#
	# It is designed to be subclassed in case any scripts want to directly leverage the capabilities of git_commits.rb and therefore need to gather the same options.
	class CommitsOptions
		# @return [String] the value of the "--git-repository" option.
		attr_reader :git_repository_path
		# @return [Hash{String => String}] the value of the "--normalized-email-addresses" option.
		attr_reader :normalized_email_addresses
		# @return [Hash{String => String}] the value of the "--normalized-names" option.
		attr_reader :normalized_names
		# @return [Array<String>] the value of the "--banned-email-addresses" option.
		attr_reader :banned_email_addresses
		# @return [Array<String>] the value of the "--banned-paths" option.
		attr_reader :banned_paths
		# @return [Boolean] the value of the "--verbose" option.
		attr_reader :verbose

		# Initializes a new instance of {CommitsOptions}.
		#
		# The option_parser will parse the args parameter and use the results to populate all of the attributes.
		#
		# @param [Array<String>] args The arguments that were passed in to the command line.
		# @param [OptionParser] option_parser An OptionParser that will consume the args parameter.
		def initialize(
			args:, 
			option_parser:
		)
			@git_repository_path = Dir.pwd
			@normalized_email_addresses = {}
			@normalized_names = {}
			@banned_email_addresses = []
			@banned_paths = []
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
				"--git-repository PATH",
				String,
				"Path of the git repository to analyze.",
				"Defaults to the current directory if none is provided."
			) do |option_path|
				@git_repository_path = option_path
			end

			option_parser.on(
				"--normalized-email-addresses JSON",
				"A JSON object where the keys are an author's email address and the values are what that email address should be normalized to.",
				"For when a single author has committed under multiple email addresses.",
				"Can be either a JSON string or a path to a JSON file.",
				JSON
			) do |option_json|
				@normalized_email_addresses = option_json
			end

			option_parser.on(
				"--normalized-names JSON",
				"A JSON object where the keys are an author's email address and the values are what the author's name should be normalized to.",
				"For when a single author has committed under multiple names or for that one crazy author whose name makes absolutely no sense.",
				"This normalization is applied after the author's email address has been normalized by the mapping passed to --normalized-email-addresses. Therefore you should only need to provide a normalized name for the one email address that represents an author.",
				"Can be either a JSON string or a path to a JSON file.",
				JSON
			) do |option_json|
				@normalized_names = option_json
			end

			option_parser.on(
				"--banned-email-addresses JSON",
				"A JSON array of author email addresses whose commits should be ignored.",
				"Primarily designed for authors whose commits are automated.",
				"Can be either a JSON string or a path to a JSON file.",
				JSON
			) do |option_json|
				@banned_email_addresses = option_json
			end

			option_parser.on(
				"--banned-paths JSON",
				"A JSON array of regular expressions used to omit file modifications to specific paths.",
				"Can be either a JSON string or a path to a JSON file.",
				JSON
			) do |option_json|
				@banned_paths = option_json
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
end

if __FILE__ == $PROGRAM_NAME
	script_options = Scripts::CommitsOptions.new(
		args: ARGV,
		option_parser: OptionParser.new
	)

	Git.commits_for(
		git_repository_path: script_options.git_repository_path,
		normalized_email_addresses: script_options.normalized_email_addresses,
		normalized_names: script_options.normalized_names,
		banned_email_addresses: script_options.banned_email_addresses,
		banned_paths: script_options.banned_paths,
		verbose: script_options.verbose
	)
end

#!/usr/bin/env ruby

require "json"
require "optparse"

=begin rdoc
A class that represents all of the information associated with a commit in a git repository.
=end
class Commit
	class FileModification
		attr_reader :path
		attr_reader :original_path
		attr_reader :number_of_additions
		attr_reader :number_of_deletions

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

		def to_s
			return "+#{@number_of_additions}\t-#{@number_of_deletions}\t#{@path}"
		end
	end

	attr_reader :author_name
	attr_reader :author_email
	attr_reader :hash
	attr_reader :file_modifications
	attr_reader :number_of_additions
	attr_reader :number_of_deletions

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

	def to_s
		return "Author: #{@author_name}\nEmail: #{author_email}\nHash: #{@hash}\nAdditions: #{@number_of_additions}\nDeletions: #{@number_of_deletions}\n#{@file_modifications.join("\n")}"
	end
end

=begin rdoc
Returns an array of Commit objects for the given git repository.

These Commit objects may have been sanitized if any of the other parameters specifying certain filtering rules were passed in.
=end
def commits_for_git_repo(
	git_repository_path:, 
	normalized_names: {}, 
	banned_names: [], 
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

			# Normalize the author name if it exists in the mapping that was provided.
			if normalized_author_name = normalized_names[author_name]
				if verbose
					puts "NORMALIZED '#{author_name}' to '#{normalized_author_name}'"
				end

				author_name = normalized_author_name
			end

			# Compare the author's name to the list of banned authors and skip the commit if a match is found.
			if banned_names.include? author_name
				if verbose
					puts "BANNED #{author_name}"
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
						path = file_modifications_string[i]
						original_path = file_modifications_string[i - 1]
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

class CommitsScriptOptions
	attr_reader :git_repository_path
	attr_reader :normalized_names
	attr_reader :banned_names
	attr_reader :banned_paths
	attr_reader :verbose

	def initialize(
		args:, 
		option_parser:
	)
		@git_repository_path = Dir.pwd
		@normalized_names = {}
		@banned_names = []
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
			"Path to the git repository to analyze.",
			"Defaults to the current directory if no path is provided."
			) do |option_path|
				@git_repository_path = option_path
		end

		option_parser.on(
			"--normalized-names JSON",
			"A JSON object where the keys are the committers' names and the values are what the names should be normalized to.",
			"For when a single author has committed under multiple names or for that one crazy committer whose name makes absolutely no sense.",
			"Can be either a JSON string or a path to a JSON file.",
			JSON
			) do |option_json|
				@normalized_names = option_json
		end

		option_parser.on(
			"--banned-names JSON",
			"A JSON array of author names whose commits should be ignored.",
			"Primarily designed for authors whose commits are automated.",
			"Can be either a JSON string or a path to a JSON file.",
			JSON
			) do |option_json|
				@banned_names = option_json
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

if __FILE__ == $PROGRAM_NAME
	script_options = CommitsScriptOptions.new(
		args: ARGV, 
		option_parser: OptionParser.new
	)

	commits_for_git_repo(
		git_repository_path: script_options.git_repository_path,
		normalized_names: script_options.normalized_names,
		banned_names: script_options.banned_names,
		banned_paths: script_options.banned_paths,
		verbose: script_options.verbose
	)
end

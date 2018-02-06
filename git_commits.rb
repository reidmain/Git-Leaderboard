#!/usr/bin/env ruby

require "json"
require "optparse"

class Commit
	class FileModification
		attr_reader :path
		attr_reader :original_path
		attr_reader :additions
		attr_reader :deletions

		def initialize(path, original_path, additions, deletions)
			@path = path
			@original_path = original_path
			@additions = additions
			@deletions = deletions
		end

		def to_s
			return "+#{@additions}\t-#{@deletions}\t#{@path}"
		end
	end

	attr_reader :author_name
	attr_reader :author_email
	attr_reader :hash
	attr_reader :file_modifications
	attr_reader :additions
	attr_reader :deletions

	def initialize(author_name, author_email, hash)
		@author_name = author_name
		@author_email = author_email
		@hash = hash
		@file_modifications = []
		@additions = 0
		@deletions = 0
	end

	def add_file_modification(file_modification)
		file_modifications.push(file_modification)
		@additions += file_modification.additions
		@deletions += file_modification.deletions
	end

	def to_s
		return "Author: #{@author_name}\nHash: #{@hash}\nAdditions: #{@additions}\nDeletions: #{@deletions}\n#{@file_modifications.join("\n")}"
	end
end

def commits_for_git_repo(git_repo, normalized_names = {}, banned_filenames = [])
	commits = []
	banned_filenames_regexp = Regexp.union(banned_filenames.map { |string| Regexp.new(string) })

	Dir.chdir(git_repo) do
		git_log_output = `git log --numstat --no-merges --pretty=format:'Author: %an%nEmail: %aE%nHash: %H' -z`

		git_log_output.scan(/Author: (.*)\nEmail: (.*)\nHash: (.*)[\n]?(.*)\x0/).each do |commit_match|
			author_name = commit_match[0]

			if normalized_author = normalized_names[author_name]
				author_name = normalized_author
			end

			author_email = commit_match[1]
			commit_hash = commit_match[2]

			current_commit = Commit.new(author_name, author_email, commit_hash)
			commits.push(current_commit)

			file_modifications_string = commit_match[3].split("\x0")
			i = 0
			while i < file_modifications_string.length
				file_modification_string = file_modifications_string[i]

				if file_match_data = file_modification_string.match(/^(\d+)\t+(\d+)\t(.*)/)
					additions = file_match_data[1].to_i
					deletions = file_match_data[2].to_i
					path = file_match_data[3]
					original_path = nil
					if path.empty?
						i += 2
						path = file_modifications_string[i]
						original_path = file_modifications_string[i - 1]
					end

					if path.match(banned_filenames_regexp).nil? == true
						file_modification = Commit::FileModification.new(path, original_path, additions, deletions)
						current_commit.add_file_modification(file_modification)
					end
				end

				i += 1
			end
		end
	end

	return commits
end

class ScriptOptions
	attr_reader :git_repository_path
	attr_reader :normalized_names
	attr_reader :banned_names
	attr_reader :banned_paths
	attr_reader :verbose

	def initialize(args)
		@git_repository_path = Dir.pwd
		@normalized_names = {}
		@banned_paths = []

		option_parser = OptionParser.new

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
			"For when a single author has commited under multiple names or for that one crazy committer whose name makes absolutely no sense.",
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
			"--banned-filenames JSON",
			"A JSON array of regular expressions used to omit specific file modifications.",
			"Can be either a JSON string or a path to a JSON file.",
			JSON
			) do |option_json|
				@banned_paths = option_json
		end

		option_parser.on(
			"--verbose flag",
			"A switch to determine if actions taken should be outputted to the console.",
			"Defaults to off.",
			FalseClass
			) do |flag|
				@verbose = flag
		end

		option_parser.parse(args)
	end
end

if __FILE__ == $PROGRAM_NAME
	script_options = ScriptOptions.new(ARGV)

	commits = commits_for_git_repo(script_options.git_repository_path,
		script_options.normalized_names,
		script_options.banned_paths)

	puts commits.join("\n\n")
end

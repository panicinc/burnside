#!/usr/bin/ruby

require "rubygems"
require "bundler/setup"
require "twitter"
require 'optparse'
require 'pp'
require 'date'
require 'oj'
require 'mail'
require 'uri'
require 'yaml'
require 'erb'

options = {}

optparse = OptionParser.new do |opts|

	opts.banner = "Usage: #{__FILE__} -c CONFIG_FILE [options]"

	opts.separator ""
	opts.separator "Required options:"

	options[:config_file] = nil;
	opts.on("-c", "--config CONFIG_FILE",
	"configuration file to use") do |user|
		options[:config_file] = user
	end

	opts.separator ""
	opts.separator "Common options:"

	options[:verbose] = false
	opts.on( '-v', '--verbose', 'Output more information' ) do
		options[:verbose] = true
	end

	options[:dryrun] = false
	opts.on( '-n', '--dry-run', "Don't send any email" ) do
		options[:dryrun] = true
	end

	options[:test] = false
	opts.on( '-t', '--test', "Ignore status file and always fetch tweets" ) do
		options[:test] = true
	end

	opts.on_tail('-h', '--help', 'Display this help') do 
		puts opts
		exit
	end

end

begin
	optparse.parse!
	mandatory = [:config_file]
	missing = mandatory.select{ |param| options[param].nil? }
	if not missing.empty?
		puts "Missing options: #{missing.join(', ')}"
		puts
		puts optparse
		exit(1)
	end
rescue OptionParser::InvalidOption, OptionParser::MissingArgument
	puts $!.to_s
	puts optparse
	exit(1)
end

@config = YAML.load_file(options[:config_file])
 
statusFile = 'config/' + @config['username'] + ".status"
templateFile = 'config/' + @config['username'] + ".erb"

lastStatusID = (File.exists?(statusFile) && !options[:test]) ? IO.read(statusFile) : nil

@client = Twitter::Client.new(@config['oauth'])
@client.user(@config['username'])

mentions = lastStatusID ? @client.mentions(:since_id => lastStatusID) : @client.mentions(:count => 3)

exit if mentions.count == 0

latestStatusID = mentions.first.id
File.open(statusFile, 'w') {|f| f.write(latestStatusID) } unless options[:dryrun]
	
renderer = ERB.new(IO.read(templateFile))

mentions.each do |@mention|
	
	@status_url = "https://twitter.com/#{@mention.user.screen_name}/status/#{@mention.id}"

	mail = Mail.new(renderer.result())
	mail.delivery_method @config['mail']['delivery_method'], @config['mail']['delivery_configuration']
	mail.delivery_method :test if (options[:dryrun])
	
	puts mail.to_s if options[:verbose]

	mail.deliver
end

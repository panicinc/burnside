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
		exit
	end
rescue OptionParser::InvalidOption, OptionParser::MissingArgument
	puts $!.to_s
	puts optparse
	exit
end

@config = YAML.load_file(options[:config_file])
 
statusFile = @config['username'] + ".status"
templateFile = 'config/' + @config['username'] + ".erb"


lastStatusID = IO.read(statusFile) if File.exists?(statusFile)

@client = Twitter::Client.new(@config['oauth'])
@client.user(@config['username'])

mentions = ()
if (lastStatusID)
	mentions = @client.mentions(:since_id => lastStatusID)
else
	mentions = @client.mentions(:count => 1)
end	

exit if mentions.count == 0

latestStatusID = mentions.first.id
File.open(statusFile, 'w') {|f| f.write(latestStatusID) }

	
renderer = ERB.new(IO.read(templateFile))

mentions.each do |@mention|
	
	@status_url = "https://twitter.com/#{@mention.user.screen_name}/status/#{@mention.id}"

	mail = Mail.new(renderer.result())
	mail.delivery_method @config['mail']['delivery_method'], @config['mail']['delivery_configuration']
	mail.delivery_method :test if (options[:dryrun])
	
	puts mail.to_s

	mail.deliver
end



#!/usr/bin/ruby

require "rubygems"
require "bundler/setup"
gem 'twitter'
gem 'oj'
gem 'mail'

require 'optparse'
require 'pp'
require 'date'
require 'uri'
require 'yaml'
require 'erb'
require 'logger'

options = {}

#! Options Parsing
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

	options[:log] = false
	opts.on( '-l', '--log', 'Log script progess' ) do
		options[:log] = true
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
		$stderr.puts "Missing options: #{missing.join(', ')}"
		$stderr.puts
		$stderr.puts optparse
		exit(1)
	end
rescue OptionParser::InvalidOption, OptionParser::MissingArgument
	$stderr.puts $!.to_s
	$stderr.puts optparse
	exit(1)
end

@config = YAML.load_file(options[:config_file])
 
statusFile = 'config/' + @config['username'] + ".status"
header_templateFile = 'config/' + @config['username'] + ".header.erb"
html_templateFile = 'config/' + @config['username'] + ".html.erb"
text_templateFile = 'config/' + @config['username'] + ".txt.erb"

log = Logger.new('config/' + @config['username'] + '.log') if options[:log]
log.info "Starting Up" if options[:log]

lastStatusID = (File.exists?(statusFile) && !options[:test]) ? IO.read(statusFile) : nil

begin
	@client = Twitter::Client.new(@config['oauth'])
	@client.user(@config['username'])
rescue
	log.error "An error occured while configuring the client: " + $! if options[:log]
	log.error "Bailing Out!" if options[:log]		
	exit(1)		
end

log.info "Last Status ID of #{@config['username']} is #{lastStatusID}" if options[:log]

begin
	mentions = lastStatusID ? @client.mentions(:since_id => lastStatusID, :count => 200) : @client.mentions(:count => 1)
rescue
	log.error "An error occured while fetching the mentions: " + $! if options[:log]
	log.error "Bailing Out!" if options[:log]
	exit(1)		
end

if mentions.count == 0
	log.info "No mentions found; shutting down" if options[:log]
	exit
else
	log.info "Found #{mentions.count} mentions" if options[:log]
end

latestStatusID = lastStatusID
	
header_renderer = ERB.new(IO.read(header_templateFile))
html_renderer = ERB.new(IO.read(html_templateFile))
text_renderer = ERB.new(IO.read(text_templateFile))

mentions.reverse.each do |@mention|
	
	@status_url = "https://twitter.com/#{@mention.user.screen_name}/status/#{@mention.id}"

	mail = Mail.new(header_renderer.result())
	
	text_part = Mail::Part.new do
		content_type 'text/plain; charset=UTF-8'
		body text_renderer.result()
	end
	
	html_part = Mail::Part.new do
		body html_renderer.result()
		content_type 'text/html; charset=UTF-8'
	end
	
	mail.text_part = text_part
	mail.html_part = html_part
	
	mail.delivery_method @config['mail']['delivery_method'], @config['mail']['delivery_configuration']
	mail.delivery_method :test if (options[:dryrun])
	
	log.info "New tweet from #{@mention.user.screen_name}: #{@mention.id} #{@mention.created_at}" if options[:log]

	puts mail.to_s if options[:verbose]

	begin
		mail.deliver
		latestStatusID = @mention.id
	rescue
		log.error "An error occured during delivery:" + $! if options[:log]
	end
end
File.open(statusFile, 'w') {|f| f.write(latestStatusID) } unless options[:dryrun]
log.info "Shutting Down" if options[:log]

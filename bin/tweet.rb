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
	opts.on( '-n', '--dry-run', "Don't send any tweets" ) do
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
templateFile = 'config/' + @config['username'] + "_reply.erb"
renderer = ERB.new(IO.read(templateFile))

mail = Mail.new(ARGF.read())

mail.to.first =~ /^twitter\+([A-Za-z0-9_]+)@panic.com/
@to = "@" + $1
@sig = "-" + mail[:from].decoded.chars.first

mail.body.decoded =~ /(.*)(On.*wrote:.*)/m
@reply_text = $1.strip

msg = renderer.result()

char_count = msg.chars.count

